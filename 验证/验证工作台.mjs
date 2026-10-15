#!/usr/bin/env node
// 自述：构建 V3.8 独立后端，用临时回环端口及合成数据验证 HTTP 业务，不连接现有实例。
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { existsSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const password = 'Demo-Repair-2026!';
let tempDir;
let child;
let origin;
let serverOutput = '';
let passed = 0;

// 发现已有且健康的 Go，不执行安装或更新。
function findGo() {
  const candidates = process.env.GO_BIN
    ? [path.isAbsolute(process.env.GO_BIN) ? process.env.GO_BIN : path.resolve(root, process.env.GO_BIN)]
    : ['go', path.join(root, 'Tools', 'go', 'bin', process.platform === 'win32' ? 'go.exe' : 'go')];
  for (const candidate of candidates) {
    const result = spawnSync(candidate, ['version'], { encoding: 'utf8' });
    if (result.status === 0) return candidate;
  }
  throw new Error('没有可用 Go，请设置 GO_BIN 或准备项目 Tools/go。');
}

// 为当前检查保留一个临时回环端口。
async function freePort() {
  const listener = net.createServer();
  listener.listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const port = listener.address().port;
  await new Promise((resolve, reject) => listener.close(error => error ? reject(error) : resolve()));
  return port;
}

// 运行构建命令并在失败时附带输出。
async function run(command, args, options) {
  const processChild = spawn(command, args, { ...options, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  processChild.stdout.on('data', value => { output += value; });
  processChild.stderr.on('data', value => { output += value; });
  const completion = await new Promise((resolve, reject) => {
    processChild.once('error', reject);
    processChild.once('close', code => resolve(code));
  });
  assert.equal(completion, 0, `${command} ${args.join(' ')} 失败\n${output}`);
}

// 发送真实 HTTP 请求，对响应码及 JSON 解析同时断言。
async function request(endpoint, { method = 'GET', token, body, key, status = 200 } = {}) {
  const response = await fetch(`${origin}/api/v38${endpoint}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(method !== 'GET' ? { 'Idempotency-Key': key || crypto.randomUUID() } : {})
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(6000)
  });
  const content = await response.text();
  assert.equal(response.status, status, `${method} ${endpoint}: ${response.status} ${content}`);
  if (!content) return null;
  return JSON.parse(content);
}

// 只登录合成角色，权限由服务端身份决定。
async function login(username) {
  const response = await request('/login', { method: 'POST', body: { username, password } });
  assert.ok(response.token, `${username} 登录缺少 token`);
  return response.token;
}

// 计算 PNG 块校验，构造有真实笔画的合成签名测试文件。
function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let index = 0; index < 8; index += 1) {
      crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

// 输出合成 PNG，不使用客户真实签名。
function signature() {
  const width = 128;
  const height = 64;
  const raw = Buffer.alloc(height * (1 + width * 4), 255);
  for (let y = 0; y < height; y += 1) {
    raw[y * (1 + width * 4)] = 0;
    for (let x = 12; x < 112; x += 1) {
      if (Math.abs(y - (20 + Math.sin(x / 9) * 10 + x / 6)) > 2) continue;
      const offset = y * (1 + width * 4) + 1 + x * 4;
      raw[offset] = 0;
      raw[offset + 1] = 0;
      raw[offset + 2] = 0;
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
  const chunk = (type, data) => {
    const name = Buffer.from(type);
    const size = Buffer.alloc(4);
    size.writeUInt32BE(data.length);
    const checksum = Buffer.alloc(4);
    checksum.writeUInt32BE(crc32(Buffer.concat([name, data])));
    return Buffer.concat([size, name, data, checksum]);
  };
  return 'data:image/png;base64,' + Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))
  ]).toString('base64');
}

// 记录独立通过的断言组，不将检查组数解释成 PRD 验收项数。
function pass(description) {
  passed += 1;
  console.log(`✔ ${description}`);
}

// 等待本次子进程的健康接口，不接受外部服务地址。
async function waitHealthy() {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    if (child.exitCode !== null) throw new Error(`临时后端提前退出\n${serverOutput}`);
    try {
      await request('/healthz');
      return;
    } catch {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }
  throw new Error(`临时后端未就绪\n${serverOutput}`);
}

// 验证登录、授权、销售整单结算及库存借还等核心 HTTP 合同。
async function smoke() {
  await request('/orders', { status: 401 });
  const admin = await login('admin');
  const customer = await login('customer');
  const customerB = await login('customer-b');
  const warehouse = await login('warehouse');
  const finance = await login('finance');
  await request('/session', { token: admin });
  pass('健康、账号登录与匿名访问拒绝');

  const bootstrap = await request('/bootstrap', { token: admin });
  assert.ok(bootstrap.parts.length > 0, '缺少合成配件');
  const part = bootstrap.parts.find(item => item.available >= 2);
  assert.ok(part, '缺少可用于验证的库存');
  let order = await request('/orders', {
    method: 'POST', token: admin, status: 201,
    body: { type: 'sale', customer: '合成客户', customerId: 'customer', companyId: 'company-a', project: '隔离验证', device: '测试控制板', description: '合成销售需求' }
  });
  await request(`/orders/${order.id}`, { token: customerB, status: 404 });
  await request(`/orders/${order.id}/actions`, {
    method: 'POST', token: customerB, status: 404,
    body: { type: 'remark', version: order.version, payload: { remark: '越权验证' } }
  });
  pass('新建销售单与跨企业读取、写入拒绝');

  const act = async (type, payload = {}, token = admin) => {
    order = await request(`/orders/${order.id}/actions`, {
      method: 'POST', token, body: { type, version: order.version, payload }
    });
    return order;
  };
  await act('intake', { ownerId: 'dispatcher', assigneeId: 'engineer' });
  await act('diagnose', { note: '合成销售规格核对' });
  const key = crypto.randomUUID();
  const quoteBody = { type: 'quote', version: order.version, payload: { amountCents: 12345, description: '合成报价', warrantyMonths: 3, paymentTerms: 'cash', prepayCents: 0, validUntil: '2099-12-31T23:59:00+08:00', autoAccept: false } };
  order = await request(`/orders/${order.id}/actions`, { method: 'POST', token: admin, key, body: quoteBody });
  const replay = await request(`/orders/${order.id}/actions`, { method: 'POST', token: admin, key, body: quoteBody });
  assert.equal(replay.version, order.version, '同键重试重复修改版本');
  await request(`/orders/${order.id}/actions`, {
    method: 'POST', token: admin, status: 409,
    body: { type: 'remark', version: quoteBody.version, payload: { remark: '旧版本写入' } }
  });
  await act('approve_quote', { note: '合成公司审核' });
  await request(`/orders/${order.id}/actions`, {
    method: 'POST', token: admin, status: 403,
    body: { type: 'sign_quote', version: order.version, payload: { signature: signature(), quoteVersion: order.quote.version } }
  });
  await act('sign_quote', { signature: signature(), quoteVersion: order.quote.version }, customer);
  pass('报价审核、客户签署、版本冲突和同键幂等');

  await request(`/orders/${order.id}/actions`, {
    method: 'POST', token: warehouse, status: 422,
    body: { type: 'stock_ready', version: order.version, payload: { partId: part.id, quantity: 1 } }
  });
  await act('cash', { amountCents: 12345, kind: 'receipt', purpose: '合成销售现款', receipt: 'SAMPLE-CASH', occurredAt: new Date().toISOString() }, finance);
  const cashId = order.cash.at(-1).id;
  await act('verify_cash', { cashId }, finance);
  await act('stock_ready', { partId: part.id, quantity: 1 }, warehouse);
  await act('dispatch', { carrier: '人工交付', tracking: 'SYNTHETIC-ONLY', note: '合成送货' }, warehouse);
  await act('deliver', { note: '合成客户签收', deliveredAt: new Date().toISOString() });
  await act('accept', { signature: signature(), passed: true, note: '合成验收' }, customer);
  await act('requirements', { documentRequirement: 'none', documentReason: '合成样例无需资料', invoiceRequirement: 'required', invoiceReason: '合成样例检查发票附件', invoiceDueCents: 12345 });
  await act('evidence', { name: '合成发票样例.png', kind: 'image', mime: 'image/png', data: signature().split(',')[1] });
  const invoiceEvidence = order.evidence.at(-1);
  await request(`/orders/${order.id}/evidence/${invoiceEvidence.id}`, { token: customerB, status: 404 });
  await act('invoice', { number: 'SAMPLE-INVOICE', amountCents: 12345, files: [invoiceEvidence.id] }, finance);
  await request(`/orders/${order.id}/actions`, {
    method: 'POST', token: admin, status: 422,
    body: { type: 'complete', version: order.version, payload: { note: '现金未交接不能完结' } }
  });
  await act('handover_cash', { cashId }, finance);
  assert.equal(order.summary.remainingCents, 0, '核实款项未覆盖应收');
  await act('complete', { note: '合成整单核对完成' });
  pass('销售交付、独立验收、现金核实交接与完结门槛');

  const beforeLoans = await request('/bootstrap', { token: admin });
  const available = beforeLoans.parts.find(item => item.id === part.id).available;
  const loanOrder = await request('/orders', {
    method: 'POST', token: admin, status: 201,
    body: { type: 'mail', customer: '合成借还客户', customerId: 'customer', companyId: 'company-a', project: '隔离库存验证', device: '测试设备', description: '合成借用需求' }
  });
  const loan = await request('/loans', {
    method: 'POST', token: warehouse, status: 201,
    body: { orderId: loanOrder.id, partId: part.id, quantity: 1, borrowerId: 'engineer', dueAt: '2099-12-31T23:59:00+08:00', note: '合成借还' }
  });
  const returned = await request(`/loans/${loan.id}/actions`, {
    method: 'POST', token: warehouse,
    body: { type: 'return', version: loan.version, payload: { quantity: 1, condition: 'good' } }
  });
  assert.equal(returned.outstanding, 0, '归还后借用未清零');
  const afterLoans = await request('/bootstrap', { token: admin });
  assert.equal(afterLoans.parts.find(item => item.id === part.id).available, available, '借还导致可用库存漂移');
  pass('借用归还和可用库存守恒');

  await request('/logout', { method: 'POST', token: customer });
  await request('/session', { token: customer, status: 401 });
  pass('退出后旧会话撤销');
}

// 停止仅由本次检查创建的进程，再清理其临时构建与合成数据。
async function cleanup() {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM');
    await Promise.race([once(child, 'close'), new Promise(resolve => setTimeout(resolve, 1800))]);
    if (child.exitCode === null) {
      child.kill('SIGKILL');
      await once(child, 'close');
    }
  }
  if (tempDir) await rm(tempDir, { recursive: true, force: true });
}

// 编排独立构建、临时启动和 HTTP 检查，并传播真实退出码。
async function main() {
  console.log('V3.8 工作台验证：临时回环服务、独立合成数据；不连接现有实例，不部署。');
  try {
    const go = findGo();
    assert.ok(existsSync(path.join(root, '前端', 'Web网页', '维修工作台', 'index.html')), '前端/Web网页/维修工作台/index.html 尚未完成');
    tempDir = await mkdtemp(path.join(os.tmpdir(), 'repair-v38-smoke-'));
    const binary = path.join(tempDir, process.platform === 'win32' ? 'workbench.exe' : 'workbench');
    await run(go, ['build', '-o', binary, './cmd/workbench'], { cwd: path.join(root, '后端', 'Go服务端') });
    const port = await freePort();
    origin = `http://127.0.0.1:${port}`;
    child = spawn(binary, [], {
      cwd: path.join(root, '后端', 'Go服务端'),
      env: { ...process.env, WB_ADDR: `127.0.0.1:${port}`, WB_DATA_DIR: path.join(tempDir, 'data'), WB_KEY_FILE: path.join(tempDir, 'keys', 'storage.key'), WB_WEB_DIR: path.join(root, '前端', 'Web网页', '维修工作台'), WB_TIDB_DSN: '', WB_BACKUP_DIR: '' },
      stdio: ['ignore', 'pipe', 'pipe']
    });
    child.stdout.on('data', value => { serverOutput += value; });
    child.stderr.on('data', value => { serverOutput += value; });
    child.on('error', error => { serverOutput += error.message; });
    await waitHealthy();
    await smoke();
    console.log(`验证完成：${passed} 组通过。此结果仅覆盖脚本列出的合同，不代表 PRD 全部验收。`);
  } catch (error) {
    console.error(`✖ ${error.stack || error.message}`);
    if (serverOutput.trim()) console.error(serverOutput.trim());
    process.exitCode = 1;
  } finally {
    await cleanup();
  }
}

process.on('SIGINT', async () => { process.exitCode = 130; await cleanup(); process.exit(130); });
process.on('SIGTERM', async () => { process.exitCode = 143; await cleanup(); process.exit(143); });
await main();
