# [**Alibaba Cloud Linux**](https://www.alibabacloud.com/product/alinux) 部署

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、目录与入口](#layout)
  - [1.1、最低支持的机器配置](#minimum-machine)
- [二、待实施的部署能力](#pending)
- [三、停止、反部署与数据保留](#stop)
- [四、验证状态](#verification)
- [五、本地部署＋内网穿透](#local-tunnel)
  - [5.1、运行结构、资源和费用](#jobs-toc-heading-8)
  - [5.2、Alibaba Cloud Linux 准备工具](#jobs-toc-heading-9)
  - [5.3、先启动本机应用并检查](#jobs-toc-heading-10)
  - [5.4、可选cpolar：用一个客户端映射两个项目](#jobs-toc-heading-11)
  - [5.5、保留固定HTTPS地址与同源设置](#jobs-toc-heading-12)
  - [5.6、Cloudflare手工诊断与固定域名](#jobs-toc-heading-13)
  - [5.7、从手机外网验收真实请求](#jobs-toc-heading-14)
  - [5.8、日志、在线时间与停止](#jobs-toc-heading-15)
  - [5.9、常见故障与验证边界](#jobs-toc-heading-16)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录保存本系统部署入口、停止说明与操作资料，提供本系统原生的双模式部署入口：本地部署＋内网穿透、服务器部署。配对反部署支持原点恢复和数据备份／清零选择；已完成的静态与隔离验证不能代替本系统实机和公网验收。

**双击部署：** 在本系统目录打开 [双击部署（快捷入口）.desktop](./双击部署（快捷入口）.desktop)。桌面快捷方式用 Bash 调用 `Deployment/` 中唯一同名脚本包，缺失或多候选即停止；部署逻辑只维护在包内。需要图形桌面和终端模拟器，并按文件管理器要求由操作者信任或允许启动；不默认修改信任或安装图形环境。须从本地文件夹启动，文件管理器传入 URI 或相对路径时停止，无桌面时仍用 SSH／终端运行下方规范脚本。完整反部署使用同目录独立的 [双击反部署（快捷入口）.desktop](./双击反部署（快捷入口）.desktop)，只转交 `Undeployment/` 内配对实现，保留原有自述、数据备份默认／清零选择和危险确认；操作前先看 [反部署说明](./Undeployment/README.md)。两个快捷入口按名称区分用途。

本系统部署同时提供各端完整 URL、终端二维码及 fzf“打开扫码页面”；回环明确仅本机，公网码取本轮真实入口。窄终端用本地 HTML／SVG／PNG，二维码失败不停止服务；退出或地址变化使旧页面失效。共同行为与验证见[访问二维码说明](../README.md#access-qr)。

## 一、<span id="layout">目录与入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 位置 | 当前用途 |
| --- | --- |
| [Deployment](./Deployment/README.md) | 已有交互双模式部署入口 |
| [Undeployment](./Undeployment/README.md) | 配对反部署、备份默认／清零选择及停止说明 |
| [项目部署文档](../README.md) | 既有运行方式、数据、安全和备份约束 |
| [实现范围](../../需求/技术方案与实现范围/技术方案与实现范围.md) | 业务能力及已验证／未验证边界 |
| [代码地图](./代码地图/README.md) | 本系统部署入口、停止说明与定位关系 |
| [环境说明](../README.md#machine-environment) | 机器公共工具、缓存与项目运行资料的目录及覆盖参数 |

### 1.1、<span id="minimum-machine">最低支持的机器配置</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

> 以下为当前单实例、少量合成数据演示的最低资源预算（工程估算，未做最低资源或并发压测），正式生产尚无已验收最低值。

| 项目 | 本系统要求 |
| --- | --- |
| 系统 | 64 位发行版，内核与系统库满足所选 Go；Go 1.24 及以上要求 Linux 内核 3.2 或以上 |
| CPU／架构 | 至少 2 个可分配逻辑核／vCPU；x86_64／linux-amd64；ARM64 须另行构建与验证 |
| 内存 | 无桌面整机至少 4 GiB，项目可用至少 2 GiB；源码构建按整机至少 8 GiB、项目可用至少 4 GiB 准备 |
| 磁盘 | 只运行已构建服务至少 10 GiB 可用 SSD；从源码构建并运行至少 20 GiB；另留业务数据、备份与恢复副本空间，保持至少 20% 空闲 |
| 同机数据库演示 | TiDB unistore 路线按至少 4 核、16 GiB 整机 RAM（项目可用 8 GiB）、40 GiB 可用 SSD 准备；仅功能演示，集群须另按官方要求配置 |
| 网络／图形 | API 仅本机回环 8098，可选 TiDB 容器仅回环 14038，无公网带宽下限；首次获取依赖需联网，无需独立显卡 |

现有 Linux AMD64 交叉构建不能代替本发行版、ARM64 或最低资源档的实机部署验收。 只运行档不含编译器、Flutter／原生 SDK、模拟器和容器虚拟机开销；执行总部署文档中的手工构建时须满足构建档。已备齐依赖与构建产物后，文件模式可离线演示。

系统兼容边界依据 [Go 官方最低要求](https://go.dev/wiki/MinimumRequirements)，选用仍获厂商维护的系统；容量增长、TiDB／Docker 的独立要求及正式部署边界见[总部署文档的最低配置](../README.md#minimum-machine)。

## 二、<span id="pending">待实施的部署能力</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本系统入口复用项目内 [**Go**](https://go.dev/) 源码，提供交互模式选择、机器公共环境缓存内依赖准备、本机健康检查和本次子进程管理；不安装系统服务、不修改防火墙。详细操作见下方本地部署章节；必须使用本系统入口而不是跨系统执行脚本。

具体部署前应结合 [项目部署文档](../README.md) 核对专用数据目录、密钥、附件、数据库连接、可信访问入口与恢复方法；已有工具或源码不等于已经部署完成。

## 三、<span id="stop">停止、反部署与数据保留</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

配对反部署从首次部署保存的原点清单核验归属。已登记的后端、隧道与菜单按PID、启动时间及完整命令匹配后停止；本项目新增的程序、SDK、依赖和构建缓存撤回，原有程序／专属环境恢复原件。复用的共享SDK与其它项目始终保留。

完整步骤、默认备份／清零选择、旧部署无清单及失败保护见[配对反部署](./Undeployment/README.md#paired-undeployment)。普通运行终端按Ctrl+C只停止本次服务并保留数据。

## 四、<span id="verification">验证状态</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

目标环境的依赖安装、业务启动、公网隧道和反部署需分别验证。 实际部署按约定系统、版本、架构和业务用例单独验收。

## 五、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署入口提供可交互的双模式选择。正常运行先展示影响范围，回车授权本次项目内准备，再必须通过[**fzf**](https://github.com/junegunn/fzf)选择“本地部署＋内网穿透”或“服务器部署”；不是先装好一套云服务再开始。

在终端进入本文所在目录后执行下面的本系统入口；脚本从自身位置定位项目，支持中文／空格及项目迁移，不依赖调用时的工作目录。请用Bash运行对应发行版入口；没有桌面也能在交互TTY使用fzf。

```bash
/bin/bash './Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh'
```

- 选择“本地部署＋内网穿透”：缺失或不兼容的Go、fzf、cloudflared按需从官方锁定来源准备到机器公共环境目录，先验证SHA256；健康已有工具复用，不升级已有系统工具。构建成功且本次子进程通过本机health后才连接免费Cloudflare Quick Tunnel，无需注册账号、购买域名或云主机。Quick只为本次子进程使用会话内空配置{}并清除继承的TUNNEL_*，不会改动本人已有cloudflared配置或父进程环境。首次下载和Go依赖需要网络；国内网络无法下载时会停止并给出日志，不跳过校验。系统还需自带基础下载／解压／校验工具（Shell需要curl、tar与shasum或sha256sum）；不会自动执行sudo、brew、apt、dnf或全局安装。来源清单见[锁定文件](../deploy-tools.lock.tsv)。

- 本地模式的“外网访问方式”默认选择“浏览器访问（指定邮箱收验证码）”。部署者先填本人或受邀者的邮箱（多个用逗号分隔），也可由当前进程的 `WB_TUNNEL_ALLOWED_MAIL` 提供。访问者打开脚本显示的HTTPS公网链接，输入允许的邮箱，再收取并填写一次性验证码才能进入。邮箱只验证公网访问者身份，与维修业务无关；脚本不会在状态提示或日志中回显邮箱。原生App／普通API客户端无法完成浏览器验证码；联调时选择“公开演示／App联调（隧道不验证邮箱）”，再输入 `PUBLIC`。公开后任何取得链接的人都能到达服务入口，仅允许合成资料；固定演示身份不是私人认证，随机网址也不能充当密码，不接入真实客户数据。

- 选择“服务器部署”：仅准备Go／fzf、构建并前台运行，保留 `127.0.0.1:8098` 和原有数据／密钥语义，不建立隧道，不购买机器，不自动配置反向代理、TLS、服务注册或防火墙。需要固定cpolar地址时先用该模式运行本机服务，再按本文可选cpolar步骤配置，避免同时建立两套公网入口。

- Esc／空选取消，“外网访问方式”子菜单按←返回部署模式；选择阶段取消不会构建或启动业务，已经校验好的fzf缓存和本次诊断日志可保留。初始说明前没有写入；确认后才允许机器公共环境缓存、构建和日志。Go路径可用 `GO_BIN` 指定，fzf／cloudflared可用 `WB_FZF_BIN`／`WB_CLOUDFLARED_BIN` 指向本人已核验工具；不需要修改全局PATH。默认文件模式须确保未误设 `WB_TIDB_DSN`；既有数据库用户保留自己的已核验配置，不把切换为空值当作数据迁移。

只读审阅（不会下载、写缓存／配置／日志、构建、启动后端或连接公网）：

```bash
/bin/bash './Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh' --check
/bin/bash './Deployment/【Linux】部署维修工作台.sh/【Linux】部署维修工作台.sh' --plan --mode local
```

`--check`／`--plan`（PowerShell为 `-Check`／`-Plan`）是结构和计划检查，不能代替实机部署验收；模式参数只供计划审阅，正常入口不能用它跳过fzf。

- 取得本次公网地址后自动显示“打开网页”fzf菜单；选择公网或本机地址并回车，交给系统默认浏览器打开，随后回到菜单继续选择。服务器模式列本机地址及扫码页面，回环码明确仅本机。Esc或“收起菜单”仅收起菜单，回到原终端按回车可重新显示；终端及服务保持运行。Linux需要已有桌面会话和 `xdg-open`，无桌面、工具缺失或打开失败会明确提示，仍可重选且服务继续运行；不会安装桌面依赖。终端保持运行，Quick Tunnel每个项目获得自己的随机HTTPS地址；维修8098与学术8080分别用各自部署入口启动，不共用一个服务端口。URL仅表示取得入口，必须完成本节外网验收。Quick官方没有可用性保证，最多200个在途请求且不支持SSE；中国大陆不同运营商可达性另行实测。固定地址可选择下方cpolar或自有域名命名Tunnel，不能把Quick地址写成长期生产入口。[Quick限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

- Ctrl+C停止本次后端和本次隧道；任一子进程异常或隧道没有及时取得地址时也会回收另一方，保留数据。脚本先检查目标TCP端口，不复用或停止已有服务；只记录并终止本次PID，不使用killall／按名字批量结束。Shell取得地址默认限45秒，可在本次进程设置 `WB_TUNNEL_START_TIMEOUT=90`（1..600）；应用构建耗时不计入此地址等待。日志位置在终端显示：Shell主日志位于系统临时目录，本次后端日志写入其中，隧道日志位于本项目独立 Runtime 下的 `deploy-session.*`；Windows路径以其入口提示为准。日志可能含公网地址，分享前脱敏；不把邮箱、令牌、数据密钥写进README或提交仓库。

本路线复用已有电脑，面向前期低访问量、少量合成数据的远程演示；无需先采购云主机。本系统已有交互部署入口；反部署使用原点清单与配对脚本，本系统实机和公网读写仍待验收。

### <span id="jobs-toc-heading-8" data-jobs-toc="v2">5.1、运行结构、资源和费用 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

维修后端使用本机 `127.0.0.1:8098`，陈泉羽项目使用 `127.0.0.1:8080`；各自保留数据目录，不合并数据库或复制正在写入的状态。内网穿透客户端与后端运行在同一台机器，直接转发回环地址；不需要把 `WB_ADDR` 改为 `0.0.0.0`，也不需要路由器转发入站端口。浏览器使用两个独立 HTTPS 地址，访问者无需安装穿透客户端。

本机资源仍按本文最低配置留出可用内存；两项目同机运行需合计系统、后台服务与编译峰值，错峰构建，不把单项目预算当成双项目并发保证。未设置 `WB_TIDB_DSN` 时维修使用加密文件快照；学术未设置 `DATABASE_URL` 时也使用独立文件存储，前期不必为了穿透再安装 TiDB／[**PostgreSQL**](https://www.postgresql.org/)。

以下是2026-11-02核对的[**cpolar**](https://www.cpolar.com/)公开套餐，实际价格、资格、地区和连接限制以[官方价目](https://www.cpolar.com/pricing)为准，不在文档中承诺续费价格永久不变：

| 路线 | 费用／带宽 | 两项目使用条件 |
| --- | --- | --- |
| 免费临时验证 | 0元，1Mbps | 随机域名会变化；1个在线客户端进程、4条隧道，适合先验证链路 |
| 基础固定地址 | 99元／年，2Mbps | 3个保留子域名、1进程、8隧道，同机两项目可共用一份套餐额度 |
| 专业自有域名 | 149元／年，3Mbps | 支持自定义域名、2进程、12隧道，域名注册续费另算 |

普通HTTP隧道也会生成公网HTTPS地址，专业版“端到端HTTPS”不等于基础版没有公网HTTPS。套餐流量不限不代表带宽、连接速率或请求大小无限；两条隧道不能据此推断有双倍带宽。已有电脑、宽带之外还需考虑电费、附件增长和备份存储。

### <span id="jobs-toc-heading-9" data-jobs-toc="v2">5.2、Alibaba Cloud Linux 准备工具 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从[cpolar官方下载页](https://www.cpolar.com/download)选择Alibaba Cloud Linux对应的真实客户端，保存在仓库之外的私人目录；不把令牌、隧道配置或第三方二进制混入本项目源码。先核对来源、包的CPU架构和可执行版本。

本系统使用Linux包，`uname -m`为`x86_64`时选择64-bit／amd64，`aarch64`时选择ARMv8 64bit／arm64；其它架构先核对Go与客户端是否同时支持。以下命令只用于识别系统：

```shell
cat /etc/os-release
uname -m
command -v go
command -v curl
command -v unzip
```

仅在确实缺少下载／解压工具时，由维护者检查本机已配置软件源后执行下面的依赖安装；该动作需要管理员权限并改变系统软件包。cpolar本身仍从官网下载匹配Linux包，解压到私人目录，不执行自动注册服务的远程安装脚本。

```shell
sudo dnf install curl unzip ca-certificates
```

在解压目录用 `./cpolar version` 检查；只有确认是刚下载的普通可执行文件且执行位确实丢失时才对这一个文件执行 `chmod u+x ./cpolar`。Rocky Linux／Alibaba Cloud Linux不照搬Ubuntu的apt命令。没有桌面时直接使用下方YAML与单进程CLI，不依赖浏览器双击或图形安装器。

### <span id="jobs-toc-heading-10" data-jobs-toc="v2">5.3、先启动本机应用并检查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用上方本平台交互入口，选择本地模式会自动先检查本次后端health再连Quick；采用下方cpolar方案时选择服务器模式，只保持本地服务。不要同时运行同一项目两个入口；另一个项目在另一终端按自己的脚本启动。可另开终端检查：

```shell
curl --fail --show-error http://127.0.0.1:8098/api/v38/healthz
curl --fail --show-error http://127.0.0.1:8080/healthz
```

第二项只用于已启动学术服务的情况。维修8099是离线预览，不是真实API；Flutter页面尚未构建时先用原Web工作台与 /admin/ 验证。文件模式与既有TiDB数据互相独立，启动前核对本人目标、密钥和备份，不自动迁移数据。

### <span id="jobs-toc-heading-11" data-jobs-toc="v2">5.4、可选cpolar：用一个客户端映射两个项目 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

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

### <span id="jobs-toc-heading-12" data-jobs-toc="v2">5.5、保留固定HTTPS地址与同源设置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 免费随机地址只用于初次测试。需要固定地址时，先核对套餐，再到cpolar控制台“预留→保留二级子域名”为两个项目分别保留不同前缀，并记录保留时选择的地区。

- 在各自配置下增加 `subdomain`，填实际已保留前缀；原来的 `region: cn` 必须与保留地区一致。如果使用GUI，则编辑对应隧道，将域名类型改为“二级子域名”，填同一前缀并保存。重新连接后从在线状态复制完整HTTPS地址，不猜测域名后缀。

- 自有域名属于另一条路线：先核对专业版权限、域名所有权和所选地区的域名／备案要求，按控制台给出的目标配置DNS，再填写 `hostname`。本指南不提供购买域名或修改DNS的自动命令，也不承诺任意域名免备案。

- 每个项目“网页、API、下载”共用自己的一个HTTPS域名，整站转发到其端口；维修连接页的API地址留空表示当前网页同源，不填本机127.0.0.1，也不把网页和API拆成两个随机域名。客户端设置填写实际公网HTTPS基址，随机域名变化后需同步更新；手机上的127.0.0.1指手机自身。

- 保留原始公网Host，不添加 `-host-header=rewrite` 或把Host改成localhost。学术服务校验Origin与Host，错误重写会导致首页可开、提交被拒；确需单独网页来源时仅按该项目实际支持的 `CORS_ORIGINS` 精确列入可信HTTPS来源，不用通配符绕过保护。维修自身的同源限制继续保留。

### <span id="jobs-toc-heading-13" data-jobs-toc="v2">5.6、Cloudflare手工诊断与固定域名 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

[**Cloudflare Tunnel**](https://developers.cloudflare.com/tunnel/get-started/)已用于上方本地默认路线；以下仅用于排查现有客户端或另行配置固定域名，避免与入口重复启动隧道。按[官方下载](https://developers.cloudflare.com/tunnel/downloads/)准备对应系统／CPU的 `cloudflared`，不要拿Mac构建包用于Windows或Linux。Quick Tunnel无需账号和域名，仅适合临时验证；默认受限浏览器方案需要支持 `--allowed-mail` 的版本（本仓锁定2026.10.7）。以下在cloudflared实际文件目录运行，示例邮箱必须改成本人允许名单；另一个项目需在另一终端将端口改为8080。手工命令同样只使用合成数据；原生API不能绕过邮箱交互。

```shell
./cloudflared tunnel \
  --url http://127.0.0.1:8098 --allowed-mail tester@example.invalid
```

如果使用包管理器安装并已加入PATH，则使用 `cloudflared` 而非上述相对文件路径。不要将示例邮箱直接当成有效授权。复制本次打印的 `https://…trycloudflare.com` 地址；停止进程后失效，每次创建可能变化。官方明确Quick Tunnel无可用性保证、每条最多200个在途请求、无SSE支持，不能把它作为发布客户端的固定地址。[Quick Tunnel限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

需要固定Cloudflare地址时，使用本人账号和托管于Cloudflare的自有域名创建命名Tunnel，再分别把两个公网主机名映射到 `http://127.0.0.1:8098` 与 `http://127.0.0.1:8080`，不要配置Origin Host重写。域名费用、账号权限和当前免费额度单独核对；连接令牌只存本机私人位置。免费全球网络不等于免费中国大陆加速，需用目标访问者实际运营商网络测试，不保证国内链路稳定。

### <span id="jobs-toc-heading-14" data-jobs-toc="v2">5.7、从手机外网验收真实请求 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 先停留在本机验证正常状态，再让指定测试者关闭Wi-Fi、使用移动网络打开两个实际HTTPS地址；浏览器访问无需安装客户端，原生App需分别设置公网API基址。

- 分别检查维修公网 `/api/v38/healthz` 与学术公网 `/healthz`，再验证各自真实登录及受保护 API 响应。在维修创建一条可识别的合成工单，刷新并重新登录重读，确认后端确实保存；学术按自己的测试账号完成一条合成需求的同样检查。两个项目都有API失败回退本地演示能力，页面出现、样例能操作或仅HTTP首页200均不能证明穿透成功。

- 上传符合当前限制的小测试附件，再以有权账号下载；未登录或无权限账号必须被拒。维修请求体上限12 MiB；学术当前单文件8 MB且上传请求体9 MiB，低带宽、JSON/Base64膨胀与代理请求限制仍可能提前失败。“不限流量”不等于允许无限大文件。

- 退出、切换身份、重复刷新和断网重连，核对真实／演示来源提示、写入未知结果与权限边界。不重放资金或业务写请求来排查隧道。维修仍有既有待修问题与固定演示身份，公网联调先使用合成资料和受控访问，不能直接承载真实客户资料。

### <span id="jobs-toc-heading-15" data-jobs-toc="v2">5.8、日志、在线时间与停止 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双模式入口由同一终端管理本次后端和Quick，Ctrl+C统一停止；只有下面的手工cpolar路线才将应用终端与穿透终端分开保留。Mac根启动器的日志在系统临时目录，启动时显示位置；手工运行的Go日志输出到该终端。上述cpolar专用配置将连接日志写入私人客户端目录的 `cpolar.log`，不要启用请求体调试或把登录、文件、令牌日志公开；分享排查信息前脱敏。

电脑睡眠、合盖、系统重启、宽带断开或客户端停止都会使外网访问中断。MacOS可在系统设置按需保持接电唤醒；Windows可按需调整接电睡眠；无桌面Linux需保持前台会话。先以前台方式验证；之后如确需无人值守，再分别核对MacOS launchd、Windows服务／任务计划、Linux systemd的实际账户、工作目录、配置文件、失败重启与撤销方式。本仓目前没有自动安装这些常驻项，不执行全局电源命令，也不把终端关闭后的持续在线当成已实现。

双模式Quick入口直接在入口终端Ctrl+C停止本次两进程；手工路线的停止顺序：先在穿透终端按 `Ctrl+C` 或在本人客户端管理界面停用相应隧道，再从外部网络发起新请求确认失败；最后在对应Go应用终端按 `Ctrl+C`。一个cpolar进程同时托管两个项目，退出该进程会同时断开两站；只停止维修时可在GUI只停repair，或明确接受短暂重连后以同一配置仅启动academic，不删除另一项目数据。停止不等于取消域名预留或续费，固定地址需在控制台按实际需求解除映射／预留；自有域名DNS和后台自启项也分别撤回。

停止后旧页面仍可能展示缓存或自动回退演示，必须以新的公网健康／API请求失败确认撤回。备份保留维修数据、对应密钥、附件、配置及必要备份；跨Mac／Windows迁移先停写再备份，不让两台电脑同时写同一份文件快照。

### <span id="jobs-toc-heading-16" data-jobs-toc="v2">5.9、常见故障与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

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

