// Run with Node.js 24+; this executes shared data code, not an ArkUI/HAP compiler.
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../代码/前端/移动端/鸿蒙');
const temp = await mkdtemp(path.join(tmpdir(), 'repair-harmony-regression-'));
const cases = [];
const test = (name, run) => cases.push({ name, run });
let failed = 0;
try {
  for (const name of ['Models', 'ActionCatalog', 'DemoLedger', 'WorkbenchStore']) {
    const source = await readFile(path.join(root, 'entry/src/main/ets/core', name + '.ets'), 'utf8');
    const portable = source.replace(/from '(\.\/[^']+)'/g, "from '$1.ts'");
    await writeFile(path.join(temp, name + '.ts'), portable);
  }
  const models = await import(pathToFileURL(path.join(temp, 'Models.ts')).href);
  const catalog = await import(pathToFileURL(path.join(temp, 'ActionCatalog.ts')).href);
  const { DemoLedger } = await import(pathToFileURL(path.join(temp, 'DemoLedger.ts')).href);
  const { WorkbenchStore } = await import(pathToFileURL(path.join(temp, 'WorkbenchStore.ts')).href);
  const clone = value => JSON.parse(JSON.stringify(value));

  class FakeTransport {
    constructor() {
      this.data = new DemoLedger('admin').snapshot;
      this.data.actor.id = 'server-admin';
      this.calls = [];
      this.actionMode = 'normal';
      this.bootstrapMode = 'normal';
      this.nextError = null;
    }
    async send(base, endpoint, method, body, token, key, timeout) {
      this.calls.push({ base, endpoint, method, body, token, key, timeout });
      if (this.nextError) {
        const error = this.nextError;
        this.nextError = null;
        throw error;
      }
      if (endpoint === '/healthz' || endpoint === '/logout') return '{}';
      if (endpoint === '/login') return JSON.stringify({ token: 'synthetic-token', actor: this.data.actor });
      if (endpoint === '/bootstrap') {
        if (this.bootstrapMode === 'offline') throw new models.ClientError('offline');
        const data = clone(this.data);
        if (this.bootstrapMode === 'wrongActor') data.actor.id = 'other';
        return JSON.stringify(data);
      }
      if (endpoint.startsWith('/orders?')) return JSON.stringify({ items: this.data.orders, total: 1, page: 1, pageSize: 30, totalPages: 1 });
      if (method === 'POST' && endpoint.endsWith('/actions')) {
        const input = JSON.parse(body);
        if (this.actionMode === 'uncertain') {
          this.actionMode = 'normal';
          throw new models.ClientError('timeout', 0, true);
        }
        if (this.actionMode === 'invalidJSON') return '{broken';
        const order = clone(this.data.orders[0]);
        order.version += this.actionMode === 'stale' ? 0 : 3;
        if (input.type === 'rework') {
          order.originalOrderId = this.data.orders[0].id;
          order.id = 'server-child';
          order.version = 1;
        }
        return JSON.stringify(order);
      }
      if (endpoint.startsWith('/orders/')) return JSON.stringify(this.data.orders[0]);
      if (endpoint === '/loans') return JSON.stringify({ id: 'shallow', version: 1 });
      throw new models.ClientError('unknown test endpoint ' + endpoint, 404);
    }
  }
  const session = async () => {
    const transport = new FakeTransport();
    const store = new WorkbenchStore(transport);
    await store.login('admin', 'synthetic');
    return { store, transport, order: clone(transport.data.orders[0]) };
  };

  test('三种演示身份均可独立进入且无真实资料', () => {
    for (const role of ['customer', 'engineer', 'admin']) {
      const ledger = new DemoLedger(role);
      assert.equal(ledger.snapshot.actor.role, role);
      assert.equal(ledger.snapshot.orders.length, 1);
      assert.ok(ledger.snapshot.orders[0].id.startsWith('demo-'));
      models.validateOrder(ledger.snapshot.orders[0], true);
    }
  });
  test('工程师不能越权录单', () => assert.throws(() => new DemoLedger('engineer').create({ device: 'x', customer: 'x', description: 'x' }), /不能新建/));
  test('演示录单与版本推进', () => {
    const ledger = new DemoLedger('admin');
    const order = ledger.snapshot.orders[0];
    const result = ledger.apply(order.id, 'intake', 1, { ownerId: 'demo-admin', assigneeId: 'demo-engineer' });
    assert.equal(result.version, 2);
    assert.equal(result.status, 'pending_arrangement');
    assert.throws(() => ledger.apply(order.id, 'intake', 1, {}), /阶段或版本/);
  });
  test('演示完成单不能再增加异议', () => {
    const ledger = new DemoLedger('customer');
    const order = ledger.snapshot.orders[0];
    order.status = 'completed';
    assert.throws(() => ledger.apply(order.id, 'issue', order.version, { note: 'x' }), /阶段或版本/);
  });
  test('金额按十进制分精确转换', () => {
    assert.equal(catalog.collectPayload([new catalog.Field('amountCents', '金额', 'money', '0.29')], 'quote').amountCents, 29);
    for (const invalid of ['NaN', '-1', '1.001', '1e3', 'Infinity']) {
      assert.throws(() => catalog.collectPayload([new catalog.Field('amountCents', '金额', 'money', invalid)], 'cash'));
    }
  });
  test('现金不接受零元', () => assert.throws(() => catalog.collectPayload([new catalog.Field('amountCents', '金额', 'money', '0')], 'cash')));
  test('报价无先款约定也拒绝超额预付', () => {
    const fields = catalog.fieldsFor('quote', new models.Order());
    for (const field of fields) {
      if (field.key === 'amountCents') field.value = '100';
      if (field.key === 'prepayCents') field.value = '200';
      if (field.key === 'description') field.value = '完整条款';
    }
    assert.throws(() => catalog.collectPayload(fields, 'quote'), /预付款不得超过/);
  });
  test('资料发送必须齐备且有接收对象', () => {
    const fields = catalog.fieldsFor('documents', new models.Order());
    fields.find(f => f.key === 'sent').value = 'true';
    assert.throws(() => catalog.collectPayload(fields, 'documents'), /接收对象/);
  });
  test('整数数量拒绝小数及零', () => {
    for (const value of ['0', '1.5', '-1']) assert.throws(() => catalog.collectPayload([new catalog.Field('quantity', '数量', 'integer', value)], 'loan'));
  });
  test('日期必须携带时区', () => assert.throws(() => catalog.collectPayload([new catalog.Field('dueAt', '期限', 'date', '2026-10-30')], 'issue')));
  test('摘要不能作为完整详情办理', () => {
    const order = new DemoLedger('customer').snapshot.orders[0];
    order.isSummary = true;
    assert.throws(() => models.validateOrder(order, true), /响应不完整/);
  });
  test('缺金额与非法方向的现金响应拒绝', () => {
    const order = new DemoLedger('customer').snapshot.orders[0];
    order.cash = [{ id: 'cash', amountCents: null, kind: 'receipt', verified: true, handedOver: false }];
    assert.throws(() => models.validateOrder(order, true), /现金明细/);
    order.cash[0].amountCents = 100;
    order.cash[0].kind = 'anything';
    assert.throws(() => models.validateOrder(order, true), /现金明细/);
  });
  test('浅借还响应拒绝', () => assert.throws(() => models.validateLoan({ id: 'shallow', version: 1 }), /借还响应/));
  test('借还数量守恒验证', () => {
    const loan = new models.Loan();
    Object.assign(loan, { id: 'l', partId: 'p', borrowerId: 'e', quantity: 5, outstanding: 4 });
    assert.throws(() => models.validateLoan(loan), /守恒/);
    loan.returnedGood = 1;
    models.validateLoan(loan);
  });
  test('不匹配会话身份的概览拒绝', () => {
    const data = new DemoLedger('admin').snapshot;
    const actor = clone(data.actor);
    actor.authVersion += 1;
    assert.throws(() => models.validateSnapshot(data, actor), /身份不匹配/);
  });
  test('原生表单覆盖现有43项工单动作', () => {
    const names = 'intake receive assign diagnose report quote approve_quote sign_quote start finish qc stock_ready dispatch deliver accept requirements documents cash verify_cash handover_cash invoice void_invoice adjust_receivable remark evidence delete_evidence issue resolve_issue failure obligation resolve_obligation visit start_visit outsource cost approve_cost commission settle_commission complete reopen rework review_acceptance handover_contact'.split(' ');
    for (const name of names) {
      assert.notEqual(catalog.actionTitle(name), name);
      assert.ok(Array.isArray(catalog.fieldsFor(name, new models.Order())));
    }
  });
  test('服务地址规范化与非法源拒绝', () => {
    assert.equal(models.normalizeBase(' http://127.0.0.1:8098/api/v38/ '), 'http://127.0.0.1:8098');
    for (const value of ['javascript:alert(1)', 'https://user:pass@example.com', 'https://example.com/path', 'https://example.com?q=1', 'http://example.com:abc']) assert.throws(() => models.normalizeBase(value));
  });
  test('真实登录与分页详情读取', async () => {
    const { store, order } = await session();
    assert.equal(store.demo, false);
    assert.equal((await store.list('', '', 1)).total, 1);
    assert.equal((await store.detail(order.id)).id, order.id);
  });
  test('合法多版本成功响应可采用', async () => {
    const { store, order } = await session();
    const result = await store.perform(order, 'intake', { ownerId: 'a', assigneeId: 'e' });
    assert.equal(result.version, order.version + 3);
  });
  test('陈旧版本成功响应不能提示保存', async () => {
    const { store, transport, order } = await session();
    transport.actionMode = 'stale';
    await assert.rejects(store.perform(order, 'intake', {}), /上下文不匹配/);
  });
  test('未知写重试使用同一请求键', async () => {
    const { store, transport, order } = await session();
    transport.actionMode = 'uncertain';
    await assert.rejects(store.perform(order, 'intake', {}), /结果未知/);
    await store.perform(order, 'intake', {});
    const calls = transport.calls.filter(c => c.endpoint.endsWith('/actions'));
    assert.ok(calls[0].key);
    assert.equal(calls[0].key, calls[1].key);
  });
  test('未知写不得修改内容生成第二次记账', async () => {
    const { store, transport, order } = await session();
    transport.actionMode = 'uncertain';
    await assert.rejects(store.perform(order, 'intake', {}));
    await assert.rejects(store.perform(order, 'intake', { note: 'changed' }), /上次提交结果未知/);
  });
  test('坏2xx JSON不清理原请求意图', async () => {
    const { store, transport, order } = await session();
    transport.actionMode = 'invalidJSON';
    await assert.rejects(store.perform(order, 'intake', {}));
    transport.actionMode = 'normal';
    await store.perform(order, 'intake', {});
    const calls = transport.calls.filter(c => c.endpoint.endsWith('/actions'));
    assert.equal(calls[0].key, calls[1].key);
  });
  test('任一受保护401撤销旧身份和资料', async () => {
    const { store, transport, order } = await session();
    transport.nextError = new models.ClientError('expired', 401);
    await assert.rejects(store.detail(order.id));
    assert.equal(store.authenticated, false);
    assert.equal(store.snapshot.orders.length, 0);
    assert.equal(store.actor.id, '');
  });
  test('连接失败独立回退，恢复自动覆盖为真实资料', async () => {
    const { store, transport } = await session();
    transport.bootstrapMode = 'offline';
    await store.refresh();
    assert.equal(store.demo, true);
    assert.ok(store.actor.id.startsWith('demo-'));
    transport.bootstrapMode = 'normal';
    await store.refresh();
    assert.equal(store.demo, false);
    assert.equal(store.actor.id, 'server-admin');
  });
  test('会话身份错配概览进入独立演示', async () => {
    const { store, transport } = await session();
    transport.bootstrapMode = 'wrongActor';
    await store.refresh();
    assert.equal(store.demo, true);
    assert.notEqual(store.actor.id, 'other');
  });
  test('切连接清空会话与未决写', async () => {
    const { store } = await session();
    store.configure('https://example.com', 1000);
    assert.equal(store.authenticated, false);
    assert.equal(store.snapshot.orders.length, 0);
    assert.equal(store.timeout, 1000);
  });
  test('浅库存写响应不能提示保存成功', async () => {
    const { store } = await session();
    await assert.rejects(store.inventoryWrite('/loans', '{}', true), /借还响应/);
  });
  test('切连接后迟到的真实详情不得覆盖新会话', async () => {
    const { store, transport, order } = await session();
    let release;
    const original = transport.send.bind(transport);
    transport.send = async (...args) => {
      if (args[1] === '/orders/' + order.id) return await new Promise(resolve => release = resolve);
      return original(...args);
    };
    const pending = store.detail(order.id);
    store.configure('https://example.com', 1000);
    release(JSON.stringify(order));
    await assert.rejects(pending, /旧响应已丢弃/);
    assert.equal(store.snapshot.orders.length, 0);
  });
  test('返修响应必须为关联子单', async () => {
    const { store, order } = await session();
    order.allowedActions.push('rework');
    const child = await store.perform(order, 'rework', { free: true, note: '合成测试' });
    assert.notEqual(child.id, order.id);
    assert.equal(child.originalOrderId, order.id);
  });
  test('工单列表超时进入独立演示', async () => {
    const { store, transport } = await session();
    transport.nextError = new models.ClientError('timeout');
    const result = await store.list('', '', 1);
    assert.equal(store.demo, true);
    assert.equal(result.items.length, 1);
    assert.ok(result.items[0].id.startsWith('demo-'));
  });
  test('详情坏响应进入演示并要求重新选择', async () => {
    const { store, transport, order } = await session();
    transport.nextError = new models.ClientError('timeout');
    await assert.rejects(store.detail(order.id), /请从工单列表重新选择/);
    assert.equal(store.demo, true);
  });
  test('签署PNG协议头与服务端尺寸边界', () => {
    const bytes = new Uint8Array(24);
    bytes.set([137, 80, 78, 71, 13, 10, 26, 10], 0);
    bytes.set([73, 72, 68, 82], 12);
    bytes[18] = 1;
    bytes[19] = 44;
    bytes[23] = 150;
    models.validateSignaturePNG(bytes);
    bytes[18] = 7;
    assert.throws(() => models.validateSignaturePNG(bytes), /签名图像须/);
    assert.throws(() => models.validateSignaturePNG(new Uint8Array(24)), /有效 PNG/);
  });
  if (process.env.REPAIR_TEST_BASE) {
    class FetchTransport {
      async send(base, endpoint, method, body, token, key, timeout) {
        const response = await fetch(base + (endpoint === '/healthz' ? endpoint : '/api/v38' + endpoint), {
          method,
          headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(key ? { 'Idempotency-Key': key } : {}) },
          body: method === 'POST' ? body : undefined,
          signal: AbortSignal.timeout(timeout)
        });
        const text = await response.text();
        if (!response.ok) throw new models.ClientError(JSON.parse(text).message || String(response.status), response.status);
        return text;
      }
    }
    test('隔离真实Go：客户登录、分页、完整详情', async () => {
      const store = new WorkbenchStore(new FetchTransport());
      store.configure(process.env.REPAIR_TEST_BASE, 10000);
      await store.login('customer', 'Demo-Repair-2026!');
      assert.equal(store.demo, false, store.source);
      const result = await store.list('', '', 1);
      assert.ok(result.total > 0);
      const order = await store.detail(result.items[0].id);
      assert.notEqual(order.isSummary, true);
      await store.logout();
    });
    test('隔离真实Go：客户录单、归档文字与重读', async () => {
      const store = new WorkbenchStore(new FetchTransport());
      store.configure(process.env.REPAIR_TEST_BASE, 10000);
      await store.login('customer', 'Demo-Repair-2026!');
      const order = await store.create({ type: 'mail', customer: '鸿蒙隔离验证物业', project: '合同回归样例', device: '门禁电源', description: '仅用于当前隔离服务的原生客户端合同回归。', customerNote: '鸿蒙联调' });
      assert.equal(order.version, 1);
      const updated = await store.perform(order, 'evidence', { kind: 'text', name: '检测说明', text: '本条为自动化隔离回归合成事实。' });
      assert.ok(updated.version > order.version);
      const reloaded = await store.detail(order.id);
      assert.equal(reloaded.evidence.length, 1);
      await store.logout();
      await assert.rejects(store.detail(order.id));
    });
    test('隔离真实Go：工程师权限与库存快照合同', async () => {
      const store = new WorkbenchStore(new FetchTransport());
      store.configure(process.env.REPAIR_TEST_BASE, 10000);
      await store.login('engineer', 'Demo-Repair-2026!');
      assert.equal(store.demo, false, store.source);
      assert.equal(store.actor.role, 'engineer');
      const result = await store.list('', '', 1);
      assert.ok(Array.isArray(result.items));
      await store.logout();
    });
  }
  for (const item of cases) {
    try {
      await item.run();
      console.log('PASS ' + item.name);
    } catch (error) {
      failed += 1;
      console.error('FAIL ' + item.name + '\n' + error.stack);
    }
  }
  console.log(JSON.stringify({ suite: 'HarmonyOS portable core contract', passed: cases.length - failed, failed, total: cases.length, arkuiCompiled: false }));
} finally {
  await rm(temp, { recursive: true, force: true });
}
process.exitCode = failed ? 1 : 0;
