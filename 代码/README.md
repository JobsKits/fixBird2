# 代码目录

![项目图标](../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、目录职责](#contents)
- [二、开发单元导航](#unit-code-maps)
  - [2.1、前端与后端单元导航](#jobs-toc-heading-4)
  - [2.2、部署单元导航](#jobs-toc-heading-5)
- [三、零基础使用说明](#usage-guide)
  - [3.1、五分钟进入工作台](#jobs-toc-heading-7)
  - [3.2、按角色走一次维修流程](#jobs-toc-heading-8)
  - [3.3、认识页面提示](#jobs-toc-heading-9)
  - [3.4、选择手机端或另一套管理端](#jobs-toc-heading-10)
  - [3.5、停止、备份与求助](#jobs-toc-heading-11)
  - [3.6、本地部署＋内网穿透](#local-tunnel)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录按前端、后端分工；部署入口在项目根的独立 `部署/` 中维护。每个具体端／语言工程及操作系统部署单元维护自己的代码地图，上级只提供导航。

## 一、<span id="contents">目录职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [前端](./前端/README.md)：PC Web、移动端、后台管理端、微信小程序及共享组件。
- [后端](./后端/README.md)：[接口契约](./后端/README.md#api-contract)与 Go 后端实现。
- [部署](../部署/README.md)：各目标机器／系统的环境准备及部署入口。
- [开发单元导航](#unit-code-maps)与[零基础使用说明](#usage-guide)：分别定位具体工程及体验演示流程。

公共 SDK、包管理器依赖和机器缓存由目标机器管理；项目保留源码、声明、锁文件、配置和准备入口。明确登记的私库及发布包必要运行依赖分别说明。

## 二、<span id="unit-code-maps">开发单元导航</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

每份代码地图只锚定一个独立开发单元，具体文件、符号、职责及就近测试在单元内维护；跨单元合作通过接口、共享包或相对链接说明。

### <span id="jobs-toc-heading-4" data-jobs-toc="v2">2.1、前端与后端单元导航 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- [PC Web 代码地图](./前端/PC端/Web/代码地图/README.md)
- [移动 Flutter 代码地图](./前端/移动端/Flutter/代码地图/README.md)
- [iOS 工程与代码地图](./前端/移动端/iOS/README.md#ios-map)
- [MacOS 原生桌面](./前端/PC端/MacOS/README.md)
- [WindowsOS 原生桌面](./前端/PC端/WindowsOS/README.md)
- [Android 代码地图](./前端/移动端/Android/代码地图/README.md)
- [鸿蒙 代码地图](./前端/移动端/鸿蒙/代码地图/README.md)
- [微信小程序 代码地图](./前端/微信小程序/代码地图/README.md)
- [后台 Web 代码地图](./前端/后台管理端/Web/代码地图/README.md)
- [后台 Flutter 代码地图](./前端/后台管理端/Flutter/代码地图/README.md)
- [共享 Flutter 代码地图](./前端/共享组件/Flutter/代码地图/README.md)
- [Go 后端 代码地图](./后端/后端代码/代码地图/README.md)

### <span id="jobs-toc-heading-5" data-jobs-toc="v2">2.2、部署单元导航 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- [MacOS 部署地图](../部署/MacOS/代码地图/README.md)
- [Windows 部署地图](../部署/Windows/代码地图/README.md)
- [Ubuntu 部署地图](../部署/Ubuntu/代码地图/README.md)
- [Debian 部署地图](../部署/Debian/代码地图/README.md)
- [RockyLinux 部署地图](../部署/RockyLinux/代码地图/README.md)
- [AlibabaCloudLinux 部署地图](../部署/AlibabaCloudLinux/代码地图/README.md)

[**CodeGraph**](https://github.com/colbymchenry/codegraph) 的 `.codegraph/` 索引与 `codegraph.json` 配置只放在具体代码开发单元内；项目根及本目录只负责导航。先选定上方具体端／语言工程，再以该单元路径查询和同步索引；单元尚无索引时使用就近地图及局部搜索，不在上层初始化混合索引。

当前 CodeGraph 不解析部署入口使用的 Shell／PowerShell；这些脚本按上方操作系统地图和局部搜索定位，不创建空索引。

## 三、<span id="usage-guide">零基础使用说明</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这份说明先教你体验流程，不要求你理解代码。第一次请只填写虚构资料；Demo 后台管理员为 `admin / 1234`，其它合成角色密码为 `Demo-Repair-2026!`。

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">3.1、五分钟进入工作台 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

最低机器准备：当前 Mac 启动器会先编译，按至少 2 核、8 GiB 整机 RAM（其中至少 4 GiB 留给项目）、20 GiB 可用 SSD 准备；当前 Mac 启动器的工具目标为 MacOS 13 或以上的 Apple Silicon 电脑；工具链在目标机器准备，不随项目打包。仅运行已构建后端可按 2 核、项目可用内存 2 GiB、10 GiB 可用 SSD 准备，MacOS 整机仍至少 8 GiB。以上为工程预算，尚未完成最低资源压测；其它系统、数据库与容量边界见[最低机器配置](../部署/README.md#minimum-machine)。

- 把完整项目文件夹放在电脑上，不要单独移动里面的程序或资源。

- 在 Mac 打开 [部署快捷入口](../部署/MacOS/【MacOS】双击部署（快捷入口）.command) 并运行，阅读影响后回车，用fzf选择“本地部署＋内网穿透”或“服务器部署”。只想本机用可选服务器模式；想让指定朋友浏览器看可选本地模式并填允许邮箱。缺失工具按锁定来源准备到当前机器的公共工具目录，终端保留运行；其它平台入口见下方本地部署章节。

- 浏览器进入 [管理工作台](http://127.0.0.1:8098/admin/)。服务端明确声明 Demo 时自动以管理员进入；正式或无法识别的环境必须先登录。

- 左边是功能入口：概览看当前数量，工单办理维修，库存借还登记配件，采购登记和分批收货，设置连接服务及寄送信息。手机窄屏导航位于页面顶部，可以横向滑动。

- 点工单卡片进入详情。“当前可办理”随角色和工单阶段变化。填写表单后点“确认提交”；出错时保留表单，按提示修改。

首次运行会按需下载并校验缺失工具到机器公共工具目录，可用 `WB_ENV_ROOT` 指定位置；SDK、依赖缓存与运行资料不放进项目源码，运行资料位置由 `WB_RUNTIME_DIR` 管理。下载失败时保留终端提示与脱敏日志，让技术同事核对网络和基础工具，不跳过SHA校验。也可使用[根README的纯网页演示](../README.md#startup)，该预览不代表后端已上线。

### <span id="jobs-toc-heading-8" data-jobs-toc="v2">3.2、按角色走一次维修流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 步骤 | 使用账号 | 点击与填写 |
| --- | --- | --- |
| 报修 | `customer` | 新建工单，选择寄修／上门，填写设备、位置和故障 |
| 受理 | `admin` 或 `dispatcher` | 打开工单，受理并指定 `dispatcher` 和 `engineer` |
| 检测报价 | `engineer`、`admin` | 按阶段开始检测、填写报告和报价范围、金额、有效期 |
| 公司确认 | `admin` | 批准当前报价版本 |
| 客户确认 | `customer` | 阅读报价，实际手写签名并提交；改价后需要重新签署 |
| 维修质检 | `engineer`、`qc` | 开始维修、维修完成、质检；有先款约定须先完成核款 |
| 交付验收 | 调度／客户 | 填写实际交付依据，再由客户实际手写验收 |
| 结算 | `finance` | 录收款或退款、核实、内部交接；按约定处理资料和发票 |
| 完结 | `admin` | 清理余项、异议、借用、款项与发票缺项后整单完结 |

同一次登录只代表一个身份。点击“退出”后再换账号；服务器会拒绝越权或不合阶段的操作。工单详情里的记录编号可用于核款、交接、解决异议等后续表单。原有 [维修协同工作台](http://127.0.0.1:8098/) 提供更成熟的专项业务交互，可与新增端使用同一服务。

### <span id="jobs-toc-heading-9" data-jobs-toc="v2">3.3、认识页面提示 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 提示 | 含义与处理 |
| --- | --- |
| 服务端数据 | 当前资料来自已登录的服务器 |
| 独立合成演示 | 连接不可用，当前操作只影响本地虚构副本，不会自动补传 |
| 暂时没有记录 | 当前身份／筛选没有数据，清空筛选或点重新加载 |
| 提交结果尚未确认 | 请求可能已经到达服务器，保留表单并原样重试，不要另建一笔 |
| 版本冲突 | 别人已修改此单，重载详情并核对后再办理 |
| 登录失效／权限不足 | 重新登录或找负责人确认职责，不能当作演示成功 |
| 服务地址切换 | 测试和线上分别保存；切换会退出原会话，旧环境资料不会混入 |

刷新可重新连接服务器；成功后以服务器数据替换演示视图。新端并非每个复杂动作都能离线模拟，明确提示“请连接服务端”时需先恢复服务。

### <span id="jobs-toc-heading-10" data-jobs-toc="v2">3.4、选择手机端或另一套管理端 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

普通使用者应让技术同事提供已安装应用或安装包；源码工程需先经过对应工具编译，不能把工程文件夹当安装包点开。

| 想用什么 | 交给技术同事的入口 |
| --- | --- |
| Flutter 管理端 | [导入和运行](./前端/后台管理端/Flutter/README.md)，与 Web 管理端使用共同界面规范 |
| Flutter 用户／工程师端 | [导入和运行](./前端/移动端/Flutter/README.md) |
| 原生 iPhone 端 | [Xcode workspace 与运行](./前端/移动端/iOS/README.md) |
| 原生 Android 端 | [Android Studio 导入](./前端/移动端/Android/README.md) |
| 原生鸿蒙端 | [DevEco Studio 导入](./前端/移动端/鸿蒙/README.md)，SDK 与设备验收边界见交付清单 |
| 微信小程序 | [微信开发者工具导入与体验步骤](./前端/微信小程序/README.md#status)，须提供本项目体验版本；源码存在不代表已经发布 |

电脑上的 `127.0.0.1` 是电脑自己，手机上的相同地址是手机自己。当前演示后端只允许电脑回环监听，不能简单把地址改为电脑 Wi-Fi IP 就期待连接成功。iOS 模拟器可连接 Mac 的本机服务；Android USB 调试可由技术同事执行 `adb reverse tcp:8098 tcp:8098` 后使用手机回环地址。模拟器还可按其网络映射访问宿主。跨设备正式使用需单独部署可信 HTTPS 服务，再在端侧设置服务根地址。

两套管理端的表单、导航和设计值来自同一个规范；浏览器与 Flutter 的字体、控件渲染仍需视觉对照验收，不能凭源码相同宣称逐像素完全一致。

### <span id="jobs-toc-heading-11" data-jobs-toc="v2">3.5、停止、备份与求助 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

停止：回启动终端按 `Ctrl+C`。重开：再次双击启动入口。端口被占用时先确认是否已有本项目服务运行，不要随意结束别的程序。

资料：默认在机器专属 `WB_RUNTIME_DIR`；加密密钥与数据必须配套备份。不要把演示账号、真实客户附件或密钥发到群聊／代码仓。

求助时提供：正在用哪个端、选择哪个角色、工单号、点击哪个按钮、完整提示和截图。不要只说“点不了”。当前问题见 [问题清单](../需求/当前问题清单/当前问题清单.md)，各端能力与设备边界见 [交付清单](../需求/交付与运维清单/交付与运维清单.md)。

### 3.6、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口提供可交互的双模式选择。正常运行先展示影响范围，回车授权本次项目内准备，再必须通过[**fzf**](https://github.com/junegunn/fzf)选择“本地部署＋内网穿透”或“服务器部署”；不是先装好一套云服务再开始。

| 本机平台 | 正常入口（先在终端进入项目根） | 详细步骤 |
| --- | --- | --- |
| MacOS | `/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'` | [本平台教程](../部署/MacOS/README.md#local-tunnel) |
| Windows | `& './部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1'` | [本平台教程](../部署/Windows/README.md#local-tunnel) |
| Ubuntu | `/bin/bash './部署/Ubuntu/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../部署/Ubuntu/README.md#local-tunnel) |
| Debian | `/bin/bash './部署/Debian/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../部署/Debian/README.md#local-tunnel) |
| RockyLinux | `/bin/bash './部署/RockyLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../部署/RockyLinux/README.md#local-tunnel) |
| AlibabaCloudLinux | `/bin/bash './部署/AlibabaCloudLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../部署/AlibabaCloudLinux/README.md#local-tunnel) |

- 选择“本地部署＋内网穿透”：缺失或不兼容的Go、fzf、cloudflared按需从官方锁定来源准备到当前机器 `WB_ENV_ROOT` 管理的公共工具目录，先验证SHA256；健康已有工具复用，不升级已有系统工具。构建成功且本次子进程通过本机health后才连接免费Cloudflare Quick Tunnel，无需注册账号、购买域名或云主机。Quick只为本次子进程使用会话内空配置{}并清除继承的TUNNEL_*，不会改动本人已有cloudflared配置或父进程环境。首次下载和Go依赖需要网络；国内网络无法下载时会停止并给出日志，不跳过校验。系统还需自带基础下载／解压／校验工具（Shell需要curl、tar与shasum或sha256sum）；不会自动执行sudo、brew、apt、dnf或全局安装。来源清单见[锁定文件](../部署/deploy-tools.lock.tsv)。

- 本地模式默认进入“指定邮箱访问（浏览器）”，输入允许的邮箱（逗号分隔），也可由当前进程的 `WB_TUNNEL_ALLOWED_MAIL` 提供。cloudflared使用网页邮箱验证码限制访问，脚本不回显邮箱；原生App／普通API客户端无法完成该交互。若确需原生App联调，在子菜单明确选择“公开合成演示（原生App联调）”，再输入 `PUBLIC`；只允许合成资料。固定演示身份不是私人认证，随机网址也不能充当密码，不把真实客户数据接入此模式。

- 选择“服务器部署”：仅准备Go／fzf、构建并前台运行，保留 `127.0.0.1:8098` 和原有数据／密钥语义，不建立隧道，不购买机器，不自动配置反向代理、TLS、服务注册或防火墙。需要固定cpolar地址时先用该模式运行本机服务，再按本文可选cpolar步骤配置，避免同时建立两套公网入口。

- Esc／空选取消，访问范围子菜单按←返回部署模式；选择阶段取消不会构建或启动业务，已经校验好的fzf缓存和本次诊断日志可保留。初始说明前没有写入；确认后才向公共工具缓存和机器运行目录写入工具、构建产物与日志。Go路径可用 `GO_BIN` 指定，fzf／cloudflared可用 `WB_FZF_BIN`／`WB_CLOUDFLARED_BIN` 指向本人已核验工具；不需要修改全局PATH。默认文件模式须确保未误设 `WB_TIDB_DSN`；既有数据库用户保留自己的已核验配置，不把切换为空值当作数据迁移。

`--check`／`--plan`（PowerShell为 `-Check`／`-Plan`）是结构和计划检查，不能代替实机部署验收；模式参数只供计划审阅，正常入口不能用它跳过fzf。

- 终端保持运行，Quick Tunnel每个项目获得自己的随机HTTPS地址；维修8098与学术8080分别用各自部署入口启动，不共用一个服务端口。URL仅表示取得入口，必须完成本节外网验收。Quick官方没有可用性保证，最多200个在途请求且不支持SSE；中国大陆不同运营商可达性另行实测。固定地址可选择下方cpolar或自有域名命名Tunnel，不能把Quick地址写成长期生产入口。[Quick限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

- Ctrl+C停止本次后端和本次隧道；任一子进程异常或隧道没有及时取得地址时也会回收另一方，保留数据。脚本先检查目标TCP端口，不复用或停止已有服务；只记录并终止本次PID，不使用killall／按名字批量结束。Shell取得地址默认限45秒，可在本次进程设置 `WB_TUNNEL_START_TIMEOUT=90`（1..600）；应用构建耗时不计入此地址等待。日志位置在终端显示：Shell主日志位于系统临时目录，本次后端日志写入其中，隧道日志位于机器专属 `WB_RUNTIME_DIR` 的本次会话目录；Windows路径以其入口提示为准。日志可能含公网地址，分享前脱敏；不把邮箱、令牌、数据密钥写进README或提交仓库。

两项目均可默认文件存储，维修使用独立数据和密钥，学术使用自己的文件目录；网页、API和文件下载各自整站同源，保留公网Host，不加Host rewrite，不把API填成手机自己的127.0.0.1。两个项目的API失败会回退本地演示，必须在移动网络验证公网health、登录、新建合成记录→刷新重读、附件上传／权限拒绝，页面打开或假数据能操作不能算成功。

需要国内固定地址时可选[**cpolar**](https://www.cpolar.com/pricing)：当前公开免费档1Mbps／随机地址，基础99元年2Mbps／3个保留子域名，专业149元年3Mbps且支持自有域名；实际资格和价格以官网为准。一个客户端进程可显式启动repair和academic两条HTTP隧道，先读[详细平台教程](../部署/README.md#local-tunnel)中的完整YAML、固定子域名／地区和Host要求，再执行；不使用启动全部SSH／远程桌面样例的命令，已有GUI／服务不再重复开一个客户端。

电脑睡眠、合盖、重启或断网会中断访问；可由使用者选择保持接电唤醒，不执行全局电源策略。停止后用全新公网health／API请求确认撤回，旧页面仍可能显示缓存／本地演示；固定域名预留、DNS、订阅和自行注册的后台常驻项另行撤销，保留数据／密钥／附件／备份。平台工具、完整可选双隧道命令、外网验收和故障排查见[本系统详细教程](../部署/README.md#local-tunnel)。

当前已完成脚本语法、只读检查及隔离假工具测试；没有实际安装工具、连接真实公网或在本系统完成真实业务穿透验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
