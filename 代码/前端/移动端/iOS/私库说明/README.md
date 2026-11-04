# <span id="前言">iOS 随项目私库说明</span>

![项目图标](../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

暂无章节。

</details>
<!-- jobs-toc:end -->

---

本项目明确随源码保留下列 JobsByPods 本地模块，用于现有 iOS 工程；它们属于源码依赖，不是 Apple SDK 或公共 CocoaPods 下载缓存。来源为既有 Jobs Swift 工程蓝本，接入以 `../Podfile.deps`、`../Podfile.lock` 和包内 podspec 为准。未提供的独立版本或授权信息留空，不补造。

| 模块 | 本项目位置 | podspec 版本 |
| --- | --- | --- |
| JobsByQuartzCore@Pods | [本地源码](<../JobsByPods/JobsByQuartzCore@Pods/>) | 0.0.1 |
| JobsByUIKit@Pods | [本地源码](<../JobsByPods/JobsByUIKit@Pods/>) | 0.0.1 |
| JobsByWebKit@Pods | [本地源码](<../JobsByPods/JobsByWebKit@Pods/>) | 0.0.1 |
| JobsGetWindow@Pods | [本地源码](<../JobsByPods/JobsGetWindow@Pods/>) | 0.1.14 |
| JobsImageTools@Pods | [本地源码](<../JobsByPods/JobsImageTools@Pods/>) | 0.1.14 |
| JobsInheritance@Pods | [本地源码](<../JobsByPods/JobsInheritance@Pods/>) | 0.0.1 |
| JobsNavBar@Pods | [本地源码](<../JobsByPods/JobsNavBar@Pods/>) | 0.1.14 |
| JobsNetworking@Pods | [本地源码](<../JobsByPods/JobsNetworking@Pods/>) | 1.0.1 |
| JobsScale@Pods | [本地源码](<../JobsByPods/JobsScale@Pods/>) | 0.1.14 |
| JobsSwiftBaseDefines@Pods | [本地源码](<../JobsByPods/JobsSwiftBaseDefines@Pods/>) | 0.1.6 |
| JobsSwiftBlock@Pods | [本地源码](<../JobsByPods/JobsSwiftBlock@Pods/>) | 0.1.0 |
| JobsSwiftDSL@Pods | [本地源码](<../JobsByPods/JobsSwiftDSL@Pods/>) | 0.1.0 |
| JobsSwiftDebugTools@Pods | [本地源码](<../JobsByPods/JobsSwiftDebugTools@Pods/>) | 0.0.1 |
| JobsSwiftFoundation@Pods | [本地源码](<../JobsByPods/JobsSwiftFoundation@Pods/>) | 0.1.1 |
| JobsSwiftStandardLibrary@Pods | [本地源码](<../JobsByPods/JobsSwiftStandardLibrary@Pods/>) | 0.0.1 |
| JobsSwiftTimer@Pods | [本地源码](<../JobsByPods/JobsSwiftTimer@Pods/>) | 0.1.0 |
| JobsTextTools@Pods | [本地源码](<../JobsByPods/JobsTextTools@Pods/>) | 0.1.14 |
| JobsToast@Pods | [本地源码](<../JobsByPods/JobsToast@Pods/>) | 0.1.14 |
| JobsViewPush@Pods | [本地源码](<../JobsByPods/JobsViewPush@Pods/>) | 0.0.1 |
| Jobsl10n@Pods | [本地源码](<../JobsByPods/Jobsl10n@Pods/>) | 0.1.14 |

- 维护与来源：沿用现有模块、包内文件头和许可证；具体公开与私有权限不由目录名推断。
- 引用方式：App 的 Podfile.deps 逐条相对引用本目录的兄弟 JobsByPods，不要求拷贝开发机 SDK。
- 公共依赖：Xcode、Ruby、CocoaPods 及公共包由目标机器准备，版本约束继续保存在声明和锁文件。标准工具必需的生成沙盒仅为本机工作缓存，不作为源码附件分发。
- 本轮只整理工程和引用，模块正文保持原字节。

<a id="🔚" href="#前言">返回前言</a>
