# 啄木鸟维修平台 · iOS 原生客户端

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、结构与能力](#architecture)
- [二、工程与构建入口](#build)
  - [2.1、CocoaPods 安装网络选路](#cocoapods-network-route)
- [三、API 优先与独立演示](#fallback)
- [四、项目配置支持](#configuration)
  - [4.1、依赖与工程维护](#dependencies)
  - [4.2、随项目私库](#private-libraries)
- [五、验证与已知边界](#verification)
- [六、代码地图](#ios-map)
  - [6.1、工程与外置测试定位](#external-test-references)
  - [6.2、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录为 [**iOS**](https://developer.apple.com/ios/) 原生客户端，使用 [**Swift**](https://www.swift.org/) 和 [**UIKit**](https://developer.apple.com/documentation/uikit) 编写，连接现有 `/api/v38` 服务。主入口是 `RepairWorkbench.xcworkspace`，最低系统版本为 iOS 15.0。工程架构、代码地图、依赖清单与验证方法在本文统一维护，各端验收状态统一见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。

[结构与能力](#architecture) · [构建入口](#build) · [API 与演示](#fallback) · [依赖与私库](#dependencies) · [验证边界](#verification) · [代码地图](#ios-map)

## 一、<span id="architecture">结构与能力</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
iOS/
├── App/
│   ├── Bootstrap/                App、Scene 与身份切换协调
│   ├── Data/                     合同解码、网络适配、会话、分页与独立演示
│   ├── UI/                       Jobs 工厂、业务表单、页面容器与主题
│   ├── Features/                 登录、工作台、工单、借还、设置与签署
│   ├── Platform/                 真实系统类型的带参创建工厂
│   └── Resource/                 Info 配置、主题数据、本地 Logo 与隐私清单
├── JobsByPods/                   从 Jobs Swift 基座复用的本地模块
├── Scripts/生成工程.rb            增量维护工程文件引用和共享 Scheme
├── Podfile、Podfile.deps、Podfile.lock
├── RepairWorkbench.xcodeproj
└── RepairWorkbench.xcworkspace   安装依赖后从这里打开
```

测试物理文件集中在外层 [Data](../../../../测试/前端/移动端/iOS/Data) 与 [Standalone](../../../../测试/前端/移动端/iOS/Standalone)：前者保存 Foundation 合同与 Store 场景供 XCTest 运行，后者提供不依赖 UIKit 的同场景运行入口；Xcode 测试 Target 通过工程引用加载外置源文件。

| 页面 | 实际职责 |
| --- | --- |
| 登录与工作台 | 真实认证、来源提示、概览数字、任务与刷新；可选择合成账号尝试演示 |
| 工单 | 业务类型、状态、搜索与分页；创建工单、读取完整详情、查看票款／资料／事件及关联借还 |
| 办理表单 | 根据完整详情返回的 `allowedActions` 展示操作；金额转整数分、日期按中国日历处理，保留未知结果输入与重试意图 |
| 签署 | 原生手写签名入口；真实签署和验收必须由服务端确认，独立演示不伪造签署结果 |
| 资料归档 | 文字事实、Files 原件选择与上传；PDF、PNG、JPEG、MP4、MP3、WAV，单份最多 8 MiB，实际内容与权限由服务端校验 |
| 库存借还 | 配件、尚欠与部分独立跟踪台账；授权仓库／管理员借出、归还，管理员批准耗用／处置／转出 |
| 设置 | 十语切换；白天、黑夜、跟随系统；Debug 服务地址与超时；服务端管理员公司配置；退出并清授权缓存 |

设置中选取语言后点击“应用语言”；外观按钮选择后立即生效。语言提供简体中文、繁体中文、藏文、英文、日文、法文、西班牙文、德文、俄文与韩文；主题提供白天、黑夜与跟随系统，选择保存在本机偏好中。业务名称、客户输入和服务端业务正文保持原值。界面文案以[共享语言目录](../../共享组件/Resources/ui-l10n.json)为源，打包资源随应用离线读取。

动态列表和详情记录区均提供 JobsEmptyAuto 按钮空态与重新加载。页面使用 `BaseVC`，自维护布局使用 [**SnapKit**](https://github.com/SnapKit/SnapKit)，系统对象／按钮配置复用 `JobsByUIKit`、`JobsSwiftDSL`。长生命周期控件由属性持有，动态行由 `WBPageView.rows` 持有。

原生通用表单不覆盖全部管理能力。停机异议复核等暂未适配动作会明确引导网页；账号管理、审计／导出、备份恢复及完整采购不能因菜单或模型存在而视为已验收。文件入口读取用户选择的原件，不提供相机／相册直接拍摄、录音或录像；每种文件格式的实际上传结果分别以运行证据为准。真实可办理事项仍由服务端权限与业务条件决定。

## 二、<span id="build">工程与构建入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备 [**Xcode**](https://developer.apple.com/xcode/)、[**Ruby**](https://www.ruby-lang.org)、`xcodeproj` gem 和 [**CocoaPods**](https://cocoapods.org/)。依赖版本以 `Podfile.lock` 为准；工具链及 SDK 版本由构建环境记录，不在脚本内自动安装或升级工具。

在本目录打开终端，维护源码引用、安装依赖并打开工作区：

```sh
ruby './Scripts/生成工程.rb'
pod install --no-repo-update
open './RepairWorkbench.xcworkspace'
```

在 Xcode 选择 `RepairWorkbench` Scheme 和本机可用 iPhone 模拟器后 Run。测试入口是同 Scheme 的 `RepairWorkbenchTests`。添加 App 或外层 `测试/前端/移动端/iOS/Data` 文件后运行工程生成脚本；它只维护工程引用，不安装依赖、不构建、不部署。

命令行模拟器构建示例（在本端目录执行）：

```sh
xcodebuild \
  -workspace RepairWorkbench.xcworkspace \
  -scheme RepairWorkbench \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TMPDIR/RepairWorkbenchDerivedData" \
  CODE_SIGNING_ALLOWED=NO build
```

该命令是模拟器构建示例；文档中的命令不代表已执行通过。实际执行状态见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)，设备签名和分发另行验收。

### 2.1、<span id="cocoapods-network-route">CocoaPods 安装网络选路</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**CocoaPods**](https://cocoapods.org/) 的安装和更新在解析依赖前，先准备本次下载链路，再实测公共 Specs；终端、手动入口与 CI 使用同一 Podfile 挂载。

| 真实入口 | 执行顺序 |
| --- | --- |
| [Podfile](./Podfile) | 网络 / 代理实测 → 官方归档注册 → Git / CDN Specs 选源 → 依赖安装 |

在相应 Podfile 所在目录执行安装命令：

```zsh
pod install
```

优先验证明确配置的代理；未指定或不可用时检查当前链路，再测试 MacOS 已启用的 HTTP / HTTPS / SOCKS 手工代理。验证通过后只让当前安装进程与子进程继承，退出恢复，不修改全局代理或 Git 配置。公共源比较同一 podspec 的有效响应及耗时；查询命令不联网，失败告警并回用已有配置 / 缓存。脚本模块缺失或异常时沿用 CocoaPods 安装流程。

原生源码下载继承同次环境；归档回退仅覆盖已核验的 AMPopTip 4.12.0 发布请求，不会添加该依赖，也不泛化为任意仓库或版本镜像。版本、私有源与锁文件内容由正常 CocoaPods 安装维护，脚本不删除 Pods 或锁文件。探测通过仍需完整安装成功才能判定依赖已就绪。

[网络适配、开关与测试](<./ScriptsByPods/【MacOS】🌐CocoaPods网络适配.command/README.md>) · [Specs 选源、超时与日志](<./ScriptsByPods/【MacOS】🌐CocoaPods源自动选择.command/README.md>)。迁移时保留完整 ScriptsByPods 包及各 Podfile 的相对加载路径。网络摘要显示在安装输出中，Specs 日志写系统临时目录并按 Podfile 所在目录隔离。

## 三、<span id="fallback">API 优先与独立演示</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产网络经过 `WBJobsTransport` → `JobsNetworking`，使用 `/api/v38`、关闭缓存与自动重试。默认超时 2.5 秒，Debug 可配置 0.5～30 秒。进入、刷新和可提交操作均先尝试 API；服务不可达或响应无法解析时，展示独立合成样例并明确标识来源。后续刷新或操作继续探测接口；恢复后读取真实授权数据，不将合成单号提交到真实服务。

会话 `generation` 与读取 `readRevision` 分别阻止身份切换及筛选改变后的迟到结果；忙碌计数在有效会话内成对收尾。读取成功须验证当前认证身份、请求页及响应结构，再写入缓存。来源变化后迟到的真实写入不能混入演示数组；结果未知时保留原请求意图，供同键核对重试。

当前会话 401 清除授权资料并返回登录；服务端明确拒绝保持拒绝语义。真实写入超时、坏响应或来源变化时提示结果未知，不显示本地成功，不自动重放；同一页面重试保留原请求意图。切换账号／服务地址、退出时清除旧缓存和意图，旧会话迟到结果不会恢复权限。

原生手写画布导出的 PNG 为 640×240，渲染格式固定 `scale=1`、`opaque=true`；提交报价签署／验收前核对条款和开页的身份／地址／来源上下文。Files 通过安全作用域 URL 读取用户选定的原件，读取前后均检查 8 MiB 限制，WAV 使用 `audio/wav`；上传不携带 `stage`，阶段由服务端记录。日期统一使用 Gregorian／Asia-Shanghai，按日历加日并覆盖截止日全天。主题资源初始化后才能设置主题，已有按钮配置随主题重放。

本地数据只在 App 进程内演示，不代替业务持久化。离线支持有限的受理、检测、报价／审核、开修、完工、质检、交付、备注和异议动作；客户签署／验收、借还过账、财务与整单完结等需要真实服务。演示与真实服务同样保留维修先款开修的明确约定：仅 `startRequiresPrepayment=true` 才核实约定预付款；现款销售仍以冻结报价全额为门槛。完整合同以 [服务端合同](../../../后端/README.md#api-contract) 为准。

无服务器时直接运行 Debug App，选择合成账号即可预览；通用演示密码为 `Demo-Repair-2026!`。所有演示资料均为合成，勿把真实密码或附件填入离线演示。本地 Logo 随 App 打包，空态图片可离线显示，不依赖外链图片。

模拟器的 `127.0.0.1:8098` 指向本机开发服务；真机须使用设备可达的服务地址。服务启动、隔离数据及部署说明见 [总部署文档](../../../../部署/README.md)，客户端不会自动启动或停止后端。

## 四、<span id="configuration">项目配置支持</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 配置 | 当前行为 |
| --- | --- |
| `Info.Debug.plist` | 允许本地 HTTP 调试，默认 `http://127.0.0.1:8098`；设置可更换地址和超时；启动参数 `--wb-api-url` 可临时指定地址 |
| `Info.Release.plist` | 不包含 Debug 的 ATS 放宽；只读取 `WBProductionAPIURL` 且要求 HTTPS，目前为空，需部署时配置真实地址 |
| `Podfile.deps` | 只列依赖，逐条写本地 `:path`，不执行外部脚本；本地 Jobs 模块来自 Jobs Swift 基座，外部依赖由 CocoaPods 管理 |
| `Podfile` | 静态 frameworks、统一最低系统／Swift 版本；post_install 将依赖清单挂到 Pods 工程根组，以 Ruby 类型展示，保存后重新打开检查根对象和无构建阶段引用；维护失败会告警并尝试恢复工程文件 |
| `Scripts/生成工程.rb` | 增量添加 App、Data 测试、资源与配置引用，维护 `RepairWorkbench` 共享 Scheme；重复执行保留已有引用与 CocoaPods 集成 |
| `JobsThemeResources.json` | 明暗成对颜色，App 设置选择三态；主题与系统外观可不同，切换时更新已有页面和按钮配置 |

生成的 `Pods/` 与供应商源码不作为 App 业务修改位置。复用蓝本为 `JobsBaseConfig@JobsSwiftBaseConfigDemo`，项目通过 `JobsByPods` 集成本地模块；维护边界见[依赖与工程维护](#dependencies)。

目前工程尚未提供已验收的自动 IPA 留存阶段；模拟器构建、真机签名、IPA 留存与正式分发是不同验证项，状态见 [交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

### 4.1、<span id="dependencies">依赖与工程维护</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本地模块复用蓝本 `JobsBaseConfig@JobsSwiftBaseConfigDemo`，由本项目 `JobsByPods/` 集成。业务修改在 `App/` 与自维护测试完成；蓝本、生成的 `Pods/`、第三方及供应商源码按各自所有权维护。

| 依赖／配置 | 职责与约束 |
| --- | --- |
| `JobsByUIKit`、`JobsSwiftDSL` | 系统对象工厂、`byXxx` 连续配置、按钮配置与事件、列表空态 |
| `JobsSwiftBaseDefines`、`JobsSwiftBlock` | `JobsCor`／`JobsFont`／`YES`、主题中心与构造闭包 |
| `JobsInheritance` | `BaseVC` 等页面基类 |
| `JobsNetworking` | 业务网络配置与响应解码；模块选择以 `Podfile.deps` 为准 |
| [**SnapKit**](https://github.com/SnapKit/SnapKit) | App 自维护布局 |
| `Podfile.deps` | 逐条声明本地相对路径及外部依赖，安装脚本与 hook 放在 `Podfile` |
| `Podfile` | [**CocoaPods**](https://cocoapods.org/) 静态 frameworks、系统及 Swift 版本；安装前准备当前进程网络，选取 Specs 来源；`post_install` 维护依赖清单的 Pods 根组引用 |
| `Scripts/生成工程.rb` | 增量维护 App、测试、资源、配置引用和共享 Scheme，不安装依赖、不构建、不部署 |

明确随项目维护的 Jobs 私库按 `Podfile.deps`、`Podfile.lock` 和实际依赖树完整保留；公共 SDK 与公共依赖在目标机器准备，不作为源码附件整体分发，不按上表几个模块名裁剪。`Podfile.deps` 在 Pods 根组唯一展示，文件类型为 `text.script.ruby`，不进入编译阶段；写入后重新打开检查根对象、引用及构建阶段，维护失败告警并尝试恢复工程文件。文件类型校验与 Xcode 内 Ruby 图标的人工核对分别进行。

安装网络探测、失败回退与日志见[安装网络选路](#cocoapods-network-route)。

### 4.2、<span id="private-libraries">随项目私库</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本项目明确随源码保留下列 JobsByPods 本地模块，用于现有 iOS 工程；它们属于源码依赖，不是 Apple SDK 或公共 CocoaPods 下载缓存。来源为既有 Jobs Swift 工程蓝本，接入以 `./Podfile.deps`、`./Podfile.lock` 和包内 podspec 为准。未提供的独立版本或授权信息留空，不补造。

| 模块 | 本项目位置 | podspec 版本 |
| --- | --- | --- |
| JobsByQuartzCore@Pods | [本地源码](<./JobsByPods/JobsByQuartzCore@Pods/>) | 0.0.1 |
| JobsByUIKit@Pods | [本地源码](<./JobsByPods/JobsByUIKit@Pods/>) | 0.0.1 |
| JobsByWebKit@Pods | [本地源码](<./JobsByPods/JobsByWebKit@Pods/>) | 0.0.1 |
| JobsGetWindow@Pods | [本地源码](<./JobsByPods/JobsGetWindow@Pods/>) | 0.1.14 |
| JobsImageTools@Pods | [本地源码](<./JobsByPods/JobsImageTools@Pods/>) | 0.1.14 |
| JobsInheritance@Pods | [本地源码](<./JobsByPods/JobsInheritance@Pods/>) | 0.0.1 |
| JobsNavBar@Pods | [本地源码](<./JobsByPods/JobsNavBar@Pods/>) | 0.1.14 |
| JobsNetworking@Pods | [本地源码](<./JobsByPods/JobsNetworking@Pods/>) | 1.0.1 |
| JobsScale@Pods | [本地源码](<./JobsByPods/JobsScale@Pods/>) | 0.1.14 |
| JobsSwiftBaseDefines@Pods | [本地源码](<./JobsByPods/JobsSwiftBaseDefines@Pods/>) | 0.1.6 |
| JobsSwiftBlock@Pods | [本地源码](<./JobsByPods/JobsSwiftBlock@Pods/>) | 0.1.0 |
| JobsSwiftDSL@Pods | [本地源码](<./JobsByPods/JobsSwiftDSL@Pods/>) | 0.1.0 |
| JobsSwiftDebugTools@Pods | [本地源码](<./JobsByPods/JobsSwiftDebugTools@Pods/>) | 0.0.1 |
| JobsSwiftFoundation@Pods | [本地源码](<./JobsByPods/JobsSwiftFoundation@Pods/>) | 0.1.1 |
| JobsSwiftStandardLibrary@Pods | [本地源码](<./JobsByPods/JobsSwiftStandardLibrary@Pods/>) | 0.0.1 |
| JobsSwiftTimer@Pods | [本地源码](<./JobsByPods/JobsSwiftTimer@Pods/>) | 0.1.0 |
| JobsTextTools@Pods | [本地源码](<./JobsByPods/JobsTextTools@Pods/>) | 0.1.14 |
| JobsToast@Pods | [本地源码](<./JobsByPods/JobsToast@Pods/>) | 0.1.14 |
| JobsViewPush@Pods | [本地源码](<./JobsByPods/JobsViewPush@Pods/>) | 0.0.1 |
| Jobsl10n@Pods | [本地源码](<./JobsByPods/Jobsl10n@Pods/>) | 0.1.14 |

- 维护与来源：沿用现有模块、包内文件头和许可证；具体公开与私有权限不由目录名推断。
- 引用方式：App 的 `Podfile.deps` 逐条相对引用当前工程内的 `JobsByPods/`，不要求拷贝开发机 SDK。
- 公共依赖：Xcode、Ruby、CocoaPods 及公共包由目标机器准备，版本约束继续保存在声明和锁文件。标准工具必需的生成沙盒仅为本机工作缓存，不作为源码附件分发。
- 文档整理不修改私库模块正文；新增或修改依赖须按实际声明、锁文件与包内元数据核对。

## 五、<span id="verification">验证与已知边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

测试分为共享 Foundation 场景、UIKit 像素、隔离真实 API、模拟器／真机交互和正式签名分发。共享场景由外层 `测试/前端/移动端/iOS/Data` 和 `测试/前端/移动端/iOS/Standalone` 复用，不因运行入口不同重复计算覆盖。真实 API 测试仅在显式注入 `WB_INTEGRATION_URL` 时执行，只允许带独立端口的 `127.0.0.1`，禁止使用日常 8098；未提供地址时该项跳过，不能计为通过。

| 验证层 | 要检查的内容 | 边界 |
| --- | --- | --- |
| 工程与依赖 | Ruby 语法、引用唯一性、脚本实际挂载、依赖安装与重复安装、Debug／Release 构建 | 语法检查不运行安装 hook；安装成功不代替构建 |
| Foundation 共享场景 | 合同、分页、逆序回包、未知写入意图、身份撤销、忙碌归零、来源隔离 | 外层 `测试/前端/移动端/iOS/Data` 与 `Standalone` 使用相同场景，不重复累加覆盖 |
| UIKit 像素 | 真实渲染器输出 PNG 后回读尺寸与像素 | 不代替实际手指拖动、条款确认和提交 |
| 隔离真实 API | JobsNetworking 登录、详情、创建后重读、错误密码 401、主线程交付 | 显式注入 `WB_INTEGRATION_URL`，仅允许独立端口的 `127.0.0.1`，禁止日常 8098；未注入为跳过 |
| 页面与主题 | 首页、详情、三态设置、系统外观变化、输入与按钮状态、空态与重载 | 静态对比计算不等于完整运行时覆盖 |
| 设备与发布 | iPhone／iPad、签署手势、Files 各格式上传、后台／恢复、签名与正式渠道 | 模拟器与源码检查不能外推真机及生产通过 |

主题静态颜色检查不能替代所有页面、输入占位和按钮状态的实际验收。签署拖动提交、Files 原件选择上传、系统外观切换、iPad／真机和 Xcode 内 `Podfile.deps` Ruby 图标均需人工核对；工程引用类型检查只验证结构。测试执行结果只在外层[测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)登记，不将未执行或跳过项计为通过。

当前 `WBProductionAPIURL` 为空。自动 IPA 留存阶段、真机签名与分发、推送、真实支付、地图／物流、认证电子签及生产发布均不得仅凭源码存在认定完成。前端各平台入口见 [前端目录](../../README.md)，项目验收与交付范围见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)及[交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

公共 SDK、依赖和缓存按目标机器准备；本地模块与维护边界见[随项目私库](#private-libraries)。

## 六、<span id="ios-map">代码地图</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

源码根目录为 `代码/前端/移动端/iOS/`；优先查下表中的 App 自维护文件，复用库再按具体符号查 `JobsByPods`，不扫描根 `Pods`。构建使用 `RepairWorkbench.xcworkspace` 与 `RepairWorkbench` Scheme；当前架构和工程边界见 [结构与能力](#architecture)，验收要求见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。

| 目录／文件 | 职责与稳定入口 |
| --- | --- |
| `App/Bootstrap/` | `WBAppDelegate`、`WBSceneDelegate`、`WBAppCoordinator`：App／Scene、登录与业务页签、身份变更替换根页面 |
| [WBStore.swift](./App/Data/WBStore/WBStore.swift) | MainActor 会话、分页、详情、写入意图、源隔离；`clearIdentity`、`refresh`、`readPage`、`loadOrder`、`writeOrder`、`simpleWrite`、`probeDemo`、`send` |
| `App/Data/WBContract/`、`WBJSON/`、`WBActor/`、`WBLoan/` | 严格整数金额与嵌套对象、未报价／空集合兼容；`actor`、`order`、`loan`、`settings`、`metrics`；借还可选真实 `createdAt`，旧响应缺失保留空值；身份比较见 `WBActor.matches` |
| `App/Data/WBJobsTransport/`、`WBEnvironment/` | JobsNetworking 适配、稳定 JSON 原文、无自动重试、短超时；Debug 本机配置与 Release HTTPS 边界 |
| `App/Data/WBDemoState/`、`WBOrderInput/` | 独立合成样例与有限离线动作；录单值类型的 9 个 `byXxx` 返回新值，`payload` 保持 API 字段 |
| `App/Data/WBInitialMedia/` | 共享录单可选 `files` 数组与设备原件响应确认；按名称、MIME、类型与SHA-256核对，本端未据此新增设备选择UI或外推验收 |
| `App/UI/` | `WBUI` 工厂与 Configuration 按钮，`WBPageView.rows` 动态持有，`WBFormField` 日期／金额／选择器，`WBTheme` 三态与 JobsThemeCenter |
| `App/Features/WBLoginVC/`、`WBDashboardVC/`、`WBOrdersVC/` | 登录、概览、搜索／状态筛选、加载更多和空态重试 |
| `App/Features/WBOrderFormVC/`、`WBOrderDetailVC/`、`WBActionFormVC/` | 链式组装录单、完整详情成功后开放办理、按 `allowedActions` 呈现业务表单 |
| `App/Features/WBInventoryVC/`、`WBInventoryFormVC/`、`WBSettingsVC/` | 库存与借还表单、公司配置、服务地址、主题及退出 |
| `App/Features/Signature/` | `WBSignatureVC` 核对报价／验收条款与开页上下文；`WBSignatureCanvas` 保留实际笔迹、绘制时协调父滚动并导出 PNG |
| `App/Features/WBFileEvidenceVC/`、`App/Platform/` | Files 原件白名单／大小与安全作用域读取；系统类型 `UIDocumentPickerViewController.make`、`UIGraphicsImageRenderer.make` 工厂 |
| `App/Resource/` | Debug／Release Info、明暗主题数据、本地 Logo 与隐私清单 |
| `Scripts/生成工程.rb`、`Podfile`、`Podfile.deps` | 增量工程引用／Scheme、依赖安装 hook 与纯依赖清单；Pods 根组 Ruby 引用保存后复开核验 |
| `测试/前端/移动端/iOS/Data/`、`测试/前端/移动端/iOS/Standalone/` | `WBDataScenarios` 基础同源 20 场景，`WBStubTransport` 控制回包；XCTest 另有 UIKit 像素与隔离真实 API 保护，实际执行状态按 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md) 分别记录 |

UIKit 页面与真实网络需单独验证；20 场景两种运行方式不累加为 40 个不同场景。离线状态不复制真实台账，离线未适配的签署、财务及库存写入不能改成演示成功；后端与网页的问题按 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md) 独立核验。

### 6.1、<span id="external-test-references">工程与外置测试定位</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [RepairWorkbench.xcworkspace](./RepairWorkbench.xcworkspace) | 本端工作区；App、JobsByPods、Podfile及脚本包保持组内相对关系。 |
| [生成工程.rb](./Scripts/生成工程.rb) | 增量维护 App 与外层 Data 测试文件引用；Tests 分组以 SOURCE_ROOT 指向测试目录，保留现有 UUID 与 CocoaPods 集成。 |
| [Data](../../../../测试/前端/移动端/iOS/Data) | WBDataScenarios、WBFixture、WBStubTransport 和 XCTest；业务／测试源码分别维护。 |
| [Standalone](../../../../测试/前端/移动端/iOS/Standalone) | 同源场景的独立运行入口 WBDataRunner；不与 XCTest 重复计算覆盖。 |

本端复用的 JobsByPods 按具体类型定位；Pods、供应商和生成文件不作为业务维护范围。测试 Target 指向外置源文件，不在 App 下重建测试副本。

### 6.2、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `./.codegraph/`，配置为 [codegraph.json](./codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
