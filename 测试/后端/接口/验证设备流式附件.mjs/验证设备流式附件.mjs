#!/usr/bin/env node
// 自述：只构建临时后端，用合成媒体验证流式设备附件；不连接已有服务，不安装SDK。
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createReadStream } from 'node:fs';
import { appendFile, mkdtemp, open, readFile, rm } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import net from 'node:net';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const work = await mkdtemp(path.join(os.tmpdir(), 'repair-stream-http-'));
let child;
let serverLog = '';
let origin;
let passed = 0;
const go = process.env.GO_BIN || 'go';
const binary = process.env.WB_STREAM_TEST_BINARY || path.join(work, process.platform === 'win32' ? 'workbench.exe' : 'workbench');
const runtime = path.join(work, 'runtime');
function check(name) { passed++; console.log('PASS ' + name); }
async function run(command, args, options = {}) {
  const task = spawn(command, args, { ...options, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  task.stdout.on('data', value => { output += value; });
  task.stderr.on('data', value => { output += value; });
  const code = await new Promise((resolve, reject) => { task.once('error', reject); task.once('close', resolve); });
  assert.equal(code, 0, output.slice(-5000));
}
async function freePort() {
  const listener = net.createServer().listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const port = listener.address().port;
  await new Promise(resolve => listener.close(resolve));
  return port;
}
async function start() {
  origin = 'http://127.0.0.1:' + await freePort();
  serverLog = '';
  child = spawn(binary, [], {
    env: { ...process.env, WB_ADDR: origin.slice(7), WB_RUNTIME_DIR: runtime, WB_DATA_DIR: path.join(runtime, 'data'), WB_KEY_FILE: path.join(runtime, 'keys', 'storage.key'), WB_PROJECT_ROOT: root, WB_TIDB_DSN: '', WB_BACKUP_DIR: '', WB_ORDER_MEDIA_DIR: '' },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.on('data', value => { serverLog += value; });
  child.stderr.on('data', value => { serverLog += value; });
  for (let n = 0; n < 200; n++) {
    if (child.exitCode !== null) throw new Error(serverLog);
    try { if ((await fetch(origin + '/api/v38/healthz')).ok) return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error('测试后端未就绪：' + serverLog);
}
async function stop() {
  if (!child || child.exitCode !== null) return;
  const task = child;
  task.kill('SIGTERM');
  await once(task, 'close');
  child = null;
}
async function request(route, { token, method = 'GET', body, status = 200, key = randomUUID() } = {}) {
  const response = await fetch(origin + '/api/v38' + route, {
    method, headers: { ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}), ...(method !== 'GET' ? { 'Idempotency-Key': key } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(15000)
  });
  const text = await response.text();
  assert.equal(response.status, status, route + ': ' + text.slice(0, 1000));
  return text ? JSON.parse(text) : null;
}
async function login(name) {
  const result = await request('/login', { method: 'POST', body: { username: name, password: name === 'admin' ? '1234' : 'Demo-Repair-2026!' } });
  assert.ok(result.token); return result.token;
}
async function hashFile(file) {
  const hash = createHash('sha256'); for await (const data of createReadStream(file)) hash.update(data); return hash.digest('hex');
}
async function upload(token, file, name, mime, key = randomUUID(), status = 201) {
  const response = await fetch(origin + '/api/v38/order-uploads', { method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Idempotency-Key': key, 'Content-Type': mime, 'X-File-Name': encodeURIComponent(name) }, body: createReadStream(file), duplex: 'half', signal: AbortSignal.timeout(120000) });
  const result = await response.json();
  assert.equal(response.status, status, JSON.stringify(result));
  if (status === 201) {
    assert.deepEqual(Object.keys(result).sort(), ['id', 'mime', 'name', 'sha256', 'size']);
    assert.equal(result.sha256, await hashFile(file));
  }
  return result;
}
const order = files => ({ type: 'mail', customer: '流式附件合成客户', customerId: 'customer', companyId: 'company-a', project: '独立设备媒体验证', device: '合成控制板', description: '只使用临时生成的媒体，不是真实业务', files });
const reference = receipt => ({ uploadId: receipt.id, name: receipt.name, mime: receipt.mime, size: receipt.size, sha256: receipt.sha256 });
try {
  console.log('设备媒体流式专项：仅临时回环实例与合成媒体，结束停止本次服务。');
  if (!process.env.WB_STREAM_TEST_BINARY) await run(go, ['build', '-o', binary, './cmd/workbench'], { cwd: path.join(root, '代码/后端/后端代码') });
  const movie = path.join(work, 'large-demo.mp4');
  await run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=green:s=96x64:d=1', '-c:v', 'mpeg4', '-y', movie]);
  // ISO-BMFF free盒保留真实可播放短片，并将原件扩到旧大小上限之上。
  const padding = 48 * 1024 * 1024;
  const box = Buffer.alloc(8); box.writeUInt32BE(padding + 8); box.write('free', 4);
  await appendFile(movie, box);
  const handle = await open(movie, 'a');
  const block = Buffer.alloc(65536);
  for (let remaining = padding; remaining > 0; remaining -= block.length) await handle.write(block.subarray(0, Math.min(block.length, remaining)));
  await handle.close();
  await start();
  let admin = await login('admin');
  const dispatcher = await login('dispatcher');
  const anonymous = await fetch(origin + '/api/v38/order-uploads', { method: 'POST', headers: { 'Content-Type': 'video/mp4', 'X-File-Name': 'anonymous.mp4', 'Idempotency-Key': randomUUID() }, body: Buffer.from('bad') });
  assert.equal(anonymous.status, 401); check('未认证上传拒绝');
  const key = randomUUID();
  const large = await upload(admin, movie, '设备 大视频.mp4', 'video/mp4', key);
  assert.ok(large.size > 32 * 1024 * 1024); check('真实可播放视频超过旧16MiB／32MiB限制流式上传');
  assert.deepEqual(await upload(admin, movie, large.name, large.mime, key), large); check('同键同原件重试返回同一凭据');
  const png = path.join(root, '代码/前端/PC端/原生共享契约/Assets/LoanBorrow.png');
  await upload(admin, png, 'different.png', 'image/png', key, 409); check('同键不同原件拒绝');
  await request('/orders', { token: dispatcher, method: 'POST', body: order([reference(large)]), status: 404 }); check('不同账号不能绑定临时原件');
  await request('/orders', { token: admin, method: 'POST', body: order([{ ...reference(large), sha256: '0'.repeat(64) }]), status: 422 });
  const photos = [];
  for (let i = 0; i < 9; i++) photos.push(await upload(admin, png, '原件-' + i + '.png', 'image/png'));
  const createKey = randomUUID();
  const created = await request('/orders', { token: admin, method: 'POST', body: order([large, ...photos].map(reference)), key: createKey, status: 201 });
  const id = created.id || created.order?.id;
  assert.ok(id, '缺少工单id');
  const detail = await request('/orders/' + id, { token: admin });
  const received = detail.order || detail;
  assert.equal(received.evidence.length, 10);
  const serialized = JSON.stringify(received);
  assert.ok(!serialized.includes('dataBase64') && !serialized.includes('blobId') && !serialized.includes('requestKey'));
  check('十个媒体与大视频原子建单，错误元数据失败不消耗原件，响应不泄漏存储字段');
  const same = await request('/orders', { token: admin, method: 'POST', body: order([large, ...photos].map(reference)), key: createKey, status: 201 });
  assert.equal(same.id || same.order?.id, id); check('建单未知结果可按原键取回相同工单');
  await request('/order-uploads/' + large.id, { token: admin, method: 'DELETE', status: 409 });
  const first = received.evidence.find(item => item.sha256 === large.sha256);
  assert.ok(first);
  async function verifyDownload(token) {
    const response = await fetch(origin + '/api/v38/orders/' + id + '/evidence/' + first.id, { headers: { Authorization: 'Bearer ' + token }, signal: AbortSignal.timeout(120000) });
    assert.equal(response.status, 200);
    const hash = createHash('sha256'); let bytes = 0;
    for await (const data of response.body) { hash.update(data); bytes += data.length; }
    assert.equal(bytes, large.size); assert.equal(hash.digest('hex'), large.sha256);
  }
  await verifyDownload(admin); check('私有原件流式下载逐字节摘要一致');
  const guestDownload = await fetch(origin + '/api/v38/orders/' + id + '/evidence/' + first.id);
  assert.equal(guestDownload.status, 401); check('匿名下载拒绝且已绑定原件不可取消');
  const unusedKey = randomUUID();
  const unused = await upload(admin, png, '未绑定.png', 'image/png', unusedKey);
  await request('/order-uploads/' + unused.id, { token: dispatcher, method: 'DELETE', status: 404 });
  await request('/order-uploads/' + unused.id, { token: admin, method: 'DELETE' });
  await upload(admin, png, unused.name, unused.mime, unusedKey, 409);
  await request('/orders', { token: admin, method: 'POST', body: order([reference(unused)]), status: 404 }); check('取消原件与跨账号删除隔离');
  await stop(); await start(); admin = await login('admin');
  await verifyDownload(admin); check('进程重启后原件与引用仍可读取');
  console.log(`RESULT cases=${passed} failures=0 skips=0`);
} catch (error) {
  console.error('FAIL', error.message, '\n临时诊断目录：' + work);
  process.exitCode = 1;
} finally {
  await stop();
  if (!process.exitCode) await rm(work, { recursive: true });
}
