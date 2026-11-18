# WindowsOS 原生桌面端构建入口

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

使用目标机器.NET 10或以上SDK发布WPF客户端；只写本工程obj／bin／Dist和公共NuGet缓存。自述后回车确认，其它输入或Ctrl+C取消；不安装SDK、不修改系统服务或执行策略。

## 一、<span id="usage">执行与产物</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

同目录 `【Windows】构建桌面端.cmd` 可双击转交系统PowerShell；执行策略由本人机器管理，脚本不绕过或改写。

```powershell
& './【Windows】构建桌面端.ps1'
```

脚本按自身位置找到本工程 `RepairDesktop.csproj`，发布 `Dist/win-x64/RepairDesktop.exe` 和同级Resources，运行时自含，无需Python。首次构建需联网下载官方NuGet包，构建失败打印系统临时目录 `RepairDesktop-build.log` 并返回失败。完整复制发布目录；只拎出exe会缺少本地资源。

签名与目标系统实测边界见 [原生端说明](../../README.md)。本机交叉发布成功不代表Windows已经完成真实运行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
