# <span id="前言">后端测试</span>

![Jobs出品，必属精品](../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口](#jobs-toc-heading-1)

</details>
<!-- jobs-toc:end -->

---

> 单元测试保持原 Go 包上下文；HTTP 验证使用独立合成数据和临时端口。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- [Go 单元运行器](./运行测试.py/README.md)：外置 16 份原测试，默认覆盖启动静态路由包及业务包。
- [HTTP 验证](./接口/验证工作台.mjs)：构建独立后端并验证真实回环业务；执行前需已有 Go、Node.js 及锁定依赖。本轮目录整理未运行此服务流程。

单元测试、接口流程、专用 TiDB、目标机与生产部署分别验收；不使用现有实例或真实客户资料。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
