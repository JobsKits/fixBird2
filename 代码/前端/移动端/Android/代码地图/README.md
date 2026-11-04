# <span id="前言">Android 原生客户端 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、原生工程与稳定入口](#native-entry)
- [三、独立合同检查](#contract-checks)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位Android 原生客户端的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护Android 原生客户端自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#native-entry) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/移动端/Android) | 测试源码与执行入口。 |

## 二、<span id="native-entry">原生工程与稳定入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [MainActivity.kt](../app/src/main/java/com/jobs/repair/MainActivity.kt) | Kotlin 原生页面、角色入口、工单、表单、库存与设置；权限和可办理动作由服务端返回。 |
| [Repository.kt](../app/src/main/java/com/jobs/repair/Repository.kt) | HTTP、认证身份、环境／超时、响应校验、幂等写入与未知结果。 |
| [Forms.kt](../app/src/main/java/com/jobs/repair/Forms.kt) | 43 类动作表单、字段与提交数据；金额以整数分传输。 |
| [DemoStore.kt](../app/src/main/java/com/jobs/repair/DemoStore.kt) | 独立合成台账与本地守卫；与真实资料隔离，恢复后以服务端响应替换。 |
| [SignatureView.kt](../app/src/main/java/com/jobs/repair/SignatureView.kt) | 原生 Canvas 手写、清空及 PNG 编码，拒绝空白签署。 |
| [app/src/main](../app/src/main) | Manifest、代码与本地资源；文件选择、网络权限和设备行为分别验收。 |
| [build.gradle.kts](../build.gradle.kts) | 本端 Android 构建配置；SDK、Gradle与设备由目标机器提供。 |

## 三、<span id="contract-checks">独立合同检查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [ContractChecks.kt](../../../../../测试/前端/移动端/Android/ContractChecks.kt) | 复用实际 Repository／DemoStore／Forms；临时 HTTP 夹具与显式隔离 Go 接口分别验证。 |
| [build.gradle.kts](../../../../../测试/前端/移动端/Android/build.gradle.kts) | 独立 JVM 工程，以相对 sourceSets 引用本端 Kotlin，不复制业务源码。 |

JVM 合同检查、Android APK／Lint、Canvas 操作、文件选择与另存为、签名和实体设备是不同验收项。服务接口以 [接口约定](../../../../后端/README.md#api-contract) 为准。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
