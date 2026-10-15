# <span id="前言">`JobsSwiftStandardLibrary`</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

按容器、整数、浮点和 Optional 等类型组织标准库扩展。当前已有数组构建与部分便利操作、默认初始化协议适配，同时也存在仅有文件头的类型占位，目录数量不代表能力数量。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

选择值或容器类型 → 调用已有扩展 → 返回新值或原地修改 → 上层决定缺省值含义

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- Array.add 返回新数组，addBy 原地修改；Builder 提供闭包内链式构建，两种 addBy 的接收类型不同。
- Builder 持有临时数组指针，使用范围应限制在 build 闭包中，不应逃逸后继续调用。
- Optional 的默认初始化适配不等于业务数据一定有效，空字符串、零值与缺失值仍有不同含义。
- 例如 Int.swift 当前只含文件头，重建时不能给所有预留类型凭空补一套不存在的方法。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 Optional.swift 与容器/Array.swift 的实际实现，再逐文件确认其他扩展是否已有正文。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Optional.swift](<./Optional.swift>)
- [容器/Array.swift](<./容器/Array.swift>)
- [容器/Collection.swift](<./容器/Collection.swift>)
- [容器/Dictionary.swift](<./容器/Dictionary.swift>)
- [容器/Sequence.swift](<./容器/Sequence.swift>)

依赖与编译入口：[JobsSwiftStandardLibrary.podspec](<./JobsSwiftStandardLibrary.podspec>)。其中显式依赖声明包括 `JobsSwiftBaseDefines`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、使用合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `Array.build` 的 Builder 使用受控存储，闭包结束后持有 Builder 也不会访问失效栈指针；后续 Builder 修改不会改变已返回的数组值。Builder 自身不提供多线程并发写入合同。
- 时间文字格式化先转换到无符号安全范围，负值显示零时长；`Int8` 等窄整数以及 `UInt64.max` 不会因中间 `Int` 转换或常量构造崩溃。
- 返回的数组、字典及元素继续遵循标准库的值语义与元素自身的并发合同。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsSwiftStandardLibrary --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
