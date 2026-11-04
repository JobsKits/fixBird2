# [**Windows**](https://www.microsoft.com/windows) 停止与反部署

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与只读审阅](#entry)
- [二、数据备份、清零与原点恢复](#retain)
- [三、失败、中断与验证边界](#resume)
- [四、本地部署＋内网穿透的停止与撤回](#local-tunnel)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录提供与部署入口配对的可执行反部署脚本。只处理记录在当前项目原点内的资源；普通停止、公网撤回和完整反部署分别选择，未知历史部署不猜测归属。

在上一级系统目录双击 [【Windows】双击反部署（快捷入口）.cmd](../【Windows】双击反部署（快捷入口）.cmd)，只转交本目录内唯一的配对反部署实现，复用原有自述、原点核验、数据备份默认／清零选择和危险确认。另一个 [【Windows】双击部署（快捷入口）.cmd](../【Windows】双击部署（快捷入口）.cmd) 用于部署；按名称选择，两个入口不互相替代。

## 一、<span id="entry">运行与只读审阅</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录的 PowerShell 终端执行，完整参数及前置条件见[反部署脚本说明](./【Windows】反部署.ps1/README.md)：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\【Windows】反部署.ps1\【Windows】反部署.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\【Windows】反部署.ps1\【Windows】反部署.ps1" -Check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\【Windows】反部署.ps1\【Windows】反部署.ps1" -Plan
```

实际入口先回车进入 fzf，数据默认“备份验证后清理源数据”；执行确认默认取消，选执行后按空格复核。取消、空选或选择器失败不执行逆操作。`-Check/-Plan` 只读发现原点，不运行工具、下载、停止服务或创建文件。

## 二、<span id="retain">数据备份、清零与原点恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

默认备份当前业务数据、附件、匹配密钥、配置与应用聚合备份，逐文件和摘要校验通过后清理源数据；“清零”不生成业务备份，须经上述明确确认。备份保存在 Runtime 外，`WB_UNDEPLOY_BACKUP_DIR` 可显式指定互不重叠的位置。TiDB 只清理本应用聚合记录，不 drop 数据库或改变其它项目；默认清零附已验证备份引用，当前内容与该快照不符时保留源并停止。文件数据先核对写入者与备份，在持有保护句柄期间把数据／密钥移入同卷隔离位置，只删除已登记的隔离对象。

部署前的程序与专属缓存有原副本和摘要，反部署按原点撤回新建SDK／依赖并还原已有产物；系统及公共已有工具不在清理清单内。活动收据限制当前账户读取，连接配置不输出日志。进程按PID、创建时间和实际程序路径核验；取得部署独占锁后重新验证原点。摘要改变、链接重解析、越界路径、备份失败或进程身份变化均停止并保留恢复依据。

## 三、<span id="resume">失败、中断与验证边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

备份后出现新内容或旧数据路径被重建时，源与备份均保留；不自动重新备份或清零，须先核清其它写入者。失败保留活动收据与已核验外置备份；重新运行保持相同数据策略，逐项核对后继续，不重新覆盖首次部署原点。完整恢复成功后才移除活动记录，完成标记及必要审计副本在 Runtime 外保留；重复调用不会猜测清理其它目录。没有历史原点的旧部署仅可审阅，不能把一次新扫描当成部署前证明。

[正式隔离回归](../../../测试/部署/Windows/【Windows】验证反部署.ps1/README.md)使用临时工程及替身存储CLI核对文件行为。Windows原生ACL、文件共享／原子重命名、Job Object、PowerShell5.1和真实数据库仍须分别在目标环境验收；没有执行用户现有部署的反部署。

## 四、<span id="local-tunnel">本地部署＋内网穿透的停止与撤回</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节适用于按[本系统教程](../README.md#local-tunnel)启动的双模式入口，或另行人工启用的Go＋cpolar。双模式入口在其终端按Ctrl+C会停止本次后端和本次隧道，异常退出也只清理本次PID。本节是保留业务数据的单纯停止／公网撤回路径；完整反部署另行运行上方配对入口。

- 使用双模式入口时先在该终端按 `Ctrl+C`，随后检查本地与外部新请求均已失败；以下独立客户端步骤只用于另行手工运行的隧道。先停止公网入口。cpolar前台窗口按 `Ctrl+C`，Cloudflare Quick窗口同样按 `Ctrl+C`；服务模式到本人实际客户端管理界面停用repair隧道，不按模糊进程名批量结束程序。一个cpolar进程同时托管repair和academic时，退出会使两个项目都断开；只停维修可在GUI只停repair，或明确接受另一站短暂重连后仅运行academic。

- 控制台核对维修域名不再指向在线隧道。停止连接并不自动解除固定子域名预留、删除命名Tunnel或取消付费续订；不再使用时按所选产品在本人控制台解除相应映射／预留。自有域名DNS另外撤回，保留学术项目和其它服务使用的记录；共享Tunnel只移除维修主机名，不删除整个共享Tunnel。

- 让外部手机关闭Wi-Fi，以新请求访问原维修公网 `/api/v38/healthz` 和受保护API确认失败。已经打开的页面可能仍展示缓存或本地演示回退，页面没消失不能证明连接仍在。

- 在维修Go前台窗口按 `Ctrl+C`，确认本机8098不再监听；学术8080仍需使用时保持其进程和数据不变。本机检查命令：

```powershell
Get-NetTCPConnection -LocalPort 8098 -State Listen -ErrorAction SilentlyContinue
```

未检出监听才符合停止预期；命令退出或没有显示进程信息不授权关闭其它服务。Linux没有rg时可用本机已有工具检查ss输出，不能为停止步骤强行安装开发工具。

- 若曾自行注册常驻项，另行记录并停用对应MacOS launchd、Windows服务／任务计划或Linux systemd单元，确认重启后不会自动重新公开；本任务没有安装这些单元，不照抄未知服务名执行卸载。若临时改了电源设置，按原记录恢复，不重置其它系统设置。

- 默认保留维修加密数据、匹配密钥、附件、有效配置及备份。先停止写入再备份或迁移，不在Mac／Windows两台设备上同时启动同一文件快照写入。停止／撤回公网不会擦除cpolar本机令牌；凭据泄露时在对应服务控制台撤销并重新授权，令牌不写入仓库或排查截图。

以上是停止和撤回指引，未实际停用公网隧道、取消订阅、删除DNS或执行系统服务操作；逐项完成后才记录本机与外网复查结果。

当前公共工具与运行资料寻址见[环境说明](../../README.md#machine-environment)，入口与生命周期见[本系统代码地图](../代码地图/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
