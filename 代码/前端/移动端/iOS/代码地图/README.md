# <span id="前言">iOS 原生客户端 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、iOS 原生客户端入口](#ios-map)
- [三、工程与外置测试定位](#external-test-references)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位iOS 原生客户端的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护iOS 原生客户端自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#ios-map) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/移动端/iOS) | 测试源码与执行入口。 |

## 二、<span id="ios-map">iOS 原生客户端入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

源码根目录为 `代码/前端/移动端/iOS/`；优先查下表中的 App 自维护文件，复用库再按具体符号查 `JobsByPods`，不扫描根 `Pods`。构建使用 `RepairWorkbench.xcworkspace` 与 `RepairWorkbench` Scheme；当前架构和工程边界见 [iOS 工程说明](../工程说明/README.md)，验收要求见 [测试与验收](../../../../../测试/测试与分级验收/测试与分级验收.md)。

| 目录／文件 | 职责与稳定入口 |
| --- | --- |
| `App/Bootstrap/` | `WBAppDelegate`、`WBSceneDelegate`、`WBAppCoordinator`：App／Scene、登录与业务页签、身份变更替换根页面 |
| [WBStore.swift](../App/Data/WBStore/WBStore.swift) | MainActor 会话、分页、详情、写入意图、源隔离；`clearIdentity`、`refresh`、`readPage`、`loadOrder`、`writeOrder`、`simpleWrite`、`probeDemo`、`send` |
| `App/Data/WBContract/`、`WBJSON/`、`WBActor/` | 严格整数金额与嵌套对象、未报价／空集合兼容；`actor`、`order`、`loan`、`settings`、`metrics`；身份比较见 `WBActor.matches` |
| `App/Data/WBJobsTransport/`、`WBEnvironment/` | JobsNetworking 适配、稳定 JSON 原文、无自动重试、短超时；Debug 本机配置与 Release HTTPS 边界 |
| `App/Data/WBDemoState/`、`WBOrderInput/` | 独立合成样例与有限离线动作；录单值类型的 9 个 `byXxx` 返回新值，`payload` 保持 API 字段 |
| `App/UI/` | `WBUI` 工厂与 Configuration 按钮，`WBPageView.rows` 动态持有，`WBFormField` 日期／金额／选择器，`WBTheme` 三态与 JobsThemeCenter |
| `App/Features/WBLoginVC/`、`WBDashboardVC/`、`WBOrdersVC/` | 登录、概览、搜索／状态筛选、加载更多和空态重试 |
| `App/Features/WBOrderFormVC/`、`WBOrderDetailVC/`、`WBActionFormVC/` | 链式组装录单、完整详情成功后开放办理、按 `allowedActions` 呈现业务表单 |
| `App/Features/WBInventoryVC/`、`WBInventoryFormVC/`、`WBSettingsVC/` | 库存与借还表单、公司配置、服务地址、主题及退出 |
| `App/Features/Signature/` | `WBSignatureVC` 核对报价／验收条款与开页上下文；`WBSignatureCanvas` 保留实际笔迹、绘制时协调父滚动并导出 PNG |
| `App/Features/WBFileEvidenceVC/`、`App/Platform/` | Files 原件白名单／大小与安全作用域读取；系统类型 `UIDocumentPickerViewController.make`、`UIGraphicsImageRenderer.make` 工厂 |
| `App/Resource/` | Debug／Release Info、明暗主题数据、本地 Logo 与隐私清单 |
| `Scripts/生成工程.rb`、`Podfile`、`Podfile.deps` | 增量工程引用／Scheme、依赖安装 hook 与纯依赖清单；Pods 根组 Ruby 引用保存后复开核验 |
| `测试/前端/移动端/iOS/Data/`、`测试/前端/移动端/iOS/Standalone/` | `WBDataScenarios` 基础同源 20 场景，`WBStubTransport` 控制回包；XCTest 另有 UIKit 像素与隔离真实 API 保护，实际执行状态按 [测试与验收](../../../../../测试/测试与分级验收/测试与分级验收.md) 分别记录 |

UIKit 页面与真实网络需单独验证；20 场景两种运行方式不累加为 40 个不同场景。离线状态不复制真实台账，离线未适配的签署、财务及库存写入不能改成演示成功；后端与网页的问题按 [测试与验收](../../../../../测试/测试与分级验收/测试与分级验收.md) 独立核验。

## 三、<span id="external-test-references">工程与外置测试定位</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [RepairWorkbench.xcworkspace](../RepairWorkbench.xcworkspace) | 本端工作区；App、JobsByPods、Podfile及脚本包保持组内相对关系。 |
| [生成工程.rb](../Scripts/生成工程.rb) | 增量维护 App 与外层 Data 测试文件引用；Tests 分组以 SOURCE_ROOT 指向测试目录，保留现有 UUID 与 CocoaPods 集成。 |
| [Data](../../../../../测试/前端/移动端/iOS/Data) | WBDataScenarios、WBFixture、WBStubTransport 和 XCTest；业务／测试源码分别维护。 |
| [Standalone](../../../../../测试/前端/移动端/iOS/Standalone) | 同源场景的独立运行入口 WBDataRunner；不与 XCTest 重复计算覆盖。 |
| [iOS工程说明](../工程说明/README.md) | 依赖、工程组织、构建与设备验证边界。 |

本端复用的 JobsByPods 按具体类型定位；Pods、供应商和生成文件不作为业务维护范围。测试 Target 指向外置源文件，不在 App 下重建测试副本。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
