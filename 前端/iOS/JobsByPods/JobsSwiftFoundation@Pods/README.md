> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

![Jobs出品，必属精品](https://picsum.photos/1500/400)


## <span id="前言">DSL 迁移说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span>

- 本 Pod 原有的链式 DSL / 点语法封装已经抽离到 `JobsSwiftDSL`。
- 继续使用 `byXxx(...)`、`dsl { ... }` 这类语法时，请在调用文件显式 `import JobsSwiftDSL`。
- 本 Pod 保留薄桥接文件和 `JobsSwiftDSL` 依赖，用于兼容旧代码的过渡期。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

保留 Foundation 相关的数据转换、数值舍入、富文本测量和 UserDefaults 便利能力，原有纯链式配置迁入 JobsSwiftDSL，通过桥接维持过渡关系。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

输入基础值 → 按指定转换或存储规则处理 → 返回结果或读取默认值 → 上层解释业务含义

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 这里仍有实际数据处理实现，不是只有桥接文件；但 byXxx DSL 应继续追到 JobsSwiftDSL。
- Decimal 舍入模式、精度与负数方向必须按实现核对，不能把显示格式化等同于业务计算精度。
- UserDefaults 的缺失值和存储的 false/0 需要按便利读取入口的默认策略解释。
- 富文本高度依赖指定宽度和字体兜底，不能脱离布局条件当作固定值。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先选 Decimal、UserDefaults 或 NSAttributedString 等目标文件，再看桥接说明与迁出后的 DSL 边界。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Decimal.swift](<./Decimal.swift>)
- [NSAttributedString.swift](<./NSAttributedString.swift>)
- [UserDefaults.swift](<./UserDefaults.swift>)
- [JobsSwiftFoundationDSLBridge.swift](<./JobsSwiftFoundationDSLBridge.swift>)
- [BinaryFloatingPoint.swift](<./BinaryFloatingPoint.swift>)

依赖与编译入口：[JobsSwiftFoundation.podspec](<./JobsSwiftFoundation.podspec>)。其中显式依赖声明包括 `JobsByUIKit`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、使用合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `UserDefaults.uint32(forKey:)` 只在整数能精确表示为 `UInt32` 时返回值；负值与超过 `UInt32.max` 的值返回 `nil`。
- 返回 `nil` 表示不存在、无法转换或越界，业务应显式选择默认值，不能把截断结果当作有效配置。
- Foundation 便利封装保留系统对象的执行与并发约束；可变容器和回调捕获状态仍由调用方管理。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

隐私清单通过独立资源 bundle 交付。当前所需理由 API：`UserDefaults`（CA92.1）。理由对应本库实际用途；宿主仍需核对业务数据收集、App Group / 用户授权文件等实际使用场景，资源声明与最终 App 内 bundle 都应验收。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsSwiftFoundation --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
