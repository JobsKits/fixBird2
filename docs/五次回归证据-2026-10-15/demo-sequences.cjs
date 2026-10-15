/* Jobs · 第五轮合成演示多动作诊断；仅加载当前产品，不修改源码。 */
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const root = "/Users/jobs/Desktop/啄木鸟维修平台-V3.8";
const D = require(path.join(root, "Workspace/data.js"));
const formal = fs.readFileSync(path.join(root, "Workspace/tests/app.test.cjs"), "utf8");
let prefix = formal.slice(0, formal.indexOf("\ntest("));
const exportNeedle = "getState: () => ({data, actor, dataKind, connected, page, token, view, cachedDetailIds: [...details.keys()]})";
assert.ok(prefix.includes(exportNeedle), "formal harness export boundary changed");
prefix = prefix
  .replace('require("../data.js")', "require(" + JSON.stringify(path.join(root, "Workspace/data.js")) + ")")
  .replace('path.join(__dirname, "../app.js")', JSON.stringify(path.join(root, "Workspace/app.js")))
  .replace(exportNeedle, "getDemo: () => demo, available, " + exportNeedle);
const { harness, flush } = new Function("require", prefix + "\nreturn {harness, flush};")(require);
const cases = [], observations = {}, rows = [];
const check = (id, title, fn) => cases.push({ id, title, fn });
const state = (h) => h.app.getState().data;
const order = (h, id) => state(h).orders.find((o) => o.id === id);
async function demo(role = "admin") {
  const h = harness();
  await flush();
  // The formal lightweight harness omits native getAll; selected files need it.
  h.context.FormData.prototype.getAll = function (name) {
    const value = this.values.get(name);
    return value == null ? [] : Array.isArray(value) ? value : [value];
  };
  h.context.fetch = async () => { throw Error("synthetic offline diagnostic"); };
  h.app.openDemo(role);
  return h;
}
function convertedInputs(h, fields) {
  h.context.document.querySelectorAll = (selector) =>
    selector === "#actionForm [data-integer]"
      ? Object.entries(fields).filter(([k]) => k === "quantity").map(([name, value]) => ({ name, value: String(value) }))
      : selector === "#actionForm [data-cents]"
        ? Object.entries(fields).filter(([k]) => ["amountCents", "prepayCents", "unitCents", "invoiceDueCents"].includes(k))
          .map(([name, value]) => ({ name, value: String(value), hasAttribute: () => false }))
        : [];
}
async function action(h, type, id, fields, record = "") {
  await h.app.showAction(type, id, record);
  convertedInputs(h, fields);
  await h.submit("actionForm", fields);
}
async function globalAction(h, type, id, mode, fields) {
  h.app.globalForm(type, id, mode);
  convertedInputs(h, fields);
  await h.submit("actionForm", fields);
}
async function cash(h, id, kind, yuan) {
  await action(h, "cash", id, { kind, amountCents: yuan, purpose: "合成资金序列", receipt: "合成现金凭证", occurredAt: "2026-10-15T08:00" });
  return order(h, id).cash.at(-1).id;
}
async function verify(h, id, cashId) {
  await action(h, "verify_cash", id, { note: "合成财务核实" }, cashId);
}
async function newLoan(h, orderId = "demo-003", quantity = "2", borrowerId = "engineer") {
  const before = new Set(state(h).loans.map((item) => item.id));
  await globalAction(h, "loan", "", "", { orderId, partId: state(h).parts[0].id, quantity, borrowerId, dueAt: "2099-01-01", note: "合成借用交接依据" });
  return state(h).loans.find((item) => !before.has(item.id));
}

for (const mode of ["consume", "dispose", "transfer"]) {
  check("Q01-" + mode, "仓库无管理员批准不能自行办理借用" + mode + "（实际全局表单）", async () => {
    const h = await demo("warehouse"), loan = state(h).loans[0], before = JSON.stringify(state(h));
    h.app.globalForm("loanAction", loan.id, mode);
    const form = h.node("#formContent").innerHTML;
    const fields = { quantity: "1", reason: "仓库自行填写的合成处置原因", ownerId: "engineer", dueAt: "2099-01-01" };
    convertedInputs(h, fields);
    await h.submit("actionForm", fields);
    observations["Q01-" + mode] = { role: h.app.getState().actor.role, formReachable: !!form, before: loan, after: state(h).loans.find((l) => l.id === loan.id), formError: h.node("#formError").textContent };
    assert.equal(JSON.stringify(state(h)), before, "仓库仅输入原因就完成了须管理员批准的" + mode);
  });
}

check("Q02", "已完结工单必须先重开才能新增关联借用（实际表单）", async () => {
  const h = await demo(), id = "demo-003";
  await action(h, "complete", id, { note: "合成负责人核对完结" });
  assert.equal(order(h, id).status, "completed");
  const before = JSON.stringify(state(h));
  await newLoan(h, id, "1");
  observations.Q02 = { orderStatus: order(h, id).status, missing: order(h, id).summary.missing, loans: state(h).loans.filter((l) => l.orderId === id) };
  assert.equal(JSON.stringify(state(h)), before, "未重开仍借出库存并给已完结工单追加未清借用");
});

check("Q03", "未关联工单的独立借用不能直接转维修耗用（实际表单）", async () => {
  const h = await demo(), loan = await newLoan(h, "", "1"), before = JSON.stringify(state(h));
  assert.ok(loan && !loan.orderId);
  await globalAction(h, "loanAction", loan.id, "consume", { quantity: "1", reason: "合成暂未指定工单耗用" });
  observations.Q03 = state(h).loans.find((l) => l.id === loan.id);
  assert.equal(JSON.stringify(state(h)), before, "没有工单和本单成本依据仍完成维修耗用");
});

check("Q04", "借用责任人必须是内部工程师，表单不能选财务后直接借出", async () => {
  const h = await demo(), before = JSON.stringify(state(h));
  h.app.globalForm("loan");
  assert.match(h.node("#formContent").innerHTML, /value="finance"/);
  const fields = { orderId: "", partId: state(h).parts[0].id, quantity: "1", borrowerId: "finance", dueAt: "2099-01-01", note: "合成选择表单提供的财务账号" };
  convertedInputs(h, fields);
  await h.submit("actionForm", fields);
  observations.Q04 = { newLoan: state(h).loans.at(-1), formError: h.node("#formError").textContent };
  assert.equal(JSON.stringify(state(h)), before, "财务账号被当作内部工程师借用责任人接受");
});

check("Q05", "财务不能核实超过已核实净收款的退款，失败应原子保留原台账", async () => {
  const h = await demo("finance"), id = "demo-003", originalNet = D.derive(order(h, id)).collectedCents;
  const refundId = await cash(h, id, "refund", String((originalNet + 100) / 100));
  const before = JSON.stringify(state(h));
  await verify(h, id, refundId);
  observations.Q05 = { originalNet, after: D.derive(order(h, id)), cash: order(h, id).cash, error: h.node("#formError").textContent };
  assert.equal(JSON.stringify(state(h)), before, "超额退款被核实，净实收变为负数");
});

check("Q06", "退款核实后仍须处理内部交接，不能在交接false时整单完结", async () => {
  const h = await demo("finance"), id = "demo-003";
  const refundId = await cash(h, id, "refund", "100.00");
  await verify(h, id, refundId);
  const net = D.derive(order(h, id)).collectedCents;
  await action(h, "adjust_receivable", id, { amountCents: String(net / 100), reason: "合成退款后有效应收更正" });
  h.app.openDemo("dispatcher");
  const before = structuredClone(order(h, id));
  if (h.app.available(order(h, id)).includes("complete")) await action(h, "complete", id, { note: "合成核对" });
  observations.Q06 = { before, after: order(h, id), refunded: order(h, id).cash.find((c) => c.id === refundId) };
  assert.notEqual(order(h, id).status, "completed", "退款handedOver=false但演示允许完结");
});

check("Q07", "已有有效票号不能重复登记（实际发票表单）", async () => {
  const h = await demo("finance"), id = "demo-002", original = order(h, id).invoices[0];
  assert.ok(original.files.length && original.number);
  const before = JSON.stringify(state(h));
  await action(h, "invoice", id, { number: original.number, amountCents: String(original.amountCents / 100), files: original.files });
  observations.Q07 = { invoices: order(h, id).invoices, beforeCount: 1, error: h.node("#formError").textContent };
  assert.equal(JSON.stringify(state(h)), before, "重复有效票号被记录为第二张发票");
});

check("Q08", "已确认无需发票时不能从发票表单继续登记真实票据", async () => {
  const h = await demo("finance"), id = "demo-002", old = order(h, id).invoices[0];
  await h.app.mutateOrder(order(h, id), "requirements", { documentRequirement: "required", documentReason: "合成保留资料", invoiceRequirement: "none", invoiceReason: "合成无需票据", invoiceDueCents: 0 });
  const before = JSON.stringify(state(h));
  await action(h, "invoice", id, { number: "SYNTHETIC-NOT-REQUIRED", amountCents: "1.00", files: old.files });
  observations.Q08 = { requirement: order(h, id).invoiceRequirement, invoices: order(h, id).invoices };
  assert.equal(JSON.stringify(state(h)), before, "无需票据约定下仍新增票据");
});

check("Q09", "文字证据不能被发票表单当作有效PDF/图片票据文件", async () => {
  const h = await demo("finance"), id = "demo-002";
  await action(h, "evidence", id, { name: "合成文字资料", kind: "text", text: "普通文字，不是电子发票原件", stage: "settling" });
  const ev = order(h, id).evidence.at(-1);
  assert.equal(ev.kind, "text");
  await h.app.showAction("invoice", id);
  assert.match(h.node("#formContent").innerHTML, new RegExp(ev.id));
  const before = JSON.stringify(state(h));
  const fields = { number: "SYNTHETIC-TEXT-INVOICE", amountCents: "1.00", files: [ev.id] };
  convertedInputs(h, fields);
  await h.submit("actionForm", fields);
  observations.Q09 = { evidence: ev, invoices: order(h, id).invoices };
  assert.equal(JSON.stringify(state(h)), before, "普通文字证据被当作发票原件接受");
});

check("Q10", "发送付款资料必须记录接收对象，空对象不能形成已发送", async () => {
  const h = await demo("finance"), id = "demo-002", files = order(h, id).documents.files;
  assert.ok(files.length);
  await action(h, "documents", id, { prepared: "true", sent: "false", recipient: "", files });
  assert.equal(order(h, id).documents.prepared, true, "合法未发送资料应先正常保存");
  assert.equal(order(h, id).documents.sent, false);
  const before = JSON.stringify(state(h));
  await action(h, "documents", id, { prepared: "true", sent: "true", recipient: "", files });
  observations.Q10 = { documents: order(h, id).documents, summary: order(h, id).summary };
  assert.equal(JSON.stringify(state(h)), before, "接收对象为空仍形成已发送资料事实");
});

check("Q11", "有效已验收结果不能通过停止履约表单覆盖取消", async () => {
  const h = await demo(), id = "demo-001", original = structuredClone(order(h, id));
  assert.equal(original.outcome, "accepted");
  assert.ok(h.app.available(original).includes("failure"));
  await action(h, "failure", id, { reason: "cancelled", amountCents: "0.00", returnRequired: "false", note: "合成在已验收后尝试取消" });
  observations.Q11 = { originalOutcome: original.outcome, nextOutcome: order(h, id).outcome, warranty: order(h, id).warranty, status: order(h, id).status };
  assert.equal(order(h, id).outcome, "accepted", "已验收事实被直接覆盖为取消且保留旧质保");
});

check("Q12", "已确认的停止结果不能用第二次停止表单覆盖原结果", async () => {
  const h = await demo(), id = "demo-004";
  await action(h, "failure", id, { reason: "unrepairable", amountCents: "0.00", returnRequired: "false", note: "合成技术判定不能修" });
  const before = JSON.stringify(order(h, id));
  await action(h, "failure", id, { reason: "cancelled", amountCents: "0.00", returnRequired: "false", note: "合成再次改成取消" });
  observations.Q12 = { outcome: order(h, id).outcome, events: order(h, id).events.filter((e) => e.type === "failure") };
  assert.equal(JSON.stringify(order(h, id)), before, "原停止履约结果和原因被第二次停止覆盖");
});

check("Q13", "未约定先款的维修预付金额仍不能高于报价总价", async () => {
  const h = await demo(), id = "demo-006";
  await action(h, "intake", id, { ownerId: "dispatcher", assigneeId: "engineer" });
  await action(h, "diagnose", id, { note: "合成实际检测" });
  assert.equal(order(h, id).status, "diagnosis_quotation");
  assert.ok(h.app.available(order(h, id)).includes("quote"));
  const before = JSON.stringify(state(h));
  await action(h, "quote", id, { amountCents: "100.00", prepayCents: "200.00", startRequiresPrepayment: "false", warrantyMonths: "3", paymentTerms: "cash", validUntil: "2099-01-01", autoAccept: "false", description: "合成预付金额高于总价" });
  observations.Q13 = { quote: order(h, id).quote, status: order(h, id).status, error: h.node("#formError").textContent };
  assert.equal(JSON.stringify(state(h)), before, "预付款超过总价的报价被保存");
});

check("Q14", "已完结客户登记异议不能保持completed并遗留未完成必办事项", async () => {
  const h = await demo(), id = "demo-003";
  await action(h, "complete", id, { note: "合成完结" });
  h.app.openDemo("customer");
  assert.ok(h.app.available(order(h, id)).includes("issue"));
  const before = JSON.stringify(state(h));
  await action(h, "issue", id, { note: "合成完结后新的争议", ownerId: "dispatcher", dueAt: "2099-01-01" });
  observations.Q14 = { status: order(h, id).status, issues: order(h, id).issues, missing: order(h, id).summary.missing };
  assert.equal(JSON.stringify(state(h)), before, "已完结单直接新增未结异议但未受控重开");
});

check("Q15", "管理员部分转出两次、先核销转出件再归还，数量守恒并保持未转件阻塞（正对照）", async () => {
  const h = await demo(), loan = await newLoan(h, "demo-003", "3");
  for (let i = 0; i < 2; i++) await globalAction(h, "loanAction", loan.id, "transfer", { quantity: "1", reason: "合成批准分批独立跟踪", ownerId: "engineer", dueAt: "2099-01-01" });
  await globalAction(h, "loanAction", loan.id, "return", { quantity: "1", condition: "quarantine" });
  let current = state(h).loans.find((l) => l.id === loan.id);
  assert.equal(current.outstanding, 2);
  assert.equal(D.loanBlockingQuantity(current), 1);
  assert.equal(current.quantity, current.returnedGood + current.returnedQuarantine + current.consumed + current.disposed + current.outstanding);
  await globalAction(h, "loanAction", loan.id, "consume", { quantity: "1", reason: "合成管理员批准关联耗用" });
  current = state(h).loans.find((l) => l.id === loan.id);
  assert.equal(current.outstanding, 1);
  assert.equal(D.loanBlockingQuantity(current), 1);
  await globalAction(h, "loanAction", loan.id, "return", { quantity: "1", condition: "good" });
  assert.equal(order(h, "demo-003").status, "pending_completion");
});

check("Q16", "超量归还/重复转出保持台账原子性（正对照）", async () => {
  const h = await demo(), loan = await newLoan(h, "demo-003", "1");
  await globalAction(h, "loanAction", loan.id, "transfer", { quantity: "1", reason: "合成批准", ownerId: "engineer", dueAt: "2099-01-01" });
  const before = JSON.stringify(state(h));
  await globalAction(h, "loanAction", loan.id, "transfer", { quantity: "1", reason: "合成重复转出", ownerId: "engineer", dueAt: "2099-01-01" });
  assert.equal(JSON.stringify(state(h)), before);
  await globalAction(h, "loanAction", loan.id, "return", { quantity: "2", condition: "good" });
  assert.equal(JSON.stringify(state(h)), before);
});

check("Q17", "明确先款的维修在净退款后仍按约定预付拦截，不要求无约定维修全款（正对照）", () => {
  const data = D.seed(), source = structuredClone(data.orders[3]);
  source.status = "pending_execution";
  Object.assign(source.quote, { signed: true, approved: true, paymentTerms: "cash", startRequiresPrepayment: true, prepayCents: 2000, amountCents: 10000 });
  source.cash = [{ kind: "receipt", amountCents: 2000, verified: true }, { kind: "refund", amountCents: 1, verified: true }];
  assert.throws(() => D.apply(source, "start", {}, { id: "engineer", role: "engineer" }, data), /预付/);
  source.quote.startRequiresPrepayment = false;
  assert.equal(D.apply(source, "start", {}, { id: "engineer", role: "engineer" }, data).status, "repairing");
});

check("Q18", "现款销售冻结报价门槛不随应收降低，账期继续原预付门槛（正对照）", () => {
  const data = D.seed(), source = structuredClone(data.orders[4]);
  source.status = "pending_execution";
  Object.assign(source.quote, { signed: true, approved: true, amountCents: 10000, prepayCents: 2000, paymentTerms: "cash" });
  source.receivableCents = 2000;
  source.cash = [{ kind: "receipt", amountCents: 2000, verified: true }];
  const payload = { partId: data.parts[0].id, quantity: 1 }, actor = { id: "warehouse", role: "warehouse" };
  assert.throws(() => D.apply(source, "stock_ready", payload, actor, data), /现款/);
  source.quote.paymentTerms = "credit";
  assert.equal(D.apply(source, "stock_ready", payload, actor, data).status, "pending_delivery");
});

check("Q19", "返修子单白名单隔离且重开复核余项未处理前不能完结（正对照）", () => {
  const data = D.seed(), actor = { id: "admin", role: "admin" };
  const finished = D.apply(data.orders[2], "complete", {}, actor, data);
  const reopened = D.apply(finished, "reopen", { reason: "合成复核" }, actor, data);
  assert.equal(reopened.status, "settling");
  assert.throws(() => D.apply(reopened, "complete", {}, actor, data));
  const child = D.apply(finished, "rework", { free: true, note: "合成返修" }, actor, data);
  assert.equal(child.receivableCents, 0);
  assert.deepEqual(child.cash, []);
  assert.deepEqual(child.outsource, []);
  assert.deepEqual(child.warranty, {});
  assert.equal(child.summary.warrantyLabel, "质保未起算");
});

check("Q20", "外部角色不能更改内部备注或冒名签署，过期报价审签拒绝（正对照）", () => {
  const data = D.seed(), source = structuredClone(data.orders[4]);
  assert.throws(() => D.apply(source, "remark", { remark: "外部改写" }, { id: "supplier", role: "supplier" }, data), /无权/);
  assert.throws(() => D.apply(source, "sign_quote", { signature: "synthetic", quoteVersion: source.quote.version }, { id: "admin", role: "admin" }, data), /无权/);
  source.quote.validUntil = "2000-01-01";
  assert.throws(() => D.apply(source, "sign_quote", { signature: "synthetic", quoteVersion: source.quote.version }, { id: "customer", role: "customer" }, data), /期限/);
});

check("Q21", "合法唯一票号和当前有效PDF文件可从真实发票callback保存（正对照）", async () => {
  const h = await demo("finance"), id = "demo-002", files = order(h, id).invoices[0].files;
  const count = order(h, id).invoices.length;
  await action(h, "invoice", id, { number: "SYNTHETIC-UNIQUE-PDF", amountCents: "1.00", files });
  assert.equal(order(h, id).invoices.length, count + 1);
  assert.equal(order(h, id).invoices.at(-1).number, "SYNTHETIC-UNIQUE-PDF");
  assert.deepEqual(Array.from(order(h, id).invoices.at(-1).files), Array.from(files));
});

check("Q22", "资料齐备并填写接收对象时真实callback正常形成已发送（正对照）", async () => {
  const h = await demo("finance"), id = "demo-002", files = order(h, id).documents.files;
  await action(h, "documents", id, { prepared: "true", sent: "true", recipient: "合成客户经办与送达凭据", files });
  assert.equal(order(h, id).documents.sent, true);
  assert.equal(order(h, id).documents.recipient, "合成客户经办与送达凭据");
  assert.equal(order(h, id).summary.documentStatus, "sent");
});

(async () => {
  for (const [index, item] of cases.entries()) {
    try {
      await item.fn(); rows.push({ id: item.id, title: item.title, passed: true });
      console.log("ok " + (index + 1) + " - " + item.id + " " + item.title);
    } catch (error) {
      rows.push({ id: item.id, title: item.title, passed: false, message: error.message, expected: error.expected, actual: error.actual, stack: error.stack });
      console.log("not ok " + (index + 1) + " - " + item.id + " " + item.title + "\n  " + error.message.split("\n")[0]);
    }
  }
  const sha256 = (file) => crypto.createHash("sha256").update(fs.readFileSync(path.join(root, file))).digest("hex");
  const report = { date: "2026-10-15", tests: rows.length, pass: rows.filter((r) => r.passed).length, fail: rows.filter((r) => !r.passed).length, skip: 0,
    mode: "Independent synthetic demo only; no real-service authorization bypass claimed", source: Object.fromEntries(["Workspace/data.js", "Workspace/app.js", "Workspace/tests/app.test.cjs"].map((file) => [file, sha256(file)])), observations, rows,
    fixture: "Current D.seed and legitimate actual app showAction/globalForm submit callbacks; no product-state export except read-only test getDemo/available injection in VM; positive boundary fixtures explicitly use synthetic clones",
    cleanup: "No services, browsers, containers, temp directories, keys or real data created. Product/formal test/historic evidence files unchanged." };
  const output = process.argv[2] || "demo-results.json";
  assert.ok(/^demo-[a-z0-9-]+\.json$/.test(output));
  fs.writeFileSync(path.join(__dirname, output), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify({ tests: report.tests, pass: report.pass, fail: report.fail, skip: 0 }));
  process.exitCode = report.fail ? 1 : 0;
})().catch((error) => { console.error(error); process.exitCode = 2; });
