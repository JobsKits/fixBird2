const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const root = path.resolve(__dirname, "..");
const flush = () => new Promise(setImmediate);
const auth = () => ({ token: "test-session-token", expiresAt: "2030-01-01T00:00:00Z",
  user: { id: "usr_test", username: "customer", displayName: "测试用户", role: "customer" },
  session: { id: "dev_pc", device: { kind: "desktop" }, capabilities: [] } });
function response(data, status = 200, cursor = "") {
  return { ok: status < 400, status, headers: { get: name => name === "X-Next-Cursor" ? cursor : "" }, json: async () => data };
}
function harness(saved = {}) {
  const nodes = new Map(), clicks = [], timers = [], qrValues = [], storage = new Map(Object.entries(saved));
  const node = key => {
    if (!nodes.has(key)) nodes.set(key, { value: "", hidden: false, disabled: false, innerHTML: "", textContent: "", events: {},
      addEventListener(name, fn) { this.events[name] = fn; }, reset() {} });
    return nodes.get(key);
  };
  const QRCode = function(_node, options) { qrValues.push(options.text); };
  QRCode.CorrectLevel = { M: 0 };
  const context = vm.createContext({ URL, URLSearchParams, structuredClone, AbortController, QRCode,
    crypto: { randomUUID }, navigator: { platform: "Web-test" }, location: new URL("http://127.0.0.1:8099/portal/"),
    localStorage: { getItem: () => null, setItem() {} },
    sessionStorage: { getItem: key => storage.get(key) || null, setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    window: { clearTimeout, addEventListener() {}, prompt: () => null,
      setTimeout(fn, ms) { if (ms === 2000) { timers.push(fn); return null; } return setTimeout(fn, ms); } },
    document: { querySelector: node, addEventListener: (name, fn) => { if (name === "click") clicks.push(fn); } },
    fetch: async () => { throw Error("offline"); }
  });
  vm.runInContext(fs.readFileSync(path.join(root, "environment.js"), "utf8").replace("const API_REQUEST_TIMEOUT_MS = 2000;", "const API_REQUEST_TIMEOUT_MS = 25;"), context);
  vm.runInContext(fs.readFileSync(path.join(root, "portal.js"), "utf8"), context);
  return { context, node, timers, qrValues, storage, clicks, run: source => vm.runInContext(source, context) };
}
function reads(url) {
  if (url.includes("/orders")) return response([]);
  if (url.includes("/ledger")) return response([]);
  return response({ code: "not_found", message: "未实现" }, 404);
}
async function login(h, value = auth()) {
  h.context.fetch = async (url, options) => url.endsWith("/auth/login") ? response(value) : reads(url);
  h.node("#username").value = "customer";
  h.node("#password").value = "test-password-example";
  await h.node("#passwordLogin").events.submit({ preventDefault() {} });
  await flush();
}
test("登录失败不创建本地身份；密码立即清除，不进入浏览器会话存储", async () => {
  const h = harness(); await flush();
  h.context.fetch = async () => response({ message: "账号密码错误" }, 401);
  h.node("#username").value = "customer"; h.node("#password").value = "typed-password";
  await h.node("#passwordLogin").events.submit({ preventDefault() {} });
  assert.equal(h.node("#password").value, "");
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#accountPanel").hidden, true);
  assert.match(h.node("#feedback").textContent, /登录失败/);
});
test("二维码等待期间不登录，只有批准返回独立认证结果才登录；二维码没有Bearer", async () => {
  const h = harness(); await flush();
  const challenge = { id: "qr_test", pollToken: "test-poll-proof", qrPayload: "repairmarketplace://login?challengeId=qr_test&approvalCode=test-proof", expiresAt: "2030-01-01T00:00:00Z" };
  let approved = false;
  h.context.fetch = async url => url.endsWith("/challenges") ? response(challenge, 201) :
    url.endsWith("/poll") ? response(approved ? { status: "approved", auth: auth() } : { status: "pending" }) : reads(url);
  await h.node("#createQR").events.click(); await flush();
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#accountPanel").hidden, true);
  assert.equal(h.qrValues[0], challenge.qrPayload);
  assert.ok(!h.qrValues[0].includes(auth().token));
  approved = true;
  await h.timers.shift()(); await flush();
  assert.equal(h.node("#accountPanel").hidden, false);
  assert.match(h.node("#feedback").textContent, /独立登录/);
  assert.equal(JSON.parse([...h.storage.values()][0]).token, auth().token);
});
test("扫码consumed不会伪造登录成功，提示重新扫码且清除二维码内容", async () => {
  const h = harness(); await flush();
  h.context.fetch = async url => url.endsWith("/challenges") ? response({ id: "qr_test", pollToken: "p", qrPayload: "repairmarketplace://login?challengeId=q&approvalCode=a", expiresAt: "2030-01-01T00:00:00Z" }, 201) : response({ status: "consumed" });
  await h.node("#createQR").events.click(); await flush();
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#qrPayload").value, "");
  assert.match(h.node("#qrState").textContent, /重新扫码/);
});
test("环境切换忽略旧登录结果；会话按服务地址隔离", async () => {
  const h = harness(); await flush();
  let complete;
  h.context.fetch = async url => url.endsWith("/auth/login") ? new Promise(resolve => { complete = resolve; }) : reads(url);
  h.node("#username").value = "customer"; h.node("#password").value = "password-example";
  const pending = h.node("#passwordLogin").events.submit({ preventDefault() {} });
  h.node("#environment").value = "test"; h.node("#baseURL").value = "http://localhost:9000";
  h.node("#saveEnvironment").events.click(); complete(response(auth())); await pending; await flush();
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#accountPanel").hidden, true);
});
test("PC退出只发送当前Bearer的logout；401撤销会话并清除本人页面", async () => {
  const h = harness(); await flush(); await login(h);
  let logoutRequest;
  h.context.fetch = async (url, options) => { logoutRequest = { url, options }; return response(null, 204); };
  await h.node("#logout").events.click();
  assert.ok(logoutRequest.url.endsWith("/auth/logout"));
  assert.equal(logoutRequest.options.headers.Authorization, "Bearer " + auth().token);
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#accountPanel").hidden, true);
  await login(h);
  h.context.fetch = async () => response({ message: "设备已撤销" }, 401);
  await h.node("#refreshOrders").events.click(); await flush();
  assert.equal(h.storage.size, 0);
  assert.equal(h.node("#accountPanel").hidden, true);
  assert.match(h.node("#feedback").textContent, /撤销/);
});
test("刷新页面保留该PC会话；请求继续使用Bearer且不依赖手机会话", async () => {
  const value = auth();
  const h = harness({ "repairPCSession:test:http://127.0.0.1:8099": JSON.stringify(value) }); await flush();
  let header;
  h.context.fetch = async (url, options) => { header = options.headers.Authorization; return reads(url); };
  await h.node("#refreshOrders").events.click();
  assert.equal(header, "Bearer " + value.token);
  assert.equal(h.node("#accountPanel").hidden, false);
  assert.match(h.node("#sessionState").textContent, /手机退出不会/);
});

test("旧已登录订单请求迟到401不能清除新登录，也不能覆盖新账号提示", async () => {
  const h = harness();
  await flush();
  await login(h);
  let finishOldRequest, oldAuthorization;
  h.context.fetch = async (_url, options) => {
    oldAuthorization = options.headers.Authorization;
    return new Promise(resolve => { finishOldRequest = resolve; });
  };
  const oldRead = h.node("#refreshOrders").events.click();
  assert.equal(oldAuthorization, "Bearer " + auth().token);

  const next = { ...auth(), token: "new-account-independent-session",
    user: { ...auth().user, id: "usr_next", username: "next-customer", displayName: "新账号用户" } };
  await login(h, next);
  const newFeedback = h.node("#feedback").textContent;
  assert.match(newFeedback, /此 PC 已独立登录/);
  assert.match(h.node("#accountTitle").textContent, /新账号用户/);

  finishOldRequest(response({ message: "旧设备已被撤销" }, 401));
  await oldRead;
  await flush();
  assert.equal(h.node("#accountPanel").hidden, false);
  assert.match(h.node("#accountTitle").textContent, /新账号用户/);
  assert.equal(h.node("#feedback").textContent, newFeedback);
  assert.equal(h.storage.size, 1);
  assert.equal(JSON.parse([...h.storage.values()][0]).token, next.token);
});
