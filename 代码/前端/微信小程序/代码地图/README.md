# <span id="前言">微信小程序 · 代码地图</span>

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、微信原生页面与数据层](#mini-source-entry)
- [三、外置测试与来源](#mini-tests-and-dependencies)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位微信小程序的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../后端/README.md#api-contract)。


本目录维护微信小程序自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#mini-source-entry) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../测试/前端/微信小程序) | 测试源码与执行入口。 |

## 二、<span id="mini-source-entry">微信原生页面与数据层</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [app.js](../app.js) | 微信应用入口；project.config.json以本目录作为miniprogramRoot。 |
| [pages/workbench](../pages/workbench) | WXML／WXSS与JS原生页面：登录、工单、详情、合同表单、库存、签署、附件与设置。 |
| [utils/store.js](../utils/store.js) | Store、ApiError、endpoint：会话、短超时、分页、完整响应核验、请求键、读取顺序与独立演示。 |
| [utils/form.js](../utils/form.js) | fields、payload、action；43类契约字段、金额、日期与提交数据转换。 |
| [utils/demo.js](../utils/demo.js) | 由现有Web合成模型随包派生；seed、createOrder、apply、derive、refreshOrder，保持独立进程内演示边界。 |
| [assets/contract.json](../assets/contract.json) | 共享43类UI合同的包内副本，和维护源比较内容一致。 |
| [assets/RepairLogo.png](../assets/RepairLogo.png) | 复用本项目已有Logo，随包加载，无运行时网络图依赖。 |

## 三、<span id="mini-tests-and-dependencies">外置测试与来源</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [mini.test.cjs](../../../../测试/前端/微信小程序/mini.test.cjs/mini.test.cjs) | Node内置运行器；真实Store、表单、WXML事件和故障／恢复；配置隔离REPAIR_TEST_BASE才执行实际Go接口。 |
| [UI契约维护源](../../后台管理端/共享契约/admin-ui.json) | 包内合同的一致性参照；不改协议JSON正文。 |
| [Web合成模型](../../PC端/Web/维修工作台/data.js) | demo.js的既有派生来源；不在运行时从另一端读取源码。 |

本端是官方原生小程序。Node合同检查、开发者工具编译、手机Canvas与文件选择、体验版及正式发布分别验收；微信登录、支付与订阅消息不能因通用API存在而写成已接入。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
