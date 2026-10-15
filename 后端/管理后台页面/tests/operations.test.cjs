const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.resolve(__dirname, "..");
const sourceNames = ["environment.js", "marketplace-data.js", "session.js", "operations-data.js", "admin.js", "auth.js", "operations.js"];
const flush = async () => { await new Promise(setImmediate); await new Promise(setImmediate); };

function fixture({ timeout = 200 } = {}) {
  const nodes = new Map();
  const downloads = [];
  const objectURLs = [];
  const revokedURLs = [];
  const documentEvents = new Map();
  function node(key) {
    if (!nodes.has(key)) {
      const events = new Map();
      nodes.set(key, { value: key === "#ledgerMode" ? "simulated" : key === "#applicationStatus" ? "pending" : "",
        hidden: false, disabled: false, innerHTML: "", textContent: "", events,
        addEventListener(type, callback) { events.set(type, [...(events.get(type) || []), callback]); },
        setAttribute(name, value) { this[name] = value; }, removeAttribute(name) { delete this[name]; }, close() { this.open = false; }, showModal() { this.open = true; }
      });
    }
    return nodes.get(key);
  }
  class RuntimeURL extends URL {
    static createObjectURL(blob) { const value = "blob:test-" + objectURLs.length; objectURLs.push({ value, blob }); return value; }
    static revokeObjectURL(value) { revokedURLs.push(value); }
  }
  const context = vm.createContext({ URL: RuntimeURL, URLSearchParams, Blob, structuredClone, AbortController,
    Image: class {}, navigator: {}, location: new URL("http://127.0.0.1:8081/admin/"),
    localStorage: { getItem: () => null, setItem() {} },
    window: { setTimeout, clearTimeout, confirm: () => true },
    document: { querySelector: node, querySelectorAll: () => [],
      addEventListener(type, callback) { documentEvents.set(type, [...(documentEvents.get(type) || []), callback]); },
      createElement(tag) { return { click() { downloads.push({ tag, href: this.href, download: this.download }); } }; }
    }, fetch: async () => { throw Error("offline"); }
  });
  for (const name of sourceNames) {
    let source = fs.readFileSync(path.join(root, name), "utf8");
    if (name === "environment.js") source = source.replace("const API_REQUEST_TIMEOUT_MS = 2000;", "const API_REQUEST_TIMEOUT_MS = " + timeout + ";");
    vm.runInContext(source, context, { filename: name });
  }
  const run = code => vm.runInContext(code, context);
  const fire = async (selector, type, event = {}) => {
    event.preventDefault ||= () => {};
    const callbacks = node(selector).events.get(type) || [];
    await Promise.all(callbacks.map(callback => callback(event)));
    await flush();
  };
  const clickOperation = (operation, id) => {
    const button = { disabled: false, dataset: { operation, id } };
    const event = { target: { closest: selector => selector.includes("data-operation") ? button : null } };
    for (const callback of documentEvents.get("click") || []) callback(event);
    return button;
  };
  return { context, nodes, node, run, fire, clickOperation, downloads, objectURLs, revokedURLs };
}

function auth(token = "admin-session") {
  return { token, expiresAt: "2099-01-01T00:00:00Z", user: { id: "admin-one", username: "admin", displayName: "管理员", role: "admin" } };
}

function application(id = "server-application") {
  return { id, workerId: "worker-one", displayName: "服务端待审核师傅", contactPhone: "13000000000",
    serviceAreas: ["上海"], skills: ["维修"], assetIds: ["private-asset"], bio: "服务端资料",
    status: "pending", revision: 1, reviewNote: "", createdAt: "2026-10-05T10:00:00Z" };
}

function journal(id = "server-journal", mode = "simulated") {
  return { id, eventKey: "collection:" + id, orderId: "server-order", customerId: "customer-one",
    workerId: "worker-one", settlementId: "settlement-one", mode, simulated: mode === "simulated",
    kind: "collection", channel: mode === "simulated" ? "demo" : "wechat", status: "posted",
    amountCents: 100, workerShareCents: 85, platformFeeCents: 15, occurredAt: "2026-10-05T10:00:00Z",
    entries: [{ account: "platform_funds", direction: "debit", amountCents: 100 },
      { account: "worker_payable", direction: "credit", amountCents: 85 },
      { account: "platform_revenue", direction: "credit", amountCents: 15 }] };
}

function summary(mode = "simulated", count = 1) {
  return { mode, simulated: mode === "simulated", currency: "CNY", scope: "filtered_movements",
    journalCount: count, collectedCents: 100 * count, workerAccruedCents: 85 * count,
    platformRevenueCents: 15 * count, payoutCents: 0, platformFundsCents: 100 * count, workerPayableCents: 85 * count };
}

function response(data, { status = 200, cursor = "" } = {}) {
  return { ok: status < 400, status, headers: { get: name => name === "X-Next-Cursor" ? cursor : "" },
    json: async () => structuredClone(data), blob: async () => data };
}

function online(h, override = {}) {
  return async url => {
    const path = new URL(url).pathname;
    const endpoint = path.split("/").pop();
    if (path.includes("worker-applications")) return response(override.applications || [application()]);
    if (path.includes("/ledger/")) return response(endpoint === "summary" ? override.summary || summary() : override.journals || [journal()], { cursor: override.cursor || "" });
    const values = { dashboard: h.run("demoDashboard()"), orders: h.run("DEMO_SEED.orders"), workers: h.run("DEMO_SEED.workers"), settlements: [] };
    return response(values[endpoint]);
  };
}

async function authenticated(h) {
  await flush();
  h.context.fetch = online(h);
  h.run("AdminSession.set(" + JSON.stringify(auth()) + ")");
  await h.run("window.AdminOperations.refresh()");
  await flush();
}

test("管理员会话只接受未过期管理员；切换服务丢弃凭据，旧401不能清除新登录", async () => {
  const h = fixture();
  await flush();
  for (const value of [{ ...auth(), user: { ...auth().user, role: "worker" } }, { ...auth(), expiresAt: "2000-01-01T00:00:00Z" }, { ...auth(), token: "" }]) {
    assert.throws(() => h.run("AdminSession.set(" + JSON.stringify(value) + ")"), /登录响应/);
  }
  await authenticated(h);
  assert.equal(h.run("AdminSession.headers().Authorization"), "Bearer admin-session");
  let finish;
  const reads = online(h);
  h.context.fetch = async url => url.endsWith("/old-auth-request") ? new Promise(resolve => { finish = resolve; }) : reads(url);
  const old = h.run('request("/old-auth-request")');
  h.run("AdminSession.set(" + JSON.stringify(auth("new-session")) + ")");
  finish(response({ code: "unauthenticated", message: "old session" }, { status: 401 }));
  await assert.rejects(old, /old session/);
  assert.equal(h.run("AdminSession.current().token"), "new-session");
  h.run('saveAPIEnvironment("test", "http://localhost:9090")');
  assert.equal(h.run("AdminSession.current()"), null);
  assert.equal(h.run("AdminSession.headers().Authorization"), undefined);
  await flush();
});

test("登录拒绝不产生本地管理员，迟到登录不进入切换后的环境", async () => {
  const h = fixture();
  await flush();
  h.node("#adminUsername").value = "admin";
  h.node("#adminPassword").value = "never-retain-password";
  h.context.fetch = async () => response({ message: "错误密码" }, { status: 401 });
  await h.fire("#adminLogin", "submit");
  assert.equal(h.run("AdminSession.current()"), null);
  assert.equal(h.node("#adminPassword").value, "");
  assert.match(h.node("#operationsState").textContent, /未创建本地管理员身份/);
  let finish;
  h.context.fetch = async () => new Promise(resolve => { finish = resolve; });
  const login = h.fire("#adminLogin", "submit");
  h.run('saveAPIEnvironment("test", "http://localhost:9090"); window.AdminOperations.reset()');
  finish(response(auth()));
  await login;
  assert.equal(h.run("AdminSession.current()"), null);
  assert.doesNotMatch(h.node("#operationsState").textContent, /管理员登录成功/);
});

test("审核409只改独立副本，后续真数据覆盖，不伪造确认也不自动重试", async () => {
  const h = fixture();
  await authenticated(h);
  let posts = 0;
  const reads = online(h);
  h.context.fetch = async (url, options) => {
    if (options.method === "POST") { posts += 1; return response({ message: "版本已变化" }, { status: 409 }); }
    return reads(url);
  };
  h.node("#note-server-application").value = "人工检查";
  h.clickOperation("approved", "server-application");
  await flush();
  assert.equal(posts, 1);
  assert.match(h.node("#applications").innerHTML, /demo-copy-server-application/);
  assert.match(h.node("#operationsState").textContent, /未获服务端确认.*不代表真实审核通过/);
  assert.match(h.node("#applicationsSource").textContent, /独立本地演示/);
  await h.run("window.AdminOperations.refresh()");
  assert.equal(posts, 1);
  assert.doesNotMatch(h.node("#applications").innerHTML, /demo-copy-server-application/);
  assert.match(h.node("#applications").innerHTML, /待审核/);
  assert.match(h.node("#operationsState").textContent, /未获服务端确认/);
});

test("审核防重复点击，驳回需意见；环境变化丢弃迟到成功", async () => {
  const h = fixture();
  await authenticated(h);
  let posts = 0, finish;
  const reads = online(h);
  h.context.fetch = async (url, options) => {
    if (options.method === "POST") { posts += 1; return new Promise(resolve => { finish = resolve; }); }
    return reads(url);
  };
  h.clickOperation("rejected", "server-application");
  assert.equal(posts, 0);
  assert.match(h.node("#operationsState").textContent, /需要填写/);
  h.clickOperation("approved", "server-application");
  h.clickOperation("approved", "server-application");
  assert.equal(posts, 1);
  h.context.fetch = async () => { throw Error("new-environment-offline"); };
  h.run('saveAPIEnvironment("test", "http://localhost:9090"); window.AdminOperations.reset()');
  assert.doesNotMatch(h.node("#applications").innerHTML, /服务端待审核师傅/);
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /server-journal/);
  finish(response({ ...application(), status: "approved", revision: 2 }));
  await flush();
  assert.doesNotMatch(h.node("#operationsState").textContent, /服务端已确认审核/);
  assert.doesNotMatch(h.node("#applications").innerHTML, /服务端待审核师傅/);
});

test("账务分页只给列表加cursor；汇总和CSV覆盖完整同一筛选范围", async () => {
  const h = fixture();
  await authenticated(h);
  h.node("#ledgerWorker").value = "worker-one";
  let urls = [];
  const reads = online(h);
  h.context.fetch = async (url, options) => {
    urls.push({ url, options });
    const parsed = new URL(url);
    if (parsed.pathname.endsWith("/journals")) return response(parsed.searchParams.has("cursor") ? [journal(), journal("second-journal")] : [journal()], { cursor: parsed.searchParams.has("cursor") ? "" : "opaque-next" });
    if (parsed.pathname.endsWith("/summary")) return response(summary("simulated", 2));
    if (parsed.pathname.endsWith("/export.csv")) return response(new Blob(["\ufeffid,mode\nserver-journal,simulated"], { type: "text/csv; charset=utf-8" }));
    return reads(url);
  };
  await h.run("window.AdminOperations.refresh()");
  assert.equal(h.node("#ledgerMore").hidden, false);
  await h.fire("#ledgerMore", "click");
  assert.match(h.node("#ledgerBody").innerHTML, /second-journal/);
  assert.equal((h.node("#ledgerBody").innerHTML.match(/server-journal/g) || []).length, 1);
  assert.equal(h.node("#ledgerMore").hidden, true);
  const page = urls.find(item => item.url.includes("cursor=opaque-next"));
  assert.ok(page && page.url.includes("workerId=worker-one"));
  assert.ok(urls.filter(item => item.url.includes("/summary")).every(item => !item.url.includes("cursor=")));
  await h.fire("#ledgerExport", "click");
  const exported = urls.find(item => item.url.includes("export.csv"));
  assert.ok(exported.url.includes("workerId=worker-one") && !exported.url.includes("cursor="));
  assert.equal(exported.options.headers.Authorization, "Bearer admin-session");
  assert.equal(h.downloads.length, 1);
  assert.equal(h.downloads[0].download, "账务流水-simulated.csv");
});

test("真实账查询失败保持空，模拟账不伪装为真实账；模式错配响应拒绝", async () => {
  const h = fixture();
  await authenticated(h);
  h.run('MarketplaceData.applyDemoAction(DEMO_DATA, "demo-collect", "demo-water-heater-002")');
  h.node("#ledgerMode").value = "actual";
  h.context.fetch = async () => { throw Error("offline-actual-ledger"); };
  await h.run("window.AdminOperations.refresh()");
  assert.match(h.node("#ledgerSource").textContent, /未获服务端确认/);
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /local-collection-|demo-water-heater-002/);
  assert.equal(h.node("#ledgerExport").disabled, true);
  h.context.fetch = online(h, { journals: [journal()], summary: summary("simulated") });
  await h.run("window.AdminOperations.refresh()");
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /server-journal/);
  assert.match(h.node("#ledgerSource").textContent, /未获服务端确认/);
  h.context.fetch = online(h, { journals: [], summary: summary("actual", 0) });
  await h.run("window.AdminOperations.refresh()");
  assert.match(h.node("#ledgerSource").textContent, /服务端账本/);
  assert.match(h.node("#ledgerBody").innerHTML, /暂无对应账务流水/);
});

test("账务结构验证金额整数与模拟标记，时间范围为半开且等界拒绝", async () => {
  const h = fixture();
  await authenticated(h);
  for (const item of [{ ...journal(), amountCents: 0.1 }, { ...journal(), simulated: false }, { ...journal(), entries: [{ account: "platform_funds", direction: "debit", amountCents: NaN }] }]) {
    assert.equal(h.run("OperationsData.journals(" + JSON.stringify([item]) + ")"), false);
  }
  assert.equal(h.run("OperationsData.journals(" + JSON.stringify([journal("actual-journal", "actual")]) + ")"), true);
  assert.equal(h.run("OperationsData.summary(" + JSON.stringify({ ...summary(), simulated: false }) + ")"), false);
  h.run('MarketplaceData.applyDemoAction(DEMO_DATA, "demo-collect", "demo-water-heater-002"); DEMO_DATA.settlements[0].createdAt = "2026-10-05T10:00:00Z"');
  h.node("#ledgerTo").value = "2026-10-05T10:00:00Z";
  h.context.fetch = async () => { throw Error("offline-date-test"); };
  await h.run("window.AdminOperations.refresh()");
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /local-collection-/);
  h.node("#ledgerFrom").value = h.node("#ledgerTo").value;
  await h.run("window.AdminOperations.refresh()");
  assert.match(h.node("#operationsState").textContent, /开始时间/);
});

test("旧账务查询与旧CSV在切换后不覆盖页面，也不下载迟到文件", async () => {
  const h = fixture();
  await authenticated(h);
  const reads = online(h);
  let finishCSV;
  h.context.fetch = async url => url.includes("export.csv") ? new Promise(resolve => { finishCSV = resolve; }) : reads(url);
  const exporting = h.fire("#ledgerExport", "click");
  h.run('saveAPIEnvironment("test", "http://localhost:9090"); window.AdminOperations.reset()');
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /server-journal/);
  finishCSV(response(new Blob(["old-ledger"], { type: "text/csv" })));
  await exporting;
  assert.equal(h.downloads.length, 0);
  assert.equal(h.objectURLs.length, 0);
  let finishRows, finishSummary;
  h.context.fetch = async url => {
    if (url.includes("/ledger/journals")) return new Promise(resolve => { finishRows = resolve; });
    if (url.includes("/ledger/summary")) return new Promise(resolve => { finishSummary = resolve; });
    return reads(url);
  };
  const pending = h.run("window.AdminOperations.refresh()");
  h.run('saveAPIEnvironment("test", "http://localhost:9191"); window.AdminOperations.reset()');
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /server-journal/);
  finishRows(response([journal("old-environment-journal")]));
  finishSummary(response(summary()));
  await pending;
  assert.doesNotMatch(h.node("#ledgerBody").innerHTML, /old-environment-journal/);
});

test("私有图片关闭后忽略迟到响应；CSV正文超时不创建下载", async () => {
  const h = fixture({ timeout: 25 });
  await authenticated(h);
  const reads = online(h);
  let finishAsset;
  h.context.fetch = async url => url.includes("/worker-assets/") ? new Promise(resolve => { finishAsset = resolve; }) : reads(url);
  h.clickOperation("asset", "private-asset");
  await h.fire("#assetClose", "click");
  finishAsset(response(new Blob(["image"], { type: "image/png" })));
  await flush();
  assert.equal(h.node("#assetImage").hidden, true);
  assert.equal(h.objectURLs.length, 0);
  h.context.fetch = async url => url.includes("export.csv") ? { ...response(null), blob: () => new Promise(() => {}) } : reads(url);
  const started = Date.now();
  await h.fire("#ledgerExport", "click");
  assert.ok(Date.now() - started < 500);
  assert.equal(h.downloads.length, 0);
  assert.match(h.node("#operationsState").textContent, /导出未完成.*超时.*未冒充服务端账本/);
});


test("后台先展示登录入口；普通账号没有身份审核和账号管理，注册页仅说明管理员开户", async () => {
  const h = fixture(); await flush();
  assert.equal(h.node("#adminWorkspace").hidden, true);
  assert.equal(h.node("#authGate").hidden, false);
  await h.fire("#tabRegister", "click");
  assert.equal(h.node("#adminRegister").hidden, false);
  assert.equal(h.node("#adminLogin").hidden, true);
  h.run("AdminSession.set(" + JSON.stringify({ ...auth(), user: { ...auth().user, role: "operator" } }) + ")");
  assert.equal(h.node("#authGate").hidden, true);
  assert.equal(h.node("#adminWorkspace").hidden, false);
  assert.equal(h.node("#identityReviewPanel").hidden, true);
  assert.equal(h.node("#administratorManagement").hidden, true);
  await h.fire("#navSettings", "click");
  assert.equal(h.node("#workspaceSettings").hidden, false);
  assert.equal(h.node("#workspaceBusiness").hidden, true);
  h.run("AdminSession.clear()");
  assert.equal(h.node("#adminWorkspace").hidden, true);
  assert.equal(h.node("#authGate").hidden, false);
});

test("恢复密码失败不模拟成功；成功要求重新登录，新增账号失败不构造本地账号", async () => {
  const h = fixture(); await flush();
  await h.fire("#tabForgot", "click");
  h.node("#forgotUsername").value = "operator-one";
  h.node("#forgotCode").value = "a".repeat(43);
  h.node("#forgotPassword").value = "password-long-123";
  h.node("#forgotConfirm").value = "password-long-123";
  h.context.fetch = async () => response({ message: "恢复码无效" }, { status: 401 });
  await h.fire("#adminForgot", "submit");
  assert.match(h.node("#authFeedback").textContent, /恢复码无效/);
  assert.equal(h.run("AdminSession.current()"), null);
  assert.equal(h.node("#forgotPassword").value, "");
  h.node("#forgotPassword").value = "password-long-123";
  h.node("#forgotConfirm").value = "password-long-123";
  h.node("#forgotCode").value = "a".repeat(43);
  h.context.fetch = async () => response(null, { status: 204 });
  await h.fire("#adminForgot", "submit");
  assert.match(h.node("#authFeedback").textContent, /密码已重置/);
  assert.equal(h.node("#adminLogin").hidden, false);
  assert.equal(h.run("AdminSession.current()"), null);
  await authenticated(h);
  h.node("#newAdminUsername").value = "operator-one";
  h.node("#newAdminName").value = "普通账号";
  h.node("#newAdminPassword").value = "password-long-123";
  h.node("#newAdminRole").value = "operator";
  h.context.fetch = async () => response({ message: "账号已存在" }, { status: 409 });
  await h.fire("#addAdministrator", "submit");
  assert.match(h.node("#accountsFeedback").textContent, /未创建本地账号/);
  assert.equal(h.node("#newAdminPassword").value, "");
});
