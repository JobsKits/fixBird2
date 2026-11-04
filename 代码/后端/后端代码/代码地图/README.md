# <span id="前言">后端工程代码地图</span>

![Jobs出品，必属精品](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、实际实施单元](#jobs-toc-heading-1)

</details>
<!-- jobs-toc:end -->

---

> 本工程保持单一 Go module，包名及业务实现不因目录整理改变。


本目录定位所属开发单元的源码、配置与测试，跨单元通过相对链接协作。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、实际实施单元 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 位置 | 内容 |
| --- | --- |
| [启动单元地图](../cmd/workbench/代码地图/README.md) | cmd/workbench 启动、静态托管、配置路径及定时备份 |
| [业务单元地图](../internal/workbench/代码地图/README.md) | internal/workbench 业务规则、权限、持久化与原有回归 |
| [TiDB 快照 DDL](../MigrationsWorkbench/001_snapshot.sql) | 当前单张聚合快照表结构 |
| [接口合同](../../README.md#api-contract) | 本期 V3.8 API、字段及职责约定 |
| [外置测试入口](../../../../测试/后端/运行测试.py/README.md) | 临时 Go overlay，不复制测试回源码 |

本地图对应的索引位于 `../.codegraph/`，配置为 [codegraph.json](../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
