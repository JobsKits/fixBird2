const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.resolve(__dirname, "..");
const sources = ["environment.js", "marketplace-data.js", "admin.js"]
  .map(file => fs.readFileSync(path.join(root, file), "utf8"));
const flush = () => new Promise(setImmediate);

function harness({ url = "http://127.0.0.1:8081/admin/", saved = {}, storageBlocked = false } = {}) {
  const nodes = new Map();
  const node = key => {
    if (!nodes.has(key)) nodes.set(key, {
      value: "", disabled: false, hidden: false, textContent: "", innerHTML: "", addEventListener() {}
    });
    return nodes.get(key);
  };
  const storage = new Map(Object.entries(saved));
  const context = vm.createContext({
    URL, structuredClone, AbortController, Image: class {}, navigator: {},
    localStorage: {
      getItem(key) { if (storageBlocked) throw Error("blocked"); return storage.get(key) || null; },
      setItem(key, value) { if (storageBlocked) throw Error("blocked"); storage.set(key, value); }
    },
    location: new URL(url),
    document: { querySelector: node, querySelectorAll: () => [], addEventListener() {} },
    window: { setTimeout, clearTimeout, confirm: () => true },
    fetch: async () => { throw Error("offline"); }
  });
  sources.forEach((source, index) => vm.runInContext(index === 0
    ? source.replace("const API_REQUEST_TIMEOUT_MS = 2000;", "const API_REQUEST_TIMEOUT_MS = 25;")
    : source, context));
  return { context, nodes, run: code => vm.runInContext(code, context) };
}

function successfulReads(h, override = {}) {
  const data = {
    dashboard: h.run("demoDashboard()"),
    orders: structuredClone(h.run("DEMO_SEED.orders")),
    workers: structuredClone(h.run("DEMO_SEED.workers")),
    settlements: [],
    ...override
  };
  return async url => ({ ok: true, status: 200, json: async () => structuredClone(data[url.split("/").pop()]) });
}

test("同源后台复用实际端口；静态预览、有效覆盖和无效存储各自有明确默认值", async () => {
  for (const url of ["http://127.0.0.1:8081/admin/", "https://demo.example:9443/admin/index.html"]) {
    const h = harness({ url });
    assert.equal(h.run("activeAPIBase()"), new URL(url).origin);
    await flush();
  }
  const preview = harness({ url: "file:///tmp/index.html", storageBlocked: true });
  assert.equal(preview.run("activeAPIBase()"), "http://127.0.0.1:8080");
  assert.doesNotThrow(() => preview.run('saveAPIEnvironment("test", "http://localhost:9000")'));
  const saved = harness({ saved: { repairTestApiBase: "http://localhost:9090" } });
  assert.equal(saved.run("activeAPIBase()"), "http://localhost:9090");
  const invalid = harness({ saved: { repairTestApiBase: "javascript:bad" } });
  assert.equal(invalid.run("activeAPIBase()"), "http://127.0.0.1:8081");
  assert.throws(() => invalid.run('saveAPIEnvironment("bad", "http://localhost")'), /未知/);
  await flush();
});

test("超时覆盖 headers 之后一直不结束的 JSON 正文", async () => {
  const h = harness();
  await flush();
  h.context.fetch = async () => ({ ok: true, status: 200, json: () => new Promise(() => {}) });
  const began = Date.now();
  await assert.rejects(h.run('request("/stalled-body")'), error => error.kind === "unknown" && /超时/.test(error.message));
  assert.ok(Date.now() - began < 500, "正文超时应及时结束");
});

test("HTTP 200 null、字段错误和坏 JSON 各模块回退；真实空数组保留为空", async () => {
  const h = harness();
  await flush();
  h.context.fetch = successfulReads(h, { dashboard: null, orders: [{ id: "bad" }], workers: null });
  await h.run("refresh()");
  assert.equal(h.run("displayedData.orders.isOnline"), false);
  assert.equal(h.run("displayedData.orders.data.length"), 2);
  assert.equal(h.run("displayedData.settlements.isOnline"), true);
  assert.match(h.nodes.get("#ordersSource").textContent, /结构/);
  h.context.fetch = async () => ({ ok: true, status: 200, json: async () => { throw Error("invalid JSON"); } });
  await h.run("refresh()");
  assert.match(h.nodes.get("#workersSource").textContent, /无法解析/);
  h.context.fetch = successfulReads(h, { orders: [], workers: [], settlements: [] });
  await h.run("refresh()");
  assert.equal(h.run("displayedData.orders.isOnline"), true);
  assert.match(h.nodes.get("#ordersBody").innerHTML, /暂时没有订单/);
  assert.doesNotMatch(h.nodes.get("#ordersBody").innerHTML, /demo-refrigerator/);
});

test("离线收款生成台账，10分舍入与后端一致；重收款不重复、不撤销核销", async () => {
  const h = harness();
  await flush();
  h.run('DEMO_DATA.orders[1].quotedAmountCents = 10; updateDemoState("demo-collect", "demo-water-heater-002")');
  assert.equal(h.run("DEMO_DATA.settlements.length"), 1);
  assert.equal(h.run("DEMO_DATA.settlements[0].workerShareCents"), 9);
  assert.equal(h.run("DEMO_DATA.settlements[0].platformFeeCents"), 1);
  h.run('MarketplaceData.applyDemoAction(DEMO_DATA, "manual-paid", DEMO_DATA.settlements[0].id)');
  h.run('MarketplaceData.applyDemoAction(DEMO_DATA, "demo-collect", "demo-water-heater-002")');
  assert.equal(h.run("DEMO_DATA.settlements.length"), 1);
  assert.equal(h.run("DEMO_DATA.settlements[0].status"), "manually_paid");
  for (const cents of [1, 5, 10, 11, 99, 101, 100000000]) {
    const result = h.run(`MarketplaceData.split(${cents})`);
    assert.equal(result.workerShareCents + result.platformFeeCents, cents);
  }
  for (const invalid of [0, -1, 0.1, 100000001, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => h.run(`MarketplaceData.split(${invalid})`), /报价/);
  }
});

test("409 拒绝有持久提示、独立demo ID；后续成功刷新不修改远端快照、不补发", async () => {
  const h = harness();
  await flush();
  const remote = structuredClone(h.run("DEMO_SEED.orders[1]"));
  remote.id = "real-order-1";
  h.context.fetch = successfulReads(h, { orders: [remote] });
  await h.run("refresh()");
  const snapshot = h.run("displayedData.orders.data[0]");
  let posts = 0;
  h.context.fetch = async () => {
    posts += 1;
    return { ok: false, status: 409, json: async () => ({ code: "state_conflict", error: "订单状态已变化" }) };
  };
  await h.run('performAction("demo-collect", "real-order-1")');
  assert.equal(snapshot.status, "awaiting_payment");
  assert.equal(h.run('DEMO_DATA.orders.find(item => item.id === "demo-copy-real-order-1").status'), "completed");
  assert.match(h.nodes.get("#actionState").textContent, /HTTP 409.*state_conflict/);
  assert.match(h.nodes.get("#actionState").textContent, /不代表服务端成功/);
  h.context.fetch = successfulReads(h, { orders: [remote] });
  await h.run("refresh()");
  assert.equal(posts, 1);
  assert.equal(h.run("displayedData.orders.data.length"), 1);
  assert.equal(h.run("displayedData.orders.data[0].status"), "awaiting_payment");
  assert.match(h.nodes.get("#actionState").textContent, /409/);
});

test("环境切换丢弃旧写请求结果，重复点击只发一次", async () => {
  const h = harness();
  await flush();
  let resolveWrite;
  let posts = 0;
  h.context.fetch = async () => {
    posts += 1;
    return new Promise(resolve => { resolveWrite = resolve; });
  };
  const pending = h.run('performAction("demo-collect", "demo-water-heater-002")');
  await h.run('performAction("demo-collect", "demo-water-heater-002")');
  assert.equal(posts, 1);
  h.run('saveAPIEnvironment("test", "http://localhost:9090")');
  resolveWrite({ ok: false, status: 409, json: async () => ({ error: "old" }) });
  await pending;
  assert.equal(h.run("DEMO_DATA.orders[1].status"), "awaiting_payment");
  assert.equal(h.nodes.get("#actionState").textContent, "");
});

test("分页按游标加载下一页，去重；失败分页明确切回本地演示", async () => {
  const h = harness();
  await flush();
  const first = structuredClone(h.run("DEMO_SEED.orders[0]"));
  const second = { ...first, id: "second-page" };
  const read = successfulReads(h, { orders: [first] });
  h.context.fetch = async url => {
    const response = await read(url);
    response.headers = { get: key => key === "X-Next-Cursor" && url.endsWith("/orders") ? "opaque-cursor" : "" };
    return response;
  };
  await h.run("refresh()");
  assert.equal(h.nodes.get("#ordersMore").hidden, false);
  let requestedURL;
  h.context.fetch = async url => {
    requestedURL = url;
    return { ok: true, status: 200, headers: { get: () => "" }, json: async () => [first, second] };
  };
  await h.run('loadMore("orders", document.querySelector("#ordersMore"))');
  assert.match(requestedURL, /cursor=opaque-cursor$/);
  assert.equal(h.run("displayedData.orders.data.length"), 2);
  assert.equal(h.nodes.get("#ordersMore").hidden, true);
  h.run('displayedData.orders.nextCursor = "next"');
  h.context.fetch = async () => { throw Error("offline-next-page"); };
  await h.run('loadMore("orders", document.querySelector("#ordersMore"))');
  assert.equal(h.run("displayedData.orders.isOnline"), false);
  assert.match(h.nodes.get("#ordersSource").textContent, /offline-next-page/);
});

test("核销合法204确认成功，HTTP200 null仍视为未知坏响应", async () => {
  const h = harness();
  await flush();
  h.run('updateDemoState("demo-collect", "demo-water-heater-002"); renderDemoPreview()');
  const read = successfulReads(h);
  h.context.fetch = async (url, options) => options.method === "POST"
    ? { ok: true, status: 204, json: async () => { throw Error("204 must not read JSON"); } }
    : read(url);
  await h.run('performAction("manual-paid", DEMO_DATA.settlements[0].id)');
  assert.match(h.nodes.get("#actionState").textContent, /服务端已确认操作完成/);
  h.context.fetch = async () => ({ ok: true, status: 200, json: async () => null });
  h.run("renderDemoPreview()");
  await h.run('performAction("manual-paid", DEMO_DATA.settlements[0].id)');
  assert.match(h.nodes.get("#actionState").textContent, /处理结果尚未确认/);
});
