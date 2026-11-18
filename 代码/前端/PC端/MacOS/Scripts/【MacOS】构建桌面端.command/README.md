# MacOS 原生桌面端构建入口

![啄木鸟维修平台](../../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、执行与产物](#usage)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本入口使用本机Xcode命令行工具编译SwiftUI客户端和同仓自有Foundation业务源码，生成Apple Silicon／Intel通用App并做ad-hoc签名。只写本工程Dist和系统临时编译／日志目录；不安装依赖、不启动服务、不修改系统配置。

## 一、<span id="usage">执行与产物</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

双击同目录 `【MacOS】构建桌面端.command` 或运行：

```shell
/bin/zsh './【MacOS】构建桌面端.command'
```

自述后回车执行，其它输入取消，Ctrl+C中止。路径基于脚本位置解析，可从任意工作目录执行；需要保留整个产品源码树以取得共用业务源码与本地资源。产物为本原生工程 `Dist/啄木鸟维修平台.app`。日志为系统临时目录 `RepairDesktop-build.log`；失败打印编译日志并返回非零，不宣称完成。正常退出清理本次临时架构二进制，中断可能留下本次系统临时目录。

成品Resources内的 `SourceManifest.sha256` 按本Mac工程相对路径记录参与编译源码及Info；`ResourceManifest.sha256` 记录包内JSON、PNG、MP4与Unicode许可；密码范围数据与许可一并打包。本地合成三张工单的设备图／检视视频和`media-seed.json`随App打包，详情不依赖网络取得这些演示原件。源码和资源摘要可分别从工程目录、成品Resources目录核验，不包含开发机绝对路径。

构建与运行范围见 [原生端说明](../../README.md)，签名不等于Developer ID认证、公证或跨机验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
