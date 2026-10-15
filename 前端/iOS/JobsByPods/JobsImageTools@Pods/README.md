# `JobsImageTools`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

# <span id="前言">`JobsImageTools`</span>

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

分开处理简单图片加载、Kingfisher/SDWebImage 缓存清理，以及对现有 UIKit 视图树的图片刷新。核心不是重新实现图片框架，而是记录与协调实际加载来源。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

记录控件图片来源及加载器 → 发起图片加载 → 按需清理缓存 → 遍历已记录来源的控件重新请求

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 同时存在两种图片框架时，应按每个控件记录的 jobs_imageLoaderKind 选择刷新方式，不能通过编译分支只处理其中一种。
- 强制重新下载依赖控件记录的远程地址，无法从任意 UIImage 反推出原始 URL。
- 缓存删除与屏幕上已显示图片更新是两件事；UIImageView、按钮前景图和背景图需要分别处理。
- UI 树遍历与控件更新遵循主线程要求，下载与磁盘缓存的完成时机应通过回调衔接。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 JobsSimpleImageLoader，再看 JobsImageCacheCleaner，最后读 ByUIKit 中如何找控件和恢复加载。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsImageCacheCleaner.swift](<./JobsImageCacheCleaner.swift>)
- [JobsSimpleImageLoader.swift](<./JobsSimpleImageLoader.swift>)
- [JobsImageCacheCleanerByUIKit.swift](<./JobsImageCacheCleanerByUIKit.swift>)

依赖与编译入口：[JobsImageTools.podspec](<./JobsImageTools.podspec>)。其中显式依赖声明包括 `Kingfisher`、`SDWebImage`、`JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 二、运行合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

加载令牌 `cancel()` 可重复调用；取消会以 `.cancelled` 结束尚未交付的结果。缓存命中、网络完成和取消竞争时只交付一次，交付在主线程。URLSession 回退请求默认 15 秒，只接受 HTTP 2xx 和不超过 32 MiB 的下载数据；使用 ImageIO 缩略图，最长边不超过 4096 像素，单图解码预算 64 MiB。第三方加载器继续使用各自缓存和处理器。

回退内存缓存按 URL、目标尺寸和 scale 区分，成本按解码字节计算；URLSession 回退的 `cachedImage(for:)` 只查询默认规格，不能把小缩略图当作原规格返回。尺寸和 scale 必须有限且大于零，非法输入使用默认规格。`jobs_remoteURL` / `jobs_bgURL` 每次赋值会记录新的绑定代次，强制重载手动完成回填须同时匹配 URL 和代次，复用同 URL 也不会接受旧回调。自定义加载器需在每次重新绑定控件时更新这两个 URL 入口。


## 三、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

本次没有为未使用所需理由 API 的模块机械添加空隐私清单；业务用途变化后再按实际调用核对。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods JobsImageTools --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
