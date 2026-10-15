# `JobsByUIKit`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。


## <span id="前言">DSL 迁移说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span>

- 本 Pod 原有的链式 DSL / 点语法封装已经抽离到 `JobsSwiftDSL`。
- 本 Pod 提供 UIKit 创建工厂、事件和功能封装；`JobsByUIKitDSLBridge` 使用 `@_exported import JobsSwiftDSL`，因此引入 `JobsByUIKit` 后可直接使用 `byXxx(...)`。
- 圆形调试按钮由 [JobsDebugPanel](../JobsDebugPanel@Pods/README.md) 使用 `UIButton.custom().byBgImage(...).byAccessibilityLabel(...).onTap(...).onLongPress(...)` 组合，背景来自本地资源，无障碍 DSL 由 `JobsSwiftDSL` 的 UIView 层提供。
- 仅使用 DSL、未引入 `JobsByUIKit` 的消费方，要显式 `import JobsSwiftDSL`。
- `JobsByUIKit` / `JobsSwiftDSL` 实现是权威源；Xcode CodeSnippets 与实现冲突时，以实现为准并反哺更新代码块。
- `UIView.tintColor` 这类公共属性在父类 DSL 统一封装，子类不重复声明同名 API。
- `UIView.byAddTo(_:)` 的基础装配位于 `JobsSwiftDSL`；传入 SnapKit 约束闭包的重载由本 Pod 提供。
- `UITextField.byPlaceholder(_:)` 的基础文字设置位于 `JobsSwiftDSL`；占位颜色、字体增强由本 Pod 提供，避免跨模块重复声明造成重载歧义。
- `UIDatePicker` / `UIPickerView` 的基础 DSL 已统一收口到 `JobsSwiftDSL`；本 Pod 仅通过 `JobsByUIKitDSLBridge` 公开转发，避免同名扩展二义性。
- `UITableViewCell.byListConfig(_:)` 负责把 `UIListContentConfiguration` 收回 Cell 主链；其文本排版可继续使用 `byTextLineBreakMode(_:)` / `bySecondaryLineBreakMode(_:)` 等值类型 DSL。
- `UIBezierPath` 创建统一使用 `make()` / `make(rect:)` / `make(ovalIn:)` / `make(roundedRect:cornerRadius:)` / `make(arcCenter:...)`。
- `UIAction` / `UIMenu` 创建统一使用 `make(...)`；`UIBarButtonItem` 的标题、图片、系统项和自定义视图均使用对应 `make(...)` 工厂。
- 空 `UIImage` 使用 `UIImage.make { image in ... }`，调用侧不直接写 `UIImage()`；`DateFormatter.make { ... }` 和 `NSUserActivity.make(activityType:configure:)` 分别承接无参格式器与带参 Activity 创建。
- 明确 Bundle 的本地图片使用 `UIImage.make(named:in:compatibleWith:configure:)`；返回 `UIImage?`，资源不存在时保留 `nil`，不强制替换成未知占位图。
- SDWebImage / Kingfisher 的按钮图片回调会避开 `UIButton.Configuration` 内部视图替换期间的过渡动画，不在回调中强制布局；前景 shimmer 直接作用于当前 `imageView.layer`，不再向 `UIButton` 插入 overlay 或启用 UIButton overlay 的 `layoutSubviews` swizzle。
- `UIViewController.jobsSetupGKNav(...)` 在写入标题和左右按钮后，会强制显示并置顶 GK 导航栏、恢复真实透明度，同时隐藏系统导航栏，避免导航容器残留状态导致 Demo 子页面无导航栏。
- 从 `RootListVC` Demo 根列表进入的每个导航 / 模态子页面，以及类名以 `DemoVC` 结尾的独立演示页，右上角最多只显示一个透明背景的主题入口；没有页面业务动作时直接切换主题，月亮 / 太阳图标与无障碍文案表达下一次点击会切换到的主题；存在业务动作时使用 Demo 总入口同款 `ellipsis.circle` 展开下拉列表，展开后切换为填充图标与“收起”语义，把主题切换与全部页面动作统一收纳。`JobsNavigationDemoVC` 使用同一规则写入系统导航栏。
- 主题入口调用 `JobsThemeCenter.shared.toggle()`；主题状态、JSON 数据包和弱引用资源绑定由 `JobsSwiftBaseDefines` 承担。切换时只重放已标记的背景色、文字色和显式主题图片，并发布 `.JobsThemeDidChange`，不遍历 Scene / Window / 控制器树。
- `UIViewController.jobsEnsureNavigationDefaults()` 统一为导航栈子页面和模态子页面补齐 Jobs/GK 导航栏、标题与 Jobs 返回按钮，但不覆盖页面在 `viewDidLoad` 中声明的背景色；已有系统 `navigationItem.titleView` / 右侧业务按钮会迁移到 GK 导航栏，不再沿用系统导航容器。仅专门演示系统导航栏能力的 `JobsNavigationDemoVC` 保持原样。
- `UIViewController.jobsEnsureNavigationBackButton()` 保留单独补齐 GK 返回按钮的入口；默认箭头使用 template 渲染和 `JobsCor.label`，随明暗主题自动变色。
- `UIKitAttributes` 的 TextKit 属性封装只声明真实可用系统版本，不复制系统的未来 deprecated 标记；调用方只看到 Jobs API 的实际 availability 边界。
- `UIWindowScene.keyWindowCompat` 统一处理新旧系统取窗逻辑；历史 `legacyKeyWindowPreiOS13()` 的弃用提示只指向 Jobs 替代入口，不向上层复制 Apple API 提示。

## 明暗主题契约 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 页面、列表和弹框的普通承载面使用 `JobsCor.systemBackground` / `JobsCor.secondarySystemBackground`，正文、说明和占位文字使用 `JobsCor.label` / `JobsCor.secondaryLabel` / `JobsCor.placeholderText`，确保白天浅底深字、黑夜深底浅字。
- 品牌色、媒体画布、二维码、相机、视频、手写和马赛克内容保留业务色；颜色写入 `CGColor`、`CALayer` 或自绘上下文时，需要显式绑定主题 Key，或监听 `.JobsThemeDidChange` 后重新解析和绘制。
- 验证时从 Demo 全局主题入口分别切换白天和黑夜，检查组件的背景、文字、禁用态、占位态与弹出层对比度。

## Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以系统类型为组织轴，承载 Jobs 的对象创建工厂、UIKit 功能扩展与事件便利入口。纯配置型链式 DSL 归入 JobsSwiftDSL；本 Pod 的桥接入口与 iOS.SDK 下的类型目录连接这两层。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

工厂创建系统对象 → DSL 配置基础属性 → 功能或事件扩展接入行为 → 宿主安装并管理对象

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 不要把 iOS.SDK 目录误当成 Apple 的 SDK 副本；其中包含本库自维护的系统类型扩展。
- 纯属性配置与带 [**SnapKit**](https://github.com/SnapKit/SnapKit) 闭包的安装、事件绑定、图片加载等功能要分层；例如 byAddTo 的不同重载分布在不同模块。
- 工厂、语言与主题辅助、图片加载器适配等各有依赖和系统版本边界，不能合并成一个万能扩展文件。
- 复建链式入口时保持当前对象类型；处理子对象的配置闭包应明确作用对象，避免链条返回父类后丢失能力。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读桥接入口明确 DSL 边界，再按 iOS.SDK 下的系统类型定位工厂、功能和事件实现，最后看调用方如何组合。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsByUIKitDSLBridge.swift](<./JobsByUIKitDSLBridge.swift>)
- [iOS.SDK/Others@SDK/UIAlertController.swift](<./iOS.SDK/Others@SDK/UIAlertController.swift>)
- [iOS.SDK/Others@SDK/UICollectionViewFlowLayout.swift](<./iOS.SDK/Others@SDK/UICollectionViewFlowLayout.swift>)
- [iOS.SDK/Others@SDK/UIListContentConfiguration.swift](<./iOS.SDK/Others@SDK/UIListContentConfiguration.swift>)
- [iOS.SDK/Others@SDK/UIPageViewController.swift](<./iOS.SDK/Others@SDK/UIPageViewController.swift>)

依赖与编译入口：[JobsByUIKit.podspec](<./JobsByUIKit.podspec>)。其中显式依赖声明包括 `Kingfisher`、`GKNavigationBarSwift`、`SnapKit`、`SVGKit`、`ESPullToRefresh`、`RxSwift`、`RxCocoa`、`RxRelay`、`NSObject+Rx`、`SkeletonView`、`lottie-ios`、`Jobsl10n`、`JobsScale`、`JobsNavBar`、`JobsTextTools`、`JobsSwiftTimer`、`JobsSwiftBlock`、`JobsImageTools`、`JobsByQuartzCore`、`JobsSwiftBaseDefines`、`JobsViewPush`、`JobsSwiftDSL`、`JobsGetWindow`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。


## 二、稳定性与编译验收 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`UIKitAttributes.byTextItemTag` / `byAdaptiveImageGlyph` 新增真实系统 Value 类型入口，保留 `Any?` 兼容重载。nil 清除属性，错误类型保留原容器，不再强制转换崩溃。对应类型仍受原来的系统可用性约束。

`UIWindowScene.keyWindowCompat` 与已弃用的 `legacyKeyWindowPreiOS13` 统一定义于 [JobsGetWindow](<../JobsGetWindow@Pods/README.md>)，本模块直接依赖并再导出，避免与窗口库同时导入时发生歧义。重编后的源码调用继续可用；符号模块迁移不承诺预编译 ABI，使用这些窗口查询的二进制客户端需要重编。

生产源码显式排除测试、Demo 和临时文件。使用 UserDefaults 的刷新适配随 `JobsByUIKitPrivacy.bundle` 交付原因清单；业务数据收集声明仍由宿主按实际用途填写。

从宿主工程根目录执行单模块编译：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsByUIKit --skip-host
```

完整入口按 Pod → 宿主顺序构建，日志和 DerivedData 位于临时目录，不能把 Parse 成功视为模块编译成功。最低系统与集成形式以 Podspec / 消费工程为准；当前宿主按 iOS 15.6 构建。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

隐私清单通过独立资源 bundle 交付。当前所需理由 API：`UserDefaults`（CA92.1）。理由对应本库实际用途；宿主仍需核对业务数据收集、App Group / 用户授权文件等实际使用场景，资源声明与最终 App 内 bundle 都应验收。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsByUIKit --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
