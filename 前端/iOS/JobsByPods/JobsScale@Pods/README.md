# `JobsScale`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

# <span id="前言">📏比例尺</span>

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

* **JobsScale**主要是协调**iPhone**的不同设备屏幕和设计稿之间的比例转换问题

  * 对于UI宽高各一个比例尺（参考[**Flutter**](https://flutter.dev/)中关于屏幕的适配方案）

    ```swift
    3.w // 宽
    3.h // 高
    ```

  * 对于字体单独的一个比例尺

  * App启动时需要配置当前UI锚定的设计稿尺寸

    ```swift
    // MARK: - 比例尺
    JobsScale.setup(designWidth: 375, designHeight: 812)
    ```

  * 兼容**iPad**

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

将设计稿尺寸到当前显示尺寸的转换集中管理，宽高布局与字体缩放分别计算。字体支持连续比例或按屏幕宽度分档，窗口尺寸由 JobsGetWindow 辅助获取。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

启动时设置设计稿尺寸 → 获取当前显示尺寸 → 计算宽高比例与字体比例 → 供布局和字体入口使用

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 字体只看宽度，避免横屏或 iPad 上随高度比例异常变化；布局宽高不能混为一个比例。
- Safe Area 是布局约束，默认不作为全局比例尺；兼容开关取不到可靠窗口时会回退。
- 比例缩放不等于自动布局，宿主仍需处理安全区、旋转、分屏及内容固有尺寸。
- 启动配置必须先于业务使用，不能让不同页面各自偷偷修改全局设计稿基准。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 setup 与设计稿基准，再看 screenSize、UI 比例和字体分档策略，最后看便利数值入口。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsScale.swift](<./JobsScale.swift>)

依赖与编译入口：[JobsScale.podspec](<./JobsScale.podspec>)。其中显式依赖声明包括 `JobsGetWindow`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、运行合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

setup 接受有限正设计稿宽高；非法宽高回退到 375×812。字体最小/最大比例为有限正值并排序；断点过滤非法项后按宽度排序，超过最后断点继续使用其比例。空或全部非法的断点表保留现有配置。

全局比例适用于单一设计稿上下文，初始化和读取在主线程。多窗口/分屏页面使用 `screenSize(in:)`、`widthScale(in:)`、`heightScale(in:)` 传实际 UIWindow，避免不同页面修改全局基准。比例尺不代替 Auto Layout 和 Dynamic Type；需要额外动态字体支持时由宿主按内容尺寸类别调整。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsScale --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
