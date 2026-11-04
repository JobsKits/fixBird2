# <span id="前言">PC Web 维修协同工作台 · 代码地图</span>

![啄木鸟维修平台](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、阅读入口](#map-navigation)
- [二、网页模块与交互入口](#frontend-map)
  - [2.1、当前 P2 与相关守卫定位](#pending-web-issue-locators)
- [三、请求到本端入口](#request-entry)
- [四、预览与外置测试](#preview-and-tests)
- [五、定位与验收边界](#verification-boundary)

</details>
<!-- jobs-toc:end -->

---

本图只定位PC Web 维修协同工作台的工程、稳定符号与外置测试。日常操作见 [本端说明](../README.md)；业务接口见 [工作台接口约定](../../../../后端/README.md#api-contract)。


本目录维护PC Web 维修协同工作台自己的源码定位图，记录实际入口、模块职责、稳定符号及外置测试。

## 一、<span id="map-navigation">阅读入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 用途 |
| --- | --- |
| [代码地图](#frontend-map) | 按本端模块和符号定位实现。 |
| [本端说明](../README.md) | 使用、依赖、构建及交付边界。 |
| [本端外置测试](../../../../../测试/前端/PC端/Web) | 测试源码与执行入口。 |

## 二、<span id="frontend-map">网页模块与交互入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 职责 | 关键符号／区域 |
| --- | --- | --- |
| [index.html](../维修工作台/index.html) | 导航、工单筛选、全范围指标、弹窗与脚本加载顺序 | `ordersView`、`filterForm`、`metrics`、`detailDialog`、`formDialog` |
| [styles.css](../维修工作台/styles.css) | 桌面／移动布局、表格、弹窗、空态与分页 | `.orders-table`、`.detail-dialog`、`.empty-state`、`.list-pagination` |
| [app.js](../维修工作台/app.js) | IIFE 内集中管理身份、真实／合成数据与事件绑定 | `render`、`showView`、`login`、`openDemo`、`refresh`、`applySnapshotMetadata` |
| `app.js` 请求与写入 | 同源地址、超时、嵌套校验、请求键与成功确认 | `normalizeBase`、`request`、`validateResponse`、`validSummary`、`validPart`、`validLoan`、`validPurchase`、`validOrderRecords`、`formKey`、`releaseFormKey` |
| `app.js` 身份与快照 | 任一当前 401 撤销旧资料，以登录会话校验完整及迟到元数据，待加载配置禁止保存 | `revokeSession`、`enterFallback`、`clearSessionViews`、`emptyServerSnapshot`、`sameSessionActor`、`sessionActor`、`snapshotReady` |
| `app.js` 列表与指标 | 服务器分页、全范围概览、工单页筛选作用域 | `orderQuery`、`loadOrders`、`pageInfo`、`pageOrders`、`pager`、`renderMetrics` |
| `app.js` 详情与表单 | 完整详情读取后办理；先款约定、签署历史只读展示、附件和全局库存操作 | `completeOrder`、`openDetail`、`showAction`、`modal`、`finishForm`、`showSignature`、`globalForm` |
| `app.js` 设置与审计 | 账号授权变更、备份状态、管理员审计分页 | `settingsMetadata`、`accountStatusForm`、`loadAudit` |
| [data.js](../维修工作台/data.js) | 独立合成样例、执行／完结边界、按数量借还与阶段派生，不缓存真实台账 | `seed`、`createOrder`、`apply`、`derive`、`loanBlockingQuantity`、`refreshOrder`、`cents`、`integer`、`addMonths`、`chinaDay` |
| [RepairLogo.png](../维修工作台/assets/RepairLogo.png) | 随包本地 Logo | `index.html` 中图标与品牌资源 |

`dataKind` 区分真实服务和独立演示，`sessionActor` 固定当前真实认证身份；bootstrap 的身份必须匹配该会话，不能信任旧 `data.actor`。登录开始和成功确立新身份时均撤销旧界面与表单，`snapshotReady` 防止保存未加载的占位公司配置。`revokeSession` 在请求边界处理任一当前会话 401，导航序号不能吞掉撤销；非 401 网络回退保留可信会话以便自动重连，401 或主动独立演示撤销会话。

`epoch` 拦截身份／连接／回退变化后的旧结果，列表使用 `listRevision`，详情使用 `detailRequests`；`formRevision` 保护当前表单实例，`actionIntent` 取消迟到办理意图，`refreshJob` 协调连续成功保存与导航期间的最新刷新。导航的工单页先到时，迟到 bootstrap 只补当前身份的概览等元数据，同会话概览失败仍完整回退演示；等待时显示待加载。嵌套校验先于缓存提交，兼容真实未报价版本 0；`modal` 不清除无关未知写入意图键。修改异步交互先查这些边界，再看视图函数。`isSummary=true` 的列表项不能当完整工单打开办理表单。

### 2.1、<span id="pending-web-issue-locators">当前 P2 与相关守卫定位</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以下仅补充本端定位入口；[当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)中的 P2 仍未修复，验收复测未执行。错误成功响应与独立合成演示分别核验，不据此推断正常服务端放行。

| 场景 | 本端稳定入口与核对范围 |
| --- | --- |
| F03 嵌套现金与库存响应 | `fields`、`validOrderRecords`、`validLoan`、`validateResponse`；检查字段模式、整数金额、现金方向与完整写响应。 |
| D02／D09 完结或终局单据的动作候选 | `stageActions`、`commonActions`、`available`、`globalForm`；与 `data.js` 的 `apply`／`refreshOrder` 联合定位，避免把候选动作展示当成完整业务守卫。 |
| D01／D03／D04 演示借还与责任人 | `renderInventory`、`globalForm`、`localApply`；检查本端演示动作分派、批准角色、维修归属及借用人选项。 |
| 内部余项的办理上下文 | `canResolveObligation`、`showAction`、`globalForm`；核对逐项责任人与表单上下文，本定位不新增问题编号或变更现有状态。 |
| B02 免费返修的网页金额输入 | `amountField`、`showAction`；定位零价输入限制，后端处理与放行结论仍见问题清单。 |
| D07／D08 发票与资料原件 | `evidenceSelector`、`showAction`；与 `data.js` 的发票／资料发送分支核对原件、票号、约定及接收对象。 |

## 三、<span id="request-entry">请求到本端入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| API／场景 | 本端定位 |
| --- | --- |
| 登录／退出 | `login`、退出点击处理；先撤销旧身份界面，再提交当前会话 |
| 概览、订单分页与详情 | `refresh`、`renderMetrics`、`loadOrders`、`orderQuery`、`completeOrder`、`openDetail` |
| 创建与动作写入 | `createForm`、`showAction`、`mutateOrder`；请求键及未知结果见 `formKey`、`releaseFormKey` |
| 附件、借还与采购 | `previewFile`、`globalForm`；完整详情与授权决定办理入口 |
| 账号、设置、审计与导出 | `settingsMetadata`、`accountStatusForm`、`companyForm`、`loadAudit`、`exportOrders` |

## 四、<span id="preview-and-tests">预览与外置测试</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件／目录 | 职责与定位入口 |
| --- | --- |
| [离线预览.mjs](../离线预览.mjs) | 本机静态预览；分别定位本端页面及管理端、Flutter Web、契约和字体资源。API 返回未连接，不启动业务服务。 |
| [app.test.cjs](../../../../../测试/前端/PC端/Web/app.test.cjs) | 加载本端真实 app.js，检查身份、当前401、概览恢复、迟到回包、嵌套坏响应、未知写与表单生命周期。 |
| [data.test.cjs](../../../../../测试/前端/PC端/Web/data.test.cjs) | 独立合成台账的金额、质保、库存与权限计算。 |
| [data-boundaries.test.cjs](../../../../../测试/前端/PC端/Web/data-boundaries.test.cjs) | 演示异议、报价、重开返修、借还数量、先款与冻结销售报价边界。 |

管理后台是独立工程，入口见 [Web 管理端地图](../../../后台管理端/Web/代码地图/README.md)。本图只定位本工作台；接口约定见 [工作台接口约定](../../../../后端/README.md#api-contract)。

## 五、<span id="verification-boundary">定位与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按本图选文件与符号，再使用本代码开发单元已有 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引查询；缺边或工具不可用时局部检索，不自动初始化或安装工具。跨单元只沿必要依赖链接进入对应地图，不在本图复制其它端或后端实现。

测试方法与执行状态统一见 [测试与分级验收](../../../../../测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题见 [当前问题清单](../../../../../需求/当前问题清单/当前问题清单.md)。源码、静态检查、合同测试、目标系统构建及设备运行分别记录；本地图不代表这些项已经执行。

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
