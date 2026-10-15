const ICONFONT_LOGO_URL = "https://img.alicdn.com/imgextra/i4/O1CN01XZe8pH1USpiUNT1QN_!!6000000002517-2-tps-114-114.png";
const LOCAL_LOGO_URL = "./assets/RepairLogo.png";
const DEMO_SEED = {
  orders: [
    {
      id: "demo-refrigerator-001",
      customerId: "customer-demo",
      workerId: "",
      category: "家电维修",
      equipment: "冰箱 · 海尔",
      issue: "冷藏室不制冷，冷冻室结霜较多",
      address: "上海市浦东新区世纪大道 100 号",
      scheduledAt: "今天 14:00",
      status: "pending_worker",
      paymentStatus: "not_started",
      quotedAmountCents: 0,
      platformFeeCents: 0,
      workerShareCents: 0
    },
    {
      id: "demo-water-heater-002",
      customerId: "customer-demo",
      workerId: "worker-demo",
      category: "家电维修",
      equipment: "热水器 · 美的",
      issue: "热水温度不稳定，需要检查温控器",
      address: "上海市浦东新区张江路 88 号",
      scheduledAt: "今天 16:30",
      status: "awaiting_payment",
      paymentStatus: "not_started",
      quotedAmountCents: 26800,
      platformFeeCents: 4020,
      workerShareCents: 22780
    }
  ],
  workers: [
    {
      id: "worker-demo",
      displayName: "演示师傅 王师傅",
      status: "active",
      skills: ["家电维修", "热水器维修"],
      serviceAreas: ["上海市浦东新区"]
    }
  ],
  settlements: []
};

let DEMO_DATA = structuredClone(DEMO_SEED);
let displayedData = {};
let refreshRevision = 0;
const pendingActions = new Set();
const environmentInput = document.querySelector("#apiEnvironment");
const baseInput = document.querySelector("#apiBase");
const copyBaseButton = document.querySelector("#copyBase");
const copyState = document.querySelector("#copyState");
let copyRevision = 0;
const connectionState = document.querySelector("#connectionState");
const ordersBody = document.querySelector("#ordersBody");
const workersRoot = document.querySelector("#workers");
const settlementsRoot = document.querySelector("#settlements");
const metricsRoot = document.querySelector("#metrics");
const orderCount = document.querySelector("#orderCount");
const actionState = document.querySelector("#actionState");
function syncEnvironmentFields() {
  environmentInput.value = currentEnvironment;
  baseInput.value = activeAPIBase();
  baseInput.disabled = currentEnvironment === "production";
  syncCopyButton();
}

syncEnvironmentFields();

function syncCopyButton() {
  copyRevision += 1;
  copyBaseButton.disabled = !baseInput.value.trim();
  copyState.textContent = "";
}

function copyWithSelection(value) {
  // HTTP 局域网页面可能没有 Clipboard API，保留选区复制兼容入口。
  const previousFocus = document.activeElement;
  const field = document.createElement("textarea");
  field.value = value;
  field.readOnly = true;
  field.style.cssText = "position:fixed;left:0;top:0;opacity:0;pointer-events:none";
  document.body.appendChild(field);
  try {
    field.select();
    if (!document.execCommand("copy")) throw new Error("Copy unavailable");
  } finally {
    field.remove();
    previousFocus?.focus({ preventScroll: true });
  }
}

async function copyAPIBase() {
  const value = baseInput.value.trim();
  if (!value) return;
  const revision = copyRevision;
  copyBaseButton.disabled = true;
  try {
    if (window.isSecureContext && navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(value);
      } catch (_) {
        copyWithSelection(value);
      }
    } else {
      copyWithSelection(value);
    }
    if (revision === copyRevision) copyState.textContent = "头 URL 已复制";
  } catch (_) {
    if (revision === copyRevision) copyState.textContent = "复制失败，请选中地址手动复制";
  } finally {
    if (revision === copyRevision) copyBaseButton.disabled = !baseInput.value.trim();
  }
}

function apiBase() {
  const base = activeAPIBase();
  if (!base) throw new APIRequestError("线上地址未配置", "configuration");
  return normalizeAPIBase(base);
}

function money(cents) {
  return new Intl.NumberFormat("zh-CN", {
    style: "currency",
    currency: "CNY"
  }).format((Number(cents) || 0) / 100);
}

function safe(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[character]);
}

function statusName(status) {
  return ({
    pending_worker: "待接单",
    accepted: "已接单",
    arrived: "已到场",
    quote_pending: "报价待确认",
    in_service: "维修中",
    awaiting_payment: "待收款",
    completed: "已完成",
    cancelled: "已取消"
  })[status] || status;
}

class APIRequestError extends Error {
  constructor(message, kind, status = 0, code = "") {
    super(message);
    this.name = "APIRequestError";
    this.kind = kind;
    this.status = status;
    this.code = code;
  }
}

async function request(path, options = {}) {
  const { onResponse, responseType, ...fetchOptions } = options;
  const authHeaders = typeof AdminSession === "undefined" ? {} : AdminSession.headers();
  const authRevision = typeof AdminSession === "undefined" ? 0 : AdminSession.revision;
  const controller = new AbortController();
  let timeoutID;
  const deadline = new Promise((_, reject) => {
    timeoutID = window.setTimeout(() => {
      reject(new APIRequestError("请求超时", "unknown"));
      controller.abort();
    }, API_REQUEST_TIMEOUT_MS);
  });
  try {
    const operation = (async () => {
      const response = await fetch(apiBase() + path, {
        ...fetchOptions,
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          ...authHeaders,
          ...(options.headers || {})
        }
      });
      if (onResponse) onResponse(response);
      if (!response.ok) {
        if (response.status === 401 && authHeaders.Authorization) AdminSession.clear(authRevision);
        const data = await response.json().catch(() => ({}));
        const detail = data && typeof data === "object" ? data : {};
        throw new APIRequestError(detail.message || detail.error || ("HTTP " + response.status),
          response.status < 500 ? "rejected" : "unknown", response.status, detail.code || "");
      }
      if (response.status === 204) return null;
      if (responseType === "blob") return await response.blob();
      try {
        return await response.json();
      } catch (_) {
        throw new APIRequestError("响应无法解析", "invalid_response", response.status);
      }
    })();
    // 超时覆盖响应正文读取，即使 headers 已返回也不能无限等待。
    return await Promise.race([operation, deadline]);
  } catch (error) {
    if (error instanceof APIRequestError) throw error;
    throw new APIRequestError(error.message || "网络请求失败", "unknown");
  } finally {
    window.clearTimeout(timeoutID);
  }
}

async function requestOrDemo(path, demoValue, kind) {
  try {
    let nextCursor = "";
    const data = await request(path, {
      onResponse: response => { nextCursor = response.headers?.get("X-Next-Cursor") || ""; }
    });
    if (!MarketplaceData.validators[kind](data)) {
      throw new APIRequestError("响应数据结构不正确", "invalid_response");
    }
    return { data, isOnline: true, nextCursor };
  } catch (error) {
    return { data: structuredClone(demoValue), isOnline: false, reason: error.message };
  }
}

function logoHTML(className, alt) {
  return '<img class="' + className + '" src="' + LOCAL_LOGO_URL +
    '" data-remote-src="' + ICONFONT_LOGO_URL + '" alt="' + safe(alt) + '">';
}

function loadIconfontImages() {
  document.querySelectorAll("img[data-remote-src]").forEach(image => {
    const remoteImage = new Image();
    remoteImage.onload = () => {
      image.src = remoteImage.src;
    };
    remoteImage.onerror = () => {
      image.src = LOCAL_LOGO_URL;
    };
    remoteImage.src = image.dataset.remoteSrc;
  });
}

function emptyState(title, detail) {
  return '<div class="empty-state">' + logoHTML("empty-state-logo", title) +
    '<strong>' + safe(title) + '</strong><small>' + safe(detail) +
    '</small><button class="button secondary" data-action="refresh">重新加载</button></div>';
}

function renderMetrics(data) {
  const cards = [
    ["全部订单", data.totalOrders],
    ["待接单", data.pendingOrders],
    ["处理中", data.activeOrders],
    ["待人工结算", data.pendingSettlements]
  ];
  metricsRoot.innerHTML = cards.map(([label, value]) =>
    '<article class="metric"><span>' + label + '</span><strong>' +
      (Number(value) || 0) + '</strong></article>'
  ).join("");
}

function demoDashboard() {
  const activeStatuses = ["accepted", "arrived", "quote_pending", "in_service", "awaiting_payment"];
  return {
    totalOrders: DEMO_DATA.orders.length,
    pendingOrders: DEMO_DATA.orders.filter(order => order.status === "pending_worker").length,
    activeOrders: DEMO_DATA.orders.filter(order => activeStatuses.includes(order.status)).length,
    pendingSettlements: DEMO_DATA.settlements.filter(item => item.status === "pending_manual").length
  };
}

function renderOrder(order, workerNames) {
  const canDemoCollect = order.status === "awaiting_payment";
  const workerName = workerNames.get(order.workerId) || order.workerId || "待分配";
  const action = canDemoCollect
    ? '<button class="button warn" data-action="demo-collect" data-id="' +
      safe(order.id) + '">模拟收款</button>'
    : "—";
  return '<tr>' +
    '<td><strong>' + safe(order.category) + ' · ' + safe(order.equipment) +
    '</strong><small>' + safe(order.id) + '<br>' + safe(order.issue) + '</small></td>' +
    '<td><strong>' + safe(order.customerId) + '</strong><small>' +
    safe(order.address) + '<br>' + safe(order.scheduledAt || "时间待协商") +
    '</small></td>' +
    '<td>' + safe(workerName) + '</td>' +
    '<td><span class="status ' + safe(order.status) + '">' +
    safe(statusName(order.status)) + '</span></td>' +
    '<td class="numeric">' + money(order.quotedAmountCents) + '</td>' +
    '<td class="numeric">' + money(order.platformFeeCents) +
    '<small>' + money(order.workerShareCents) + '</small></td>' +
    '<td class="row-action">' + action + '</td>' +
    '</tr>';
}

function renderOrders(orders, workers) {
  const workerNames = new Map(workers.map(worker => [worker.id, worker.displayName]));
  orderCount.textContent = orders.length + " 条";
  ordersBody.innerHTML = orders.length
    ? orders.map(order => renderOrder(order, workerNames)).join("")
    : '<tr><td colspan="7">' + emptyState("暂时没有订单", "新订单会显示在这里。") + '</td></tr>';
}

function renderWorkers(workers) {
  workersRoot.innerHTML = workers.length ? workers.map(worker =>
    '<article class="record"><strong>' + safe(worker.displayName) + ' · ' +
      safe(worker.status) + '</strong><small>' + safe(worker.id) +
      '<br>技能：' + safe((worker.skills || []).join("、")) +
      '<br>服务区域：' + safe((worker.serviceAreas || []).join("、")) +
      '</small></article>'
  ).join("") : emptyState("暂时没有师傅资料", "师傅注册和审核完成后会显示在这里。");
}

function renderSettlements(settlements) {
  settlementsRoot.innerHTML = settlements.length ? settlements.map(item => {
    const action = item.status === "pending_manual"
      ? '<button class="button secondary" data-action="manual-paid" data-id="' +
        safe(item.id) + '">核销线下打款</button>'
      : "";
    return '<article class="record"><strong>' + safe(item.orderId) + ' · ' +
      safe(item.status) + '</strong><small>订单 ' +
      money(item.grossAmountCents) + '；平台 ' +
      money(item.platformFeeCents) + '；师傅 ' +
      money(item.workerShareCents) + '</small>' + action + '</article>';
  }).join("") : emptyState("暂无分润记录", "演示收款后会生成待人工处理的台账。");
}

function renderConnectionState(onlineCount, totalCount) {
  if (!activeAPIBase()) {
    connectionState.textContent = "线上地址未配置：显示本地演示数据";
    return;
  }
  if (onlineCount === totalCount) {
    connectionState.textContent = "已连接：显示服务器数据";
  } else if (onlineCount === 0) {
    connectionState.textContent = "离线演示：接口失败，显示本地假数据";
  } else {
    connectionState.textContent = "部分接口已连接：失败项目显示本地假数据";
  }
}

function renderDemoPreview() {
  displayedData = {
    dashboard: { data: demoDashboard(), isOnline: false },
    orders: { data: DEMO_DATA.orders, isOnline: false },
    workers: { data: DEMO_DATA.workers, isOnline: false },
    settlements: { data: DEMO_DATA.settlements, isOnline: false }
  };
  renderMetrics(demoDashboard());
  renderOrders(DEMO_DATA.orders, DEMO_DATA.workers);
  renderWorkers(DEMO_DATA.workers);
  renderSettlements(DEMO_DATA.settlements);
  renderSources();
  loadIconfontImages();
}

function renderSources() {
  for (const kind of ["dashboard", "orders", "workers", "settlements"]) {
    const source = document.querySelector("#" + (kind === "dashboard" ? "metrics" : kind) + "Source");
    const result = displayedData[kind];
    source.textContent = result.isOnline ? "服务端数据" :
      "本地演示" + (result.reason ? "（" + result.reason + "）" : "");
    if (kind !== "dashboard") {
      const button = document.querySelector("#" + kind + "More");
      button.hidden = !result.isOnline || !result.nextCursor;
      button.disabled = false;
    }
  }
}

async function loadMore(kind, button) {
  if (!["orders", "workers", "settlements"].includes(kind)) return;
  const previous = displayedData[kind];
  if (!previous.isOnline || !previous.nextCursor || button.disabled) return;
  const environment = environmentRevision;
  const revision = refreshRevision;
  button.disabled = true;
  const result = await requestOrDemo("/api/v1/admin/" + kind + "?cursor=" +
    encodeURIComponent(previous.nextCursor), DEMO_DATA[kind], kind);
  if (environment !== environmentRevision || revision !== refreshRevision) return;
  if (result.isOnline) {
    const rows = new Map(previous.data.map(item => [item.id, item]));
    result.data.forEach(item => rows.set(item.id, item));
    result.data = [...rows.values()];
    if (result.nextCursor === previous.nextCursor) result.nextCursor = "";
  }
  displayedData[kind] = result;
  renderOrders(displayedData.orders.data, displayedData.workers.data);
  renderWorkers(displayedData.workers.data);
  renderSettlements(displayedData.settlements.data);
  renderSources();
  loadIconfontImages();
  renderConnectionState(Object.values(displayedData).filter(item => item.isOnline).length, 4);
}

function showAction(message) {
  actionState.hidden = false;
  actionState.textContent = message;
}

async function refresh() {
  const revision = ++refreshRevision;
  const environment = environmentRevision;
  connectionState.textContent = "正在请求服务端…";
  const [dashboard, orders, workers, settlements] = await Promise.all([
    requestOrDemo("/api/v1/admin/dashboard", demoDashboard(), "dashboard"),
    requestOrDemo("/api/v1/admin/orders", DEMO_DATA.orders, "orders"),
    requestOrDemo("/api/v1/admin/workers", DEMO_DATA.workers, "workers"),
    requestOrDemo("/api/v1/admin/settlements", DEMO_DATA.settlements, "settlements")
  ]);
  if (revision !== refreshRevision || environment !== environmentRevision) return;
  displayedData = { dashboard, orders, workers, settlements };
  renderMetrics(dashboard.data);
  renderOrders(orders.data, workers.data);
  renderWorkers(workers.data);
  renderSettlements(settlements.data);
  renderSources();
  loadIconfontImages();
  const onlineCount = [dashboard, orders, workers, settlements]
    .filter(result => result.isOnline).length;
  renderConnectionState(onlineCount, 4);
  if (window.AdminOperations) window.AdminOperations.refresh();
}

function updateDemoState(action, id) {
  const kind = action === "demo-collect" ? "orders" : "settlements";
  const snapshot = displayedData[kind];
  if (snapshot.isOnline) {
    const original = snapshot.data.find(item => item.id === id);
    if (!original) throw new Error("当前服务端记录已不在页面中，请刷新");
    id = MarketplaceData.copyForDemo(DEMO_DATA, kind, original);
  }
  MarketplaceData.applyDemoAction(DEMO_DATA, action, id);
}

async function performAction(action, id, button) {
  if (!["demo-collect", "manual-paid"].includes(action) || !id) return;
  const environment = environmentRevision;
  const key = environment + ":" + action + ":" + id;
  if (pendingActions.has(key)) return;
  const endpoint = action === "demo-collect"
    ? "/api/v1/admin/orders/" + encodeURIComponent(id) + "/demo-collect"
    : "/api/v1/admin/settlements/" + encodeURIComponent(id) + "/manual-paid";
  const label = action === "demo-collect"
    ? "写入一条演示收款记录？不会真实扣款。"
    : "写入演示结算核销记录？此操作不会发起转账，账目仍标记为模拟。";
  if (!window.confirm(label)) return;
  pendingActions.add(key);
  if (button) button.disabled = true;
  try {
    let responseStatus = 0;
    const result = await request(endpoint, {
      method: "POST",
      onResponse: response => { responseStatus = response.status; }
    });
    const validator = action === "demo-collect" ? "orders" : "settlements";
    const emptyConfirmation = action === "manual-paid" && responseStatus === 204 && result === null;
    if (!emptyConfirmation && !MarketplaceData.validators[validator]([result])) {
      throw new APIRequestError("操作响应数据结构不正确", "invalid_response");
    }
    if (environment !== environmentRevision) return;
    showAction("服务端已确认操作完成；正在刷新记录。此操作不会扣款或转账。");
    await refresh();
  } catch (error) {
    if (environment !== environmentRevision) return;
    const outcome = error.kind === "rejected" ? "服务端拒绝操作" :
      error.kind === "configuration" ? "服务地址未配置" : "服务端处理结果尚未确认";
    const detail = (error.status ? "HTTP " + error.status + " " : "") +
      (error.code ? error.code + "：" : "") + error.message;
    try {
      updateDemoState(action, id);
      refreshRevision += 1;
      renderDemoPreview();
      if (window.AdminOperations) window.AdminOperations.refresh();
      connectionState.textContent = "本地演示副本：刷新成功后恢复服务端数据";
      showAction(outcome + "（" + detail + "）。已在独立本地副本演示此操作；本地结果不代表服务端成功，也不会自动补发。");
    } catch (demoError) {
      showAction(outcome + "（" + detail + "）；本地演示未完成：" + demoError.message);
    }
  } finally {
    pendingActions.delete(key);
    if (button) button.disabled = false;
  }
}

function applyEnvironment() {
  try {
    saveAPIEnvironment(environmentInput.value, baseInput.value);
  } catch (error) {
    connectionState.textContent = error.message;
    syncEnvironmentFields();
    return;
  }
  syncEnvironmentFields();
  DEMO_DATA = structuredClone(DEMO_SEED);
  if (typeof AdminSession !== "undefined") AdminSession.clear();
  if (window.AdminOperations) window.AdminOperations.reset();
  actionState.hidden = true;
  actionState.textContent = "";
  renderDemoPreview();
  refresh();
}

environmentInput.addEventListener("change", () => {
  baseInput.value = environmentInput.value === "test" ? testBase : API_ENVIRONMENTS.production.baseURL;
  applyEnvironment();
});
document.querySelector("#saveBase").addEventListener("click", applyEnvironment);
copyBaseButton.addEventListener("click", copyAPIBase);
baseInput.addEventListener("input", syncCopyButton);
document.querySelector("#refresh").addEventListener("click", refresh);

document.addEventListener("click", event => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const action = button.dataset.action;
  if (action === "refresh") {
    refresh();
    return;
  }
  if (action === "load-more") {
    loadMore(button.dataset.kind, button);
    return;
  }
  performAction(action, button.dataset.id, button);
});

renderDemoPreview();
refresh();
