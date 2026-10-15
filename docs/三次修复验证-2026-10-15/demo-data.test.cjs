const test = require("node:test");
const assert = require("node:assert/strict");
const D = require("../data.js");

test("金额使用严格十进制转换，拒绝负数、科学记数与多余精度", () => {
  assert.equal(D.cents("1280.50"), 128050);
  assert.equal(D.cents("0.01"), 1);
  assert.equal(D.cents("12.1"), 1210);
  for (const invalid of ["", "-1", "1e3", "12.345", "NaN", ".1", "1,000"]) {
    assert.throws(() => D.cents(invalid));
  }
  assert.throws(() => D.cents("0", false));
  assert.throws(() => D.integer("1.5"));
});

test("现金仅累计已核实收款退款，内部交接不重记收入", () => {
  const order = D.seed().orders[0];
  order.quote.amountCents = 100000;
  order.cash = [
    { amountCents: 30000, kind: "receipt", verified: true, handedOver: true },
    { amountCents: 70000, kind: "receipt", verified: true, handedOver: false },
    { amountCents: 20000, kind: "receipt", verified: false },
    { amountCents: 10000, kind: "refund", verified: true, handedOver: true },
  ];
  const summary = D.derive(order);
  assert.equal(summary.collectedCents, 90000);
  assert.equal(summary.remainingCents, 10000);
  assert.equal(summary.pendingCashCents, 20000);
  assert.ok(summary.missing.includes("内部现金交接待完成"));
  order.cash[1].handedOver = true;
  assert.equal(D.derive(order).collectedCents, 90000);
});

test("待收为零并不掩盖超收与未核实现金", () => {
  const order = D.seed().orders[0];
  order.quote.amountCents = 100000;
  order.cash = [
    { amountCents: 110000, kind: "receipt", verified: true, handedOver: true },
  ];
  const summary = D.derive(order);
  assert.equal(summary.remainingCents, 0);
  assert.equal(summary.overpaidCents, 10000);
  assert.ok(summary.missing.includes("超收款尚未处理"));
});

test("发票超开和引用附件删除都会形成待办理缺项", () => {
  const order = D.seed().orders[1];
  order.invoices[0].amountCents = 120000;
  assert.equal(D.derive(order).invoiceStatus, "over");
  order.evidence[0].deleted = true;
  assert.equal(D.derive(order).documentStatus, "supplement");
  assert.equal(order.cash[0].verified, true);
});

test("借用数量守恒且仅关联工单受阻塞", () => {
  const data = D.seed();
  const loan = data.loans[0];
  assert.equal(
    loan.quantity,
    loan.returnedGood +
      loan.returnedQuarantine +
      loan.consumed +
      loan.disposed +
      loan.outstanding,
  );
  assert.ok(
    D.derive(data.orders[3], data.loans).missing.includes("关联借用配件未清"),
  );
  assert.ok(
    !D.derive(data.orders[0], data.loans).missing.includes("关联借用配件未清"),
  );
});

test("自然月质保支持月末和闰年，不能用固定30天代替", () => {
  assert.equal(
    D.addMonths("2026-01-31T02:00:00Z", 1),
    "2026-02-28T02:00:00.000Z",
  );
  assert.equal(
    D.addMonths("2024-01-31T02:00:00Z", 1),
    "2024-02-29T02:00:00.000Z",
  );
  assert.equal(
    D.addMonths("2026-10-13T02:00:00Z", 3),
    "2027-01-13T02:00:00.000Z",
  );
  assert.equal(
    D.addMonths("2026-01-30T18:00:00Z", 1),
    "2026-02-27T18:00:00.000Z",
  );
});

test("现款销售未核实收齐不得出库，失败不扣库存", () => {
  const data = D.seed();
  const order = structuredClone(data.orders[4]);
  order.status = "pending_execution";
  order.quote.signed = true;
  order.quote.paymentTerms = "cash";
  const initialStock = data.parts[0].available;
  assert.throws(
    () =>
      D.apply(
        order,
        "stock_ready",
        { partId: data.parts[0].id, quantity: 4 },
        { id: "warehouse", role: "warehouse" },
        data,
      ),
    /收齐/,
  );
  assert.equal(data.parts[0].available, initialStock);
});

test("管理员不代客户签署，外包不改内部备注，完结需人工确认", () => {
  const data = D.seed();
  assert.throws(
    () =>
      D.apply(
        data.orders[4],
        "sign_quote",
        { signature: "synthetic" },
        { id: "admin", role: "admin" },
        data,
      ),
    /无权/,
  );
  assert.ok(!D.permissions.outsource.includes("remark"));
  const complete = D.apply(
    data.orders[2],
    "complete",
    { note: "合成负责人核对" },
    { id: "dispatcher", role: "dispatcher" },
    data,
  );
  assert.equal(complete.status, "completed");
  assert.equal(data.orders[2].status, "pending_completion");
  assert.equal(Object.keys(D.states).length, 12);
});

function remarkFixture() {
  const data = D.seed();
  const order = data.orders[0];
  order.remark = "合成内部备注，省略字段必须保留";
  order.customerNote = "原客户说明";
  return { data, order };
}

test("备注按字段更新，省略与 null 都保留未修改的原值", () => {
  for (const role of [
    "admin", "dispatcher", "finance", "engineer", "qc", "warehouse",
  ]) {
    for (const payload of [
      {},
      { remark: null, customerNote: null },
      { customerNote: "新客户说明" },
    ]) {
      const { data, order } = remarkFixture();
      const before = structuredClone(data);
      const result = D.apply(order, "remark", payload, { id: role, role }, data);
      assert.equal(result.remark, order.remark, role);
      assert.equal(
        result.customerNote,
        payload.customerNote ?? order.customerNote,
        role,
      );
      assert.equal(result.version, order.version + 1, role);
      assert.equal(result.events.length, order.events.length + 1, role);
      assert.deepEqual(data, before, role);
    }
  }
});

test("授权角色可明确清空任一备注字段，另一字段仍保留", () => {
  for (const role of ["admin", "dispatcher", "finance", "engineer"]) {
    for (const payload of [
      { remark: "" },
      { customerNote: "" },
      { remark: "", customerNote: "" },
      { remark: "更正内部备注" },
    ]) {
      const { data, order } = remarkFixture();
      const result = D.apply(order, "remark", payload, { id: role, role }, data);
      assert.equal(result.remark, payload.remark ?? order.remark, role);
      assert.equal(
        result.customerNote,
        payload.customerNote ?? order.customerNote,
        role,
      );
    }
  }
});

test("质检与仓库兼容脱敏空备注，只更正或清空客户说明", () => {
  for (const role of ["qc", "warehouse"]) {
    for (const payload of [
      { remark: "" },
      { remark: "", customerNote: "新客户说明" },
      { remark: "", customerNote: "" },
      { remark: null, customerNote: "" },
    ]) {
      const { data, order } = remarkFixture();
      const result = D.apply(order, "remark", payload, { id: role, role }, data);
      assert.equal(result.remark, order.remark, role);
      assert.equal(
        result.customerNote,
        payload.customerNote ?? order.customerNote,
        role,
      );
    }
  }
});

test("备注权限或格式校验失败时保留台账、版本、事件和输入，纠正后仅更新一次", () => {
  const cases = [
    ...["qc", "warehouse"].flatMap((role) => [
      { role, payload: { customerNote: "不能部分提交", remark: "禁止内部改写" } },
      { role, payload: { remark: "   ", customerNote: "不能部分提交" } },
    ]),
    ...[
      "admin", "dispatcher", "finance", "engineer", "qc", "warehouse",
    ].flatMap((role) => [
      { role, payload: { remark: 123, customerNote: "不能部分提交" } },
      { role, payload: { remark: "", customerNote: false } },
      { role, payload: { customerNote: "不能部分提交", remark: [] } },
      { role, payload: { remark: "", customerNote: {} } },
    ]),
  ];
  for (const { role, payload } of cases) {
    const { data, order } = remarkFixture();
    const before = structuredClone(data);
    const originalPayload = structuredClone(payload);
    assert.throws(
      () => D.apply(order, "remark", payload, { id: role, role }, data),
      /备注|无权/,
      role,
    );
    assert.deepEqual(data, before, role);
    assert.deepEqual(payload, originalPayload, role);
    const corrected = D.apply(
      order,
      "remark",
      { customerNote: "纠正后客户说明" },
      { id: role, role },
      data,
    );
    assert.equal(corrected.remark, order.remark, role);
    assert.equal(corrected.customerNote, "纠正后客户说明", role);
    assert.equal(corrected.version, order.version + 1, role);
    assert.equal(corrected.events.length, order.events.length + 1, role);
    assert.deepEqual(data, before, role);
  }
});

test("外部角色不能通过演示备注动作修改任一字段", () => {
  for (const role of ["customer", "outsource", "supplier"]) {
    const { data, order } = remarkFixture();
    const before = structuredClone(data);
    assert.throws(
      () => D.apply(
        order,
        "remark",
        { remark: "", customerNote: "外部改写" },
        { id: role, role },
        data,
      ),
      /无权/,
      role,
    );
    assert.deepEqual(data, before, role);
  }
});

test("备注字段大小写、重复名称与 null 的覆盖顺序和后端一致", () => {
  for (const row of [
    {
      json: '{"remark":"禁止改写","Remark":"","customerNote":"新客户说明"}',
      allowed: true,
      note: "新客户说明",
    },
    {
      json: '{"remark":"","Remark":"禁止改写","customerNote":"新客户说明"}',
      allowed: false,
    },
    {
      json: '{"remark":"禁止改写","Remark":null,"CUSTOMERNOTE":"新客户说明"}',
      allowed: true,
      note: "新客户说明",
    },
    {
      json: '{"customerNote":"替换值","CustomerNote":null}',
      allowed: true,
      note: "原客户说明",
    },
  ]) {
    const { data, order } = remarkFixture();
    const before = structuredClone(data);
    const payload = JSON.parse(row.json);
    if (!row.allowed) {
      assert.throws(
        () => D.apply(order, "remark", payload, { id: "qc", role: "qc" }, data),
        /备注|无权/,
      );
      assert.deepEqual(data, before);
      continue;
    }
    const result = D.apply(order, "remark", payload, { id: "qc", role: "qc" }, data);
    assert.equal(result.remark, order.remark);
    assert.equal(result.customerNote, row.note);
  }
});
