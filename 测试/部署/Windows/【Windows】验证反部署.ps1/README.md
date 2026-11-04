# Windows 配对反部署隔离回归

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行](#run)
- [二、覆盖范围](#coverage)
- [三、验收边界](#limits)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

验证[部署脚本](../../../../部署/Windows/Deployment/【Windows】部署.ps1/README.md)与[反部署脚本](../../../../部署/Windows/Undeployment/【Windows】反部署.ps1/README.md)的首次原点、数据处理和恢复行为。全部对象来自测试创建的临时完整工程，不下载工具，不连接真实数据库，不读取或删除日常 Runtime。

## 一、<span id="run">运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本 README 所在目录，使用已有 [**PowerShell**](https://learn.microsoft.com/powershell/)：

```powershell
pwsh -NoProfile -File './【Windows】验证反部署.ps1'
```

Windows PowerShell 5.1 可用 `powershell.exe` 替代 `pwsh`。不需要安装模块或修改执行策略；目标机器若拒绝执行脚本，先按本机既定策略核验文件与授权，不由测试自动放宽全局策略。

成功输出 JSON 断言总数与宿主／替身验证范围；任何断言失败返回非零结果。测试结束恢复进程环境并清理自身临时目录，错误输出保留失败断言位置。不要把真实路径填入测试夹具，也不要用真实反部署代替回归。

## 二、<span id="coverage">覆盖范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 包装脚本从无关工作目录发现带中文和空格的完整工程，不猜测固定父级层数。
- 首次部署记录原点；默认备份、数据及匹配密钥成对保留，验证后清理源数据，撤回新增 SDK 与 Runtime。
- 已有专属工具与原件恢复，共享资源保留；旧数据也按明确选择处理。
- 备份失败、摘要不一致、损坏或越界的原点、PID 身份变化与部署锁冲突拒绝危险清理。
- 数据阶段及产物恢复中断后继续处理，避免重复清零或依赖已撤回的程序；重复运行与取消路径保留清楚结果。
- 活跃文件写入者拒绝、备份后数据变化保留、数据及密钥同卷隔离、旧路径被重建后保留；已确认快照变化不会自动补备份或重删。
- 原件暂存复制失败、两次移动后检查点写入失败、隔离产物部分删除失败均可续跑；暂存对象被改或新原路径出现时保留并拒绝覆盖。
- TiDB 默认清零携带已验证备份引用，明确清零不附引用；当前进程的 Go 缓存含 GOPATH，父环境保持原值。
- 部署收尾异常释放锁，原点及恢复依据继续可读。

## 三、<span id="limits">验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

跨宿主执行替换 Windows ACL、原生服务过程和存储 CLI；假 CLI 只验证参数、备份／清零顺序、失败传播与恢复阶段。真实加密与数据库事务另由[后端测试](../../../后端/README.md)核验，TiDB 事务桩不代表实际数据库已验收。

Windows 原生 ACL、文件共享／原子重命名、Job Object、PE 工具、控制台 fzf 交互、真实数据库及独立备份介质仍需在目标机器按[分级验收](../../../测试与分级验收/测试与分级验收.md)分别执行。测试通过不能推定正式生产退役或完整灾备通过。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
