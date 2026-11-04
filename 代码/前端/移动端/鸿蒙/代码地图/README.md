# <span id="前言">鸿蒙原生客户端 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、Stage 入口与核心模块](#stage-entry)
- [三、核心合同与平台验收](#portable-contract-tests)
- [四、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位鸿蒙原生客户端的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护鸿蒙原生客户端自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#stage-entry) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/移动端/鸿蒙) | 测试源码与执行入口。 |

## 二、<span id="stage-entry">Stage 入口与核心模块</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [EntryAbility.ets](../entry/src/main/ets/entryability/EntryAbility.ets) | Stage UIAbility，加载 Index 原生页面。 |
| [Index.ets](../entry/src/main/ets/pages/Index.ets) | ArkUI 页面、连接设置、工单详情、原生表单、Canvas与文件交互。 |
| [Models.ets](../entry/src/main/ets/core/Models.ets) | 身份、整数金额、工单／分页及库存响应校验。 |
| [ActionCatalog.ets](../entry/src/main/ets/core/ActionCatalog.ets) | 动作标题、字段、金额／日期与提交校验。 |
| [WorkbenchStore.ets](../entry/src/main/ets/core/WorkbenchStore.ets) | configure、login、refresh、list、detail、create、perform；会话代次、迟到响应与未知写保护。 |
| [DemoLedger.ets](../entry/src/main/ets/core/DemoLedger.ets) | 独立样例、有限动作与演示阶段守卫，不产生真实签署或财务事实。 |
| [HttpTransport.ets](../entry/src/main/ets/platform/HttpTransport.ets) | NetworkKit HTTP 适配、短超时与授权请求。 |
| [FileEvidence.ets](../entry/src/main/ets/platform/FileEvidence.ets) | 系统文件 Picker、原件大小／类型与签署 PNG 边界。 |
| [module.json5](../entry/src/main/module.json5) | 入口、设备类型与权限；AppScope及资源目录沿用平台布局。 |

## 三、<span id="portable-contract-tests">核心合同与平台验收</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [regression.mjs](../../../../../测试/前端/移动端/鸿蒙/regression.mjs) | 读取本端真实核心 ETS，转换到系统临时目录运行合同与故障恢复检查；显式传入隔离接口时才运行真实 HTTP。 |

Node.js 核心检查不编译 ArkUI，也不代表 HAP、签名、手机／平板、Canvas触控和文件供应商 URI 已通过。工程导入与设备步骤见 [本端说明](../README.md)。

## 四、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
