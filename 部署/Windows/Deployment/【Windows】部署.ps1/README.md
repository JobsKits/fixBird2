# <span id="前言">Windows 维修工作台一键部署</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、启动与选择](#jobs-toc-heading-1)
- [二、本地部署＋内网穿透](#jobs-toc-heading-2)
- [三、平台、最低配置与首次准备](#jobs-toc-heading-3)
- [四、只读检查与计划](#jobs-toc-heading-4)
- [五、数据、缓存与配置](#jobs-toc-heading-5)
- [六、停止与故障定位](#jobs-toc-heading-6)

</details>
<!-- jobs-toc:end -->

---

本包的 [【Windows】部署.ps1](【Windows】部署.ps1) 面向 Windows PowerShell 5.1 和更新版本。保留完整项目，双击兄弟包中的 [【Windows】部署.cmd](../【Windows】部署.cmd/【Windows】部署.cmd)，或在普通用户的 PowerShell 终端运行下列命令，阅读自述并直接回车。入口通过 [fzf](https://github.com/junegunn/fzf) 选择两种模式，菜单及解析器可按静态锁引导；选择模式后重新查询官方稳定工具，校验下载至本项目机器缓存，不需要预先安装Go或cloudflared。

**部署快捷入口：** 可在本系统目录直接双击 [【Windows】双击部署（快捷入口）.cmd](../../【Windows】双击部署（快捷入口）.cmd)；它调用本目录下的规范部署实现，复用同一自述、确认与参数，不另存部署逻辑。

**扫码入口：** 启动后保留各端完整 URL，分别显示用户／工程师工作台和管理端的离线二维码。宽度足够且支持颜色时直接在终端扫码；否则用“打开网页”菜单中的“打开扫码页面”打开本次 HTML，页面内嵌 SVG，并保留 PNG／SVG 文件。回环码明确“仅本机，手机不可用”，公网码使用本轮实际隧道 URL，仍须原有邮箱验证与登录。二维码工具复用已有 Go 和锁定依赖，失败只告警并保留 URL／服务；产物位于本次 Runtime 会话。隧道地址变化会使旧页面失效并生成新码，退出也标记失效；已另存的图片不能撤销，重新部署必须使用新码。来源及参数见[二维码工具](../../../公共组件/地址二维码/README.md)。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、启动与选择 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在项目根目录执行，下列相对路径可以随完整工程一起移动；路径含中文或空格时保留双引号：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\部署\Windows\Deployment\【Windows】部署.ps1\【Windows】部署.ps1"
```

CMD 仅按自身位置找到兄弟包的同名 PS1，透传参数与错误码；没有参数且运行失败时停留显示错误。`-ExecutionPolicy Bypass` 仅作用于本次新建的 PowerShell 进程，不修改系统执行策略。入口要求可交互终端，重定向输入和无人值守调用不能代替回车确认。直接双击 `.ps1` 常会打开编辑器，请双击 `.cmd`。

| 选择 | 实际行为 | 适合场景 |
| --- | --- | --- |
| 本地部署＋内网穿透 | 构建并运行本机后端，核对健康检查与监听 PID，再建立 Cloudflare Quick Tunnel HTTPS 随机地址 | 前期低频展示、异地浏览器演示、合成数据联调 |
| 正常服务器部署 | 构建并运行当前后端，仅监听 `127.0.0.1:8098`，不创建隧道 | 本机使用、由已有可信 HTTPS 反向代理接入 |

部署前根菜单和子菜单均可按 Esc 取消；本地访问方式子菜单可按左方向键返回根菜单。任何空选择、非法返回值或 fzf 失败都会停止，不会默认启动。

启动成功后自动进入“打开网页”fzf菜单，列出本次生成的公网地址和本机地址；用方向键选择并回车，直接交给系统默认浏览器打开，无需复制或输入网址。打开后菜单再次显示，可以反复选择，终端和服务保持运行。服务器模式列本机地址及扫码页面，回环码明确仅本机。网页菜单按 Esc 或选择“收起菜单”仅收起菜单，在原终端按回车重新显示；Ctrl+C停止本次菜单、后端和隧道。打开失败可继续选择，服务不会因此停止。

服务器模式沿用当前程序的固定演示账号和回环监听。它不会自动完成生产认证改造、域名、HTTPS 反向代理、备案或防火墙配置，不能直接当作生产公网服务使用。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、本地部署＋内网穿透 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

选择本地模式后，还需选择访问范围：

- **浏览器访问（指定邮箱收验证码，默认）。** 部署者输入允许访问者的邮箱，多个用英文逗号分隔。访问者仍打开HTTPS链接，再输入允许的邮箱，收取并填写一次性验证码后才能进入。邮箱只用于公网入口身份验证，与维修业务无关；不写入入口日志。可用当前进程的 `WB_TUNNEL_ALLOWED_MAIL` 提供名单。原生App／普通API无法完成网页验证码。
- **公开演示／App联调（隧道不验证邮箱）。** 只有再次输入准确的 `PUBLIC` 才启动公开隧道。必须仅使用可丢弃的合成资料；当前程序有固定演示账号，公开链接的访问者仍可能登录并操作这些演示资料。若工程现有数据含真实信息，请取消并先准备独立的合成数据目录，不要直接公开现有数据。

后端通过 `/api/v38/healthz` 且监听端口确实属于本次后端后，入口才创建隧道。本次私有运行目录写入 `quick-empty.yml` 有效空映射，并显式传入 `--config`；子进程局部隔离继承的 `TUNNEL_*` 配置，不改已有用户配置或调用者环境，避免既有命名隧道配置影响 Quick Tunnel。只有日志出现本次真实生成的 `https://…trycloudflare.com` 地址，才会显示公网访问地址。默认等待 45 秒，超时、后端退出或隧道退出会停止本次全部进程。可将 `WB_TUNNEL_START_TIMEOUT_SECONDS` 设为 5～300 的整数；该变量只影响等待地址的时限。

在“打开网页”菜单选择本次公网地址即可用本机默认浏览器打开；需要验证外网时，再用手机关闭 Wi-Fi、通过移动网络访问同一链接。依次验证邮箱 PIN（受限方式）、真实登录、一次合成资料写操作、刷新重读和文件访问权限。页面自带演示回退，**仅能看到页面不能证明接口和穿透成功**。原生 App 仅在已明确选择公开合成联调时，将实际 HTTPS 地址配置为 API 根地址，不要填写 `/api/v38/healthz` 或 `/admin` 子路径。

Quick Tunnel 不要求租用云服务器、固定公网 IP 或购买域名，适合短期低频验证；地址随重启变化，电脑休眠、关机、终端退出或网络中断后不可访问。其连接数、SSE 和服务保证等限制见 [Cloudflare Quick Tunnels 官方说明](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)。免费工具不包含本机电费、网络费或可用性保证。在中国大陆的实际连通性以本机与访问者网络测试为准。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、平台、最低配置与首次准备 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 要求 |
| --- | --- |
| 系统 | 能运行 Windows PowerShell 5.1、.NET Framework 4.5+，且具备 `Get-NetTCPConnection` 的 Windows；建议使用仍受厂商支持的 Windows 版本 |
| amd64 / x64 | 两种模式均有锁定的原生工具资产 |
| ARM64 | 服务器模式支持下载原生 Go 和 fzf；若官方当次未提供Windows ARM64 cloudflared成品，本地模式只接受显式指定且满足官方目标、架构与能力检查的原生客户端，否则在启动后端前停止，不混用x64下载包 |
| 单项目最低可用资源 | 2 核 CPU、4 GiB **可用内存**、20 GiB 空闲 SSD；这是应用的规划下限，另留 Windows 和其它程序的资源 |
| 同机运行两个项目 | 建议至少 4 核 CPU、8 GiB **可用内存**、40 GiB 空闲 SSD；仍需按并发、附件和数据库实际占用监测调整 |
| 网络 | 首次缺工具时需要 HTTPS 访问 GitHub Releases 和 `go.dev`；首次 Go 构建还需模块下载网络 |

工程内 [deploy-tools.lock.tsv](../../../deploy-tools.lock.tsv) 的fzf `0.74.5`、Go `1.27.3`、cloudflared `2026.10.7` 只是静态引导基线；正常部署由官方元数据确定当次稳定目标。入口记录官方来源、版本、目标路径和 SHA256；完整下载经SHA256校验后才解压和执行；临时网络错误退避重试可取消，摘要或来源错误停止，不使用部分下载或旧构建产物。压缩包中的绝对路径、父级跳转和符号链接会被拒绝。

最终工具必须同时满足当次官方稳定版本与能力检查。显式 `GO_BIN` / `WB_FZF_BIN` / `WB_CLOUDFLARED_BIN` 过旧、损坏或架构不符即停止；未显式指定时从PATH、公共及项目专属多版本缓存中按实际语义版本择新，否则校验下载新版。保留Go至少1.24、fzf菜单参数及cloudflared的 `--config`、`--url`、`--no-autoupdate` 能力门禁；私有邮箱模式额外要求 `--allowed-mail`，公开模式不要求邮箱能力，不以新版号代替可用性检查。完整策略见[工具更新与业务依赖检查](../../../README.md#tool-updates)。

下载不需要管理员权限，不修改系统 PATH、系统服务、网络代理或防火墙，不自动开放路由器端口。访问官方来源发生临时网络故障会持续退避，可Ctrl+C取消；不会关闭TLS校验或改用无校验镜像。显式工具仍须完成官方目标确认，不以离线旧锁假称最新版。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">四、只读检查与计划 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```powershell
# 校验工程结构和锁清单，只输出检查结果。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\部署\Windows\Deployment\【Windows】部署.ps1\【Windows】部署.ps1" -Check

# 审阅所选模式，不执行部署。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\部署\Windows\Deployment\【Windows】部署.ps1\【Windows】部署.ps1" -Plan -Mode local
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\部署\Windows\Deployment\【Windows】部署.ps1\【Windows】部署.ps1" -Plan -Mode server
```

`-Check` 和 `-Plan` 不联网、不写目录、日志或配置，不执行工具版本探针，不启动服务。它们可以在非交互环境审阅，成功退出不代表已验证 Windows 目标机的工具、权限或公网网络。`-Mode` 仅能配合 `-Plan`；正常部署必须经过 fzf，不支持用参数静默公开服务。

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">五、数据、缓存与配置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 位置或变量 | 行为 |
| --- | --- |
| `WB_RUNTIME_DIR/data/` | 默认业务数据；普通停止保留，完整反部署按备份／清零策略处理 |
| `WB_RUNTIME_DIR/keys/storage.key` | 默认加密密钥；反部署默认验证外置配对备份后清理源，不公开 |
| `WB_ENV_ROOT/Projects/RepairWorkbench/<工程标识>/Tools/` | 本项目独立工具缓存；按名称、版本与架构隔离，反部署只撤回登记范围 |
| `WB_RUNTIME_DIR/windows-deploy/日期 时间-随机值` | 每次新构建、脱敏日志和下载暂存；运行目录 ACL 限当前 Windows 账户访问 |
| `WB_RUNTIME_DIR/windows-deploy.lock` | 同工程入口的独占文件锁；程序退出后释放句柄，锁文件可以保留 |
| 项目专属机器缓存下 `GoCache/Modules/`、`GoCache/Build/` 与 `GoCache/Path/` | 本工程 Go 模块、构建及 GOPATH 缓存，仅本次子进程生效，按原点撤回 |
| `WB_RUNTIME_DIR/deploy-state-Windows/` | 首次部署原点、原产物副本、进程身份及私有存储配置，不公开或手工清空 |
| `WB_ADDR` | 默认 `127.0.0.1:8098`，只接受 `127.0.0.1`、`localhost` 或 `[::1]` 的有效端口 |
| `WB_DATA_DIR` / `WB_KEY_FILE` | 可覆盖数据与密钥路径；未指定密钥时，沿用数据目录父级的 `keys\storage.key` |
| `WB_WEB_DIR` / `WB_ADMIN_DIR` / `WB_ADMIN_FLUTTER_DIR` / `WB_CLIENT_FLUTTER_DIR` / `WB_ADMIN_CONTRACT_DIR` | 可覆盖现有前端与管理后台目录；默认按完整工程位置解析 |
| `WB_BACKUP_DIR` / `WB_BACKUP_INTERVAL_MINUTES` | 显式传给现有后端的备份配置 |
| `WB_TIDB_DSN` / `WB_REQUIRE_DB_TLS` | 仅已有明确数据库配置时沿用；默认使用项目现有本地文件存储，不要求购买云数据库 |
| `GOPROXY` | 已设置时仅在本次构建沿用；否则本次子进程使用 `https://goproxy.cn|https://proxy.golang.org|direct`，不执行全局 `go env -w` |

默认机器目录与覆盖规则见[环境说明](../../../README.md#machine-environment)。首次写入前保存原点和已有产物；后续部署沿用最初原点并拒绝覆盖已改变的产物。配对[反部署入口](../../Undeployment/README.md)按记录备份／清零数据并撤回新安装SDK和专属缓存，已有共享工具继续复用。

相对环境变量路径均以**工程根目录**解析，不依赖启动时所在目录。源码每次构建到本次运行目录，只有本次构建成功才启动；不会启动此前留下的旧程序。入口日志与子进程日志过滤邮箱、常见密码/Token/DSN 和 URL 凭据，仍应妥善保管运行目录，不向外分享密钥、连接配置或整套业务数据。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">六、停止与故障定位 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

保持终端打开；可反复在“打开网页”菜单选择地址，Esc只收起菜单，回车重新显示；按 Ctrl+C 停止。菜单等待期间仍监控本次后端和隧道，任一服务退出会结束菜单并清理本次会话。本入口使用 Windows Job Object 仅跟踪并回收本次启动的菜单、后端、隧道、构建和健康探针进程树，给予有限宽限后终止，不按端口或进程名批量杀进程，不删除数据、密钥或备份。后端退出、隧道退出、地址超时、构建失败或其它异常同样进入清理流程。

| 现象 | 处理 |
| --- | --- |
| 提示端口已有监听 | 先确认原程序；本入口不会复用或关闭它。停止原实例或设置另一个回环 `WB_ADDR` 后重试 |
| 下载失败或 SHA256 不符 | 查看本次 `deployment.log` 的官方来源、目标和错误；检查网络后重试，不运行未验证暂存文件 |
| Go 构建失败 | 查看本次 `build.log`，确认模块网络与完整工程；失败不会回退运行旧程序 |
| 缺少 NetTCPIP / 无法创建 Job Object | 当前 Windows 环境无法安全核实进程归属或管理生命周期，入口停止；换用完整受支持的原生 Windows 终端环境 |
| 后端健康检查失败 | 查看 `backend.log`；同时确认端口归属。即使其它程序返回 `/api/v38/healthz` 成功，也不会启动穿透 |
| 隧道退出或无实际 HTTPS 地址 | 查看 `tunnel.log`，检查出站网络；不要将模板地址当作成功结果 |
| 浏览器能访问，原生 App 不能访问 | 邮箱 PIN 模式需要浏览器，原生 App 不兼容；如需 App 联调，用独立合成资料并显式选择公开模式 |
| 移动网络能看页面，写操作刷新后丢失 | 页面可能正在使用演示回退，检查 API 根地址、服务端日志和真实请求，不以页面渲染判断部署成功 |

菜单、取消、打开失败和服务退出的隔离验证见[网页菜单验证说明](../../../../测试/部署/Windows/【Windows】验证网页菜单.ps1/README.md)。本包已做静态语法检查、只读计划检查与隔离模拟；当前开发环境为 MacOS，Windows 目标机的 Job Object、ACL、原生工具与真实公网连通性仍需在目标 Windows 实机验收。

当前公共工具与运行资料寻址见 [环境说明](../../../README.md#machine-environment)；入口与生命周期见 [本系统代码地图](../../代码地图/README.md)。

本机＋内网穿透属于临时运行：确认公网访问前和公网地址就绪后，运行日志都会醒目显示“关闭此运行终端，服务将结束”。支持颜色的终端使用红色加粗；`NO_COLOR`、`TERM=dumb` 或非交互输出使用纯文本，落盘日志不含颜色控制码。按 `Ctrl+C` 正常停止，业务数据和匹配密钥保留。




<!-- JOBS_TERMINAL_STYLE_V1:BEGIN -->

> Windows 终端配色保护：支持完整颜色查询的交互控制台会先保存当前会话默认前景、背景与16色色表，再临时使用黑底白字和统一强调色；正常结束、业务失败及可捕获中断后恢复。用户运行中自行改动的颜色保留并提示，不修改用户主题、共享 Profile、注册表或全局策略。快照不包含进入前任意叠加的临时文字样式。非控制台、重定向、`NO_COLOR`、Sourcetree 及无法可靠保存／恢复颜色的环境保持原状态或降级为纯文本。

> 强制结束进程或终端崩溃无法保证自动恢复。恢复失败时保留并提示本轮 `%TEMP%\JobsTerminalStyle-<PID>-*.ps1` 恢复脚本，需在原控制台核对后运行；不要通过重置用户配置恢复。`-ExecutionPolicy Bypass` 如被入口使用，仅作用于本次子进程，不持久修改策略。

> 验证范围：已完成 PowerShell 语法、参数／退出与隔离生命周期核验；Windows 原生控制台的显示、按键与 `Ctrl+C` 实机验证尚未完成。

<!-- JOBS_TERMINAL_STYLE_V1:END -->

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
