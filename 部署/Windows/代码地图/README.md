# <span id="前言">Windows 部署代码地图</span>

![Jobs出品，必属精品](../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、真实入口](#jobs-toc-heading-1)
- [二、生命周期与边界](#jobs-toc-heading-2)
- [三、部署原点与恢复边界](#undo-origin)

</details>
<!-- jobs-toc:end -->

---

> 按当前系统入口定位，不复制其它系统业务实现。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、真实入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 文件 | 定位符号与职责 |
| --- | --- |
| [【Windows】双击部署（快捷入口）.cmd](<../【Windows】双击部署（快捷入口）.cmd>) | 本系统唯一部署快捷入口；只定位并调用 Deployment 内规范实现，复用自述与确认 |
| [【Windows】双击反部署（快捷入口）.cmd](<../【Windows】双击反部署（快捷入口）.cmd>) | 独立反部署快捷入口；只定位并调用 Undeployment 内配对实现，保留原点核验、备份默认／清零选择与确认 |
| [【Windows】部署.ps1](<../Deployment/【Windows】部署.ps1/【Windows】部署.ps1>) | Invoke-RepairDeployment、Initialize-StoragePaths、Ensure-DeploymentTool、Set-WorkbenchEnvironment、Build-AccessQr、Show-AccessQr、Expire-AccessQr、Start-BrowserMenu、Complete-BrowserMenu、Watch-Deployment、Clear-OwnedDeployment |
| [【Windows】部署.cmd](<../Deployment/【Windows】部署.cmd/【Windows】部署.cmd>) | PowerShell 转发；复用真实部署入口自述 |
| [【Windows】反部署.ps1](<../Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1>) | Read-UndoReceipt、Assert-UndoReceipt、Stop-RecordedProcesses、Invoke-UndoSelection、Backup-UndoData、Assert-NoActiveDataWriter、Clear-UndoData、Assert-UndoDataRetired、Get-UndoArtifactRestoreState、Restore-UndoArtifacts、Complete-UndoOperation |
| [反部署隔离验证](../../../测试/部署/Windows/【Windows】验证反部署.ps1/README.md) | 临时工程验证备份、清零、原子隔离、产物暂存恢复故障续跑、收据与路径边界；不修改当前运行实例 |

`Initialize-DependencyResolver`、`Get-OfficialDependencyAsset`、`Resolve-LatestDeploymentTool` 负责官方latest稳定版与显式／PATH／多缓存择新；`Save-VerifiedDownload` 只对网络故障退避。`New-ModuleManifestCopy`、`Get-ModuleBuildEnvironment`、`Test-BusinessModuleUpdates` 使用本轮 `module.mod/module.sum` 报告业务更新，只有查询未完成可按原锁继续，源码／路径校验失败停止。原生进程仍由本轮Job Object管理。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、生命周期与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

平台目录分别提供“部署”和“反部署”两种独立快捷入口，只转交 `Deployment/` 与 `Undeployment/` 中各自唯一的规范实现；反部署复用原点核验、数据备份默认／清零选择及危险确认。部署入口先展示自述并确认，再用 fzf 选择本地穿透或服务器模式；只读检查／计划不下载、不创建文件、不启动业务。菜单／解析器可按静态锁引导；选定模式后通过官方稳定发行版元数据核对平台、版本和摘要，只有版本达标且功能健康才复用；公共 SDK 与 Go 缓存位于机器环境，业务运行资料位于本项目独立用户目录。

健康检查使用后端合同 `/api/v38/healthz`。网页菜单以继承控制台的fzf子进程加入本次Job Object，显示公网／本机地址，回车调用默认浏览器并继续选择；Esc收起保留服务，回车重开。菜单等待期间继续监控后端和隧道；本次服务退出或Ctrl+C时统一回收菜单与服务，浏览器打开失败允许重选。

确认、邮箱门禁、PUBLIC 明确授权、端口归属、本次子进程清理及保留数据的行为沿用现有实现。`Undeployment/` 的配对脚本读取首次原点，默认备份验证后清理源数据，再恢复旧产物并撤回新SDK／依赖。完整命令、取消、失败及验收边界以就近README为准。完整版本策略见[工具更新与业务依赖检查](../../README.md#tool-updates)。

入口与操作见 [系统说明](../README.md)，通用路径见 [环境说明](../../README.md#machine-environment)。


## 三、<span id="undo-origin">部署原点与恢复边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

两入口通过 `Find-RepairProjectRoot` 从自身逐级定位完整工程。`Initialize-DeploymentReceipt`、`Register-DeploymentArtifact` 与 `Save-DeploymentConfiguration` 在写入前保存首次原点；程序和新工具落在单会话Runtime与本项目机器缓存，公共已有SDK只复用。退出时先封存产物摘要再释放独占锁，封存失败仍回收锁句柄。

反部署先验证收据的规范路径、配置与进程身份，停进程后取得同一部署锁并重读原点；外置备份覆盖数据、密钥和应用CLI快照，摘要通过才清源。文件数据在保护句柄下同卷隔离后只清理隔离对象，TiDB清零引用已验证快照；备份后内容变化或旧路径重建均保留并拒绝自动重删。产物先暂存原件再原子换回，进度保存数据阶段、隔离位置与逐项恢复状态，部分恢复可在相同策略下重试；越界、原副本损坏及用户后续改动均保留并拒绝盲目恢复。

本单元地图直接由本README承载，不复制其它端源码或创建根层混合索引。Windows原生ACL／文件共享及重命名／Job Object、PowerShell5.1、真实数据库及公网业务分别验收。

访问地址由[共用离线二维码工具](../../公共组件/地址二维码/README.md)生成，用户／工程师工作台与管理端分别编码。终端不足宽度时菜单打开HTML；回环明确仅本机。地址变化与退出先使旧页失效；产物属于本次session，按原点清单封存并由配对反部署回收。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
