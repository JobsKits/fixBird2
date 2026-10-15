/* Jobs · 第四轮外部演示业务诊断；不修改产品或正式测试。 */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = '/Users/jobs/Desktop/啄木鸟维修平台-V3.8';
const output = __dirname;
const D = require(path.join(root, 'Workspace/data.js'));
const formal = fs.readFileSync(path.join(root, 'Workspace/tests/app.test.cjs'), 'utf8');
let prefix = formal.slice(0, formal.indexOf('\ntest('));
prefix = prefix.replace('require("../data.js")', `require(${JSON.stringify(path.join(root, 'Workspace/data.js'))})`)
  .replace('path.join(__dirname, "../app.js")', JSON.stringify(path.join(root, 'Workspace/app.js')))
  .replace('getState: () => ({data, actor, dataKind, connected, page, token, view, cachedDetailIds: [...details.keys()]})',
    'getDemo: () => demo, available, getState: () => ({data, actor, dataKind, connected, page, token, view, cachedDetailIds: [...details.keys()]})');
const {harness, flush} = new Function('require', prefix + '\nreturn {harness, flush};')(require);
const checks = [];
const rows = [];
const observations = {};
function check(id, title, fn) { checks.push({id, title, fn}); }
const actor = role => ({id: role, role});
function orderFixture() {
  const data = D.seed();
  const o = structuredClone(data.orders[3]);
  o.status = 'pending_execution';
  o.quote = {...o.quote, signed: true, approved: true, amountCents: 10000, prepayCents: 0, paymentTerms: 'credit'};
  o.receivableCents = 10000;
  o.issues = [];
  o.cash = [];
  return {data, o};
}
function apply(o, type, payload, role, data) {
  return D.apply(o, type, payload, actor(role), data);
}
async function demoHarness(role = 'admin') {
  const h = harness();
  await flush();
  h.context.fetch = async () => { throw new Error('synthetic offline only'); };
  h.app.openDemo(role);
  return h;
}
function integerInput(h, values) {
  h.context.document.querySelectorAll = selector => selector === '#actionForm [data-integer]'
    ? Object.entries(values).map(([name, value]) => ({name, value: String(value)})) : [];
}
async function globalSubmit(h, type, id, action, fields) {
  h.app.globalForm(type, id, action);
  if (fields.quantity != null) integerInput(h, {quantity: fields.quantity});
  await h.submit('actionForm', fields);
}
async function freshRepair(h, terms = 'cash') {
  h.app.createForm();
  await h.submit('actionForm', {type: 'mail', customerId: 'customer', customer: '合成现金维修客户',
    device: '合成设备', description: '合成业务验证', project: '仅测试', prepayChoice: 'none'});
  const id = h.app.getState().data.orders.find(o => !/^demo-00\d$/.test(o.id)).id;
  for (const [type, payload] of [
    ['intake', {ownerId: 'dispatcher', assigneeId: 'engineer'}],
    ['diagnose', {note: '实际合成检测'}],
    ['quote', {amountCents: 10000, description: '合成方案', warrantyMonths: 3,
      paymentTerms: terms, prepayCents: 0, validUntil: '2099-01-01T15:59:59.000Z'}],
    ['approve_quote', {note: '合成审核'}],
  ]) await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), type, payload);
  h.app.openDemo('customer');
  let o = h.app.getState().data.orders.find(o => o.id === id);
  await h.app.mutateOrder(o, 'sign_quote', {signature: 'synthetic-demo-only', quoteVersion: o.quote.version});
  h.app.openDemo('admin');
  return id;
}
async function completedFreshRepair(h) {
  const id = await freshRepair(h, 'credit');
  const act = async (type, payload) => h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), type, payload);
  for (const [type, payload] of [
    ['start', {note: '合成开修'}],
    ['finish', {note: '合成完工'}],
    ['qc', {passed: true, note: '合成质检通过'}],
    ['deliver', {deliveredAt: new Date().toISOString(), note: '合成完整签收'}],
  ]) await act(type, payload);
  h.app.openDemo('customer');
  await act('accept', {signature: 'synthetic-demo-only', passed: true, note: '合成验收'});
  h.app.openDemo('admin');
  await act('requirements', {documentRequirement: 'none', documentReason: '合成无需资料',
    invoiceRequirement: 'none', invoiceReason: '合成无需票据', invoiceDueCents: 0});
  await act('cash', {kind: 'receipt', amountCents: 10000, occurredAt: new Date().toISOString(), purpose: '合成收款', note: '合成凭据'});
  const cashId = h.app.getState().data.orders.find(o => o.id === id).cash[0].id;
  await act('verify_cash', {cashId, note: '合成财务核实'});
  await act('handover_cash', {cashId, note: '合成交接核实'});
  await act('complete', {note: '合成负责人完结核对'});
  assert.equal(h.app.getState().data.orders.find(o => o.id === id).status, 'completed');
  return id;
}

check('D01', '批准企业账期且无异议允许开始维修（正对照）', () => {
  const {data, o} = orderFixture();
  assert.equal(apply(o, 'start', {note: '合成开修'}, 'engineer', data).status, 'repairing');
});
check('D02', '现款维修未收款不能开始维修（实际 app 完整新单链）', async () => {
  const h = await demoHarness();
  const id = await freshRepair(h);
  const o = h.app.getState().data.orders.find(o => o.id === id);
  assert.equal(o.quote.paymentTerms, 'cash');
  assert.equal(D.derive(o).collectedCents, 0);
  await h.app.showAction('start', id);
  await h.submit('actionForm', {note: '合成未收款开修'});
  const next = h.app.getState().data.orders.find(o => o.id === id);
  observations.cashRepair = {mode: next.quote.paymentTerms, collectedCents: D.derive(next).collectedCents,
    amountCents: next.quote.amountCents, actualStatus: next.status, currentMode: h.app.getState().dataKind};
  assert.equal(next.status, 'pending_execution', '未核实全款却进入 ' + next.status);
});
check('D03', '已登记但未核实的全额现金不能开始现款维修', () => {
  const {data, o} = orderFixture();
  o.quote.paymentTerms = 'cash';
  o.cash = [{id: 'synthetic-pending', amountCents: 10000, kind: 'receipt', verified: false, handedOver: false}];
  assert.throws(() => apply(o, 'start', {note: '合成'}, 'engineer', data), /款|核实/);
});
check('D04', '明确预付款未核实仍被拒绝（正对照）', () => {
  const {data, o} = orderFixture();
  o.quote.prepayCents = 100;
  assert.throws(() => apply(o, 'start', {note: '合成'}, 'engineer', data), /预付|核实/);
});
for (const action of ['start', 'stock_ready', 'deliver', 'accept']) {
  check('D05-' + action, '未解决异议不能推进 ' + action, () => {
    const {data, o} = orderFixture();
    o.issues = [{id: 'synthetic-issue', title: '合成尚未协商解决', resolved: false}];
    const settings = {
      start: ['pending_execution', 'engineer', {note: '合成开修'}],
      stock_ready: ['pending_execution', 'warehouse', {partId: data.parts[0].id, quantity: 1}],
      deliver: ['pending_delivery', 'warehouse', {deliveredAt: new Date().toISOString(), note: '合成签收'}],
      accept: ['pending_acceptance', 'customer', {signature: 'synthetic-demo-only', passed: true, note: '合成验收'}],
    };
    const [status, role, payload] = settings[action];
    o.status = status;
    if (action === 'stock_ready') o.type = 'sale';
    const stock = data.parts[0].available;
    assert.throws(() => apply(o, action, payload, role, data), /异议|协商|解决/);
    assert.equal(data.parts[0].available, stock);
  });
}
check('D06', '已过期报价不能审核发送', () => {
  const {data, o} = orderFixture();
  o.status = 'diagnosis_quotation';
  o.quote.signed = false;
  o.quote.approved = false;
  o.quote.validUntil = '2000-01-01T15:59:59Z';
  assert.throws(() => apply(o, 'approve_quote', {note: '合成审核'}, 'admin', data), /期限|过期|报价/);
});
check('D07', '已审核但过期报价不能由客户签署', () => {
  const {data, o} = orderFixture();
  o.status = 'pending_customer_confirmation';
  o.quote.signed = false;
  o.quote.validUntil = '2000-01-01T15:59:59Z';
  assert.throws(() => apply(o, 'sign_quote', {signature: 'synthetic-demo-only', quoteVersion: o.quote.version}, 'customer', data), /期限|过期|报价/);
});
check('D08', '旧报价版本签署被拒绝（正对照）', () => {
  const {data, o} = orderFixture();
  o.status = 'pending_customer_confirmation';
  assert.throws(() => apply(o, 'sign_quote', {signature: 'synthetic-demo-only', quoteVersion: o.quote.version - 1}, 'customer', data), /报价版本/);
});
check('D09', '未结算提成阻止整单完结（实际 app 动作）', async () => {
  const h = await demoHarness();
  const id = 'demo-003';
  await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), 'commission',
    {person: '合成提成人员', amountCents: 100, note: '合成批准依据'});
  const o = h.app.getState().data.orders.find(o => o.id === id);
  assert.equal(o.commissions[0].settled, false);
  await h.app.mutateOrder(o, 'complete', {note: '合成未结算提成完结测试'});
  const completed = h.app.getState().data.orders.find(o => o.id === id);
  observations.unsettledCommission = {beforeCompletion: o.status, afterCompletion: completed.status,
    commission: completed.commissions[0], missing: Array.from(completed.summary.missing)};
  assert.equal(o.status, 'settling', '提成待结算但主阶段为 ' + o.status);
  assert.ok(o.summary.missing.some(s => /提成/.test(s)));
});
check('D10', '结算提成后允许完结（正对照）', () => {
  const data = D.seed();
  let o = apply(data.orders[2], 'commission', {person: '合成人员', amountCents: 100, note: '合成'}, 'admin', data);
  o = apply(o, 'settle_commission', {commissionId: o.commissions[0].id, note: '合成凭据'}, 'finance', data);
  assert.equal(apply(o, 'complete', {note: '合成核对'}, 'dispatcher', data).status, 'completed');
});
check('D11', '重开必须停留结算并保留未完成复核事项（实际 app 表单）', async () => {
  const h = await demoHarness();
  const id = 'demo-003';
  await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), 'complete', {note: '合成核对'});
  await h.app.showAction('reopen', id);
  await h.submit('actionForm', {reason: '合成付款凭证需要重新核查'});
  const o = h.app.getState().data.orders.find(o => o.id === id);
  observations.reopen = {actualStatus: o.status, obligations: o.obligations, available: h.app.available(o)};
  assert.equal(o.status, 'settling', '重开后立即回到 ' + o.status);
  assert.ok(o.obligations.some(t => !t.resolved && /重开|复核/.test(t.title)));
});
check('D12', '新返修单不能继承已完结旧单应收（实际 app 完整新单链）', async () => {
  const h = await demoHarness();
  const id = await completedFreshRepair(h);
  const original = h.app.getState().data.orders.find(o => o.id === id);
  await h.app.showAction('rework', id);
  await h.submit('actionForm', {free: 'true', note: '合成免费返修'});
  const child = h.app.getState().data.orders.find(o => o.originalOrderId === id);
  observations.reworkFinancial = {original: {status: original.status, receivableCents: original.receivableCents,
    collectedCents: D.derive(original).collectedCents}, child: {status: child.status, quoteAmountCents: child.quote.amountCents,
    receivableCents: child.receivableCents, cashCount: child.cash.length, cachedSummary: child.summary,
    recalculatedSummary: D.derive(child), warranty: child.warranty}};
  assert.equal(child.quote.amountCents, 0);
  assert.equal(D.derive(child).receivableCents, 0, '子单重新待受理但应收仍为 ' + D.derive(child).receivableCents);
});
check('D13', '未验收返修单不能继承旧质保与旧外包流向（实际 app 表单）', async () => {
  const h = await demoHarness();
  const id = 'demo-003';
  await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), 'outsource',
    {provider: '合成旧单外包机构', contact: '合成联系人', destination: '合成旧流向', note: '原单事实'});
  await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === id), 'complete', {note: '合成核对'});
  await h.app.showAction('rework', id);
  await h.submit('actionForm', {free: 'true', note: '合成免费返修'});
  const child = h.app.getState().data.orders.find(o => o.originalOrderId === id);
  assert.ok(child);
  observations.reworkCopiedFields = {status: child.status, outsource: child.outsource,
    warranty: child.warranty, warrantyLabel: D.derive(child).warrantyLabel};
  assert.equal(child.status, 'pending_intake');
  assert.equal(child.outsource.length, 0, '新子单继承旧外包');
  assert.equal(D.derive(child).warrantyLabel, '质保未起算');
});
check('D14', '部分独立跟踪只解除对应数量的工单阻塞（实际 app 全局表单）', async () => {
  const h = await demoHarness();
  await globalSubmit(h, 'loan', '', '', {partId: 'demo-part-1', quantity: '2', orderId: 'demo-003',
    borrowerId: 'engineer', dueAt: '2099-01-01', note: '合成部分转出借用'});
  const loan = h.app.getState().data.loans.find(l => l.id !== 'demo-loan-1');
  assert.equal(loan.outstanding, 2);
  await globalSubmit(h, 'loanAction', loan.id, 'transfer', {quantity: '1', reason: '合成部分转独立跟踪', ownerId: 'engineer', dueAt: '2099-01-01'});
  const state = h.app.getState().data;
  const next = state.loans.find(l => l.id === loan.id);
  observations.partialTransfer = {quantity: next.quantity, outstanding: next.outstanding,
    transferred: next.transferred, transfer: next.transfer,
    blocked: D.derive(state.orders.find(o => o.id === next.orderId), state.loans).missing.includes('关联借用配件未清')};
  assert.equal(next.outstanding, 2);
  assert.ok(D.derive(state.orders.find(o => o.id === next.orderId), state.loans).missing.includes('关联借用配件未清'),
    '仅转 1/2 件后全部关联借用阻塞被解除');
});
check('D15', '最后关联借用归还后主阶段同步到待完结（真实 app 全局表单）', async () => {
  const h = await demoHarness();
  // Synthetic boundary fixture: acceptance-ready order with the seed outstanding loan.
  const demo = h.app.getDemo();
  const source = demo.orders.find(o => o.id === 'demo-004');
  source.status = 'pending_acceptance';
  source.documents.requirement = 'none';
  source.invoiceRequirement = 'none';
  source.cash = [{id: 'synthetic-paid', amountCents: source.quote.amountCents, kind: 'receipt', verified: true, handedOver: true}];
  h.app.openDemo('customer');
  await h.app.mutateOrder(h.app.getState().data.orders.find(o => o.id === source.id), 'accept',
    {passed: true, signature: 'synthetic-demo-only', note: '合成客户验收'});
  h.app.openDemo('admin');
  let o = h.app.getState().data.orders.find(o => o.id === source.id);
  assert.equal(o.status, 'settling');
  assert.deepEqual(Array.from(o.summary.missing), ['关联借用配件未清']);
  const loan = h.app.getState().data.loans.find(l => l.orderId === source.id);
  await globalSubmit(h, 'loanAction', loan.id, 'return', {quantity: String(loan.outstanding), condition: 'good'});
  o = h.app.getState().data.orders.find(o => o.id === source.id);
  observations.loanClearedStage = {status: o.status, missing: Array.from(o.summary.missing),
    available: h.app.available(o), outstanding: h.app.getState().data.loans.find(l => l.id === loan.id).outstanding};
  assert.equal(o.summary.missing.length, 0);
  assert.equal(o.status, 'pending_completion', '缺项已清而主阶段仍为 ' + o.status);
  assert.ok(h.app.available(o).includes('complete'));
});
check('D16', '采购分批收货库存守恒（正对照）', async () => {
  const h = await demoHarness();
  h.app.globalForm('purchase');
  h.context.document.querySelectorAll = selector => selector === '#actionForm [data-integer]'
    ? [{name: 'quantity', value: '3'}] : selector === '#actionForm [data-cents]'
      ? [{name: 'unitCents', value: '5.00', hasAttribute: () => true}] : [];
  await h.submit('actionForm', {supplier: '合成供应商', partId: 'demo-part-1', quantity: '3', unitCents: '5.00', note: '合成采购'});
  const purchase = h.app.getState().data.purchases[0];
  const before = h.app.getState().data.parts.find(p => p.id === purchase.partId).available;
  await globalSubmit(h, 'purchaseReceive', purchase.id, '', {quantity: '1', note: '合成实收'});
  const state = h.app.getState().data;
  assert.equal(state.purchases[0].received, purchase.received + 1);
  assert.equal(state.parts.find(p => p.id === purchase.partId).available, before + 1);
});
check('D17', '采购超收失败不改变库存或采购版本（正对照）', async () => {
  const h = await demoHarness();
  h.app.globalForm('purchase');
  h.context.document.querySelectorAll = selector => selector === '#actionForm [data-integer]'
    ? [{name: 'quantity', value: '3'}] : selector === '#actionForm [data-cents]'
      ? [{name: 'unitCents', value: '5.00', hasAttribute: () => true}] : [];
  await h.submit('actionForm', {supplier: '合成供应商', partId: 'demo-part-1', quantity: '3', unitCents: '5.00', note: '合成采购'});
  const purchase = h.app.getState().data.purchases[0];
  const before = JSON.stringify(h.app.getState().data);
  await globalSubmit(h, 'purchaseReceive', purchase.id, '', {quantity: String(purchase.quantity + 1), note: '合成超收'});
  assert.equal(JSON.stringify(h.app.getState().data), before);
  assert.equal(h.node('#formDialog').open, true);
  assert.match(h.node('#formError').textContent, /超过/);
});
check('D18', '完好归还借用保持数量守恒并增加可用库存（正对照）', async () => {
  const h = await demoHarness();
  const loan = h.app.getState().data.loans[0];
  const before = h.app.getState().data.parts.find(p => p.id === loan.partId).available;
  await globalSubmit(h, 'loanAction', loan.id, 'return', {quantity: '1', condition: 'good'});
  const state = h.app.getState().data;
  const next = state.loans[0];
  assert.equal(next.quantity, next.returnedGood + next.returnedQuarantine + next.consumed + next.disposed + next.outstanding);
  assert.equal(next.outstanding, loan.outstanding - 1);
  assert.equal(state.parts.find(p => p.id === loan.partId).available, before + 1);
});
check('D19', '自然月质保闰年与月末夹取（正对照）', () => {
  assert.equal(D.addMonths('2024-01-31T02:00:00Z', 1), '2024-02-29T02:00:00.000Z');
  assert.equal(D.addMonths('2026-01-30T18:00:00Z', 1), '2026-02-27T18:00:00.000Z');
});
for (const end of ['2027-01-12', '2027-01-12T02:00:00.000Z']) {
  check('D20-' + (end.length === 10 ? 'seed-date' : 'accepted-iso'), '质保截止日 20 点仍有效：' + end, () => {
    const data = D.seed();
    const o = data.orders[2];
    o.warranty = {startsAt: '2026-10-12T02:00:00Z', endsAt: end};
    const realNow = Date.now;
    try {
      Date.now = () => Date.parse('2027-01-12T12:00:00+00:00');
      observations['warranty-' + end] = {end, now: '2027-01-12T20:00:00+08:00', actual: D.derive(o).warrantyLabel,
        expected: '质保中', requirement: 'PRD V3.8 line 1832: 截止日当日仍在质保内，次日过期'};
      assert.equal(D.derive(o).warrantyLabel, '质保中');
    } finally { Date.now = realNow; }
  });
}

(async () => {
  for (const [index, item] of checks.entries()) {
    try {
      await item.fn();
      rows.push({id: item.id, title: item.title, passed: true});
      console.log('ok ' + (index + 1) + ' - ' + item.id + ' ' + item.title);
    } catch (error) {
      rows.push({id: item.id, title: item.title, passed: false, message: error.message, expected: error.expected, actual: error.actual, stack: error.stack});
      console.log('not ok ' + (index + 1) + ' - ' + item.id + ' ' + item.title + '\n  ' + error.message);
    }
  }
  const hash = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
  const report = {date: '2026-10-15', scope: 'external synthetic demo business regression; no product writes', tests: rows.length,
    pass: rows.filter(r => r.passed).length, fail: rows.filter(r => !r.passed).length, skip: 0,
    source: {'Workspace/data.js': hash('Workspace/data.js'), 'Workspace/app.js': hash('Workspace/app.js')},
    fixtures: 'All data are synthetic D.seed, plus one explicitly declared acceptance-ready boundary fixture in D15; actual app loaded through VM harness.',
    cleanup: 'No services, containers, temp directories, real data or credentials created; VM and test inputs exist only in the terminating Node process.', observations, rows};
  fs.writeFileSync(path.join(output, 'demo-results.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({tests: report.tests, pass: report.pass, fail: report.fail, skip: report.skip}));
  process.exitCode = report.fail ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 2; });
