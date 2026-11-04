# <span id="前言">Web 维修协同工作台</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、启动与演示](#jobs-toc-heading-1)
- [二、验证](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

浏览器维修协同工作台调用 `/api/v38`，提供完整业务操作和独立合成演示。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、启动与演示 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行 [MacOS 部署入口](../../../../部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command) 后访问 [维修工作台](http://127.0.0.1:8098/)；[Web 管理端](http://127.0.0.1:8098/admin/)使用独立界面。

无服务器时，在本目录使用 [**Node.js**](https://nodejs.org/) 运行：

```sh
node './离线预览.mjs'
```

访问 [离线工作台](http://127.0.0.1:8099/) 或 [离线管理端](http://127.0.0.1:8099/admin/)；服务只托管静态界面，API 返回 503，不读取真实业务存储。页面继续请求 API，失败后显示独立合成数据；动态列表提供空态与重载，本地 Logo 可离线显示。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从当前端根目录运行外置测试：

```sh
node --test ../../../../测试/前端/PC端/Web/*.test.cjs
```

业务和有限离线边界见 [接口合同](../../../后端/README.md#api-contract)、[测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)；操作步骤见 [使用说明](../../../README.md#usage-guide)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
