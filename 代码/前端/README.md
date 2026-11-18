# <span id="前言">前端目录说明</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、客户端](#jobs-toc-heading-1)

</details>
<!-- jobs-toc:end -->

---

用户与工程师端按平台独立组织，共同调用 `/api/v38`。

对外产品名称为“啄木鸟维修平台”。用户端的系统显示名、网页标题与页面品牌统一使用该名称；管理端显示为“啄木鸟维修平台 · 管理工作台”，宿主短名为“啄木鸟维修平台管理端”。产品名称不附带版本号；技术版本、应用标识与既有偏好存储键按各工程配置保留。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、客户端 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 目录 | 实现 |
| --- | --- |
| [iOS](./移动端/iOS/README.md) | [**Swift**](https://www.swift.org/) 原生工程与 JobsByPods |
| [Flutter](./移动端/Flutter/README.md) | [**Flutter**](https://flutter.dev/) 用户／工程师应用 |
| [共享Flutter](./共享组件/Flutter/README.md) | 两个Flutter应用共用的模型、请求、表单与原生组件 |
| [Android](./移动端/Android/README.md) | [**Kotlin**](https://kotlinlang.org/) 原生工程 |
| [鸿蒙](./移动端/鸿蒙/README.md) | [**ArkTS**](https://developer.huawei.com/consumer/cn/arkts/)／ArkUI Stage 原生工程 |
| [Web网页](./PC端/Web/README.md) | 桌面浏览器／手机竖屏工作台和离线预览 |
| [MacOS桌面](./PC端/MacOS/README.md) | SwiftUI 原生桌面应用 |
| [WindowsOS桌面](./PC端/WindowsOS/README.md) | C#／WPF 原生桌面应用 |
| [微信小程序](./微信小程序/README.md) | [**微信官方原生**](https://developers.weixin.qq.com/miniprogram/dev/framework/)独立工程，JavaScript／WXML／WXSS／JSON |

管理端另在 [后台管理端](后台管理端/README.md)。普通操作者先读 [使用说明](../README.md#usage-guide)，开发者读对应平台 README、[交付清单](../../需求/交付与运维清单/交付与运维清单.md)和[测试与验收](../../测试/测试与分级验收/测试与分级验收.md)；目录或工程存在不代表已通过设备验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
