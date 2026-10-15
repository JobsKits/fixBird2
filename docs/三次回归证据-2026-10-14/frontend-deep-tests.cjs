/* Jobs · 使用实际 app.js 和可控 HTTP 响应回归交互边界。 */
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");
const D = require("/Users/jobs/Desktop/啄木鸟维修平台-V3.8/Workspace/data.js");
const source = fs.readFileSync("/Users/jobs/Desktop/啄木鸟维修平台-V3.8/Workspace/app.js", "utf8");
const flush = async () => {
  for (let i = 0; i < 4; i++) await new Promise(setImmediate);
};
const response = (value, status = 200) => ({
  ok: status < 400,
  status,
  json: async () => structuredClone(value),
});
function fixture() {
  const seed = D.seed();
  const orders = seed.orders.map((order) => ({
    ...order,
    allowedActions: D.permissions.admin,
  }));
  const actor = {
    id: "admin",
    role: "admin",
    name: "合成管理员",
    status: "active",
    authVersion: 1,
  };
  return {
    actor,
    orders,
    parts: seed.parts,
    loans: seed.loans,
    purchases: seed.purchases,
    settings: {
      companyAddress: "合成地址",
      companyReceiver: "样例",
      companyPhone: "测试电话",
      reminderHours: 24,
      remarkLimit: 2000,
    },
    orderPage: { page: 1, pageSize: 30, total: 95, totalPages: 4 },
    metrics: {
      openCount: 89,
      settlingCount: 51,
      remainingCents: 99000000,
      readyCount: 15,
      tasksCount: 135,
      blockedCount: 12,
    },
    capacity: { requestCount: 9001, warning: true, threshold: 10000 },
  };
}
function harness({ url = "http://127.0.0.1:8098/", saved = {}, fetcher } = {}) {
  const nodes = new Map(),
    listeners = new Map(),
    storage = new Map(Object.entries(saved)),
    calls = [];
  let activeFetch =
    fetcher || (async () => response({ message: "未认证" }, 401));
  const controlledFetch = async (url, options) => {
    calls.push({ url, options });
    return activeFetch(url, options);
  };
  function node(key) {
    if (!nodes.has(key)) {
      const events = new Map();
      const el = {
        id: key.replace(/^#/, ""),
        value: "",
        hidden: false,
        disabled: false,
        open: false,
        textContent: "",
        innerHTML: "",
        dataset: {},
        classList: { toggle() {} },
        emit(type) { events.get(type)?.(); },
        addEventListener(type, fn) {
          events.set(type, fn);
        },
        insertAdjacentHTML(_where, value) {
          this.innerHTML += value;
        },
        showModal() {
          this.open = true;
        },
        close() {
          this.open = false;
          events.get("close")?.();
        },
        reset() {
          [
            "#search",
            "#statusFilter",
            "#documentFilter",
            "#paymentFilter",
          ].forEach((name) => (node(name).value = ""));
        },
      };
      nodes.set(key, el);
    }
    return nodes.get(key);
  }
  const context = vm.createContext({
    URL,
    URLSearchParams,
    Intl,
    Date,
    Blob,
    structuredClone,
    AbortController,
    AbortSignal,
    WorkbenchData: D,
    location: new URL(url),
    setTimeout(fn, duration) {
      const timer = setTimeout(fn, duration);
      timer.unref();
      return timer;
    },
    clearTimeout,
    FormData: class {
      constructor(form) {
        this.values = new Map(Object.entries(form.fields || {}));
      }
      get(name) {
        return this.values.get(name);
      }
      entries() {
        return this.values.entries();
      }
    },
    localStorage: {
      getItem(name) {
        return storage.get(name) || null;
      },
      setItem(name, value) {
        storage.set(name, value);
      },
    },
    document: {
      querySelector: node,
      querySelectorAll: () => [],
      addEventListener(type, fn) {
        listeners.set(type, fn);
      },
      createElement: () => ({ click() {} }),
    },
    fetch: controlledFetch,
  });
  Object.defineProperty(context, "fetch", {
    get: () => controlledFetch,
    set: (value) => {
      activeFetch = value;
    },
  });
  const instrumented = source.replace(
    /\n\}\)\(\);\s*$/,
    `\n globalThis.__app = { request, mutateOrder, previewFile, showSignature, login, refresh, loadOrders, openDetail, showAction, accountStatusForm, createForm, globalForm, openDemo, normalizeBase, getState: () => ({data, actor, dataKind, connected, page, token, view}), setPage: (value) => {page = value;} };\n})();`,
  );
  assert.notEqual(instrumented, source);
  vm.runInContext(instrumented, context);
  const click = async (dataset = {}, id = "") => {
    const button = {
      dataset,
      id,
      hasAttribute: (name) =>
        name === "data-reload" && dataset.reload !== undefined,
    };
    button.closest = () => button;
    await listeners.get("click")({ target: button });
    await flush();
  };
  const submit = async (id, fields) => {
    const target = node("#" + id);
    target.fields = fields;
    const event = { target, currentTarget: target, preventDefault() {} };
    if (id === "actionForm") await target.onsubmit(event);
    else await listeners.get("submit")(event);
    await flush();
  };
  return {
    context,
    app: context.__app,
    nodes,
    node,
    calls,
    storage,
    click,
    submit,
  };
}
function reads(value = fixture(), override = {}) {
  return async (url) => {
    const path = url.split("/api/v38")[1];
    if (path === "/login")
      return response({ token: "synthetic-test-token", actor: value.actor });
    if (path === "/bootstrap") return response(value);
    if (path?.startsWith("/orders?")) {
      const query = new URLSearchParams(path.split("?")[1]);
      return response({
        items: value.orders,
        ...value.orderPage,
        page: Number(query.get("page")),
        ...override,
      });
    }
    if (path === "/accounts") return response([value.actor]);
    if (/^\/orders\/[^/]+$/.test(path))
      return response(
        value.orders.find(
          (order) => order.id === decodeURIComponent(path.split("/")[2]),
        ),
      );
    if (url.endsWith("/securityz"))
      return response({ configured: false, storage: "file" });
    return response({ message: "拒绝" }, 403);
  };
}
async function connected() {
  const h = harness();
  await flush();
  h.context.fetch = reads();
  await h.app.login("admin", "synthetic");
  await flush();
  assert.equal(h.app.getState().dataKind, "server");
  return h;
}


function canvasFor(h) {
  const canvas = h.node("#signatureCanvas");
  canvas.width = 900; canvas.height = 260;
  canvas.getContext = () => ({ beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, clearRect() {}, fillText() {} });
  canvas.getBoundingClientRect = () => ({ left: 0, top: 0, width: 900, height: 260 });
  canvas.setPointerCapture = () => {};
  canvas.toDataURL = () => "data:image/png;base64,c3ludGhldGlj";
  return canvas;
}
function draw(canvas) {
  canvas.onpointerdown({ clientX: 2, clientY: 3, pointerId: 1 });
  canvas.onpointermove({ clientX: 30, clientY: 40, pointerId: 1 }); canvas.onpointerup();
}
async function connectedAs(role) {
  const h = harness(); await flush(); const live = fixture();
  live.actor = { ...live.actor, id: role, role, companyId: "company-a" };
  if (role === "customer") live.orders = [live.orders[0]];
  h.context.fetch = reads(live); await h.app.login(role, "synthetic");
  return { h, live };
}

test("T01 [正常保护] 连续刷新＋后一次保存＋两次列表切换只保留最新metadata和分页", async () => {
  const h = await connected(), live = fixture(), boots = [];
  const latest = { ...live.orders[0], id: "newest-filter", number: "NEWEST-FILTER" };
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) { live.settings = JSON.parse(options.body); live.metrics.openCount = 111; return response(live.settings); }
    if (url.endsWith("/bootstrap")) {
      const snapshot = structuredClone(live);
      return new Promise((resolve) => boots.push(() => resolve(response(snapshot))));
    }
    return reads(live, { items: [latest], total: 1, totalPages: 1 })(url, options);
  };
  const first = h.app.refresh(); await flush();
  const saved = h.submit("companyForm", { companyAddress: "后一次配置", companyReceiver: "合成", companyPhone: "合成", reminderHours: "24" });
  await flush(); await h.click({ view: "finance" });
  boots[0](); await flush(); assert.equal(boots.length, 2);
  await h.click({ view: "orders" }); h.node("#search").value = "NEWEST"; h.node("#search").oninput(); await flush();
  boots[1](); await Promise.all([first, saved]);
  assert.equal(h.app.getState().data.settings.companyAddress, "后一次配置");
  assert.equal(h.app.getState().data.metrics.openCount, 111);
  assert.equal(h.app.getState().data.orders[0].id, "newest-filter");
  assert.equal(boots.length, 2, "没有无界补读");
});

test("T02 [安全拒绝] 更新分页401后，之前已授权的迟到bootstrap不能复活身份或旧资料", async () => {
  const h = await connected(); let finish;
  h.context.fetch = (url) => url.endsWith("/bootstrap")
    ? new Promise((resolve) => { finish = () => resolve(response(fixture())); })
    : Promise.resolve(response({ message: "当前会话已撤销" }, 401));
  const refreshing = h.app.refresh(); await flush();
  await h.app.loadOrders({ reset: true });
  assert.equal(h.app.getState().dataKind, "demo"); assert.equal(h.app.getState().token, "");
  finish(); await refreshing;
  assert.equal(h.app.getState().dataKind, "demo"); assert.equal(h.app.getState().token, "");
  assert.equal(h.app.getState().actor.authVersion, undefined);
  assert.match(h.app.getState().actor.displayName, /演示/);
});

test("T03 [安全拒绝] 反序metadata的授权版本/角色/企业不匹配时不并入当前分页", async () => {
  for (const changed of [{ authVersion: 2 }, { role: "customer" }, { companyId: "other-company" }]) {
    const h = await connected(), wrong = fixture(); wrong.actor = { ...wrong.actor, ...changed }; let finish;
    h.context.fetch = (url, options) => url.endsWith("/bootstrap")
      ? new Promise((resolve) => { finish = () => resolve(response(wrong)); }) : reads()(url, options);
    const refreshing = h.app.refresh(); await flush();
    await h.app.loadOrders(); finish(); await refreshing;
    assert.equal(h.app.getState().actor.role, "admin");
    assert.equal(h.app.getState().data.actor.authVersion, 1);
    assert.notEqual(h.app.getState().data.actor.companyId, "other-company");
  }
});

test("T04 [正常保护] 刷新队列等待期间换身份，新会话结束后旧job不覆盖新状态", async () => {
  const h = await connected(); let finishOld;
  h.context.fetch = () => new Promise((resolve) => { finishOld = () => resolve(response(fixture())); });
  const old = h.app.refresh(); const queued = h.app.refresh(); await flush();
  h.app.openDemo("finance");
  const live = fixture(); live.actor = { ...live.actor, id: "finance", role: "finance" };
  h.context.fetch = reads(live); await h.app.login("finance", "synthetic");
  finishOld(); await Promise.all([old, queued]);
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().actor.id, "finance");
  assert.equal(h.app.getState().data.actor.id, "finance");
});

test("R3-F01/T05 [保护预期] 新客户登录到分页完成及迟到bootstrap全过程不显示旧管理员资料", async () => {
  const h = harness(); await flush(); const admin = fixture();
  admin.orders[0].number = "ADMIN-PRIVATE-COMPANY-B";
  admin.orders[0].customerId = "customer-b"; admin.orders[0].companyId = "company-b";
  h.context.fetch = reads(admin); await h.app.login("admin", "synthetic"); await h.click({ view: "settings" });
  const customer = fixture();
  customer.actor = { ...customer.actor, id: "customer", role: "customer", companyId: "company-a" };
  customer.orders = [{ ...customer.orders[0], number: "CUSTOMER-A-ONLY", customerId: "customer", companyId: "company-a" }];
  customer.metrics.remainingCents = 123;
  let finishBootstrap, finishCustomerPage; const stages = [];
  const record = (stage) => { const state = h.app.getState(); const list = state.view === "finance" ? h.node("#financeView").innerHTML : state.view === "orders" ? h.node("#ordersBody").innerHTML : "";
    const item = { stage, actor: state.actor.id, actorRole: state.actor.role, snapshotActor: state.data.actor.id, snapshotRole: state.data.actor.role, view: state.view, oldCrossCompanyCached: state.data.orders.some(o => o.number === "ADMIN-PRIVATE-COMPANY-B"), oldCrossCompanyVisible: list.includes("ADMIN-PRIVATE-COMPANY-B"), remainingCents: state.data.metrics?.remainingCents, dataKind: state.dataKind }; stages.push(item); console.log("R3-F01_STAGE", JSON.stringify(item)); };
  h.context.fetch = async (url) => {
    if (url.endsWith("/login")) return response({ token: "synthetic-customer-token", actor: customer.actor });
    if (url.endsWith("/bootstrap")) return new Promise((resolve) => { finishBootstrap = () => resolve(response(customer)); });
    if (url.includes("/orders?")) return new Promise((resolve) => { finishCustomerPage = () => resolve(response({ items: customer.orders, ...customer.orderPage })); });
    return response({ message: "当前角色拒绝" }, 403);
  };
  const login = h.app.login("customer", "synthetic"); await flush(); record("login_success_bootstrap_pending");
  await h.click({ view: "finance" }); record("finance_navigation_new_page_pending");
  finishCustomerPage(); await flush(); record("customer_page_arrived_before_bootstrap");
  finishBootstrap(); await login; record("new_customer_bootstrap_arrived_final");
  assert.equal(stages.some(stage => stage.oldCrossCompanyVisible), false, "新客户身份下不可显示上一管理员的跨企业列表");
  assert.equal(h.app.getState().data.actor.id, "customer");
  assert.equal(h.app.getState().data.metrics.remainingCents, 123);
});

test("T06 [正常保护] 客户签名保存迟到，不关闭随后打开的新建工单表单", async () => {
  const { h, live } = await connectedAs("customer"); const canvas = canvasFor(h);
  h.app.showSignature("sign_quote", live.orders[0]); draw(canvas); let finish;
  h.context.fetch = (url, options) => url.endsWith("/actions")
    ? new Promise((resolve) => { finish = () => resolve(response({ ...live.orders[0], version: 2 })); }) : reads(live)(url, options);
  const signed = h.submit("actionForm", { agreed: "on" }); await flush();
  h.node("#formDialog").close(); h.app.createForm(); finish(); await signed;
  assert.equal(h.node("#formDialog").open, true); assert.match(h.node("#formContent").innerHTML, /新建维修/);
});

test("T07 [安全拒绝] 同身份关闭附件表单并开新表单后，迟到FileReader不发原写请求", async () => {
  const h = await connected(); let reader;
  h.context.FileReader = class { constructor() { reader = this; } readAsDataURL() {} };
  await h.app.showAction("evidence", fixture().orders[0].id);
  const submitted = h.submit("actionForm", { name: "合成媒体", kind: "image", stage: "settling", file: { size: 12, type: "image/png" } });
  const before = h.calls.filter((call) => call.url.endsWith("/actions")).length;
  h.node("#formDialog").close(); h.app.createForm();
  reader.result = "data:image/png;base64,c3ludGhldGlj"; reader.onload(); await submitted;
  assert.equal(h.calls.filter((call) => call.url.endsWith("/actions")).length, before);
  assert.equal(h.node("#formDialog").open, true);
});

test("T08 [正常保护] 浏览器旧close事件排队后新表单已打开，不使新实例失效", async () => {
  const h = await connected(), dialog = h.node("#formDialog");
  const delayed = [];
  dialog.close = function () { this.open = false; delayed.push(() => this.emit("close")); };
  h.app.accountStatusForm("customer", "disabled");
  h.context.fetch = async () => response({ id: "customer", role: "customer", status: "disabled", authVersion: 2 });
  await h.submit("actionForm", { reason: "合成依据" });
  h.app.createForm(); delayed.shift()();
  h.context.fetch = async () => response({ message: "新工单内容需补齐" }, 422);
  const before = h.calls.filter((call) => call.url === "/api/v38/orders").length;
  await h.submit("actionForm", { type: "mail", customerId: "customer", customer: "合成", device: "合成", description: "合成", prepayChoice: "none" });
  assert.equal(h.calls.filter((call) => call.url === "/api/v38/orders").length, before + 1, "新表单确实执行自身请求，而非被旧事件票据拒绝");
  assert.equal(dialog.open, true); assert.match(h.node("#formError").textContent, /新工单内容需补齐/);
});

test("T09 [安全拒绝] 手写签名未知/空成功响应不关闭表单且不进入合成事实", async () => {
  for (const mode of ["unavailable", "null"]) {
    const { h, live } = await connectedAs("customer"); const canvas = canvasFor(h);
    h.app.showSignature("sign_quote", live.orders[0]); draw(canvas);
    const before = JSON.stringify(h.app.getState().data.orders);
    h.context.fetch = async () => { if (mode === "unavailable") throw Error("unknown"); return response(null); };
    await h.submit("actionForm", { agreed: "on" });
    assert.equal(h.node("#formDialog").open, true);
    assert.equal(h.app.getState().dataKind, "server");
    assert.equal(JSON.stringify(h.app.getState().data.orders), before);
  }
});

test("R3-F02/T10 [保护预期] 独立演示中QC只更新客户说明时，省略内部备注须保留原值", async () => {
  const h = harness(); await flush(); h.app.openDemo("qc");
  h.context.fetch = async () => { throw Error("offline"); };
  const order = h.app.getState().data.orders[0], original = order.remark;
  await h.click({ open: order.id });
  assert.match(h.node("#detailContent").innerHTML, /data-action="remark"/);
  await h.click({ action: "remark", order: order.id });
  assert.doesNotMatch(h.node("#formContent").innerHTML, /name="remark"/);
  await h.submit("actionForm", { customerNote: "合成客户说明更新" });
  const changed = h.app.getState().data.orders.find((item) => item.id === order.id);
  const actionRequest = h.calls.findLast(call => call.url.endsWith("/actions"));
  const sentPayload = JSON.parse(actionRequest.options.body).payload;
  assert.deepEqual(Object.keys(sentPayload), ["customerNote"]);
  console.log("R3-F02_UI_PAYLOAD", JSON.stringify(sentPayload));
  console.log("OBSERVED T10", JSON.stringify({ dataKind: h.app.getState().dataKind, originalRemarkPresent: !!original, updatedRemarkPresent: typeof changed.remark === "string", noteUpdated: changed.customerNote === "合成客户说明更新" }));
  assert.equal(changed.remark, original, "合成演示也不应以缺省字段抹掉内部备注");
});
