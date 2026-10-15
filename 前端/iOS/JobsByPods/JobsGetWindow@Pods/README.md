# `JobsGetWindow`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

# <span id="前言">JobsGetWindow</span>

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

- `UIWindowScene.keyWindowCompat` 统一处理 iOS 15+ `keyWindow` 与旧系统 `windows` 回退。
- `legacyKeyWindowPreiOS13()` 仅作为已退役的 Jobs 兼容入口保留，其 deprecated message 指向 Jobs 替代 API；底层系统版本差异由实现内部处理。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

封装多场景下的窗口选择与可见控制器查找。全局便利函数委托 UIApplication 和 UIWindowScene 扩展，在不同窗口和容器控制器之间寻找适合业务操作的入口。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

指定场景或使用默认选择 → 筛选并排序窗口 → 遍历展示和容器关系 → 返回可选窗口或控制器

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 多窗口环境不能永久缓存第一次获取的 keyWindow；需要确定场景时优先使用显式 scene 入口。
- 前台状态、窗口层级、主屏偏好与可见性共同影响选择，不能简化成 connectedScenes 的第一个元素。
- 可见控制器查找涉及导航、标签、分栏、分页与 presented 关系，并有忽略提示框的选项。
- 获取结果可能为空，调用方应保留降级路径，不能强制解包假定应用始终存在活动窗口。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 Inlines 中的公开入口，再看 UIApplication 的默认选择和 UIWindowScene 的局部查找。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Inlines.swift](<./Inlines.swift>)
- [UIApplication.swift](<./UIApplication.swift>)
- [UIWindowScene.swift](<./UIWindowScene.swift>)

依赖与编译入口：[JobsGetWindow.podspec](<./JobsGetWindow.podspec>)。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、运行合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

所有 UI 查询在主线程调用。多 Scene 页面优先使用显式 `in: scene` 或 `from: controller`；全局入口只能按当前可观察的窗口状态择优，无法判断业务的唯一正确窗口。没有窗口时返回 nil。空导航、标签、分栏和分页容器返回容器自身，查找会终止；已展示控制器优先，`ignoreAlert` 可以跳过提示框。

本 Pod 只链接 UIKit，不依赖第三方或其它自建 Pod，是 `UIApplication.jobsKeyWindow`、`jobsTopMostVC`、安全区和刘海查询的唯一声明与实现归属。只需要窗口查询时可直接 `import JobsGetWindow`；[JobsSwiftDSL](<../JobsSwiftDSL@Pods/README.md>) 直接依赖并再导出本模块，重新编译的旧源码仍可仅通过 `import JobsSwiftDSL` 使用这些查询。备用 AppIcon 的查询与切换 DSL 继续由 SwiftDSL 承接。

从旧 SwiftDSL 复制实现迁移到本模块时，公开查询名称和参数保持一致，但符号所属模块变化不属于预编译 ABI 兼容承诺。应重新解析依赖，并重编使用这些查询的 App、库和测试；不能只替换某个 Pod 二进制。

全局 `jobsGetMainWindow`、`jobsGetMainWindowBefore13`、`jobsGetMainWindowAfter13` 同样只在本模块定义，[JobsSwiftBaseTools](<../JobsSwiftBaseTools@Pods/README.md>) 直接依赖并再导出，避免同时导入产生歧义。通用入口用系统 availability 选择版本路径，当前版本窗口为空时再延迟求值旧入口；旧 `After13` 仍采用前台活动 Scene 的 key/首个窗口，需确定多窗口业务归属时使用显式 scene 查询。

`UIWindowScene.keyWindowCompat` 和已弃用的 `legacyKeyWindowPreiOS13` 也由本模块唯一承接，[JobsByUIKit](<../JobsByUIKit@Pods/README.md>) 通过直接依赖和再导出保持源码入口。使用这些符号的预编译客户端同样需要重编。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsGetWindow --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
