# <span id="前言">啄木鸟维修平台 · Go 服务端</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口与运行](#jobs-toc-heading-1)
- [二、检查与数据](#jobs-toc-heading-2)
  - [2.1、备份、恢复与反部署存储命令](#storage-maintenance)
- [三、本地部署＋内网穿透](#local-tunnel)

</details>
<!-- jobs-toc:end -->

服务接口为 `/api/v38`。一份通用服务代码供不同系统构建，不按平台复制。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、入口与运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

cmd/workbench负责服务启动、静态客户端、定时任务与备份恢复；internal/workbench负责业务权限、报价签署、履约、财务库存、账号审计及加密快照；MigrationsWorkbench是当前TiDB快照表资料。

最低资源预算：仅运行已构建服务＋文件存储按 2 核、项目可用内存 2 GiB、10 GiB 可用 SSD 准备；下方手工构建及根启动器按 2 核、项目可用内存 4 GiB、20 GiB 可用 SSD 准备。内存不含系统与其它软件占用；数值为少量合成数据的工程估算，未做最低资源或并发压测。整机内存、系统／架构、网络及 TiDB 要求见[最低机器配置](../../../部署/README.md#minimum-machine)。

Mac操作者从项目根双击启动器。手工构建在本目录运行：

```sh
# 使用对应系统部署入口，自动传入项目位置及独立运行资料路径。
# 仅构建时由操作者显式指定仓外目标文件：
go build -o /明确指定的仓外目录/workbench ./cmd/workbench
```

默认地址127.0.0.1:8098，仅回环合成演示。配置与密钥保护见 [总部署文档](../../../部署/README.md)。

| 路径 | 页面 |
| --- | --- |
| / | 维修协同工作台 |
| /admin/ | Web管理端 |
| /admin-flutter/ | Flutter管理端web构建目录 |
| /client-flutter/ | Flutter用户端web构建目录 |
| /admin-contract/admin-ui.json | 两管理端公共界面规范 |

Flutter未构建时对应入口返回503并提示构建。API仍走同源 /api/v38，避免本地浏览器跨源阻止请求。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、检查与数据 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```sh
python3 '../../../测试/后端/运行测试.py/运行测试.py' --run --race --vet
```

TiDB集成测试须独立WB_TEST_TIDB_DSN，未提供则明确跳过。HTTP流程从项目根运行node 测试/后端/接口/验证工作台.mjs。数据、密钥、附件和备份配套保管，不删除日常运行资料。当前17组已知P2见 [当前问题清单](../../../需求/当前问题清单/当前问题清单.md)；验收方法见 [测试与验收](../../../测试/测试与分级验收/测试与分级验收.md)。

### 2.1、<span id="storage-maintenance">备份、恢复与反部署存储命令</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运维命令使用部署时同一数据目录、匹配密钥及存储配置，不自动读取 `.env.example`。普通操作者从[配对反部署菜单](../../../部署/README.md#undeployment)选择数据处理，由脚本验证原点与停机状态后调用 CLI。

| 参数 | 当前能力与边界 |
| --- | --- |
| `-backup <新文件>` | 文件或 TiDB 模式生成可解密的应用加密备份、`.manifest.json` 摘要及存在时的同名 `.media/` 原件目录；拒绝覆盖，密钥另行成对保管，不含数据库拓扑、账号权限或系统表 |
| `-restore <备份> -restore-target <新目录>` | 仅文件模式隔离恢复；要求最新源与原密钥，合并当前授权、删除及审计约束，校验分块加密原件后原子发布，不覆盖在线数据 |
| `-clear-storage -confirm-clear-storage` | 停止所有该应用写入者后，明确清零当前 TiDB 的 `v38_workbench_snapshot` 中 `id=1`；事务锁定并核对 revision 与解密结果，不删除数据库、表结构、其它记录或账号 |
| `-clear-storage -confirm-clear-storage -clear-storage-backup <已验证备份>` | 默认备份策略使用：校验备份与匹配密钥，同一实例读取最新业务内容并与备份逐字比较，再按读取版本清零；备份后的新写入或版本冲突会拒绝清理，已为空且备份有效时允许幂等重试 |

设备原件与快照分开加密存储，默认目录及流式协议见[设备附件合同](../README.md#action-contract)。备份主文件、清单、原件旁件目录与匹配密钥必须成套保管；文件恢复后的旁件位于新目标 `order-media/`，不能沿用指向在线数据的 `WB_ORDER_MEDIA_DIR`。

清零缺少任一确认参数、未指定 TiDB，或与生成备份的 `-backup`／恢复参数混用时拒绝执行；`-clear-storage-backup` 只引用已经生成的备份，不能独立使用。文件清理由反部署脚本在数据选择及范围确认后完成；默认备份必须验证内容及匹配密钥，失败保留源数据。数据库事务桩、隔离文件回归与真实 TiDB 实机验收分别核对，不能因 CLI 已存在就视作完整数据库灾备通过。

## 三、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口提供可交互的双模式选择。正常运行先展示影响范围，回车授权本次项目内准备，再必须通过[**fzf**](https://github.com/junegunn/fzf)选择“本地部署＋内网穿透”或“服务器部署”；不是先装好一套云服务再开始。

| 本机平台 | 正常入口（先在终端进入项目根） | 详细步骤 |
| --- | --- | --- |
| MacOS | `/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'` | [本平台教程](../../../部署/MacOS/README.md#local-tunnel) |
| Windows | `& './部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1'` | [本平台教程](../../../部署/Windows/README.md#local-tunnel) |
| Ubuntu | `/bin/bash './部署/Ubuntu/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../../../部署/Ubuntu/README.md#local-tunnel) |
| Debian | `/bin/bash './部署/Debian/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../../../部署/Debian/README.md#local-tunnel) |
| RockyLinux | `/bin/bash './部署/RockyLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../../../部署/RockyLinux/README.md#local-tunnel) |
| AlibabaCloudLinux | `/bin/bash './部署/AlibabaCloudLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](../../../部署/AlibabaCloudLinux/README.md#local-tunnel) |

1、选择“本地部署＋内网穿透”：缺失或不兼容的Go、fzf、cloudflared按需从官方锁定来源准备到机器公共环境目录，先验证SHA256；健康已有工具复用，不升级已有系统工具。构建成功且本次子进程通过本机health后才连接免费Cloudflare Quick Tunnel，无需注册账号、购买域名或云主机。Quick只为本次子进程使用会话内空配置{}并清除继承的TUNNEL_*，不会改动本人已有cloudflared配置或父进程环境。首次下载和Go依赖需要网络；国内网络无法下载时会停止并给出日志，不跳过校验。系统还需自带基础下载／解压／校验工具（Shell需要curl、tar与shasum或sha256sum）；不会自动执行sudo、brew、apt、dnf或全局安装。来源清单见[锁定文件](../../../部署/deploy-tools.lock.tsv)。

2、本地模式默认进入“指定邮箱访问（浏览器）”，输入允许的邮箱（逗号分隔），也可由当前进程的 `WB_TUNNEL_ALLOWED_MAIL` 提供。cloudflared使用网页邮箱验证码限制访问，脚本不回显邮箱；原生App／普通API客户端无法完成该交互。若确需原生App联调，在子菜单明确选择“公开合成演示（原生App联调）”，再输入 `PUBLIC`；只允许合成资料。固定演示身份不是私人认证，随机网址也不能充当密码，不把真实客户数据接入此模式。

3、选择“服务器部署”：仅准备Go／fzf、构建并前台运行，保留 `127.0.0.1:8098` 和原有数据／密钥语义，不建立隧道，不购买机器，不自动配置反向代理、TLS、服务注册或防火墙。需要固定cpolar地址时先用该模式运行本机服务，再按本文可选cpolar步骤配置，避免同时建立两套公网入口。

4、Esc／空选取消，访问范围子菜单按←返回部署模式；选择阶段取消不会构建或启动业务，已经校验好的fzf缓存和本次诊断日志可保留。初始说明前没有写入；确认后才允许机器公共环境缓存、构建和日志。Go路径可用 `GO_BIN` 指定，fzf／cloudflared可用 `WB_FZF_BIN`／`WB_CLOUDFLARED_BIN` 指向本人已核验工具；不需要修改全局PATH。默认文件模式须确保未误设 `WB_TIDB_DSN`；既有数据库用户保留自己的已核验配置，不把切换为空值当作数据迁移。

`--check`／`--plan`（PowerShell为 `-Check`／`-Plan`）是结构和计划检查，不能代替实机部署验收；模式参数只供计划审阅，正常入口不能用它跳过fzf。

5、终端保持运行，Quick Tunnel每个项目获得自己的随机HTTPS地址；维修8098与学术8080分别用各自部署入口启动，不共用一个服务端口。URL仅表示取得入口，必须完成本节外网验收。Quick官方没有可用性保证，最多200个在途请求且不支持SSE；中国大陆不同运营商可达性另行实测。固定地址可选择下方cpolar或自有域名命名Tunnel，不能把Quick地址写成长期生产入口。[Quick限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

6、Ctrl+C停止本次后端和本次隧道；任一子进程异常或隧道没有及时取得地址时也会回收另一方，保留数据。脚本先检查目标TCP端口，不复用或停止已有服务；只记录并终止本次PID，不使用killall／按名字批量结束。Shell取得地址默认限45秒，可在本次进程设置 `WB_TUNNEL_START_TIMEOUT=90`（1..600）；应用构建耗时不计入此地址等待。日志位置在终端显示：Shell主日志位于系统临时目录，本次后端日志写入其中，隧道日志位于本项目独立 Runtime 下的 `deploy-session.*`；Windows路径以其入口提示为准。日志可能含公网地址，分享前脱敏；不把邮箱、令牌、数据密钥写进README或提交仓库。

两项目均可默认文件存储，维修使用独立数据和密钥，学术使用自己的文件目录；网页、API和文件下载各自整站同源，保留公网Host，不加Host rewrite，不把API填成手机自己的127.0.0.1。两个项目的API失败会回退本地演示，必须在移动网络验证公网health、登录、新建合成记录→刷新重读、附件上传／权限拒绝，页面打开或假数据能操作不能算成功。

需要国内固定地址时可选[**cpolar**](https://www.cpolar.com/pricing)：当前公开免费档1Mbps／随机地址，基础99元年2Mbps／3个保留子域名，专业149元年3Mbps且支持自有域名；实际资格和价格以官网为准。一个客户端进程可显式启动repair和academic两条HTTP隧道，先读[详细平台教程](../../../部署/README.md#local-tunnel)中的完整YAML、固定子域名／地区和Host要求，再执行；不使用启动全部SSH／远程桌面样例的命令，已有GUI／服务不再重复开一个客户端。

电脑睡眠、合盖、重启或断网会中断访问；可由使用者选择保持接电唤醒，不执行全局电源策略。停止后用全新公网health／API请求确认撤回，旧页面仍可能显示缓存／本地演示；固定域名预留、DNS、订阅和自行注册的后台常驻项另行撤销，保留数据／密钥／附件／备份。平台工具、完整可选双隧道命令、外网验收和故障排查见[本系统详细教程](../../../部署/README.md#local-tunnel)。

目标系统的真实依赖、启动与公网业务需按 [测试与验收](../../../测试/测试与分级验收/测试与分级验收.md) 执行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

本工程定位见 [代码地图](./代码地图/README.md)，机器目录与手工启动配置见 [环境说明](../../../部署/README.md#machine-environment)。

配置字段见 [.env.example](./.env.example)。程序与部署入口不会自动读取该文件，须在当前终端或部署环境显式传入；空字段沿用真实入口默认值，真实数据库地址、凭据和邮箱由运行者另行安全配置。
