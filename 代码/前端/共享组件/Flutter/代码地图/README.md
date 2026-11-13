# <span id="前言">Flutter 共享业务包 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、公共导出与实际实现](#shared-package)
- [三、调用者与契约维护源](#shared-callers-and-contract)
- [四、外置共享测试](#shared-tests)
- [五、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

`launchWorkbench(admin: true)` 通过 `WorkbenchStore.openAdmin/checkEnvironment` 识别服务端 Demo；仅明确 Demo 自动进入管理员，正式与未知环境必须登录。移动端入口继续使用原有登录流程。

---

本图只定位Flutter 共享业务包的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护Flutter 共享业务包自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#shared-package) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/共享组件/Flutter) | 测试源码与执行入口。 |

## 二、<span id="shared-package">公共导出与实际实现</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [lib/repair_shared.dart](../lib/repair_shared.dart) | repair_shared 公共入口；导出 app、contract、store，供用户与管理两个 App 以 package URI 引用。 |
| [contract.dart](../lib/src/contract.dart) | WorkbenchContract、Json与字段解码；身份、完整工单和嵌套响应的约束。 |
| [store.dart](../lib/src/store.dart) | WorkbenchStore：真实API、会话／读取顺序、请求意图、环境双地址、账号审计、401撤销与恢复。 |
| [demo.dart](../lib/src/demo.dart) | DemoLedger：独立合成台账、角色可见性、允许动作与本地业务守卫。 |
| [app.dart](../lib/src/app.dart) | launchWorkbench、WorkbenchApp、WorkbenchHome；响应式页面、导航、完整详情、库存采购、账号和主题。 |
| [localization.dart](../lib/src/localization.dart) | WorkbenchTranslations、WorkbenchLocaleScope、WorkbenchText；十语展示、语言偏好及即时切换，业务原文与请求不受影响。 |
| [form.dart](../lib/src/form.dart) | WorkbenchForm、showWorkbenchDateTimePicker、十语字段、手写 PNG、文件选择与提交。 |
| [assets/](../assets) | 共享本地Logo、中文字体、许可与契约副本；包内路径保持既有声明。 |
| [pubspec.yaml](../pubspec.yaml) | 共享依赖、资源与字体声明；两个App均通过相对path复用本包。 |

## 三、<span id="shared-callers-and-contract">调用者与契约维护源</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

调用者分别为 [用户／工程师端](../../../移动端/Flutter/代码地图/README.md) 和 [Flutter 管理端](../../../后台管理端/Flutter/代码地图/README.md)。UI契约维护源为 [admin-ui.json](../../../后台管理端/共享契约/admin-ui.json)，包内 `assets/admin-ui.json` 为受控副本；单元检查比较字节一致，不形成两套人工维护源。

## 四、<span id="shared-tests">外置共享测试</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [workbench_test.dart](../../../../../测试/前端/共享组件/Flutter/单元/workbench_test.dart) | 实际 Store、合同、演示、逆序响应及窄屏／桌面 Widget检查；从本共享包根运行以加载资源。 |
| [real_api_test.dart](../../../../../测试/前端/共享组件/Flutter/接口/real_api_test.dart) | 显式API_TEST_URL指向隔离合成服务，验证真实网络；未运行不能计入通过。 |
| [web_money_probe.dart](../../../../../测试/前端/共享组件/Flutter/接口/web_money_probe.dart) | 运行真实 DemoLedger，检查Dart VM与Dart2JS金额表达差异。 |

共享测试、两个应用各自构建、浏览器及原生设备分别验收；`lib/src` 和 `assets` 是包内布局，不因外层目录整理改写实现或资源声明。

## 五、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
