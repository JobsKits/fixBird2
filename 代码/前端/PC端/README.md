# <span id="前言">PC 端</span>

![项目图标](../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

暂无章节。

</details>
<!-- jobs-toc:end -->

---

PC 端包含三个独立入口，共用现有 `/api/v38` 业务服务：

| 入口 | 技术与用途 |
| --- | --- |
| [Web 工作台](./Web/README.md) | 标准网页，覆盖桌面浏览器与手机竖屏；[代码地图](./Web/代码地图/README.md) |
| [MacOS 原生桌面](./MacOS/README.md) | SwiftUI 原生窗口、表单、签名与系统文件选择 |
| [WindowsOS 原生桌面](./WindowsOS/README.md) | C#／WPF 原生窗口、表单、签名与系统文件选择 |

原生桌面直接访问 API，不内嵌网页。源码、构建入口、产物及目标系统实测分别核验，见[资产盘点](../../../项目相关报告/README.md)。

<a id="🔚" href="#前言">返回前言</a>
