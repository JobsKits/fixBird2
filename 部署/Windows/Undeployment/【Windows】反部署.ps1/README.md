# Windows 配对反部署脚本

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与菜单](#usage)
- [二、原点与资源边界](#origin)
- [三、备份、清零与配置](#data)
- [四、验证与故障处理](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本入口与[Windows 部署脚本](../../Deployment/【Windows】部署.ps1/README.md)配对，依据首次部署原点停止本项目进程、处理当前业务数据、恢复已有程序及依赖，并撤回本次新增的专属 SDK 与缓存。需要 [**Windows PowerShell**](https://learn.microsoft.com/powershell/) 5.1 或更新版本和已有 [**fzf**](https://formulae.brew.sh/formula/fzf)。普通停止仍在部署终端按 `Ctrl+C`，与反部署的数据处理分开。

## 一、<span id="usage">运行与菜单</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从本 README 所在目录打开 PowerShell：

```powershell
& './【Windows】反部署.ps1' -Check
& './【Windows】反部署.ps1' -Plan
& './【Windows】反部署.ps1'
```

`-Check` 与 `-Plan` 只读发现项目、运行目录及原点清单，不下载依赖、写日志、停止进程或处理数据，两者不能同时使用。正常入口显示内置说明，回车进入菜单；没有交互终端时拒绝执行。脚本从自身位置发现完整项目，不依赖终端当前目录。

- fzf 默认选择“数据库／文件数据备份”：备份全部当前业务、附件、签名、匹配密钥及必要恢复配置，通过摘要及应用解密验证后清理源数据。
- 可选择“数据库／文件数据清零”：不生成本次业务备份，处理明确列出的应用数据与匹配密钥，保留原点审计。
- 展示 Runtime、专属缓存、数据及密钥的实际范围后，执行菜单默认取消；明确选择执行后还需按空格复核。Esc、空选、其它确认键及选择器失败不执行删除。
- 反部署不重新下载 fzf；可以通过当前进程的 `WB_FZF_BIN` 指定已有工具。

## 二、<span id="origin">原点与资源边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

部署首次写入前保存 `Runtime/deploy-state-Windows/receipt.json` 和原件副本，重复部署沿用原点。记录必要数据配置、程序路径、资源摘要、进程创建时间和实际可执行文件；私有目录以当前账户 ACL 保护，不输出数据库连接值。

反部署先核验进程身份，再停止清单内的本项目后端及隧道，取得与部署共用的独占锁，并在锁内重新校验原点及全部产物。PID 复用、路径穿越、符号链接／重解析点、数据与产物重叠、摘要冲突或原件副本损坏时停止并保留现场。

已有程序及被覆盖的专属环境先在同目录暂存并校验原件，再隔离当前产物、原子换回原件；逐项恢复阶段及临时对象摘要记入原点，复制或移动中断可核验后继续，未知改动保留并拒绝覆盖。本次新增程序、下载暂存、依赖与 SDK 仅从机器环境 `Projects/RepairWorkbench/<项目标识>/` 的专属范围撤回。系统 PATH、显式工具及部署前已存在的共享 SDK 不按名称卸载，不停止其它项目或数据库服务。

备份与数据处理、逐项恢复保存检查点；中断后须保持原配置及原数据策略继续，已完成的数据清理不会因重试重新依赖被撤回的程序。缺少历史原点的旧部署保留未知资源并报告；不能重建未经记录的安装前状态，也不能将部分完成称为已还原。

明确确认后在私有原点内保留已核验的 fzf 副本，供已撤回 SDK 后的中断重试继续选择；反部署成功后随活动原点一并移除。

## 三、<span id="data">备份、清零与配置</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 当前进程参数 | 作用 |
| --- | --- |
| `WB_RUNTIME_DIR` | 指定原部署 Runtime；缺省按当前账户的系统资料目录解析 |
| `WB_ENV_ROOT` | 指定原部署机器环境根，必须与原点记录相符 |
| `WB_FZF_BIN` | 指定已有 fzf 可执行文件；未指定时发现 PATH 或专属缓存中的工具 |
| `WB_UNDEPLOY_BACKUP_DIR` | 指定独立备份位置；缺省为 Runtime 外同级 `UndeploymentBackups/`，不能位于待清理目标内 |

备份包含现行业务副本、原始匹配密钥、应用 `.wbbak` 及其摘要和私有部署原点；原数据或密钥在备份期间变化、应用不能解密或摘要不匹配时不清理。备份含敏感恢复资料，应限制权限并迁往合适的独立介质。

文件清理先拒绝仍活跃的 `writer.lock`，持有 `.writer.guard` 与匹配密钥句柄后复核备份，先隔离独立密钥，再把数据目录原子移到同父目录的私有隔离位置；只删除已登记且摘要相符的隔离对象。隔离对象完整时中断可沿清单继续，不重新创建旧数据路径；若系统只删除部分隔离数据后报错，摘要改变会保留剩余对象并停止，须人工核对，不自动扩大删除。清理期间或之后新出现的原数据／密钥路径会保留并报冲突，原生 Windows 共享与重命名语义仍须目标机验证。

已确认的备份后出现新业务内容时，源数据与旧备份都保留，脚本不会自动重新备份或重试清零。先停止并核清其它写入者，再显式完成新的备份与处理；不要删除活动原点绕过冲突。

可选 TiDB 使用原存储配置执行应用备份，验证后通过 `-clear-storage -confirm-clear-storage` 精确处理 `v38_workbench_snapshot` 中的 `id=1`。默认备份策略额外使用 `-clear-storage-backup` 关联已验证的备份；若最新业务内容或读取版本不匹配，保留源数据并停止。不删除数据库、表结构、其它记录、账号权限或服务；应用聚合备份不等于数据库完整灾备。所有该应用写入者必须先停止，真实数据库及独立介质恢复仍需验收。

自行配置的系统服务、命名 Tunnel、cpolar、DNS、域名预留、订阅及电源设置不由本部署入口创建，按其原始记录另行撤回。完整操作见[系统反部署说明](../README.md)与[总部署说明](../../../README.md#undeployment)。

## 四、<span id="validation">验证与故障处理</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[隔离回归入口](../../../../测试/部署/Windows/【Windows】验证反部署.ps1/README.md)使用临时工程、合成数据和权限／存储替身验证恢复行为，不操作现有 Runtime。语法与跨宿主 PowerShell 验证不能替代 Windows 原生 ACL、文件共享／重命名、Job Object、已安装 SDK、真实 TiDB 及目标机反部署验收。

发生错误时保留活动原点、外置备份和阶段信息，先核对提示范围；不要删除清单、写锁或覆盖恢复副本来绕过拒绝。共享资源或后续人工修改被保留时，逐项处理差异再继续。



<!-- JOBS_TERMINAL_STYLE_V1:BEGIN -->

> Windows 终端配色保护：支持完整颜色查询的交互控制台会先保存当前会话默认前景、背景与16色色表，再临时使用黑底白字和统一强调色；正常结束、业务失败及可捕获中断后恢复。用户运行中自行改动的颜色保留并提示，不修改用户主题、共享 Profile、注册表或全局策略。快照不包含进入前任意叠加的临时文字样式。非控制台、重定向、`NO_COLOR`、Sourcetree 及无法可靠保存／恢复颜色的环境保持原状态或降级为纯文本。

> 强制结束进程或终端崩溃无法保证自动恢复。恢复失败时保留并提示本轮 `%TEMP%\JobsTerminalStyle-<PID>-*.ps1` 恢复脚本，需在原控制台核对后运行；不要通过重置用户配置恢复。`-ExecutionPolicy Bypass` 如被入口使用，仅作用于本次子进程，不持久修改策略。

> 验证范围：已完成 PowerShell 语法、参数／退出与隔离生命周期核验；Windows 原生控制台的显示、按键与 `Ctrl+C` 实机验证尚未完成。

<!-- JOBS_TERMINAL_STYLE_V1:END -->

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
