import { readdirSync, readFileSync, existsSync } from "node:fs";
import { resolve, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const scriptsOnly = process.argv.includes("--scripts-only");
const requirePowerShell = process.argv.includes("--require-powershell");
const requireIOS = process.argv.includes("--require-ios");
const excluded = new Set([".git", "node_modules", "Pods", ".dart_tool", "build", "DerivedData", "xcuserdata"]);
let failures = 0;
let skips = 0;
let unprovided = 0;

function files(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    if (excluded.has(entry.name)) return [];
    const path = resolve(directory, entry.name);
    return entry.isDirectory() ? files(path) : entry.isFile() ? [path] : [];
  });
}

function available(command) {
  return !spawnSync(command, ["--version"], { stdio: "ignore" }).error;
}

function run(label, command, args, cwd = root, environment = process.env) {
  console.log(`\n[验证] ${label}`);
  const result = spawnSync(command, args, { cwd, stdio: "inherit", env: environment });
  if (result.error || result.status !== 0) {
    failures += 1;
    console.error(result.error?.message || `${label} 失败：退出码 ${result.status}`);
    return false;
  }
  return true;
}

function skip(label, required = false) {
  console.log(`[${required ? "缺失" : "跳过"}] ${label}`);
  if (required) failures += 1;
  else skips += 1;
}

const scriptFiles = files(resolve(root, "后端/部署"));
const powershell = [...scriptFiles, ...files(resolve(root, "验证/旧版基线"))].filter(path => extname(path) === ".ps1");
for (const path of powershell) {
  const data = readFileSync(path);
  if (!(data[0] === 0xef && data[1] === 0xbb && data[2] === 0xbf)) {
    console.error(`缺少 Windows PowerShell 5.1 所需 UTF-8 BOM：${path}`);
    failures += 1;
  }
}
console.log(`[验证] ${powershell.length} 个 PowerShell 入口的 UTF-8 BOM`);
const psCommand = process.env.POWERSHELL_BINARY || (process.platform === "win32" && available("powershell.exe")
  ? "powershell.exe" : available("pwsh") ? "pwsh" : null);
if (psCommand) {
  run("PowerShell AST 解析（不执行部署）", psCommand,
    ["-NoProfile", "-NonInteractive", "-File", resolve(root, "验证/旧版基线/parse-powershell.ps1"), "-Root", root]);
} else {
  skip("本机没有 PowerShell；未执行 Windows 实际解析，不计为通过", requirePowerShell);
}

if (process.platform !== "win32") {
  const shells = scriptFiles.filter(path => [".sh", ".zsh", ".command"].includes(extname(path)));
  for (const path of shells) {
    const firstLine = readFileSync(path, "utf8").split("\n", 1)[0];
    const shell = extname(path) === ".zsh" || firstLine.includes("zsh") ? "zsh" : "bash";
    const result = spawnSync(shell, ["-n", path], { encoding: "utf8" });
    if (result.error || result.status !== 0) {
      failures += 1;
      console.error(`${path}: ${result.error?.message || result.stderr}`);
    }
  }
  console.log(`[验证] ${shells.length} 个 Shell 文件语法`);
  const mock = resolve(root, "后端/部署/macOS/deployment/Tests/validate-targets.sh");
  if (existsSync(mock)) run("部署目标与卸载保护模拟回归", "bash", [mock]);
} else {
  skip("Windows 环境未执行 bash/zsh 语法检查，不计为通过");
}

const windowsMock = resolve(root, "后端/部署/Windows/deployment/Tests/validate-windows.ps1");
if (psCommand && existsSync(windowsMock)) {
  run("Windows 部署保护模拟回归", psCommand, ["-NoProfile", "-NonInteractive", "-File", windowsMock]);
}

if (!scriptsOnly) {
  const webTests = files(resolve(root, "后端/管理后台页面/tests")).filter(path => path.endsWith(".test.cjs"));
  run("WebAdmin 故障与业务回归", process.execPath, ["--test", ...webTests]);
  const portalTests = files(resolve(root, "前端/Web网页/旧版用户网页/tests")).filter(path => path.endsWith(".test.cjs"));
  run("PC Web 认证与环境隔离回归", process.execPath, ["--test", ...portalTests]);
  for (const path of files(resolve(root, "后端/管理后台页面")).filter(path => extname(path) === ".js")) {
    run(`JavaScript 语法：${path.slice(root.length + 1)}`, process.execPath, ["--check", path]);
  }
  for (const path of files(resolve(root, "前端/Web网页/旧版用户网页")).filter(path => extname(path) === ".js" && !path.includes("ThirdParty"))) {
    run(`JavaScript 语法：${path.slice(root.length + 1)}`, process.execPath, ["--check", path]);
  }
  const go = process.env.GO_BINARY || "go";
  const gofmt = process.env.GOFMT_BINARY || (go === "go" ? "gofmt" : resolve(dirname(go), "gofmt"));
  const server = resolve(root, "后端/Go服务端");
  const format = spawnSync(gofmt, ["-l", ...files(server).filter(path => extname(path) === ".go")], { encoding: "utf8" });
  if (format.error || format.status !== 0 || format.stdout.trim()) {
    console.error(format.error?.message || format.stdout || format.stderr);
    failures += 1;
  } else {
    console.log("[验证] Go 格式一致");
  }
  // 密码派生有意保留高计算成本；串行测试包，包内并发合同仍照常执行。
  run("Go 单元测试及竞态检查", go, ["test", "-race", "-p", "1", "./..."], server,
    { ...process.env, REPAIR_TEST_TIDB_DSN: "" });
  run("Go 静态检查", go, ["vet", "./..."], server);
  run("独立 API HTTP 全流程", process.execPath, [resolve(root, "验证/旧版基线/smoke-api.mjs")]);
  unprovided += 1;
  console.log("[未提供] 本副本没有原生 iOS 工程，未执行原生源码或实体设备验证，不计为通过。");
  if (requireIOS) failures += 1;
}

console.log(`\n验证结束：${failures} 项失败，${skips} 项跳过，${unprovided} 项原生能力未提供。没有运行部署、迁移、卸载或 App 打包。`);
process.exitCode = failures ? 1 : 0;
