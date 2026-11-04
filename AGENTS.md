# V3.8 项目代码定位

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、定位与维护](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本文件只补充本项目定位入口，沿用用户全局规约。

本项目按 [项目需求与开发评审](./需求/项目需求与开发评审/项目需求与开发评审.md) 组织需求、设计、测试、部署与交接。当前源码和交付范围见 [实现范围](./需求/技术方案与实现范围/技术方案与实现范围.md)、[交付清单](./需求/交付与运维清单/交付与运维清单.md)；验收入口见 [测试与验收](./测试/测试与分级验收/测试与分级验收.md)，尚未处理的问题集中在 [当前问题清单](./需求/当前问题清单/当前问题清单.md)。文档只维护当前基线，不追加更新记录、修复流水、多轮报告或日期化证据目录。

目录按 [项目目录说明](./README.md#directory) 分为代码、测试、需求、部署；代码内按前端、后端分工。通用服务源码仅放 `代码/后端/后端代码`，部署资料按目标操作系统放 `部署`。用户／工程师端包含 Web、[**Swift**](https://www.swift.org/) [**iOS**](https://developer.apple.com/ios/)、[**Flutter**](https://flutter.dev/)、[**Android**](https://developer.android.com/) 与[**鸿蒙**](https://developer.huawei.com/consumer/cn/)；管理端为 Flutter／Web 双工程，[**微信小程序**](https://developers.weixin.qq.com/miniprogram/dev/framework/)为本期独立官方原生端，工程在 `代码/前端/微信小程序`。源码具备、构建、实机和正式发布分别核验，不把演示结果外推为生产验收。

公共 SDK、依赖与缓存由目标机器管理，参考[环境说明](./部署/README.md#machine-environment)。项目内明确登记的私库保留；业务数据和密钥位于项目专属运行目录，清理缓存不接触它们。代码地图仅描述所属独立开发单元，上级 README 只导航。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、定位与维护 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 先从[开发单元导航](./代码/README.md#unit-code-maps)进入本次具体端、语言工程或操作系统部署目录内的代码地图，再用 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 查询具体文件或符号；不要默认全量扫描或读取大文件。
- MCP 使用 `codegraph_explore`，`projectPath` 指向本次具体端／语言工程的代码根，`maxFiles` 通常设为 1～3。后端示例：`codegraph explore -p ./代码/后端/后端代码 --max-files 3 'internal/workbench/permissions.go canReadEvidence'`。已返回的源码不重复读取；缺边、漏符号或工具不可用时再局部 `rg`。
- `.codegraph/` 与 `codegraph.json` 只属于具体代码开发单元，项目根不维护混合索引。修改源码后仅同步所属单元，例如 `codegraph sync ./代码/后端/后端代码`，再用 `codegraph status --json ./代码/后端/后端代码` 检查；入口或模块职责变动时同步单元地图。尚无索引的单元使用就近地图与局部搜索，不在上层主动初始化；索引不纳入运行数据、密钥、第三方工具或验证日志。
- 当前 V3.8 主入口是 `代码/后端/后端代码/cmd/workbench`、`代码/后端/后端代码/internal/workbench`、`代码/前端/PC端/Web/维修工作台`。管理端入口为 `代码/前端/后台管理端/{Web,Flutter}`，共同规范在 `共享契约/admin-ui.json`；各端定位见本单元自己的代码地图。接口行为看 [合同](./代码/后端/README.md#api-contract)，当前问题及复现看 [当前问题清单](./需求/当前问题清单/当前问题清单.md)。
- 维修是否先款由 `quote.startRequiresPrepayment` 明确约定，字段缺省为 false；现款销售仍按冻结报价总额核实净收款后出库。签署历史、质保日历、会话撤销和演示派生规则修改时，同时核对地图列出的正式测试。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
