# 啄木鸟维修平台 · V3.8

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

当前提供 [**Go**](https://go.dev/) 服务端、维修工作台网页与 [**iOS**](https://developer.apple.com/ios/) 原生客户端，使用合成账号和样例数据。iOS 工程入口、有限离线范围及各项验证见 [客户端说明](./前端/iOS/README.md) 和 [本轮实现与验证](./iOS实现与验证-2026-10-15.md)。第五轮回归确认 **17 组 P2 尚未修复**：后端 4 组、网页坏响应保护 3 组、独立演示 10 组；其中 15 组为新发现，F03／D10 为上轮补充遗漏，详见 [五次回归报告](./docs/五次回归报告-2026-10-15.md)。错误 2xx 注入和合成演示结果不外推为真实后端越权、实际资金或库存损失。

当前目录按前端、后端、操作系统部署和验证职责组织。此前目录整理仅调整位置与入口，记录见 [目录整理说明](./docs/目录整理说明-2026-10-15.md)；此后新增 iOS 客户端，**没有修复上述 17 组问题，也没有新增其它系统部署能力**。第四轮 14 组修复及用户确认的先款开修 X01 实现保留在 [四次修复说明](./docs/四次修复说明-2026-10-15.md)。

[目录与状态](#directory) · [启动](#startup) · [能力与账号](#capabilities) · [配置](#configuration) · [验证](#verification) · [数据与部署原则](#data-safety) · [部署文档](./部署文档.md) · [代码地图](./代码地图.md)

## 一、<span id="directory">完整目录与实现状态</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以下展示交付职责目录；Go 内部业务包、网页资源及历史证据的细项见各目录说明和 [代码地图](./代码地图.md)。

```text
.
├── README.md
├── AGENTS.md                         本项目代码定位规则
├── 代码地图.md
├── 部署文档.md                       V3.8 运行、配置、备份与边界
├── 【MacOS】启动维修工作台.command   指向 macOS deployment 内脚本的入口
├── 前端/
│   ├── README.md
│   ├── iOS/                          Swift 原生客户端、工程、依赖与测试
│   ├── Android/                      预留：仅说明，无客户端工程
│   ├── 鸿蒙/                         预留：仅说明，无客户端工程
│   ├── 微信小程序/                   预留：仅说明，无小程序工程
│   └── Web网页/
│       ├── README.md
│       ├── 维修工作台/                当前 V3.8 网页：页面、数据、资源与正式测试
│       ├── 旧版用户网页/              旧 /api/v1 用户／师傅网页基线
│       └── 离线预览.mjs              只服务维修工作台静态页面
├── 后端/
│   ├── README.md
│   ├── Go服务端/                     一份通用服务源码，不按操作系统复制
│   │   ├── cmd/workbench/            当前 /api/v38 启动入口
│   │   ├── internal/workbench/       当前业务、权限、存储及测试
│   │   ├── migrations-workbench/     当前聚合快照表资料
│   │   ├── cmd/api/、cmd/migrate/     旧 /api/v1 服务与迁移基线
│   │   └── api/、migrations/、seeds/  旧接口合同与数据库资料
│   ├── 管理后台页面/                 旧 /api/v1 管理网页，非新工作台的另一套后台
│   └── 部署/
│       ├── README.md
│       ├── macOS/
│       │   ├── 部署文档.md
│       │   ├── deployment/
│       │   │   └── 【MacOS】启动维修工作台.command/
│       │   │       ├── 【MacOS】启动维修工作台.command
│       │   │       └── README.md
│       │   └── undeployment/         预留，未提供自动反部署脚本
│       ├── Windows/                 资料预留：部署文档.md、deployment/、undeployment/
│       └── Linux/
│           ├── Ubuntu/              资料预留：部署文档.md、deployment/、undeployment/
│           ├── Debian/              资料预留：部署文档.md、deployment/、undeployment/
│           ├── RockyLinux/          资料预留：部署文档.md、deployment/、undeployment/
│           └── AlibabaCloudLinux/   资料预留：部署文档.md、deployment/、undeployment/
├── 验证/
│   ├── README.md
│   ├── 验证工作台.mjs               独立临时服务的 HTTP 合成流程验证
│   └── 旧版基线/                    原型与旧验证资料
├── 需求/                            原始需求、PRD 历史版本及独立 IM 方案
├── docs/                            接口合同、范围、回归报告、历史日志和截图
├── Tools/go/                        随附第三方 Go 工具链
├── codegraph.json、.codegraph/       代码索引配置与可再生本地索引
└── .runtime/                        本地运行产物、数据及密钥；不随目录整理搬动
```

| 路径 | 当前状态与入口 |
| --- | --- |
| [维修工作台](./前端/Web网页/维修工作台/index.html)＋[Go 服务端](./后端/Go服务端/README.md) | 当前可运行的 V3.8 主体，接口前缀 `/api/v38`；当前仍有回归待修问题 |
| [旧版用户网页](./前端/Web网页/旧版用户网页/README.md)＋[管理后台页面](./后端/管理后台页面/README.md) | 保留旧基线，由旧 `cmd/api` 同源托管于 `/portal/`、`/admin/`；不能与 V3.8 接口混用 |
| [iOS 原生客户端](./前端/iOS/README.md) | 已提供 [**Swift**](https://www.swift.org/) 原生页面、`RepairWorkbench.xcworkspace` 和同源数据测试；构建、运行、签署与文件上传的实际验收范围见本轮报告 |
| [前端目录](./前端/README.md)中的 [**Android**](https://developer.android.com/)／[**鸿蒙**](https://developer.huawei.com/consumer/cn/harmonyos)／[**微信小程序**](https://developers.weixin.qq.com/miniprogram/dev/framework/) | 仍仅预留说明，未提供对应客户端工程、包或构建入口 |
| [操作系统部署](./后端/部署/README.md) | [**macOS**](https://www.apple.com/macos/) 有现成启动脚本；`Windows` 与各 `Linux` 发行版目录仅资料预留，目录存在不代表已实机部署 |
| [验证](./验证/README.md) | 当前 HTTP 验证与旧版基线分开；正式单元测试仍随各源码模块保存 |
| [需求](./需求/物业设备维修服务平台%20PRD%20V3.8（Jobs规范版）.md)与[实现范围](./docs/实现范围.md) | 需求目标与已实现／未验收边界分别记录；目录整理不代表全部 PRD 完成 |

## 二、<span id="startup">启动与网页预览</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 2.1、<span id="mac-startup">macOS 当前启动入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

双击根目录 `【MacOS】启动维修工作台.command`。它指向 [macOS 部署脚本](./后端/部署/macOS/deployment/【MacOS】启动维修工作台.command/README.md)，显示用途后按回车构建并启动；确认前按 `Ctrl+C` 取消，运行期间按 `Ctrl+C` 停止。浏览器访问 [本机工作台](http://127.0.0.1:8098/)。

也可在项目根目录的系统终端执行：

```zsh
/bin/zsh './后端/部署/macOS/deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command'
```

脚本优先使用 `GO_BIN`、其次 `PATH`、最后 `./Tools/go/bin/go`，验证工具后构建。不安装软件或重部署旧业务实例。启动日志位于系统临时目录中的 `【MacOS】启动维修工作台.log`，确认启动后覆盖当次启动日志。自定义数据源、数据与备份目标会按配置读写，应使用演示专用目标。

### 2.2、<span id="offline-preview">纯网页离线预览</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备已有 [**Node.js**](https://nodejs.org/) 20 或以上版本，在项目根目录运行：

```sh
node './前端/Web网页/离线预览.mjs'
```

打开 [离线样例工作台](http://127.0.0.1:8099/)。该服务只托管维修工作台，API 明确返回未连接后台，不读取业务数据库或提供真实登录；`WB_PREVIEW_PORT` 可调整端口，`Ctrl+C` 停止。直接以 `file://` 打开页面也只作合成预览。

### 2.3、<span id="other-platforms">其它操作系统</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Windows**](https://www.microsoft.com/windows) 与 [**Linux**](https://www.kernel.org/) 使用同一份 Go 服务源码；按目标系统、架构准备工具链和部署资料，不复制另一份后端源码。当前 `后端/部署/Windows` 与各 Linux 发行版目录仅预留，未附本轮验证过的自动部署或反部署脚本。跨系统构建记录不等于目标系统的实际部署验收，手动运行及环境变量见 [总部署文档](./部署文档.md)。

### 2.4、<span id="ios-startup">iOS 原生入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

按 [iOS 构建说明](./前端/iOS/README.md#build) 打开 `前端/iOS/RepairWorkbench.xcworkspace`，选择 `RepairWorkbench` Scheme 与可用模拟器。Debug 默认请求 `http://127.0.0.1:8098`，可设置服务地址和短超时；没有服务时可选择合成账号预览有限离线流程，后续成功响应恢复服务端资料。Release 服务地址只接受 HTTPS，目前需另行配置；模拟器构建不等于真机签名或生产分发验收。

## 三、<span id="capabilities">实际能力与演示账号</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

维修工作台提供寄修、上门与配件销售的人工业务主线：受理、检测、报价版本、客户签署、维修／备货、质检、交付验收、资料票款、借还与整单完结。账号及字段权限由后端处理；文件存储使用加密快照，可选择 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 聚合快照存储。分页不代表存储已经拆成完整关系明细表。

维修仅在 `quote.startRequiresPrepayment=true` 的明确约定下，核实约定预付款净额后才可开修；现款销售仍须核实冻结报价全款。人工验收通过或不通过均追加签署历史，质保按中国日历月计算。详细业务合同、已知缺口与边界见 [接口合同](./docs/workbench-contract.md) 和 [实现范围](./docs/实现范围.md)。

页面进入、刷新及写操作照常请求 API，网络故障时回退到独立合成副本并明确来源，后续有效响应恢复服务端数据；当前会话 401 清会话与旧资料。未知写入不应自动重放。第五轮仍发现部分动作／导出关联、嵌套响应及演示规则未完整守住这些约定，不能用离线成功代替服务端确认。

### 3.1、<span id="demo-accounts">V3.8 合成账号</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

统一演示密码为 `Demo-Repair-2026!`，页面切角色会重新登录。以下是 V3.8 样例账号，不是旧版 `cmd/api` 的初始化账号，也不能作为生产身份方案。

| 用户名 | 角色 |
| --- | --- |
| `admin`、`dispatcher` | 管理员、公司订单负责人 |
| `engineer`、`outsource` | 内部师傅、外包办理人员 |
| `warehouse`、`qc`、`finance` | 仓库、质检、财务 |
| `customer`、`customer-peer` | 企业 A 当前及另一经办人，用于授权交接检查 |
| `customer-b` | 企业 B 客户，用于跨企业隔离检查 |
| `supplier` | 供应商 |

地图、实时物流、真实支付、微信／短信、认证电子签、AI 与独立聊天按后续阶段实施；当前手写签名和现金登记不等于认证电子签或真实资金操作。

## 四、<span id="configuration">配置与路径解析</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 变量 | 默认值或用途 |
| --- | --- |
| `GO_BIN` | 启动与验证使用的已有 Go 可执行文件；否则检查 PATH 及随附工具 |
| `WB_ADDR` | `127.0.0.1:8098`，仅回环；端口冲突时使用自己的空闲端口 |
| `WB_WEB_DIR` | 当前网页目录 `./前端/Web网页/维修工作台` |
| `WB_DATA_DIR` | macOS 启动入口使用 `./.runtime/data` |
| `WB_KEY_FILE` | macOS 启动入口使用 `./.runtime/keys/storage.key`；可指定独立密钥位置 |
| `WB_TIDB_DSN` | 空时使用加密文件；非空选择专用 TiDB 数据源 |
| `WB_REQUIRE_DB_TLS` | 要求校验数据库连接身份；实际拓扑的加密链路仍须验证 |
| `WB_BACKUP_DIR` | 指定独立目标才启用定时备份，默认未配置 |
| `WB_BACKUP_INTERVAL_MINUTES` | 定时备份间隔（分钟），详见部署文档 |
| `WB_PREVIEW_PORT` | 纯网页离线预览端口，默认 8099 |

macOS 启动脚本将项目内相对路径按项目根目录解析；直接运行二进制时，相对路径按当前工作目录解析。迁移文件位置不改变已有数据源选择：V3.8 不运行旧 `migrations`，不因目录搬动把文件快照切到数据库。含凭据的 DSN、密钥或会话不写入公开文档、日志和截图。

## 五、<span id="verification">验证入口与当前结果</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以下命令以项目根目录为工作目录，使用已有工具；网页测试无需安装包，Go 仍可能按 `go.mod` 下载缺少的模块：

```sh
node './验证/验证工作台.mjs'
node --test 前端/Web网页/维修工作台/tests/*.test.cjs 后端/管理后台页面/tests/*.test.cjs 前端/Web网页/旧版用户网页/tests/*.test.cjs
./Tools/go/bin/go -C './后端/Go服务端' test -race -p 1 ./...
```

HTTP 验证会构建自己的二进制、临时回环服务及合成数据，退出清理自身进程和目录；不会连接当前业务实例。数据库集成需要独立测试实例及专用变量，不能指向业务数据库。只有匹配架构的随附工具可直接运行，其它系统用 `GO_BIN` 或自身 Go 替换命令。

第五轮正式网页 166 项及 HTTP 6 组通过，但深入诊断确认 17 组 P2 尚未修复：前端最终 25 项为 13 过／12 失败，后端 5 根／20 条含父子结果为 10 过／10 失败，演示 24 项为 8 过／16 失败，失败场景均已复跑。完整结果与限制以 [五次回归报告](./docs/五次回归报告-2026-10-15.md#results) 为准，第四轮与更早通过记录继续保留。

iOS 独立 Foundation 的 20 个数据场景通过；最终冻结 App XCTest 在显式隔离地址下执行 22 项，包含同源 20 项、UIKit 签名像素 1 项、JobsNetworking 隔离真实 API 1 项，0 失败、0 跳过；默认未提供隔离地址时会跳过真实 API 项，其余 21 项仍执行；本轮全量结果来自显式隔离联调。最终 Debug／Release 构建均通过；声明主题色值静态检查 31／31 配对通过，已有真实 API 首页／新单详情与设置三态截图。未覆盖的红钻视觉、签署手势、Files 原件选择上传及真机等见 [iOS 验证记录](./iOS实现与验证-2026-10-15.md#verification)，不以编译或静态检查代替完整界面验收。

历史证据中的旧路径、脚本命令及哈希对应当时的目录，不能直接当成重组后的运行入口；当前应按本页、代码地图和部署文档执行。目录整理后的检查不等于已经修复业务问题。

## 六、<span id="data-safety">数据、部署与反部署原则</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 通用服务源码只保留在 `后端/Go服务端`；按目标操作系统选择 `后端/部署` 内的资料。前端页面位置不决定服务操作系统，预留客户端目录不代表已有应用包。
- `deployment` 保存部署／启动资料，`undeployment` 保存停止／卸载资料的预留位置。当前只有 macOS 启动脚本，停止运行使用 `Ctrl+C`；未提供自动卸载、删除数据库或清空业务数据的脚本。
- 后续反部署脚本必须让运行者选择保留或删除业务数据，默认保留；删除须明确确认范围。保留时同时保留匹配密钥、附件、配置及必要备份，避免只剩无法解密的数据。
- `.runtime`、外部数据源、密钥和备份独立于源码与部署目录保存。目录重组不搬动、清空或重建已有运行数据，不结束用户已运行的服务。
- 密钥与快照配套保管，备份包不含密钥。不要删除 `.runtime` 后期待恢复资料，也不要用新密钥覆盖旧密钥。
- 隔离恢复使用新的不存在目录，并核对最新账号、工单授权、删除约束及已消费请求；不覆盖在线数据或盲目重放未知写入。详见 [备份与恢复](./部署文档.md#isolated-restore)。
- 合成账号、回环 HTTP、加密文件及同盘备份不能替代真实资料内测、可信证书、独立介质、容量、恢复和上线验收。

## 七、<span id="faq">常见问题与工具来源</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 现象 | 排查 |
| --- | --- |
| 端口已占用 | 用自己的空闲 `WB_ADDR` 启动，不结束其它服务 |
| 无可用 Go | 设置 `GO_BIN` 或准备匹配系统、架构的工具；脚本不会联网安装 |
| 只有 README 的客户端／系统目录 | 属预留结构，尚无对应应用工程或自动部署脚本 |
| 页面显示本地演示 | 检查服务、登录、API 及超时后重新加载，不能据此确认真实保存 |
| 写入结果未知 | 保留原输入和请求意图，重新读取核对，避免重复录入收款或签名 |
| 提示数据目录占用或无法解密 | 核对存活进程与原密钥，不删活动锁或生成替代密钥 |
| 旧日志命令找不到目录 | 使用本页的新路径；旧证据只记录历史执行 |

随附 Go 为官方 `go1.27.2.darwin-arm64.tar.gz`，适用 Apple Silicon 的 macOS；其它系统准备各自工具。来源见 [官方 Go 下载页](https://go.dev/dl/)，SHA-256 为 `76812b213b1b2302c978d28fa52fa92d541704b9e7d9d5db8002c50e4018c4c5`，许可见 `./Tools/go/LICENSE`。第三方工具源码保持原样，不作为本项目业务源码修改。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
