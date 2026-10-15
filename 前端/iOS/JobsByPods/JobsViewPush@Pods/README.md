# `JobsViewPush`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

---

## 🔥 <font id=前言>前言</font>

> `JobsViewPush` 提供 UIView 级安全推入容器和控制器级侧滑抽屉，统一处理上下左右方向、推出比例、背景遮罩、点击关闭与交互式拖动。

## 一、能力范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `JobsViewPushPresentation`：把任意 `UIView` 从上、下、左、右方向推入指定容器，并支持沿原路拖回。
- `JobsSideDrawerVC`：支持 `UIViewController` / `UIView` 两种载体、跟随或固定主内容、边缘拖出以及点击遮罩关闭。
- 模块内部使用 `JobsSwiftDSL` 组织视图与动画，基础色使用 `JobsSwiftBaseDefines.JobsCor`。

## 二、侧滑抽屉交互 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 打开：从配置方向对应的屏幕边缘拖动，抽屉、主内容和遮罩实时跟随手指进度。
- 关闭：抽屉打开后可从整个容器开始反向拖动，不限于抽屉内容区域；松手前可反向回拉取消。
- 松手判定：同时参考当前位移、甩动速度和短时速度投影，完成动画只覆盖剩余距离。
- 动画接管：按钮动画尚未结束时可以直接用手势接管，不需要等待程序动画完成。
- 滚动仲裁：与抽屉同轴的 `UIScrollView` 能继续滚动时优先滚动，到达边界后再交给抽屉；垂直轴列表可与横向抽屉手势协同识别。
- 无障碍：开启“减弱动态效果”后，松手收口时间会进一步缩短。

## 三、交互参数 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`JobsSideDrawerConfiguration` 提供以下可调参数：

| 参数 | 默认值 | 作用 |
| --- | ---: | --- |
| `allowsInteractiveTransition` | `true` | 是否启用边缘打开与拖动关闭 |
| `shouldBeginOpeningGesture` | `nil` | 每次边缘打开前校验当前页面；返回 `false` 时禁止打开，不影响关闭手势 |
| `interactiveCompletionThreshold` | `0.28` | 低速拖动完成开关所需的位移比例 |
| `interactiveVelocityThreshold` | `360` | 超过该速度后按甩动方向直接决定结果 |
| `interactiveProjectionTime` | `0.18` | 松手速度参与进度预测的时间窗口 |
| `interactiveAxisDominanceRatio` | `0.8` | 主轴相对副轴达到多少比例后接管手势 |
| `onDidClose` | `nil` | 抽屉完成关闭后回调；全屏模态预览可在此退出承载页面 |

```swift
let configuration = JobsSideDrawerConfiguration(
    direction: .left,
    contentMode: .following,
    presentedRatio: 0.5,
    interactiveCompletionThreshold: 0.28,
    interactiveVelocityThreshold: 360
)

let drawer = JobsSideDrawerVC(
    drawerViewController: menuViewController,
    mainViewController: mainViewController,
    configuration: configuration
)
```

运行期间修改配置后，调用 `applyConfiguration(animated:)` 使方向、比例、颜色和交互阈值生效。

## 四、模块边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Swift**](https://www.swift.org/) 源码位于 `./JobsViewPush.swift` 与 `./Core/`。
- `./JobsViewPush.podspec` 负责声明源码、`UIKit` 以及 Jobs 本地依赖。
- 模块修改后应扫描主工程中的 `import JobsViewPush`、`JobsSideDrawerVC`、`JobsSideDrawerConfiguration` 和 `jobsPush` 调用，避免公开配置与调用示例漂移。

## 明暗主题契约 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 页面、列表和弹框的普通承载面使用 `JobsCor.systemBackground` / `JobsCor.secondarySystemBackground`，正文、说明和占位文字使用 `JobsCor.label` / `JobsCor.secondaryLabel` / `JobsCor.placeholderText`，确保白天浅底深字、黑夜深底浅字。
- 品牌色、媒体画布、二维码、相机、视频、手写和马赛克内容保留业务色；颜色写入 `CGColor`、`CALayer` 或自绘上下文时，需要在主题 Trait 变化后重新解析和绘制。
- 验证时从 Demo 全局主题入口分别切换白天和黑夜，检查组件的背景、文字、禁用态、占位态与弹出层对比度。

## Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## 五、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 5.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

提供视图推出便利能力和侧边抽屉控制器。抽屉将主内容与抽屉内容按子控制器关系装配，Configuration 描述方向、展示方式和手势阈值，进度统一驱动布局和遮罩。

### 5.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

安装子控制器 → 等待有效尺寸后挂载视图 → 手势或接口改变进度 → 判断完成方向 → 打开或关闭并回调

### 5.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 先完成父子控制器关系，再读取和布局子视图，避免导航容器在零尺寸阶段提前生成错误布局。
- 左、右、上、下抽屉需把位移与速度转换到统一开合方向，不能全部按水平向右处理。
- 低速按位移比例判断，快速甩动按方向及预测进度判断，同时协调主副轴手势竞争。
- 禁止本次边缘打开不应影响已打开抽屉的关闭手势；关闭完成回调可供宿主退出承载页面。
- 容器旋转或尺寸变化更新布局，不应无条件再次强制子导航栏布局或重复安装控制器。

### 5.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 SideDrawerConfiguration 与子控制器装配，再看 progress 布局、交互判定和关闭回调，最后看 JobsViewPush.swift 便利入口。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsViewPush.swift](<./JobsViewPush.swift>)
- [Core/JobsSideDrawer/JobsSideDrawer.swift](<./Core/JobsSideDrawer/JobsSideDrawer.swift>)

依赖与编译入口：[JobsViewPush.podspec](<./JobsViewPush.podspec>)。其中显式依赖声明包括 `JobsSwiftDSL`、`JobsSwiftBaseDefines`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 六、运行合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

push/pop 和交互式返回以实际 UINavigationController 的过渡状态为准；宿主不重复触发同一切页动作。页面内自定义动画与系统返回手势一起回归，包括取消手势及过渡中再次触发。调用方的完成闭包使用弱引用管理页面生命周期。


## 七、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsViewPush --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
