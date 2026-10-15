# 啄木鸟维修 · iOS 原生客户端

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本目录为 [**iOS**](https://developer.apple.com/ios/) 原生客户端，使用 [**Swift**](https://www.swift.org/) 和 [**UIKit**](https://developer.apple.com/documentation/uikit) 编写，连接现有 `/api/v38` 服务。主入口是 `RepairWorkbench.xcworkspace`，最低系统版本为 iOS 15.0。最终冻结版 Debug／Release 构建通过，App XCTest 22／22、0 失败、0 跳过，已核查真实 API 首页／新单详情和设置三态；未验收项分开记录，见 [本轮实现与验证](../../iOS实现与验证-2026-10-15.md)。

[结构与能力](#architecture) · [构建入口](#build) · [API 与演示](#fallback) · [配置支持](#configuration) · [验证边界](#verification)

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
├── Tests/Data/                   Foundation 合同与 Store 场景，供 XCTest 运行
├── Tests/Standalone/             不依赖 UIKit 的同场景运行入口
├── Scripts/生成工程.rb            增量维护工程文件引用和共享 Scheme
├── Podfile、Podfile.deps、Podfile.lock
├── RepairWorkbench.xcodeproj
└── RepairWorkbench.xcworkspace   安装依赖后从这里打开
```

| 页面 | 实际职责 |
| --- | --- |
| 登录与工作台 | 真实认证、来源提示、概览数字、任务与刷新；可选择合成账号尝试演示 |
| 工单 | 业务类型、状态、搜索与分页；创建工单、读取完整详情、查看票款／资料／事件及关联借还 |
| 办理表单 | 根据完整详情返回的 `allowedActions` 展示操作；金额转整数分、日期按中国日历处理，保留未知结果输入与重试意图 |
| 签署 | 原生手写签名入口；真实签署和验收必须由服务端确认，独立演示不伪造签署结果 |
| 资料归档 | 文字事实、Files 原件选择与上传；PDF、PNG、JPEG、MP4、MP3、WAV，单份最多 8 MiB，实际内容与权限由服务端校验 |
| 库存借还 | 配件、尚欠与部分独立跟踪台账；授权仓库／管理员借出、归还，管理员批准耗用／处置／转出 |
| 设置 | 白天、黑夜、跟随系统；Debug 服务地址与超时；服务端管理员公司配置；退出并清授权缓存 |

动态列表和详情记录区均提供 JobsEmptyAuto 按钮空态与重新加载。页面使用 `BaseVC`，自维护布局使用 [**SnapKit**](https://github.com/SnapKit/SnapKit)，系统对象／按钮配置复用 `JobsByUIKit`、`JobsSwiftDSL`。长生命周期控件由属性持有，动态行由 `WBPageView.rows` 持有。

原生通用表单不覆盖全部管理能力。停机异议复核等暂未适配动作会明确引导网页；账号管理、审计／导出、备份恢复及完整采购不能因菜单或模型存在而视为已验收。文件入口读取用户选择的原件，不提供相机／相册直接拍摄、录音或录像；每种文件格式的实际上传结果分别以运行证据为准。真实可办理事项仍由服务端权限与业务条件决定。

## 二、<span id="build">工程与构建入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备 [**Xcode**](https://developer.apple.com/xcode/)、[**Ruby**](https://www.ruby-lang.org)、`xcodeproj` gem 和 [**CocoaPods**](https://cocoapods.org/)。本机核查可用组合是 Xcode 27.0、`/usr/bin/ruby` 2.6.10＋xcodeproj 1.27.0、`/opt/homebrew/bin/pod` 1.17.0；CocoaPods 版本查询曾有 gem 原生扩展警告，安装结果以日志为准，不在脚本内自动安装或升级工具。

从项目根目录进入本端，增补源码引用、安装已有依赖并打开工作区：

```sh
cd './前端/iOS'
/usr/bin/ruby './Scripts/生成工程.rb'
/opt/homebrew/bin/pod install --no-repo-update
open './RepairWorkbench.xcworkspace'
```

在 Xcode 选择 `RepairWorkbench` Scheme 和 iPhone 模拟器后 Run。当前本机既有可用目标是 iPhone 18 Pro / iOS 27.0，UDID `BF64EEDF-887C-4728-B5F2-B3AEEBECD87A`；其它电脑应改用自己的可用设备。测试入口是同 Scheme 的 `RepairWorkbenchTests`。新增 App 或 `Tests/Data` 文件后重新运行工程生成脚本；它只维护工程引用，不安装依赖、不构建、不部署。

命令行模拟器构建示例（在本端目录执行）：

```sh
xcodebuild \
  -workspace RepairWorkbench.xcworkspace \
  -scheme RepairWorkbench \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=BF64EEDF-887C-4728-B5F2-B3AEEBECD87A' \
  -derivedDataPath "$TMPDIR/RepairWorkbenchDerivedData" \
  CODE_SIGNING_ALLOWED=NO build
```

该命令是模拟器构建示例；文档中的命令不代表已执行通过。实际运行结果、失败过程及最终产物见 [验证报告](../../iOS实现与验证-2026-10-15.md#verification)。

## 三、<span id="fallback">API 优先与独立演示</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产网络经过 `WBJobsTransport` → `JobsNetworking`，使用 `/api/v38`、关闭缓存与自动重试。默认超时 2.5 秒，Debug 可配置 0.5～30 秒。进入、刷新和可提交操作均先尝试 API；服务不可达或响应无法解析时，展示独立合成样例并明确标识来源。后续刷新或操作继续探测接口；恢复后读取真实授权数据，不将合成单号提交到真实服务。

当前会话 401 清除授权资料并返回登录；服务端明确拒绝保持拒绝语义。真实写入超时、坏响应或来源变化时提示结果未知，不显示本地成功，不自动重放；同一页面重试保留原请求意图。切换账号／服务地址、退出时清除旧缓存和意图，旧会话迟到结果不会恢复权限。

本地数据只在 App 进程内演示，不代替业务持久化。离线支持有限的受理、检测、报价／审核、开修、完工、质检、交付、备注和异议动作；客户签署／验收、借还过账、财务与整单完结等需要真实服务。演示与真实服务同样保留维修先款开修的明确约定：仅 `startRequiresPrepayment=true` 才核实约定预付款；现款销售仍以冻结报价全额为门槛。完整合同以 [服务端合同](../../docs/workbench-contract.md) 为准。

无服务器时直接运行 Debug App，选择合成账号即可预览；通用演示密码为 `Demo-Repair-2026!`。所有演示资料均为合成，勿把真实密码或附件填入离线演示。本地 Logo 随 App 打包，空态图片可离线显示，不依赖外链图片。

模拟器的 `127.0.0.1:8098` 指向本机开发服务；真机须使用设备可达的服务地址。服务启动、隔离数据及部署说明见 [总部署文档](../../部署文档.md)，客户端不会自动启动或停止后端。

## 四、<span id="configuration">项目配置支持</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 配置 | 当前行为 |
| --- | --- |
| `Info.Debug.plist` | 允许本地 HTTP 调试，默认 `http://127.0.0.1:8098`；设置可更换地址和超时；启动参数 `--wb-api-url` 可临时指定地址 |
| `Info.Release.plist` | 不包含 Debug 的 ATS 放宽；只读取 `WBProductionAPIURL` 且要求 HTTPS，目前为空，需部署时配置真实地址 |
| `Podfile.deps` | 只列依赖，逐条写本地 `:path`，不执行外部脚本；本地 Jobs 模块来自 Jobs Swift 基座，外部依赖由 CocoaPods 管理 |
| `Podfile` | 静态 frameworks、统一最低系统／Swift 版本；post_install 将依赖清单挂到 Pods 工程根组，以 Ruby 类型展示，保存后重新打开检查根对象和无构建阶段引用；维护失败会告警并尝试恢复工程文件 |
| `Scripts/生成工程.rb` | 增量添加 App、Data 测试、资源与配置引用，维护 `RepairWorkbench` 共享 Scheme；重复执行保留已有引用与 CocoaPods 集成 |
| `JobsThemeResources.json` | 明暗成对颜色，App 设置选择三态；主题与系统外观可不同，切换时更新已有页面和按钮配置 |

生成的 `Pods/` 与供应商源码不作为 App 业务修改位置。原始 Swift 脚手架保持只读；来源清单见 [复用来源证据](../../docs/iOS实现验证-2026-10-15/JobsByPods来源清单.json)。

目前工程尚未提供已验收的自动 IPA 留存阶段；模拟器构建、真机签名、IPA 留存与正式分发是不同验证项，最终状态见 [本轮报告](../../iOS实现与验证-2026-10-15.md)。

## 五、<span id="verification">验证与已知边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

独立 Foundation 基础场景 20／20 通过。最终冻结 App XCTest 在显式隔离地址下执行，22／22、0 失败、0 跳过，其中 20 项复用基础场景，另 1 项验证实际 UIKit PNG 像素，1 项通过 JobsNetworking 连接隔离 Go 服务，核查登录、完整详情、创建后读回和错误密码 401；不是所有业务操作的真实联调。证据见 [冻结摘要](../../docs/iOS实现验证-2026-10-15/XCTest冻结摘要.json) 与 [最终验证汇总](../../docs/iOS实现验证-2026-10-15/最终验证摘要.json)。真实 API 测试仅在显式注入 `WB_INTEGRATION_URL` 时执行，只允许带独立端口的 `127.0.0.1`，禁止使用日常 8098；未提供地址时真实 API 项会跳过，其余 21 项仍执行；这里的 22 项通过来自本轮显式隔离联调，不能把默认跳过计为通过。

本轮通过生成的 `build/DerivedData/Build/Products/RepairWorkbench_iphonesimulator27.0-arm64.xctestrun` 中 `RepairWorkbenchTests > EnvironmentVariables` 注入该变量，再执行 `test-without-building`。验证后已删除该临时字段；默认测试命令不会自动连接隔离服务或得到 22 项全过。

主题声明色值静态计算 31／31 配对通过，最低 5.4164:1；见 [颜色证据](../../docs/iOS实现验证-2026-10-15/static-theme-contrast.json)。模拟器已看到真实 API 首页、联调新单详情，并从设置实际选择黑夜、白天和跟随系统，后者当前为浅色。签署实际拖动提交、Files 原件选择上传、系统外观切换、iPad／真机、所有按钮状态以及完整主题覆盖仍待人工验收。Podfile.deps 的唯一 Ruby 文件类型引用与重复安装已核查，Xcode 红钻图标尚无人工界面证据。完整日志与截图见 [实现与验证](../../iOS实现与验证-2026-10-15.md#verification)。

原有 [17 组 P2](../../docs/五次回归报告-2026-10-15.md) 未因增加 iOS 端而修复。当前原生客户端不代表全部 PRD 或所有平台已交付；真机签名、推送、真实支付、地图／物流、认证电子签和生产发布不在本轮已验证范围内。前端其它平台状态见 [前端目录](../README.md)，整体入口见 [根说明](../../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
