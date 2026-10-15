# V3.8 项目代码定位

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本文件只补充本项目定位入口，沿用用户全局规约。

当前先读 [五次回归报告](./docs/五次回归报告-2026-10-15.md)：确认 17 组 P2 尚未修复，后端 4、网页坏响应保护 3、独立演示 10；其中 15 组为新发现，F03／D10 为上轮补充遗漏。第五轮回归时 124 个业务源码、正式测试及入口文件未改，不能把诊断失败数当作缺陷组数，或把坏 2xx／合成演示结果外推为真实后端越权。完整执行结果以报告为准，再按代码地图定位。

[四次修复说明](./docs/四次修复说明-2026-10-15.md) 保留第四轮 14 组修复及 X01“仅明确约定先款开修时核实预付款”的用户确认实现；[四次回归报告](./docs/四次回归报告-2026-10-15.md) 保留当时修复前发现与失败证据。

当前目录按 [项目目录说明](./README.md#directory) 分为前端、后端、验证、需求与文档；目录重组只调整位置和入口引用，不代表修复上述 17 组问题。通用服务源码仅放 `后端/Go服务端`，部署资料按目标操作系统放 `后端/部署`；`前端/iOS` 已提供 Swift 原生工程、JobsByPods 和独立 Podfile.deps，定位先查代码地图的 iOS 入口；Android／鸿蒙／微信小程序及非 macOS 部署脚本仍为预留，不能当成已有可运行工程。

## 一、定位与维护 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 先按任务阅读 [代码地图](./代码地图.md) 对应行，再用 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 查询具体文件或符号；不要默认全量扫描或读取大文件。
- MCP 使用 `codegraph_explore`，`projectPath` 指向本目录，`maxFiles` 通常设为 1～3。命令行示例：`codegraph explore -p . --max-files 3 '后端/Go服务端/internal/workbench/permissions.go canReadEvidence'`。已返回的源码不重复读取；缺边、漏符号或工具不可用时再局部 `rg`。
- 修改源码后运行 `codegraph sync .`，用 `codegraph status --json .` 检查状态；入口或模块职责变动时同步更新地图对应项。`.codegraph/` 是可再生本地索引，范围由 [配置](./codegraph.json) 控制，禁止纳入运行数据、密钥、第三方工具和验证日志。
- 当前 V3.8 主入口是 `后端/Go服务端/cmd/workbench`、`后端/Go服务端/internal/workbench`、`前端/Web网页/维修工作台`。旧业务基线另列于地图，避免把同名旧模块当成新工作台。接口行为看 [合同](./docs/workbench-contract.md)，当前待修问题及复现看 [五次回归报告](./docs/五次回归报告-2026-10-15.md)，历史修复看 [四次修复说明](./docs/四次修复说明-2026-10-15.md)。
- 维修是否先款由 `quote.startRequiresPrepayment` 明确约定，旧数据缺省为 false；现款销售仍按冻结报价总额核实净收款后出库。签署历史、质保日历、会话撤销和演示派生规则修改时，同时核对地图列出的正式测试。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
