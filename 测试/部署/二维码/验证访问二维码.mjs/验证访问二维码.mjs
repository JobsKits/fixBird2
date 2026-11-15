// 用途：隔离验证各系统真实部署二维码函数；仅写临时目录，不连接服务、隧道或浏览器。
// 显式传 --run 开始；使用 GO_BIN 指定健康Go；测试只读取已下载依赖（GOPROXY=off）。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
console.log('访问二维码隔离验证：临时生成真实HTML/SVG/PNG，加载各平台部署函数；不连接业务、隧道或真实浏览器。');
if (process.argv.length !== 3 || process.argv[2] !== '--run') {
  console.log('执行：GO_BIN=已核验Go路径 node 验证访问二维码.mjs --run；Ctrl+C取消。');
  process.exit(0);
}
const temp = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'repair-qr-check-'));
let count = 0;
const go = process.env.GO_BIN || 'go';
function execute(file, args, environment = {}) {
  const result = spawnSync(file, args, { encoding: 'utf8', timeout: 90000, env: { ...process.env, ...environment } });
  if (result.error || result.status !== 0) throw new Error(`${file}: ${result.error || result.status}\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
try {
  const binary = path.join(temp, process.platform === 'win32' ? 'deployqr.exe' : 'deployqr');
  execute(go, ['-C', path.join(root, '部署/公共组件/地址二维码'), 'build', '-mod=readonly', '-o', binary, '.'], { GOPROXY: 'off', GOTOOLCHAIN: 'local' });
  console.log('PASS locked-tool-build (GOPROXY=off)'); count++;
  for (const system of ['MacOS', 'Ubuntu', 'Debian', 'RockyLinux', 'AlibabaCloudLinux']) {
    const mac = system === 'MacOS';
    const filename = mac ? '【MacOS】启动维修工作台.command' : '【Linux】部署维修工作台.sh';
    const sourcePath = path.join(root, '部署', system, 'Deployment', filename, filename);
    const source = fs.readFileSync(sourcePath, 'utf8');
    if (!source.trimEnd().endsWith('main "$@"')) throw new Error('入口结构变化，拒绝执行部署。');
    const functions = path.join(temp, `${system}-functions`);
    fs.writeFileSync(functions, source.replace(/main "\$@"\s*$/, ''));
    const runDir = path.join(temp, system, '中文 空格会话'); fs.mkdirSync(runDir, { recursive: true });
    const fixture = path.join(temp, `${system}-fixture`);
    fs.writeFileSync(fixture, `source "$SOURCE"
RUN_DIR="$CASE_ROOT"
LOG_FILE="$RUN_DIR/deploy.log"
: > "$LOG_FILE"
QR_BINARY="$QR_TOOL"
WB_ADDR=127.0.0.1:18198
PUBLIC_URL=https://fixture-a.trycloudflare.com
OUTPUT_COLOR=0
show_access_qr
first="$QR_PAGE"
[ -f "$first" ] || exit 10
grep -F 'https://fixture-a.trycloudflare.com/admin/' "$first" >/dev/null || exit 11
grep -F '仅本机，手机不可用' "$first" >/dev/null || exit 12
PUBLIC_URL=https://fixture-b.trycloudflare.com
show_access_qr
[ "$first" != "$QR_PAGE" ] || exit 13
grep -F '已失效' "$first" >/dev/null || exit 14
grep -F 'https://fixture-b.trycloudflare.com/admin/' "$QR_PAGE" >/dev/null || exit 15
# 真实菜单函数映射扫码页面；替身不打开浏览器。
fixture_fzf() { cat > "$RUN_DIR/menu-input"; printf '\\nqr\\t打开扫码页面（各端二维码与原始URL）\\n'; }
open() { printf '%s' "$1" > "$RUN_DIR/opened"; }
xdg-open() { printf '%s' "$1" > "$RUN_DIR/opened"; }
export DISPLAY=fixture
FZF_EXECUTABLE=fixture_fzf
start_browser_menu
handle_browser_menu_result
for retry in 1 2 3 4 5; do [ -f "$RUN_DIR/opened" ] && break; sleep 0.1; done
[ "$(cat "$RUN_DIR/opened")" = "$QR_PAGE" ] || exit 16
# 辅助失败仍返回成功，后端进程保持；旧二维码页先失效。
sleep 20 &
API_PID=$!
QR_BINARY=/usr/bin/false
show_access_qr
kill -0 "$API_PID" || exit 17
[ -z "$QR_PAGE" ] || exit 18
kill -TERM "$API_PID"; wait "$API_PID" 2>/dev/null || true; API_PID=''
QR_BINARY="$QR_TOOL"
PUBLIC_URL=''
show_access_qr
grep -F '手机不可用' "$QR_PAGE" >/dev/null || exit 19
expire_access_qr
grep -F '已失效' "$RUN_DIR/access-qr-4/index.html" >/dev/null || exit 20
[ -z "$QR_PAGE" ] || exit 21
# 会话已由原部署原点清单纳管，辅助产物无需新增删除边界。
grep -F 'session' "$SOURCE" >/dev/null || exit 22
# 非TTY日志不得残留ANSI。
LC_ALL=C awk 'index($0,sprintf("%c",27)){exit 1}' "$LOG_FILE" || exit 23
RUN_DIR=''
`);
    execute(mac ? '/bin/zsh' : '/bin/bash', [fixture], { SOURCE: functions, CASE_ROOT: runDir, QR_TOOL: binary });
    console.log(`PASS ${system}: URL/card/menu/update/expiry/failure/plain-log`); count++;
    if (mac && process.platform === 'darwin') {
      // 用系统图像识别解码实际PNG，避免只验证页面文案却遗漏码内地址。
      const decoded = JSON.parse(execute('/usr/bin/osascript', ['-l', 'JavaScript', '-e', `
ObjC.import('AppKit');
ObjC.import('CoreImage');
function run(argv) {
  var detector = $.CIDetector.detectorOfTypeContextOptions($.CIDetectorTypeQRCode, $.CIContext.contextWithOptions($.NSDictionary.dictionary), $({CIDetectorAccuracy: 'CIDetectorAccuracyHigh'}));
  var result = [];
  for (var name of ['01.png', '02.png', '03.png', '04.png']) {
    var image = $.CIImage.imageWithContentsOfURL($.NSURL.fileURLWithPath(argv[0] + '/' + name));
    var features = detector.featuresInImage(image);
    if (Number(features.count) !== 1) throw new Error('PNG必须能解出唯一二维码：' + name);
    result.push(ObjC.unwrap(features.objectAtIndex(0).messageString));
  }
  return JSON.stringify(result);
}`, path.join(runDir, 'access-qr-2')]));
      const expected = ['https://fixture-b.trycloudflare.com/', 'https://fixture-b.trycloudflare.com/admin/', 'http://127.0.0.1:18198/', 'http://127.0.0.1:18198/admin/'];
      if (JSON.stringify(decoded) !== JSON.stringify(expected)) throw new Error(`MacOS二维码内容错误：${JSON.stringify(decoded)}`);
      console.log('PASS MacOS: actual-PNG-decode/frontend/admin/loopback'); count++;
    }
  }
  const ps = path.join(temp, 'windows-fixture.ps1');
  fs.writeFileSync(ps, `Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($env:PS_SOURCE,[ref]$tokens,[ref]$errors)
if ($errors) { throw '部署脚本解析失败。' }
# 只提取二维码实际需要的函数，兼容入口外层的终端配色try/finally；不执行初始化或部署。
foreach ($name in @('Write-DeployLog', 'Expire-AccessQr', 'Show-AccessQr')) {
    $matches = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true))
    if ($matches.Count -ne 1) { throw ('二维码函数缺失或重复：' + $name) }
    . ([scriptblock]::Create($matches[0].Extent.Text))
}
$script:QrBinary=$env:QR_TOOL; $script:QrPage=$null; $script:QrGeneration=0
$script:RunDirectory=$env:CASE_ROOT; $script:AppEnvironment=@{WB_ADDR='127.0.0.1:18198'}
$script:LogFile=Join-Path $script:RunDirectory 'deploy.log'
Show-AccessQr 'https://fixture-a.trycloudflare.com'
$first=$script:QrPage
if (-not $first -or -not (Test-Path $first)) { throw '第一轮页面未生成。' }
Show-AccessQr 'https://fixture-b.trycloudflare.com'
if ($first -eq $script:QrPage -or (Get-Content $first -Raw) -notmatch '已失效') { throw '旧页未失效。' }
if ((Get-Content $script:QrPage -Raw) -notmatch 'https://fixture-b.trycloudflare.com/admin/') { throw '管理端URL错误。' }
Expire-AccessQr
if ($script:QrPage) { throw '失效后仍提供菜单入口。' }
$script:QrBinary='/usr/bin/false'
Show-AccessQr 'https://fixture-c.trycloudflare.com'
if ($script:QrPage) { throw '失败时保留旧入口。' }
$script:QrBinary=$env:QR_TOOL
Show-AccessQr ''
if ((Get-Content $script:QrPage -Raw) -notmatch '仅本机，手机不可用') { throw '回环未标记。' }
`);
  const windowsSource = path.join(root, '部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1');
  const windowsDir = path.join(temp, 'Windows'); fs.mkdirSync(windowsDir);
  execute(process.env.PWSH_BIN || 'pwsh', ['-NoProfile', '-File', ps], { PS_SOURCE: windowsSource, QR_TOOL: binary, CASE_ROOT: windowsDir, NO_COLOR: '1' });
  console.log('PASS Windows: actual-render/update/expiry/failure/loopback'); count++;
  console.log(`通过 ${count} 组；未执行目标系统原生部署或手机公网验收。`);
  fs.rmSync(temp, { recursive: true });
} catch (error) {
  console.error(`失败：${error.message}\n夹具保留：${temp}`); process.exitCode = 1;
}
