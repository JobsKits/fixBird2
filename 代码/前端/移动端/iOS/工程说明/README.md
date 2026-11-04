# iOS 工程说明

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、架构与职责](#architecture)
- [二、依赖与工程维护](#dependencies)
- [三、业务交互与数据边界](#business)
- [四、构建与运行](#build)
- [五、测试方法与验收边界](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本说明描述 `代码/前端/移动端/iOS/` 的当前工程结构、业务边界及验证方式。客户端使用 [**Swift**](https://www.swift.org/)／[**UIKit**](https://developer.apple.com/documentation/uikit)，最低 iOS 15.0，调用 `/api/v38`。使用和构建入口见 [iOS README](../README.md)，统一验收见 [测试与验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，安装产物与交接状态见 [交付清单](../../../../../需求/交付与运维清单/交付与运维清单.md)。

## 一、<span id="architecture">架构与职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 模块 | 当前职责 |
| --- | --- |
| `App/Bootstrap` | `WBAppCoordinator` 切换登录与业务页签；身份变化后替换根页面 |
| `App/Data/WBStore` | MainActor 会话、列表、完整详情、库存、写入意图与服务／演示来源隔离 |
| `App/Data/WBContract`、`WBJSON`、`WBActor` | 严格整数金额、嵌套对象、身份锚点及分页关联校验 |
| `WBJobsTransport`、`WBEnvironment` | JobsNetworking 适配、固定 JSON 请求原文、关闭缓存及自动重试、可配置短超时 |
| `WBDemoState`、`WBOrderInput` | 独立合成台账与有限动作；录单值类型的 `byXxx` 方法返回新值，保持 API 字段 |
| `App/UI` | Jobs 工厂、JobsEmptyAuto 按钮空态、原生表单与主题；动态行由 `WBPageView.rows` 持有 |
| `App/Features` | 登录、概览、分页筛选、工单、库存借还、设置、原生签署与 Files 原件归档 |
| `App/Platform` | 真实系统类型的带参创建工厂 |
| `App/Resource` | Debug／Release 配置、明暗主题、本地 Logo、隐私清单 |

会话 `generation` 与读取 `readRevision` 分别阻止身份切换及筛选改变后的迟到结果；忙碌计数在有效会话内成对收尾。读取成功须验证当前认证身份、请求页及响应结构，再写入缓存。来源变化后迟到的真实写入不能混入演示数组；结果未知时保留原请求意图，供同键核对重试。

## 二、<span id="dependencies">依赖与工程维护</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

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

安装前网络探测仅作用于当前安装进程及子进程，退出恢复；不修改全局代理或 Git 配置。脚本包缺失或异常时沿用 CocoaPods 流程，参数、日志及归档回退范围见 [安装网络选路](../README.md#cocoapods-network-route)。

## 三、<span id="business">业务交互与数据边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 进入、刷新及可提交操作先请求 API；默认超时 2.5 秒，Debug 可设 0.5～30 秒。网络或解析失败后显示独立合成样例，后续探测成功自动读取真实授权数据；演示不复制或上传真实台账。
- 当前会话 401 清除身份及授权资料；403 等业务拒绝保持原语义。真实写入超时、坏响应或来源变化不显示演示成功，保留表单及原意图键。
- 表单按完整详情的 `allowedActions` 展示；金额转整数分，日期统一 Gregorian／Asia-Shanghai，按日历加日及截止日全天处理。维修仅在 `startRequiresPrepayment=true` 时检查约定预付款；现款销售按冻结报价核实全款。
- 原生手写画布保留本人实际笔迹，PNG 输出为 640×240，渲染格式固定 `scale=1`、`opaque=true`。报价签署和验收先核对条款与开页身份／地址／来源上下文，不以合成签名冒充真实签署。
- Files 读取用户选择的 PDF／PNG／JPEG／MP4／MP3／WAV 原件，读取前后均限制 8 MiB，通过安全作用域 URL 获取内容，WAV 使用 `audio/wav`。提交不携带 `stage`，阶段由服务端记录，文件头、实际权限和内容仍由服务端校验。
- 主题使用白天、黑夜、跟随系统三态；资源初始化后才能设置主题，已有按钮配置随主题重放。静态色值计算按实际背景合成，不替代运行时各状态检查。

独立演示只覆盖受理、检测、报价／审核、开修、完工、质检、交付、备注、异议等已适配动作。签署／验收、财务、库存过账与整单完结等不伪造成功。停机异议复核、账号管理、审计导出、备份恢复及完整采购等未适配管理能力按页面提示使用网页工作台。

不提供相机／相册直接拍摄、录音或录像入口。每种格式的实际原件选择、上传及下载按对应运行证据分别验收。后端权限、业务版本与资金条件以 [服务端合同](../../../../后端/README.md#api-contract) 为准。

## 四、<span id="build">构建与运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备 [**Xcode**](https://developer.apple.com/xcode/)、[**Ruby**](https://www.ruby-lang.org)、`xcodeproj` gem 和 CocoaPods；版本由构建环境记录。以下命令从本说明所在 `工程说明/` 目录进入工程，不绑定开发机目录：

```shell
cd '..'
ruby './Scripts/生成工程.rb'
pod install --no-repo-update
open './RepairWorkbench.xcworkspace'
```

在 Xcode 选择 `RepairWorkbench` Scheme 和本机可用模拟器后运行；同 Scheme 下执行 `RepairWorkbenchTests`。命令行构建示例在 iOS 工程目录执行：

```shell
xcodebuild \
  -workspace RepairWorkbench.xcworkspace \
  -scheme RepairWorkbench \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TMPDIR/RepairWorkbenchDerivedData" \
  CODE_SIGNING_ALLOWED=NO build
```

Debug 支持本地 HTTP 地址和短超时；Release 只接受 `WBProductionAPIURL` 的 HTTPS 地址，当前配置为空。模拟器回环地址与真机网络分别配置，客户端不会启动后端。模拟器构建、真机签名、IPA 留存和正式分发是独立交付项；当前没有已验收的自动 IPA 留存阶段。

## 五、<span id="verification">测试方法与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 验证层 | 要检查的内容 | 边界 |
| --- | --- | --- |
| 工程与依赖 | Ruby 语法、引用唯一性、脚本实际挂载、依赖安装与重复安装、Debug／Release 构建 | 语法检查不运行安装 hook；安装成功不代替构建 |
| Foundation 共享场景 | 合同、分页、逆序回包、未知写入意图、身份撤销、忙碌归零、来源隔离 | 外层 `测试/前端/移动端/iOS/Data` 与 `Standalone` 使用相同场景，不重复累加覆盖 |
| UIKit 像素 | 真实渲染器输出 PNG 后回读尺寸与像素 | 不代替实际手指拖动、条款确认和提交 |
| 隔离真实 API | JobsNetworking 登录、详情、创建后重读、错误密码 401、主线程交付 | 显式注入 `WB_INTEGRATION_URL`，仅允许独立端口的 `127.0.0.1`，禁止日常 8098；未注入为跳过 |
| 页面与主题 | 首页、详情、三态设置、系统外观变化、输入与按钮状态、空态与重载 | 静态对比计算不等于完整运行时覆盖 |
| 设备与发布 | iPhone／iPad、签署手势、Files 各格式上传、后台／恢复、签名与正式渠道 | 模拟器与源码检查不能外推真机及生产通过 |

签署拖动提交、Files 原件选择上传、Xcode 内 Ruby 图标、系统外观实际切换、iPad／真机及全部主题组合需人工验收。生产 HTTPS、自动 IPA、真机签名、推送、真实支付、地图／物流、认证电子签和完整业务流程分别验证。测试执行结果只在 [测试与验收](../../../../../测试/测试与分级验收/测试与分级验收.md) 的当前状态中登记，不将未执行或跳过项计为通过。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
