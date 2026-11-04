/* Jobs · 维修协同工作台。服务端事实与合成演示副本保持独立。 */
(() => {
  "use strict";
  const D = WorkbenchData;
  const $ = (selector) => document.querySelector(selector);
  const safe = (value) =>
    String(value ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const money = (value) =>
    new Intl.NumberFormat("zh-CN", {
      style: "currency",
      currency: "CNY",
      minimumFractionDigits: 2,
    }).format((Number.isSafeInteger(value) ? value : 0) / 100);
  const date = (value) =>
    value
      ? new Intl.DateTimeFormat("zh-CN", {
          timeZone: "Asia/Shanghai",
          month: "2-digit",
          day: "2-digit",
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        }).format(new Date(value))
      : "未填写";
  const outcomes = {
    accepted: "已验收",
    customer_refused: "客户拒修",
    company_refused: "公司拒修",
    unrepairable: "不能修",
    cancelled: "已取消",
    negotiated: "协商结束",
  };
  const typeNames = { mail: "寄修", onsite: "上门", sale: "销售" };
  const documentNames = {
    unknown: "待确认需求",
    required: "未制作",
    prepared: "已做未送",
    sent: "已发送",
    not_required: "无需，已确认",
    supplement: "需补附件",
  };
  const invoiceNames = {
    unknown: "待确认需求",
    pending: "未开",
    partial: "部分已开",
    complete: "已满足",
    not_required: "无需，已确认",
    over: "超开待核实",
  };
  const stageActions = {
    pending_intake: ["intake"],
    pending_arrangement: ["receive", "assign", "diagnose"],
    diagnosis_quotation: ["report", "quote", "approve_quote"],
    pending_customer_confirmation: ["sign_quote", "quote"],
    pending_execution: ["start", "stock_ready"],
    repairing: ["finish"],
    pending_quality_check: ["receive", "qc"],
    pending_delivery: ["dispatch", "deliver"],
    pending_acceptance: ["accept", "review_acceptance"],
    settling: [],
    pending_completion: ["complete"],
    completed: ["reopen", "rework"],
  };
  const commonActions = [
    "handover_contact",
    "requirements",
    "documents",
    "cash",
    "invoice",
    "remark",
    "evidence",
    "issue",
    "failure",
    "obligation",
    "visit",
    "outsource",
    "cost",
    "commission",
  ];
  let demo = D.seed(),
    data = structuredClone(demo),
    actor = demo.actor,
    token = "",
    sessionActor = null,
    authenticating = false,
    snapshotReady = false,
    dataKind = "demo",
    connected = false,
    view = "orders",
    quick = "all",
    selectedId = "",
    detailTab = "overview",
    epoch = 0,
    loading = false,
    toastTimer;
  let listRevision = 0,
    detailRevision = 0,
    actionIntent = 0,
    formRevision = 0,
    refreshJob = null,
    metadataRevision = 0,
    auditRevision = 0,
    auditPage = 1,
    page = 1;
  const pageSize = 30,
    details = new Map(),
    detailRequests = new Map();
  let apiBase = "",
    timeoutMs = 2500;
  try {
    apiBase = localStorage.getItem("repairV38Base") || "";
    timeoutMs = Number(localStorage.getItem("repairV38Timeout")) || 2500;
  } catch (_) {}
  // 同源部署与离线预览使用不同入口，旧地址不能绕过页面的安全策略。
  try {
    apiBase = normalizeBase(apiBase);
  } catch (_) {
    apiBase = "";
  }
  const pending = new Set();
  const formKeys = new Map();
  function formKey(path, body) {
    const scope = path + ":" + body;
    if (!formKeys.has(scope)) formKeys.set(scope, D.uid("request"));
    return formKeys.get(scope);
  }
  function releaseFormKey(path, body) {
    formKeys.delete(path + ":" + body);
  }
  function toast(message) {
    $("#toast").textContent = message;
    $("#toast").hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => ($("#toast").hidden = true), 6500);
  }
  class APIError extends Error {
    constructor(message, status = 0) {
      super(message);
      this.status = status;
    }
  }
  function normalizeBase(value) {
    if (location.protocol === "file:") {
      if (value)
        throw new Error("离线页面仅供合成预览，请从服务端页面连接 API。");
      return "";
    }
    if (!value) return "";
    const url = new URL(value);
    if (
      !["http:", "https:"].includes(url.protocol) ||
      url.origin !== location.origin ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      !["", "/"].includes(url.pathname)
    )
      throw new Error(
        "API 地址必须与当前页面同源，且不含路径、账号、查询或片段。请打开目标服务页面后登录。",
      );
    return url.origin;
  }
  const object = (value) =>
    !!value && typeof value === "object" && !Array.isArray(value);
  const positiveInteger = (value) => Number.isSafeInteger(value) && value > 0;
  const nonnegativeInteger = (value) =>
    Number.isSafeInteger(value) && value >= 0;
  const strings = (value) =>
    Array.isArray(value) && value.every((item) => typeof item === "string");
  const validDate = (value) =>
    value == null ||
    value === "" ||
    (typeof value === "string" && Number.isFinite(Date.parse(value)));
  function fields(value, schema) {
    return (
      object(value) &&
      Object.entries(schema).every(
        ([name, check]) => value[name] == null || check(value[name]),
      )
    );
  }
  function records(value, check) {
    return value == null || (Array.isArray(value) && value.every(check));
  }
  function validSummary(value) {
    return (
      object(value) &&
      strings(value.missing) &&
      ["documentStatus", "invoiceStatus", "nextTask", "warrantyLabel"].every(
        (name) => typeof value[name] === "string",
      ) &&
      [
        "collectedCents",
        "receivableCents",
        "remainingCents",
        "overpaidCents",
        "pendingCashCents",
        "invoiceCents",
      ].every((name) => Number.isSafeInteger(value[name])) &&
      nonnegativeInteger(value.remainingCents)
    );
  }
  function validPart(value) {
    return (
      object(value) &&
      ["id", "name", "sku"].every((name) => typeof value[name] === "string") &&
      !!value.id &&
      nonnegativeInteger(value.available) &&
      nonnegativeInteger(value.quarantine)
    );
  }
  function validLoan(value) {
    return (
      object(value) &&
      typeof value.id === "string" &&
      !!value.id &&
      positiveInteger(value.version) &&
      positiveInteger(value.quantity) &&
      [
        "outstanding",
        "returnedGood",
        "returnedQuarantine",
        "consumed",
        "disposed",
      ].every((name) => nonnegativeInteger(value[name])) &&
      fields(value, {
        dueAt: validDate,
        orderId: (v) => typeof v === "string",
        partId: (v) => typeof v === "string",
      }) &&
      records(
        value.transfers,
        (item) =>
          fields(item, { dueAt: validDate }) &&
          nonnegativeInteger(item.quantity),
      )
    );
  }
  function validPurchase(value) {
    return (
      object(value) &&
      typeof value.id === "string" &&
      !!value.id &&
      positiveInteger(value.version) &&
      positiveInteger(value.quantity) &&
      nonnegativeInteger(value.received) &&
      nonnegativeInteger(value.unitCents)
    );
  }
  function validOrderRecords(value) {
    const text = (v) => typeof v === "string",
      bool = (v) => typeof v === "boolean",
      record = (v) =>
        fields(v, {
          id: text,
          files: strings,
          amountCents: Number.isSafeInteger,
          createdAt: validDate,
          at: validDate,
          occurredAt: validDate,
          plannedAt: validDate,
          startedAt: validDate,
          dueAt: validDate,
          signedAt: validDate,
          resolved: bool,
          verified: bool,
          handedOver: bool,
        });
    return (
      [
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
      ].every((name) => records(value[name], record)) &&
      records(value.quoteHistory, (q) =>
        fields(q, { signedAt: validDate, validUntil: validDate }),
      ) &&
      records(
        value.acceptanceRecords,
        (item) =>
          record(item) &&
          typeof item.id === "string" &&
          !!item.id &&
          typeof item.passed === "boolean" &&
          typeof item.signature === "string" &&
          !!item.signature &&
          typeof item.signerId === "string" &&
          typeof item.signerName === "string" &&
          typeof item.signedAt === "string" &&
          validDate(item.signedAt) &&
          typeof item.note === "string" &&
          positiveInteger(item.quoteVersion) &&
          positiveInteger(item.orderVersion),
      ) &&
      (value.quote == null ||
        (fields(value.quote, {
          version: nonnegativeInteger,
          signedAt: validDate,
          validUntil: validDate,
          startRequiresPrepayment: bool,
          amountCents: nonnegativeInteger,
          prepayCents: nonnegativeInteger,
          warrantyMonths: nonnegativeInteger,
        }) &&
          (!value.quote.version ||
            positiveInteger(value.quote.warrantyMonths)))) &&
      (value.documents == null ||
        fields(value.documents, { files: strings })) &&
      (value.warranty == null ||
        fields(value.warranty, {
          startsAt: validDate,
          endsAt: validDate,
          startAt: validDate,
          endAt: validDate,
        })) &&
      fields(value, {
        createdAt: validDate,
        updatedAt: validDate,
        deliveredAt: validDate,
        acceptanceDueAt: validDate,
        acceptedAt: validDate,
        completionAt: validDate,
      })
    );
  }
  function validActor(value) {
    return (
      object(value) &&
      typeof value.id === "string" &&
      !!value.id &&
      Object.hasOwn(D.roles, value.role) &&
      ["active", "disabled"].includes(value.status) &&
      positiveInteger(value.authVersion)
    );
  }
  function validOrder(value) {
    return (
      object(value) &&
      typeof value.id === "string" &&
      !!value.id &&
      typeof value.number === "string" &&
      !!value.number &&
      positiveInteger(value.version) &&
      Object.hasOwn(D.states, value.status) &&
      validSummary(value.summary) &&
      strings(value.allowedActions) &&
      validOrderRecords(value)
    );
  }
  function validSettings(value) {
    return (
      object(value) &&
      ["companyAddress", "companyReceiver", "companyPhone"].every(
        (name) => typeof value[name] === "string" && !!value[name],
      ) &&
      positiveInteger(value.reminderHours) &&
      positiveInteger(value.remarkLimit)
    );
  }
  function validPage(value, items = value?.items) {
    return (
      object(value) &&
      Array.isArray(items) &&
      items.every(validOrder) &&
      positiveInteger(value.page) &&
      positiveInteger(value.pageSize) &&
      nonnegativeInteger(value.total) &&
      nonnegativeInteger(value.totalPages) &&
      value.totalPages === Math.ceil(value.total / value.pageSize) &&
      items.length <= value.pageSize &&
      items.length <= value.total
    );
  }
  function validBootstrap(value) {
    return (
      object(value) &&
      validActor(value.actor) &&
      validSettings(value.settings) &&
      ["parts", "loans", "purchases"].every((name) =>
        Array.isArray(value[name]),
      ) &&
      value.parts.every(validPart) &&
      value.loans.every(validLoan) &&
      value.purchases.every(validPurchase) &&
      validPage(value.orderPage, value.orders) &&
      object(value.metrics) &&
      [
        "openCount",
        "settlingCount",
        "remainingCents",
        "readyCount",
        "tasksCount",
        "blockedCount",
      ].every((name) => nonnegativeInteger(value.metrics[name])) &&
      object(value.capacity) &&
      nonnegativeInteger(value.capacity.requestCount) &&
      positiveInteger(value.capacity.threshold) &&
      typeof value.capacity.warning === "boolean"
    );
  }
  function validateResponse(path, options, result) {
    let valid = false;
    if (path === "/bootstrap") valid = validBootstrap(result);
    else if (path === "/login")
      valid =
        object(result) &&
        typeof result.token === "string" &&
        !!result.token &&
        validActor(result.actor);
    else if (path === "/logout") valid = object(result) && result.ok === true;
    else if (path === "/accounts")
      valid = Array.isArray(result) && result.every(validActor);
    else if (/^\/accounts\/[^/]+\/status$/.test(path)) {
      const wanted = JSON.parse(options.body);
      valid =
        validActor(result) &&
        result.id === decodeURIComponent(path.split("/")[2]) &&
        result.status === wanted.status;
    } else if (path === "/settings") {
      const wanted = JSON.parse(options.body);
      valid =
        validSettings(result) &&
        Object.keys(wanted).every((name) => result[name] === wanted[name]);
    } else if (path.startsWith("/audit?"))
      valid =
        object(result) &&
        Array.isArray(result.items) &&
        nonnegativeInteger(result.total) &&
        positiveInteger(result.page) &&
        positiveInteger(result.pageSize) &&
        result.items.every(
          (event) =>
            object(event) &&
            typeof event.id === "string" &&
            !!event.id &&
            typeof event.actorId === "string" &&
            typeof event.type === "string" &&
            typeof event.result === "string" &&
            typeof event.at === "string" &&
            validDate(event.at) &&
            (event.resourceIds == null || strings(event.resourceIds)),
        );
    else if (
      path.startsWith("/orders?") ||
      (path === "/orders" && !options.method)
    )
      valid = validPage(result);
    else if (
      path === "/orders" ||
      /^\/orders\/[^/]+(?:\/actions)?$/.test(path)
    ) {
      valid = validOrder(result);
      if (valid && /^\/orders\/[^/]+$/.test(path))
        valid = result.id === decodeURIComponent(path.split("/")[2]);
      if (
        valid &&
        path.endsWith("/actions") &&
        JSON.parse(options.body).type !== "rework"
      )
        valid = result.id === decodeURIComponent(path.split("/")[2]);
    } else if (/^\/loans(?:\/[^/]+\/actions)?$/.test(path)) {
      valid =
        object(result) &&
        typeof result.id === "string" &&
        !!result.id &&
        positiveInteger(result.version) &&
        positiveInteger(result.quantity) &&
        nonnegativeInteger(result.outstanding);
      if (valid && path.endsWith("/actions"))
        valid = result.id === decodeURIComponent(path.split("/")[2]);
    } else if (/^\/purchases(?:\/[^/]+\/receive)?$/.test(path)) {
      valid =
        object(result) &&
        typeof result.id === "string" &&
        !!result.id &&
        positiveInteger(result.version) &&
        positiveInteger(result.quantity) &&
        nonnegativeInteger(result.received);
      if (valid && path.endsWith("/receive"))
        valid = result.id === decodeURIComponent(path.split("/")[2]);
    } else if (path === "/export")
      valid =
        object(result) &&
        validActor(result.actor) &&
        Array.isArray(result.orders) &&
        result.orders.every(validOrder);
    if (!valid)
      throw new APIError(
        "服务端响应格式不完整，未确认保存成功。请核对服务端结果后重试。",
        200,
      );
  }
  function revokeSession(revision, status) {
    if (status !== 401 || revision !== epoch || !token) return;
    // 撤销属于认证会话，不能被导航、详情或元数据的局部序号吞掉。
    formKeys.clear();
    enterFallback(new APIError("当前账号会话已失效，请重新登录。", 401));
  }
  async function request(path, options = {}) {
    if (location.protocol === "file:")
      throw new APIError("离线预览没有 API 连接，请从部署服务地址打开页面。");
    const revision = epoch;
    const controller = new AbortController(),
      timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(apiBase + "/api/v38" + path, {
        ...options,
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: "Bearer " + token } : {}),
          ...(options.method && options.method !== "GET"
            ? {
                "Idempotency-Key":
                  options.key || formKey(path, options.body || ""),
              }
            : {}),
          ...options.headers,
        },
      });
      revokeSession(revision, response.status);
      let result;
      try {
        result = await response.json();
      } catch (_) {
        throw new APIError("服务端响应无法解析。", response.status);
      }
      if (revision !== epoch)
        throw new APIError("身份或连接已切换，请重新核对。", 409);
      if (!response.ok)
        throw new APIError(
          result?.message || result?.error || "请求未成功。",
          response.status,
        );
      validateResponse(path, options, result);
      if (options.method && options.method !== "GET")
        releaseFormKey(path, options.body || "");
      return result;
    } catch (error) {
      if (error instanceof APIError) throw error;
      throw new APIError(
        error.name === "AbortError"
          ? "连接超时，服务未返回结果。"
          : "无法连接服务，请检查地址或启动服务。",
      );
    } finally {
      clearTimeout(timer);
    }
  }
  function empty(
    title,
    description = "可以调整筛选条件，或重新加载当前列表。",
  ) {
    return (
      '<div class="empty-state"><div class="empty-icon">▤</div><h3>' +
      safe(title) +
      "</h3><p>" +
      safe(description) +
      '</p><button class="button" data-reload>重新加载</button></div>'
    );
  }
  function badge(label, color = "") {
    return '<span class="badge ' + color + '">' + safe(label) + "</span>";
  }
  function summary(order) {
    const value = order.summary || D.derive(order, data.loans);
    if (dataKind === "demo" && !internal()) {
      return {
        ...value,
        missing: [],
        pendingCashCents: 0,
        nextTask:
          order.status === "pending_customer_confirmation"
            ? "请确认报价与履约条款"
            : order.status === "pending_acceptance"
              ? "请验收或反馈异议"
              : "公司正在处理，请查看进度",
      };
    }
    return value;
  }
  function displayDocument(order) {
    const value = summary(order).documentStatus;
    return documentNames[value] || value || "待确认需求";
  }
  function displayInvoice(order) {
    const value = summary(order).invoiceStatus;
    return invoiceNames[value] || value || "待确认需求";
  }
  function internal() {
    return !["customer", "supplier", "outsource"].includes(actor.role);
  }
  function unavailable(error) {
    return !error.status || error.status >= 500;
  }
  function permitted(order, type) {
    return Array.isArray(order.allowedActions)
      ? order.allowedActions.includes(type)
      : (D.permissions[actor.role] || []).includes(type);
  }
  function canResolveObligation(task) {
    return (
      !!task &&
      !task.resolved &&
      (["admin", "dispatcher"].includes(actor.role) ||
        task.ownerId === actor.id)
    );
  }
  function actionButton(order, type, label, extra = "") {
    return permitted(order, type)
      ? '<button class="button ' +
          extra +
          '" data-action="' +
          safe(type) +
          '" data-order="' +
          safe(order.id) +
          '">' +
          safe(label || D.actionNames[type]) +
          "</button>"
      : "";
  }
  function available(order) {
    return [...(stageActions[order.status] || []), ...commonActions].filter(
      (type) =>
        permitted(order, type) &&
        !(
          order.type === "sale" &&
          ["diagnose", "start", "finish", "qc"].includes(type)
        ) &&
        !(order.type !== "sale" && type === "stock_ready") &&
        !(
          order.status === "completed" &&
          ![
            "handover_contact",
            "remark",
            "evidence",
            "issue",
            "rework",
            "reopen",
          ].includes(type)
        ),
    );
  }
  function currentOrders() {
    if (dataKind !== "demo") return data.orders || [];
    if (actor.role === "supplier") return [];
    if (actor.role === "customer")
      return data.orders.filter((o) => o.customerId === actor.id);
    if (["engineer", "outsource"].includes(actor.role))
      return data.orders.filter((o) => o.assigneeId === actor.id);
    return data.orders || [];
  }
  function renderAccount() {
    const label =
      dataKind === "demo"
        ? "演示 · " + (D.roles[actor.role] || actor.role)
        : actor.displayName || actor.name || D.roles[actor.role] || actor.role;
    $("#accountLabel").textContent = label;
    $(".avatar").textContent = (D.roles[actor.role] || "人").slice(0, 1);
    $("#sourceBadge").textContent = connected
      ? "服务端数据"
      : dataKind === "demo"
        ? "合成演示"
        : "服务端 · 待重连";
    $("#sourceBadge").classList.toggle("online", connected);
    $("#connectionNote").classList.toggle("online", connected);
    $("#createOrder").hidden = !["admin", "dispatcher", "customer"].includes(
      actor.role,
    );
    document
      .querySelectorAll("[data-view=inventory]")
      .forEach(
        (el) =>
          (el.hidden = actor.role === "customer" || actor.role === "outsource"),
      );
  }
  function renderMetrics() {
    const pendingMetadata = dataKind === "server" && !snapshotReady;
    const orders = currentOrders(),
      totals =
        dataKind === "server"
          ? data.metrics
          : {
              openCount: orders.filter((o) => o.status !== "completed").length,
              settlingCount: orders.filter((o) => o.status === "settling")
                .length,
              remainingCents: orders.reduce(
                (n, o) => n + summary(o).remainingCents,
                0,
              ),
              readyCount: orders.filter(
                (o) => o.status === "pending_completion",
              ).length,
            };
    const entries = [
      {
        label: "进行中工单",
        value: totals.openCount,
        note: "全链路跟踪至整单完结",
        icon: "▦",
      },
      {
        label: "结算待办理",
        value: totals.settlingCount,
        note: "资料 · 票据 · 现金及余项",
        icon: "☷",
      },
      {
        label: "客户待收款",
        value: money(totals.remainingCents),
        note: "仅计入财务核实净收款",
        icon: "¥",
        money: true,
      },
      {
        label: "待完结确认",
        value: totals.readyCount,
        note: "负责人一次核对确认",
        icon: "✓",
      },
    ];
    $("#metrics").innerHTML = entries
      .map(
        (e) =>
          '<article class="metric"><div class="metric-label">' +
          e.label +
          '<span class="metric-icon">' +
          e.icon +
          '</span></div><div class="metric-value ' +
          (e.money ? "money" : "") +
          '">' +
          (pendingMetadata ? "待加载" : e.value) +
          "</div><small><b>" +
          (pendingMetadata
            ? "当前概览尚未加载"
            : dataKind === "demo"
              ? "合成样例"
              : "当前授权范围") +
          "</b>" +
          e.note +
          "</small></article>",
      )
      .join("");
    $("#navCount").textContent = pendingMetadata ? "…" : totals.openCount;
    $("#capacityNote").hidden = dataKind !== "server" || !data.capacity.warning;
    if (!$("#capacityNote").hidden)
      $("#capacityNote").textContent =
        "业务记录接近本机容量上限（" +
        data.capacity.requestCount +
        " / " +
        data.capacity.threshold +
        "）。请管理员安排备份并按部署说明迁移数据；不要删除台账或重置请求记录。";
  }
  function filteredOrders() {
    if (dataKind === "server") return currentOrders();
    if (view !== "orders") return currentOrders();
    const q = $("#search").value.trim().toLowerCase(),
      stage = $("#statusFilter").value,
      docs = $("#documentFilter").value,
      pay = $("#paymentFilter").value;
    return currentOrders().filter((o) => {
      const s = summary(o);
      return (
        (!q ||
          [o.number, o.customer, o.device, o.project, o.ownerId].some((t) =>
            String(t || "")
              .toLowerCase()
              .includes(q),
          )) &&
        (!stage || o.status === stage) &&
        (quick === "all" ||
          (quick === "mine" &&
            (o.ownerId === actor.id || o.assigneeId === actor.id)) ||
          (quick === "blocked" && (o.issues || []).some((i) => !i.resolved)) ||
          o.status === quick) &&
        (!docs ||
          (docs === "sent" && ["sent", "已发送"].includes(s.documentStatus)) ||
          (docs === "not_required" &&
            ["not_required", "无需，已确认"].includes(s.documentStatus)) ||
          (docs === "required" &&
            !["sent", "not_required", "已发送", "无需，已确认"].includes(
              s.documentStatus,
            ))) &&
        (!pay ||
          (pay === "outstanding" && s.remainingCents > 0) ||
          (pay === "pending" && s.pendingCashCents > 0) ||
          (pay === "paid" &&
            s.remainingCents === 0 &&
            s.overpaidCents === 0 &&
            s.pendingCashCents === 0))
      );
    });
  }
  function pageInfo() {
    if (dataKind === "server") return data.orderPage;
    const total = filteredOrders().length;
    return { total, page, pageSize, totalPages: Math.ceil(total / pageSize) };
  }
  function pageOrders() {
    return dataKind === "server"
      ? currentOrders()
      : filteredOrders().slice((page - 1) * pageSize, page * pageSize);
  }
  function pager() {
    const info = pageInfo();
    return (
      '<div class="list-pagination"><span>按工单分页 · 共 ' +
      info.total +
      " 张 · 第 " +
      (info.total === 0 ? 1 : info.page) +
      " / " +
      Math.max(1, info.totalPages) +
      ' 页</span><div class="action-list"><button class="button quiet" data-page="previous"' +
      (info.total === 0 || info.page <= 1 ? " disabled" : "") +
      '>上一页</button><button class="button quiet" data-page="next"' +
      (info.page >= info.totalPages ? " disabled" : "") +
      ">下一页</button></div></div>"
    );
  }
  function orderQuery() {
    const useOrderFilters = view === "orders";
    return new URLSearchParams({
      page: String(page),
      pageSize: String(pageSize),
      q: useOrderFilters ? $("#search").value.trim() : "",
      status: useOrderFilters ? $("#statusFilter").value : "",
      filter: useOrderFilters ? quick : "all",
      documents: useOrderFilters ? $("#documentFilter").value : "",
      payment: useOrderFilters ? $("#paymentFilter").value : "",
    }).toString();
  }
  function sameSessionActor(value) {
    return (
      !!sessionActor &&
      !!token &&
      value.status === "active" &&
      ["id", "role", "companyId", "authVersion"].every(
        (key) => value[key] === sessionActor[key],
      )
    );
  }
  function clearSessionViews() {
    actionIntent++;
    formRevision++;
    detailRevision++;
    metadataRevision++;
    auditRevision++;
    auditPage = 1;
    selectedId = "";
    details.clear();
    detailRequests.clear();
    if ($("#formDialog").open) $("#formDialog").close();
    if ($("#detailDialog").open) $("#detailDialog").close();
    [
      "#settingsView",
      "#accountList",
      "#auditList",
      "#detailContent",
      "#formContent",
    ].forEach((selector) => {
      const element = $(selector);
      if (element) element.innerHTML = "";
    });
    clearTimeout(toastTimer);
    $("#toast").hidden = true;
    $("#toast").textContent = "";
  }
  function emptyServerSnapshot(identity) {
    return {
      actor: identity,
      orders: [],
      parts: [],
      loans: [],
      purchases: [],
      settings: {},
      orderPage: { page: 1, pageSize, total: 0, totalPages: 0 },
      metrics: {
        openCount: 0,
        settlingCount: 0,
        remainingCents: 0,
        readyCount: 0,
        tasksCount: 0,
        blockedCount: 0,
      },
      capacity: { requestCount: 0, warning: false, threshold: 10000 },
    };
  }
  function enterFallback(error) {
    // 回退也撤销在途详情、附件及表单票据，已认证锚点仅供后续显式刷新恢复。
    epoch++;
    listRevision++;
    refreshJob = null;
    loading = false;
    authenticating = false;
    snapshotReady = false;
    clearSessionViews();
    connected = false;
    const role = actor.role in D.roles ? actor.role : "dispatcher";
    actor = {
      id: role,
      role,
      displayName: "演示" + D.roles[role],
      companyId: "company-demo",
    };
    dataKind = "demo";
    data = structuredClone(demo);
    data.actor = actor;
    page = 1;
    $("#connectionNote").textContent =
      "独立合成演示 · " +
      error.message +
      " 未复制服务端资料或当前表单；恢复连接后重新加载自动使用服务端数据。";
    if (error.status === 401 && token) {
      token = "";
      sessionActor = null;
      toast("会话已失效，请重新登录。合成样例继续可预览。");
    }
    render();
  }
  async function loadOrders({ reset = false } = {}) {
    if (reset) page = 1;
    if (dataKind !== "server") {
      render();
      if (!loading && token) refresh();
      return;
    }
    const revision = epoch,
      sequence = ++listRevision,
      query = orderQuery();
    $("#tableSummary").textContent = "正在加载当前筛选结果…";
    try {
      const result = await request("/orders?" + query);
      if (revision !== epoch || sequence !== listRevision) return;
      data.orders = result.items;
      data.orderPage = {
        page: result.page,
        pageSize: result.pageSize,
        total: result.total,
        totalPages: result.totalPages,
      };
      page = result.page;
      connected = true;
    } catch (error) {
      if (revision !== epoch || sequence !== listRevision) return;
      enterFallback(error);
    }
    render();
  }
  function changeFilters() {
    loadOrders({ reset: true });
  }
  function renderOrders() {
    const orders = pageOrders(),
      info = pageInfo(),
      all = currentOrders();
    $("#orderCount").textContent = info.total;
    $("#blockedCount").textContent =
      dataKind === "server"
        ? data.metrics.blockedCount
        : all.filter((o) => (o.issues || []).some((i) => !i.resolved)).length;
    $("#ordersBody").innerHTML = orders
      .map((o) => {
        const s = summary(o),
          doc = displayDocument(o),
          inv = displayInvoice(o),
          color =
            o.status === "completed"
              ? "green"
              : [
                    "settling",
                    "pending_customer_confirmation",
                    "pending_completion",
                  ].includes(o.status)
                ? "amber"
                : "blue",
          docOk = ["已发送", "无需，已确认"].includes(doc),
          invOk = ["已满足", "无需，已确认"].includes(inv);
        return (
          '<tr><td><span class="order-number">' +
          safe(o.number) +
          '</span><div class="order-title">' +
          safe(o.customer) +
          '</div><span class="order-equipment">' +
          safe(o.device) +
          '<span class="type-chip">' +
          safe(typeNames[o.type] || o.type) +
          "</span></span></td><td>" +
          badge(D.states[o.status] || o.status, color) +
          '<span class="cell-sub">' +
          safe(outcomes[o.outcome] || "履约进行中") +
          (o.outcome ? " · " + safe(s.warrantyLabel) : "") +
          '</span></td><td><span class="mobile-label">付款资料</span><button class="cell-action" data-open="' +
          safe(o.id) +
          '" data-tab="finance">' +
          badge(doc, docOk ? "green" : "amber") +
          '</button><span class="cell-sub">' +
          (o.documents?.requirement === "none"
            ? "需求已确认"
            : "资料包 v" + (o.documents?.version || 1)) +
          '</span></td><td><span class="mobile-label">票据进度</span><button class="cell-action" data-open="' +
          safe(o.id) +
          '" data-tab="finance">' +
          badge(inv, invOk ? "green" : "amber") +
          '</button><span class="cell-sub">' +
          (o.invoiceRequirement === "none"
            ? "需求已确认"
            : money(s.invoiceCents) + " / " + money(o.invoiceDueCents || 0)) +
          '</span></td><td><span class="mobile-label">核实收款 / 应收</span><div class="amount">' +
          money(s.collectedCents) +
          " <small>/ " +
          money(s.receivableCents) +
          '</small></div><div class="money-progress"><span style="width:' +
          Math.min(
            100,
            s.receivableCents
              ? Math.max(0, (s.collectedCents / s.receivableCents) * 100)
              : 0,
          ) +
          '%"></span></div><span class="cell-sub ' +
          (s.pendingCashCents || s.overpaidCents ? "warning" : "") +
          '">' +
          (s.pendingCashCents
            ? money(s.pendingCashCents) + " 待核实"
            : s.overpaidCents
              ? "超收 " + money(s.overpaidCents)
              : s.remainingCents
                ? "部分 / 尚未收款"
                : !o.quote?.amountCents && !o.outcome
                  ? "应收待确认"
                  : "已结清") +
          '</span></td><td><span class="mobile-label">待收金额</span><div class="amount ' +
          (s.remainingCents ? "remaining" : "zero") +
          '">' +
          money(s.remainingCents) +
          '</div></td><td><div class="next-task">' +
          safe(s.nextTask) +
          '</div><span class="cell-sub">' +
          safe(o.ownerId || "负责人待安排") +
          " · " +
          date(o.updatedAt) +
          '</span></td><td><button class="row-open" data-open="' +
          safe(o.id) +
          '">办理 →</button></td></tr>'
        );
      })
      .join("");
    $("#ordersEmpty").hidden = !!orders.length;
    if (!orders.length)
      $("#ordersEmpty").innerHTML = empty("暂无符合条件的工单");
    $("#tableSummary").textContent =
      "本页 " + orders.length + " 条 / 共 " + info.total + " 张工单";
    $("#orderPagination").innerHTML = pager();
    renderAttention();
  }
  function renderAttention() {
    const list = currentOrders()
      .filter((o) => o.status !== "completed")
      .sort(
        (a, b) =>
          (b.status === "pending_completion") -
          (a.status === "pending_completion"),
      )
      .slice(0, 3);
    $("#attentionList").innerHTML = list.length
      ? list
          .map(
            (o) =>
              '<div class="attention-item" data-open="' +
              safe(o.id) +
              '"><span class="attention-icon">' +
              (o.status === "pending_completion" ? "✓" : "◷") +
              "</span><div><strong>" +
              safe(summary(o).nextTask) +
              "</strong><small>" +
              safe(o.number) +
              " · " +
              safe(o.customer) +
              "</small></div><span>查看 →</span></div>",
          )
          .join("")
      : empty("暂无待处理事项");
  }
  function tasks() {
    const list = [];
    pageOrders()
      .filter((o) => o.status !== "completed")
      .forEach((o) => {
        list.push({
          order: o,
          title: summary(o).nextTask,
          owner: o.ownerId,
          due: o.updatedAt,
        });
        if (internal()) {
          (o.visits || [])
            .filter((v) => !v.started && !v.startedAt)
            .forEach((v) =>
              list.push({
                order: o,
                title: "上门行程 · " + (v.note || "现场处理"),
                owner: o.assigneeId,
                due: v.plannedAt,
                action: "start_visit",
                id: v.id,
              }),
            );
          (o.issues || [])
            .filter((i) => !i.resolved)
            .forEach((i) =>
              list.push({
                order: o,
                title: "协商 · " + (i.title || i.note),
                owner: i.ownerId,
                due: i.dueAt,
                action: "resolve_issue",
                id: i.id,
              }),
            );
          (o.obligations || [])
            .filter((i) => !i.resolved)
            .forEach((i) =>
              list.push({
                order: o,
                title: i.title,
                owner: i.ownerId,
                due: i.dueAt,
                action: "resolve_obligation",
                id: i.id,
              }),
            );
        }
      });
    return list;
  }
  function renderTasks() {
    const list = tasks();
    $("#taskCount").textContent =
      dataKind === "server" ? data.metrics.tasksCount : list.length;
    $("#tasksView").innerHTML =
      '<section class="panel"><div class="panel-heading"><div><h2>并行待办与内部上门</h2><p>处理一个事项不会覆盖同单其他人员的待办</p></div><button class="button" data-reload>重新加载</button></div>' +
      (list.length
        ? list
            .map(
              (t) =>
                '<article class="list-card"><div><h3>' +
                safe(t.title) +
                "</h3><p>" +
                safe(t.order.number) +
                " · " +
                safe(t.owner || "待认领") +
                " · " +
                date(t.due) +
                '</p></div><div class="card-actions">' +
                (t.action
                  ? recordActionButton(t.order, t.action, t.id, "办理本项")
                  : "") +
                '<button class="button quiet" data-open="' +
                safe(t.order.id) +
                '" data-tab="collaboration">工单详情</button></div></article>',
            )
            .join("")
        : empty("暂无待办")) +
      pager() +
      "</section>";
  }
  function renderFinance() {
    const orders = pageOrders(),
      cash = orders.flatMap((o) => (o.cash || []).map((c) => ({ o, c })));
    $("#financeView").innerHTML =
      '<section class="panel"><div class="panel-heading"><div><h2>现金登记与核实</h2><p>待核实不计实收；内部现金交接不重复计收入；退款关联原业务</p></div><button class="button" data-reload>重新加载</button></div>' +
      (cash.length
        ? '<div class="table-container"><table class="data-table"><thead><tr><th>工单 / 客户</th><th>用途</th><th>现金金额</th><th>事实状态</th><th>操作</th></tr></thead><tbody>' +
          cash
            .map(
              ({ o, c }) =>
                "<tr><td>" +
                safe(o.number) +
                '<span class="cell-sub">' +
                safe(o.customer) +
                "</span></td><td>" +
                safe(c.purpose) +
                '<span class="cell-sub">' +
                safe(c.collector) +
                " · " +
                date(c.occurredAt) +
                '</span></td><td class="amount">' +
                (c.kind === "refund" ? "−" : "") +
                money(c.amountCents) +
                "</td><td>" +
                badge(
                  c.verified ? "已财务核实" : "待财务核实",
                  c.verified ? "green" : "amber",
                ) +
                '<span class="cell-sub">' +
                (c.handedOver ? "内部已交接" : "内部未交接") +
                '</span></td><td><div class="action-list">' +
                (!c.verified
                  ? recordActionButton(o, "verify_cash", c.id)
                  : !c.handedOver
                    ? recordActionButton(o, "handover_cash", c.id)
                    : "") +
                '<button class="button quiet" data-open="' +
                safe(o.id) +
                '" data-tab="finance">查看票款</button></div></td></tr>',
            )
            .join("") +
          "</tbody></table></div>"
        : empty(
            "暂无现金记录",
            "进入工单详情登记每笔收款或退款，再由财务核实。",
          )) +
      '</section><h2 class="subheading">资料与票据待办</h2><section class="panel">' +
      (orders.length
        ? orders
            .filter((o) => o.status !== "completed")
            .map(
              (o) =>
                '<article class="list-card"><div><h3>' +
                safe(o.number) +
                " · " +
                safe(o.customer) +
                "</h3><p>资料：" +
                safe(displayDocument(o)) +
                " · 票据：" +
                safe(displayInvoice(o)) +
                " · 待收 " +
                money(summary(o).remainingCents) +
                '</p></div><button class="button" data-open="' +
                safe(o.id) +
                '" data-tab="finance">办理 →</button></article>',
            )
            .join("")
        : empty("暂无资料票据事项")) +
      pager() +
      "</section>";
  }
  function loanRemaining(loan) {
    return Number.isSafeInteger(loan.outstanding)
      ? loan.outstanding
      : loan.quantity -
          loan.returnedGood -
          loan.returnedQuarantine -
          loan.consumed -
          loan.disposed;
  }
  function renderInventory() {
    const parts = data.parts || [],
      loans = data.loans || [],
      purchases = data.purchases || [],
      canWarehouse = ["admin", "warehouse"].includes(actor.role);
    $("#inventoryView").innerHTML =
      '<section class="panel"><div class="panel-heading"><div><h2>配件库存</h2><p>借出、归还、隔离及耗用分别记账；内部借用不形成销售收入</p></div><div class="action-list">' +
      (["admin", "warehouse", "dispatcher"].includes(actor.role)
        ? '<button class="button" data-global="purchase">＋ 采购登记</button>'
        : "") +
      (canWarehouse
        ? '<button class="button primary" data-global="loan">＋ 登记借出</button>'
        : "") +
      '<button class="button" data-reload>重新加载</button></div></div>' +
      (parts.length
        ? '<div class="inventory-stats">' +
          parts
            .map(
              (p) =>
                '<article class="inventory-stat"><strong>' +
                p.available +
                "</strong><span>" +
                safe(p.name) +
                "</span><span>" +
                safe(p.sku) +
                " · 隔离 " +
                p.quarantine +
                " 件</span></article>",
            )
            .join("") +
          "</div>"
        : empty("暂无授权库存")) +
      '</section><h2 class="subheading">内部借还台账</h2><section class="panel">' +
      (loans.length
        ? '<div class="table-container"><table class="data-table"><thead><tr><th>借用配件 / 原工单</th><th>借用人 / 到期</th><th>数量去向</th><th>尚欠</th><th>办理</th></tr></thead><tbody>' +
          loans
            .map(
              (l) =>
                "<tr><td>" +
                safe(
                  l.partName ||
                    parts.find((p) => p.id === l.partId)?.name ||
                    l.partId,
                ) +
                '<span class="cell-sub">' +
                safe(l.orderId || "独立内部借用") +
                "</span></td><td>" +
                safe(l.borrowerId) +
                '<span class="cell-sub">' +
                date(l.dueAt) +
                "</span></td><td>借出 " +
                l.quantity +
                " · 完好还 " +
                l.returnedGood +
                " · 隔离还 " +
                l.returnedQuarantine +
                '<span class="cell-sub">转耗用 ' +
                l.consumed +
                " · 处置 " +
                l.disposed +
                " · 尚欠中独立跟踪 " +
                (loanRemaining(l) - D.loanBlockingQuantity(l)) +
                " · 原单待清 " +
                D.loanBlockingQuantity(l) +
                "</span></td><td>" +
                badge(
                  loanRemaining(l) + " 件",
                  loanRemaining(l) ? "amber" : "green",
                ) +
                '</td><td><div class="action-list">' +
                (canWarehouse && loanRemaining(l) > 0
                  ? '<button class="button" data-loan="' +
                    safe(l.id) +
                    '" data-loan-action="return">归还</button>'
                  : "") +
                (["admin", "warehouse"].includes(actor.role) &&
                loanRemaining(l) > 0
                  ? '<button class="button" data-loan="' +
                    safe(l.id) +
                    '" data-loan-action="consume">转耗用</button><button class="button" data-loan="' +
                    safe(l.id) +
                    '" data-loan-action="dispose">批准处置</button>' +
                    (D.loanBlockingQuantity(l) > 0
                      ? '<button class="button" data-loan="' +
                        safe(l.id) +
                        '" data-loan-action="transfer">独立跟踪</button>'
                      : "")
                  : "") +
                "</div></td></tr>",
            )
            .join("") +
          "</tbody></table></div>"
        : empty(
            "暂无借用记录",
            "借出前记录配件、实际数量、责任人和预计归还日。",
          )) +
      '</section><h2 class="subheading">采购与收货</h2><section class="panel">' +
      (purchases.length
        ? purchases
            .map(
              (p) =>
                '<article class="list-card"><div><h3>' +
                safe(p.supplier) +
                " · " +
                safe(parts.find((i) => i.id === p.partId)?.name || p.partId) +
                "</h3><p>已收 " +
                p.received +
                " / 采购 " +
                p.quantity +
                " · 单价 " +
                money(p.unitCents) +
                " · " +
                safe(p.note) +
                "</p></div>" +
                (canWarehouse && p.received < p.quantity
                  ? '<button class="button" data-purchase="' +
                    safe(p.id) +
                    '">登记实际收货</button>'
                  : badge("已收齐", "green")) +
                "</article>",
            )
            .join("")
        : empty("暂无采购记录")) +
      "</section>";
  }
  function renderSettings() {
    $("#settingsView").innerHTML =
      '<div class="setting-layout"><section class="panel setting-panel"><h2>身份与角色</h2><div class="inline-note">当前：' +
      safe(D.roles[actor.role] || actor.role) +
      " · " +
      (token ? "服务端已认证" : "合成演示身份") +
      '<br>这里的账号仅用于受控合成演示，不能作为真实客户身份。</div><form id="loginForm"><label class="form-field">账号<input name="username" id="loginUsername" value="' +
      safe(actor.username || actor.id || actor.role) +
      '" required autocomplete="username"></label><label class="form-field">合成演示密码<input name="password" type="password" value="Demo-Repair-2026!" required autocomplete="current-password"><small>合成账号统一密码 Demo-Repair-2026!，不属于真实业务凭据。</small></label><div class="action-list"><button class="button primary" type="submit">连接服务并登录</button><button class="button" type="button" id="logout">退出当前会话</button></div></form><div class="role-grid">' +
      Object.entries(D.roles)
        .map(
          ([id, label]) =>
            '<button class="role-button ' +
            (actor.role === id ? "active" : "") +
            '" data-role="' +
            id +
            '">' +
            label +
            "</button>",
        )
        .join("") +
      '</div><div class="action-list"><button class="button" id="localDemo">打开独立合成演示</button><button class="button" data-login="customer-peer">接替经办人登录</button></div><p>角色切换重新请求登录，由服务端判断授权。接口拒绝不产生虚假成功。</p></section><section class="panel setting-panel"><h2>连接与公司配置</h2><form id="connectionForm"><label class="form-field">服务地址<input name="base" placeholder="留空使用当前同源服务" value="' +
      safe(apiBase) +
      '"><small>留空或填写当前页面同源地址。离线文件仅供演示，切换服务请打开目标服务页面。</small></label><label class="form-field">请求超时（毫秒）<input name="timeout" type="number" min="500" max="15000" value="' +
      timeoutMs +
      '" required></label><button class="button" type="submit">保存地址并重载</button></form><hr style="border:0;border-top:1px solid var(--line);margin:24px 0"><form id="companyForm"><label class="form-field">公司寄送地址<textarea name="companyAddress" required>' +
      safe(data.settings?.companyAddress || "") +
      '</textarea></label><label class="form-field">公司收件人<input name="companyReceiver" value="' +
      safe(data.settings?.companyReceiver || "待配置") +
      '" required></label><label class="form-field">公司联系电话<input name="companyPhone" value="' +
      safe(data.settings?.companyPhone || "待配置") +
      '" required></label><label class="form-field">站内提醒提前量（小时）<input name="reminderHours" type="number" min="1" max="168" value="' +
      (data.settings?.reminderHours || 24) +
      '"></label>' +
      (actor.role === "admin"
        ? '<button class="button primary" type="submit"' +
          (dataKind === "server" && !snapshotReady ? " disabled" : "") +
          ">保存公司配置</button>" +
          (dataKind === "server" && !snapshotReady
            ? "<p>正在读取当前账号的公司配置，加载完成后可保存。</p>"
            : "")
        : "<p>公司设置仅管理员可保存。</p>") +
      "</form><p>首期仅现金登记。地图、物流查询、短信、聚合支付与腾讯电子签按后续阶段接入，当前以真实人工事实留痕。</p></section></div>";
  }
  async function settingsMetadata() {
    const revision = epoch,
      sequence = ++metadataRevision;
    $("#settingsView").insertAdjacentHTML(
      "beforeend",
      '<section class="panel setting-panel" style="margin-top:22px"><h2>数据保护与独立备份</h2><div id="securityState" class="inline-note">正在核对备份配置与上次结果。</div><button class="button" data-reload>重新核对</button></section>' +
        (actor.role === "admin"
          ? '<section class="panel setting-panel" style="margin-top:22px"><div class="panel-heading compact" style="padding:0 0 18px"><h2>账号状态与人员权限</h2><button class="button" data-reload>重新加载</button></div><div id="accountList">' +
            empty("正在读取账号") +
            '</div></section><section class="panel setting-panel" style="margin-top:22px"><div class="panel-heading compact" style="padding:0 0 18px"><h2>安全审计记录</h2><button class="button" data-audit-reload>重新加载</button></div><div id="auditList">' +
            empty("正在读取审计记录") +
            "</div></section>"
          : ""),
    );
    try {
      if (location.protocol === "file:") throw new Error("离线预览");
      const response = await fetch(apiBase + "/securityz", {
        signal: AbortSignal.timeout(timeoutMs),
      });
      revokeSession(revision, response.status);
      if (!response.ok) throw new Error("状态入口不可用");
      const value = await response.json();
      if (
        revision !== epoch ||
        sequence !== metadataRevision ||
        view !== "settings"
      )
        return;
      $("#securityState").textContent =
        (value.configured ? "独立备份已配置" : "独立备份尚未配置") +
        " · 存储 " +
        (value.storage || "本机") +
        " · 最近成功 " +
        (value.lastSuccess && !String(value.lastSuccess).startsWith("0001")
          ? date(value.lastSuccess)
          : "尚无成功记录") +
        (value.error ? " · " + value.error : "") +
        "。当前仅用于合成样例，真实资料启用前按部署说明核验可信加密链路与恢复演练。";
    } catch (error) {
      if (
        revision === epoch &&
        sequence === metadataRevision &&
        view === "settings"
      )
        $("#securityState").textContent =
          "无法读取服务安全状态。独立离线演示不代表真实备份与加密配置已完成。";
    }
    if (
      revision !== epoch ||
      sequence !== metadataRevision ||
      view !== "settings" ||
      actor.role !== "admin"
    )
      return;
    if (dataKind !== "server" || !token) {
      $("#accountList").innerHTML = empty(
        "独立演示没有服务端账号资料",
        "连接服务并认证管理员后加载账号。",
      );
      $("#auditList").innerHTML = empty(
        "独立演示没有服务端审计台账",
        "认证服务端管理员后查看必要审计元数据。",
      );
      return;
    }
    try {
      const accounts = await request("/accounts");
      if (
        revision !== epoch ||
        sequence !== metadataRevision ||
        view !== "settings"
      )
        return;
      $("#accountList").innerHTML = accounts.length
        ? accounts
            .map(
              (a) =>
                '<article class="list-card"><div><h3>' +
                safe(a.name) +
                " · " +
                safe(D.roles[a.role] || a.role) +
                "</h3><p>" +
                safe(a.id) +
                " · " +
                safe(a.companyId || "内部账号") +
                '</p></div><div class="card-actions">' +
                badge(
                  a.status === "disabled" ? "已停用" : "有效",
                  a.status === "disabled" ? "red" : "green",
                ) +
                (a.id !== actor.id
                  ? '<button class="button" data-account="' +
                    safe(a.id) +
                    '" data-status="' +
                    (a.status === "disabled" ? "active" : "disabled") +
                    '">' +
                    (a.status === "disabled" ? "恢复授权" : "停用账号") +
                    "</button>"
                  : "") +
                "</div></article>",
            )
            .join("")
        : empty("暂无账号");
    } catch (error) {
      if (
        revision === epoch &&
        sequence === metadataRevision &&
        view === "settings"
      )
        $("#accountList").innerHTML = empty("账号列表未加载", error.message);
    }
    if (
      revision === epoch &&
      sequence === metadataRevision &&
      view === "settings"
    )
      await loadAudit();
  }
  async function loadAudit({ reset = false } = {}) {
    if (
      actor.role !== "admin" ||
      dataKind !== "server" ||
      !token ||
      view !== "settings"
    )
      return;
    if (reset) auditPage = 1;
    const revision = epoch,
      sequence = ++auditRevision;
    $("#auditList").innerHTML = empty("正在读取安全审计记录");
    try {
      const result = await request("/audit?page=" + auditPage + "&pageSize=30");
      if (
        revision !== epoch ||
        sequence !== auditRevision ||
        view !== "settings"
      )
        return;
      auditPage = result.page;
      const labels = {
        account_status: "账号授权变更",
        export: "导出资料",
        download: "下载证据",
        evidence_download: "下载证据",
        order_read: "读取工单详情",
        login: "登录",
        authentication: "身份校验",
        logout: "退出登录",
        backup: "备份",
        restore: "恢复",
      };
      const results = { success: "成功", denied: "已拒绝" };
      const auditRoles = { anonymous: "未登录", system: "恢复工具" };
      $("#auditList").innerHTML =
        (result.items.length
          ? result.items
              .map(
                (entry) =>
                  '<article class="list-card"><div><h3>' +
                  safe(labels[entry.type] || entry.type) +
                  " · " +
                  safe(results[entry.result] || entry.result) +
                  "</h3><p>" +
                  safe(entry.actorId) +
                  " · " +
                  safe(
                    D.roles[entry.actorRole] ||
                      auditRoles[entry.actorRole] ||
                      entry.actorRole,
                  ) +
                  " · " +
                  date(entry.at) +
                  "</p><p>" +
                  safe(entry.resource || "") +
                  (entry.resourceIds?.length
                    ? " · " + safe(entry.resourceIds.join("、"))
                    : "") +
                  "</p>" +
                  (entry.reason
                    ? "<p>依据：" + safe(entry.reason) + "</p>"
                    : "") +
                  "</div></article>",
              )
              .join("")
          : empty(
              "暂无安全审计记录",
              "后续授权变更及资料读取会记录必要元数据。",
            )) +
        '<div class="list-pagination"><span>共 ' +
        result.total +
        " 条 · 第 " +
        result.page +
        ' 页</span><div class="action-list"><button class="button quiet" data-audit-page="previous"' +
        (result.page <= 1 ? " disabled" : "") +
        '>上一页</button><button class="button quiet" data-audit-page="next"' +
        (result.page * result.pageSize >= result.total ? " disabled" : "") +
        ">下一页</button></div></div>";
    } catch (error) {
      if (
        revision === epoch &&
        sequence === auditRevision &&
        view === "settings"
      )
        $("#auditList").innerHTML = empty("安全审计记录未加载", error.message);
    }
  }
  function accountStatusForm(id, status) {
    modal(
      status === "disabled" ? "停用账号授权" : "恢复账号授权",
      '<div class="inline-note warning">停用后立即撤销该账号后续访问与会话，不抹去历史作者、签署与责任记录。</div><div class="form-grid">' +
        field("reason", "状态变更依据与交接说明", "textarea") +
        "</div>",
      async (fd, instance) => {
        const revision = epoch;
        await request("/accounts/" + encodeURIComponent(id) + "/status", {
          method: "POST",
          body: JSON.stringify({ status, reason: fd.get("reason") }),
        });
        if (revision !== epoch) return;
        finishForm(instance);
        render();
        toast("账号状态已更新。");
      },
    );
  }
  function render() {
    renderAccount();
    renderMetrics();
    renderOrders();
    renderTasks();
    renderFinance();
    renderInventory();
    if (view === "settings") {
      renderSettings();
      settingsMetadata();
    }
    if ($("#detailDialog").open && selectedId) renderDetail();
  }
  function showView(next) {
    actionIntent++;
    view = next;
    const names = {
      orders: "工单工作台",
      tasks: "我的待办",
      finance: "现金与票据",
      inventory: "库存与借还",
      settings: "账号与连接",
    };
    document
      .querySelectorAll(".view")
      .forEach((v) => (v.hidden = v.id !== next + "View"));
    document
      .querySelectorAll(".nav-item")
      .forEach((n) => n.classList.toggle("active", n.dataset.view === next));
    $("#breadcrumb").textContent = names[next];
    $("#pageTitle").textContent =
      next === "orders" ? "每一张工单，都有下一步。" : names[next];
    $("#pageSubtitle").textContent = {
      orders: "从受理到整单完结，业务进度、资料票款与责任人一目了然。",
      tasks: "同一工单的协作待办并行办理，内部行程按职责查看。",
      finance: "每一笔现金独立登记、核实与交接，资料票据持续可查。",
      inventory: "记录实物去向与责任，数量守恒，不以状态代替事实。",
      settings: "连接本机服务，确认当前身份与公司业务配置。",
    }[next];
    render();
    if (["orders", "tasks", "finance"].includes(next))
      loadOrders({ reset: true });
    else listRevision++;
  }
  function applySnapshotMetadata(result) {
    if (
      !sameSessionActor(result.actor) ||
      (dataKind === "server" && !sameSessionActor(data.actor))
    )
      return false;
    // 离线恢复时只保留空列表，不能把合成记录挂到真实身份的元数据下。
    const { orders, orderPage } =
      dataKind === "server" ? data : emptyServerSnapshot(sessionActor);
    data = { ...result, orders, orderPage };
    actor = result.actor;
    dataKind = "server";
    snapshotReady = true;
    connected = true;
    $("#connectionNote").textContent =
      "服务端已连接 · 所有数据按当前账号权限返回，保存后自动刷新。";
    return true;
  }
  async function refresh() {
    if (authenticating) return;
    const revision = epoch;
    if (refreshJob?.epoch === revision && refreshJob.running) {
      refreshJob.queued = true;
      listRevision++;
      return refreshJob.promise;
    }
    const job = { epoch: revision, queued: true, running: true, promise: null };
    refreshJob = job;
    loading = true;
    job.promise = (async () => {
      try {
        while (job.queued && revision === epoch) {
          job.queued = false;
          const sequence = ++listRevision;
          let snapshot;
          try {
            const result = await request("/bootstrap");
            if (revision !== epoch || job.queued) continue;
            if (!sameSessionActor(result.actor)) {
              if (sequence !== listRevision && snapshotReady) continue;
              throw new APIError(
                "授权资料与当前认证身份不一致，请重新加载或登录。",
                409,
              );
            }
            snapshot = result;
            if (sequence !== listRevision) {
              // 导航只取代工单页，成功保存后的经营指标与配置仍须更新。
              if (applySnapshotMetadata(result)) render();
              continue;
            }
            let query = orderQuery(),
              orders = await request("/orders?" + query);
            while (
              revision === epoch &&
              sequence === listRevision &&
              query !== orderQuery()
            ) {
              query = orderQuery();
              orders = await request("/orders?" + query);
            }
            if (revision !== epoch || job.queued) continue;
            if (sequence !== listRevision) {
              if (applySnapshotMetadata(result)) render();
              continue;
            }
            data = result;
            data.orders = orders.items;
            data.orderPage = {
              page: orders.page,
              pageSize: orders.pageSize,
              total: orders.total,
              totalPages: orders.totalPages,
            };
            page = orders.page;
            actor = result.actor;
            dataKind = "server";
            snapshotReady = true;
            connected = true;
            $("#connectionNote").textContent =
              "服务端已连接 · 所有数据按当前账号权限返回，保存后自动刷新。";
            if ($("#detailDialog").open && selectedId)
              openDetail(selectedId, detailTab);
          } catch (error) {
            if (revision !== epoch || job.queued) continue;
            if (sequence !== listRevision && snapshot) {
              if (applySnapshotMetadata(snapshot)) render();
              continue;
            }
            enterFallback(error);
          } finally {
            if (revision === epoch && sequence === listRevision) render();
          }
        }
      } finally {
        job.running = false;
      }
    })();
    try {
      await job.promise;
    } finally {
      if (refreshJob === job) {
        refreshJob = null;
        loading = false;
      }
    }
  }
  async function login(username, password) {
    let revision = ++epoch;
    formKeys.clear();
    clearSessionViews();
    refreshJob = null;
    listRevision++;
    page = 1;
    loading = false;
    token = "";
    sessionActor = null;
    snapshotReady = false;
    authenticating = true;
    connected = false;
    actor = {
      id: "dispatcher",
      role: "dispatcher",
      displayName: "演示调度",
      companyId: "company-demo",
    };
    dataKind = "demo";
    data = structuredClone(demo);
    data.actor = actor;
    $("#connectionNote").textContent =
      "正在认证 · 旧账号资料已清除，当前仅显示独立合成样例。";
    render();
    try {
      const result = await request("/login", {
        method: "POST",
        body: JSON.stringify({ username, password }),
      });
      if (revision !== epoch) return;
      if (result.actor.status !== "active")
        throw new APIError("账号当前不可用，请核对授权。", 401);
      // 认证等待期间新开的合成表单也必须重新核对，不能沿用到新账号。
      revision = ++epoch;
      clearSessionViews();
      listRevision++;
      page = 1;
      token = result.token;
      sessionActor = structuredClone(result.actor);
      actor = sessionActor;
      authenticating = false;
      dataKind = "server";
      data = emptyServerSnapshot(actor);
      $("#connectionNote").textContent = "当前账号已认证 · 正在读取授权资料。";
      render();
      await refresh();
      if (revision === epoch && dataKind === "server")
        toast("已登录为 " + (D.roles[actor.role] || actor.role));
    } catch (error) {
      if (revision !== epoch) return;
      authenticating = false;
      toast(error.message + " 未建立服务端身份。");
      $("#connectionNote").textContent = "登录未完成 · " + error.message;
      connected = false;
      render();
    }
  }
  function openDemo(role = actor.role) {
    epoch++;
    formKeys.clear();
    clearSessionViews();
    refreshJob = null;
    listRevision++;
    page = 1;
    loading = false;
    token = "";
    sessionActor = null;
    authenticating = false;
    snapshotReady = false;
    connected = false;
    dataKind = "demo";
    actor = {
      id: role,
      role,
      displayName: "演示" + (D.roles[role] || role),
      companyId: "company-demo",
    };
    demo.actor = actor;
    data = structuredClone(demo);
    $("#connectionNote").textContent =
      "独立合成演示 · 仅录入虚构信息，所有修改均不进入真实业务台账。每次刷新仍尝试连接服务。";
    render();
    toast("已打开独立合成样例 · " + D.roles[role]);
  }
  function recordActionButton(o, type, id, label) {
    if (
      type === "resolve_obligation" &&
      !canResolveObligation(
        (o.obligations || []).find((task) => task.id === id),
      )
    )
      return "";
    return permitted(o, type)
      ? '<button class="button" data-action="' +
          type +
          '" data-order="' +
          safe(o.id) +
          '" data-record="' +
          safe(id) +
          '">' +
          safe(label || D.actionNames[type]) +
          "</button>"
      : "";
  }
  async function completeOrder(id) {
    if (dataKind === "demo") return currentOrders().find((o) => o.id === id);
    const revision = epoch,
      sequence = (detailRequests.get(id) || 0) + 1;
    detailRequests.set(id, sequence);
    const order = await request("/orders/" + encodeURIComponent(id));
    if (order.isSummary === true)
      throw new APIError(
        "详情接口返回工单摘要，请核对服务端接口后重新加载。",
        200,
      );
    if (revision !== epoch)
      throw new APIError("身份或连接已切换，请重新核对。", 409);
    if (detailRequests.get(id) !== sequence)
      throw new APIError("已有较新的工单读取，请重新核对。", 409);
    details.set(id, order);
    return order;
  }
  async function openDetail(id, tab = "overview") {
    actionIntent++;
    selectedId = id;
    detailTab = tab;
    if (!$("#detailDialog").open) $("#detailDialog").showModal();
    if (dataKind === "server") {
      const revision = epoch,
        sequence = ++detailRevision;
      details.delete(id);
      $("#detailContent").innerHTML = empty(
        "正在读取完整工单",
        "核对全部资料与记录后才能办理事实。",
      );
      try {
        await completeOrder(id);
        if (
          revision !== epoch ||
          sequence !== detailRevision ||
          selectedId !== id
        )
          return;
      } catch (error) {
        if (
          revision !== epoch ||
          sequence !== detailRevision ||
          selectedId !== id
        )
          return;
        $("#detailContent").innerHTML =
          '<button class="close-button" data-close="detail" aria-label="关闭详情">×</button>' +
          empty("工单详情未加载", error.message + " · 请重新加载后办理。");
        return;
      }
    }
    try {
      renderDetail();
    } catch (error) {
      details.delete(id);
      $("#detailContent").innerHTML =
        '<button class="close-button" data-close="detail" aria-label="关闭详情">×</button>' +
        empty("工单详情未加载", "详情结构无法展示，请重新加载后办理。");
    }
  }
  function renderDetail() {
    const order =
      dataKind === "server"
        ? details.get(selectedId)
        : currentOrders().find((o) => o.id === selectedId);
    if (!order) {
      if (dataKind !== "server") $("#detailDialog").close();
      return;
    }
    const s = summary(order),
      tabs = [
        ...["overview", "quote", "evidence", "finance"],
        ...(internal() ? ["collaboration", "costs", "loans"] : []),
        "timeline",
      ],
      labels = {
        overview: "工单总览",
        quote: "报价与确认",
        evidence: "全链路证据",
        finance: "资料 · 票据 · 现金",
        collaboration: "协商与上门",
        costs: "外包 · 成本 · 提成",
        loans: "借还余项",
        timeline: "操作时间轴",
      };
    let body = "";
    if (detailTab === "overview")
      body =
        '<div class="flow-steps">' +
        Object.entries(D.states)
          .map(
            ([id, label]) =>
              '<span class="flow-step ' +
              (id === order.status
                ? "current"
                : Object.keys(D.states).indexOf(id) <
                    Object.keys(D.states).indexOf(order.status)
                  ? "done"
                  : "") +
              '">' +
              safe(label) +
              "</span>",
          )
          .join("") +
        '</div><div class="detail-grid"><div><section class="detail-section"><h3>工单信息</h3><dl class="description-list"><dt>客户 / 企业</dt><dd>' +
        safe(order.customer) +
        "</dd><dt>设备 / 配件</dt><dd>" +
        safe(order.device) +
        "</dd><dt>项目 / 类型</dt><dd>" +
        safe(order.project || "未填写") +
        " · " +
        safe(typeNames[order.type]) +
        "</dd><dt>故障 / 需求</dt><dd>" +
        safe(order.description) +
        "</dd><dt>负责人</dt><dd>" +
        safe(order.ownerId || "待安排") +
        " / 执行 " +
        safe(order.assigneeId || "待安排") +
        "</dd><dt>客户说明</dt><dd>" +
        safe(order.customerNote || "暂无已发布说明") +
        "</dd>" +
        (internal()
          ? "<dt>内部备注</dt><dd>" + safe(order.remark || "暂无备注") + "</dd>"
          : "") +
        "<dt>质保</dt><dd>" +
        safe(s.warrantyLabel) +
        " " +
        (order.warranty?.endsAt || order.warranty?.endAt
          ? "· 至 " + date(order.warranty.endsAt || order.warranty.endAt)
          : "") +
        '</dd></dl></section><section class="detail-section"><h3>当前可办理动作</h3><div class="inline-note">' +
        safe(s.nextTask) +
        '<br>提交本次真实事实一次，服务端同步摘要和主阶段。报价与最终验收必须由客户分别签署。</div><div class="action-list">' +
        available(order)
          .map((t) => actionButton(order, t))
          .join("") +
        "</div>" +
        (!available(order).length
          ? '<p class="muted">当前角色只读本单。</p>'
          : "") +
        '</section></div><section class="detail-section"><h3>整单完结核对</h3><div class="inline-note ' +
        (s.missing.length ? "warning" : "") +
        '">' +
        (s.missing.length
          ? "仍有 " + s.missing.length + " 项需要办理"
          : "适用条件已齐，等待授权负责人一次确认。") +
        '</div><ul class="checklist">' +
        [
          { title: "有效履约结果", ok: !!order.outcome },
          {
            title: "付款资料齐备且已发送 / 确认无需",
            ok: ["sent", "not_required", "已发送", "无需，已确认"].includes(
              s.documentStatus,
            ),
          },
          {
            title: "有效票据金额及附件齐备 / 确认无需",
            ok: ["complete", "not_required", "已满足", "无需，已确认"].includes(
              s.invoiceStatus,
            ),
          },
          {
            title: "核实净收款满足应收，超收与待核实均处理",
            ok:
              (!!order.quote?.amountCents || !!order.outcome) &&
              !s.remainingCents &&
              !s.overpaidCents &&
              !s.pendingCashCents,
          },
        ]
          .map(
            (i) =>
              '<li><span class="check-icon ' +
              (!i.ok ? "missing" : "") +
              '">' +
              (i.ok ? "✓" : "○") +
              "</span>" +
              i.title +
              "</li>",
          )
          .join("") +
        "</ul>" +
        (s.missing.length
          ? '<h3 style="margin-top:22px">当前缺项</h3><ul class="checklist">' +
            s.missing
              .map(
                (m) =>
                  '<li><span class="check-icon missing">○</span>' +
                  safe(m) +
                  "</li>",
              )
              .join("")
          : "") +
        '<div class="action-list">' +
        actionButton(order, "complete", null, "primary") +
        "</div></section></div>";
    if (detailTab === "quote") {
      const q = order.quote || {};
      body =
        '<section class="detail-section"><h3>' +
        (order.type === "sale" ? "销售报价确认单" : "报价暨维修确认单") +
        " · v" +
        (q.version || 0) +
        '</h3><dl class="description-list"><dt>当前含税总价</dt><dd class="amount">' +
        money(q.amountCents || 0) +
        "</dd><dt>范围 / 条款</dt><dd>" +
        safe(q.description || "尚未拟定") +
        "</dd><dt>付款约定</dt><dd>" +
        (q.paymentTerms === "credit" ? "企业账期" : "现金约定") +
        " · 约定预付 " +
        money(q.prepayCents || 0) +
        (order.type !== "sale"
          ? " · " +
            (q.startRequiresPrepayment
              ? "明确约定先款：核实约定预付款后开修"
              : "未约定先款开修")
          : "") +
        "</dd><dt>质保</dt><dd>" +
        (q.warrantyMonths || 3) +
        " 个月</dd><dt>报价接受期限</dt><dd>" +
        safe(q.validUntil || "未约定") +
        "</dd><dt>确认事实</dt><dd>" +
        badge(
          q.signed
            ? "客户已一次签署"
            : q.approved
              ? "公司已审核，待客户签署"
              : "待公司审核",
          q.signed ? "green" : "amber",
        ) +
        "</dd>" +
        (q.signed
          ? "<dt>签署人 / 时间</dt><dd>" +
            safe(q.signer) +
            " · " +
            date(q.signedAt) +
            "</dd>"
          : "") +
        '</dl><div class="action-list" style="margin-top:22px">' +
        ["quote", "approve_quote", "sign_quote", "accept"]
          .map((t) => actionButton(order, t))
          .join("") +
        '<button class="button" data-download-order="' +
        safe(order.id) +
        '">下载当前单据摘要</button></div></section><div class="inline-note">报价与维修事项合并一次确认；最终验收独立办理，不能复用报价签名。手写签名是业务留痕，当前未接第三方认证电子签。</div>';
    }
    if (detailTab === "evidence")
      body =
        '<section class="detail-section"><div class="panel-heading compact" style="padding:0 0 18px"><h3 style="margin:0">文字 · 图片 · 视频 · 语音与业务文件</h3>' +
        actionButton(order, "evidence") +
        "</div>" +
        evidenceList(order) +
        "</section>";
    if (detailTab === "finance")
      body =
        '<div class="detail-grid"><div><section class="detail-section"><h3>付款资料</h3>' +
        badge(
          displayDocument(order),
          ["已发送", "无需，已确认"].includes(displayDocument(order))
            ? "green"
            : "amber",
        ) +
        '<dl class="description-list" style="margin-top:17px"><dt>需求依据</dt><dd>' +
        safe(order.documents?.reason || "待确认") +
        "</dd><dt>资料包版本</dt><dd>v" +
        (order.documents?.version || 1) +
        "</dd><dt>实际发送对象</dt><dd>" +
        safe(order.documents?.recipient || "尚未发送") +
        '</dd></dl><div class="action-list" style="margin-top:18px">' +
        actionButton(order, "requirements") +
        actionButton(order, "documents") +
        '</div></section><section class="detail-section"><h3>真实票据 · 有效含税 ' +
        money(s.invoiceCents) +
        " / " +
        money(order.invoiceDueCents || 0) +
        "</h3>" +
        (order.invoices?.length
          ? order.invoices
              .map(
                (i) =>
                  '<div class="file-card"><div>' +
                  safe(i.number) +
                  " · " +
                  money(i.amountCents) +
                  "<p>" +
                  (i.voided ? "原票已红冲 / 作废" : "有效票据") +
                  " · " +
                  (i.files?.length || 0) +
                  " 个关联文件</p></div>" +
                  (!i.voided
                    ? recordActionButton(order, "void_invoice", i.id)
                    : "") +
                  "</div>",
              )
              .join("")
          : empty(
              "暂无票据记录",
              "需票时须上传真实 PDF / 图片并登记票号与含税金额。",
            )) +
        '<div class="action-list">' +
        actionButton(order, "invoice") +
        '</div></section></div><section class="detail-section"><h3>现金收款与退款</h3><dl class="description-list"><dt>核实净收款</dt><dd class="amount">' +
        money(s.collectedCents) +
        "</dd><dt>有效应收</dt><dd>" +
        money(s.receivableCents) +
        "</dd><dt>待收 / 超收</dt><dd>" +
        money(s.remainingCents) +
        " / " +
        money(s.overpaidCents) +
        "</dd><dt>现金待核实</dt><dd>" +
        money(s.pendingCashCents) +
        '</dd></dl><div class="action-list" style="margin:20px 0">' +
        actionButton(order, "cash") +
        actionButton(order, "adjust_receivable") +
        "</div>" +
        ((order.cash || []).length
          ? order.cash
              .map(
                (c) =>
                  '<div class="file-card"><div>' +
                  safe(c.kind === "refund" ? "现金退款" : "现金收款") +
                  " " +
                  money(c.amountCents) +
                  "<p>" +
                  safe(c.purpose || "") +
                  " · " +
                  (c.verified ? "已核实" : "待核实") +
                  " · " +
                  (c.handedOver ? "已交接" : "未交接") +
                  "</p><p>" +
                  safe(c.receipt || "无凭证说明") +
                  '</p></div><div class="action-list">' +
                  (!c.verified
                    ? recordActionButton(order, "verify_cash", c.id)
                    : !c.handedOver
                      ? recordActionButton(order, "handover_cash", c.id)
                      : "") +
                  "</div></div>",
              )
              .join("")
          : empty("暂无现金记录")) +
        "</section></div>";
    if (detailTab === "collaboration")
      body =
        '<div class="detail-grid"><div><section class="detail-section"><h3>协商 / 异议</h3>' +
        ((order.issues || []).length
          ? order.issues
              .map(
                (i) =>
                  '<div class="file-card"><div>' +
                  safe(i.title || i.note) +
                  "<p>" +
                  safe(i.ownerId) +
                  " · " +
                  (i.resolved
                    ? "已处理：" + safe(i.resolution || i.note)
                    : "未解决") +
                  "</p></div>" +
                  (!i.resolved
                    ? recordActionButton(order, "resolve_issue", i.id)
                    : badge("已解决", "green")) +
                  "</div>",
              )
              .join("")
          : empty("暂无协商记录")) +
        '<div class="action-list">' +
        actionButton(order, "issue") +
        actionButton(order, "failure") +
        '</div></section><section class="detail-section"><h3>本单适用余项</h3>' +
        ((order.obligations || []).length
          ? order.obligations
              .map(
                (i) =>
                  '<div class="file-card"><div>' +
                  safe(i.title) +
                  "<p>" +
                  safe(i.ownerId) +
                  " · " +
                  safe(i.dueAt || "") +
                  "</p></div>" +
                  (!i.resolved
                    ? recordActionButton(order, "resolve_obligation", i.id)
                    : badge("已办理", "green")) +
                  "</div>",
              )
              .join("")
          : empty("暂无内部余项")) +
        actionButton(order, "obligation") +
        '</section></div><section class="detail-section"><h3>内部上门行程与费用备忘</h3><div class="inline-note">该模块不向客户展示。已发生行程只能管理员留依据更正。</div>' +
        ((order.visits || []).length
          ? order.visits
              .map(
                (v) =>
                  '<div class="file-card"><div>' +
                  date(v.plannedAt) +
                  "<p>" +
                  safe(v.note) +
                  " · " +
                  safe(v.feeMemo) +
                  '</p></div><div class="action-list">' +
                  (!v.started && !v.startedAt
                    ? recordActionButton(order, "start_visit", v.id)
                    : badge("已发生", "green")) +
                  recordActionButton(order, "visit", v.id, "调整 / 留痕更正") +
                  "</div></div>",
              )
              .join("")
          : empty("暂无内部行程")) +
        actionButton(order, "visit") +
        "</section></div>";
    if (detailTab === "costs")
      body =
        '<div class="detail-grid"><div><section class="detail-section"><h3>一手外包与可选后续流向</h3>' +
        ((order.outsource || []).length
          ? order.outsource
              .map(
                (o) =>
                  '<div class="file-card"><div>' +
                  safe(o.provider) +
                  "<p>" +
                  safe(o.contact || "联系人未知") +
                  " · " +
                  safe(o.destination || "后续流向未知") +
                  "</p><p>" +
                  safe(o.note) +
                  "</p></div></div>",
              )
              .join("")
          : empty("暂无外包流向")) +
        actionButton(order, "outsource") +
        '</section><section class="detail-section"><h3>提成结算</h3>' +
        ((order.commissions || []).length
          ? order.commissions
              .map(
                (c) =>
                  '<div class="file-card"><div>' +
                  safe(c.person) +
                  " · " +
                  money(c.amountCents) +
                  "<p>" +
                  safe(c.note) +
                  " · " +
                  (c.settled ? "已结算" : "待结算") +
                  "</p></div>" +
                  (!c.settled
                    ? recordActionButton(order, "settle_commission", c.id)
                    : "") +
                  "</div>",
              )
              .join("")
          : empty("暂无提成记录")) +
        actionButton(order, "commission") +
        '</section></div><section class="detail-section"><h3>内部成本与审批</h3>' +
        ((order.costs || []).length
          ? order.costs
              .map(
                (c) =>
                  '<div class="file-card"><div>' +
                  safe(c.category) +
                  " · " +
                  money(c.amountCents) +
                  "<p>" +
                  safe(c.note) +
                  " · " +
                  (c.approved ? "已审核" : "待审核") +
                  "</p></div>" +
                  (!c.approved
                    ? recordActionButton(order, "approve_cost", c.id)
                    : "") +
                  "</div>",
              )
              .join("")
          : empty("暂无成本记录")) +
        actionButton(order, "cost") +
        "</section></div>";
    if (detailTab === "loans") {
      const loans = (data.loans || []).filter((l) => l.orderId === order.id);
      body =
        '<section class="detail-section"><h3>关联内部配件借还</h3><div class="inline-note">借出 = 完好归还 + 隔离归还 + 转耗用 + 批准处置 + 尚欠。独立跟踪保留原借用关联，不改变库存数量。</div>' +
        (loans.length
          ? loans
              .map(
                (l) =>
                  '<div class="file-card"><div>' +
                  safe(l.partName) +
                  " · 借出 " +
                  l.quantity +
                  " 件<p>尚欠 " +
                  loanRemaining(l) +
                  " · 完好还 " +
                  l.returnedGood +
                  " · 隔离还 " +
                  l.returnedQuarantine +
                  " · 耗用 " +
                  l.consumed +
                  "</p><p>" +
                  safe(l.borrowerId) +
                  " · " +
                  date(l.dueAt) +
                  "</p></div>" +
                  badge(
                    loanRemaining(l) ? "借用未清" : "已清",
                    loanRemaining(l) ? "amber" : "green",
                  ) +
                  "</div>",
              )
              .join("")
          : empty("本单暂无关联借用")) +
        '<button class="button" data-view="inventory">打开库存与借还台账</button></section>';
    }
    if (detailTab === "timeline")
      body =
        '<section class="detail-section"><h3>人工动作与审计时间轴</h3>' +
        ((order.events || []).length
          ? '<ul class="timeline">' +
            [...order.events]
              .reverse()
              .map(
                (e) =>
                  "<li><strong>" +
                  safe(D.actionNames[e.type] || e.type || "业务记录") +
                  "</strong><p>" +
                  safe(e.note || e.message || "") +
                  "</p><time>" +
                  date(e.createdAt || e.at) +
                  " · " +
                  safe(e.actorId || e.actor || "系统") +
                  "</time></li>",
              )
              .join("") +
            "</ul>"
          : empty("暂无事件记录")) +
        "</section>";
    if (detailTab === "overview" && !internal())
      body =
        '<section class="detail-section"><h3>授权工单信息</h3><dl class="description-list"><dt>工单</dt><dd>' +
        safe(order.number) +
        "</dd><dt>设备 / 型号</dt><dd>" +
        safe(order.device) +
        "</dd><dt>维修 / 销售需求</dt><dd>" +
        safe(order.description) +
        "</dd><dt>当前进度</dt><dd>" +
        safe(D.states[order.status]) +
        " · " +
        safe(outcomes[order.outcome] || "处理中") +
        "</dd><dt>客户说明</dt><dd>" +
        safe(order.customerNote || "暂无已发布说明") +
        "</dd><dt>质保</dt><dd>" +
        safe(s.warrantyLabel) +
        '</dd></dl><div class="inline-note" style="margin-top:20px">' +
        safe(s.nextTask) +
        '</div><div class="action-list">' +
        available(order)
          .map((t) => actionButton(order, t))
          .join("") +
        "</div></section>";
    if (
      ["overview", "quote"].includes(detailTab) &&
      order.acceptanceRecords?.length
    )
      body +=
        '<section class="detail-section"><h3>客户人工验收签署记录</h3>' +
        order.acceptanceRecords
          .map(
            (record) =>
              '<article class="file-card"><div><strong>' +
              (record.passed ? "验收通过" : "验收未通过（异议）") +
              "</strong><p>" +
              safe(record.signerName || record.signerId) +
              " · " +
              date(record.signedAt) +
              "</p><p>" +
              safe(record.note) +
              "</p><p>报价 v" +
              record.quoteVersion +
              " · 工单 v" +
              record.orderVersion +
              '</p></div><button class="button" data-acceptance-signature="' +
              safe(record.id) +
              '" data-order="' +
              safe(order.id) +
              '">查看原始签名</button></article>',
          )
          .join("") +
        "</section>";
    $("#detailContent").innerHTML =
      '<header class="detail-header"><div><div class="eyebrow">' +
      safe(order.number) +
      " · VERSION " +
      order.version +
      "</div><h2>" +
      safe(order.customer) +
      " · " +
      safe(order.device) +
      "</h2><p>" +
      safe(D.states[order.status]) +
      " · " +
      safe(outcomes[order.outcome] || "履约进行中") +
      " · " +
      (dataKind === "demo" ? "合成演示副本" : "服务端授权数据") +
      '</p></div><button class="close-button" data-close="detail" aria-label="关闭详情">×</button></header><nav class="detail-tabs" aria-label="工单详情">' +
      tabs
        .map(
          (t) =>
            '<button class="detail-tab ' +
            (detailTab === t ? "active" : "") +
            '" data-detail-tab="' +
            t +
            '">' +
            labels[t] +
            "</button>",
        )
        .join("") +
      '</nav><div class="detail-body">' +
      body +
      '</div><footer class="detail-footer"><span>工单事实提交一次 · 主阶段由服务端统一判定</span><button class="text-button" data-reload>刷新当前数据 ↻</button></footer>';
  }
  function evidenceList(o) {
    return (o.evidence || []).length
      ? o.evidence
          .map(
            (e) =>
              '<article class="file-card ' +
              (e.deleted ? "deleted" : "") +
              '"><div><strong>' +
              safe(e.name) +
              "</strong><p>" +
              safe(e.kind) +
              " · " +
              safe(e.stage) +
              " · " +
              safe(e.uploaderId) +
              " · " +
              date(e.createdAt) +
              "</p>" +
              (e.deleted
                ? "<p>原件已删除 · 原业务事实与删除审计保留</p>"
                : e.kind === "text"
                  ? "<p>" + safe(e.text) + "</p>"
                  : "") +
              '</div><div class="action-list">' +
              (!e.deleted && e.kind !== "text"
                ? '<button class="button" data-file="' +
                  safe(e.id) +
                  '" data-order="' +
                  safe(o.id) +
                  '">预览 / 下载</button>'
                : "") +
              (!e.deleted &&
              (e.uploaderId === actor.id || actor.role === "admin")
                ? recordActionButton(o, "delete_evidence", e.id, "删除")
                : "") +
              "</div></article>",
          )
          .join("")
      : empty("暂无归档证据", "文字、图片、视频与语音均可关联到本单业务环节。");
  }
  function options(items, selected) {
    return items
      .map(
        ([value, label]) =>
          '<option value="' +
          safe(value) +
          '" ' +
          (String(value) === String(selected) ? "selected" : "") +
          ">" +
          safe(label) +
          "</option>",
      )
      .join("");
  }
  function field(
    name,
    label,
    type = "text",
    value = "",
    extra = "",
    required = true,
  ) {
    return (
      '<label class="form-field ' +
      (type === "textarea" ? "full" : "") +
      '">' +
      safe(label) +
      (type === "textarea"
        ? '<textarea name="' +
          name +
          '" ' +
          (required ? "required" : "") +
          " " +
          extra +
          ">" +
          safe(value) +
          "</textarea>"
        : '<input name="' +
          name +
          '" type="' +
          type +
          '" value="' +
          safe(value) +
          '" ' +
          (required ? "required" : "") +
          " " +
          extra +
          ">") +
      "</label>"
    );
  }
  function select(name, label, items, value = "", extra = "") {
    return (
      '<label class="form-field">' +
      label +
      '<select name="' +
      name +
      '" ' +
      extra +
      ">" +
      options(items, value) +
      "</select></label>"
    );
  }
  function amountField(name, label, value = 0, zero = true) {
    return field(
      name,
      label,
      "text",
      (value / 100).toFixed(2),
      'inputmode="decimal" pattern="[0-9]+([.][0-9]{1,2})?" data-cents' +
        (!zero ? " data-positive" : ""),
    );
  }
  function evidenceSelector(o, name = "files") {
    const files = (o.evidence || []).filter((e) => !e.deleted);
    return (
      '<label class="form-field full">有效附件 / 证据引用<select name="' +
      name +
      '" multiple size="' +
      Math.min(5, Math.max(2, files.length)) +
      '">' +
      options(files.map((e) => [e.id, e.name])) +
      "</select><small>可按住 Ctrl / Command 多选。真实票据应选择 PDF / 图片；无附件请先归档证据。</small></label>"
    );
  }
  function defaultNote() {
    return field(
      "note",
      "本次事实 / 依据说明",
      "textarea",
      "",
      "maxlength=" + 2000,
    );
  }
  function localDateTime(value) {
    if (!value) return "";
    const d = new Date(value);
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000)
      .toISOString()
      .slice(0, 16);
  }
  function modal(title, body, onSubmit, { readOnly = false } = {}) {
    const revision = epoch,
      instance = ++formRevision;
    actionIntent++;
    $("#formContent").innerHTML =
      '<header class="form-heading"><h2>' +
      safe(title) +
      '</h2><button class="close-button" data-close="form" aria-label="关闭表单">×</button></header><form id="actionForm"><div class="form-body">' +
      body +
      '<div id="formError" class="form-error" hidden></div></div><footer class="form-footer"><button class="button" type="button" data-close="form">' +
      (readOnly ? "关闭" : "取消") +
      "</button>" +
      (readOnly
        ? ""
        : '<button class="button primary" type="submit" id="submitAction">确认本次事实</button>') +
      "</footer></form>";
    $("#actionForm").onsubmit = async (event) => {
      event.preventDefault();
      if (readOnly) return;
      const button = $("#submitAction");
      if (button.disabled) return;
      button.disabled = true;
      $("#formError").hidden = true;
      try {
        if (revision !== epoch || instance !== formRevision)
          throw new Error("身份或连接已切换，请重新打开表单核对。");
        await onSubmit(new FormData(event.currentTarget), instance);
      } catch (error) {
        if (revision !== epoch || instance !== formRevision) return;
        $("#formError").textContent = error.message;
        $("#formError").hidden = false;
      } finally {
        button.disabled = false;
      }
    };
    if (!$("#formDialog").open) $("#formDialog").showModal();
  }
  function finishForm(instance) {
    if (instance !== formRevision || !$("#formDialog").open) return false;
    $("#formDialog").close();
    return true;
  }
  async function showAction(type, id, record = "") {
    let o;
    const revision = epoch,
      intent = ++actionIntent,
      sourceView = view;
    try {
      o = await completeOrder(id);
    } catch (error) {
      if (revision === epoch && intent === actionIntent && sourceView === view)
        toast("完整工单未加载，暂不能办理：" + error.message);
      return;
    }
    if (revision !== epoch || intent !== actionIntent || sourceView !== view)
      return;
    if (!o) return;
    if (
      type === "resolve_obligation" &&
      !canResolveObligation(
        (o.obligations || []).find((task) => task.id === record),
      )
    ) {
      toast("仅责任人或管理员／调度可办理这条未完成余项。");
      return;
    }
    const q = o.quote || {};
    let body = "",
      read = (fd) => Object.fromEntries(fd.entries());
    const owners = Object.entries(D.roles).filter(
      ([r]) => !["customer", "supplier"].includes(r),
    );
    if (["sign_quote", "accept"].includes(type)) {
      showSignature(type, o);
      return;
    }
    switch (type) {
      case "intake":
        body =
          select(
            "ownerId",
            "公司工单负责人",
            owners,
            o.ownerId || "dispatcher",
          ) +
          select(
            "assigneeId",
            "执行责任人",
            owners,
            o.assigneeId || "engineer",
          );
        break;
      case "handover_contact":
        body =
          field(
            "customerId",
            "同企业新授权经办人账号",
            "text",
            "customer-peer",
          ) + field("reason", "授权核实、交接原因及待办说明", "textarea");
        break;
      case "assign":
        body = select(
          "assigneeId",
          "新执行责任人",
          owners,
          o.assigneeId || "engineer",
        );
        break;
      case "quote":
        body =
          amountField(
            "amountCents",
            "含税总价（元）",
            q.amountCents || 0,
            false,
          ) +
          field(
            "warrantyMonths",
            "质保月数",
            "number",
            q.warrantyMonths || 3,
            'min="1" max="60"',
          ) +
          select(
            "paymentTerms",
            "付款约定",
            [
              ["credit", "批准企业账期"],
              ["cash", "现金约定"],
            ],
            q.paymentTerms || "cash",
          ) +
          amountField(
            "prepayCents",
            "约定预付款（元，可为零）",
            q.prepayCents || 0,
          ) +
          (o.type !== "sale"
            ? select(
                "startRequiresPrepayment",
                "维修开修前是否明确约定先款",
                [
                  ["false", "未约定先款，不以预付款拦截开修"],
                  ["true", "已明确约定：核实约定预付款后开修"],
                ],
                String(!!q.startRequiresPrepayment),
              )
            : "") +
          field(
            "validUntil",
            "报价接受期限",
            "date",
            q.validUntil?.slice(0, 10) || "2026-11-01",
          ) +
          select(
            "autoAccept",
            "销售 / 寄修七日自动验收告知",
            [
              ["false", "未同意，不自动验收"],
              ["true", "客户接受规则，凭完整交付启动"],
            ],
            String(!!q.autoAccept),
          ) +
          field(
            "description",
            "型号、数量、方案与完整条款",
            "textarea",
            q.description || "",
          );
        break;
      case "qc":
        body =
          select("passed", "实际质量结论", [
            ["true", "公司质检合格"],
            ["false", "质检不合格，安排整改"],
          ]) + defaultNote();
        break;
      case "stock_ready":
        body =
          select(
            "partId",
            "实际出库配件",
            (data.parts || []).map((p) => [
              p.id,
              p.name + " · 可用 " + p.available,
            ]),
          ) +
          field(
            "quantity",
            "实际数量",
            "number",
            1,
            'min="1" step="1" data-integer',
          );
        break;
      case "dispatch":
        body =
          field("carrier", "承运方 / 自送方式") +
          field("tracking", "真实物流号（自送可注明）", "text", "", "", false) +
          defaultNote();
        break;
      case "deliver":
        body =
          field(
            "deliveredAt",
            "实际完整签收 / 交接时间",
            "datetime-local",
            localDateTime(new Date().toISOString()),
          ) + defaultNote();
        break;
      case "requirements":
        body =
          select(
            "documentRequirement",
            "本单付款资料要求",
            [
              ["unknown", "待确认"],
              ["required", "需要制作并发送"],
              ["none", "无需，有确认依据"],
            ],
            o.documents?.requirement,
          ) +
          select(
            "invoiceRequirement",
            "本单开票要求",
            [
              ["unknown", "待确认"],
              ["required", "需要真实票据"],
              ["none", "无需，有确认依据"],
            ],
            o.invoiceRequirement,
          ) +
          field(
            "documentReason",
            "付款资料要求来源 / 无需依据",
            "textarea",
            o.documents?.reason || "",
          ) +
          field(
            "invoiceReason",
            "开票要求来源 / 无需依据",
            "textarea",
            o.invoiceReason || "",
          ) +
          amountField(
            "invoiceDueCents",
            "当前应开含税票额（元）",
            o.invoiceDueCents || q.amountCents || 0,
          );
        break;
      case "documents":
        body =
          select(
            "prepared",
            "实际制作状态",
            [
              ["false", "尚未制作齐备"],
              ["true", "当前资料已实际齐备"],
            ],
            String(!!o.documents?.prepared),
          ) +
          select(
            "sent",
            "实际发送状态",
            [
              ["false", "尚未发送"],
              ["true", "已经实际发送"],
            ],
            String(!!o.documents?.sent),
          ) +
          field(
            "recipient",
            "发送对象与方式 / 凭据说明",
            "text",
            o.documents?.recipient || "",
            "",
            false,
          ) +
          evidenceSelector(o);
        break;
      case "cash":
        body =
          select("kind", "本次真实现金事实", [
            ["receipt", "收到现金"],
            ["refund", "实际退还现金"],
          ]) +
          amountField("amountCents", "现金金额（元）", 0, false) +
          field("purpose", "款项用途（预付 / 尾款等）") +
          field(
            "occurredAt",
            "现金实际发生时间",
            "datetime-local",
            localDateTime(new Date().toISOString()),
          ) +
          field("receipt", "现金凭证 / 客户收讫依据", "textarea");
        break;
      case "verify_cash":
        body =
          '<div class="inline-note warning">核实本笔真实收到 / 退还的现金，未核实记录不计入净实收。核实后仍保留内部交接事实。</div>' +
          defaultNote();
        read = (fd) => ({ cashId: record });
        break;
      case "handover_cash":
        body =
          '<div class="inline-note">确认该笔现金已经内部交接，不会再增加一次客户收款。</div>' +
          defaultNote();
        read = (fd) => ({ cashId: record });
        break;
      case "invoice":
        body =
          field("number", "真实发票号码") +
          amountField("amountCents", "含税票额（元）", 0, false) +
          evidenceSelector(o);
        break;
      case "void_invoice":
        body = field("reason", "红冲 / 作废原因与依据", "textarea");
        read = (fd) => ({ invoiceId: record, reason: fd.get("reason") });
        break;
      case "adjust_receivable":
        body =
          amountField(
            "amountCents",
            "批准后的有效应收总额（元）",
            summary(o).receivableCents,
          ) + field("reason", "调整批准人与依据", "textarea");
        break;
      case "remark":
        body =
          (["admin", "dispatcher", "finance", "engineer"].includes(actor.role)
            ? field(
                "remark",
                "内部备注（默认不向客户展示）",
                "textarea",
                o.remark || "",
                "maxlength=2000",
                false,
              )
            : "") +
          field(
            "customerNote",
            "单独发布的客户说明",
            "textarea",
            o.customerNote || "",
            "maxlength=2000",
            false,
          );
        read = (fd) => {
          const payload = Object.fromEntries(fd.entries());
          if (
            !["admin", "dispatcher", "finance", "engineer"].includes(actor.role)
          )
            delete payload.remark;
          return payload;
        };
        break;
      case "evidence":
        body =
          field("name", "资料名称") +
          select("kind", "证据类型", [
            ["text", "文字记录"],
            ["image", "图片"],
            ["video", "视频"],
            ["audio", "语音"],
            ["document", "PDF / 业务文件"],
          ]) +
          field("stage", "业务环节", "text", o.status) +
          field(
            "text",
            "文字内容 / 资料说明",
            "textarea",
            "",
            "maxlength=5000",
            false,
          ) +
          field(
            "file",
            "媒体 / 业务文件（最多 8 MB）",
            "file",
            "",
            'accept="image/*,video/*,audio/*,application/pdf"',
            false,
          );
        break;
      case "delete_evidence":
        body =
          '<div class="inline-note warning">删除原件后旧下载地址与新资料包停用；签署、验收、核实收款不会自动撤销。如影响必需附件将生成缺项。</div>' +
          field("reason", "删除原因", "textarea");
        read = (fd) => ({ evidenceId: record, reason: fd.get("reason") });
        break;
      case "issue":
        body =
          defaultNote() +
          select("ownerId", "协商责任人", owners, o.ownerId) +
          field("dueAt", "下次处理期限", "date", "2026-10-20");
        break;
      case "resolve_issue":
        body = defaultNote();
        read = (fd) => ({ issueId: record, note: fd.get("note") });
        break;
      case "failure":
        body =
          select("reason", "真实停止履约结果", [
            ["customer_refused", "客户拒修"],
            ["company_refused", "公司拒修"],
            ["unrepairable", "确认不能修"],
            ["cancelled", "批准取消"],
            ["negotiated", "按协商停止履约"],
          ]) +
          amountField(
            "amountCents",
            "批准的本次最终应收（元）",
            summary(o).receivableCents,
          ) +
          select("returnRequired", "客户设备是否必须退回", [
            ["true", "需要退件并生成余项"],
            ["false", "无需退件，有实际依据"],
          ]) +
          defaultNote();
        break;
      case "obligation":
        body =
          field("title", "本单必须办理事项") +
          select("ownerId", "责任人", owners, o.ownerId) +
          field("dueAt", "办理期限", "date", "2026-10-20");
        break;
      case "resolve_obligation":
        body = defaultNote();
        read = (fd) => ({ obligationId: record, note: fd.get("note") });
        break;
      case "visit":
        {
          const v = (o.visits || []).find((i) => i.id === record);
          body =
            field(
              "plannedAt",
              "预计到场（分钟可由实际精度注明）",
              "datetime-local",
              localDateTime(v?.plannedAt),
            ) +
            field(
              "feeMemo",
              "内部基础费用备忘",
              "textarea",
              v?.feeMemo || "",
              "maxlength=2000",
              false,
            ) +
            field("note", "行程事项", "textarea", v?.note || "") +
            field("reason", "调整 / 更正依据", "textarea", "", "", !!record);
          read = (fd) => ({ ...Object.fromEntries(fd.entries()), id: record });
        }
        break;
      case "start_visit":
        body = defaultNote();
        read = (fd) => ({ visitId: record });
        break;
      case "outsource":
        body =
          field("provider", "一手外包责任主体 / 后续机构") +
          field("contact", "已知联系人（未知可留空）", "text", "", "", false) +
          field("destination", "后续流向 / 设备去向", "text", "", "", false) +
          defaultNote();
        break;
      case "cost":
        body =
          select("category", "真实成本分类", [
            ["parts", "配件成本"],
            ["labor", "人工工时"],
            ["transport", "交通物流"],
            ["outsource", "一手外包"],
            ["other", "其他获批费用"],
          ]) +
          amountField("amountCents", "成本金额（元）", 0, false) +
          defaultNote();
        break;
      case "approve_cost":
        body = defaultNote();
        read = (fd) => ({ costId: record });
        break;
      case "commission":
        body =
          field("person", "实际提成归属人") +
          amountField("amountCents", "提成金额（元）", 0, false) +
          defaultNote();
        break;
      case "settle_commission":
        body = defaultNote();
        read = (fd) => ({ commissionId: record, note: fd.get("note") });
        break;
      case "reopen":
        body = field("reason", "重开原因与批准依据", "textarea");
        break;
      case "rework":
        body =
          defaultNote() +
          select("free", "本次返修费用约定", [
            ["true", "有效质保内免费（范围已核实）"],
            ["false", "另行核定费用"],
          ]);
        break;
      default:
        body = defaultNote();
    }
    const warning =
      dataKind === "demo"
        ? '<div class="inline-note warning">独立合成演示：仅填写虚构信息。服务不可达时只更新样例；真实文件和手绘签名不会迁入演示。</div>'
        : "";
    modal(
      D.actionNames[type],
      warning + '<div class="form-grid">' + body + "</div>",
      async (fd, instance) => {
        let payload = read(fd);
        document
          .querySelectorAll("#actionForm [data-cents]")
          .forEach(
            (input) =>
              (payload[input.name] = D.cents(
                input.value,
                !input.hasAttribute("data-positive"),
              )),
          );
        document
          .querySelectorAll("#actionForm [data-integer]")
          .forEach((input) => (payload[input.name] = D.integer(input.value)));
        [
          "passed",
          "prepared",
          "sent",
          "returnRequired",
          "autoAccept",
          "startRequiresPrepayment",
          "free",
        ].forEach((key) => {
          if (key in payload) payload[key] = payload[key] === "true";
        });
        if ("warrantyMonths" in payload)
          payload.warrantyMonths = Number(payload.warrantyMonths);
        if (type === "quote" && o.type !== "sale") {
          payload.startRequiresPrepayment =
            payload.startRequiresPrepayment === true;
          if (payload.startRequiresPrepayment && !(payload.prepayCents > 0))
            throw new Error("明确约定先款开修时，请填写大于零的约定预付款。");
        }
        for (const key of ["validUntil", "dueAt"]) {
          if (payload[key])
            payload[key] = new Date(
              String(payload[key]).slice(0, 10) + "T23:59:59+08:00",
            ).toISOString();
        }
        if ("files" in payload) payload.files = fd.getAll("files");
        for (const key of ["occurredAt", "deliveredAt", "plannedAt"]) {
          if (payload[key]) payload[key] = new Date(payload[key]).toISOString();
        }
        let sensitive = false;
        if (type === "evidence") {
          const file = fd.get("file");
          delete payload.file;
          if (payload.kind !== "text") {
            if (!file?.size)
              throw new Error("请选择对应类型的媒体或 PDF 文件。");
            if (file.size > 8 * 1024 * 1024)
              throw new Error("文件不得超过 8 MB。");
            if (!/^(image\/|video\/|audio\/|application\/pdf$)/.test(file.type))
              throw new Error("不支持此文件类型。");
            payload.mime = file.type;
            payload.data = await fileBase64(file);
            sensitive = true;
          } else {
            if (!payload.text.trim()) throw new Error("文字记录不能为空。");
            payload.mime = "text/plain";
          }
        }
        if (revision !== epoch || instance !== formRevision)
          throw new APIError("身份或表单已切换，请重新核对。", 409);
        await mutateOrder(o, type, payload, {
          sensitive,
          formInstance: instance,
        });
      },
    );
  }
  function fileBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result).split(",")[1]);
      reader.onerror = () => reject(new Error("无法读取文件。"));
      reader.readAsDataURL(file);
    });
  }
  function showSignature(type, o, record = null) {
    if (record) {
      const image = /^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(
        record.signature,
      )
        ? '<img class="signature-pad" src="' +
          safe(record.signature) +
          '" alt="客户原始手写签名">'
        : "<p>此为合成演示签名，无真实签名原件。</p>";
      modal(
        "客户人工验收原始签名",
        '<div class="document-preview"><h3>' +
          (record.passed ? "验收通过" : "验收未通过（异议）") +
          "</h3><p>" +
          safe(record.signerName || record.signerId) +
          " · " +
          date(record.signedAt) +
          "</p><p>" +
          safe(record.note) +
          "</p>" +
          image +
          "</div>",
        null,
        { readOnly: true },
      );
      return;
    }
    const accepting = type === "accept",
      q = o.quote || {};
    let drawn = false,
      synthetic = false,
      signature = "";
    const body =
      '<div class="document-preview"><h3>' +
      safe(
        accepting
          ? "最终验收确认单"
          : o.type === "sale"
            ? "销售报价确认单"
            : "报价暨维修确认单",
      ) +
      "</h3><p>工单：" +
      safe(o.number) +
      " · 客户：" +
      safe(o.customer) +
      "</p><p>设备 / 型号：" +
      safe(o.device) +
      "</p><p>" +
      safe(q.description || o.description) +
      "</p><p>含税价：" +
      money(q.amountCents) +
      " · 质保 " +
      (q.warrantyMonths || 3) +
      " 个月 · " +
      safe(q.paymentTerms === "credit" ? "批准企业账期" : "现金约定") +
      (o.type !== "sale"
        ? " · " +
          (q.startRequiresPrepayment
            ? "明确约定先款：核实约定预付款 " +
              money(q.prepayCents || 0) +
              " 后开修"
            : "未约定先款开修")
        : "") +
      "</p><p>" +
      (accepting
        ? "独立确认本次实际交付完整、约定测试通过与质量验收合格。"
        : "本次一次确认当前报价版本 v" +
          q.version +
          "、范围、付款与维修 / 销售履约条款。") +
      '</p><p>本机手写业务留痕，尚未接入第三方认证电子签。</p></div><label class="checkbox-field"><input type="checkbox" name="agreed" required>我已完整阅读并同意当前单据内容，确认本人获得客户授权。</label><canvas id="signatureCanvas" class="signature-pad" width="900" height="260" aria-label="鼠标或触摸手写签名"></canvas><div class="signature-tools"><span>鼠标 / 手指书写 · 空白不可提交</span><div><button type="button" class="text-button" id="clearSignature">清空重签</button>' +
      (dataKind === "demo"
        ? '<button type="button" class="text-button" id="syntheticSignature">填入合成演示签名</button>'
        : "") +
      "</div></div>";
    modal(D.actionNames[type], body, async (fd, instance) => {
      if (!drawn) throw new Error("请完成非空白手写签名。");
      if (!fd.get("agreed")) throw new Error("请先阅读并同意单据内容。");
      signature = $("#signatureCanvas").toDataURL("image/png");
      await mutateOrder(
        o,
        type,
        accepting
          ? { signature, passed: true, note: "客户独立签署最终验收" }
          : { signature, quoteVersion: q.version },
        { sensitive: !synthetic, formInstance: instance },
      );
    });
    const canvas = $("#signatureCanvas"),
      ctx = canvas.getContext("2d");
    ctx.lineWidth = 3;
    ctx.strokeStyle = "#234a37";
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    let writing = false;
    function point(event) {
      const r = canvas.getBoundingClientRect();
      return [
        ((event.clientX - r.left) * canvas.width) / r.width,
        ((event.clientY - r.top) * canvas.height) / r.height,
      ];
    }
    canvas.onpointerdown = (event) => {
      writing = true;
      synthetic = false;
      canvas.setPointerCapture(event.pointerId);
      ctx.beginPath();
      ctx.moveTo(...point(event));
    };
    canvas.onpointermove = (event) => {
      if (!writing) return;
      drawn = true;
      ctx.lineTo(...point(event));
      ctx.stroke();
    };
    canvas.onpointerup = () => (writing = false);
    canvas.onpointercancel = () => (writing = false);
    $("#clearSignature").onclick = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawn = false;
      synthetic = false;
    };
    if ($("#syntheticSignature"))
      $("#syntheticSignature").onclick = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.font = "italic 45px serif";
        ctx.fillStyle = "#234a37";
        ctx.fillText("DEMO · SAMPLE ONLY", 90, 140);
        drawn = true;
        synthetic = true;
      };
  }
  async function mutateOrder(
    order,
    type,
    payload,
    { sensitive = false, formInstance = formRevision } = {},
  ) {
    const mutation = order.id + ":" + type;
    if (pending.has(mutation))
      throw new Error("该动作正在提交，请勿重复确认。");
    pending.add(mutation);
    const revision = epoch,
      navigation = actionIntent,
      wasDemo =
        dataKind === "demo" && demo.orders.some((o) => o.id === order.id),
      key = formKey(
        "/orders/" + encodeURIComponent(order.id) + "/actions",
        JSON.stringify({ type, version: order.version, payload }),
      );
    try {
      const result = await request(
        "/orders/" + encodeURIComponent(order.id) + "/actions",
        {
          method: "POST",
          key,
          body: JSON.stringify({ type, version: order.version, payload }),
        },
      );
      if (revision !== epoch) throw new Error("身份或连接已切换，请重新核对。");
      if (wasDemo)
        throw new Error("此合成单未进入服务端台账。请重载服务端工单后办理。");
      const i = data.orders.findIndex((o) => o.id === result.id);
      if (i >= 0) data.orders[i] = result;
      details.set(result.id, result);
      connected = true;
      const finished = finishForm(formInstance);
      await refresh();
      if (revision !== epoch) return;
      if (finished && navigation === actionIntent && type === "rework")
        openDetail(result.id);
      toast("已保存：" + D.actionNames[type]);
    } catch (error) {
      if (revision !== epoch) throw error;
      if (!wasDemo || !unavailable(error) || sensitive) {
        if ([401, 403, 409, 422].includes(error.status))
          throw new Error(error.message + "（输入保留，未改写任何事实）");
        throw new Error(
          error.message +
            (sensitive
              ? " 文件 / 手绘签名未转入演示，也未自动重试。"
              : " 未自动重放此写请求；请重新核对服务端结果。"),
        );
      }
      const existing = demo.orders.find((o) => o.id === order.id);
      const next = D.apply(existing, type, payload, actor, demo);
      const i = demo.orders.findIndex((o) => o.id === next.id);
      if (i >= 0) demo.orders[i] = next;
      else demo.orders.unshift(next);
      data = structuredClone(demo);
      const finished = finishForm(formInstance);
      render();
      if (finished && navigation === actionIntent && type === "rework")
        openDetail(next.id);
      toast("服务不可达 · 已在独立合成演示中保存：" + D.actionNames[type]);
    } finally {
      pending.delete(mutation);
    }
  }
  function createForm() {
    const sourceAtOpen = dataKind;
    const body =
      '<div class="inline-note">个人客户建议协商可选预付款，不强制收取；企业以批准账期为准。</div><div class="form-grid">' +
      select("type", "业务类型", [
        ["mail", "设备寄修"],
        ["onsite", "上门维修"],
        ["sale", "配件销售"],
      ]) +
      select("customerId", "客户账号", [
        ["customer", "合成客户公司 A · 原经办人"],
        ["customer-peer", "合成客户公司 A · 接替经办人"],
        ["customer-b", "合成客户公司 B"],
      ]) +
      field(
        "customer",
        "客户 / 企业名称",
        "text",
        dataKind === "demo" ? "合成客户" : "",
      ) +
      field("project", "项目 / 销售归属", "text", "", "", false) +
      field("device", "设备 / 货品型号") +
      field("description", "故障与报修 / 销售需求", "textarea") +
      select("prepayChoice", "个人可选预付款约定", [
        ["not_applicable", "企业 / 暂不适用"],
        ["collect", "个人客户同意收取，后续报价记录金额"],
        ["none", "个人客户确认不收取"],
        ["pending", "个人客户待协商，记入备注"],
      ]) +
      "</div>";
    modal("新建维修 / 销售工单", body, async (fd, instance) => {
      const payload = Object.fromEntries(fd.entries());
      payload.companyId =
        dataKind === "demo"
          ? "company-demo"
          : data.orders.find((o) => o.customerId === payload.customerId)
              ?.companyId ||
            (payload.customerId === "customer-b" ? "company-b" : "company-a");
      payload.remark = "可选预付款约定：" + payload.prepayChoice;
      delete payload.prepayChoice;
      const revision = epoch,
        navigation = actionIntent,
        wasDemo = sourceAtOpen === "demo";
      try {
        const result = await request("/orders", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        if (revision !== epoch) return;
        page = 1;
        await refresh();
        if (revision !== epoch) return;
        const finished = finishForm(instance);
        render();
        if (finished && navigation === actionIntent) openDetail(result.id);
        toast("工单已提交服务端。");
      } catch (error) {
        if (revision !== epoch) return;
        if (!unavailable(error) || !wasDemo)
          throw new Error(error.message + " 输入保留，未自动迁入演示。");
        const order = D.createOrder(payload);
        order.summary = D.derive(order, demo.loans);
        demo.orders.unshift(order);
        data = structuredClone(demo);
        const finished = finishForm(instance);
        render();
        if (finished && navigation === actionIntent) openDetail(order.id);
        toast("服务不可达 · 已建立独立合成工单。");
      }
    });
  }
  function globalForm(type, id = "", loanAction = "") {
    const sourceAtOpen = dataKind;
    const parts = (data.parts || []).map((p) => [
        p.id,
        p.name + " · 可用 " + p.available,
      ]),
      orderOptions = [
        ["", "独立借用，不关联工单"],
        ...currentOrders().map((o) => [o.id, o.number + " · " + o.device]),
      ];
    let body = "",
      title = "",
      path = "",
      payloadReader = (fd) => Object.fromEntries(fd.entries()),
      localApply;
    if (type === "loan") {
      title = "登记实际借出交接";
      path = "/loans";
      body =
        select("partId", "配件 / 型号", parts) +
        field("quantity", "实际借出数量", "number", 1, 'min="1" data-integer') +
        select("orderId", "关联工单（可选）", orderOptions) +
        select(
          "borrowerId",
          "借用责任人",
          Object.entries(D.roles).filter(
            ([r]) => !["customer", "supplier"].includes(r),
          ),
          "engineer",
        ) +
        field("dueAt", "预计归还日", "date", "2026-10-20") +
        defaultNote();
      localApply = (p) => {
        const part = demo.parts.find((i) => i.id === p.partId);
        if (part.available < p.quantity) throw new Error("可用库存不足。");
        part.available -= p.quantity;
        demo.loans.push({
          ...p,
          id: D.uid("loan"),
          version: 1,
          partName: part.name,
          returnedGood: 0,
          returnedQuarantine: 0,
          consumed: 0,
          disposed: 0,
          outstanding: p.quantity,
        });
      };
    }
    if (type === "purchase") {
      title = "登记实际采购订单";
      path = "/purchases";
      body =
        field("supplier", "供应商责任主体") +
        select("partId", "采购配件", parts) +
        field("quantity", "采购数量", "number", 1, 'min="1" data-integer') +
        amountField("unitCents", "含税采购单价（元）", 0, false) +
        defaultNote();
      localApply = (p) =>
        demo.purchases.push({
          ...p,
          id: D.uid("purchase"),
          version: 1,
          received: 0,
        });
    }
    if (type === "purchaseReceive") {
      const p = data.purchases.find((i) => i.id === id);
      title = "确认采购实际收货";
      path = "/purchases/" + encodeURIComponent(id) + "/receive";
      body =
        field(
          "quantity",
          "本次实收数量",
          "number",
          p.quantity - p.received,
          'min="1" data-integer',
        ) + defaultNote();
      payloadReader = (fd) => ({
        ...Object.fromEntries(fd.entries()),
        version: p.version,
      });
      localApply = (payload) => {
        const item = demo.purchases.find((i) => i.id === id);
        if (payload.quantity > item.quantity - item.received)
          throw new Error("收货数量超过未收数量。");
        item.received += payload.quantity;
        item.version++;
        demo.parts.find((p) => p.id === item.partId).available +=
          payload.quantity;
      };
    }
    if (type === "loanAction") {
      const l = data.loans.find((i) => i.id === id);
      title = {
        return: "核对实际归还",
        consume: "批准转维修耗用",
        dispose: "批准尚欠件处置",
        transfer: "正式转为独立跟踪",
      }[loanAction];
      path = "/loans/" + encodeURIComponent(id) + "/actions";
      body =
        '<div class="inline-note">' +
        safe(l.partName) +
        " · 当前尚欠 " +
        loanRemaining(l) +
        " 件。不可超归还，不用取消清零尚欠。</div>" +
        field(
          "quantity",
          "本次实际数量",
          "number",
          1,
          'min="1" max="' +
            (loanAction === "transfer"
              ? D.loanBlockingQuantity(l)
              : loanRemaining(l)) +
            '" data-integer',
        ) +
        (loanAction === "return"
          ? select("condition", "核对实物成色", [
              ["good", "完好，回可用库"],
              ["quarantine", "待检测 / 损坏，进隔离库"],
            ])
          : field("reason", "批准人与处置依据", "textarea")) +
        (loanAction === "transfer"
          ? select(
              "ownerId",
              "独立跟踪责任人",
              Object.entries(D.roles).filter(
                ([r]) => !["customer", "supplier"].includes(r),
              ),
              l.borrowerId,
            ) + field("dueAt", "独立归还期限", "date", l.dueAt?.slice(0, 10))
          : "");
      payloadReader = (fd) => ({
        type: loanAction,
        version: l.version,
        payload: Object.fromEntries(fd.entries()),
      });
      localApply = (p) => {
        const item = demo.loans.find((i) => i.id === id),
          quantity = p.payload.quantity,
          part = demo.parts.find((i) => i.id === item.partId);
        if (quantity > loanRemaining(item))
          throw new Error("办理数量超过尚欠数量。");
        if (loanAction === "return") {
          if (p.payload.condition === "good") {
            item.returnedGood += quantity;
            part.available += quantity;
          } else {
            item.returnedQuarantine += quantity;
            part.quarantine += quantity;
          }
        } else if (loanAction === "consume") item.consumed += quantity;
        else if (loanAction === "dispose") item.disposed += quantity;
        else {
          if (quantity > D.loanBlockingQuantity(item))
            throw new Error("独立跟踪数量超过未转出的尚欠数量。");
          item.transfers ||= item.transfer ? [{ ...item.transfer }] : [];
          item.transfers.push({ ...p.payload, at: new Date().toISOString() });
          delete item.transferred;
          delete item.transfer;
          item.version++;
          return;
        }
        item.outstanding -= quantity;
        // 先核销独立跟踪件，尚未转出的件仍保留原工单阻塞。
        let remaining = quantity;
        const transfers =
          item.transfers || (item.transfer ? [item.transfer] : []);
        for (const transfer of transfers) {
          const cleared = Math.min(remaining, transfer.quantity);
          transfer.quantity -= cleared;
          remaining -= cleared;
          if (!remaining) break;
        }
        item.version++;
      };
    }
    modal(
      title,
      '<div class="form-grid">' + body + "</div>",
      async (fd, instance) => {
        const payload = payloadReader(fd),
          nested = payload.payload || payload;
        document
          .querySelectorAll("#actionForm [data-integer]")
          .forEach((i) => (nested[i.name] = D.integer(i.value)));
        document
          .querySelectorAll("#actionForm [data-cents]")
          .forEach(
            (i) =>
              (nested[i.name] = D.cents(
                i.value,
                !i.hasAttribute("data-positive"),
              )),
          );
        if (nested.dueAt)
          nested.dueAt = new Date(
            String(nested.dueAt).slice(0, 10) + "T23:59:59+08:00",
          ).toISOString();
        const wasDemo = sourceAtOpen === "demo",
          revision = epoch;
        try {
          await request(path, {
            method: "POST",
            body: JSON.stringify(payload),
          });
          if (revision !== epoch) return;
          finishForm(instance);
          await refresh();
          if (revision === epoch) toast("已保存：" + title);
        } catch (error) {
          if (revision !== epoch) return;
          if (!unavailable(error) || !wasDemo)
            throw new Error(error.message + " 输入保留，未自动重放。");
          localApply(payload);
          demo.orders.forEach((o) => D.refreshOrder(o, demo.loans));
          data = structuredClone(demo);
          finishForm(instance);
          render();
          toast("已保存到独立合成台账：" + title);
        }
      },
    );
  }
  function download(name, blob) {
    const url = URL.createObjectURL(blob),
      anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = name;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function previewFile(id, orderId) {
    const revision = epoch;
    try {
      const response = await fetch(
        apiBase +
          "/api/v38/orders/" +
          encodeURIComponent(orderId) +
          "/evidence/" +
          encodeURIComponent(id),
        {
          headers: { Authorization: "Bearer " + token },
          signal: AbortSignal.timeout(timeoutMs),
        },
      );
      revokeSession(revision, response.status);
      if (!response.ok)
        throw new APIError("下载拒绝或原件已删除。", response.status);
      const blob = await response.blob();
      if (revision !== epoch) return;
      const order =
          dataKind === "server"
            ? details.get(orderId)
            : data.orders.find((o) => o.id === orderId),
        ev = order.evidence.find((e) => e.id === id);
      download(ev.name, blob);
    } catch (error) {
      if (revision === epoch) toast(error.message + " 未生成替代原件。");
    }
  }
  document.addEventListener("click", (event) => {
    const el = event.target.closest("button,[data-open]");
    if (!el) return;
    if (el.dataset.view) {
      if ($("#detailDialog").open) $("#detailDialog").close();
      showView(el.dataset.view);
      return;
    }
    if (el.hasAttribute("data-reload")) {
      if ($("#detailDialog").open && selectedId)
        openDetail(selectedId, detailTab);
      else refresh();
      return;
    }
    if (el.hasAttribute("data-audit-reload")) {
      loadAudit({ reset: true });
      return;
    }
    if (el.dataset.auditPage) {
      auditPage = Math.max(
        1,
        auditPage + (el.dataset.auditPage === "next" ? 1 : -1),
      );
      loadAudit();
      return;
    }
    if (el.dataset.open) {
      openDetail(el.dataset.open, el.dataset.tab || "overview");
      return;
    }
    if (el.dataset.close) {
      if (el.dataset.close === "detail") {
        actionIntent++;
        detailRevision++;
        selectedId = "";
      } else formRevision++;
      $(
        el.dataset.close === "detail" ? "#detailDialog" : "#formDialog",
      ).close();
      return;
    }
    if (el.dataset.detailTab) {
      detailTab = el.dataset.detailTab;
      renderDetail();
      return;
    }
    if (el.dataset.action) {
      showAction(el.dataset.action, el.dataset.order, el.dataset.record || "");
      return;
    }
    if (el.dataset.quick) {
      quick = el.dataset.quick;
      document
        .querySelectorAll(".segment")
        .forEach((b) => b.classList.toggle("active", b === el));
      changeFilters();
      return;
    }
    if (el.dataset.page) {
      const info = pageInfo();
      page = Math.min(
        Math.max(1, info.totalPages),
        Math.max(1, page + (el.dataset.page === "next" ? 1 : -1)),
      );
      loadOrders();
      return;
    }
    if (el.dataset.login) {
      login(el.dataset.login, "Demo-Repair-2026!");
      return;
    }
    if (el.dataset.role) {
      $("#loginUsername").value = el.dataset.role;
      login(el.dataset.role, "Demo-Repair-2026!");
      return;
    }
    if (el.dataset.account) {
      accountStatusForm(el.dataset.account, el.dataset.status);
      return;
    }
    if (el.dataset.global) {
      globalForm(el.dataset.global);
      return;
    }
    if (el.dataset.loan) {
      globalForm("loanAction", el.dataset.loan, el.dataset.loanAction);
      return;
    }
    if (el.dataset.purchase) {
      globalForm("purchaseReceive", el.dataset.purchase);
      return;
    }
    if (el.dataset.file) {
      previewFile(el.dataset.file, el.dataset.order);
      return;
    }
    if (el.dataset.acceptanceSignature) {
      const order =
          dataKind === "server"
            ? details.get(el.dataset.order)
            : currentOrders().find((item) => item.id === el.dataset.order),
        record = order?.acceptanceRecords?.find(
          (item) => item.id === el.dataset.acceptanceSignature,
        );
      if (record) showSignature("accept", order, record);
      return;
    }
    if (el.dataset.downloadOrder) {
      const o =
        dataKind === "server"
          ? details.get(el.dataset.downloadOrder)
          : currentOrders().find((o) => o.id === el.dataset.downloadOrder);
      if (o)
        download(
          o.number + "-单据摘要.json",
          new Blob(
            [
              JSON.stringify(
                {
                  number: o.number,
                  customer: o.customer,
                  device: o.device,
                  quote: o.quote,
                  status: o.status,
                  outcome: o.outcome,
                  source: dataKind,
                },
                null,
                2,
              ),
            ],
            { type: "application/json" },
          ),
        );
      return;
    }
    if (el.id === "localDemo") {
      openDemo(
        $("#loginUsername").value in D.roles
          ? $("#loginUsername").value
          : "dispatcher",
      );
      return;
    }
    if (el.id === "logout") {
      request("/logout", { method: "POST", body: "{}" }).catch(() => {});
      openDemo("dispatcher");
      return;
    }
  });
  document.addEventListener("submit", async (event) => {
    if (event.target.id === "loginForm") {
      event.preventDefault();
      const fd = new FormData(event.target);
      await login(fd.get("username"), fd.get("password"));
    }
    if (event.target.id === "connectionForm") {
      event.preventDefault();
      const fd = new FormData(event.target),
        value = String(fd.get("base")).trim().replace(/\/$/, "");
      try {
        apiBase = normalizeBase(value);
      } catch (error) {
        toast(error.message);
        return;
      }
      timeoutMs = Math.min(
        15000,
        Math.max(500, Number(fd.get("timeout")) || 2500),
      );
      try {
        localStorage.setItem("repairV38Base", apiBase);
        localStorage.setItem("repairV38Timeout", String(timeoutMs));
      } catch (_) {}
      token = "";
      epoch++;
      openDemo(actor.role);
      await refresh();
      toast("连接已保存，请重新认证当前账号。");
    }
    if (event.target.id === "companyForm") {
      event.preventDefault();
      if (actor.role !== "admin") return;
      if (dataKind === "server" && !snapshotReady) {
        toast("公司配置尚未加载，请重新加载后再保存。");
        return;
      }
      const fd = new FormData(event.target),
        revision = epoch,
        wasDemo = dataKind === "demo",
        payload = {
          companyAddress: fd.get("companyAddress"),
          companyReceiver: fd.get("companyReceiver"),
          companyPhone: fd.get("companyPhone"),
          reminderHours: Number(fd.get("reminderHours")),
          remarkLimit: data.settings?.remarkLimit || 2000,
        };
      try {
        await request("/settings", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        if (revision !== epoch) return;
        releaseFormKey("/settings", JSON.stringify(payload));
        await refresh();
        if (revision === epoch) toast("公司配置已保存。");
      } catch (error) {
        if (revision !== epoch) return;
        if (unavailable(error) && wasDemo && dataKind === "demo") {
          demo.settings = payload;
          data.settings = payload;
          toast("配置已保存到独立合成演示。");
        } else toast(error.message);
      }
    }
  });
  $("#refresh").onclick = refresh;
  $("#accountButton").onclick = () => showView("settings");
  $("#createOrder").onclick = createForm;
  $("#filterForm").onsubmit = (event) => event.preventDefault();
  $("#search").oninput = changeFilters;
  ["#statusFilter", "#documentFilter", "#paymentFilter"].forEach(
    (s) => ($(s).onchange = changeFilters),
  );
  $("#clearFilters").onclick = () => {
    $("#filterForm").reset();
    quick = "all";
    document
      .querySelectorAll(".segment")
      .forEach((b) => b.classList.toggle("active", b.dataset.quick === "all"));
    changeFilters();
  };
  $("#statusFilter").insertAdjacentHTML(
    "beforeend",
    options(Object.entries(D.states)),
  );
  $("#exportOrders").onclick = async () => {
    if (dataKind === "server") {
      try {
        const result = await request("/export");
        download(
          "授权工单导出.json",
          new Blob([JSON.stringify(result, null, 2)], {
            type: "application/json",
          }),
        );
        toast("已导出当前角色授权资料。");
      } catch (error) {
        toast("导出未完成：" + error.message);
      }
      return;
    }
    const rows = [
      [
        "来源",
        "工单号",
        "客户",
        "主阶段",
        "资料",
        "票据",
        "核实净收款(分)",
        "待收(分)",
      ],
      ...filteredOrders().map((o) => [
        "synthetic-demo",
        o.number,
        o.customer,
        D.states[o.status],
        displayDocument(o),
        displayInvoice(o),
        summary(o).collectedCents,
        summary(o).remainingCents,
      ]),
    ];
    const csv =
      "\ufeff" +
      rows
        .map((row) =>
          row
            .map(
              (c) =>
                '"' +
                String(c)
                  .replace(/"/g, '""')
                  .replace(/^[=+@-]/, "'$&") +
                '"',
            )
            .join(","),
        )
        .join("\r\n");
    download(
      "合成演示工单.csv",
      new Blob([csv], { type: "text/csv;charset=utf-8" }),
    );
  };
  $("#detailDialog").addEventListener("close", () => {
    if ($("#detailDialog").open) return;
    selectedId = "";
    detailRevision++;
    actionIntent++;
  });
  $("#detailDialog").addEventListener("cancel", () => {
    detailRevision++;
    actionIntent++;
  });
  $("#formDialog").addEventListener("close", () => {
    if (!$("#formDialog").open) formRevision++;
  });
  $("#formDialog").addEventListener("cancel", () => formRevision++);
  render();
  refresh();
})();
