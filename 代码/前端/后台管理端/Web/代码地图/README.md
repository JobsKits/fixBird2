# <span id="前言">Web 后台管理端 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、管理页面与状态](#web-admin-entry)
- [三、外置测试与静态托管](#admin-tests)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位Web 后台管理端的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护Web 后台管理端自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#web-admin-entry) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/后台管理端/Web) | 测试源码与执行入口。 |

## 二、<span id="web-admin-entry">管理页面与状态</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [index.html](../index.html) | 页面入口及本地脚本／样式，浏览器原生实现，无 npm 安装步骤。 |
| [core.mjs](../core.mjs) | AdminStore：API请求、身份锚点、epoch、同键重试和独立合成演示；fieldValue、sameActor、validOrder 为字段与响应入口。 |
| [app.mjs](../app.mjs) | 原生 DOM、表单、Canvas签署、文件选择、响应式卡片、主题与双环境。 |
| [styles.css](../styles.css) | 管理端布局、明暗色与响应式样式。 |
| [admin-ui.json](../../共享契约/admin-ui.json) | 两管理实现共用导航、布局值、字段、43动作与合成种子；协议数据不在本端另建维护源。 |

## 三、<span id="admin-tests">外置测试与静态托管</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [core.test.mjs](../../../../../测试/前端/后台管理端/Web/单元/core.test.mjs) | 加载真实 AdminStore 与同一契约，验证会话、请求、表单、演示与权限边界。 |
| [验证管理端.mjs](../../../../../测试/前端/后台管理端/Web/验证管理端.mjs) | 显式隔离回环服务下复用真实 AdminStore；登录、创建、读回、动作版本、导出和退出。 |
| [PC Web离线预览](../../../PC端/Web/离线预览.mjs) | 仅静态预览；分别托管本端、共享契约与字体，不提供真实业务API。 |

本端通过 `/admin/` 同源加载，Flutter 管理端属于 [独立 Flutter 应用](../../Flutter/代码地图/README.md)。两端共享契约，JavaScript与Dart实现分别维护；本图只定位Web管理端。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
