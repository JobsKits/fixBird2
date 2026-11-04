# <span id="前言">Web 管理工作台</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、启动](#jobs-toc-heading-1)
- [二、能力](#jobs-toc-heading-2)
- [三、验证与源码](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

使用浏览器原生 [**JavaScript、HTML、CSS**](https://developer.mozilla.org/en-US/docs/Web) 实现，直接读取 [共享界面规范](../共享契约/admin-ui.json)。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、启动 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行 [MacOS 部署入口](../../../../部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command)，浏览器访问 http://127.0.0.1:8098/admin/；演示账号与步骤见 [使用说明](../../../README.md#usage-guide)。无需 npm install。

独立离线预览在项目根执行：

```sh
node './代码/前端/PC端/Web/离线预览.mjs'
```

然后访问 http://127.0.0.1:8099/admin/。不能直接双击 HTML，因为共享规范通过 HTTP 读取。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、能力 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

概览6指标、搜索／分页工单、完整详情、43种授权动作表单、PNG手写、8MB内文件选择、收退款资料记录、库存借还、采购收货、公司设置、账号启停、审计与身份关联导出。桌面224px侧栏，窄屏顶部横向导航；深浅色跟随系统。

默认同源 API，2500ms 可配置超时覆盖连接与响应正文。测试／线上地址分别保存；跨源服务需其明确配置 CORS，当前Go演示不开放跨源。仅内存保存token。服务恢复后刷新重新采用服务端资料。离线是独立合成副本，支持主链与部分台账；复杂动作提示联网，不会自动上传演示改动。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、验证与源码 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```sh
node --test 测试/前端/后台管理端/Web/单元/*.test.mjs
```

以上测试命令从仓库根运行。`core.mjs` 负责会话、身份、请求键与演示状态；`app.mjs` 负责原生 DOM 与表单；`styles.css` 负责响应式主题。实际浏览器、HTTP、目标环境与执行状态见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。API 超时按 [MDN AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) 处理，模态使用 [HTML dialog](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
