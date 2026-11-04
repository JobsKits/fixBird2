> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

![Jobs出品，必属精品](https://picsum.photos/1500/400)

JobsFont 提供系统字体静态工厂的 Jobs 等价入口；上层代码使用 JobsFont.systemFont(...)、JobsFont.boldSystemFont(...)、JobsFont.monospacedDigitSystemFont(...) 和 JobsFont.preferredFont(...)，底层统一承接 UIKit。

JobsCor 提供 UIKit 基础色、系统色和动态语义色的 Jobs 等价入口；上层代码使用 JobsCor.clear、JobsCor.white、JobsCor.systemBlue 等属性，底层统一承接 UIColor。

`JobsThemeCenter` 提供主题数据包解析、状态持久化、弱引用资源绑定和 `JobsThemeDidChange` 通知。App 在主工程资源目录维护 `JobsThemeResources.json`，框架只消费 `background.*`、`text.*` 等 Key，不包含具体业务色值。切换主题只重放已登记的背景色、文字色以及显式声明的主题图片，不遍历 Scene、Window 或控制器树，也不写入 `overrideUserInterfaceStyle`。

<a id="jobs-architecture"></a>

## <span id="前言">一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

集中维护基础常量、枚举、协议、结构、颜色字体入口和主题机制，给上层组件提供一致表达。主题系统消费宿主资源中的语义 Key，并通知已登记的 UI 赋值重新应用。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

宿主提供基础配置和主题资源 → 上层使用定义或语义颜色 → 登记可刷新赋值 → 主题变化时重放

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- JobsThemeResources.json 由主工程维护，基础层不应混入具体业务颜色。
- 主题切换只重放已登记的背景、文字及显式声明的主题图片，不遍历全部窗口和控制器，也不设置全局 overrideUserInterfaceStyle。
- Cell 数据协议、默认配置与空实现只是契约起点；返回零高度的默认方法不代表业务布局已经完成。
- 基础回调通过独立 Block 层衔接，复建时避免让定义层反向依赖全部业务 UI。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读基础协议与结构，再看 JobsBaseCor/Font 和 JobsTheme，最后沿组件调用看登记与通知关系。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsBaseProtocolDefs.swift](<./JobsBaseProtocolDefs.swift>)
- [JobsBaseCor.swift](<./JobsBaseCor.swift>)
- [JobsTheme.swift](<./JobsTheme.swift>)
- [JobsSwiftBlockBridge.swift](<./JobsSwiftBlockBridge.swift>)
- [JobsBaseCellConfig.swift](<./JobsBaseCellConfig.swift>)

依赖与编译入口：[JobsSwiftBaseDefines.podspec](<./JobsSwiftBaseDefines.podspec>)。其中显式依赖声明包括 `JobsSwiftBlock`、`JobsTextTools`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 一、使用合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 文本输入代理先询问原 delegate；其拒绝的候选输入不会被通知为已经接受。输入范围先按 UTF-16 校验，非法范围直接拒绝。
- 输入法标记文本保留原 delegate 的决定，组合期间不做长度截断；提交后按 Swift `Character` 长度执行上限并回报已提交文本。字符上限小于零按零处理。
- UITextField 保留既有空格策略，UITextView 保留多行编辑行为。绑定、主题和 UIKit 回调在 UI 执行域使用；业务闭包及原 delegate 的线程约束由调用方维护。
- ThemeCenter 的主题包、资源 Bundle 与当前 style 使用锁快照，替换旧主题包和注入 Bundle 时在解锁后释放；绑定表和 apply 归主线程。后台 setStyle 保留异步投递并返回当前快照的语义，主题回调重绑时不会继续应用同槽旧绑定。
- IME 的最终体验需在实际 iOS 输入法验收，源码与编译验收不能替代交互验证。


## 二、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

隐私清单通过独立资源 bundle 交付。当前所需理由 API：`UserDefaults`（CA92.1）。理由对应本库实际用途；宿主仍需核对业务数据收集、App Group / 用户授权文件等实际使用场景，资源声明与最终 App 内 bundle 都应验收。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsSwiftBaseDefines --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
