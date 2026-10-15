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
    `\n globalThis.__app = { request, mutateOrder, previewFile, login, refresh, loadOrders, openDetail, showAction, accountStatusForm, createForm, globalForm, openDemo, normalizeBase, getState: () => ({data, actor, dataKind, connected, page, token}), setPage: (value) => {page = value;} };\n})();`,
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


// 以下测试调用真实 app.js；失败断言记录独立复核确认的用户可见行为缺陷。
test("F01: 旧账号表单提交迟到，应保留随后打开的新建工单表单", async () => {
  const h = await connected(); let finish;
  h.context.fetch = () => new Promise((resolve) => { finish = resolve; });
  h.app.accountStatusForm("customer", "disabled");
  const submitted = h.submit("actionForm", { reason: "合成授权依据" });
  h.node("#formDialog").close();
  h.app.createForm();
  assert.equal(h.node("#formDialog").open, true);
  assert.match(h.node("#formContent").innerHTML, /新建维修/);
  finish(response({ id: "customer", role: "customer", status: "disabled", authVersion: 2 }));
  await submitted;
  assert.equal(h.node("#formDialog").open, true, "同一身份下，旧提交不应关闭新的工单表单");
});

test("F02: 办理前的详情读取迟到，导航到财务后不应打开旧备注表单", async () => {
  const h = await connected(); let finish;
  const delegate = reads();
  h.context.fetch = (url, options) => /^\/api\/v38\/orders\/[^/?]+$/.test(url)
    ? new Promise((resolve) => { finish = resolve; }) : delegate(url, options);
  const action = h.app.showAction("remark", fixture().orders[0].id);
  await h.click({ view: "finance" });
  assert.equal(h.node("#formDialog").open, false);
  finish(response(fixture().orders[0]));
  await action;
  assert.equal(h.node("#formDialog").open, false, "切换业务视图后，旧动作读取不应弹出原视图的表单");
});

test("F03: 两次公司配置保存都成功后，较早刷新不得把新配置显示为旧配置", async () => {
  const h = await connected(), live = fixture(); let finishFirstBootstrap;
  const fields = (address) => ({ companyAddress: address, companyReceiver: "合成", companyPhone: "合成", reminderHours: "24" });
  let writes = 0;
  h.context.fetch = async (url, options) => {
    if (url.endsWith("/settings")) {
      writes++;
      live.settings = JSON.parse(options.body);
      return response(live.settings);
    }
    if (url.endsWith("/bootstrap") && writes === 1) {
      const first = structuredClone(live);
      return new Promise((resolve) => { finishFirstBootstrap = () => resolve(response(first)); });
    }
    return reads(live)(url, options);
  };
  const first = h.submit("companyForm", fields("地址 A"));
  await flush();
  assert.equal(typeof finishFirstBootstrap, "function");
  await h.submit("companyForm", fields("地址 B"));
  assert.equal(live.settings.companyAddress, "地址 B");
  finishFirstBootstrap(); await first;
  assert.equal(h.app.getState().data.settings.companyAddress, "地址 B", "已确认后一次保存成功，旧刷新不能显示地址 A");
});

test("F04: 403/409/422 写入拒绝与未知写入均不转入真实身份的模拟事实", async () => {
  for (const status of [403, 409, 422, 0]) {
    const h = await connected();
    const order = fixture().orders[0];
    const before = structuredClone(h.app.getState().data.orders);
    h.context.fetch = async () => { if (!status) throw Error("transport failed"); return response({ message: "合成拒绝" }, status); };
    await assert.rejects(h.app.mutateOrder(order, "remark", { note: "不得假成功" }));
    assert.equal(h.app.getState().dataKind, "server");
    assert.deepEqual(JSON.parse(JSON.stringify(h.app.getState().data.orders)), before);
  }
});

test("F05: 合成离线写入与接口恢复保持数据来源独立", async () => {
  const h = harness(); await flush();
  h.app.openDemo("dispatcher");
  h.context.fetch = async () => { throw Error("offline"); };
  const order = D.seed().orders[0];
  await h.app.mutateOrder(order, "remark", { note: "独立演示备注" });
  assert.equal(h.app.getState().dataKind, "demo");
  assert.match(h.node("#toast").textContent, /独立合成演示/);
  h.context.fetch = reads();
  await h.app.login("admin", "synthetic");
  assert.equal(h.app.getState().dataKind, "server");
  assert.equal(h.app.getState().actor.id, "admin");
  assert.doesNotMatch(JSON.stringify(h.app.getState().data.orders), /独立演示备注/);
});

test("F06: 借出未知响应不假成功，同一表单重试保留相同请求键", async () => {
  const h = await connected();
  h.app.globalForm("loan");
  h.context.fetch = async () => { throw Error("unknown commit"); };
  const fields = { partId: fixture().parts[0].id, quantity: "1", borrowerId: "engineer", orderId: "", dueAt: "2026-10-15", note: "合成借出" };
  await h.submit("actionForm", fields);
  const one = h.calls.at(-1);
  assert.equal(h.node("#formDialog").open, true);
  await h.submit("actionForm", fields);
  const two = h.calls.at(-1);
  assert.equal(one.options.headers["Idempotency-Key"], two.options.headers["Idempotency-Key"]);
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
  h.context.fetch = async () => ({ ok: true, status: 200, json: async () => { throw Error("malformed JSON"); } });
  await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "demo");
  h.context.fetch = reads(); await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "server");
  h.context.fetch = async () => response(null);
  await h.app.refresh();
  assert.equal(h.app.getState().dataKind, "demo");
});

test("F10: 下载原件迟到至身份切换之后不会生成旧身份下载", async () => {
  const h = await connected(); let finish;
  h.context.fetch = () => new Promise((resolve) => { finish = resolve; });
  const download = h.app.previewFile("evidence-synthetic", fixture().orders[0].id);
  h.app.openDemo("customer");
  finish({ ok: true, blob: async () => new Blob(["synthetic evidence"]) });
  await download;
  assert.equal(h.app.getState().actor.role, "customer");
  assert.doesNotMatch(h.node("#toast").textContent, /未生成替代原件/);
});

test("F11: 真正 fetch AbortSignal 超时会结束读取，独立合成回退保留可预览界面", async () => {
  const h = await connected();
  await h.submit("connectionForm", { base: "", timeout: "500" });
  h.context.fetch = (_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener("abort", () => { const error = Error("abort"); error.name = "AbortError"; reject(error); }, { once: true });
  });
  const began = Date.now();
  // 维持真实定时器的 event loop，诊断 harness 的超时定时器使用 unref。
  const keepAlive = setTimeout(() => {}, 1000);
  await h.app.refresh(); clearTimeout(keepAlive);
  assert.equal(h.app.getState().dataKind, "demo");
  assert.ok(Date.now() - began >= 450 && Date.now() - began < 900);
  assert.match(h.node("#connectionNote").textContent, /连接超时/);
});
