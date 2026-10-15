# `JobsByQuartzCore`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。


## <span id="前言">DSL 迁移说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span>

- 本 Pod 原有的链式 DSL / 点语法封装已经抽离到 `JobsSwiftDSL`。
- 继续使用 `byXxx(...)`、`dsl { ... }` 这类语法时，请在调用文件显式 `import JobsSwiftDSL`。
- 本 Pod 保留薄桥接文件和 `JobsSwiftDSL` 依赖，用于兼容旧代码的过渡期。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这是 QuartzCore 链式扩展迁移后的模块入口。当前本目录保留 JobsByQuartzCore.swift，实际 DSL 由 JobsSwiftDSL 承载，基础定义和回调类型由相应基础 Pod 提供。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

宿主引入模块 → 找到 JobsSwiftDSL 的 QuartzCore 扩展 → 配置系统图层或动画对象

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 本 Pod 不包含一套独立动画调度引擎，不应把名称理解成所有动画行为都在这里实现。
- 重建时保留依赖方向，不要同时在兼容 Pod 和 DSL Pod 中复制相同扩展。
- 图层对象的配置能力与动画播放、暂停、销毁等行为应按实际实现分别定位。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从模块入口和 podspec 开始，再沿依赖到 JobsSwiftDSL 的 QuartzCore 目录。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsByQuartzCore.swift](<./JobsByQuartzCore.swift>)

依赖与编译入口：[JobsByQuartzCore.podspec](<./JobsByQuartzCore.podspec>)。其中显式依赖声明包括 `JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。


## 二、稳定性与编译验收 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

继续作为 JobsSwiftDSL 的兼容桥接，实际 Layer / Animation 链式能力以 JobsSwiftDSL 实现为准。生产 target 显式排除测试、Demo 和临时文件；不另外复制动画生命周期实现。

从宿主工程根目录执行单模块编译：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsByQuartzCore --skip-host
```

完整入口按 Pod → 宿主顺序构建，日志和 DerivedData 位于临时目录，不能把 Parse 成功视为模块编译成功。最低系统与集成形式以 Podspec / 消费工程为准；当前宿主按 iOS 15.6 构建。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsByQuartzCore --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
