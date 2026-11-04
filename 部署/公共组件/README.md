# 部署公共组件

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、模块导航](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录存放供多个操作系统部署入口复用的辅助模块。各系统的快捷入口、部署与反部署实现继续放在各自系统目录，入口和参数见[部署指南](../README.md#systems)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、模块导航 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 模块 | 职责与调用方式 |
| --- | --- |
| [地址二维码](./地址二维码/README.md) | 独立 [**Go**](https://go.dev/) 模块，由各平台部署实现用已准备的 Go 构建；生成终端二维码及本地 HTML／SVG／PNG，不修改业务模块，不调用在线二维码服务 |

公共组件源代码与依赖声明留在本目录，构建缓存由机器环境管理，生成的辅助程序与二维码留在本次 Runtime 会话。配对反部署按原有清单处理运行产物，源码不属于运行资源删除范围。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
