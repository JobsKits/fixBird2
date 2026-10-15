const test = require("node:test");
const assert = require("node:assert/strict");
const D = require("../data.js");

const actor = (role) => ({ id: role, role });
function fixture() {
  const data = D.seed();
  const order = structuredClone(data.orders[3]);
  order.status = "pending_execution";
  order.quote = {
    ...order.quote,
    approved: true,
    signed: true,
    amountCents: 10000,
    prepayCents: 0,
    paymentTerms: "credit",
    validUntil: "2099-01-01T15:59:59Z",
  };
  order.receivableCents = 10000;
  order.issues = [];
  order.cash = [];
  return { data, order };
}
function unchangedRejection(order, type, payload, role, data, pattern) {
  const before = structuredClone({ order, payload, data });
  assert.throws(() => D.apply(order, type, payload, actor(role), data), pattern);
  assert.deepEqual({ order, payload, data }, before);
}

for (const action of ["start", "stock_ready", "deliver", "accept"]) {
  test("未解决异议拦截 " + action + "，拒绝时保持输入、库存与事件不变", () => {
    const { data, order } = fixture();
    const settings = {
      start: ["pending_execution", "engineer", { note: "合成开修" }],
      stock_ready: ["pending_execution", "warehouse", { partId: data.parts[0].id, quantity: 1 }],
      deliver: ["pending_delivery", "warehouse", { deliveredAt: new Date().toISOString() }],
      accept: ["pending_acceptance", "customer", { signature: "synthetic", passed: true }],
    };
    const [status, role, payload] = settings[action];
    order.status = status;
    if (action === "stock_ready") order.type = "sale";
    order.issues = [{ id: "open-issue", title: "待协商", resolved: false }];
    unchangedRejection(order, action, payload, role, data, /异议|协商/);
    order.issues[0].resolved = true;
    assert.notEqual(D.apply(order, action, payload, actor(role), data).status, status);
  });
}

for (const action of ["approve_quote", "sign_quote"]) {
  test("过期或无有效接受期限的报价不能 " + action, () => {
    for (const validUntil of ["2000-01-01", "2000-01-01T15:59:59Z", "", "invalid"]) {
      const { data, order } = fixture();
      order.status = action === "approve_quote" ? "diagnosis_quotation" : "pending_customer_confirmation";
      order.quote.signed = false;
      order.quote.validUntil = validUntil;
      unchangedRejection(order, action, { quoteVersion: order.quote.version, signature: "synthetic" },
        action === "approve_quote" ? "admin" : "customer", data, /报价|期限/);
    }
  });
}

test("日期型报价到中国自然日末仍可审核和签署，次日即过期", () => {
  const realNow = Date.now;
  try {
    Date.now = () => Date.parse("2027-01-12T15:59:59.000Z");
    const { data, order } = fixture();
    order.status = "diagnosis_quotation";
    order.quote.validUntil = "2027-01-12";
    order.quote.signed = false;
    let next = D.apply(order, "approve_quote", {}, actor("admin"), data);
    next = D.apply(next, "sign_quote", { quoteVersion: next.quote.version, signature: "synthetic" }, actor("customer"), data);
    assert.equal(next.status, "pending_execution");
    Date.now = () => Date.parse("2027-01-12T16:00:00Z");
    unchangedRejection(order, "approve_quote", {}, "admin", data, /报价|期限/);
  } finally {
    Date.now = realNow;
  }
});

for (const type of ["mail", "sale"]) {
  test("接受期限内已签署的 " + type + " 报价过期后仍可履约", () => {
    const { data, order } = fixture();
    order.type = type;
    order.quote.validUntil = "2000-01-01";
    order.quote.signedAt = "1999-12-31T12:00:00Z";
    const action = type === "sale" ? "stock_ready" : "start";
    const payload = type === "sale" ? { partId: data.parts[0].id, quantity: 1 } : {};
    assert.equal(D.apply(order, action, payload, actor(type === "sale" ? "warehouse" : "engineer"), data).status,
      type === "sale" ? "pending_delivery" : "repairing");
  });
}

test("未结提成形成缺项并拦截完结，结算后仍需人工确认", () => {
  const data = D.seed();
  let order = D.apply(data.orders[2], "commission", { person: "合成人员", amountCents: 100, note: "批准依据" }, actor("admin"), data);
  assert.equal(order.status, "settling");
  assert.ok(order.summary.missing.includes("提成待结算"));
  unchangedRejection(order, "complete", { note: "核对" }, "dispatcher", data, /条件|阶段/);
  order = D.apply(order, "settle_commission", { commissionId: order.commissions[0].id, note: "结算凭据" }, actor("finance"), data);
  assert.equal(order.status, "pending_completion");
  assert.equal(D.apply(order, "complete", {}, actor("dispatcher"), data).status, "completed");
});

test("提成没有独立转出合同，任意 transferred 标记不能绕过未结算缺项", () => {
  const data = D.seed();
  const order = data.orders[2];
  order.commissions = [{ id: "c", settled: false, transferred: true, amountCents: 100 }];
  assert.ok(D.derive(order, data.loans).missing.includes("提成待结算"));
});

test("重开保留历史与质保并生成有责任人的待复核余项，核实后才恢复待完结", () => {
  const data = D.seed();
  const original = D.apply(data.orders[2], "complete", { note: "合成完结" }, actor("dispatcher"), data);
  const snapshot = structuredClone(original);
  let order = D.apply(original, "reopen", { reason: "付款凭证需核查" }, actor("admin"), data);
  assert.equal(order.status, "settling");
  assert.equal(order.outcome, snapshot.outcome);
  assert.deepEqual(order.warranty, snapshot.warranty);
  assert.deepEqual(order.events.slice(0, -1), snapshot.events);
  const review = order.obligations.find((item) => !item.resolved && /重开复核/.test(item.title));
  assert.ok(review);
  assert.equal(review.ownerId, "admin");
  assert.ok(Date.parse(review.dueAt) > Date.parse(order.updatedAt));
  unchangedRejection(order, "complete", {}, "dispatcher", data, /条件|阶段/);
  order = D.apply(order, "resolve_obligation", { obligationId: review.id, note: "已核实" }, actor("admin"), data);
  assert.equal(order.status, "pending_completion");
  assert.equal(D.apply(order, "complete", {}, actor("dispatcher"), data).status, "completed");
  assert.deepEqual(original, snapshot);
});

test("重开缺少依据时原单、台账、版本及历史均不变", () => {
  const data = D.seed();
  const order = D.apply(data.orders[2], "complete", {}, actor("dispatcher"), data);
  unchangedRejection(order, "reopen", { reason: "" }, "admin", data, /原因|依据/);
});

for (const free of [true, false]) {
  test((free ? "免费" : "收费") + "返修仅继承稳定字段，旧财务、质保、外包及摘要均隔离", () => {
    const data = D.seed();
    const original = data.orders[2];
    Object.assign(original, {
      receivableCents: 100000, deliveredAt: "2026-01-01T01:00:00Z", acceptedAt: "2026-01-02T01:00:00Z",
      completionAt: "2026-01-03T01:00:00Z", completionBy: "dispatcher", completionVersion: 99,
      quoteHistory: [{ version: 99 }], restartReview: true,
      outsource: [{ id: "old", provider: "旧单外包" }],
      summary: { collectedCents: 100000, receivableCents: 100000, remainingCents: 0, missing: [] },
    });
    const before = structuredClone({ data, original });
    const child = D.apply(original, "rework", { free, note: "合成返修依据" }, actor("dispatcher"), data);
    assert.notEqual(child.id, original.id);
    assert.equal(child.originalOrderId, original.id);
    for (const name of ["type", "customer", "customerId", "companyId", "project", "device"]) assert.equal(child[name], original[name], name);
    assert.equal(child.description, "合成返修依据");
    assert.equal(child.status, "pending_intake");
    assert.equal(child.outcome, "");
    assert.equal(child.quote.amountCents, 0);
    assert.equal(child.quote.version, 0);
    assert.equal(child.receivableCents, 0);
    assert.equal(child.invoiceDueCents, 0);
    assert.equal(child.customerNote, "");
    assert.match(child.remark, free ? /免费/ : /收费/);
    for (const name of ["cash", "invoices", "evidence", "visits", "outsource", "costs", "commissions", "issues", "obligations"]) assert.deepEqual(child[name], [], name);
    assert.deepEqual(child.warranty, {});
    for (const name of ["acceptedAt", "deliveredAt", "completionAt", "completionBy", "completionVersion", "quoteHistory", "restartReview"]) assert.equal(child[name], undefined, name);
    assert.equal(child.events.length, 1);
    assert.equal(child.events[0].type, "rework");
    assert.deepEqual(child.summary, D.derive(child, data.loans));
    assert.equal(child.summary.warrantyLabel, "质保未起算");
    assert.equal(child.summary.collectedCents, 0);
    assert.equal(child.summary.receivableCents, 0);
    assert.ok(child.summary.missing.length > 0);
    assert.deepEqual({ data, original }, before);
  });
}

test("返修必须说明依据，未验收或空依据均不能创建子单", () => {
  const data = D.seed();
  unchangedRejection(data.orders[2], "rework", { note: "" }, "dispatcher", data, /依据|问题/);
  unchangedRejection(data.orders[3], "rework", { note: "合成依据" }, "dispatcher", data, /验收/);
});

for (const endsAt of ["2027-01-12", "2027-01-12T02:00:00.000Z"]) {
  test("中国自然日质保到截止日全天有效，次日零点到期：" + endsAt, () => {
    const order = D.seed().orders[2];
    const realNow = Date.now;
    try {
      for (const field of ["endAt", "endsAt"]) {
        order.warranty = { [field]: endsAt };
        for (const instant of ["2027-01-11T16:00:00Z", "2027-01-12T12:00:00Z", "2027-01-12T15:59:59.999Z"]) {
          Date.now = () => Date.parse(instant);
          assert.equal(D.derive(order).warrantyLabel, "质保中", field + ":" + instant);
        }
        Date.now = () => Date.parse("2027-01-12T16:00:00Z");
        assert.equal(D.derive(order).warrantyLabel, "质保已到期", field);
      }
    } finally { Date.now = realNow; }
  });
}

test("借用阻塞只扣已独立跟踪数量，并兼容旧记录", () => {
  for (const [loan, expected] of [
    [{ outstanding: 2 }, 2],
    [{ outstanding: 2, transfers: [{ quantity: 1 }] }, 1],
    [{ outstanding: 2, transfers: [{ quantity: 1 }, { quantity: 1 }] }, 0],
    [{ outstanding: 2, transfers: [{ quantity: 1, resolved: true }] }, 2],
    [{ outstanding: 2, transferred: true, transfer: { quantity: 1 } }, 1],
    [{ outstanding: 2, transferred: true }, 0],
    [{ outstanding: 2, transferred: true, transfers: [] }, 2],
    [{ outstanding: 0, transfers: [{ quantity: 1 }] }, 0],
  ]) {
    assert.equal(D.loanBlockingQuantity(loan), expected, JSON.stringify(loan));
  }
});

test("统一刷新让最后借用清除后恢复待完结，原完结状态仍由人工重开", () => {
  const data = D.seed();
  const order = data.orders[2];
  const loan = { id: "linked", orderId: order.id, outstanding: 2, transfers: [{ quantity: 1 }] };
  assert.equal(D.refreshOrder(order, [loan]), order);
  assert.equal(order.status, "settling");
  assert.ok(order.summary.missing.includes("关联借用配件未清"));
  loan.outstanding = 1;
  D.refreshOrder(order, [loan]);
  assert.equal(order.status, "pending_completion");
  assert.equal(order.summary.missing.length, 0);
  order.status = "completed";
  loan.outstanding = 2;
  D.refreshOrder(order, [loan]);
  assert.equal(order.status, "completed");
  assert.ok(order.summary.missing.includes("关联借用配件未清"));
});

test("未约定先款的现款或账期维修可零款开修，旧字段缺省与已有预付金额不隐含约定", () => {
  for (const paymentTerms of ["cash", "credit"]) {
    for (const flag of [undefined, false]) {
      for (const prepayCents of [0, 2000]) {
        const { data, order } = fixture();
        Object.assign(order.quote, { paymentTerms, prepayCents });
        if (flag !== undefined) order.quote.startRequiresPrepayment = flag;
        assert.equal(D.derive(order).collectedCents, 0);
        assert.equal(D.apply(order, "start", {}, actor("engineer"), data).status, "repairing");
      }
    }
  }
});

test("明确先款维修必须核实足额净预付款，未核实、部分与净退款不足均拒绝且输入不变", () => {
  for (const cash of [
    [],
    [{ kind: "receipt", amountCents: 2000, verified: false }],
    [{ kind: "receipt", amountCents: 1999, verified: true }],
    [{ kind: "receipt", amountCents: 2000, verified: true }, { kind: "refund", amountCents: 1, verified: true }],
  ]) {
    const { data, order } = fixture();
    Object.assign(order.quote, { startRequiresPrepayment: true, prepayCents: 2000 });
    order.cash = cash;
    unchangedRejection(order, "start", { note: "合成先款开修" }, "engineer", data, /预付|核实/);
  }
});

test("明确先款维修核实约定部分预付即可开修，不将约定升级为全款", () => {
  for (const paymentTerms of ["cash", "credit"]) {
    const { data, order } = fixture();
    Object.assign(order.quote, { paymentTerms, startRequiresPrepayment: true, prepayCents: 2000 });
    order.cash = [{ kind: "receipt", amountCents: 2500, verified: true }, { kind: "refund", amountCents: 500, verified: true }];
    assert.equal(D.derive(order).remainingCents, 8000);
    assert.equal(D.apply(order, "start", {}, actor("engineer"), data).status, "repairing");
  }
});

test("先款维修报价须明确合法布尔并约定正数预付且不超过总价，错误不改原单", () => {
  for (const patch of [
    ...[undefined, 0, -1, 10001, 0.5].map((prepayCents) => ({ startRequiresPrepayment: true, prepayCents })),
    { startRequiresPrepayment: "true", prepayCents: 2000 },
    { startRequiresPrepayment: "false", prepayCents: 2000 },
  ]) {
    const { data, order } = fixture();
    order.status = "diagnosis_quotation";
    unchangedRejection(order, "quote", { ...order.quote, ...patch }, "engineer", data, /先款|预付/);
  }
});

test("新维修报价记录先款约定，缺省false保留兼容但不改变预付金额", () => {
  for (const flag of [undefined, false, true]) {
    const { data, order } = fixture();
    order.status = "diagnosis_quotation";
    const payload = { ...order.quote, prepayCents: 2000 };
    if (flag !== undefined) payload.startRequiresPrepayment = flag;
    const before = structuredClone(payload);
    const next = D.apply(order, "quote", payload, actor("engineer"), data);
    assert.equal(next.quote.startRequiresPrepayment, flag === true);
    assert.equal(next.quote.prepayCents, 2000);
    assert.equal(next.quote.approved, false);
    assert.equal(next.quote.signed, false);
    assert.deepEqual(payload, before);
  }
  assert.equal(D.createOrder({ type: "mail", customer: "合成客户", device: "合成设备" }).quote.startRequiresPrepayment, false);
});

test("旧异常先款约定为零仍不能直接开修", () => {
  const { data, order } = fixture();
  Object.assign(order.quote, { startRequiresPrepayment: true, prepayCents: 0 });
  unchangedRejection(order, "start", {}, "engineer", data, /预付|核实/);
});

test("销售继续执行现款全款与账期既有预付门槛，维修开关不会放宽销售", () => {
  for (const [paymentTerms, prepayCents, required] of [["cash", 0, 10000], ["credit", 2000, 2000]]) {
    const { data, order } = fixture();
    order.type = "sale";
    Object.assign(order.quote, { paymentTerms, prepayCents, startRequiresPrepayment: false });
    const payload = { partId: data.parts[0].id, quantity: 1 };
    unchangedRejection(order, "stock_ready", payload, "warehouse", data, /款|核实/);
    order.cash = [{ kind: "receipt", amountCents: required, verified: false }];
    unchangedRejection(order, "stock_ready", payload, "warehouse", data, /款|核实/);
    order.cash[0].verified = true;
    assert.equal(D.apply(order, "stock_ready", payload, actor("warehouse"), data).status, "pending_delivery");
  }
});
