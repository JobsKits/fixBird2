// 接口校验与演示台账保持独立，避免坏响应进入渲染或改动服务器快照。
const MarketplaceData = (() => {
  const MAX_AMOUNT_CENTS = 100000000;
  const orderStatuses = new Set([
    "pending_worker", "accepted", "arrived", "quote_pending", "in_service",
    "awaiting_payment", "completed", "cancelled"
  ]);
  const isObject = value => value !== null && typeof value === "object" && !Array.isArray(value);
  const text = value => typeof value === "string";
  const count = value => Number.isSafeInteger(value) && value >= 0;
  const amount = value => count(value) && value <= MAX_AMOUNT_CENTS;
  const strings = value => value === null || (Array.isArray(value) && value.every(text));
  const order = value => isObject(value) &&
    ["id", "customerId", "workerId", "category", "equipment", "issue", "address", "scheduledAt"].every(key => text(value[key])) &&
    value.id.length > 0 && orderStatuses.has(value.status) &&
    ["not_started", "pending", "demo_paid"].includes(value.paymentStatus) &&
    ["quotedAmountCents", "platformFeeCents", "workerShareCents"].every(key => amount(value[key]));
  const worker = value => isObject(value) &&
    ["id", "displayName", "status"].every(key => text(value[key])) && value.id.length > 0 &&
    strings(value.skills) && strings(value.serviceAreas);
  const settlement = value => isObject(value) && text(value.id) && value.id.length > 0 &&
    text(value.orderId) && ["pending_manual", "manually_paid"].includes(value.status) &&
    ["grossAmountCents", "platformFeeCents", "workerShareCents"].every(key => amount(value[key]));
  const validators = {
    dashboard: value => isObject(value) &&
      ["totalOrders", "pendingOrders", "activeOrders", "pendingSettlements"].every(key => count(value[key])),
    orders: value => Array.isArray(value) && value.every(order),
    workers: value => Array.isArray(value) && value.every(worker),
    settlements: value => Array.isArray(value) && value.every(settlement)
  };

  function split(cents) {
    if (!amount(cents) || cents < 1) throw new Error("报价必须在 1 分至 1000000 元之间");
    const workerShareCents = Math.floor((cents * 85 + 50) / 100);
    return { workerShareCents, platformFeeCents: cents - workerShareCents };
  }

  function applyDemoAction(data, action, id) {
    if (action === "demo-collect") {
      const target = data.orders.find(item => item.id === id);
      if (!target) throw new Error("本地演示订单不存在");
      if (target.status === "completed" && target.paymentStatus === "demo_paid") return;
      if (target.status !== "awaiting_payment") throw new Error("订单当前状态不能模拟收款");
      const shares = split(target.quotedAmountCents);
      Object.assign(target, shares, { status: "completed", paymentStatus: "demo_paid" });
      if (!data.settlements.some(item => item.orderId === id)) {
        data.settlements.push({
          id: "demo-settlement-" + id,
          orderId: id,
          workerId: target.workerId,
          grossAmountCents: target.quotedAmountCents,
          ...shares,
          profitRuleVersion: "demo-v1",
          status: "pending_manual"
        });
      }
      return;
    }
    if (action === "manual-paid") {
      const target = data.settlements.find(item => item.id === id);
      if (!target) throw new Error("本地演示台账不存在");
      if (!["pending_manual", "manually_paid"].includes(target.status)) throw new Error("台账当前状态不能核销");
      target.status = "manually_paid";
      return;
    }
    throw new Error("未知演示动作");
  }

  function copyForDemo(data, kind, original) {
    const id = "demo-copy-" + original.id;
    const existing = data[kind].find(item => item.id === id);
    if (!existing) data[kind].push({ ...structuredClone(original), id });
    return id;
  }

  return Object.freeze({ validators, split, applyDemoAction, copyForDemo });
})();
