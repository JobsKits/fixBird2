# 啄木鸟维修平台 V3.8 部署指南

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、系统入口与目录职责](#systems)
  - [1.1、源码与数据约定](#policy)
  - [1.2、配对反部署入口与操作](#undeployment)
  - [1.3、各端访问地址与扫码入口](#access-qr)
- [二、选择部署路线](#routes)
  - [2.1、最低支持的机器配置](#minimum-machine)
- [三、机器环境说明](#machine-environment)
  - [3.1、机器目录与覆盖参数](#machine-paths)
  - [3.2、SDK 与数据分别管理](#sdk-and-data)
  - [3.3、静态资料与验证边界](#static-boundaries)
  - [3.4、SDK 来源记录](#sdk-provenance)
  - [3.5、工具更新与业务依赖检查](#tool-updates)
- [四、MacOS 本机启动](#macos)
  - [4.1、执行前检查](#preflight)
  - [4.2、双击或终端启动](#quick-start)
  - [4.3、健康检查与登录](#health-login)
- [五、配置、路径与持久化](#configuration)
  - [5.1、读取权限、审计与容量](#reading-audit-capacity)
  - [5.2、先款、验收原件与质保日期](#payment-acceptance-calendar)
- [六、可选 TiDB 本机演示](#tidb)
  - [6.1、准备专用演示数据库](#tidb-container)
  - [6.2、创建数据库并连接](#tidb-connect)
  - [6.3、数据库加密连接边界](#database-tls)
- [七、Windows、Linux 与离线预览](#other-platforms)
  - [7.1、Linux 前台运行](#linux)
  - [7.2、Windows PowerShell 前台运行](#windows)
  - [7.3、纯界面离线预览与数据回退](#offline)
- [八、备份与隔离恢复](#backup)
  - [8.1、定时备份](#scheduled-backup)
  - [8.2、文件模式人工备份](#manual-backup)
  - [8.3、文件模式隔离恢复](#isolated-restore)
- [九、升级、停止与项目移动](#maintenance)
- [十、日志与故障排查](#troubleshooting)
- [十一、验收入口与正式部署条件](#verification)
- [十二、多端静态客户端](#new-clients)
- [十三、本地部署＋内网穿透](#local-tunnel)
  - [13.1、运行结构、资源和费用](#jobs-toc-heading-38)
  - [13.2、按平台准备工具](#jobs-toc-heading-39)
  - [13.3、先启动本机应用并检查](#jobs-toc-heading-40)
  - [13.4、可选cpolar：用一个客户端映射两个项目](#jobs-toc-heading-41)
  - [13.5、保留固定HTTPS地址与同源设置](#jobs-toc-heading-42)
  - [13.6、Cloudflare手工诊断与固定域名](#jobs-toc-heading-43)
  - [13.7、从手机外网验收真实请求](#jobs-toc-heading-44)
  - [13.8、日志、在线时间与停止](#jobs-toc-heading-45)
  - [13.9、常见故障与验证边界](#jobs-toc-heading-46)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本指南对应 `代码/后端/后端代码/cmd/workbench` 和各客户端，适用于第一阶段本机合成演示。后端使用 [**Go**](https://go.dev/)，默认加密文件快照，可选 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 适配。完整目录见 [根说明](../README.md#directory)，平台入口见 [系统部署索引](#systems)。

部署前核对 [实现范围](../需求/技术方案与实现范围/技术方案与实现范围.md)、[交付清单](../需求/交付与运维清单/交付与运维清单.md) 和 [当前问题清单](../需求/当前问题清单/当前问题清单.md)。各端及目标系统的构建、设备业务和正式发布分别验收，见 [测试与验收](../测试/测试与分级验收/测试与分级验收.md)。普通使用者先看 [零基础说明](../代码/README.md#usage-guide)。

**最快运行方式**：在 `MacOS/` 文件夹中双击 [MacOS 部署快捷入口](./MacOS/【MacOS】双击部署（快捷入口）.command)，阅读自述并按回车，按菜单选择部署方式。启动成功后在“打开网页”[**fzf**](https://formulae.brew.sh/formula/fzf)菜单选择本次公网地址或本机地址，回车交给默认浏览器打开；打开后菜单继续保留，可反复选，不需要复制或输入网址。终端保持运行，停止服务按 `Ctrl+C`。

本文档的文件链接以当前 `部署/` 目录为基准；下文命令除另有说明外，均从项目根目录执行。在本文件所在目录打开终端时，先执行 `cd ..`；路径包含中文或空格时保留引号。

[选择路线](#routes) · [MacOS 启动](#macos) · [配置与数据](#configuration) · [TiDB](#tidb) · [Windows／Linux](#other-platforms) · [备份恢复](#backup) · [升级与停止](#maintenance) · [排查](#troubleshooting) · [验证与正式部署](#verification)

## 一、<span id="systems">系统入口与目录职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

每个系统以自身的 `README.md` 作为完整部署说明，`Deployment/` 管理部署脚本，`Undeployment/` 管理停止与反部署边界。跨系统复用的辅助模块统一放在[公共组件](./公共组件/README.md)，不与操作系统目录混放；根目录保留总导航及共用锁清单。

| 系统 | 资料 | 当前脚本状态 |
| --- | --- | --- |
| MacOS | [部署文档](./MacOS/README.md) | zsh 双模式部署与配对反部署 |
| Ubuntu | [部署文档](./Ubuntu/README.md) | Bash 双模式部署与配对反部署 |
| Debian | [部署文档](./Debian/README.md) | Bash 双模式部署与配对反部署 |
| Rocky Linux | [部署文档](./RockyLinux/README.md) | Bash 双模式部署与配对反部署 |
| Alibaba Cloud Linux | [部署文档](./AlibabaCloudLinux/README.md) | Bash 双模式部署与配对反部署 |
| Windows | [部署文档](./Windows/README.md) | 原生 [**PowerShell**](https://learn.microsoft.com/powershell/) 双模式部署与配对反部署 |

**<span id="deployment-shortcuts">各系统部署／反部署快捷入口与唯一实现</span>**

在本系统文件夹中按用途选择“部署”或“反部署”快捷入口；下表路径以各自系统目录为基准。两组快捷文件分别定位并调用 `Deployment/`、`Undeployment/` 中各自唯一的规范实现，复用原有自述、确认和完整流程，不保存另一套业务逻辑。

| 系统目录 | 部署快捷入口 | 唯一部署实现 |
| --- | --- | --- |
| `MacOS/` | [【MacOS】双击部署（快捷入口）.command](./MacOS/【MacOS】双击部署（快捷入口）.command) | [Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command](./MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command) |
| `Windows/` | [【Windows】双击部署（快捷入口）.cmd](./Windows/【Windows】双击部署（快捷入口）.cmd) | [Deployment/【Windows】部署.ps1/【Windows】部署.ps1](./Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1) |
| `Ubuntu/` | [双击部署（快捷入口）.desktop](./Ubuntu/双击部署（快捷入口）.desktop) | [Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh](./Ubuntu/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh) |
| `Debian/` | [双击部署（快捷入口）.desktop](./Debian/双击部署（快捷入口）.desktop) | [Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh](./Debian/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh) |
| `RockyLinux/` | [双击部署（快捷入口）.desktop](./RockyLinux/双击部署（快捷入口）.desktop) | [Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh](./RockyLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh) |
| `AlibabaCloudLinux/` | [双击部署（快捷入口）.desktop](./AlibabaCloudLinux/双击部署（快捷入口）.desktop) | [Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh](./AlibabaCloudLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh) |

| 系统目录 | 反部署快捷入口 | 唯一反部署实现 |
| --- | --- | --- |
| `MacOS/` | [【MacOS】双击反部署（快捷入口）.command](./MacOS/【MacOS】双击反部署（快捷入口）.command) | [Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command](./MacOS/Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command) |
| `Windows/` | [【Windows】双击反部署（快捷入口）.cmd](./Windows/【Windows】双击反部署（快捷入口）.cmd) | [Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1](./Windows/Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1) |
| `Ubuntu/` | [双击反部署（快捷入口）.desktop](./Ubuntu/双击反部署（快捷入口）.desktop) | [Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh](./Ubuntu/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh) |
| `Debian/` | [双击反部署（快捷入口）.desktop](./Debian/双击反部署（快捷入口）.desktop) | [Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh](./Debian/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh) |
| `RockyLinux/` | [双击反部署（快捷入口）.desktop](./RockyLinux/双击反部署（快捷入口）.desktop) | [Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh](./RockyLinux/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh) |
| `AlibabaCloudLinux/` | [双击反部署（快捷入口）.desktop](./AlibabaCloudLinux/双击反部署（快捷入口）.desktop) | [Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh](./AlibabaCloudLinux/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh) |

MacOS 快捷文件按自身位置转交对应 zsh 脚本；Windows 快捷 CMD 在对应的 `Deployment/` 或 `Undeployment/` 中查找唯一同名 PowerShell 脚本包，保留参数与退出码，缺失或多候选即停止。包内 CMD 继续调用同一 PowerShell 实现。Linux 桌面快捷方式用 Bash 调用对应目录中唯一同名脚本包；需要图形桌面与终端模拟器，文件管理器可能要求操作者信任或允许启动。快捷入口不默认修改信任、安装桌面依赖或更改全局环境。文件管理器须传入本地绝对路径；`file://` 等 URI 或相对路径会停止，此时从本地文件夹启动或用 SSH／终端运行规范脚本。

**部署与反部署分开操作：** 两组快捷入口按名称独立选择，部署只进入 `Deployment/`，反部署只进入 `Undeployment/`。停止当前服务用运行终端的 `Ctrl+C`；需要恢复原环境或处理数据时，先阅读本系统 `Undeployment/README.md`，再打开反部署快捷入口或运行配对脚本，原有备份默认／清零选择及危险确认继续保留。

最低资源预算及系统兼容边界见[最低支持的机器配置](#minimum-machine)，公共工具与运行数据目录见[机器环境说明](#machine-environment)。

### 1.1、<span id="policy">源码与数据约定</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

各系统构建同一份 [Go 服务端](../代码/后端/后端代码/README.md)，不复制业务实现。通用环境变量、手动前台运行及验证边界在本文对应章节维护。

部署与反部署入口成对提供。部署前保存原有程序、必要配置、产物与资源归属，反部署核对后停止属于该项目的进程、恢复原有产物，并撤回本次新增的程序、依赖与 SDK。显式指定、系统 PATH 或机器环境中原有的健康公共工具继续保留；不按工具名称批量卸载，不修改其它项目、系统服务或全局环境。

数据通过 fzf 选择“数据库／文件数据备份（默认）”或“数据库／文件数据清零”。默认先备份全部现行业务、附件、签名、匹配密钥及恢复所需配置，核对备份及解密能力后再清理源数据；清零不生成本次业务备份，须额外确认。已有业务数据也按明确选择处理，不能将备份选项理解为保留原服务继续运行。原有独立历史备份及其它项目数据不在清理范围内。

### 1.2、<span id="undeployment">配对反部署入口与操作</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

可从[快捷入口索引](#deployment-shortcuts)打开本系统独立的反部署快捷文件；下表仍保留从本 README 所在 `部署/` 目录执行的规范命令。先用只读检查审阅范围，再按正常入口阅读自述、回车进入 fzf 数据菜单；执行确认默认取消。Esc、空选、选择器失败及确认取消均不删除。

| 系统 | 正常反部署命令 | 本系统说明 |
| --- | --- | --- |
| MacOS | `/bin/zsh './MacOS/Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command'` | [MacOS 反部署](./MacOS/Undeployment/README.md) |
| Windows | `& './Windows/Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1'` | [Windows 反部署](./Windows/Undeployment/README.md) |
| Ubuntu | `/bin/bash './Ubuntu/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh'` | [Ubuntu 反部署](./Ubuntu/Undeployment/README.md) |
| Debian | `/bin/bash './Debian/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh'` | [Debian 反部署](./Debian/Undeployment/README.md) |
| Rocky Linux | `/bin/bash './RockyLinux/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh'` | [Rocky Linux 反部署](./RockyLinux/Undeployment/README.md) |
| Alibaba Cloud Linux | `/bin/bash './AlibabaCloudLinux/Undeployment/【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh'` | [Alibaba Cloud Linux 反部署](./AlibabaCloudLinux/Undeployment/README.md) |

Shell 命令追加 `--check` 或 `--plan`；PowerShell 追加 `-Check` 或 `-Plan`，只读解析目录和原点记录，不下载工具、创建缓存、停止服务或处理数据。反部署复用已有 fzf，缺失时指定已核验工具路径，不为卸载重新安装依赖。

部署前记录位于项目独立 Runtime 的 `deploy-state/`（Shell）或 `deploy-state-Windows/`（Windows），由目标系统权限限制当前账户。记录首次原点，不用重复部署覆盖原有恢复依据；配置与当前记录不一致、指纹改变、原件副本损坏、进程身份不符或部署仍占用操作锁时保留现场并停止。此前缺少原点记录的旧部署不能推测安装前状态，脚本会保留未知资源并报告，不能据此宣称已恢复原点。

备份与反部署审计默认放在 Runtime 外、同级的 `UndeploymentBackups/`；可用 `WB_UNDEPLOY_BACKUP_DIR` 指定其它独立位置，不能放在待清理目录内。包含密钥及私有恢复配置，分享前脱敏。可选 TiDB 仅处理当前应用的 `v38_workbench_snapshot` 中 `id=1` 聚合记录，默认备份策略在清零时引用已验证备份，与最新业务内容和读取版本核对；备份失败、备份后出现新写入或版本冲突时保留数据并停止。不删除数据库、表结构、账号权限、其它记录或数据库服务，应用备份也不等于数据库完整灾备。

自行配置的 cpolar、命名 Tunnel、DNS、订阅、系统常驻项与电源设置继续按原记录单独撤回；部署脚本没有安装的对象不纳入自动删除。脚本源码、隔离回归和各目标系统实机反部署分别验收，不能用本机临时夹具推定 Windows／Linux 原生或真实数据库已验收。

### 1.3、<span id="access-qr">各端访问地址与扫码入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

六个系统的部署入口保留完整可复制 URL，并为前端用户／工程师工作台 `/` 与后台管理网页 `/admin/` 分别本地生成两张二维码。公网码直接编码本轮实际 Quick Tunnel 地址，扫码后继续执行现有业务登录与权限校验；MacOS 本地模式直接公开演示、不设隧道邮箱门禁，其他平台仍按所选访问方式验证邮箱。回环地址明确标记“仅本机，手机不可用”，服务器模式未提供公网入口时不会推测公网域名或把监听地址当作手机入口。

支持颜色且宽度足够的终端显示黑白方块码；窄窗口、纯文本、非 TTY、`TERM=dumb` 或 `NO_COLOR` 时保留 URL，并在 fzf 的“打开扫码页面”中打开本地 `index.html`。页面内嵌二维码，不依赖网络图片或在线二维码服务，同时保留 SVG／PNG；无桌面的服务器可取出这些本地文件后打开。选择器仍用方向键与回车，Esc收起、回车恢复，Ctrl+C停止本次服务。

[二维码工具与固定依赖](./公共组件/地址二维码/README.md)由部署已准备的 Go 构建；不新增 Node.js／Python 运行依赖，不改业务模块。辅助构建或生成失败只告警，URL与服务仍然保留。二进制及每轮独占的 `access-qr-N/` 位于本次 Runtime 会话，归原有部署与反部署原点清单管理；退出或隧道地址变化时将旧页面标记失效，地址变化后重新生成。已另存图片无法远程撤销，重新部署应使用新码。

二维码只包含访问地址，不包含账号、密码、令牌或签名；生成成功和扫码打开均不代表公网验收通过，仍用手机移动网络验证真实登录、写入、刷新重读及文件权限。隔离验证见[访问二维码验证](../测试/部署/二维码/验证访问二维码.mjs/README.md)。

## 二、<span id="routes">选择部署路线</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 路线 | 用途 | 依赖与持久化 |
| --- | --- | --- |
| 本机默认运行 | 录入合成工单、演示业务、验证重启读取 | Go；加密文件快照与独立密钥文件 |
| 本机 TiDB 演示 | 验证数据库适配、事务与重启读取 | Go、已运行的专用 TiDB；数据库加密聚合快照与原密钥 |
| 纯界面离线预览 | 无后端时查看界面与操作独立样例 | [**Node.js**](https://nodejs.org/)；不连接业务数据库、不保存服务端业务 |
| 正式云部署／真实资料内测 | 后续阶段 | 当前尚未交付；必须先完成本指南末节列出的实施与验收工作 |

当前 API 只允许 `127.0.0.1`、`localhost` 或回环 IPv6 地址，不能将 `WB_ADDR` 改为 `0.0.0.0`、局域网 IP 或公网 IP 直接开放。手机尺寸响应式页面可以在本机浏览器预览；实体手机外网访问须按[内网穿透步骤](#local-tunnel)单独验收，当前尚未完成公网业务验收。

管理后台为 `代码/前端/后台管理端/{Web,Flutter}` 两套客户端，均调用 `/api/v38`。此目录没有针对 V3.8 应用的一键容器／集群部署包；下文容器示例仅准备演示数据库。

### 2.1、<span id="minimum-machine">最低支持的机器配置</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

下表是当前单实例、少量合成数据演示的最低资源预算，属于工程估算，尚未在这些资源限制下完成最低配置或并发压测。CPU 按可分配的逻辑核／vCPU 计；内存按扣除操作系统、浏览器及其它软件后可供本项目使用的容量计；磁盘按安装系统后剩余的可用 SSD 空间计，不是整盘标称容量。

| 使用场景 | CPU | 项目可用内存 | 可用 SSD 空间 | 适用边界 |
| --- | --- | --- | --- | --- |
| 仅运行已构建服务＋文件存储 | 2 核 | 2 GiB | 10 GiB | 单个回环 API 服务及已构建静态网页；不含本机数据库、客户端 SDK 或构建工具 |
| 本机从源码构建并运行服务 | 2 核 | 4 GiB | 20 GiB | 包含 Go 工具链、模块与编译缓存；本指南的启动脚本和手工构建命令必须按此档准备 |
| 同机运行服务＋TiDB unistore 演示 | 4 核 | 8 GiB | 40 GiB | 仅下文单容器合成功能演示；容器虚拟机还须给宿主系统留足资源，不适用 TiDB 集群 |
| 仅预览已构建网页 | 2 核 | 2 GiB | 5 GiB | 已有 Node.js 与浏览器，不含 Flutter／原生客户端编译及模拟器 |

整机预算另计系统开销：MacOS／Windows 至少 8 GiB RAM，且仍须满足表中的项目可用内存；无桌面的 Linux 文件演示至少 4 GiB 整机 RAM，源码构建按至少 8 GiB 整机 RAM 准备。同机 TiDB 演示按至少 16 GiB 整机 RAM 准备，并确保项目仍可分配 8 GiB。其它程序占用较多时继续增加内存；交换空间不能替代上述内存预算。无需独立显卡。

| 系统与架构 | 工具链最低兼容边界 | 本项目验证边界 |
| --- | --- | --- |
| [**MacOS**](https://www.apple.com/macos/)／Apple Silicon 64 位 | 机器环境中的 Go 1.27.2 按 MacOS 13 或以上准备；Intel Mac由入口按需准备darwin-amd64工具链并构建 | 已有 ARM64 本机验证；Intel Mac 未实机验收 |
| [**Windows**](https://www.microsoft.com/windows)／x86_64 | Go 官方范围为 Windows 10 或 Windows Server 2016 及以上；须另备 windows-amd64 工具链，不能运行其它系统的 Mac 工具 | 已有 AMD64 交叉构建；Windows 原生运行、ACL 与 ARM64 路线仍须单独验证 |
| [**Linux**](https://www.kernel.org/)／x86_64，ARM64 另验 | Ubuntu、Debian、Rocky Linux、Alibaba Cloud Linux 使用 64 位版本；内核及系统库须满足所选 Go，Go 1.24 及以上要求内核 3.2 或以上 | 已有 Linux AMD64 交叉构建；四个发行版与 ARM64 均未完成实机部署验收 |

系统边界依据 [Go 官方最低要求](https://go.dev/wiki/MinimumRequirements)，不代表项目已在最低系统版本实测。选择仍获系统厂商维护的版本；更换工具链后重新核对其要求。连接 TiDB 时还须满足 [TiDB 官方软硬件与镜像架构要求](https://docs.pingcap.com/tidb/v8.5/hardware-and-software-requirements/)；上表 4 核／8 GiB 的 unistore 演示预算不能代替其集群配置。MacOS 使用 [**Docker Desktop**](https://docs.docker.com/desktop/setup/install/mac-install/) 时，还须满足所用版本的系统与虚拟化要求，不能仅凭 Go 可运行就认定 Docker 可运行。

网络：默认服务只监听本机回环端口 8098，TiDB 容器示例仅映射回环端口 14038；本机演示没有公网带宽下限，也不能按此配置直接开放公网。首次下载工具、模块或容器镜像需要能访问对应来源；准备完整依赖缓存、已构建网页与二进制后，文件模式可在断网环境演示。远端数据库还须单独验证连接、TLS 与网络稳定性。

容量：业务、附件、签名、审计与请求记录共用聚合快照，数据增长会增加内存和整份加密写入开销；磁盘须在表中初始空间之外另留附件、日志、各份备份及隔离恢复副本空间，并保留至少 20% 空闲。当前没有自动清理备份保留期，不能把 10 GiB 当成长期容量上限或并发人数保证。正式生产／真实资料内测尚无已验收的最低机器配置，须先完成[正式部署条件](#verification)与目标负载验收。

## 三、<span id="machine-environment">机器环境说明</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

项目保留源码、配置声明和来源记录；公共工具与项目运行资料分别位于用户机器目录。

### 3.1、<span id="machine-paths">机器目录与覆盖参数</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 平台 | 公共 SDK 与依赖缓存 | 本项目运行资料 |
| --- | --- | --- |
| [**MacOS**](https://www.apple.com/macos/) | 当前用户 Library/Caches 下的 JobsSoftwareEnvironments | 当前用户 Library/Application Support 下的 JobsSoftwareProjects/RepairWorkbench/Runtime |
| [**Windows**](https://www.microsoft.com/windows) | LOCALAPPDATA 下的 JobsSoftwareEnvironments | LOCALAPPDATA 下的 JobsSoftwareProjects/RepairWorkbench/Runtime |
| Linux | XDG_CACHE_HOME（缺省为用户 .cache）下的 JobsSoftwareEnvironments | XDG_STATE_HOME（缺省为用户 .local/state）下的 JobsSoftwareProjects/RepairWorkbench/Runtime |

`WB_ENV_ROOT` 覆盖公共环境根；`WB_RUNTIME_DIR` 覆盖本项目运行资料根。Shell 使用绝对路径，Windows 按项目根解析显式相对路径。`GO_BIN`、`WB_FZF_BIN`、`WB_CLOUDFLARED_BIN` 可指定已有健康工具。路径均在目标机器运行时解析，不设置全局环境变量。

### 3.2、<span id="sdk-and-data">SDK 与数据分别管理</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

公共工具按名称、版本、系统及架构隔离；已有工具还须达到当次官方稳定目标，不能只因健康便跳过版本检查。需要新增时，工具、下载暂存及 Go 构建缓存进入机器环境 `Projects/RepairWorkbench/<项目标识>/` 下的 `Tools/`、`Downloads/`、`GoCache/`，与其它项目和原有共享 SDK 分开，便于按原点完整撤回。来源及校验信息见 [SDK来源](#sdk-provenance) 和 [工具锁清单](./deploy-tools.lock.tsv)。不将公共 SDK、下载归档或 Go 缓存复制回源码，不以项目内软链接替代外置。

Runtime 保留 `data/`、匹配 `keys/`、备份与恢复副本的原有相对结构；默认数据为其 `data/`，默认密钥为同级 `keys/storage.key`。已有显式 `WB_DATA_DIR`、`WB_KEY_FILE`、`WB_BACKUP_DIR` 配置继续有效。运行目录中的旧验证快照及密钥仍按数据保管，不能按构建缓存删除。

正常部署先展示自述、等待确认，再由fzf选择模式；菜单与解析器允许静态锁引导，最终构建前重新检查官方稳定版。只读 `--check/--plan` 或 PowerShell `-Check/-Plan` 不下载、不创建缓存、不构建、不启动服务。

### 3.3、<span id="static-boundaries">静态资料与验证边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口从自身位置定位完整项目，通过 `WB_PROJECT_ROOT` 指定项目根；Go 手工运行同样需显式指定，或把二进制放在完整项目树内由其祖先定位。`WB_WEB_DIR`、各管理及 Flutter 静态目录、契约目录仍可显式覆盖。

Flutter 发布网页默认位于各端 `Dist/Web/`；它是已构建发布副本，不属于源码或公共 SDK。重新构建按前端 README 操作。外置 Go 单测使用 [测试入口](../测试/后端/运行测试.py/README.md)，不把测试复制到业务源码。目标系统部署、真实数据库、联网下载及公网穿透仍分别验收。

### 3.4、<span id="sdk-provenance">SDK 来源记录</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以下是已有Apple Silicon共享Go的来源记录，保留来源、SHA256、许可文件及安装布局；不是本次部署采用版本的声明。静态[工具锁清单](./deploy-tools.lock.tsv)用于引导与精确摘要兜底，当次官方目标和实际采用版本以运行日志为准。

```json
{
  "name": "Go",
  "version": "1.27.2",
  "platform": "darwin-arm64",
  "source": "https://go.dev/dl/go1.27.2.darwin-arm64.tar.gz",
  "archiveSha256": "76812b213b1b2302c978d28fa52fa92d541704b9e7d9d5db8002c50e4018c4c5",
  "checksumVerified": true,
  "licenseFile": "go/LICENSE",
  "purpose": "Machine-level shared compiler; project repository contains only dependency declarations and provenance.",
  "installationLayout": "Go/go1.27.2/MacOS-arm64/go"
}
```

### 3.5、<span id="tool-updates">工具更新与业务依赖检查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

六个系统的正常部署在确认用途并选择模式后，每次查询Go、fzf的官方最新稳定版；仅本地穿透模式查询cloudflared。Go使用官方发行目录，fzf／cloudflared使用对应官方GitHub Release，排除预发布。菜单所需fzf及编译标准库[版本解析器](./公共组件/依赖版本/README.md)的Go可先复用健康工具，缺失时依静态锁校验引导；最终构建会再次按官方目标核验，静态锁不冒充当次最新版。

日志显示当前版本、官方稳定目标及实际采用路径／版本。显式 `GO_BIN`、`WB_FZF_BIN`、`WB_CLOUDFLARED_BIN` 过旧或功能不兼容时停止，由操作者修正配置；不覆盖显式文件或悄悄改用其它来源。未显式指定时，从PATH、既有公共缓存及本项目全部版本缓存中按实际语义版本择新，只有不低于官方目标且功能健康才复用。新工具下载到机器环境的项目专属版本目录，校验官方SHA256后切换；保留原点与旧对象，反部署按原清单恢复专属资源，原有共享工具及后续修改不被误删。若官方没有本平台／架构成品，只有明确提供且满足目标的原生工具可用，否则停止，不混用架构。

SDK元数据或归档获取的临时网络错误、限流及服务端故障采用有界单次等待与退避持续重试，Ctrl+C可取消本轮短作业；来源、摘要、参数、平台错误立即停止，不跳过校验或回旧锁假称最新版。cloudflared运行仍带 `--no-autoupdate`，由下一次部署检查更新，不在服务运行中自行替换。只读 `--check/--plan`、`-Check/-Plan` 不查询网络、不构建解析器、不下载或创建缓存。

后端与二维码业务库只通过 `go list -m -u` 查询当前模块路径的可更新项，列出版本后由维护者单独升级并回归；不会自动执行 `go get`、`go mod tidy` 或改写源码锁，也不发现换路径的新主版本。查询与readonly构建使用Runtime内的 `module.mod/module.sum` 副本，禁用外部workspace，原 `go.mod/go.sum` 字节保留。检查默认每模块30秒，可用 `WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS` 设置1—300秒；超时或查询失败明确显示“检查未完成”后可按已有锁构建，参数／路径／源码变化校验失败则停止核对。

本入口不暗中升级Flutter、Pods、Gradle／Android或其它客户端依赖；它只托管已存在的Web及Flutter发布资源。客户端依赖更新须在各自工程单独回归；不会批量升级系统基础包或执行sudo、Homebrew、APT、DNF全局安装。隔离边界与命令见[依赖更新验证](../测试/部署/依赖更新/README.md)。

## 四、<span id="macos">MacOS 本机启动</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 4.1、<span id="preflight">执行前检查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本机已准备的公共工具为官方 Go 1.27.2 `darwin-arm64`，适用于 [**MacOS**](https://www.apple.com/macos/) 的 Apple Silicon。来源、归档校验值与许可位置见 [SDK 来源记录](#sdk-provenance)。Intel Mac、Windows、Linux必须使用匹配平台工具；双模式入口可按锁定清单自动准备机器公共环境中的工具，也可按[Go官方说明](https://go.dev/doc/install)复用本人健康环境。

`./代码/后端/后端代码/go.mod` 声明最低 Go 1.24.0；已经实测的编译基线为已核验工具版本。默认启动脚本先找 `GO_BIN`，再找 `PATH`，再找机器环境中的已有 SDK，缺失时按锁清单准备。PATH 中版本过旧时，用 `GO_BIN` 明确选择可用工具。

```zsh
export WB_PROJECT_ROOT="$PWD"
export WB_ENV_ROOT="${WB_ENV_ROOT:-$HOME/Library/Caches/JobsSoftwareEnvironments}"
export WB_RUNTIME_DIR="${WB_RUNTIME_DIR:-$HOME/Library/Application Support/JobsSoftwareProjects/RepairWorkbench/Runtime}"
export GO_BIN="${GO_BIN:-$WB_ENV_ROOT/Go/go1.27.2/MacOS-arm64/go/bin/go}"
pwd
test -f './代码/后端/后端代码/go.mod'
test -f './代码/前端/PC端/Web/维修工作台/index.html'
test -x './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'
"$GO_BIN" version
lsof -nP -iTCP:8098 -sTCP:LISTEN
```

最后一条命令没有输出，表示未发现监听该端口的进程；这时退出码为 1 属于正常检查结果。存在监听时先确认所属应用，不能直接关闭其它项目的服务。

以上变量只在当前终端及其子进程生效，后续 MacOS 手工运行、备份及恢复示例复用这些变量；机器目录规则见 [环境说明](#machine-environment)。首次构建可能按 `go.mod` 获取缺少的模块依赖；没有模块缓存且网络不可达时不能保证离线编译。启动脚本不安装或升级系统软件。

### 4.2、<span id="quick-start">双击或终端启动</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 双击 `./部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command`。它位于同名脚本目录内；移动项目时保留目录结构。

- 阅读终端自述并按回车，用 fzf 的 `↑`／`↓` 选择“本地部署＋内网穿透”或“服务器部署”，回车确认、`Esc` 取消。MacOS 本地模式只需再按回车确认公开临时入口，不收邮箱，也不要求输入 `PUBLIC`；仅使用合成数据。确认后先按登记身份停止本项目旧实例，等待退出封存、解锁再准备依赖与构建；确认前取消及 `--check`／`--plan` 保留旧实例，未知归属或反部署作业保留并报告。脚本每次编译 `./代码/后端/后端代码/cmd/workbench`，成功后以前台方式运行 `"${WB_RUNTIME_DIR}/workbench"`，本次后端健康后才建立隧道，构建失败不启动旧二进制。

- 启动后显示工作台 `/` 和后台 `/admin/` 的完整 URL 与两张二维码，并自动显示“打开网页”fzf 菜单；选择本次公网、本机或扫码页面并回车，由默认浏览器打开，随后返回菜单继续选择。服务器模式列本机入口及扫码页面，回环码明确仅本机。`Esc` 或“收起菜单”只收起菜单、保留服务，在原终端按回车重新显示；`Ctrl+C` 或关闭 MacOS 运行终端停止本轮菜单、后端与隧道，独立守护核验入口及终端父进程异常退出并完成回收与解锁，数据、配置、密钥和首轮原点保留，再次双击可重新部署。Windows 及各 Linux 的网页菜单交互相同，邮箱／`PUBLIC` 流程仍以各自文档为准；Linux 本机打开浏览器需已有桌面会话与 `xdg-open`，无桌面时提示并保持服务运行。

Apple Silicon 在终端复用机器环境中的工具、默认文件存储的明确配置示例：

```zsh
GO_BIN="$GO_BIN" \
WB_ADDR='127.0.0.1:8098' \
WB_DATA_DIR="${WB_RUNTIME_DIR}/data" \
WB_KEY_FILE="${WB_RUNTIME_DIR}/keys/storage.key" \
WB_WEB_DIR='./代码/前端/PC端/Web/维修工作台' \
WB_TIDB_DSN='' \
WB_BACKUP_DIR='' \
/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'
```

此示例明确关闭该次运行的 TiDB 与定时备份，保持本机默认路线；不会删除已有数据。已有其它配置时按 [配置表](#configuration)调整。

使用非默认端口时，把 `WB_ADDR` 改为 `127.0.0.1:18098`，并同步使用 [对应工作台地址](http://127.0.0.1:18098/)。

### 4.3、<span id="health-login">健康检查与登录</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

另开终端执行只读检查：

```zsh
curl --fail --silent --show-error 'http://127.0.0.1:8098/api/v38/healthz'
curl --fail --silent --show-error 'http://127.0.0.1:8098/securityz'
```

健康结果应包含 `status: ok`、`version: 3.8`、`mode: synthetic_demo`。当前没有新入口的 `/readyz`；`healthz` 只说明服务在响应，不保证运行中的数据库、业务数据或备份始终健康。

工作台右上角进入账号页，用 `admin`、`dispatcher`、`finance`、`warehouse`、`customer` 等合成账号登录。统一演示密码为 `Demo-Repair-2026!`；完整角色与交接账号见 [演示账号](../README.md#demo-accounts)。

页面显示“合成演示”不能证明后端已连接；只有成功登录并读取授权工单后，才应显示服务端来源。服务重启后原会话失效，重新登录。停机前待验收工单重启后需核实线下异议，再办理“复核停机期间异议”。

## 五、<span id="configuration">配置、路径与持久化</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 变量 | 默认值／行为 |
| --- | --- |
| `WB_ENV_ROOT` | 公共 SDK 与依赖缓存根；默认按目标操作系统当前用户缓存目录解析 |
| `WB_RUNTIME_DIR` | 本项目独立运行资料根；默认按目标系统用户资料／状态目录解析 |
| `WB_PROJECT_ROOT` | 完整项目根；部署入口从自身位置解析后传给后端 |
| `WB_ADMIN_DIR` | `代码/前端/后台管理端/Web` |
| `WB_ADMIN_FLUTTER_DIR` | `代码/前端/后台管理端/Flutter/Dist/Web` |
| `WB_CLIENT_FLUTTER_DIR` | `代码/前端/移动端/Flutter/Dist/Web` |
| `WB_ADMIN_CONTRACT_DIR` | `代码/前端/后台管理端/共享契约`，唯一管理UI契约 |
| `GO_BIN` | 启动与验证脚本使用的已有 Go 可执行文件；显式指定但无效时直接失败 |
| `WB_ADDR` | `127.0.0.1:8098`；仅回环监听 |
| `WB_DATA_DIR` | 本项目独立用户 Runtime 下的 `data/`；文件快照与写锁在此 |
| `WB_WEB_DIR` | 启动脚本使用项目根 `./代码/前端/PC端/Web/维修工作台`；保持该静态资源边界，不要指向项目根或数据目录 |
| `WB_KEY_FILE` | 未设置时取数据目录同级的 `keys/storage.key`；须保留原密钥 |
| `WB_TIDB_DSN` | 为空采用文件存储；非空连接指定数据库，不自动迁移文件数据 |
| `WB_REQUIRE_DB_TLS` | 字符串 `true` 强制验证身份的数据库 TLS；非回环数据库默认拒绝不安全连接配置 |
| `WB_BACKUP_DIR` | 未设置时不运行定时备份；设置后启动立即备份并周期执行 |
| `WB_BACKUP_INTERVAL_MINUTES` | 默认 `1440`；须为正整数，只有配置备份目录后才生效 |
| `WB_PREVIEW_PORT` | 仅离线预览脚本使用，默认 `8099` |
| `NO_COLOR` | 启动脚本关闭彩色展示 |

**路径区别**：部署入口将显式相对 Go、数据、页面、密钥和备份路径按项目根解析；直接执行二进制时，操作者显式传入的相对路径仍以当前目录为准。默认运行数据从 `WB_RUNTIME_DIR` 或当前用户系统目录解析，默认静态资料从 `WB_PROJECT_ROOT` 或二进制所在完整项目树解析，不依赖启动工作目录。下文手工示例均在项目根明确设置环境；机器路径见 [环境说明](#machine-environment)。

```text
Runtime/
├── workbench                  构建程序
├── data/
│   ├── snapshot.enc           加密业务、签名及附件聚合快照
│   ├── writer.lock            当前写入进程的PID标记
│   └── .writer.guard          持久内核锁文件，进程退出后由系统释放锁定
└── keys/
    └── storage.key            32 字节密钥，不包含在备份包中
```

首次无快照运行时生成合成种子与密钥；已有快照时读取原数据。数据和密钥都必须保存，不能删除密钥再生成新文件来尝试解密旧快照。程序拒绝明文快照回退、损坏快照和错误密钥。

默认文件存储同一数据目录只能运行一个服务。TiDB 使用 revision 校验拒绝旧版本覆盖，但并非多实例业务部署方案，同样保持一个业务服务。

MacOS、Windows及各Linux入口共用同一后端锁机制。异常退出遗留 `writer.lock` 时，后端先独占 `.writer.guard`，只有确认旧PID不存在且标记未被替换才自动回收并重新启动。存活PID、权限不足、空或无效PID均保留原锁并拒绝启动；不会删除业务快照、密钥、附件或备份。`.writer.guard` 是需要保留的普通文件，文件存在不代表服务仍在运行，不要手动删除它或绕过并发保护。

不把 本项目独立 Runtime、密钥、备份、日志或数据库配置公开为静态资源。默认 Logo 位于 `./代码/前端/PC端/Web/维修工作台/assets/RepairLogo.png`，运行时使用本地打包资源。

### 5.1、<span id="reading-audit-capacity">读取权限、审计与容量</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

工单读取统一使用 [职责矩阵](../代码/后端/README.md#field-permissions)：管理员／调度／财务可读成本提成，工程师／仓库只读本人成本，质检及外部角色无成本提成。财务审批、发票及现金交接事件的内部正文也按矩阵过滤，原件下载重新校验工单授权与证据职责。公开报告及本人上传资料保持可读；私有附件依据已有阶段与资料引用判断，仍需正式用途分类模型。

管理员在设置页查看安全审计，接口为 `GET /api/v38/audit?page=1&pageSize=30`，只有管理员可用。账号停用／启用保存操作人、目标、原因、前后状态与授权版本；它们与账号变更同一次原子提交。完整工单详情、完整工单幂等重试、原件下载和导出在返回内容前持久保存读取审计；审计保存失败时请求失败，不释放资料。审计与业务仍在同一加密聚合快照中，没有独立不可篡改审计或独立运维审计服务。

首屏 `/api/v38/bootstrap` 默认返回 30 条轻量工单与 `orderPage`、完整可见范围的 `metrics`、`capacity`；列表搜索及翻页请求服务器。摘要标记 `isSummary=true`，不带完整事件、证据、报价历史、签名、成本或提成，打开详情后按授权读取。库存、借还与采购列表仍随首屏返回，整体持久化仍是小规模聚合框架。

幂等记录保留所有已处理键与内容摘要，工单／借用／采购历史响应压缩为稳定 ID，重试按当前授权读取最新结果；启动兼容压缩旧响应，随后随快照保存。8,000 个请求键开始显示容量预警，10,000 为参考阈值，超过后继续可写。容量提示不等于容量已经验收；不要清空幂等记录，继续规划关系表、独立媒体与请求记录存储。

### 5.2、<span id="payment-acceptance-calendar">先款、验收原件与质保日期</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

维修报价只有明确设置 `quote.startRequiresPrepayment=true` 才要求先款开修；此时约定预付款须大于零，核实收款减退款的净额达到约定后允许开修。仅填写预付款金额不自动形成先款约定，旧快照缺少开关按 false 处理。现款销售仍须核实达到冻结报价总额后才可出库，应收调整不改变该门槛；账期销售保留原有预付款条件。报价形成新版本，客户签署前展示当前约定，见 [执行门槛合同](../代码/后端/README.md#execution-payment-contract)。

人工验收通过或不通过均追加 `acceptanceRecords`，保存原件、签署人、时间和报价／工单版本；不通过继续保留异议，后续通过不覆盖原件。完整记录仅向当前授权客户经办人及管理员／调度／财务返回，列表摘要不含原件。记录随加密快照备份和恢复，恢复仍使用最新源的当前授权；旧版本已丢失的原件不能补造。普通页面提供历史只读展示，不通过提交路径由公开 API 及正式测试覆盖。

新验收按中国日期加 1 至 60 个完整日历月，目标月无同日则取月末；质保截止日全天有效，次日中国时间零点到期。升级不会重算已有持久化截止日；历史订单应按真实约定核对，详见 [验收签署与日历合同](../代码/后端/README.md#acceptance-history-contract)。

## 六、<span id="tidb">可选 TiDB 本机演示</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 6.1、<span id="tidb-container">准备专用演示数据库</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

已经有可用的专用 TiDB 时跳到下一节。以下示例要求已有可运行的 [**Docker**](https://docs.docker.com/) 环境，固定使用已验证的 `pingcap/tidb:v8.5.8`；这是合成演示基线，不是最新版本或生产拓扑建议。Docker 参数依据 [官方容器运行说明](https://docs.docker.com/reference/cli/docker/container/run/)。

先检查工具、容器名称和端口：

```zsh
docker version
docker ps -a --filter 'name=jobs-repair-v38-tidb'
lsof -nP -iTCP:14038 -sTCP:LISTEN
```

确认该名称和端口可用后，再按需运行以下创建命令。命名卷保存数据库文件；不加 `--rm`，不删除已有同名卷或其它项目容器。

```zsh
docker run -d \
  --name jobs-repair-v38-tidb \
  -p 127.0.0.1:14038:4000 \
  --mount type=volume,source=jobs-repair-v38-tidb-data,target=/data/tidb \
  pingcap/tidb:v8.5.8 \
  --store=unistore \
  --path=/data/tidb \
  --host=0.0.0.0

docker logs --tail 80 jobs-repair-v38-tidb
```

`--host=0.0.0.0` 在数据库容器内部监听，宿主机发布仍限制为 `127.0.0.1:14038`。`unistore` 参数是 TiDB 自带存储选项，参考 [官方配置源码](https://github.com/pingcap/tidb/blob/master/pkg/config/config.toml.example)；本示例不具备正式集群容灾能力。

已经存在该演示容器时，核对配置后用 `docker start jobs-repair-v38-tidb` 恢复运行，不再次执行同名创建。需要停止时先停止业务服务，再执行 `docker stop jobs-repair-v38-tidb`；保留命名卷。

### 6.2、<span id="tidb-connect">创建数据库并连接</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

用已有 [**MySQL**](https://www.mysql.com/) 兼容客户端连接专用演示实例。已有 `mysql` 命令时可执行：

```zsh
mysql --host=127.0.0.1 --port=14038 --user=root
```

确认实例用于该合成演示，再在 SQL 客户端中创建数据库：

```sql
CREATE DATABASE IF NOT EXISTS repair_workbench_v38;
```

程序只自动创建 `v38_workbench_snapshot` 表，不创建数据库。既有业务账号的权限需覆盖该数据库的建表、查询、插入和更新；当前表通过 `id=1` 保存一个加密聚合快照。不执行旧 `./代码/后端/后端代码/migrations`，不把旧订单完成状态映射到新工单。

在项目根执行：

```zsh
GO_BIN="$GO_BIN" \
WB_ADDR='127.0.0.1:8098' \
WB_DATA_DIR="${WB_RUNTIME_DIR}/tidb-context" \
WB_KEY_FILE="${WB_RUNTIME_DIR}/tidb-keys/storage.key" \
WB_WEB_DIR='./代码/前端/PC端/Web/维修工作台' \
WB_TIDB_DSN='root@tcp(127.0.0.1:14038)/repair_workbench_v38?tls=false' \
WB_REQUIRE_DB_TLS='false' \
WB_BACKUP_DIR='' \
/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'
```

此处无密码、明文数据库连接仅用于上述本机专用合成实例。检查 `/securityz` 的 `storage` 应为 `TiDB encrypted snapshot`。数据库已有记录时仍必须使用原 `WB_KEY_FILE`，不能换成新密钥。

文件模式和 TiDB 模式是独立存储；切换变量不会导入、清空或合并原数据。若原来使用过另一数据库、密钥或文件目录，先记录并保留其配置。

### 6.3、<span id="database-tls">数据库加密连接边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

非回环数据库，或 `WB_REQUIRE_DB_TLS=true` 时，程序拒绝空 TLS、`false`、`skip-verify` 和 `preferred`。`tls=true` 依赖系统信任根与可验证的服务器证书；私有 CA 必须先完成受控信任配置或扩展客户端实现。当前没有自定义 CA 文件环境变量，不添加无效参数来假装已配置。

数据库还需自行启用 TLS，并核验身份及证书匹配，参考 [TiDB 官方 TLS 说明](https://docs.pingcap.com/tidb/v7.5/enable-tls-between-clients-and-servers/)。该参考解释连接原则，实际配置应按部署的 TiDB 版本核对。不得以跳过证书验证或明文连接处理安全失败。即使数据库连接已加密，当前应用也仍是本机合成框架。

## 七、<span id="other-platforms">Windows、Linux 与离线预览</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 7.1、<span id="linux">Linux 前台运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Linux**](https://www.kernel.org/) 使用匹配平台的已有 Go，在项目根运行；终端前台保持，按 `Ctrl+C` 停止。

```sh
export WB_PROJECT_ROOT="$PWD"
export WB_RUNTIME_DIR="${WB_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/JobsSoftwareProjects/RepairWorkbench/Runtime}"
go version
mkdir -p "$WB_RUNTIME_DIR"
go -C ./代码/后端/后端代码 build -o "$WB_RUNTIME_DIR/workbench" ./cmd/workbench && \
WB_ADDR=127.0.0.1:8098 \
WB_DATA_DIR="$WB_RUNTIME_DIR/data" \
WB_KEY_FILE="$WB_RUNTIME_DIR/keys/storage.key" \
WB_WEB_DIR=./代码/前端/PC端/Web/维修工作台 \
WB_TIDB_DSN='' \
WB_BACKUP_DIR='' \
"$WB_RUNTIME_DIR/workbench"
```

构建失败时停止，不继续启动已有产物。当前没有 V3.8 的后台守护、开机启动或应用容器包；不把关掉终端后仍运行作为默认行为。

### 7.2、<span id="windows">Windows PowerShell 前台运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Windows**](https://www.microsoft.com/windows) 使用匹配平台的已有 Go，在项目根的 [**PowerShell**](https://learn.microsoft.com/powershell/) 中运行；不能使用其它平台的 `darwin-arm64` 工具。

```powershell
$env:WB_PROJECT_ROOT = (Get-Location).Path
if (-not $env:WB_RUNTIME_DIR) { $env:WB_RUNTIME_DIR = Join-Path $env:LOCALAPPDATA 'JobsSoftwareProjects\RepairWorkbench\Runtime' }
go version
if ($LASTEXITCODE -ne 0) { throw 'Go 不可用' }
New-Item -ItemType Directory -Force $env:WB_RUNTIME_DIR | Out-Null
go -C ./代码/后端/后端代码 build -o (Join-Path $env:WB_RUNTIME_DIR 'workbench.exe') ./cmd/workbench
if ($LASTEXITCODE -ne 0) { throw 'Go 构建失败' }
$env:WB_ADDR = '127.0.0.1:8098'
$env:WB_DATA_DIR = Join-Path $env:WB_RUNTIME_DIR 'data'
$env:WB_KEY_FILE = Join-Path $env:WB_RUNTIME_DIR 'keys/storage.key'
$env:WB_WEB_DIR = './代码/前端/PC端/Web/维修工作台'
$env:WB_TIDB_DSN = ''
$env:WB_BACKUP_DIR = ''
& (Join-Path $env:WB_RUNTIME_DIR 'workbench.exe')
```

访问地址与登录方式相同。当前提供终端指令，没有 Windows 系统服务安装入口；真实 Windows／Linux 运行未实机验证。密钥及文件在 Windows 的访问保护还需核对实际 ACL，不能把 POSIX 权限值当作已完成 Windows 权限隔离。

### 7.3、<span id="offline">纯界面离线预览与数据回退</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备已有 Node.js 20 或以上版本，在项目根运行：

```sh
node --version
node './代码/前端/PC端/Web/离线预览.mjs'
```

打开 [离线预览](http://127.0.0.1:8099/)，按 `Ctrl+C` 停止。该服务公开维修工作台，以及 `/admin/` 新 Web 管理端、已构建的 `/admin-flutter/` 和 `/client-flutter/`、管理界面契约与共用字体；Flutter 未构建时对应路径为404。API 返回 `503 offline_preview`，不会读写 本项目独立 Runtime 或连接数据库。自定义端口使用环境变量 `WB_PREVIEW_PORT`。

所有页面进入与刷新照常请求 API，默认请求超时为 2500 毫秒，可在账号与连接页调整。快照与详情先检查实际使用的嵌套字段、类型及关联资源，校验完成后才提交缓存；合法未报价工单的零报价版本保持兼容。错误的 2xx 不能当作成功。概览等待期间显示待加载，导航不吞掉概览失败；读取失败完整切换独立合成样例，恢复后的有效刷新自动采用服务端响应。列表有空态、服务器分页与重新加载入口。

当前认证会话任一受保护请求返回 401 时统一清除会话、旧资料界面及表单意图，提示重新登录；旧会话迟到响应不能撤销新会话。非 401 网络故障保留可信会话供后续成功响应自动恢复，不能把该回退当作继续读取服务端授权资料。

服务端写入失败时保留输入并提示拒绝；超时或返回结构错误时提示结果未知，不显示保存成功、不自动重放，也不把真实表单、签名、附件复制到演示数据。一次业务意图保留原请求键用于核对，无关弹窗不清除该键；明确成功后只释放对应意图，同样内容的下一次办理使用新键，避免合法重复采购／借用被旧结果吞掉。

网页动作版本／返修关联、导出身份及嵌套完整响应保护尚待补齐；独立演示也有本地业务边界问题，见 [当前问题清单](../需求/当前问题清单/当前问题清单.md)。演示可操作不代表对应真实接口放行。

连接页只接受与当前网页同源的 API 地址，留空代表当前地址；需要不同端口时，先打开该端口的工作台再登录。`file://` 页面仅作离线合成预览，不连接后端，也没有默认回退到其它端口的行为。建议用上述静态服务预览。离线样例操作不能当成服务端已保存；正式记录、签署和票据按页面来源区分。Logo 使用本地资源，当前没有必须联网加载的视觉素材。

## 八、<span id="backup">备份与隔离恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 8.1、<span id="scheduled-backup">定时备份</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在当前部署路线的启动命令中设置 `WB_BACKUP_DIR` 与 `WB_BACKUP_INTERVAL_MINUTES`。例如已挂载的独立介质，可从其路径输入备份目录；路径按实际环境填写，不使用不存在的示例挂载点冒充可用介质。

仅为了本机演练可设置 `WB_BACKUP_DIR="${WB_RUNTIME_DIR}/backup-drill"`、`WB_BACKUP_INTERVAL_MINUTES='1440'`，其余数据与密钥配置保持原值。此目录在同盘，不能抵御整机损失。设置独立目标后，核对权限、可写性与备份文件是否实际位于独立介质。

程序启动立即尝试备份，之后按间隔重复。备份包括同一聚合中的工单、款项、库存、签名、附件、账号、授权、删除及安全审计记录，产生 `.wbbak` 与 `.wbbak.manifest.json`；**不包含密钥、应用二进制、环境配置或 TLS 证书**。保留对应代码版本和恢复配置，密钥分离保管。

`/securityz` 的 `configured=true` 只说明启用；还必须检查 `lastSuccess`、`error` 和实际文件。未成功时的零时间不是成功记录。记录可能以 UTC 返回，查看时换算当地时间。状态保存在进程内，重启后重新建立；整机停机和外部介质故障需要独立监测。当前没有自动保留期清理或异地上传功能。

### 8.2、<span id="manual-backup">文件模式人工备份</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先在运行终端按 `Ctrl+C` 停止文件模式服务，再从项目根执行。确认已经运行过且存在业务快照。文件名每次使用新名称，以下名称已存在时换名，不覆盖旧备份。

```zsh
WB_DATA_DIR="${WB_RUNTIME_DIR}/data" \
WB_KEY_FILE="${WB_RUNTIME_DIR}/keys/storage.key" \
WB_TIDB_DSN='' \
"${WB_RUNTIME_DIR}/workbench" -backup "${WB_RUNTIME_DIR}/backup-drill/manual-20261014-01.wbbak"
```

若服务仍占用同一目录的 `writer.lock`，独立备份命令会拒绝运行，不删除锁来绕过。备份文件和摘要清单必须一起保存；目录不存在时工具会创建父目录。

TiDB 模式可以通过已配置的周期作业生成应用聚合备份。其备份不包含数据库权限、系统表、拓扑或运维配置，不等于数据库完整灾备；本 CLI 的隔离恢复路径不支持直接恢复到 TiDB。

### 8.3、<span id="isolated-restore">文件模式隔离恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

停止演示业务服务，保留最新源数据与原密钥。恢复目标必须为**尚不存在的新目录**；不提前创建目标目录，不覆盖在线目录。`WB_DATA_DIR` 指向最新源数据，而不是恢复目标。

```zsh
WB_DATA_DIR="${WB_RUNTIME_DIR}/data" \
WB_KEY_FILE="${WB_RUNTIME_DIR}/keys/storage.key" \
WB_TIDB_DSN='' \
"${WB_RUNTIME_DIR}/workbench" \
  -restore "${WB_RUNTIME_DIR}/backup-drill/manual-20261014-01.wbbak" \
  -restore-target "${WB_RUNTIME_DIR}/restore-drill-20261014-01"
```

恢复会校验备份及清单摘要、解密内容及完整账号身份／凭据，再合并最新源中的账号状态／角色／企业／`authVersion`、每个备份工单当前的 `customerId/companyId/assigneeId/ownerId`，以及按工单与证据 ID 对应的删除约束。因此恢复旧业务事实时继续使用当前联系人、执行人、负责人及企业授权，不恢复旧交接／改派权限。按稳定审计 ID 合并历史与当前记录，并新增恢复审计；不靠数组位置对应授权或删除记录。最新已消费请求键与原内容摘要也合并：最新仅有的账号状态请求返回当前授权，其它业务请求标为待核对，重试返回 409 `recovery_reconciliation_required`，不会再次收款、扣库存或交接；该标记跨后续备份／恢复保留。相同键不同内容仍返回 409，不能通过清键或换键盲目重做。

最新源不存在、不可解密、清单缺失、备份中任一工单缺少当前授权、旧证据缺少当前删除约束，或账号身份／状态／角色／授权版本／凭据、已消费请求或审计约束格式不完整／冲突时直接拒绝；拒绝后不创建可用恢复快照，不回退旧授权。旧版本没有审计清单时按空清单兼容，但已存在的审计记录必须完整有效。当前工具不提供仅依靠旧备份和密钥的整机损失恢复路线，也不能替代 TiDB 独立数据库恢复。

成功日志会说明“已合并最新账号及工单授权、证据删除与审计记录，旧会话不会复用”。出现该日志后仍要完成下述隔离业务与权限核对；不能把日志当成完整灾备验收。

使用恢复目录在另一个回环端口启动，仍明确指定原密钥；不要误用恢复目录旁自动推导的新密钥路径：

```zsh
WB_ADDR='127.0.0.1:18098' \
WB_DATA_DIR="${WB_RUNTIME_DIR}/restore-drill-20261014-01" \
WB_KEY_FILE="${WB_RUNTIME_DIR}/keys/storage.key" \
WB_WEB_DIR='./代码/前端/PC端/Web/维修工作台' \
WB_TIDB_DSN='' \
WB_BACKUP_DIR='' \
"${WB_RUNTIME_DIR}/workbench"
```

重新登录，核对工单阶段、报价签署版本、净收款、借还库存、附件可读性、账号停用与已删证据，并确认旧联系人／旧师傅不可读、新经办人／当前执行人可接续，安全审计含当前账号变更与恢复记录；旧已消费键重试不变更当前授权、重复收款或扣库存，待核对键继续返回 409。恢复的业务事实仍是备份时间点，不是最新业务数据。演练不调用真实支付、电子签或推送。

回切应在核对通过后另行办理，保持原数据、原密钥与备份可回退；本指南不提供自动覆盖在线目录的命令。Windows 人工备份／恢复同样使用这三个 CLI 参数，通过 PowerShell 设置相同环境变量并执行 Runtime 内的 `workbench.exe`，本机尚未实测。

各系统在自己的 `Undeployment/` 提供[配对反部署入口](#undeployment)，默认将当前数据、匹配密钥及必要恢复配置备份到外部并验证，再按原点撤回部署；清零须明确选择和确认。人工恢复与自动反部署的备份分别保管，不以反部署替代完整灾备验收。

## 九、<span id="maintenance">升级、停止与项目移动</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 记录当前存储路线、数据目录、密钥路径、数据库、监听地址和备份目标，保留当前代码及 `代码/前端/PC端/Web/维修工作台` 页面版本。

- 在原服务终端按 `Ctrl+C`。程序进行最多 5 秒的 HTTP 停机处理，正常退出释放文件写锁；不使用强制杀死或批量关闭进程作为常规停止方式。

- 按 [备份与隔离恢复](#backup)完成备份与隔离核对。文件模式确认原服务已停止；核对后停止自己的恢复演练服务。没有可恢复备份时不开始覆盖式升级。

- 只替换需要升级的源码与页面，保留数据、密钥、备份及配置。重新运行启动脚本构建；构建失败停止处理，不盲目执行残留二进制。

- 用原存储与原密钥启动，重新登录，检查健康、存储来源、关键工单与附件，并核对停机期间异议。当前快照 schema 为 38；未来版本若改变格式，先检查其明确迁移方案，不把更换二进制当成自动数据迁移。

项目可整体移动，但要保留启动相对链接、`代码/后端/后端代码`、`代码/前端/PC端/Web/维修工作台`、工具及运行数据。使用外部绝对目录或独立介质时，它们不会随项目移动；记录并验证实际路径。浏览器的服务地址与账号会话也需按新地址重新配置。

按 `Ctrl+C` 停止应用仍保留程序、依赖与业务数据；需要撤回部署时运行[本系统配对反部署脚本](#undeployment)。反部署只处理有原点归属的程序／依赖及明确选定的数据；原有共享 Go、数据库服务、TiDB 卷和其它应用不按名称批量删除。

## 十、<span id="troubleshooting">日志与故障排查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

MacOS 启动日志在系统临时目录的 `【MacOS】启动维修工作台.log`，运行自述显示准确位置；每次确认启动后重建该日志。直接执行二进制、Linux 和 Windows 指令默认输出到当前终端；按环境自行保存运行日志。日志可能含配置路径，发送前移除敏感信息，不输出密钥或含密码的 DSN。

| 现象 | 检查与处理 |
| --- | --- |
| Go 不可用／格式不匹配 | 核对平台与芯片；Apple Silicon 明确设置机器环境中的 `GO_BIN`，其它平台准备匹配工具 |
| Go 编译失败 | 查看构建退出码、工具版本、模块依赖与网络；不要继续启动旧程序 |
| 双击无交互输入 | 从系统终端运行 `/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'`，保留回车确认 |
| 8098 已占用 | 用 `lsof` 确认所属程序；停止自己的旧服务或换端口，不关闭其它项目 |
| 提示只允许回环 | 恢复回环地址；不要改为公网／局域网来绕过本机演示边界 |
| 页面始终合成演示 | 核对 health、登录、账号与连接页地址及端口；页面本身可显示不代表 API 已连通 |
| 连接地址被拒绝 | 目标必须与网页同源且不含路径／凭据／查询／片段；切换端口时先打开目标网页 |
| 写入 403／404 | 核对角色、企业与当前经办人授权；404 也可能表示无权访问，不因此新建重复工单 |
| 写入 409 | 刷新并核对当前版本与原请求结果；不要把同一请求键用于不同内容或重复登记现金 |
| 2xx 但提示结果未知 | 响应字段／类型或资源不符合合同；保留输入及原请求键，重新读取核对，不盲目重复办理 |
| 安全审计保存失败 | 检查持久化、磁盘容量或数据库冲突；完整详情、完整工单重试、下载和导出会拒绝返回资料 |
| 请求键容量预警 | 核对 8,000 预警与 10,000 参考阈值；规划存储扩展，不删除关键键，不依赖此前硬停机制 |
| 提示目录占用 | 查看后端日志中的PID；已有服务存活时先在其原终端停止。已确认不存在的旧PID会在启动时自动恢复；权限不足、空或无效标记时保留原锁并由管理员核实，禁止边运行边删锁或删除 `.writer.guard` |
| 快照无法解密／缺密钥 | 找回对应原密钥并检查完整性；不覆盖快照、不生成替代密钥或改用明文 |
| TiDB 连接失败 | 确认实例运行、数据库已创建、账号权限、端口与 TLS；本程序不会创建数据库 |
| TiDB revision 冲突 | 检查是否误开多个业务实例；停掉自己的重复服务，重新读取后核对，不手改 revision |
| 备份 configured 但无成功 | 检查目标挂载、容量、权限、密钥、实际文件与 `error`；configured 不等于已备份 |
| 恢复目标已存在 | 使用新的、尚不存在的目标路径，不清空已有目录来强行恢复 |
| 恢复后业务重试 409 | 已消费请求对应的业务未确认恢复；由负责人核对差异，不删除键或盲目换键重做 |
| 恢复后仍无法登录／越权 | 旧会话应失效；重新登录，并核对最新账号与工单级授权，未核对前不开放 |

## 十一、<span id="verification">验收入口与正式部署条件</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

按 [测试与验收](../测试/测试与分级验收/测试与分级验收.md) 确定环境、数据、用例和当前结果。构建、安装、目标环境业务与正式发布分别核验，不根据演示页面或交叉构建推定生产通过。

可选验证入口在项目根运行，会创建自己的临时服务与合成数据，不连接当前实例：

```sh
node './测试/后端/接口/验证工作台.mjs'
```

文档核对命令路径、环境变量、CLI 参数、相对链接与代码围栏；不将静态检查或交叉编译写成新的 Windows／Linux／数据库部署实测。

正式部署前至少完成这些当前缺口：

- 真实账号、企业授权与角色最小权限方案；当前默认账号仅适用于合成样例。
- 可信 HTTPS 入口、应用网络边界、数据库证书及身份验证；当前代码仍只开放回环。
- 受控密钥保管与轮换、独立一致备份、告警及完整恢复；当前恢复已合并工单授权与证据约束，最新源损失场景和完整灾备仍需实现及演练。
- 数据库部署拓扑、规范化业务表、独立媒体、独立运维审计及容量／并发验证；当前单聚合快照和库存／采购列表仍是小规模框架。
- 多设备／分批范围及结构化销售出库等业务缺口、模板与全部场景验收；付费渠道、AI 与独立 IM 继续按阶段实施。

不把设置域名、反向代理或数据库加密单项成功视为正式上线已完成。需要正式部署时，先按上述缺口补齐对应实现，再制定与实际代码匹配的发布方案。

## 十二、<span id="new-clients">多端静态客户端</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Web管理端随Go服务位于 `/admin/`，共同规范位于 `/admin-contract/admin-ui.json`。Flutter管理端在对应工程构建 `--base-href /admin-flutter/` 后访问 `/admin-flutter/`；Flutter用户端以 `--base-href /client-flutter/` 构建后访问 `/client-flutter/`。使用 `--no-web-resources-cdn` 将引擎资源留在包内。两入口未构建时返回503并提示构建，不发布源工程目录。

配置可用 `WB_ADMIN_DIR`、`WB_ADMIN_FLUTTER_DIR`、`WB_CLIENT_FLUTTER_DIR`、`WB_ADMIN_CONTRACT_DIR` 指定静态根目录；路径由根启动器按项目位置解析。不要将这些目录指向业务数据或密钥目录。独立 Node 预览也提供这些已构建页面，但其API始终503，不能当成真实服务联调。

## 十三、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口提供可交互的双模式选择。正常运行先展示影响范围，回车授权本次项目内准备，再必须通过[**fzf**](https://github.com/junegunn/fzf)选择“本地部署＋内网穿透”或“服务器部署”；不是先装好一套云服务再开始。

| 本机平台 | 正常入口（先在终端进入项目根） | 详细步骤 |
| --- | --- | --- |
| MacOS | `/bin/zsh './部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'` | [本平台教程](./MacOS/README.md#local-tunnel) |
| Windows | `& './部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1'` | [本平台教程](./Windows/README.md#local-tunnel) |
| Ubuntu | `/bin/bash './部署/Ubuntu/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](./Ubuntu/README.md#local-tunnel) |
| Debian | `/bin/bash './部署/Debian/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](./Debian/README.md#local-tunnel) |
| RockyLinux | `/bin/bash './部署/RockyLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](./RockyLinux/README.md#local-tunnel) |
| AlibabaCloudLinux | `/bin/bash './部署/AlibabaCloudLinux/Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'` | [本平台教程](./AlibabaCloudLinux/README.md#local-tunnel) |

- 选择“本地部署＋内网穿透”：模式确认后查询Go／fzf／本地模式cloudflared的官方最新稳定版；已有工具仅在实际版本不低于目标且功能健康时复用，否则按官方摘要校验下载到项目专属机器缓存，不覆盖系统或显式路径文件。构建成功且本次子进程通过本机health后才连接免费Cloudflare Quick Tunnel，无需注册账号、购买域名或云主机。Quick只为本次子进程使用会话内空配置{}并清除继承的TUNNEL_*，不会改动本人已有cloudflared配置或父进程环境。首次下载和Go依赖需要网络；临时网络故障持续退避重试，Ctrl+C可取消；来源、摘要或参数错误明确停止，不跳过校验。系统还需自带基础下载／解压／校验工具（Shell需要curl、tar与shasum或sha256sum）；不会自动执行sudo、brew、apt、dnf或全局安装。来源清单见[锁定文件](./deploy-tools.lock.tsv)。

- **MacOS 本地模式：** 直接采用公开演示／App 联调，模式选定后再按回车确认公开，不收邮箱，不要求输入 `PUBLIC`，继承的 `WB_TUNNEL_ALLOWED_MAIL` 不会重新启用邮箱门禁。自述、模式选择或公开确认取消均保留旧实例；确认后先按登记身份停止本项目旧实例，等待其退出封存、解锁再部署，未知归属与反部署作业保留并报告。此调整仅适用于 MacOS。

  MacOS 模式选择前只读复用健康 fzf；缺失时仅下载校验后的选择器到本次会话的 `RUN_DIR/bootstrap-environment`，不改动旧部署专属缓存，临时资源随本次会话登记原点和清单。取消可保留本次工具与诊断记录；其他平台的依赖目录沿用各自实现。

- **Windows 与各 Linux 本地模式：** 保留“外网访问方式”菜单，默认“浏览器访问（指定邮箱收验证码）”。部署者先填本人或受邀者邮箱（多个用逗号分隔），也可由当前进程的 `WB_TUNNEL_ALLOWED_MAIL` 提供。访问者打开本次 HTTPS 公网链接，输入允许的邮箱，再收取并填写一次性验证码才能进入；邮箱只验证公网访问者身份，与维修业务无关。原生 App／普通 API 客户端联调选择“公开演示／App联调（隧道不验证邮箱）”并输入 `PUBLIC`。各平台公开演示均为取得链接即可到达服务入口，仅使用合成资料，固定演示身份和随机网址不能充当私人认证，不接入真实客户数据。

- 选择“服务器部署”：仅准备Go／fzf、构建并前台运行，保留 `127.0.0.1:8098` 和原有数据／密钥语义，不建立隧道，不购买机器，不自动配置反向代理、TLS、服务注册或防火墙。需要固定cpolar地址时先用该模式运行本机服务，再按本文可选cpolar步骤配置，避免同时建立两套公网入口。

- 部署模式用方向键及回车选择，`Esc`／空选取消；仅 Windows／Linux 的“外网访问方式”子菜单按 `←` 返回部署模式。选择阶段取消不会构建或启动业务，MacOS 本地公开确认取消也保留旧实例；已经校验好的 fzf 缓存和本次诊断日志可保留。初始说明前没有业务写入。Go 路径可用 `GO_BIN` 指定，fzf／cloudflared 可用 `WB_FZF_BIN`／`WB_CLOUDFLARED_BIN` 指向本人已核验工具，不需要修改全局 PATH。默认文件模式须确保未误设 `WB_TIDB_DSN`；既有数据库用户保留自己的已核验配置，不把切换为空值当作数据迁移。

`--check`／`--plan`（PowerShell为 `-Check`／`-Plan`）是结构和计划检查，不能代替实机部署验收；模式参数只供计划审阅，正常入口不能用它跳过fzf。

- 取得本次公网地址后自动显示“打开网页”fzf菜单；选择公网或本机地址并回车，即交给系统默认浏览器打开，随后回到菜单继续选择，终端及服务保持运行。Esc或“收起菜单”仅收起菜单，在原终端按回车重新显示；服务器模式列本机地址及扫码页面，回环码明确仅本机。MacOS、Windows和各Linux入口提供相同交互；Linux本机打开浏览器需要已有桌面会话及 `xdg-open`，无桌面环境时提示并保持服务运行。Quick Tunnel每个项目获得自己的随机HTTPS地址；维修8098与学术8080分别用各自部署入口启动，不共用一个服务端口。URL仅表示取得入口，必须完成本节外网验收。Quick官方没有可用性保证，最多200个在途请求且不支持SSE；中国大陆不同运营商可达性另行实测。固定地址可选择下方cpolar或自有域名命名Tunnel，不能把Quick地址写成长期生产入口。[Quick限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

- `Ctrl+C` 停止本次后端和隧道；任一子进程异常或隧道没有及时取得地址时也会回收另一方，保留数据。MacOS 另由独立会话守护处理关窗、入口或终端父进程异常结束；确认再次部署后只接管身份可核验的本项目旧会话，保留首轮原点。各平台都不复用或停止其他服务，外部服务占用端口时报告并停止，不使用 `killall` 或按名字、端口批量结束进程。隧道取得地址默认限45秒，可在本次进程设置 `WB_TUNNEL_START_TIMEOUT=90`（1..600）；应用构建耗时不计入此地址等待。日志位置在终端显示：Shell 主日志位于系统临时目录，本次后端日志写入其中，隧道日志位于本项目独立 Runtime 下的 `deploy-session.*`；Windows 路径以其入口提示为准。日志可能含公网地址，分享前脱敏，不把邮箱、令牌或数据密钥写进 README 或提交仓库。

本路线复用已有电脑，面向前期低访问量、少量合成数据的远程演示；无需先采购云主机。现有本机启动验证不等于已完成穿透或公网业务验收。

### <span id="jobs-toc-heading-38" data-jobs-toc="v2">13.1、运行结构、资源和费用 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

维修后端使用本机 `127.0.0.1:8098`，陈泉羽项目使用 `127.0.0.1:8080`；各自保留数据目录，不合并数据库或复制正在写入的状态。内网穿透客户端与后端运行在同一台机器，直接转发回环地址；不需要把 `WB_ADDR` 改为 `0.0.0.0`，也不需要路由器转发入站端口。浏览器使用两个独立 HTTPS 地址，访问者无需安装穿透客户端。

本机资源仍按本文最低配置留出可用内存；两项目同机运行需合计系统、后台服务与编译峰值，错峰构建，不把单项目预算当成双项目并发保证。未设置 `WB_TIDB_DSN` 时维修使用加密文件快照；学术未设置 `DATABASE_URL` 时也使用独立文件存储，前期不必为了穿透再安装 TiDB／[**PostgreSQL**](https://www.postgresql.org/)。

以下是2026-11-02核对的[**cpolar**](https://www.cpolar.com/)公开套餐，实际价格、资格、地区和连接限制以[官方价目](https://www.cpolar.com/pricing)为准，不在文档中承诺续费价格永久不变：

| 路线 | 费用／带宽 | 两项目使用条件 |
| --- | --- | --- |
| 免费临时验证 | 0元，1Mbps | 随机域名会变化；1个在线客户端进程、4条隧道，适合先验证链路 |
| 基础固定地址 | 99元／年，2Mbps | 3个保留子域名、1进程、8隧道，同机两项目可共用一份套餐额度 |
| 专业自有域名 | 149元／年，3Mbps | 支持自定义域名、2进程、12隧道，域名注册续费另算 |

普通HTTP隧道也会生成公网HTTPS地址，专业版“端到端HTTPS”不等于基础版没有公网HTTPS。套餐流量不限不代表带宽、连接速率或请求大小无限；两条隧道不能据此推断有双倍带宽。已有电脑、宽带之外还需考虑电费、附件增长和备份存储。

### <span id="jobs-toc-heading-39" data-jobs-toc="v2">13.2、按平台准备工具 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

工具品牌可以跨平台复用，安装包、架构、终端语法及后台方式分别选择；不能在Windows运行Mac包，也不能把Linux安装器当作MacOS工具。

| 宿主系统 | 穿透工具准备 | 本机启动入口 |
| --- | --- | --- |
| MacOS | 官网下载Mac M1／ARM64或Intel 64-bit包；可选官方Homebrew tap，zsh前台运行 | [本系统详细步骤](./MacOS/README.md#local-tunnel) |
| Windows | Windows原生安装器／cpolar.exe＋PowerShell；确认默认Windows服务是否已运行 | [本系统详细步骤](./Windows/README.md#local-tunnel) |
| Ubuntu | Linux原生amd64／ARMv8 64bit包；复用已有下载／解压工具，不自动APT安装／升级或注册systemd | [本系统详细步骤](./Ubuntu/README.md#local-tunnel) |
| Debian | Linux原生amd64／ARMv8 64bit包；复用已有下载／解压工具，不自动APT安装／升级或注册systemd | [本系统详细步骤](./Debian/README.md#local-tunnel) |
| Rocky Linux | Linux原生amd64／ARMv8 64bit包；复用已有下载／解压工具，不自动DNF安装／升级或注册systemd | [本系统详细步骤](./RockyLinux/README.md#local-tunnel) |
| Alibaba Cloud Linux | Linux原生amd64／ARMv8 64bit包；复用已有下载／解压工具，不自动DNF安装／升级或注册systemd | [本系统详细步骤](./AlibabaCloudLinux/README.md#local-tunnel) |

上方交互入口默认免费Quick；下文cpolar是需要账户／固定地址时的可选人工路线，先用“服务器部署”保持本机服务，再按平台准备原生客户端。

### <span id="jobs-toc-heading-40" data-jobs-toc="v2">13.3、先启动本机应用并检查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用上方本平台交互入口，选择本地模式会自动先检查本次后端health再连Quick；采用下方cpolar方案时选择服务器模式，只保持本地服务。不要同时运行同一项目两个入口；另一个项目在另一终端按自己的脚本启动。可另开终端检查：

```shell
curl --fail --show-error http://127.0.0.1:8098/api/v38/healthz
curl --fail --show-error http://127.0.0.1:8080/healthz
```

第二项只用于已启动学术服务的情况。维修8099是离线预览，不是真实API；Flutter页面尚未构建时先用原Web工作台与 /admin/ 验证。文件模式与既有TiDB数据互相独立，启动前核对本人目标、密钥和备份，不自动迁移数据。

### <span id="jobs-toc-heading-41" data-jobs-toc="v2">13.4、可选cpolar：用一个客户端映射两个项目 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

cpolar隧道默认网址可被知晓地址者访问，先落实应用权限或额外访问控制，仅用合成资料。不要因cpolar账号令牌存在就认为访客已被认证。在仓库外建立本机私人客户端目录，将实际客户端和专用 `cpolar.yml` 放入该目录。使用本机编辑器写入下例；令牌从本人cpolar控制台取得，替换占位文字后才能运行，不放进仓库、截图、共享压缩包或命令历史。配置文件含凭据，应只允许当前账户读取；MacOS／Linux可用 `chmod 600 ./cpolar.yml`，Windows在“属性→安全”核对当前账户权限。

```yaml
authtoken: "只在本机私人配置中填入实际令牌"
log: ./cpolar.log
log_level: info
tunnels:
  repair:
    proto: http
    addr: 127.0.0.1:8098
    region: cn
    inspect: false
  academic:
    proto: http
    addr: 127.0.0.1:8080
    region: cn
    inspect: false
```

仅测试维修时删除或暂不启动 `academic` 配置；两项目都运行时，在同一个cpolar客户端进程中启动这两个名称。不要为了第二个端口再开第二个cpolar进程，基础／免费套餐只有1个在线进程额度；Windows安装器或既有GUI服务可能已占用该额度，先识别并选择“现有服务管理”或“前台专用进程”其中一种。

```shell
# 以下命令在私人客户端目录运行
./cpolar version
chmod 600 ./cpolar.yml
./cpolar start \
  -config=./cpolar.yml \
  repair academic
```

前台界面应列出两个指向不同回环端口的公网HTTPS地址。只运行维修时将最后的 `repair academic` 改为 `repair`。不要用 `start-all` 启动未经审查的其它隧道，安装器可能带有SSH或远程桌面样例；只保留需要公开的应用入口。

Windows若客户端由安装器装在其它位置，先在安装目录或 `Get-Command cpolar` 返回位置核对实际 `cpolar.exe`，以上相对路径须指向该真实文件；不要把不存在的解压目录当成已安装。已选择Windows服务模式时，在本地 `http://127.0.0.1:9200` 的管理界面分别创建HTTP隧道，名称为repair／academic、本地地址为8098／8080，先停用无关样例，不再运行上面的第二个前台进程。CLI检查界面可能使用4040，以本次终端显示为准；这些管理端口均不对外映射。

### <span id="jobs-toc-heading-42" data-jobs-toc="v2">13.5、保留固定HTTPS地址与同源设置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 免费随机地址只用于初次测试。需要固定地址时，先核对套餐，再到cpolar控制台“预留→保留二级子域名”为两个项目分别保留不同前缀，并记录保留时选择的地区。

- 在各自配置下增加 `subdomain`，填实际已保留前缀；原来的 `region: cn` 必须与保留地区一致。如果使用GUI，则编辑对应隧道，将域名类型改为“二级子域名”，填同一前缀并保存。重新连接后从在线状态复制完整HTTPS地址，不猜测域名后缀。

- 自有域名属于另一条路线：先核对专业版权限、域名所有权和所选地区的域名／备案要求，按控制台给出的目标配置DNS，再填写 `hostname`。本指南不提供购买域名或修改DNS的自动命令，也不承诺任意域名免备案。

- 每个项目“网页、API、下载”共用自己的一个HTTPS域名，整站转发到其端口；维修连接页的API地址留空表示当前网页同源，不填本机127.0.0.1，也不把网页和API拆成两个随机域名。客户端设置填写实际公网HTTPS基址，随机域名变化后需同步更新；手机上的127.0.0.1指手机自身。

- 保留原始公网Host，不添加 `-host-header=rewrite` 或把Host改成localhost。学术服务校验Origin与Host，错误重写会导致首页可开、提交被拒；确需单独网页来源时仅按该项目实际支持的 `CORS_ORIGINS` 精确列入可信HTTPS来源，不用通配符绕过保护。维修自身的同源限制继续保留。

### <span id="jobs-toc-heading-43" data-jobs-toc="v2">13.6、Cloudflare手工诊断与固定域名 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

[**Cloudflare Tunnel**](https://developers.cloudflare.com/tunnel/get-started/)已用于上方本地路线；以下仅用于排查现有客户端或另行配置固定域名，避免与入口重复启动隧道。按[官方下载](https://developers.cloudflare.com/tunnel/downloads/)准备对应系统／CPU的 `cloudflared`，不要拿 Mac 构建包用于 Windows 或 Linux。Quick Tunnel 无需账号和域名，仅适合临时验证；Windows／Linux 的默认受限浏览器方案需要支持 `--allowed-mail` 的版本（静态引导锁基线为2026.10.7，正常部署另查当次官方稳定版并核对必需能力）。下例保留该受限手工方案，在 cloudflared 实际文件目录运行，示例邮箱必须改成本人允许名单；MacOS 自动公开演示入口不使用此邮箱参数，匹配命令见 [MacOS 教程](./MacOS/README.md#local-tunnel)。另一个项目需在另一终端将端口改为8080。手工命令同样只使用合成数据；采用邮箱门禁时原生 API 不能绕过邮箱交互。

```shell
./cloudflared tunnel \
  --url http://127.0.0.1:8098 --allowed-mail tester@example.invalid
```

如果使用包管理器安装并已加入PATH，则使用 `cloudflared` 而非上述相对文件路径。不要将示例邮箱直接当成有效授权。复制本次打印的 `https://…trycloudflare.com` 地址；停止进程后失效，每次创建可能变化。官方明确Quick Tunnel无可用性保证、每条最多200个在途请求、无SSE支持，不能把它作为发布客户端的固定地址。[Quick Tunnel限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

需要固定Cloudflare地址时，使用本人账号和托管于Cloudflare的自有域名创建命名Tunnel，再分别把两个公网主机名映射到 `http://127.0.0.1:8098` 与 `http://127.0.0.1:8080`，不要配置Origin Host重写。域名费用、账号权限和当前免费额度单独核对；连接令牌只存本机私人位置。免费全球网络不等于免费中国大陆加速，需用目标访问者实际运营商网络测试，不保证国内链路稳定。

### <span id="jobs-toc-heading-44" data-jobs-toc="v2">13.7、从手机外网验收真实请求 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 先停留在本机验证正常状态，再让指定测试者关闭Wi-Fi、使用移动网络打开两个实际HTTPS地址；浏览器访问无需安装客户端，原生App需分别设置公网API基址。

- 分别检查维修公网 `/api/v38/healthz` 与学术公网 `/healthz`，再验证各自真实登录及受保护 API 响应。在维修创建一条可识别的合成工单，刷新并重新登录重读，确认后端确实保存；学术按自己的测试账号完成一条合成需求的同样检查。两个项目都有API失败回退本地演示能力，页面出现、样例能操作或仅HTTP首页200均不能证明穿透成功。

- 上传符合当前限制的小测试附件，再以有权账号下载；未登录或无权限账号必须被拒。维修请求体上限12 MiB；学术当前单文件8 MB且上传请求体9 MiB，低带宽、JSON/Base64膨胀与代理请求限制仍可能提前失败。“不限流量”不等于允许无限大文件。

- 退出、切换身份、重复刷新和断网重连，核对真实／演示来源提示、写入未知结果与权限边界。不重放资金或业务写请求来排查隧道。维修仍有既有待修问题与固定演示身份，公网联调先使用合成资料和受控访问，不能直接承载真实客户资料。

### <span id="jobs-toc-heading-45" data-jobs-toc="v2">13.8、日志、在线时间与停止 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双模式入口由同一终端管理本次后端和Quick，Ctrl+C统一停止；只有下面的手工cpolar路线才将应用终端与穿透终端分开保留。Mac根启动器的日志在系统临时目录，启动时显示位置；手工运行的Go日志输出到该终端。上述cpolar专用配置将连接日志写入私人客户端目录的 `cpolar.log`，不要启用请求体调试或把登录、文件、令牌日志公开；分享排查信息前脱敏。

电脑睡眠、合盖、系统重启、宽带断开或客户端停止都会使外网访问中断。MacOS可在系统设置按需保持接电唤醒；Windows可按需调整接电睡眠；无桌面Linux需保持前台会话。先以前台方式验证；之后如确需无人值守，再分别核对MacOS launchd、Windows服务／任务计划、Linux systemd的实际账户、工作目录、配置文件、失败重启与撤销方式。本仓目前没有自动安装这些常驻项，不执行全局电源命令，也不把终端关闭后的持续在线当成已实现。

双模式Quick入口直接在入口终端Ctrl+C停止本次两进程；手工路线的停止顺序：先在穿透终端按 `Ctrl+C` 或在本人客户端管理界面停用相应隧道，再从外部网络发起新请求确认失败；最后在对应Go应用终端按 `Ctrl+C`。一个cpolar进程同时托管两个项目，退出该进程会同时断开两站；只停止维修时可在GUI只停repair，或明确接受短暂重连后以同一配置仅启动academic，不删除另一项目数据。停止不等于取消域名预留或续费，固定地址需在控制台按实际需求解除映射／预留；自有域名DNS和后台自启项也分别撤回。

停止后旧页面仍可能展示缓存或自动回退演示，必须以新的公网健康／API请求失败确认撤回。备份保留维修数据、对应密钥、附件、配置及必要备份；跨Mac／Windows迁移先停写再备份，不让两台电脑同时写同一份文件快照。

### <span id="jobs-toc-heading-46" data-jobs-toc="v2">13.9、常见故障与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 现象 | 检查顺序 |
| --- | --- |
| 本机health失败 | 确认Go构建成功、端口未冲突、使用8098而不是离线8099，查看应用终端 |
| 客户端连不上／进程超限 | 核对匹配平台和架构、出站网络、本人令牌；检查服务与前台是否重复登录 |
| 公网502／404 | 核对隧道目标端口与本机服务；Flutter入口缺构建时先测原Web入口 |
| 首页正常、提交被拒 | 核对浏览器Origin、公网Host、同源API配置与实际后端错误，不关闭鉴权保护 |
| 看似操作成功但后端无记录 | 检查是否已回退演示，查看真实API状态并刷新重读 |
| 附件超时／413／429 | 检查套餐带宽、应用请求体上限、代理大小／连接限制；不要自动重放写请求 |
| 隔天地址失效／手机仍旧地址 | 免费随机地址可能变化；固定地址核对预留地区、在线状态与App配置 |
| 停止后页面仍可看 | 发起全新health/API请求，排除缓存与本地演示回退 |

本节依据项目源码、当前双模式脚本与[cpolar官方文档](https://www.cpolar.com/docs)编写并做文档静态核对；未在本系统安装穿透工具、建立公网隧道或完成外部读写／并发／断电恢复实测。正式开放前完成上述外网验收及现有项目的身份、权限、备份恢复验证；不能把本文步骤存在写成已部署成功。

本机＋内网穿透属于临时运行：确认公网访问前和公网地址就绪后，运行日志都会醒目显示“关闭此运行终端，服务将结束”。支持颜色的终端使用红色加粗；`NO_COLOR`、`TERM=dumb` 或非交互输出使用纯文本，落盘日志不含颜色控制码。按 `Ctrl+C` 正常停止，业务数据和匹配密钥保留。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
