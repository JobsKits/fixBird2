# [**MacOS**](https://www.apple.com/macos/) 部署入口

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与范围](#entries)
  - [1.1、最低支持的机器配置](#minimum-machine)
- [二、本地部署＋内网穿透](#local-tunnel)

</details>
<!-- jobs-toc:end -->

---

**部署快捷入口：** 可在本系统目录直接双击 [【MacOS】双击部署（快捷入口）.command](../【MacOS】双击部署（快捷入口）.command)；它调用本目录下的规范部署实现，复用同一自述、确认与参数，不另存部署逻辑。

## 🔥 <span id="前言">前言</span>

这里保留现有本机启动脚本。它构建项目内服务并以前台进程运行，不负责系统服务安装或生产发布。

## 一、<span id="entries">入口与范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

现有入口：[启动工作台](【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command)；参数、交互、日志及风险见 [脚本 README](【MacOS】启动维修工作台.command/README.md)。运行数据保留在本项目独立 Runtime，不放入部署目录；路径规则见[机器环境与运行资料](../../README.md#machine-environment)。

返回 [本系统部署文档](../README.md)，或查看 [配对反部署](../Undeployment/README.md)。

### 1.1、<span id="minimum-machine">最低支持的机器配置</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 场景 | 最低资源预算 |
| --- | --- |
| 已构建服务＋文件存储 | 2 核，项目可用内存 2 GiB，10 GiB 可用 SSD |
| 本机从源码构建并运行 | 2 核，项目可用内存 4 GiB，20 GiB 可用 SSD；当前脚本每次构建，必须按此档准备 |
| 同机 TiDB unistore 演示 | 4 核，项目可用内存 8 GiB，40 GiB 可用 SSD；整机 RAM 至少 16 GiB |

整机至少 8 GiB；只运行时项目可用至少 2 GiB，脚本构建时至少 4 GiB。MacOS 13 或以上（随附 Go 1.27.2 的工具链门槛）；Apple Silicon 64 位；Intel Mac可由入口按需准备darwin-amd64工具并构建，尚未实机验收。网络仅本机回环，无公网带宽下限；首次获取依赖需联网，无需独立显卡。上述为少量合成数据的工程预算，未做最低资源或并发压测，不代表正式生产支持；备份、容器额外开销与本系统验收边界见[本系统最低配置](../README.md#minimum-machine)。

## 二、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口提供可交互的双模式选择。正常运行先展示影响范围，回车授权本次项目内准备，再必须通过[**fzf**](https://github.com/junegunn/fzf)选择“本地部署＋内网穿透”或“服务器部署”；不是先装好一套云服务再开始。

模式选择前只读复用健康 fzf；缺失时按锁清单校验并下载到本次会话的 `RUN_DIR/bootstrap-environment`，不改动旧部署的项目专属工具缓存。临时选择器随本次会话登记原点与资源清单；取消可保留本次记录，旧实例继续运行。

在终端进入本文所在目录后执行下面的本系统入口；脚本从自身位置定位项目，支持中文／空格及项目迁移，不依赖调用时的工作目录。可从本系统目录双击 `【MacOS】双击部署（快捷入口）.command`，或在终端使用 zsh 运行包内脚本。

```zsh
/bin/zsh './【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'
```

- 选择“本地部署＋内网穿透”：模式确认后查询Go／fzf／本地模式cloudflared的官方最新稳定版；已有工具仅在实际版本不低于目标且功能健康时复用，否则按官方摘要校验下载到项目专属机器缓存，不覆盖系统或显式路径文件。构建成功且本次子进程通过本机health后才连接免费Cloudflare Quick Tunnel，无需注册账号、购买域名或云主机。Quick只为本次子进程使用会话内空配置{}并清除继承的TUNNEL_*，不会改动本人已有cloudflared配置或父进程环境。首次下载和Go依赖需要网络；临时网络故障持续退避重试，Ctrl+C可取消；来源、摘要或参数错误明确停止，不跳过校验。系统还需自带基础下载／解压／校验工具（Shell需要curl、tar与shasum或sha256sum）；不会自动执行sudo、brew、apt、dnf或全局安装。来源清单见[锁定文件](../../deploy-tools.lock.tsv)。

- 本地模式直接采用公开演示／App 联调：选择模式后说明公开范围，按回车继续，其他输入或输入结束取消；不再选择“外网访问方式”、填写邮箱或输入 `PUBLIC`，也不使用继承的 `WB_TUNNEL_ALLOWED_MAIL` 加回邮箱门禁。取得链接的人都能到达服务入口，业务登录和权限继续按现有实现执行；仅使用合成资料，固定演示身份与随机网址不能充当私人认证，不接入真实客户数据。此简化仅适用于 MacOS，其他系统仍按各自文档操作。

- 选择“服务器部署”：仅准备Go／fzf、构建并前台运行，保留 `127.0.0.1:8098` 和原有数据／密钥语义，不建立隧道，不购买机器，不自动配置反向代理、TLS、服务注册或防火墙。需要固定cpolar地址时先用该模式运行本机服务，再按本文可选cpolar步骤配置，避免同时建立两套公网入口。

- fzf 使用 `↑`／`↓` 与回车选择，`Esc`／空选取消；自述、模式选择及本地公开确认取消均保留旧实例，不构建或启动新业务，已经校验好的 fzf 缓存和本次诊断日志可保留。确认重启后才按登记身份接管本项目旧实例；后续失败不承诺自动恢复旧实例。初始说明前没有业务写入；Go 路径可用 `GO_BIN` 指定，fzf／cloudflared 可用 `WB_FZF_BIN`／`WB_CLOUDFLARED_BIN` 指向本人已核验工具，不需要修改全局 PATH。默认文件模式须确保未误设 `WB_TIDB_DSN`；既有数据库用户保留自己的已核验配置，不把切换为空值当作数据迁移。

只读审阅（不会下载、写缓存／配置／日志、构建、启动后端或连接公网）：

```zsh
/bin/zsh './【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command' --check
/bin/zsh './【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command' --plan --mode local
```

`--check`／`--plan`（PowerShell为 `-Check`／`-Plan`）是结构和计划检查，不能代替实机部署验收；模式参数只供计划审阅，正常入口不能用它跳过fzf。

- 取得本次公网地址后自动显示“打开网页”fzf菜单；选择公网或本机地址并回车，即交给默认浏览器打开，随后回到菜单继续选择。终端和服务保持运行；Esc或“收起菜单”仅收起菜单，回到原终端按回车可重新显示。服务器模式只列本机地址。Quick Tunnel每个项目获得自己的随机HTTPS地址；维修8098与学术8080分别用各自部署入口启动，不共用一个服务端口。URL仅表示取得入口，必须完成本节外网验收。Quick官方没有可用性保证，最多200个在途请求且不支持SSE；中国大陆不同运营商可达性另行实测。固定地址可选择下方cpolar或自有域名命名Tunnel，不能把Quick地址写成长期生产入口。[Quick限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

- `Ctrl+C`、关窗及任一子进程异常时回收本次后端和隧道，保留数据、密钥、配置及首轮原点。独立守护处理入口或终端父进程异常退出；再次部署只接管身份可核验的本项目旧实例，等待退出、封存及解锁后再启动，未知归属或正在反部署时保留并报告，其他服务占用端口时停止并报告。不会使用 `killall` 或按名字、端口批量结束进程。隧道取得地址默认限45秒，可在本次进程设置 `WB_TUNNEL_START_TIMEOUT=90`（1..600）；应用构建耗时不计入此地址等待。日志位置在终端显示：主日志位于系统临时目录，本次后端日志写入其中，隧道日志位于本项目独立 Runtime 下的 `deploy-session.*`。日志可能含公网地址，分享前脱敏，不把令牌或数据密钥写进 README 或提交仓库。

两项目均可默认文件存储，维修使用独立数据和密钥，学术使用自己的文件目录；网页、API和文件下载各自整站同源，保留公网Host，不加Host rewrite，不把API填成手机自己的127.0.0.1。两个项目的API失败会回退本地演示，必须在移动网络验证公网health、登录、新建合成记录→刷新重读、附件上传／权限拒绝，页面打开或假数据能操作不能算成功。

需要国内固定地址时可选[**cpolar**](https://www.cpolar.com/pricing)：当前公开免费档1Mbps／随机地址，基础99元年2Mbps／3个保留子域名，专业149元年3Mbps且支持自有域名；实际资格和价格以官网为准。一个客户端进程可显式启动repair和academic两条HTTP隧道，先读[详细平台教程](../README.md#local-tunnel)中的完整YAML、固定子域名／地区和Host要求，再执行；不使用启动全部SSH／远程桌面样例的命令，已有GUI／服务不再重复开一个客户端。

电脑睡眠、合盖、重启或断网会中断访问；可由使用者选择保持接电唤醒，不执行全局电源策略。停止后用全新公网health／API请求确认撤回，旧页面仍可能显示缓存／本地演示；固定域名预留、DNS、订阅和自行注册的后台常驻项另行撤销，保留数据／密钥／附件／备份。平台工具、完整可选双隧道命令、外网验收和故障排查见[本系统详细教程](../README.md#local-tunnel)。

真实依赖安装、公网连接和本系统业务穿透需在目标环境完成验收。



首次部署在 Runtime 的 `deploy-state/` 保存原程序及项目专属环境原件、指纹与进程身份；重复部署不覆盖首轮原点。已有共享工具仅在版本与功能达标时复用，新工具、下载与Go缓存写入机器环境 `Projects/RepairWorkbench/<项目标识>/` 下的 `Tools/`、`Downloads/`、`GoCache/`，以便按归属完整撤回。配套[反部署入口](../Undeployment/README.md)恢复原件并处理数据；未记录原点的旧部署不会推测删除共享SDK。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>


当前公共工具与运行资料寻址见 [环境说明](../../README.md#machine-environment)；入口与生命周期见 [本系统代码地图](../代码地图/README.md)。
