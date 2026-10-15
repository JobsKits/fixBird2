/* Jobs · 使用实际 app.js 和可控 HTTP 响应回归交互边界。 */
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");
const D = require("../data.js");
const source = fs.readFileSync(path.join(__dirname, "../app.js"), "utf8");
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
        emit(type) {
          events.get(type)?.();
        },
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
    `\n globalThis.__app = { request, mutateOrder, previewFile, showSignature, login, refresh, loadOrders, openDetail, showAction, accountStatusForm, createForm, globalForm, openDemo, normalizeBase, getDemo: () => demo, available, getState: () => ({data, actor, dataKind, connected, page, token, view, cachedDetailIds: [...details.keys()]}), setPage: (value) => {page = value;} };\n})();`,
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

test("账号状态的 null、空对象、错误账号/状态/版本和坏 JSON 均保留表单，不提示成功", async () => {
  const h = await connected();
  for (const value of [
    null,
    {},
    { id: "other", role: "customer", status: "disabled", authVersion: 2 },
    { id: "customer", role: "customer", status: "active", authVersion: 2 },
    { id: "customer", role: "customer", status: "disabled", authVersion: 0 },
  ]) {
    h.context.fetch = async () => response(value);
    h.app.accountStatusForm("customer", "disabled");
    await h.submit("actionForm", { reason: "合成回归依据" });
    assert.equal(h.node("#formDialog").open, true);
    assert.equal(h.node("#formError").hidden, false);
    assert.match(h.node("#formError").textContent, /响应格式/);
    assert.doesNotMatch(h.node("#toast").textContent, /账号状态已更新/);
    assert.equal(h.app.getState().dataKind, "server");
  }
  h.context.fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => {
      throw Error("bad JSON");
    },
  });
  h.app.accountStatusForm("customer", "disabled");
  await h.submit("actionForm", { reason: "合成回归依据" });
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formError").textContent, /无法解析/);
});

test("账号状态成功响应完成表单，403 与未知写保持原身份和表单", async () => {
  const h = await connected();
  h.context.fetch = async () =>
    response({
      id: "customer",
      role: "customer",
      status: "disabled",
      authVersion: 2,
    });
  h.app.accountStatusForm("customer", "disabled");
  await h.submit("actionForm", { reason: "合成回归依据" });
  assert.equal(h.node("#formDialog").open, false);
  assert.match(h.node("#toast").textContent, /账号状态已更新/);
  for (const fetcher of [
    async () => response({ message: "不允许" }, 403),
    async () => {
      throw Error("network");
    },
  ]) {
    h.context.fetch = fetcher;
    h.app.accountStatusForm("customer", "disabled");
    await h.submit("actionForm", { reason: "合成回归依据" });
    assert.equal(h.node("#formDialog").open, true);
    assert.equal(h.app.getState().dataKind, "server");
  }
});

test("服务器分页查询重置页码，指标使用全部授权范围，工单/待办/财务都有分页入口", async () => {
  const h = await connected();
  assert.equal(h.node("#navCount").textContent, 89);
  assert.equal(h.node("#taskCount").textContent, 135);
  assert.equal(h.node("#blockedCount").textContent, 12);
  assert.equal(h.node("#orderCount").textContent, 95);
  assert.match(h.node("#metrics").innerHTML, /990,000\.00/);
  for (const selector of ["#orderPagination", "#tasksView", "#financeView"])
    assert.match(h.node(selector).innerHTML, /data-page="next"/);
  assert.equal(h.node("#capacityNote").hidden, false);
  await h.click({ page: "next" });
  assert.equal(h.app.getState().page, 2);
  h.node("#search").value = "合成设备";
  h.node("#search").oninput();
  await flush();
  assert.equal(h.app.getState().page, 1);
  const last = h.calls.at(-1).url;
  assert.match(last, /page=1&/);
  assert.match(decodeURIComponent(last), /q=合成设备/);
  await h.click({ quick: "blocked" });
  assert.match(h.calls.at(-1).url, /filter=blocked/);
});

test("较早的筛选/切页结果和失败不能覆盖最新列表", async () => {
  const h = await connected(),
    pending = [];
  h.context.fetch = (_url) =>
    new Promise((resolve, reject) => pending.push({ resolve, reject }));
  h.node("#search").value = "旧";
  h.node("#search").oninput();
  h.node("#search").value = "新";
  h.node("#search").oninput();
  const order = { ...fixture().orders[0], id: "newest", number: "NEWEST" };
  pending[1].resolve(
    response({
      items: [order],
      page: 1,
      pageSize: 30,
      total: 1,
      totalPages: 1,
    }),
  );
  await flush();
  pending[0].reject(Error("stale failure"));
  await flush();
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().data.orders[0].id, "newest");
  assert.match(h.node("#ordersBody").innerHTML, /NEWEST/);
});

test("有效空页有重载入口；当前筛选失败回到独立演示，不带入真实列表", async () => {
  const h = await connected();
  h.context.fetch = reads(fixture(), { items: [], total: 0, totalPages: 0 });
  await h.app.loadOrders();
  assert.equal(h.node("#ordersEmpty").hidden, false);
  assert.match(h.node("#ordersEmpty").innerHTML, /data-reload/);
  h.context.fetch = async () => response(null);
  await h.app.loadOrders();
  assert.equal(h.app.getState().dataKind, "demo");
  assert.match(h.node("#connectionNote").textContent, /独立合成演示/);
  assert.notEqual(h.app.getState().actor.id, "admin-real-account");
});

test("摘要不会打开动作表单，必须先取得完整详情；迟到详情不替换新选择", async () => {
  const h = await connected(),
    pending = [];
  h.context.fetch = () => new Promise((resolve) => pending.push(resolve));
  const order = fixture().orders[0];
  const action = h.app.showAction("remark", order.id);
  assert.equal(h.node("#formDialog").open, false);
  pending[0](response(order));
  await action;
  assert.equal(h.node("#formDialog").open, true);
  h.node("#formDialog").close();
  const old = h.app.openDetail(order.id);
  const nextOrder = fixture().orders[1];
  const latest = h.app.openDetail(nextOrder.id);
  pending[2](response(nextOrder));
  await latest;
  pending[1](response(order));
  await old;
  assert.match(
    h.node("#detailContent").innerHTML,
    new RegExp(nextOrder.number),
  );
  assert.doesNotMatch(
    h.node("#detailContent").innerHTML,
    new RegExp(order.number),
  );
});

test("切换身份或环境后迟到写响应不会关闭新表单、提示成功或模拟旧写", async () => {
  const h = await connected();
  let resolve;
  h.context.fetch = () =>
    new Promise((finish) => {
      resolve = finish;
    });
  h.app.accountStatusForm("customer", "disabled");
  const submitted = h.submit("actionForm", { reason: "合成依据" });
  h.app.openDemo("dispatcher");
  h.app.createForm();
  resolve(
    response({
      id: "customer",
      role: "customer",
      status: "disabled",
      authVersion: 2,
    }),
  );
  await submitted;
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
  assert.doesNotMatch(h.node("#toast").textContent, /账号状态已更新/);
  assert.equal(h.app.getState().actor.id, "dispatcher");
});

test("连接设置拒绝跨源、路径与凭据，file 离线入口没有默认 8380 请求", async () => {
  const h = await connected(),
    before = h.calls.length;
  await h.submit("connectionForm", {
    base: "http://127.0.0.1:9090",
    timeout: "1000",
  });
  assert.match(h.node("#toast").textContent, /同源/);
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.calls.length, before);
  for (const base of [
    "http://127.0.0.1:8098/path",
    "http://user@127.0.0.1:8098",
    "https://127.0.0.1:8098",
    "http://127.0.0.1:8098?x=1",
  ])
    assert.throws(() => h.app.normalizeBase(base));
  assert.equal(
    h.app.normalizeBase("http://127.0.0.1:8098/"),
    "http://127.0.0.1:8098",
  );
  const offline = harness({
    url: "file:///tmp/index.html",
    saved: { repairV38Base: "http://127.0.0.1:8380" },
  });
  await flush();
  assert.equal(offline.calls.length, 0);
  assert.equal(offline.app.getState().dataKind, "demo");
  await offline.submit("connectionForm", {
    base: "http://127.0.0.1:8098",
    timeout: "1000",
  });
  assert.match(offline.node("#toast").textContent, /离线/);
  assert.equal(offline.calls.length, 0);
});

test("公司配置 A→B→A 是三个独立成功意图，未知保存保留原键且错误目标不报告成功", async () => {
  const h = await connected(),
    live = fixture();
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      live.settings = JSON.parse(options.body);
      return response(live.settings);
    }
    return reads(live)(url, options);
  };
  const fields = (address) => ({
    companyAddress: address,
    companyReceiver: "合成人员",
    companyPhone: "合成电话",
    reminderHours: "24",
  });
  for (const address of ["地址 A", "地址 B", "地址 A"])
    await h.submit("companyForm", fields(address));
  const successes = h.calls.filter((call) => call.url.endsWith("/settings"));
  assert.equal(successes.length, 3);
  assert.equal(
    new Set(successes.map((call) => call.options.headers["Idempotency-Key"]))
      .size,
    3,
  );
  assert.equal(live.settings.companyAddress, "地址 A");
  h.context.fetch = async () => {
    throw Error("unknown result");
  };
  await h.submit("companyForm", fields("地址 C"));
  await h.submit("companyForm", fields("地址 C"));
  const failures = h.calls
    .filter((call) => call.url.endsWith("/settings"))
    .slice(-2);
  assert.equal(
    failures[0].options.headers["Idempotency-Key"],
    failures[1].options.headers["Idempotency-Key"],
  );
  h.context.fetch = async () =>
    response({ ...live.settings, companyAddress: "错误目标" });
  await h.submit("companyForm", fields("地址 C"));
  assert.match(h.node("#toast").textContent, /响应格式不完整/);
});

test("管理员安全审计只展示必要元数据并独立分页，普通身份不请求审计", async () => {
  const h = await connected();
  h.context.fetch = async (url, options) => {
    if (url.includes("/audit?"))
      return response({
        items: [
          {
            id: "audit-1",
            actorId: "admin",
            actorRole: "admin",
            type: "account_status",
            resource: "account",
            resourceIds: ["customer"],
            result: "success",
            at: "2026-10-14T02:00:00Z",
            reason: "合成授权变更依据",
            before: { signature: "DO-NOT-SHOW" },
          },
        ],
        total: 61,
        page: Number(new URLSearchParams(url.split("?")[1]).get("page")),
        pageSize: 30,
      });
    return reads()(url, options);
  };
  await h.click({ view: "settings" });
  assert.match(h.node("#auditList").innerHTML, /合成授权变更依据/);
  assert.doesNotMatch(h.node("#auditList").innerHTML, /DO-NOT-SHOW/);
  await h.click({ auditPage: "next" });
  assert.match(h.calls.at(-1).url, /audit\?page=2/);
  h.app.openDemo("dispatcher");
  const before = h.calls.filter((call) => call.url.includes("/audit?")).length;
  await h.click({ view: "settings" });
  assert.equal(
    h.calls.filter((call) => call.url.includes("/audit?")).length,
    before,
  );
});

test("未取得完整详情或详情接口只返回摘要时，不从缺失记录打开办理表单", async () => {
  const h = await connected();
  h.context.fetch = async () =>
    response({ ...fixture().orders[0], isSummary: true });
  await h.app.showAction("documents", fixture().orders[0].id);
  assert.equal(h.node("#formDialog").open, false);
  assert.match(h.node("#toast").textContent, /返回工单摘要/);
});

test("较早登录与 bootstrap 迟到结果不能恢复已切换的身份或服务事实", async () => {
  const h = await connected();
  let resolve;
  h.context.fetch = () =>
    new Promise((finish) => {
      resolve = finish;
    });
  const refreshing = h.app.refresh();
  h.app.openDemo("warehouse");
  resolve(response(fixture()));
  await refreshing;
  assert.equal(h.app.getState().actor.role, "warehouse");
  assert.equal(h.app.getState().dataKind, "demo");
  let finishLogin;
  h.context.fetch = () =>
    new Promise((finish) => {
      finishLogin = finish;
    });
  const loggingIn = h.app.login("admin", "synthetic");
  h.app.openDemo("customer");
  finishLogin(response({ actor: fixture().actor, token: "synthetic-token" }));
  await loggingIn;
  assert.equal(h.app.getState().actor.role, "customer");
  assert.equal(h.app.getState().token, "");
});

test("待办和财务查询不继承隐藏的工单筛选，切换视图请求第一页；返回工单页保留其筛选", async () => {
  const h = await connected();
  h.node("#search").value = "只找特定工单";
  h.node("#statusFilter").value = "settling";
  h.node("#documentFilter").value = "required";
  h.node("#paymentFilter").value = "pending";
  await h.click({ quick: "blocked" });
  await h.click({ page: "next" });
  for (const view of ["tasks", "finance"]) {
    await h.click({ view });
    const query = new URLSearchParams(h.calls.at(-1).url.split("?")[1]);
    assert.equal(query.get("page"), "1");
    assert.equal(query.get("filter"), "all");
    for (const name of ["q", "status", "documents", "payment"])
      assert.equal(query.get(name), "");
    assert.equal(h.app.getState().page, 1);
    await h.click({ page: "next" });
    const next = new URLSearchParams(h.calls.at(-1).url.split("?")[1]);
    assert.equal(next.get("page"), "2");
    assert.equal(next.get("q"), "");
  }
  await h.click({ view: "orders" });
  const restored = new URLSearchParams(h.calls.at(-1).url.split("?")[1]);
  assert.equal(restored.get("page"), "1");
  assert.equal(restored.get("q"), "只找特定工单");
  assert.equal(restored.get("filter"), "blocked");
  assert.equal(restored.get("status"), "settling");
  assert.equal(restored.get("documents"), "required");
  assert.equal(restored.get("payment"), "pending");
  h.app.openDemo("dispatcher");
  await h.click({ view: "tasks" });
  assert.doesNotMatch(h.node("#tasksView").innerHTML, /暂无待办/);
  await h.click({ view: "finance" });
  assert.doesNotMatch(h.node("#financeView").innerHTML, /暂无现金记录/);
});

test("零总数返回 totalPages=0 时显示第一页且前后分页禁用，正总数却 totalPages=0 视为坏响应", async () => {
  const h = await connected();
  h.context.fetch = reads(fixture(), {
    items: [],
    page: 1,
    total: 0,
    totalPages: 0,
  });
  await h.app.loadOrders();
  assert.match(h.node("#orderPagination").innerHTML, /第 1 \/ 1 页/);
  assert.match(
    h.node("#orderPagination").innerHTML,
    /data-page="previous" disabled/,
  );
  assert.match(
    h.node("#orderPagination").innerHTML,
    /data-page="next" disabled/,
  );
  assert.equal(h.app.getState().page, 1);
  assert.equal(h.node("#ordersEmpty").hidden, false);
  h.context.fetch = reads(fixture(), {
    items: [],
    page: 1,
    total: 1,
    totalPages: 0,
  });
  await h.app.loadOrders();
  assert.equal(h.app.getState().dataKind, "demo");
  assert.match(h.node("#connectionNote").textContent, /响应格式不完整/);
});

test("F01: 旧账号表单提交迟到，应保留随后打开的新建工单表单", async () => {
  const h = await connected();
  let finish;
  h.context.fetch = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  h.app.accountStatusForm("customer", "disabled");
  const submitted = h.submit("actionForm", { reason: "合成授权依据" });
  h.node("#formDialog").close();
  h.app.createForm();
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
  finish(
    response({
      id: "customer",
      role: "customer",
      status: "disabled",
      authVersion: 2,
    }),
  );
  await submitted;
  assert.equal(
    h.node("#formDialog").open,
    true,
    "同一身份下，旧提交不应关闭新的工单表单",
  );
});

test("F02: 办理前的详情读取迟到，导航到财务后不应打开旧备注表单", async () => {
  const h = await connected();
  let finish;
  const delegate = reads();
  h.context.fetch = (url, options) =>
    /^\/api\/v38\/orders\/[^/?]+$/.test(url)
      ? new Promise((resolve) => {
          finish = resolve;
        })
      : delegate(url, options);
  const action = h.app.showAction("remark", fixture().orders[0].id);
  await h.click({ view: "finance" });
  assert.equal(h.node("#formDialog").open, false);
  finish(response(fixture().orders[0]));
  await action;
  assert.equal(
    h.node("#formDialog").open,
    false,
    "切换业务视图后，旧动作读取不应弹出原视图的表单",
  );
});

test("F03: 两次公司配置保存都成功后，较早刷新不得把新配置显示为旧配置", async () => {
  const h = await connected(),
    live = fixture();
  let finishFirstBootstrap;
  const fields = (address) => ({
    companyAddress: address,
    companyReceiver: "合成",
    companyPhone: "合成",
    reminderHours: "24",
  });
  let writes = 0;
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      writes++;
      live.settings = JSON.parse(options.body);
      return response(live.settings);
    }
    if (url.endsWith("/bootstrap") && writes === 1) {
      const first = structuredClone(live);
      return new Promise((resolve) => {
        finishFirstBootstrap = () => resolve(response(first));
      });
    }
    return reads(live)(url, options);
  };
  const first = h.submit("companyForm", fields("地址 A"));
  await flush();
  assert.equal(typeof finishFirstBootstrap, "function");
  const second = h.submit("companyForm", fields("地址 B"));
  await flush();
  assert.equal(live.settings.companyAddress, "地址 B");
  finishFirstBootstrap();
  await Promise.all([first, second]);
  assert.equal(
    h.app.getState().data.settings.companyAddress,
    "地址 B",
    "已确认后一次保存成功，旧刷新不能显示地址 A",
  );
});

test("F04: 403/409/422 写入拒绝与未知写入均不转入真实身份的模拟事实", async () => {
  for (const status of [403, 409, 422, 0]) {
    const h = await connected();
    const order = fixture().orders[0];
    const before = structuredClone(h.app.getState().data.orders);
    h.context.fetch = async () => {
      if (!status) throw Error("transport failed");
      return response({ message: "合成拒绝" }, status);
    };
    await assert.rejects(
      h.app.mutateOrder(order, "remark", { note: "不得假成功" }),
    );
    assert.equal(h.app.getState().dataKind, "server");
    assert.deepEqual(
      JSON.parse(JSON.stringify(h.app.getState().data.orders)),
      before,
    );
  }
});

test("F05: 合成离线写入与接口恢复保持数据来源独立", async () => {
  const h = harness();
  await flush();
  h.app.openDemo("dispatcher");
  h.context.fetch = async () => {
    throw Error("offline");
  };
  const order = D.seed().orders[0];
  await h.app.mutateOrder(order, "remark", { note: "独立演示备注" });
  assert.equal(h.app.getState().dataKind, "demo");
  assert.match(h.node("#toast").textContent, /独立合成演示/);
  h.context.fetch = reads();
  await h.app.login("admin", "synthetic");
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().actor.id, "admin");
  assert.doesNotMatch(
    JSON.stringify(h.app.getState().data.orders),
    /独立演示备注/,
  );
});

test("F06: 借出未知响应不假成功，同一表单重试保留相同请求键", async () => {
  const h = await connected();
  h.app.globalForm("loan");
  h.context.fetch = async () => {
    throw Error("unknown commit");
  };
  const fields = {
    partId: fixture().parts[0].id,
    quantity: "1",
    borrowerId: "engineer",
    orderId: "",
    dueAt: "2026-10-15",
    note: "合成借出",
  };
  await h.submit("actionForm", fields);
  const one = h.calls.at(-1);
  assert.equal(h.node("#formDialog").open, true);
  await h.submit("actionForm", fields);
  const two = h.calls.at(-1);
  assert.equal(
    one.options.headers["Idempotency-Key"],
    two.options.headers["Idempotency-Key"],
  );
  assert.equal(h.app.getState().dataKind, "server");
});

test("F07: 当前详情读取失败保留完整空态，不把列表摘要当作办事实依据", async () => {
  const h = await connected();
  h.context.fetch = async () => response({ message: "撤权" }, 403);
  await h.app.openDetail(fixture().orders[0].id);
  assert.match(h.node("#detailContent").innerHTML, /工单详情未加载/);
  assert.match(h.node("#detailContent").innerHTML, /data-reload/);
  assert.doesNotMatch(h.node("#detailContent").innerHTML, /data-action=/);
});

test("F08: 401 列表刷新撤销前端会话，保留独立合成预览并允许重新认证恢复", async () => {
  const h = await connected();
  h.context.fetch = async () => response({ message: "账号已停用" }, 401);
  await h.app.loadOrders();
  assert.equal(h.app.getState().token, "");
  assert.equal(h.app.getState().dataKind, "demo");
  h.context.fetch = reads();
  await h.app.login("admin", "synthetic");
  assert.equal(h.app.getState().dataKind, "server");
});

test("F09: JSON 解析失败或 null 首屏独立回退，成功后无需切换演示模式", async () => {
  const h = await connected();
  h.context.fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => {
      throw Error("malformed JSON");
    },
  });
  await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "demo");
  h.context.fetch = reads();
  await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "server");
  h.context.fetch = async () => response(null);
  await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "demo");
});

test("F10: 下载原件迟到至身份切换之后不会生成旧身份下载", async () => {
  const h = await connected();
  let finish;
  h.context.fetch = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  const download = h.app.previewFile(
    "evidence-synthetic",
    fixture().orders[0].id,
  );
  h.app.openDemo("customer");
  finish({ ok: true, blob: async () => new Blob(["synthetic evidence"]) });
  await download;
  assert.equal(h.app.getState().actor.role, "customer");
  assert.doesNotMatch(h.node("#toast").textContent, /未生成替代原件/);
});

test("F11: 真正 fetch AbortSignal 超时会结束读取，独立合成回退保留可预览界面", async () => {
  const h = await connected();
  await h.submit("connectionForm", { base: "", timeout: "500" });
  h.context.fetch = (_url, options) =>
    new Promise((_resolve, reject) => {
      options.signal.addEventListener(
        "abort",
        () => {
          const error = Error("abort");
          error.name = "AbortError";
          reject(error);
        },
        { once: true },
      );
    });
  const began = Date.now();
  // 维持真实定时器的 event loop，诊断 harness 的超时定时器使用 unref。
  const keepAlive = setTimeout(() => {}, 2500);
  await h.app.refresh();
  clearTimeout(keepAlive);
  assert.equal(h.app.getState().dataKind, "demo");
  assert.ok(Date.now() - began >= 450 && Date.now() - began < 2000);
  assert.match(h.node("#connectionNote").textContent, /连接超时/);
});

test("旧表单失败响应不会把错误写进后来打开的新表单", async () => {
  const h = await connected();
  let finish;
  h.context.fetch = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  h.app.accountStatusForm("customer", "disabled");
  const submitted = h.submit("actionForm", { reason: "合成授权依据" });
  h.node("#formDialog").close();
  h.app.createForm();
  finish(response({ message: "原请求已拒绝" }, 403));
  await submitted;
  assert.equal(h.node("#formDialog").open, true);
  assert.equal(h.node("#formError").hidden, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
});

test("关闭详情后即使仍在同一视图，旧办理读取也不得重新弹表单", async () => {
  const h = await connected(),
    order = fixture().orders[0];
  await h.app.openDetail(order.id);
  let finish;
  h.context.fetch = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  const action = h.app.showAction("remark", order.id);
  await h.click({ close: "detail" });
  finish(response(order));
  await action;
  assert.equal(h.node("#formDialog").open, false);
  assert.equal(h.node("#detailDialog").open, false);
});

test("异步读取附件期间切换身份或重开表单，不以新身份发送旧文件", async () => {
  const h = await connected();
  let reader;
  h.context.FileReader = class {
    constructor() {
      reader = this;
    }
    readAsDataURL() {}
  };
  await h.app.showAction("evidence", fixture().orders[0].id);
  const submitted = h.submit("actionForm", {
    name: "合成附件",
    kind: "image",
    stage: "settling",
    file: { size: 12, type: "image/png" },
  });
  assert.ok(reader);
  const before = h.calls.filter((call) => call.url.endsWith("/actions")).length;
  h.app.openDemo("dispatcher");
  h.app.createForm();
  reader.result = "data:image/png;base64,c3ludGhldGlj";
  reader.onload();
  await submitted;
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/actions")).length,
    before,
  );
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
});

test("QC和仓库仅提交客户说明，不展示或提交脱敏的内部备注", async () => {
  for (const role of ["qc", "warehouse"]) {
    const h = harness();
    await flush();
    const live = fixture();
    live.actor = { ...live.actor, id: role, role };
    live.orders[0].remark = "";
    h.context.fetch = reads(live);
    await h.app.login(role, "synthetic");
    await h.app.showAction("remark", live.orders[0].id);
    assert.doesNotMatch(h.node("#formContent").innerHTML, /name="remark"/);
    assert.match(h.node("#formContent").innerHTML, /name="customerNote"/);
    h.context.fetch = async (url, options) => {
      if (url.endsWith("/actions")) {
        const payload = JSON.parse(options.body).payload;
        assert.equal(Object.hasOwn(payload, "remark"), false);
        assert.equal(payload.customerNote, "新的客户说明");
        return response({
          ...live.orders[0],
          version: 2,
          customerNote: payload.customerNote,
        });
      }
      return reads(live)(url, options);
    };
    await h.submit("actionForm", { remark: "", customerNote: "新的客户说明" });
    assert.equal(h.node("#formDialog").open, false);
  }
});

test("财务可读他人余项但只能办理本人事项，管理员与调度可以代办", async () => {
  for (const role of ["finance", "admin", "dispatcher"]) {
    const h = harness();
    await flush();
    const live = fixture();
    live.actor = { ...live.actor, id: role, role };
    live.orders[0].obligations = [
      {
        id: "own-task",
        title: "本人的合成余项",
        ownerId: role,
        resolved: false,
      },
      {
        id: "other-task",
        title: "他人的合成余项",
        ownerId: "engineer",
        resolved: false,
      },
      {
        id: "resolved-task",
        title: "已完成余项",
        ownerId: role,
        resolved: true,
      },
    ];
    h.context.fetch = reads(live);
    await h.app.login(role, "synthetic");
    const cards = h.node("#tasksView").innerHTML;
    assert.match(cards, /data-record="own-task"/);
    if (role === "finance")
      assert.doesNotMatch(cards, /data-record="other-task"/);
    else assert.match(cards, /data-record="other-task"/);
    await h.app.showAction(
      "resolve_obligation",
      live.orders[0].id,
      "other-task",
    );
    assert.equal(h.node("#formDialog").open, role !== "finance");
    if (h.node("#formDialog").open) h.node("#formDialog").close();
    await h.app.showAction(
      "resolve_obligation",
      live.orders[0].id,
      "resolved-task",
    );
    assert.equal(h.node("#formDialog").open, false);
    await h.app.showAction("resolve_obligation", live.orders[0].id, "own-task");
    assert.equal(h.node("#formDialog").open, true);
  }
});

test("成功保存后导航与筛选取代工单请求，配置和全量指标仍更新且保留新筛选页", async () => {
  const h = await connected();
  await h.click({ view: "settings" });
  const live = fixture();
  let finishBootstrap;
  const fresh = {
    ...live.orders[0],
    id: "new-filter-page",
    number: "NEW-FILTER-PAGE",
  };
  const baselineBoots = h.calls.filter((call) =>
    call.url.endsWith("/bootstrap"),
  ).length;
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      live.settings = JSON.parse(options.body);
      live.metrics.openCount = 90;
      return response(live.settings);
    }
    if (url.endsWith("/bootstrap"))
      return new Promise((resolve) => {
        finishBootstrap = () => resolve(response(live));
      });
    return reads(live, { items: [fresh], total: 1, totalPages: 1 })(
      url,
      options,
    );
  };
  const saved = h.submit("companyForm", {
    companyAddress: "最新配置 B",
    companyReceiver: "合成",
    companyPhone: "合成",
    reminderHours: "24",
  });
  await flush();
  await h.click({ view: "orders" });
  h.node("#search").value = "NEW-FILTER-PAGE";
  h.node("#search").oninput();
  await flush();
  finishBootstrap();
  await saved;
  assert.equal(h.app.getState().data.settings.companyAddress, "最新配置 B");
  assert.equal(h.app.getState().data.metrics.openCount, 90);
  assert.equal(h.app.getState().data.orders[0].id, "new-filter-page");
  assert.equal(h.app.getState().data.orderPage.total, 1);
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/bootstrap")).length,
    baselineBoots + 1,
    "导航不会导致 bootstrap 无限重试",
  );
});

test("刷新已取得bootstrap但旧工单页迟到，保留后来的财务页且应用最新配置", async () => {
  const h = await connected();
  await h.click({ view: "settings" });
  const live = fixture();
  let finishOldPage,
    first = true;
  const fresh = {
    ...live.orders[0],
    id: "new-finance-page",
    number: "NEW-FINANCE-PAGE",
  };
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      live.settings = JSON.parse(options.body);
      return response(live.settings);
    }
    if (url.includes("/orders?") && first) {
      first = false;
      return new Promise((resolve) => {
        finishOldPage = () =>
          resolve(
            response({
              items: [{ ...live.orders[0], id: "stale-page" }],
              ...live.orderPage,
            }),
          );
      });
    }
    return reads(live, { items: [fresh], total: 1, totalPages: 1 })(
      url,
      options,
    );
  };
  const saved = h.submit("companyForm", {
    companyAddress: "新财务配置",
    companyReceiver: "合成",
    companyPhone: "合成",
    reminderHours: "24",
  });
  await flush();
  assert.equal(typeof finishOldPage, "function");
  await h.click({ view: "finance" });
  finishOldPage();
  await saved;
  assert.equal(h.app.getState().data.settings.companyAddress, "新财务配置");
  assert.equal(h.app.getState().data.orders[0].id, "new-finance-page");
  assert.equal(h.app.getState().data.orderPage.total, 1);
  assert.doesNotMatch(h.node("#financeView").innerHTML, /stale-page/);
});

function canvasFor(h) {
  const canvas = h.node("#signatureCanvas");
  canvas.width = 900;
  canvas.height = 260;
  canvas.getContext = () => ({
    beginPath() {},
    moveTo() {},
    lineTo() {},
    stroke() {},
    clearRect() {},
    fillText() {},
  });
  canvas.getBoundingClientRect = () => ({
    left: 0,
    top: 0,
    width: 900,
    height: 260,
  });
  canvas.setPointerCapture = () => {};
  canvas.toDataURL = () => "data:image/png;base64,c3ludGhldGlj";
  return canvas;
}
function draw(canvas) {
  canvas.onpointerdown({ clientX: 2, clientY: 3, pointerId: 1 });
  canvas.onpointermove({ clientX: 30, clientY: 40, pointerId: 1 });
  canvas.onpointerup();
}
async function connectedAs(role) {
  const h = harness();
  await flush();
  const live = fixture();
  live.actor = { ...live.actor, id: role, role, companyId: "company-a" };
  if (role === "customer") live.orders = [live.orders[0]];
  h.context.fetch = reads(live);
  await h.app.login(role, "synthetic");
  return { h, live };
}

test("R3/T01 [正常保护] 连续刷新＋后一次保存＋两次列表切换只保留最新metadata和分页", async () => {
  const h = await connected(),
    live = fixture(),
    boots = [];
  const latest = {
    ...live.orders[0],
    id: "newest-filter",
    number: "NEWEST-FILTER",
  };
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      live.settings = JSON.parse(options.body);
      live.metrics.openCount = 111;
      return response(live.settings);
    }
    if (url.endsWith("/bootstrap")) {
      const snapshot = structuredClone(live);
      return new Promise((resolve) =>
        boots.push(() => resolve(response(snapshot))),
      );
    }
    return reads(live, { items: [latest], total: 1, totalPages: 1 })(
      url,
      options,
    );
  };
  const first = h.app.refresh();
  await flush();
  const saved = h.submit("companyForm", {
    companyAddress: "后一次配置",
    companyReceiver: "合成",
    companyPhone: "合成",
    reminderHours: "24",
  });
  await flush();
  await h.click({ view: "finance" });
  boots[0]();
  await flush();
  assert.equal(boots.length, 2);
  await h.click({ view: "orders" });
  h.node("#search").value = "NEWEST";
  h.node("#search").oninput();
  await flush();
  boots[1]();
  await Promise.all([first, saved]);
  assert.equal(h.app.getState().data.settings.companyAddress, "后一次配置");
  assert.equal(h.app.getState().data.metrics.openCount, 111);
  assert.equal(h.app.getState().data.orders[0].id, "newest-filter");
  assert.equal(boots.length, 2, "没有无界补读");
});

test("R3/T02 [安全拒绝] 更新分页401后，之前已授权的迟到bootstrap不能复活身份或旧资料", async () => {
  const h = await connected();
  let finish;
  h.context.fetch = (url) =>
    url.endsWith("/bootstrap")
      ? new Promise((resolve) => {
          finish = () => resolve(response(fixture()));
        })
      : Promise.resolve(response({ message: "当前会话已撤销" }, 401));
  const refreshing = h.app.refresh();
  await flush();
  await h.app.loadOrders({ reset: true });
  assert.equal(h.app.getState().dataKind, "demo");
  assert.equal(h.app.getState().token, "");
  finish();
  await refreshing;
  assert.equal(h.app.getState().dataKind, "demo");
  assert.equal(h.app.getState().token, "");
  assert.equal(h.app.getState().actor.authVersion, undefined);
  assert.match(h.app.getState().actor.displayName, /演示/);
});

test("R3/T03 [安全拒绝] 反序metadata的授权版本/角色/企业不匹配时不并入当前分页", async () => {
  for (const changed of [
    { authVersion: 2 },
    { role: "customer" },
    { companyId: "other-company" },
  ]) {
    const h = await connected(),
      wrong = fixture();
    wrong.actor = { ...wrong.actor, ...changed };
    let finish;
    h.context.fetch = (url, options) =>
      url.endsWith("/bootstrap")
        ? new Promise((resolve) => {
            finish = () => resolve(response(wrong));
          })
        : reads()(url, options);
    const refreshing = h.app.refresh();
    await flush();
    await h.app.loadOrders();
    finish();
    await refreshing;
    assert.equal(h.app.getState().actor.role, "admin");
    assert.equal(h.app.getState().data.actor.authVersion, 1);
    assert.notEqual(h.app.getState().data.actor.companyId, "other-company");
  }
});

test("R3/T04 [正常保护] 刷新队列等待期间换身份，新会话结束后旧job不覆盖新状态", async () => {
  const h = await connected();
  let finishOld;
  h.context.fetch = () =>
    new Promise((resolve) => {
      finishOld = () => resolve(response(fixture()));
    });
  const old = h.app.refresh();
  const queued = h.app.refresh();
  await flush();
  h.app.openDemo("finance");
  const live = fixture();
  live.actor = { ...live.actor, id: "finance", role: "finance" };
  h.context.fetch = reads(live);
  await h.app.login("finance", "synthetic");
  finishOld();
  await Promise.all([old, queued]);
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().actor.id, "finance");
  assert.equal(h.app.getState().data.actor.id, "finance");
});

test("R3-F01/T05 [保护预期] 新客户登录到分页完成及迟到bootstrap全过程不显示旧管理员资料", async () => {
  const h = harness();
  await flush();
  const admin = fixture();
  admin.orders[0].number = "ADMIN-PRIVATE-COMPANY-B";
  admin.orders[0].customerId = "customer-b";
  admin.orders[0].companyId = "company-b";
  h.context.fetch = reads(admin);
  await h.app.login("admin", "synthetic");
  await h.click({ view: "settings" });
  const customer = fixture();
  customer.actor = {
    ...customer.actor,
    id: "customer",
    role: "customer",
    companyId: "company-a",
  };
  customer.orders = [
    {
      ...customer.orders[0],
      number: "CUSTOMER-A-ONLY",
      customerId: "customer",
      companyId: "company-a",
    },
  ];
  customer.metrics.remainingCents = 123;
  let finishBootstrap, finishCustomerPage;
  const stages = [];
  const record = (stage) => {
    const state = h.app.getState();
    const list =
      state.view === "finance"
        ? h.node("#financeView").innerHTML
        : state.view === "orders"
          ? h.node("#ordersBody").innerHTML
          : "";
    const item = {
      stage,
      actor: state.actor.id,
      actorRole: state.actor.role,
      snapshotActor: state.data.actor.id,
      snapshotRole: state.data.actor.role,
      view: state.view,
      oldCrossCompanyCached: state.data.orders.some(
        (o) => o.number === "ADMIN-PRIVATE-COMPANY-B",
      ),
      oldCrossCompanyVisible: list.includes("ADMIN-PRIVATE-COMPANY-B"),
      remainingCents: state.data.metrics?.remainingCents,
      dataKind: state.dataKind,
    };
    stages.push(item);
    assert.equal(item.oldCrossCompanyCached, false, stage);
    assert.equal(item.oldCrossCompanyVisible, false, stage);
    assert.notEqual(item.remainingCents, 99000000, stage);
  };
  h.context.fetch = async (url) => {
    if (url.endsWith("/login"))
      return response({
        token: "synthetic-customer-token",
        actor: customer.actor,
      });
    if (url.endsWith("/bootstrap"))
      return new Promise((resolve) => {
        finishBootstrap = () => resolve(response(customer));
      });
    if (url.includes("/orders?"))
      return new Promise((resolve) => {
        finishCustomerPage = () =>
          resolve(response({ items: customer.orders, ...customer.orderPage }));
      });
    return response({ message: "当前角色拒绝" }, 403);
  };
  const login = h.app.login("customer", "synthetic");
  await flush();
  record("login_success_bootstrap_pending");
  await h.click({ view: "finance" });
  record("finance_navigation_new_page_pending");
  finishCustomerPage();
  await flush();
  record("customer_page_arrived_before_bootstrap");
  finishBootstrap();
  await login;
  record("new_customer_bootstrap_arrived_final");
  assert.equal(
    stages.some((stage) => stage.oldCrossCompanyVisible),
    false,
    "新客户身份下不可显示上一管理员的跨企业列表",
  );
  assert.equal(h.app.getState().data.actor.id, "customer");
  assert.equal(h.app.getState().data.metrics.remainingCents, 123);
});

test("R3/T06 [正常保护] 客户签名保存迟到，不关闭随后打开的新建工单表单", async () => {
  const { h, live } = await connectedAs("customer");
  const canvas = canvasFor(h);
  h.app.showSignature("sign_quote", live.orders[0]);
  draw(canvas);
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/actions")
      ? new Promise((resolve) => {
          finish = () => resolve(response({ ...live.orders[0], version: 2 }));
        })
      : reads(live)(url, options);
  const signed = h.submit("actionForm", { agreed: "on" });
  await flush();
  h.node("#formDialog").close();
  h.app.createForm();
  finish();
  await signed;
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
});

test("R3/T07 [安全拒绝] 同身份关闭附件表单并开新表单后，迟到FileReader不发原写请求", async () => {
  const h = await connected();
  let reader;
  h.context.FileReader = class {
    constructor() {
      reader = this;
    }
    readAsDataURL() {}
  };
  await h.app.showAction("evidence", fixture().orders[0].id);
  const submitted = h.submit("actionForm", {
    name: "合成媒体",
    kind: "image",
    stage: "settling",
    file: { size: 12, type: "image/png" },
  });
  const before = h.calls.filter((call) => call.url.endsWith("/actions")).length;
  h.node("#formDialog").close();
  h.app.createForm();
  reader.result = "data:image/png;base64,c3ludGhldGlj";
  reader.onload();
  await submitted;
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/actions")).length,
    before,
  );
  assert.equal(h.node("#formDialog").open, true);
});

test("R3/T08 [正常保护] 浏览器旧close事件排队后新表单已打开，不使新实例失效", async () => {
  const h = await connected(),
    dialog = h.node("#formDialog");
  const delayed = [];
  dialog.close = function () {
    this.open = false;
    delayed.push(() => this.emit("close"));
  };
  h.app.accountStatusForm("customer", "disabled");
  h.context.fetch = async () =>
    response({
      id: "customer",
      role: "customer",
      status: "disabled",
      authVersion: 2,
    });
  await h.submit("actionForm", { reason: "合成依据" });
  h.app.createForm();
  delayed.shift()();
  h.context.fetch = async () => response({ message: "新工单内容需补齐" }, 422);
  const before = h.calls.filter(
    (call) => call.url === "/api/v38/orders",
  ).length;
  await h.submit("actionForm", {
    type: "mail",
    customerId: "customer",
    customer: "合成",
    device: "合成",
    description: "合成",
    prepayChoice: "none",
  });
  assert.equal(
    h.calls.filter((call) => call.url === "/api/v38/orders").length,
    before + 1,
    "新表单确实执行自身请求，而非被旧事件票据拒绝",
  );
  assert.equal(dialog.open, true);
  assert.match(h.node("#formError").textContent, /新工单内容需补齐/);
});

test("R3/T09 [安全拒绝] 手写签名未知/空成功响应不关闭表单且不进入合成事实", async () => {
  for (const mode of ["unavailable", "null"]) {
    const { h, live } = await connectedAs("customer");
    const canvas = canvasFor(h);
    h.app.showSignature("sign_quote", live.orders[0]);
    draw(canvas);
    const before = JSON.stringify(h.app.getState().data.orders);
    h.context.fetch = async () => {
      if (mode === "unavailable") throw Error("unknown");
      return response(null);
    };
    await h.submit("actionForm", { agreed: "on" });
    assert.equal(h.node("#formDialog").open, true);
    assert.equal(h.app.getState().dataKind, "server");
    assert.equal(JSON.stringify(h.app.getState().data.orders), before);
  }
});

test("R3-F02/T10 [保护预期] 独立演示中QC只更新客户说明时，省略内部备注须保留原值", async () => {
  const h = harness();
  await flush();
  h.app.openDemo("qc");
  h.context.fetch = async () => {
    throw Error("offline");
  };
  const order = h.app.getState().data.orders[0],
    original = order.remark;
  await h.click({ open: order.id });
  assert.match(h.node("#detailContent").innerHTML, /data-action="remark"/);
  await h.click({ action: "remark", order: order.id });
  assert.doesNotMatch(h.node("#formContent").innerHTML, /name="remark"/);
  await h.submit("actionForm", { customerNote: "合成客户说明更新" });
  const changed = h.app
    .getState()
    .data.orders.find((item) => item.id === order.id);
  const actionRequest = h.calls.findLast((call) =>
    call.url.endsWith("/actions"),
  );
  const sentPayload = JSON.parse(actionRequest.options.body).payload;
  assert.deepEqual(Object.keys(sentPayload), ["customerNote"]);
  assert.equal(changed.customerNote, "合成客户说明更新");
  assert.equal(
    changed.remark,
    original,
    "合成演示也不应以缺省字段抹掉内部备注",
  );
});

function privateFixture() {
  const live = fixture();
  live.actor.name = "ADMIN-PRIVATE-ACCOUNT";
  live.orders[0].number = "ADMIN-PRIVATE-ORDER";
  live.settings.companyAddress = "ADMIN-PRIVATE-ADDRESS";
  live.parts[0].name = "ADMIN-PRIVATE-PART";
  live.loans[0].note = "ADMIN-PRIVATE-LOAN";
  live.purchases = [
    {
      id: "private-purchase",
      version: 1,
      supplier: "合成供应商",
      partId: live.parts[0].id,
      received: 0,
      quantity: 1,
      unitCents: 100,
      note: "ADMIN-PRIVATE-PURCHASE",
    },
  ];
  return live;
}
function customerFixture() {
  const live = fixture();
  live.actor = {
    ...live.actor,
    id: "customer",
    role: "customer",
    companyId: "company-a",
  };
  live.orders = [
    {
      ...live.orders[0],
      id: "customer-only",
      number: "CUSTOMER-ONLY",
      customerId: "customer",
      companyId: "company-a",
    },
  ];
  live.parts = [];
  live.loans = [];
  live.purchases = [];
  live.metrics.remainingCents = 123;
  live.settings.companyAddress = "CUSTOMER-CURRENT-ADDRESS";
  return live;
}
function assertNoPrivateSnapshot(h, stage) {
  assert.doesNotMatch(
    JSON.stringify(h.app.getState().data),
    /ADMIN-PRIVATE/,
    stage,
  );
  for (const selector of [
    "#ordersBody",
    "#tasksView",
    "#financeView",
    "#inventoryView",
    "#settingsView",
    "#accountList",
    "#auditList",
    "#detailContent",
    "#formContent",
  ])
    assert.doesNotMatch(
      h.node(selector).innerHTML,
      /ADMIN-PRIVATE/,
      stage + selector,
    );
}
async function privateSession() {
  const h = harness();
  await flush();
  const live = privateFixture();
  h.context.fetch = reads(live);
  await h.app.login("admin", "synthetic");
  return { h, live };
}

test("R3/B01: 登录发出即清旧授权及隐藏DOM，拒绝/断网/坏响应后导航也不恢复旧数据", async () => {
  for (const failure of ["denied", "network", "null"]) {
    const { h, live } = await privateSession();
    h.context.fetch = async (url, options) =>
      url.includes("/audit?")
        ? response({
            items: [
              {
                id: "audit-old",
                actorId: "admin",
                actorRole: "admin",
                type: "login",
                result: "success",
                resource: "ADMIN-PRIVATE-AUDIT",
                at: "2026-10-15T00:00:00Z",
              },
            ],
            total: 1,
            page: 1,
            pageSize: 30,
          })
        : reads(live)(url, options);
    await h.click({ view: "settings" });
    assert.match(h.node("#accountList").innerHTML, /ADMIN-PRIVATE-ACCOUNT/);
    assert.match(h.node("#auditList").innerHTML, /ADMIN-PRIVATE-AUDIT/);
    await h.click({ view: "orders" });
    let finish, reject;
    h.context.fetch = (url) =>
      url.endsWith("/login")
        ? new Promise((resolve, fail) => {
            finish = resolve;
            reject = fail;
          })
        : Promise.resolve(response({ message: "未认证" }, 401));
    const loggingIn = h.app.login("customer", "synthetic");
    assert.equal(h.app.getState().token, "");
    assert.equal(
      h.calls.at(-1).options.headers.Authorization,
      undefined,
      "登录不能携带上一账号Token",
    );
    assertNoPrivateSnapshot(h, "login-request-pending");
    for (const view of [
      "finance",
      "inventory",
      "settings",
      "tasks",
      "orders",
    ]) {
      await h.click({ view });
      await h.app.refresh();
      assertNoPrivateSnapshot(h, failure + ":pending:" + view);
    }
    if (failure === "network") reject(Error("offline"));
    else
      finish(
        response(
          failure === "null" ? null : { message: "拒绝登录" },
          failure === "null" ? 200 : 401,
        ),
      );
    await loggingIn;
    assert.equal(h.app.getState().token, "");
    assert.equal(h.app.getState().dataKind, "demo");
    assertNoPrivateSnapshot(h, failure + ":failed");
    h.context.fetch = reads(customerFixture());
    await h.app.login("customer", "synthetic");
    assert.equal(h.app.getState().data.actor.id, "customer");
    assertNoPrivateSnapshot(h, failure + ":retry");
  }
});

test("R3/B02: 新身份bootstrap与最新页正反序、五种导航均只提交新身份metadata和最新列表", async () => {
  for (const view of ["orders", "tasks", "finance", "inventory", "settings"]) {
    for (const order of ["bootstrap-first", "page-first"]) {
      const { h } = await privateSession(),
        customer = customerFixture(),
        pages = new Map();
      let finishBootstrap,
        bootstrapCount = 0;
      h.context.fetch = async (url) => {
        if (url.endsWith("/login"))
          return response({
            token: "customer-test-token",
            actor: customer.actor,
          });
        if (url.endsWith("/bootstrap")) {
          bootstrapCount++;
          return new Promise((resolve) => {
            finishBootstrap = () => resolve(response(customer));
          });
        }
        if (url.includes("/orders?")) {
          const page = Number(
            new URL(url, "http://test").searchParams.get("page"),
          );
          return new Promise((resolve) =>
            pages.set(page, () =>
              resolve(
                response({
                  ...customer.orderPage,
                  page,
                  items: [
                    { ...customer.orders[0], id: "customer-page-" + page },
                  ],
                }),
              ),
            ),
          );
        }
        return response({ message: "当前角色不可读取" }, 403);
      };
      const loggingIn = h.app.login("customer", "synthetic");
      await flush();
      assertNoPrivateSnapshot(h, view + ":authenticated-empty");
      assert.equal(h.app.getState().data.actor.id, "customer");
      await h.click({ view });
      const hasPage = ["orders", "tasks", "finance"].includes(view);
      let newest;
      if (hasPage) {
        h.app.setPage(2);
        newest = h.app.loadOrders();
        await flush();
      }
      assertNoPrivateSnapshot(h, view + ":navigation");
      if (order === "bootstrap-first") {
        finishBootstrap();
        await flush();
      }
      if (hasPage) {
        pages.get(2)();
        await newest;
      }
      if (order === "page-first") {
        finishBootstrap();
        await flush();
      }
      if (hasPage) {
        pages.get(1)();
        await flush();
      }
      await loggingIn;
      const state = h.app.getState();
      assert.equal(state.actor.id, "customer");
      assert.equal(state.data.actor.id, "customer");
      assert.equal(state.data.metrics.remainingCents, 123);
      assert.equal(
        state.data.settings.companyAddress,
        "CUSTOMER-CURRENT-ADDRESS",
      );
      assert.equal(state.dataKind, "server");
      if (hasPage) {
        assert.equal(state.page, 2);
        assert.equal(state.data.orders[0].id, "customer-page-2");
      }
      assert.equal(bootstrapCount, 1, "导航不导致无界bootstrap补读");
      assert.equal(
        h.calls.filter(
          (call) =>
            call.url.includes("/audit?") || call.url.endsWith("/accounts"),
        ).length,
        0,
      );
      assertNoPrivateSnapshot(h, view + ":final:" + order);
    }
  }
});

test("R3/B03: 新身份bootstrap失败和重试均不复活旧数据，401重新认证，其余失败刷新恢复", async () => {
  for (const failure of ["network", "null", "401"]) {
    const { h } = await privateSession(),
      customer = customerFixture();
    h.context.fetch = (url, options) => {
      if (url.endsWith("/bootstrap"))
        return failure === "network"
          ? Promise.reject(Error("offline"))
          : Promise.resolve(
              response(
                failure === "null" ? null : { message: "会话撤销" },
                failure === "null" ? 200 : 401,
              ),
            );
      return reads(customer)(url, options);
    };
    await h.app.login("customer", "synthetic");
    assert.equal(h.app.getState().dataKind, "demo");
    assertNoPrivateSnapshot(h, failure + ":fallback");
    h.context.fetch = reads(customer);
    if (failure === "401") {
      assert.equal(h.app.getState().token, "");
      await h.app.login("customer", "synthetic");
    } else {
      assert.notEqual(h.app.getState().token, "");
      await h.app.refresh();
    }
    assert.equal(h.app.getState().data.actor.id, "customer");
    assert.equal(h.app.getState().data.metrics.remainingCents, 123);
  }
});

test("R3/B04: 完整bootstrap也校验已认证账号/角色/企业/授权版本/有效状态，错误2xx不能换身份", async () => {
  for (const change of [
    { id: "other" },
    { role: "customer" },
    { companyId: "other-company" },
    { authVersion: 2 },
    { status: "disabled" },
  ]) {
    const h = await connected(),
      wrong = fixture();
    wrong.actor = { ...wrong.actor, ...change };
    wrong.settings.companyAddress = "WRONG-ACTOR-PRIVATE";
    h.context.fetch = async () => response(wrong);
    await h.app.refresh();
    assert.equal(h.app.getState().dataKind, "demo");
    assert.doesNotMatch(
      JSON.stringify(h.app.getState().data),
      /WRONG-ACTOR-PRIVATE/,
    );
    h.context.fetch = reads();
    await h.app.refresh();
    assert.equal(h.app.getState().actor.id, "admin");
    assert.equal(h.app.getState().data.actor.authVersion, 1);
    assert.equal(h.app.getState().dataKind, "server");
  }
});

test("R3/B05: 清空设置父DOM后账号/审计节点不存在，登录清理仍可完成", async () => {
  const h = await connected(),
    query = h.context.document.querySelector;
  h.context.document.querySelector = (selector) =>
    ["#accountList", "#auditList"].includes(selector) ? null : query(selector);
  h.context.fetch = reads(customerFixture());
  await h.app.login("customer", "synthetic");
  assert.equal(h.app.getState().data.actor.id, "customer");
  assert.equal(h.app.getState().dataKind, "server");
});

test("R3/B06: 网络回退撤销迟到详情及账号/审计响应，不回填旧缓存或旧DOM", async () => {
  for (const metadata of ["accounts", "audit"]) {
    const { h, live } = await privateSession();
    let finishDetail, finishMetadata;
    h.context.fetch = (url, options) => {
      if (url.endsWith("/orders/" + live.orders[0].id))
        return new Promise((resolve) => {
          finishDetail = () => resolve(response(live.orders[0]));
        });
      if (
        (metadata === "accounts" && url.endsWith("/accounts")) ||
        (metadata === "audit" && url.includes("/audit?"))
      )
        return new Promise((resolve) => {
          finishMetadata = () =>
            resolve(
              response(
                metadata === "accounts"
                  ? [live.actor]
                  : {
                      items: [
                        {
                          id: "late-audit",
                          actorId: "admin",
                          type: "login",
                          result: "success",
                          at: "2026-10-15T00:00:00Z",
                          resource: "ADMIN-PRIVATE-AUDIT",
                        },
                      ],
                      total: 1,
                      page: 1,
                      pageSize: 30,
                    },
              ),
            );
        });
      return reads(live)(url, options);
    };
    const detail = h.app.openDetail(live.orders[0].id);
    await h.click({ view: "settings" });
    assert.equal(typeof finishMetadata, "function");
    h.context.fetch = async () => {
      throw Error("offline");
    };
    await h.app.loadOrders();
    finishDetail();
    finishMetadata();
    await detail;
    await flush();
    assert.equal(h.app.getState().dataKind, "demo");
    assert.equal(h.app.getState().cachedDetailIds.length, 0);
    assert.equal(h.node("#detailDialog").open, false);
    assertNoPrivateSnapshot(h, metadata + ":late-after-fallback");
  }
});

test("R3/B07: 独立回退重连被导航取代，可信身份metadata仍恢复且不把合成列表当作真实记录", async () => {
  for (const view of ["inventory", "settings", "finance"]) {
    const h = await connected();
    h.context.fetch = async () => {
      throw Error("offline");
    };
    await h.app.refresh();
    const live = fixture();
    live.settings.companyAddress = "RECOVERED-CURRENT";
    live.orders = [{ ...live.orders[0], id: "recovered-only" }];
    let finish;
    h.context.fetch = (url, options) =>
      url.endsWith("/bootstrap")
        ? new Promise((resolve) => {
            finish = () => resolve(response(live));
          })
        : reads(live)(url, options);
    const recovering = h.app.refresh();
    await flush();
    await h.click({ view });
    finish();
    await recovering;
    assert.equal(h.app.getState().dataKind, "server");
    assert.equal(h.app.getState().actor.id, "admin");
    assert.equal(
      h.app.getState().data.settings.companyAddress,
      "RECOVERED-CURRENT",
    );
    if (view === "finance")
      assert.equal(h.app.getState().data.orders[0].id, "recovered-only");
    else
      assert.equal(
        h.app.getState().data.orders.length,
        0,
        "只合入metadata时保留安全空列表",
      );
  }
});

test("R3/B08: 旧登录或旧bootstrap迟到失败不能撤销后来已成功认证的会话", async () => {
  for (const phase of ["login", "bootstrap"]) {
    const h = await connected(),
      customer = customerFixture();
    let failOld;
    h.context.fetch = (url, options) =>
      url.endsWith("/" + phase)
        ? new Promise((resolve) => {
            failOld = () => resolve(response({ message: "旧会话失败" }, 401));
          })
        : reads(customer)(url, options);
    const old = h.app.login("customer", "synthetic");
    await flush();
    const finance = fixture();
    finance.actor = { ...finance.actor, id: "finance", role: "finance" };
    h.context.fetch = reads(finance);
    await h.app.login("finance", "synthetic");
    failOld();
    await old;
    assert.equal(h.app.getState().actor.id, "finance");
    assert.equal(h.app.getState().data.actor.id, "finance");
    assert.equal(h.app.getState().dataKind, "server");
    assert.notEqual(h.app.getState().token, "");
  }
});

test("R3/B09: 已认证而bootstrap未返回时公司配置仅为加载占位，不能保存占位值", async () => {
  const { h } = await privateSession();
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((resolve) => {
          finish = () => resolve(response(fixture()));
        })
      : reads()(url, options);
  const loggingIn = h.app.login("admin", "synthetic");
  await flush();
  await h.click({ view: "settings" });
  assert.match(
    h.node("#settingsView").innerHTML,
    /type="submit" disabled>保存公司配置/,
  );
  const before = h.calls.filter((call) =>
    call.url.endsWith("/settings"),
  ).length;
  await h.submit("companyForm", {
    companyAddress: "占位地址",
    companyReceiver: "待配置",
    companyPhone: "待配置",
    reminderHours: "24",
  });
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/settings")).length,
    before,
  );
  assertNoPrivateSnapshot(h, "admin-waiting-metadata");
  finish();
  await loggingIn;
  assert.doesNotMatch(
    h.node("#settingsView").innerHTML,
    /type="submit" disabled>保存公司配置/,
  );
});

test("R3/B10: 未知公司保存经过独立回退与恢复不自动重放，明确重试仍保留原请求键", async () => {
  const h = await connected(),
    fields = {
      companyAddress: "待核对配置",
      companyReceiver: "合成",
      companyPhone: "合成",
      reminderHours: "24",
    };
  h.context.fetch = async () => {
    throw Error("unknown commit");
  };
  await h.submit("companyForm", fields);
  const original = h.calls.findLast((call) => call.url.endsWith("/settings"));
  await h.app.loadOrders();
  assert.equal(h.app.getState().dataKind, "demo");
  h.context.fetch = reads();
  await h.app.refresh();
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/settings")).length,
    1,
  );
  h.context.fetch = async () => {
    throw Error("still unknown");
  };
  await h.submit("companyForm", fields);
  const retry = h.calls.findLast((call) => call.url.endsWith("/settings"));
  assert.equal(
    retry.options.headers["Idempotency-Key"],
    original.options.headers["Idempotency-Key"],
  );
  assert.equal(h.app.getState().dataKind, "server");
});

test("R3/B11: 登录等待期间开的合成新建表单不能沿用到认证成功后的真实身份", async () => {
  const h = await connected(),
    customer = customerFixture();
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/login")
      ? new Promise((resolve) => {
          finish = () =>
            resolve(response({ token: "new-customer", actor: customer.actor }));
        })
      : reads(customer)(url, options);
  const loggingIn = h.app.login("customer", "synthetic");
  await flush();
  h.app.createForm();
  const oldSubmit = h.node("#actionForm").onsubmit;
  assert.equal(h.node("#formDialog").open, true);
  finish();
  await loggingIn;
  assert.equal(h.node("#formDialog").open, false);
  const before = h.calls.length;
  h.node("#actionForm").fields = {
    customer: "等待期间的合成表单",
    type: "mail",
  };
  await oldSubmit({ preventDefault() {} });
  assert.equal(h.calls.length, before, "旧实例不能使用新账号发业务请求");
  assert.equal(h.app.getState().data.actor.id, "customer");
});

test("R3/B12: 登录等待期间的附件读取在认证成功后不能带新Token发送旧文件", async () => {
  const h = await connected(),
    customer = customerFixture();
  let finish, reader;
  h.context.fetch = (url, options) =>
    url.endsWith("/login")
      ? new Promise((resolve) => {
          finish = () =>
            resolve(response({ token: "new-customer", actor: customer.actor }));
        })
      : reads(customer)(url, options);
  const loggingIn = h.app.login("customer", "synthetic");
  await flush();
  h.context.FileReader = class {
    constructor() {
      reader = this;
    }
    readAsDataURL() {}
  };
  await h.app.showAction("evidence", h.app.getState().data.orders[0].id);
  const submitted = h.submit("actionForm", {
    name: "等待期间附件",
    kind: "image",
    stage: "settling",
    file: { size: 12, type: "image/png" },
  });
  const before = h.calls.filter((call) => call.url.endsWith("/actions")).length;
  finish();
  await loggingIn;
  reader.result = "data:image/png;base64,c3ludGhldGlj";
  reader.onload();
  await submitted;
  assert.equal(
    h.calls.filter((call) => call.url.endsWith("/actions")).length,
    before,
  );
  assert.equal(h.node("#formDialog").open, false);
  assert.equal(h.app.getState().data.actor.id, "customer");
});

/* Jobs · 第四轮真实交互故障保护，保留原只读诊断的 22 条有效边界。 */
function observe() {}
function r4PrivateFixture() {
  const data = fixture();
  data.orders.forEach((o, i) => {
    o.id = "private-" + i;
    o.number = "PRIVATE-" + i;
    o.remark = "PRIVATE-INTERNAL-NOTE";
  });
  data.settings.companyAddress = "PRIVATE-COMPANY-ADDRESS";
  return data;
}
async function r4PrivateSession() {
  const h = harness();
  await flush();
  const data = r4PrivateFixture();
  h.context.fetch = reads(data);
  await h.app.login("admin", "synthetic");
  return { h, data };
}
function r4Current(h) {
  const s = h.app.getState();
  return {
    hasToken: !!s.token,
    dataKind: s.dataKind,
    connected: s.connected,
    actor: s.actor.id,
    dataActor: s.data.actor.id,
    orders: s.data.orders.length,
    remainingCents: s.data.metrics?.remainingCents,
    cache: s.cachedDetailIds,
    privateDOM: [...h.nodes.values()].some((n) => /PRIVATE-/.test(n.innerHTML)),
    detailOpen: h.node("#detailDialog").open,
    formOpen: h.node("#formDialog").open,
    toast: h.node("#toast").textContent,
    error: h.node("#formError").textContent,
  };
}
function r4ExpectRevoked(h) {
  observe(r4Current(h));
  assert.equal(
    h.app.getState().token,
    "",
    "当前会话收到明确401后必须撤销本地服务端会话",
  );
  assert.equal(h.app.getState().dataKind, "demo", "401后只保留独立合成资料");
  assert.doesNotMatch(
    JSON.stringify(h.app.getState().data),
    /PRIVATE-/,
    "401后真实缓存必须清除",
  );
}
test("R4-C01: 完整详情401后撤销会话和旧真实资料", async () => {
  const { h, data } = await r4PrivateSession();
  h.context.fetch = async () => response({ message: "synthetic revoked" }, 401);
  await h.app.openDetail(data.orders[0].id);
  r4ExpectRevoked(h);
});
test("R4-C02: 附件原件401后撤销会话和旧真实资料", async () => {
  const { h, data } = await r4PrivateSession();
  await h.app.openDetail(data.orders[0].id);
  h.context.fetch = async () => response({ message: "synthetic revoked" }, 401);
  await h.app.previewFile("synthetic-evidence", data.orders[0].id);
  r4ExpectRevoked(h);
});
test("R4-C03: 授权导出401后撤销会话和旧真实资料", async () => {
  const { h } = await r4PrivateSession();
  h.context.fetch = async () => response({ message: "synthetic revoked" }, 401);
  await h.node("#exportOrders").onclick();
  r4ExpectRevoked(h);
});
test("R4-C04: 业务写401后撤销会话和旧真实资料，不能显示旧账号仍已连接", async () => {
  const { h, data } = await r4PrivateSession();
  await h.app.showAction("remark", data.orders[0].id);
  h.context.fetch = async () => response({ message: "synthetic revoked" }, 401);
  await h.submit("actionForm", {
    remark: "新的合成备注",
    customerNote: "合成对客说明",
  });
  r4ExpectRevoked(h);
});
test("R4-C05: 账号元数据401后撤销会话和旧真实资料", async () => {
  const { h, data } = await r4PrivateSession();
  h.context.fetch = (url, options) =>
    url.endsWith("/accounts")
      ? Promise.resolve(response({ message: "synthetic revoked" }, 401))
      : reads(data)(url, options);
  await h.click({ view: "settings" });
  await flush();
  r4ExpectRevoked(h);
});
test("R4-C06: 管理员审计401后撤销会话和旧真实资料", async () => {
  const { h, data } = await r4PrivateSession();
  h.context.fetch = (url, options) =>
    url.includes("/audit?")
      ? Promise.resolve(response({ message: "synthetic revoked" }, 401))
      : reads(data)(url, options);
  await h.click({ view: "settings" });
  await flush();
  r4ExpectRevoked(h);
});
test("R4-C07: 同一身份bootstrap401即使被导航列表先到也必须撤销会话", async () => {
  const { h, data } = await r4PrivateSession();
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((r) => {
          finish = () => r(response({ message: "synthetic revoked" }, 401));
        })
      : reads(data)(url, options);
  const refreshing = h.app.refresh();
  await flush();
  await h.click({ view: "finance" });
  finish();
  await refreshing;
  r4ExpectRevoked(h);
});
test("R4-C08: 新身份bootstrap失败被导航抢先时应明确回退或重试，不能保持已连接且概览永久为零", async () => {
  const { h } = await r4PrivateSession(),
    data = fixture();
  data.actor = {
    ...data.actor,
    id: "customer",
    role: "customer",
    companyId: "company-a",
  };
  data.orders = [
    { ...data.orders[0], id: "customer-r4Current", number: "CUSTOMER-CURRENT" },
  ];
  data.parts = [];
  data.loans = [];
  data.purchases = [];
  data.metrics.remainingCents = 123;
  let fail;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((_r, reject) => {
          fail = () => reject(Error("synthetic network failure"));
        })
      : reads(data)(url, options);
  const loggingIn = h.app.login("customer", "synthetic");
  await flush();
  await h.click({ view: "finance" });
  fail();
  await loggingIn;
  observe(r4Current(h));
  assert.ok(
    h.app.getState().dataKind === "demo" ||
      h.app.getState().data.metrics.remainingCents === 123,
    "bootstrap失败后应回退独立演示或成功补读当前身份概览，不能停留部分真数据+零概览",
  );
});
test("R4-C09: 服务返回部分坏库存2xx时可控回退，不使render抛错并留下半套真资料", async () => {
  const h = await connected(),
    bad = fixture();
  bad.parts = [null];
  h.context.fetch = reads(bad);
  let thrown;
  try {
    await h.app.refresh();
  } catch (e) {
    thrown = e;
  }
  observe({ ...r4Current(h), thrown: thrown?.message });
  assert.equal(
    thrown,
    undefined,
    "坏响应应拒绝并回退，不应逃出render造成页面未完成",
  );
  assert.equal(h.app.getState().dataKind, "demo", "坏库存响应不能采用为真数据");
});
test("R4-C10: 服务返回缺missing的详情2xx时显示可重试错误，不使详情直接抛错", async () => {
  const { h, data } = await r4PrivateSession(),
    bad = structuredClone(data.orders[0]);
  delete bad.summary.missing;
  h.context.fetch = async () => response(bad);
  let thrown;
  try {
    await h.app.openDetail(bad.id);
  } catch (e) {
    thrown = e;
  }
  observe({
    ...r4Current(h),
    thrown: thrown?.message,
    detailHTML: h.node("#detailContent").innerHTML.slice(0, 500),
  });
  assert.equal(
    thrown,
    undefined,
    "详情缺必填派生字段应拒绝并显示完整空态，不应向事件循环抛错",
  );
  assert.match(h.node("#detailContent").innerHTML, /工单详情未加载/);
});
test("R4-C11: 403业务拒绝保留真实事实和表单，无模拟成功", async () => {
  const { h, data } = await r4PrivateSession(),
    before = JSON.stringify(h.app.getState().data);
  await h.app.showAction("remark", data.orders[0].id);
  h.context.fetch = async () =>
    response({ message: "synthetic forbidden" }, 403);
  await h.submit("actionForm", { remark: "不得落入演示" });
  observe(r4Current(h));
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(JSON.stringify(h.app.getState().data), before);
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formError").textContent, /synthetic forbidden/);
});
test("R4-C12: 旧身份详情401迟到不能撤销新身份成功会话", async () => {
  const { h, data } = await r4PrivateSession();
  let finish;
  h.context.fetch = () =>
    new Promise((r) => {
      finish = () => r(response({ message: "old synthetic revoked" }, 401));
    });
  const detail = h.app.openDetail(data.orders[0].id);
  await flush();
  const next = fixture();
  next.actor = { ...next.actor, id: "finance", role: "finance" };
  h.context.fetch = reads(next);
  await h.app.login("finance", "synthetic");
  finish();
  await detail;
  observe(r4Current(h));
  assert.equal(h.app.getState().actor.id, "finance");
  assert.ok(h.app.getState().token);
  assert.equal(h.app.getState().dataKind, "server");
});
test("R4-C13: 附件读取失败时保留当前真实表单且不发送动作", async () => {
  const { h, data } = await r4PrivateSession();
  let reader;
  h.context.FileReader = class {
    constructor() {
      reader = this;
    }
    readAsDataURL() {}
  };
  await h.app.showAction("evidence", data.orders[0].id);
  const submitted = h.submit("actionForm", {
    name: "合成附件",
    kind: "image",
    stage: "settling",
    file: { size: 10, type: "image/png" },
  });
  const before = h.calls.filter((c) => c.url.endsWith("/actions")).length;
  reader.onerror();
  await submitted;
  observe(r4Current(h));
  assert.equal(
    h.calls.filter((c) => c.url.endsWith("/actions")).length,
    before,
  );
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formError").textContent, /无法读取文件/);
});
test("R4-C14: 当前列表401按既有路径撤销会话，作为401对照组", async () => {
  const { h } = await r4PrivateSession();
  h.context.fetch = async () => response({ message: "synthetic revoked" }, 401);
  await h.app.loadOrders();
  r4ExpectRevoked(h);
});
test("R4-C15: 当前bootstrap网络失败无导航抢先时进入独立回退，作为并发失败对照组", async () => {
  const { h } = await r4PrivateSession();
  h.context.fetch = async () => {
    throw Error("synthetic offline");
  };
  await h.app.refresh();
  observe(r4Current(h));
  assert.equal(h.app.getState().dataKind, "demo");
  assert.ok(h.app.getState().token, "非401保留可信身份用于恢复");
  assert.doesNotMatch(JSON.stringify(h.app.getState().data), /PRIVATE-/);
});
test("R4-C16: 坏JSON写响应不能提示成功或迁入演示", async () => {
  const { h, data } = await r4PrivateSession();
  await h.app.showAction("remark", data.orders[0].id);
  const before = JSON.stringify(h.app.getState().data);
  h.context.fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => {
      throw SyntaxError("synthetic json");
    },
  });
  await h.submit("actionForm", { remark: "合成未知提交" });
  observe(r4Current(h));
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(JSON.stringify(h.app.getState().data), before);
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formError").textContent, /无法解析/);
});
test("R4-C17: 当前有效空bootstrap和空列表正常显示空态", async () => {
  const h = await connected(),
    data = fixture();
  data.orders = [];
  data.orderPage = { page: 1, pageSize: 30, total: 0, totalPages: 0 };
  for (const key of Object.keys(data.metrics)) data.metrics[key] = 0;
  data.parts = [];
  data.loans = [];
  data.purchases = [];
  h.context.fetch = reads(data);
  await h.app.refresh();
  observe(r4Current(h));
  assert.equal(h.app.getState().dataKind, "server");
  assert.match(h.node("#ordersEmpty").innerHTML, /暂无符合条件的工单/);
  assert.match(h.node("#ordersEmpty").innerHTML, /重新加载/);
});
test("R4-C18: 打开无关动作表单不应丢失公司配置未知提交的请求键", async () => {
  const h = await connected(),
    fields = {
      companyAddress: "合成未知提交地址",
      companyReceiver: "合成收件",
      companyPhone: "合成电话",
      reminderHours: "24",
    };
  h.context.fetch = async () => {
    throw Error("synthetic unknown commit");
  };
  await h.submit("companyForm", fields);
  const original = h.calls.findLast((c) => c.url.endsWith("/settings")).options
    .headers["Idempotency-Key"];
  h.app.createForm();
  await h.click({ close: "form" });
  await h.submit("companyForm", fields);
  const retry = h.calls.findLast((c) => c.url.endsWith("/settings")).options
    .headers["Idempotency-Key"];
  observe({
    ...r4Current(h),
    sameIdempotencyKey: original === retry,
    settingsWrites: h.calls.filter((c) => c.url.endsWith("/settings")).length,
  });
  assert.equal(
    retry,
    original,
    "公司配置未知结果的相同输入重试必须保留原键，不能被无关弹窗重置",
  );
});
test("R4-C19: 超限附件在读取前本地拒绝，不发送文件和动作", async () => {
  const { h, data } = await r4PrivateSession();
  let readerCount = 0;
  h.context.FileReader = class {
    constructor() {
      readerCount++;
    }
    readAsDataURL() {}
  };
  await h.app.showAction("evidence", data.orders[0].id);
  const before = h.calls.length;
  await h.submit("actionForm", {
    name: "合成大附件",
    kind: "image",
    stage: "settling",
    file: { size: 8 * 1024 * 1024 + 1, type: "image/png" },
  });
  observe({ ...r4Current(h), readerCount, newCalls: h.calls.length - before });
  assert.equal(readerCount, 0);
  assert.equal(h.calls.length, before);
  assert.match(h.node("#formError").textContent, /8 MB/);
});
test("R4-C20: 错误授权资料被导航抢先后不被合入，随后显式刷新可恢复", async () => {
  const h = await connected(),
    wrong = fixture();
  wrong.actor = { ...wrong.actor, id: "wrong" };
  wrong.settings.companyAddress = "WRONG-SNAPSHOT";
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((r) => {
          finish = () => r(response(wrong));
        })
      : reads()(url, options);
  const refreshing = h.app.refresh();
  await flush();
  await h.click({ view: "finance" });
  finish();
  await refreshing;
  assert.doesNotMatch(JSON.stringify(h.app.getState().data), /WRONG-SNAPSHOT/);
  h.context.fetch = reads();
  await h.app.refresh();
  observe(r4Current(h));
  assert.equal(h.app.getState().actor.id, "admin");
  assert.equal(h.app.getState().dataKind, "server");
});
test("R4-C21: 新身份bootstrap503被导航抢先后不应留在零概览的真实身份", async () => {
  const { h } = await r4PrivateSession(),
    data = fixture();
  data.actor = {
    ...data.actor,
    id: "customer",
    role: "customer",
    companyId: "company-a",
  };
  data.orders = [
    { ...data.orders[0], id: "customer-r4Current", number: "CUSTOMER-CURRENT" },
  ];
  data.parts = [];
  data.loans = [];
  data.purchases = [];
  data.metrics.remainingCents = 123;
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((r) => {
          finish = () =>
            r(response({ error: "synthetic outage", message: "合成503" }, 503));
        })
      : reads(data)(url, options);
  const login = h.app.login("customer", "synthetic");
  await flush();
  await h.click({ view: "finance" });
  finish();
  await login;
  observe(r4Current(h));
  assert.ok(
    h.app.getState().dataKind === "demo" ||
      h.app.getState().data.metrics.remainingCents === 123,
    "503应明确降级或补读，不能把未取得的概览当作0",
  );
});
test("R4-C22: 新身份bootstrap空2xx被导航抢先后不应留在零概览的真实身份", async () => {
  const { h } = await r4PrivateSession(),
    data = fixture();
  data.actor = {
    ...data.actor,
    id: "customer",
    role: "customer",
    companyId: "company-a",
  };
  data.orders = [
    { ...data.orders[0], id: "customer-r4Current", number: "CUSTOMER-CURRENT" },
  ];
  data.parts = [];
  data.loans = [];
  data.purchases = [];
  data.metrics.remainingCents = 123;
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((r) => {
          finish = () => r(response(null));
        })
      : reads(data)(url, options);
  const login = h.app.login("customer", "synthetic");
  await flush();
  await h.click({ view: "finance" });
  finish();
  await login;
  observe(r4Current(h));
  assert.ok(
    h.app.getState().dataKind === "demo" ||
      h.app.getState().data.metrics.remainingCents === 123,
    "空2xx应明确降级或补读，不能把未取得的概览当作0",
  );
});

/* Jobs · 实际演示表单与跨模块派生状态保护。 */
const r4DemoObservations = {};
async function r4DemoHarness(role = "admin") {
  const h = harness();
  await flush();
  h.context.fetch = async () => {
    throw new Error("synthetic offline only");
  };
  h.app.openDemo(role);
  return h;
}
function r4IntegerInput(h, values) {
  h.context.document.querySelectorAll = (selector) =>
    selector === "#actionForm [data-integer]"
      ? Object.entries(values).map(([name, value]) => ({
          name,
          value: String(value),
        }))
      : [];
}
async function r4GlobalSubmit(h, type, id, action, fields) {
  h.app.globalForm(type, id, action);
  if (fields.quantity != null) r4IntegerInput(h, { quantity: fields.quantity });
  await h.submit("actionForm", fields);
}
async function r4FreshRepair(h, terms = "cash") {
  h.app.createForm();
  await h.submit("actionForm", {
    type: "mail",
    customerId: "customer",
    customer: "合成现金维修客户",
    device: "合成设备",
    description: "合成业务验证",
    project: "仅测试",
    prepayChoice: "none",
  });
  const id = h.app
    .getState()
    .data.orders.find((o) => !/^demo-00\d$/.test(o.id)).id;
  for (const [type, payload] of [
    ["intake", { ownerId: "dispatcher", assigneeId: "engineer" }],
    ["diagnose", { note: "实际合成检测" }],
    [
      "quote",
      {
        amountCents: 10000,
        description: "合成方案",
        warrantyMonths: 3,
        paymentTerms: terms,
        prepayCents: 0,
        validUntil: "2099-01-01T15:59:59.000Z",
      },
    ],
    ["approve_quote", { note: "合成审核" }],
  ])
    await h.app.mutateOrder(
      h.app.getState().data.orders.find((o) => o.id === id),
      type,
      payload,
    );
  h.app.openDemo("customer");
  let o = h.app.getState().data.orders.find((o) => o.id === id);
  await h.app.mutateOrder(o, "sign_quote", {
    signature: "synthetic-demo-only",
    quoteVersion: o.quote.version,
  });
  h.app.openDemo("admin");
  return id;
}
async function r4CompletedFreshRepair(h) {
  const id = await r4FreshRepair(h, "credit");
  const act = async (type, payload) =>
    h.app.mutateOrder(
      h.app.getState().data.orders.find((o) => o.id === id),
      type,
      payload,
    );
  for (const [type, payload] of [
    ["start", { note: "合成开修" }],
    ["finish", { note: "合成完工" }],
    ["qc", { passed: true, note: "合成质检通过" }],
    [
      "deliver",
      { deliveredAt: new Date().toISOString(), note: "合成完整签收" },
    ],
  ])
    await act(type, payload);
  h.app.openDemo("customer");
  await act("accept", {
    signature: "synthetic-demo-only",
    passed: true,
    note: "合成验收",
  });
  h.app.openDemo("admin");
  await act("requirements", {
    documentRequirement: "none",
    documentReason: "合成无需资料",
    invoiceRequirement: "none",
    invoiceReason: "合成无需票据",
    invoiceDueCents: 0,
  });
  await act("cash", {
    kind: "receipt",
    amountCents: 10000,
    occurredAt: new Date().toISOString(),
    purpose: "合成收款",
    note: "合成凭据",
  });
  const cashId = h.app.getState().data.orders.find((o) => o.id === id)
    .cash[0].id;
  await act("verify_cash", { cashId, note: "合成财务核实" });
  await act("handover_cash", { cashId, note: "合成交接核实" });
  await act("complete", { note: "合成负责人完结核对" });
  assert.equal(
    h.app.getState().data.orders.find((o) => o.id === id).status,
    "completed",
  );
  return id;
}

test("R4-D09: 未结算提成阻止整单完结（实际 app 动作）", async () => {
  const h = await r4DemoHarness();
  const id = "demo-003";
  await h.app.mutateOrder(
    h.app.getState().data.orders.find((o) => o.id === id),
    "commission",
    { person: "合成提成人员", amountCents: 100, note: "合成批准依据" },
  );
  const o = h.app.getState().data.orders.find((o) => o.id === id);
  assert.equal(o.commissions[0].settled, false);
  await assert.rejects(
    () => h.app.mutateOrder(o, "complete", { note: "合成未结算提成完结测试" }),
    /阶段|提成|完结/,
  );
  const completed = h.app.getState().data.orders.find((o) => o.id === id);
  r4DemoObservations.unsettledCommission = {
    beforeCompletion: o.status,
    afterCompletion: completed.status,
    commission: completed.commissions[0],
    missing: Array.from(completed.summary.missing),
  };
  assert.equal(o.status, "settling", "提成待结算但主阶段为 " + o.status);
  assert.ok(o.summary.missing.some((s) => /提成/.test(s)));
});
test("R4-D11: 重开必须停留结算并保留未完成复核事项（实际 app 表单）", async () => {
  const h = await r4DemoHarness();
  const id = "demo-003";
  await h.app.mutateOrder(
    h.app.getState().data.orders.find((o) => o.id === id),
    "complete",
    { note: "合成核对" },
  );
  await h.app.showAction("reopen", id);
  await h.submit("actionForm", { reason: "合成付款凭证需要重新核查" });
  const o = h.app.getState().data.orders.find((o) => o.id === id);
  r4DemoObservations.reopen = {
    actualStatus: o.status,
    obligations: o.obligations,
    available: h.app.available(o),
  };
  assert.equal(o.status, "settling", "重开后立即回到 " + o.status);
  assert.ok(
    o.obligations.some((t) => !t.resolved && /重开|复核/.test(t.title)),
  );
});
test("R4-D12: 新返修单不能继承已完结旧单应收（实际 app 完整新单链）", async () => {
  const h = await r4DemoHarness();
  const id = await r4CompletedFreshRepair(h);
  const original = h.app.getState().data.orders.find((o) => o.id === id);
  await h.app.showAction("rework", id);
  await h.submit("actionForm", { free: "true", note: "合成免费返修" });
  const child = h.app
    .getState()
    .data.orders.find((o) => o.originalOrderId === id);
  r4DemoObservations.reworkFinancial = {
    original: {
      status: original.status,
      receivableCents: original.receivableCents,
      collectedCents: D.derive(original).collectedCents,
    },
    child: {
      status: child.status,
      quoteAmountCents: child.quote.amountCents,
      receivableCents: child.receivableCents,
      cashCount: child.cash.length,
      cachedSummary: child.summary,
      recalculatedSummary: D.derive(child),
      warranty: child.warranty,
    },
  };
  assert.equal(child.quote.amountCents, 0);
  assert.equal(
    D.derive(child).receivableCents,
    0,
    "子单重新待受理但应收仍为 " + D.derive(child).receivableCents,
  );
});
test("R4-D13: 未验收返修单不能继承旧质保与旧外包流向（实际 app 表单）", async () => {
  const h = await r4DemoHarness();
  const id = "demo-003";
  await h.app.mutateOrder(
    h.app.getState().data.orders.find((o) => o.id === id),
    "outsource",
    {
      provider: "合成旧单外包机构",
      contact: "合成联系人",
      destination: "合成旧流向",
      note: "原单事实",
    },
  );
  await h.app.mutateOrder(
    h.app.getState().data.orders.find((o) => o.id === id),
    "complete",
    { note: "合成核对" },
  );
  await h.app.showAction("rework", id);
  await h.submit("actionForm", { free: "true", note: "合成免费返修" });
  const child = h.app
    .getState()
    .data.orders.find((o) => o.originalOrderId === id);
  assert.ok(child);
  r4DemoObservations.reworkCopiedFields = {
    status: child.status,
    outsource: child.outsource,
    warranty: child.warranty,
    warrantyLabel: D.derive(child).warrantyLabel,
  };
  assert.equal(child.status, "pending_intake");
  assert.equal(child.outsource.length, 0, "新子单继承旧外包");
  assert.equal(D.derive(child).warrantyLabel, "质保未起算");
});
test("R4-D14: 部分独立跟踪只解除对应数量的工单阻塞（实际 app 全局表单）", async () => {
  const h = await r4DemoHarness();
  await r4GlobalSubmit(h, "loan", "", "", {
    partId: "demo-part-1",
    quantity: "2",
    orderId: "demo-003",
    borrowerId: "engineer",
    dueAt: "2099-01-01",
    note: "合成部分转出借用",
  });
  const loan = h.app.getState().data.loans.find((l) => l.id !== "demo-loan-1");
  assert.equal(loan.outstanding, 2);
  await r4GlobalSubmit(h, "loanAction", loan.id, "transfer", {
    quantity: "1",
    reason: "合成部分转独立跟踪",
    ownerId: "engineer",
    dueAt: "2099-01-01",
  });
  const state = h.app.getState().data;
  const next = state.loans.find((l) => l.id === loan.id);
  r4DemoObservations.partialTransfer = {
    quantity: next.quantity,
    outstanding: next.outstanding,
    transferred: next.transferred,
    transfer: next.transfer,
    blocked: D.derive(
      state.orders.find((o) => o.id === next.orderId),
      state.loans,
    ).missing.includes("关联借用配件未清"),
  };
  assert.equal(next.outstanding, 2);
  assert.ok(
    D.derive(
      state.orders.find((o) => o.id === next.orderId),
      state.loans,
    ).missing.includes("关联借用配件未清"),
    "仅转 1/2 件后全部关联借用阻塞被解除",
  );
});
test("R4-D15: 最后关联借用归还后主阶段同步到待完结（真实 app 全局表单）", async () => {
  const h = await r4DemoHarness();
  // Synthetic boundary fixture: acceptance-ready order with the seed outstanding loan.
  const demo = h.app.getDemo();
  const source = demo.orders.find((o) => o.id === "demo-004");
  source.status = "pending_acceptance";
  source.documents.requirement = "none";
  source.invoiceRequirement = "none";
  source.cash = [
    {
      id: "synthetic-paid",
      amountCents: source.quote.amountCents,
      kind: "receipt",
      verified: true,
      handedOver: true,
    },
  ];
  h.app.openDemo("customer");
  await h.app.mutateOrder(
    h.app.getState().data.orders.find((o) => o.id === source.id),
    "accept",
    { passed: true, signature: "synthetic-demo-only", note: "合成客户验收" },
  );
  h.app.openDemo("admin");
  let o = h.app.getState().data.orders.find((o) => o.id === source.id);
  assert.equal(o.status, "settling");
  assert.deepEqual(Array.from(o.summary.missing), ["关联借用配件未清"]);
  const loan = h.app.getState().data.loans.find((l) => l.orderId === source.id);
  await r4GlobalSubmit(h, "loanAction", loan.id, "return", {
    quantity: String(loan.outstanding),
    condition: "good",
  });
  o = h.app.getState().data.orders.find((o) => o.id === source.id);
  r4DemoObservations.loanClearedStage = {
    status: o.status,
    missing: Array.from(o.summary.missing),
    available: h.app.available(o),
    outstanding: h.app.getState().data.loans.find((l) => l.id === loan.id)
      .outstanding,
  };
  assert.equal(o.summary.missing.length, 0);
  assert.equal(
    o.status,
    "pending_completion",
    "缺项已清而主阶段仍为 " + o.status,
  );
  assert.ok(h.app.available(o).includes("complete"));
});
test("R4-D16: 采购分批收货库存守恒（正对照）", async () => {
  const h = await r4DemoHarness();
  h.app.globalForm("purchase");
  h.context.document.querySelectorAll = (selector) =>
    selector === "#actionForm [data-integer]"
      ? [{ name: "quantity", value: "3" }]
      : selector === "#actionForm [data-cents]"
        ? [{ name: "unitCents", value: "5.00", hasAttribute: () => true }]
        : [];
  await h.submit("actionForm", {
    supplier: "合成供应商",
    partId: "demo-part-1",
    quantity: "3",
    unitCents: "5.00",
    note: "合成采购",
  });
  const purchase = h.app.getState().data.purchases[0];
  const before = h.app
    .getState()
    .data.parts.find((p) => p.id === purchase.partId).available;
  await r4GlobalSubmit(h, "purchaseReceive", purchase.id, "", {
    quantity: "1",
    note: "合成实收",
  });
  const state = h.app.getState().data;
  assert.equal(state.purchases[0].received, purchase.received + 1);
  assert.equal(
    state.parts.find((p) => p.id === purchase.partId).available,
    before + 1,
  );
});
test("R4-D17: 采购超收失败不改变库存或采购版本（正对照）", async () => {
  const h = await r4DemoHarness();
  h.app.globalForm("purchase");
  h.context.document.querySelectorAll = (selector) =>
    selector === "#actionForm [data-integer]"
      ? [{ name: "quantity", value: "3" }]
      : selector === "#actionForm [data-cents]"
        ? [{ name: "unitCents", value: "5.00", hasAttribute: () => true }]
        : [];
  await h.submit("actionForm", {
    supplier: "合成供应商",
    partId: "demo-part-1",
    quantity: "3",
    unitCents: "5.00",
    note: "合成采购",
  });
  const purchase = h.app.getState().data.purchases[0];
  const before = JSON.stringify(h.app.getState().data);
  await r4GlobalSubmit(h, "purchaseReceive", purchase.id, "", {
    quantity: String(purchase.quantity + 1),
    note: "合成超收",
  });
  assert.equal(JSON.stringify(h.app.getState().data), before);
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formError").textContent, /超过/);
});
test("R4-D18: 完好归还借用保持数量守恒并增加可用库存（正对照）", async () => {
  const h = await r4DemoHarness();
  const loan = h.app.getState().data.loans[0];
  const before = h.app
    .getState()
    .data.parts.find((p) => p.id === loan.partId).available;
  await r4GlobalSubmit(h, "loanAction", loan.id, "return", {
    quantity: "1",
    condition: "good",
  });
  const state = h.app.getState().data;
  const next = state.loans[0];
  assert.equal(
    next.quantity,
    next.returnedGood +
      next.returnedQuarantine +
      next.consumed +
      next.disposed +
      next.outstanding,
  );
  assert.equal(next.outstanding, loan.outstanding - 1);
  assert.equal(
    state.parts.find((p) => p.id === loan.partId).available,
    before + 1,
  );
});

test("R4-C23: bootstrap所有渲染嵌套记录在采用前校验，坏记录不留下半套真实状态且刷新可恢复", async () => {
  const changes = [
    (v) => {
      v.parts = [null];
    },
    (v) => {
      v.parts[0].available = "坏数量";
    },
    (v) => {
      v.loans = [null];
    },
    (v) => {
      v.loans[0].dueAt = "坏日期";
    },
    (v) => {
      v.loans[0].transfers = [null];
    },
    (v) => {
      v.purchases = [null];
    },
    (v) => {
      v.orders[0].summary.missing = null;
    },
    (v) => {
      v.orders[0].summary.missing = [null];
    },
    (v) => {
      v.orders[0].allowedActions = [null];
    },
    (v) => {
      v.orders[0].quote.validUntil = "坏日期";
    },
    (v) => {
      v.orders[0].documents.files = {};
    },
    (v) => {
      v.orders[0].events = [null];
    },
    (v) => {
      v.orders[0].events[0].createdAt = "坏日期";
    },
    (v) => {
      v.orders[0].warranty.endsAt = "坏日期";
    },
  ];
  for (const change of changes) {
    const h = await connected(),
      bad = fixture();
    change(bad);
    h.context.fetch = reads(bad);
    await assert.doesNotReject(() => h.app.refresh());
    assert.equal(h.app.getState().dataKind, "demo");
    assert.equal(h.app.getState().cachedDetailIds.length, 0);
    assert.match(h.node("#connectionNote").textContent, /格式|响应/);
    h.context.fetch = reads();
    await h.app.refresh();
    assert.equal(h.app.getState().dataKind, "server");
  }
});

test("R4-C24: 详情各记录数组拒绝空条目和非法日期，错误完整可重试且坏详情不进cache", async () => {
  const changes = [
    ...[
      "invoices",
      "cash",
      "evidence",
      "events",
      "visits",
      "outsource",
      "costs",
      "commissions",
      "issues",
      "obligations",
      "quoteHistory",
      "acceptanceRecords",
    ].map((name) => (o) => {
      o[name] = [null];
    }),
    (o) => {
      o.visits = [{ id: "bad-date", plannedAt: "坏日期" }];
    },
    (o) => {
      delete o.summary.missing;
    },
    (o) => {
      o.quote.startRequiresPrepayment = "true";
    },
  ];
  for (const change of changes) {
    const h = await connected(),
      bad = fixture().orders[0];
    change(bad);
    h.context.fetch = async () => response(bad);
    await assert.doesNotReject(() => h.app.openDetail(bad.id));
    assert.match(h.node("#detailContent").innerHTML, /工单详情未加载/);
    assert.match(h.node("#detailContent").innerHTML, /重新加载/);
    assert.equal(h.app.getState().cachedDetailIds.length, 0);
    h.context.fetch = reads();
    await h.app.openDetail(bad.id);
    assert.doesNotMatch(
      h.node("#detailContent").innerHTML,
      /工单详情未加载|正在读取完整工单/,
    );
  }
});

test("R4-C25: 坏JSON的当前401仍撤销，旧身份附件401与旧详情401均不撤销新身份", async () => {
  for (const route of ["json401", "late-attachment", "late-detail"]) {
    const { h, data } = await r4PrivateSession();
    if (route === "json401") {
      h.context.fetch = async () => ({
        ok: false,
        status: 401,
        json: async () => {
          throw SyntaxError("bad 401 json");
        },
      });
      await h.app.openDetail(data.orders[0].id);
      r4ExpectRevoked(h);
      continue;
    }
    let finish;
    h.context.fetch = () =>
      new Promise((resolve) => {
        finish = () => resolve(response({ message: "旧会话" }, 401));
      });
    const pending =
      route === "late-attachment"
        ? h.app.previewFile("synthetic", data.orders[0].id)
        : h.app.openDetail(data.orders[0].id);
    await flush();
    h.context.fetch = reads(customerFixture());
    await h.app.login("customer", "synthetic");
    finish();
    await pending;
    assert.equal(h.app.getState().data.actor.id, "customer");
    assert.equal(h.app.getState().dataKind, "server");
    assert.ok(h.app.getState().token);
  }
});

test("R4-C26: 导航取代旧/orders错误时，成功bootstrap仍补元数据并保留最新页", async () => {
  const h = await connected(),
    live = fixture();
  live.metrics.remainingCents = 234;
  let failOld,
    count = 0;
  h.context.fetch = (url, options) => {
    if (url.includes("/orders?")) {
      if (++count === 1)
        return new Promise((_resolve, reject) => {
          failOld = () => reject(Error("旧筛选离线"));
        });
      return response({
        items: [{ ...live.orders[0], id: "latest-current-page" }],
        page: 1,
        pageSize: 30,
        total: 1,
        totalPages: 1,
      });
    }
    return reads(live)(url, options);
  };
  const refresh = h.app.refresh();
  await flush();
  await h.click({ view: "finance" });
  failOld();
  await refresh;
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().data.orders[0].id, "latest-current-page");
  assert.equal(h.app.getState().data.metrics.remainingCents, 234);
});

test("R4-D21: 部分转出后先归还独立件仍阻塞原工单，超量二次转出原子拒绝，全部清零才能待完结", async () => {
  const h = await r4DemoHarness();
  await r4GlobalSubmit(h, "loan", "", "", {
    partId: "demo-part-1",
    quantity: "2",
    orderId: "demo-003",
    borrowerId: "engineer",
    dueAt: "2099-01-01",
    note: "合成",
  });
  const loan = h.app.getState().data.loans.find((l) => l.id !== "demo-loan-1");
  await r4GlobalSubmit(h, "loanAction", loan.id, "transfer", {
    quantity: "1",
    reason: "合成批准",
    ownerId: "engineer",
    dueAt: "2099-01-01",
  });
  assert.equal(
    h.app.getState().data.orders.find((o) => o.id === "demo-003").status,
    "settling",
  );
  const before = JSON.stringify(h.app.getState().data);
  await r4GlobalSubmit(h, "loanAction", loan.id, "transfer", {
    quantity: "2",
    reason: "重复超量",
    ownerId: "engineer",
    dueAt: "2099-01-01",
  });
  assert.equal(JSON.stringify(h.app.getState().data), before);
  assert.match(h.node("#formError").textContent, /未转|超过/);
  await r4GlobalSubmit(h, "loanAction", loan.id, "return", {
    quantity: "1",
    condition: "good",
  });
  const state = h.app.getState().data,
    next = state.loans.find((l) => l.id === loan.id);
  assert.equal(next.outstanding, 1);
  assert.equal(next.transfers[0].quantity, 0);
  assert.ok(
    state.orders
      .find((o) => o.id === "demo-003")
      .summary.missing.includes("关联借用配件未清"),
  );
  await r4GlobalSubmit(h, "loanAction", loan.id, "return", {
    quantity: "1",
    condition: "good",
  });
  const order = h.app.getState().data.orders.find((o) => o.id === "demo-003");
  assert.equal(order.status, "pending_completion");
  assert.ok(h.app.available(order).includes("complete"));
});

test("R4-X01/UI: 维修报价默认未约定先款，明确选择后提交bool，零预付在本地拒绝", async () => {
  for (const option of [undefined, "false", "true"]) {
    const h = await connected(),
      order = fixture().orders[3],
      writes = [];
    h.context.fetch = (url, options) => {
      if (url.endsWith("/actions")) {
        writes.push(JSON.parse(options.body).payload);
        return response({
          ...order,
          quote: { ...order.quote, ...writes.at(-1) },
        });
      }
      return reads()(url, options);
    };
    await h.app.showAction("quote", order.id);
    assert.match(
      h.node("#formContent").innerHTML,
      /维修开修前是否明确约定先款/,
    );
    assert.match(
      h.node("#formContent").innerHTML,
      /value="false" selected>未约定先款/,
    );
    const fields = {
      amountCents: "100.00",
      prepayCents: "20.00",
      warrantyMonths: "3",
      paymentTerms: "cash",
      validUntil: "2099-01-01",
      autoAccept: "false",
      description: "合成维修报价",
    };
    if (option !== undefined) fields.startRequiresPrepayment = option;
    h.context.document.querySelectorAll = (selector) =>
      selector === "#actionForm [data-cents]"
        ? ["amountCents", "prepayCents"].map((name) => ({
            name,
            value: fields[name],
            hasAttribute: () => name === "amountCents",
          }))
        : [];
    if (option === "true") {
      fields.prepayCents = "0.00";
      await h.submit("actionForm", fields);
      assert.equal(writes.length, 0);
      assert.match(h.node("#formError").textContent, /大于零/);
      fields.prepayCents = "20.00";
    }
    await h.submit("actionForm", fields);
    assert.equal(writes.length, 1);
    assert.equal(writes[0].startRequiresPrepayment, option === "true");
    assert.equal(writes[0].prepayCents, 2000);
  }
});

test("R4-X01/签署: 当前先款约定与预付金额在详情及客户签署前可见，销售不发送维修开关", async () => {
  for (const required of [false, true]) {
    const h = await connected(),
      live = fixture(),
      order = live.orders[0];
    order.quote.startRequiresPrepayment = required;
    order.quote.prepayCents = 2000;
    h.context.fetch = reads(live);
    await h.app.openDetail(order.id, "quote");
    assert.match(
      h.node("#detailContent").innerHTML,
      required ? /明确约定先款/ : /未约定先款开修/,
    );
    canvasFor(h);
    h.app.showSignature("sign_quote", order);
    assert.match(
      h.node("#formContent").innerHTML,
      required
        ? /明确约定先款：核实约定预付款.*20\.00.*后开修/
        : /未约定先款开修/,
    );
  }
  const h = await connected(),
    live = fixture(),
    order = live.orders[0];
  order.type = "sale";
  h.context.fetch = reads(live);
  await h.app.showAction("quote", order.id);
  assert.doesNotMatch(
    h.node("#formContent").innerHTML,
    /name="startRequiresPrepayment"/,
  );
});

test("R4-B03/UI: 人工失败和后来通过均独立展示，原签名为只读且不产生写请求", async () => {
  const h = await connected(),
    live = fixture(),
    order = live.orders[0];
  order.acceptanceRecords = [false, true].map((passed, index) => ({
    id: "acceptance-" + index,
    passed,
    signature: "data:image/png;base64,c3ludGhldGlj",
    signerId: "customer",
    signerName: "合成经办人",
    signedAt: "2026-10-15T01:00:00Z",
    note: passed ? "后来整改通过" : "首次测试未通过",
    quoteVersion: 1,
    orderVersion: 2 + index,
  }));
  h.context.fetch = reads(live);
  await h.app.openDetail(order.id);
  const html = h.node("#detailContent").innerHTML;
  assert.match(html, /验收未通过（异议）/);
  assert.match(html, /首次测试未通过/);
  assert.match(html, /验收通过/);
  assert.match(html, /后来整改通过/);
  const before = h.calls.length;
  await h.click({ acceptanceSignature: "acceptance-0", order: order.id });
  assert.match(h.node("#formContent").innerHTML, /验收未通过（异议）/);
  assert.match(h.node("#formContent").innerHTML, /客户原始手写签名/);
  assert.doesNotMatch(
    h.node("#formContent").innerHTML,
    /type="submit"|确认本次事实/,
  );
  await h.submit("actionForm", {});
  assert.equal(h.calls.length, before);
});

test("R4-C27: 当前身份metadata仍待加载时概览明确占位，导航成功列表不把未知指标显示为真实零", async () => {
  const h = await connected(),
    live = customerFixture();
  let finish;
  h.context.fetch = (url, options) =>
    url.endsWith("/bootstrap")
      ? new Promise((resolve) => {
          finish = () => resolve(response(live));
        })
      : reads(live)(url, options);
  const login = h.app.login("customer", "synthetic");
  await flush();
  await h.click({ view: "finance" });
  assert.match(h.node("#metrics").innerHTML, /当前概览尚未加载/);
  assert.match(h.node("#metrics").innerHTML, /待加载/);
  assert.doesNotMatch(h.node("#metrics").innerHTML, /¥0\.00|￥0\.00/);
  finish();
  await login;
  assert.doesNotMatch(h.node("#metrics").innerHTML, /待加载/);
  assert.equal(h.app.getState().data.metrics.remainingCents, 123);
});

test("R4-C28: 服务端未报价新单的零值Quote与nil记录有效，真实新建成功且后续首屏不误回退", async () => {
  const h = await connected(),
    live = fixture(),
    fresh = {
      ...live.orders[0],
      id: "new-unquoted",
      number: "WX-ZERO-QUOTE",
      status: "pending_intake",
      outcome: "",
      quote: {
        version: 0,
        amountCents: 0,
        description: "",
        warrantyMonths: 0,
        paymentTerms: "",
        prepayCents: 0,
        validUntil: "",
        approved: false,
        signed: false,
        autoAccept: false,
        startRequiresPrepayment: false,
      },
      warranty: { startsAt: "", endsAt: "" },
      summary: {
        ...live.orders[0].summary,
        collectedCents: 0,
        receivableCents: 0,
        remainingCents: 0,
        invoiceCents: 0,
        missing: ["尚未形成有效履约结果"],
      },
    };
  for (const key of [
    "invoices",
    "cash",
    "evidence",
    "events",
    "visits",
    "outsource",
    "costs",
    "commissions",
    "issues",
    "obligations",
    "quoteHistory",
  ])
    fresh[key] = null;
  h.context.fetch = (url, options) => {
    if (url.endsWith("/orders") && options.method === "POST") {
      live.orders = [fresh];
      live.orderPage = { page: 1, pageSize: 30, total: 1, totalPages: 1 };
      return response(fresh);
    }
    return reads(live)(url, options);
  };
  h.app.createForm();
  await h.submit("actionForm", {
    type: "mail",
    customer: "合成未报价客户",
    device: "合成设备",
    description: "合成登记",
  });
  assert.equal(h.node("#formDialog").open, false);
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().data.orders[0].id, fresh.id);
  await h.app.openDetail(fresh.id);
  assert.doesNotMatch(h.node("#detailContent").innerHTML, /工单详情未加载/);
});

test("R4-C29: 仅未报价version0允许零月份占位，正式报价version正数的零/负/非整数月份仍拒绝", async () => {
  for (const months of [0, -1, 1.5, "3"]) {
    const h = await connected(),
      bad = fixture();
    bad.orders[0].quote.version = 1;
    bad.orders[0].quote.warrantyMonths = months;
    h.context.fetch = reads(bad);
    await h.app.refresh();
    assert.equal(h.app.getState().dataKind, "demo");
    h.context.fetch = reads();
    await h.app.refresh();
    assert.equal(h.app.getState().dataKind, "server");
  }
});
