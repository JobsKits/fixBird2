# <span id="前言">Flutter 后台管理端 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、本应用入口与依赖](#app-entry)
- [三、资源、契约与测试](#app-resources-and-tests)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位Flutter 后台管理端的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护Flutter 后台管理端自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#app-entry) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/后台管理端/Flutter) | 测试源码与执行入口。 |

## 二、<span id="app-entry">本应用入口与依赖</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [lib/main.dart](../lib/main.dart) | 唯一业务启动入口：`launchWorkbench(admin: true)`；本应用负责管理端身份与导航选择。 |
| [pubspec.yaml](../pubspec.yaml) | 声明 repair_shared 的相对 path 依赖及本应用配置，锁定解析位于 pubspec.lock。 |
| [共享业务地图](../../../共享组件/Flutter/代码地图/README.md) | 实际页面、模型、网络、表单、签署和演示实现集中在 repair_shared，本应用不复制这些源码。 |
| [android/](../android) | Flutter Android 平台壳和构建配置；与独立原生 Android 产品分开。 |
| [ios/](../ios) | Flutter iOS 平台壳、Runner工程与共享Scheme；与独立 Swift 原生产品分开。 |
| [web/](../web) | Web 引导页与图标声明；编译包保留在 Dist/Web，由 Go 同源托管。 |

## 三、<span id="app-resources-and-tests">资源、契约与测试</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

管理界面值与动作由 [共享界面契约](../../共享契约/admin-ui.json) 定义；Flutter 使用共享包内受一致性检查的副本。

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [RunnerTests.swift](../../../../../测试/前端/后台管理端/Flutter/iOS/RunnerTests.swift) | 本应用 iOS 测试 Target 外置源文件，PBX Tests分组通过 SOURCE_ROOT 定位。 |
| [共享单元与接口测试](../../../../../测试/前端/共享组件/Flutter) | Widget、Store与合同用例在共享包上下文执行；本应用构建与设备运行另验。 |

Web 同源入口为 `/admin-flutter/`。源码存在、依赖解析、Web／原生构建、签名和实体设备分别核验；本图不把共享包测试写成本应用设备通过。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
