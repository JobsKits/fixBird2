# <span id="前言">`JobsTextTools`</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

用 JobsText 统一承载纯文本和富文本，再由 JobsRichRun 描述文本片段或附件，JobsRichText 将片段及段落样式拼成可显示的富文本。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

建立纯文本或富文本载体 → 组合片段和附件 → 应用段落样式 → 输出所需文本形式

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 将富文本取为 String 会丢失样式，仅保留字符内容；调用方应主动选择输出形式。
- 附件、文本片段与整体段落样式有不同作用范围，不能把全部样式只施加到最后一个片段。
- JobsText 的属性与附件不能保证深层不可变，因此不声明 Sendable；富文本在调用方指定执行域内使用。
- 基础载体和 UIKit 富文本构建器的依赖边界不同，阅读时先确定是否需要图像附件。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 JobsText.Storage 与转换入口，再看 JobsRichRun.Payload 和 JobsRichText.make 的拼装。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsRichText.swift](<./JobsRichText.swift>)
- [JobsText.swift](<./JobsText.swift>)

依赖与编译入口：[JobsTextTools.podspec](<./JobsTextTools.podspec>)。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、使用合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `JobsText` 拷贝富文本容器，保持基础值语义；任意属性值和文本附件可能含有可变对象，因此 JobsText 不声明 `Sendable`。
- 富文本在创建它的 UI / 业务执行域使用。跨 actor 传递纯内容时取 `asString`，或由调用方建立可验证的属性与附件快照。
- 移除 `Sendable` 是有意的并发合同收紧；原有文本、富文本和 DSL 调用继续可用，需要跨 actor 的消费端应显式调整数据模型。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsTextTools --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
