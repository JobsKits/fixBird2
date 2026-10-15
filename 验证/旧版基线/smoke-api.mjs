import assert from "node:assert/strict";
import { mkdtempSync, rmSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:net";
import { once } from "node:events";
import { randomBytes } from "node:crypto";

// 默认启动独立内存 API；--tidb 仅接受显式回环测试实例，并创建自己的新测试库。
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const temporary = mkdtempSync(resolve(tmpdir(), "repair-api-smoke-"));
let api;
let logs = "";
const adminPassword = randomBytes(24).toString("hex");
let databaseDSN = "";
let cleanupDatabase;
try {
  if (process.argv.includes("--tidb")) {
    const input = process.env.REPAIR_TEST_TIDB_DSN || "";
    const match = /^(.*@tcp\((?:127\.0\.0\.1|localhost|\[::1\]):\d+\)\/)repair_test_[A-Za-z0-9_]+(\?[^\n]*)?$/.exec(input);
    assert.ok(match, "--tidb requires a dedicated loopback REPAIR_TEST_TIDB_DSN with repair_test_ database prefix");
    const name = "repair_test_smoke_" + Date.now() + "_" + randomBytes(4).toString("hex");
    databaseDSN = match[1] + name + (match[2] || "");
    const cleanupSource = resolve(temporary, "cleanup.go");
    writeFileSync(cleanupSource, `package main
import("context";"database/sql";"os";"regexp";"time";mysql "github.com/go-sql-driver/mysql")
func main(){cfg,err:=mysql.ParseDSN(os.Getenv("REPAIR_SMOKE_OWNED_DSN"));if err!=nil{panic(err)};name:=cfg.DBName;if !regexp.MustCompile("^repair_test_smoke_[0-9]+_[a-f0-9]{8}$").MatchString(name){panic("refuse non-owned database")};cfg.DBName="";db,err:=sql.Open("mysql",cfg.FormatDSN());if err!=nil{panic(err)};defer db.Close();ctx,cancel:=context.WithTimeout(context.Background(),10*time.Second);defer cancel();if _,err=db.ExecContext(ctx,"DROP DATABASE IF EXISTS \\x60"+name+"\\x60");err!=nil{panic(err)}}
`);
    cleanupDatabase = () => {
      const result = spawnSync(process.env.GO_BINARY || "go", ["run", cleanupSource], {
        cwd: resolve(root, "后端/Go服务端"), env: { ...process.env, REPAIR_SMOKE_OWNED_DSN: databaseDSN }, stdio: "inherit"
      });
      assert.equal(result.status, 0, "owned test database cleanup failed");
    };
    const migrated = spawnSync(process.env.GO_BINARY || "go", ["run", "./cmd/migrate", "-seed-demo=false"], {
      cwd: resolve(root, "后端/Go服务端"), env: { ...process.env, TIDB_DSN: databaseDSN }, stdio: "inherit"
    });
    assert.equal(migrated.status, 0, "owned TiDB migration failed");
  }
  const binary = resolve(temporary, process.platform === "win32" ? "api.exe" : "api");
  const build = spawnSync(process.env.GO_BINARY || "go", ["build", "-o", binary, "./cmd/api"], {
    cwd: resolve(root, "后端/Go服务端"), stdio: "inherit"
  });
  assert.equal(build.status, 0, build.error?.message || "API build failed");
  const reservation = createServer();
  reservation.listen(0, "127.0.0.1");
  await once(reservation, "listening");
  const port = reservation.address().port;
  await new Promise(resolve => reservation.close(resolve));
  const base = `http://127.0.0.1:${port}`;
  api = spawn(binary, [], {
    cwd: resolve(root, "后端/Go服务端"),
    env: { ...process.env, APP_ADDR: `127.0.0.1:${port}`, TIDB_DSN: databaseDSN, DEMO_MODE: "true",
      ALLOW_DEMO_NETWORK: "false", ADMIN_WEB_DIR: resolve(root, "后端/管理后台页面"), WEB_DIR: resolve(root, "前端/Web网页/旧版用户网页"),
      WORKER_ASSET_DIR: resolve(temporary, "private-uploads"), ADMIN_BOOTSTRAP_USERNAME: "smoke_admin",
      ADMIN_BOOTSTRAP_PASSWORD: adminPassword, ALLOW_ANONYMOUS_DEMO: "true" },
    stdio: ["ignore", "pipe", "pipe"]
  });
  api.stdout.on("data", data => { logs += data; });
  api.stderr.on("data", data => { logs += data; });
  const deadline = Date.now() + 10000;
  while (true) {
    try {
      const ready = await fetch(base + "/readyz", { signal: AbortSignal.timeout(500) });
      if (ready.ok) break;
    } catch (_) {}
    assert.ok(api.exitCode === null && Date.now() < deadline, "API readiness failed: " + logs);
    await new Promise(resolve => setTimeout(resolve, 50));
  }

  const tokens = {};
  async function call(path, { role = "customer", actor, body, key, raw, token, method, anonymous = false } = {}) {
    const response = await fetch(base + path, {
      method: method || (body !== undefined || raw !== undefined ? "POST" : "GET"),
      headers: { "Content-Type": "application/json", "X-Actor-Role": role,
        "X-Actor-ID": actor || role + "-demo", ...(key ? { "Idempotency-Key": key } : {}),
        ...(!anonymous && (token || tokens[role]) ? { Authorization: "Bearer " + (token || tokens[role]) } : {}) },
      body: raw !== undefined ? raw : body !== undefined ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(3000)
    });
    const data = response.status === 204 ? null : await response.json();
    return { status: response.status, data, cursor: response.headers.get("X-Next-Cursor") };
  }
  assert.equal((await call("/api/v1/admin/dashboard", { role: "admin", anonymous: true })).status, 401);
  async function register(username, role) {
    const password = randomBytes(16).toString("hex");
    const result = await call("/api/v1/auth/register", { anonymous: true, body: { username,
      password, displayName: "验收账号", role,
      device: { kind: "mobile", label: "验收手机", platform: "iOS" } } });
    assert.equal(result.status, 201);
    assert.equal(result.data.user.role, role);
    return { ...result.data, testPassword: password };
  }
  const adminLogin = await call("/api/v1/auth/login", { anonymous: true,
    body: { username: "smoke_admin", password: adminPassword, device: { kind: "desktop", label: "验收管理后台", platform: "Web" } } });
  assert.equal(adminLogin.status, 200);
  tokens.admin = adminLogin.data.token;
  const customer = await register("smoke_customer", "customer");
  tokens.customer = customer.token;
  const worker = await register("smoke_worker", "worker");
  tokens.worker = worker.token;
  const other = await register("smoke_other", "customer");
  const unapprovedOrders = await call("/api/v1/orders", { role: "worker" });
  assert.equal(unapprovedOrders.status, 200);
  assert.deepEqual(unapprovedOrders.data, []);
  const applicationBefore = await call("/api/v1/workers/me/application", { role: "worker" });
  assert.equal(applicationBefore.status, 404);
  const png = readFileSync(resolve(root, "后端/管理后台页面/assets/RepairLogo.png"));
  const form = new FormData();
  form.append("file", new Blob([png], { type: "image/png" }), "qualification.png");
  const uploaded = await fetch(base + "/api/v1/worker-assets", { method: "POST",
    headers: { Authorization: "Bearer " + worker.token }, body: form, signal: AbortSignal.timeout(3000) });
  assert.equal(uploaded.status, 201);
  const asset = await uploaded.json();
  const unauthorizedAsset = await fetch(base + "/api/v1/worker-assets/" + asset.id,
    { headers: { Authorization: "Bearer " + other.token } });
  assert.equal(unauthorizedAsset.status, 403);
  const application = await call("/api/v1/workers/me/application", { role: "worker", body: {
    displayName: "验收维修师傅", contactPhone: "13800138000", serviceAreas: ["验收区域"], skills: ["家电维修"],
    bio: "独立自动化验收资料", assetIds: [asset.id], expectedRevision: 0 } });
  assert.equal(application.status, 200);
  assert.equal(application.data.status, "pending");
  const reviewed = await call("/api/v1/admin/worker-applications/" + application.data.id + "/review", { role: "admin", body: {
    decision: "approved", note: "测试通过", expectedRevision: application.data.revision } });
  assert.equal(reviewed.status, 200);
  assert.equal(reviewed.data.status, "approved");
  assert.equal((await call("/api/v1/admin/worker-applications/" + application.data.id + "/review", { role: "admin", body: {
    decision: "rejected", note: "迟到审核", expectedRevision: application.data.revision } })).status, 409);
  const challenge = await call("/api/v1/auth/qr/challenges", { anonymous: true, body: {
    device: { kind: "desktop", label: "验收 PC", platform: "Web" } } });
  assert.equal(challenge.status, 201);
  assert.ok(!challenge.data.qrPayload.includes(customer.token));
  const qr = new URL(challenge.data.qrPayload);
  const approvalCode = qr.searchParams.get("approvalCode");
  const challengePath = "/api/v1/auth/qr/challenges/" + challenge.data.id;
  const pending = await call(challengePath + "/poll", { anonymous: true, body: { pollToken: challenge.data.pollToken } });
  assert.equal(pending.data.status, "pending");
  assert.equal((await call(challengePath + "/inspect", { body: { approvalCode } })).status, 200);
  assert.equal((await call(challengePath + "/approve", { body: { approvalCode, decision: "approve" } })).status, 200);
  const redeemed = await call(challengePath + "/poll", { anonymous: true, body: { pollToken: challenge.data.pollToken } });
  assert.equal(redeemed.data.status, "approved");
  const desktop = redeemed.data.auth;
  assert.equal(desktop.user.id, customer.user.id);
  assert.deepEqual(desktop.session.capabilities, []);
  assert.equal((await call("/api/v1/auth/devices", { token: desktop.token })).status, 403);
  assert.equal((await call(challengePath + "/poll", { anonymous: true, body: { pollToken: challenge.data.pollToken } })).data.status, "consumed");
  const devices = await call("/api/v1/auth/devices");
  assert.equal(devices.status, 200);
  assert.equal(devices.data.length, 2);
  assert.equal((await call("/api/v1/auth/logout", { body: {} })).status, 204);
  assert.equal((await call("/api/v1/auth/me", { token: customer.token })).status, 401);
  assert.equal((await call("/api/v1/auth/me", { token: desktop.token })).data.id, customer.user.id);
  tokens.customer = desktop.token;
  const input = { category: "家电维修", equipment: "测试冰箱", issue: "独立进程维修流程验收",
    address: "测试地址", scheduledAt: "2026-10-06T14:00:00+08:00" };
  const created = await call("/api/v1/orders", { body: input, key: "smoke-order-1" });
  assert.equal(created.status, 201);
  const retries = await Promise.all(Array.from({ length: 8 }, () =>
    call("/api/v1/orders", { body: input, key: "smoke-order-1" })));
  assert.ok(retries.every(item => item.status === 201 && item.data.id === created.data.id));
  const conflict = await call("/api/v1/orders", { body: { ...input, issue: "不同请求" }, key: "smoke-order-1" });
  assert.equal(conflict.status, 409);
  assert.ok(conflict.data.code);
  const hidden = await call("/api/v1/orders", { token: other.token });
  assert.deepEqual(hidden.data, []);
  const trailing = await call("/api/v1/orders", { raw: JSON.stringify(input) + " {}" });
  assert.equal(trailing.status, 400);
  const orderPath = "/api/v1/orders/" + created.data.id;
  for (const action of ["accept", "arrive"]) {
    assert.equal((await call(orderPath + "/" + action, { role: "worker", body: {} })).status, 200);
  }
  const excessive = await call(orderPath + "/quote", { role: "worker", body: { quoteCents: 100000001 } });
  assert.equal(excessive.status, 400);
  assert.equal((await call(orderPath + "/quote", { role: "worker", body: { quoteCents: 10 } })).status, 200);
  assert.equal((await call(orderPath + "/confirm-quote", { body: {} })).status, 200);
  assert.equal((await call(orderPath + "/complete", { role: "worker", body: {} })).status, 200);
  for (const provider of ["wechat", "alipay", "aggregate"]) {
    const payment = await call("/api/v1/payment-intents", { body: { orderId: created.data.id, provider } });
    assert.equal(payment.status, 501);
  }
  const collectPath = "/api/v1/admin/orders/" + created.data.id + "/demo-collect";
  const collected = await call(collectPath, { role: "admin", body: {} });
  assert.equal(collected.status, 200);
  assert.equal(collected.data.workerShareCents, 9);
  assert.equal(collected.data.platformFeeCents, 1);
  assert.equal((await call(collectPath, { role: "admin", body: {} })).status, 200);
  const settlements = await call("/api/v1/admin/settlements", { role: "admin" });
  assert.equal(settlements.data.length, 1);
  const paidPath = "/api/v1/admin/settlements/" + settlements.data[0].id + "/manual-paid";
  assert.equal((await call(paidPath, { role: "admin", body: {} })).status, 204);
  assert.equal((await call(paidPath, { role: "admin", body: {} })).status, 204);
  assert.equal((await call("/api/v1/admin/settlements", { role: "admin" })).data[0].status, "manually_paid");
  const journals = await call("/api/v1/admin/ledger/journals", { role: "admin" });
  assert.equal(journals.status, 200);
  assert.equal(journals.data.length, 2);
  assert.ok(journals.data.every(item => item.mode === "simulated" && item.simulated));
  for (const journal of journals.data) {
    const debit = journal.entries.filter(entry => entry.direction === "debit").reduce((sum, entry) => sum + entry.amountCents, 0);
    const credit = journal.entries.filter(entry => entry.direction === "credit").reduce((sum, entry) => sum + entry.amountCents, 0);
    assert.equal(debit, credit);
  }
  const totals = await call("/api/v1/admin/ledger/summary", { role: "admin" });
  assert.equal(totals.data.collectedCents, 10);
  assert.equal(totals.data.workerPayableCents, 0);
  assert.equal((await call("/api/v1/ledger/journals", { token: other.token })).data.length, 0);
  assert.equal((await call("/api/v1/admin/ledger/journals?mode=actual", { role: "admin" })).data.length, 0);
  const csv = await fetch(base + "/api/v1/admin/ledger/export.csv", { headers: { Authorization: "Bearer " + tokens.admin } });
  assert.equal(csv.status, 200);
  assert.match(csv.headers.get("Content-Type"), /text\/csv/);
  assert.match(await csv.text(), /simulated/);
  await call("/api/v1/orders", { body: input, key: "smoke-order-2" });
  const page = await call("/api/v1/admin/orders?limit=1", { role: "admin" });
  assert.equal(page.data.length, 1);
  assert.ok(page.cursor);
  const next = await call("/api/v1/admin/orders?limit=1&cursor=" + encodeURIComponent(page.cursor), { role: "admin" });
  assert.equal(next.data.length, 1);
  assert.notEqual(next.data[0].id, page.data[0].id);
  const dashboard = await call("/api/v1/admin/dashboard", { role: "admin" });
  assert.equal(dashboard.data.totalOrders, 2);
  const admin = await fetch(base + "/admin/");
  assert.equal(admin.status, 200);
  assert.match(await admin.text(), /marketplace-data.js/);
  const portal = await fetch(base + "/portal/");
  assert.equal(portal.status, 200);
  assert.match(await portal.text(), /portal.js/);
  const mobileAgain = await call("/api/v1/auth/login", { anonymous: true, body: { username: "smoke_customer",
    password: customer.testPassword, device: { kind: "mobile", label: "重新登录手机", platform: "iOS" } } });
  assert.equal(mobileAgain.status, 200);
  assert.equal((await call("/api/v1/auth/devices/" + desktop.session.id,
    { token: mobileAgain.data.token, method: "DELETE" })).status, 204);
  assert.equal((await call("/api/v1/auth/me", { token: desktop.token })).status, 401);
  assert.equal((await call("/api/v1/auth/me", { token: mobileAgain.data.token })).status, 200);
  console.log("PASS: 独立 HTTP 登录/私有图片/人工审核/扫码/多设备退出隔离/维修全流程/并发幂等/分页/平衡账本/本人账务/CSV/三渠道501及双Web托管");
} finally {
  if (api && api.exitCode === null) {
    api.kill("SIGTERM");
    await new Promise(resolve => {
      const timer = setTimeout(() => api.kill("SIGKILL"), 6000);
      api.once("exit", () => { clearTimeout(timer); resolve(); });
    });
  }
  if (cleanupDatabase) cleanupDatabase();
  rmSync(temporary, { recursive: true, force: true });
}
