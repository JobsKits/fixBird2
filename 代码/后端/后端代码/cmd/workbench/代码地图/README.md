# <span id="前言">后端启动单元代码地图</span>

![Jobs出品，必属精品](../../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口与职责](#jobs-toc-heading-1)
- [二、配置寻址](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

> 只覆盖当前 cmd/workbench 实现及其配置路径。


本目录定位所属开发单元的源码、配置与测试，跨单元通过相对链接协作。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、入口与职责 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 文件 | 职责 | 关键符号／验证 |
| --- | --- | --- |
| [启动入口](../main.go) | 选择存储、CLI 备份／恢复、回环 HTTP、定时任务与 `/securityz` | `run`、`backupMonitor.run` |
| [web.go](../web.go) | admin、admin-flutter、client-flutter、admin-contract静态路由；web_test.go检查路由隔离与未构建503 |
## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、配置寻址 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

`configuredRuntimeDir` 只解析 `WB_RUNTIME_DIR` 或当前用户系统目录；`configuredProjectDir` 只解析 `WB_PROJECT_ROOT` 或二进制所在完整项目树。`run` 的存储、业务服务、监听、备份与调度仍沿用原实现；静态默认路径指向前端实际工程及各端 `Dist/Web`。

原路由测试已移到 [外置测试](../../../../../../测试/后端/单元/cmd/workbench/web_test.go)，通过 [overlay入口](../../../../../../测试/后端/运行测试.py/README.md)执行。

本地图对应的索引位于 `../../../.codegraph/`，配置为 [codegraph.json](../../../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
