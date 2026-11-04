# <span id="前言">Ubuntu 配对反部署</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口与交互](#run)
- [二、业务数据处理](#data-policy)
- [三、原点、冲突与日志](#ownership)
- [四、验证与边界](#verification)

</details>
<!-- jobs-toc:end -->

---

> 配对反部署从首次部署保存的原点清单核验归属。已登记的后端、隧道与菜单按PID、启动时间及完整命令匹配后停止；本项目新增的程序、SDK、依赖和构建缓存撤回，原有程序／专属环境恢复原件。复用的共享SDK与其它项目始终保留。

## 一、<span id="run">入口与交互</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录打开终端执行：

```shell
/bin/bash './【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh'
/bin/bash './【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh' --plan
/bin/bash './【Linux】反部署维修工作台.sh/【Linux】反部署维修工作台.sh' --check
```

- 普通入口先阅读自述并按回车；fzf默认选择“数据库／文件数据备份”，也可选择“清零”或取消。第二层执行确认默认取消；清零还须按空格后回车。Esc、空选和选择器异常不进入删除。
- 反部署复用已有fzf，按 `WB_FZF_BIN`、PATH、本项目专属工具及既有共享缓存发现；不会为了删除再安装SDK。缺少选择器时停止并说明如何指定现有工具。
- `--check`／`--plan` 不下载、不创建缓存或日志、不停止进程、不读写数据库；没有原点清单时明确显示保留旧环境。

## 二、<span id="data-policy">业务数据处理</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

默认备份模式把当前文件数据、附件／签名聚合快照、匹配密钥和私有部署配置复制到 Runtime 外的独立操作目录，逐项核验内容后才清理当前应用数据。文件快照存在时，还须用原程序的 `-backup` 成功解密并生成有效加密聚合备份与SHA256清单；缺少原程序、密钥不匹配或校验失败均拒绝清理。备份目录与密钥应按敏感业务资料保管。

TiDB 使用原程序的 `-backup` 生成加密应用聚合备份及摘要清单，校验SHA256并配对保存原密钥；成功后通过 `-clear-storage -confirm-clear-storage` 清零本应用 `v38_workbench_snapshot` 的 `id=1`。备份模式同时传入 `-clear-storage-backup` 绑定已验证备份；备份后出现新业务内容时拒绝清零，保留新数据。清零使用事务行锁、解密与版本条件；不删除数据库、表结构、权限、其它行或其它服务。应用聚合备份不能代替数据库完整灾备。数据库连接、备份、摘要或清零失败时停止后续移除。

“清零”模式不创建当前业务数据备份，明确确认后清理同一应用范围。两种模式均保留部署前原程序／专属依赖恢复副本；备份模式先归档当前业务数据，清零模式按明确选择舍弃当前业务数据。不能把清零当成恢复旧业务数据或自动重置外部数据库服务。

## 三、<span id="ownership">原点、冲突与日志</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

首次原点清单保存在项目独立 Runtime 的 `deploy-state/`，记录原程序／专属环境副本、当前指纹、数据与密钥位置、进程身份及私有数据库连接配置；权限只面向当前用户，不写入普通日志。重复部署复用首轮原点，配置变化时拒绝覆盖旧清单。部署与反部署通过同一个操作锁串行化。

缺失清单的旧部署、PID复用、权限不明、运行中的写入者、软链接、超出项目范围的目标、原件备份损坏、部署后人工修改、未封存会话摘要或未知新增内容均会保留现场并停止。旧部署没有记录安装前状态时，脚本不会推测哪些共享SDK可以删除；应先核对旧资料与环境归属。当前操作锁残留时先核对原运行终端及状态，不删除锁强行绕过。

备份／审计根默认是本项目 Runtime 同级的 `UndeploymentBackups/`，每次使用独立 `repair-undeploy.*` 目录。备份根与显式外置数据、密钥也必须互不包含，防止复制进待删范围或递归自复制。可通过 `WB_UNDEPLOY_BACKUP_DIR` 指定位于Runtime、专属环境和项目源码之外的绝对路径。`WB_RUNTIME_DIR`／`WB_ENV_ROOT` 必须与原部署一致；日志在独立操作目录的 `operation.log`。失败保留状态、原件及已完成备份，不输出恢复成功。部署前不存在的父目录有独立清单，只尝试回收这些当前为空的目录；原有空目录、用户后来新增内容及已生成的外置备份／审计目录保留。数据阶段、外置操作目录与逐项原件恢复均有检查点；已核验恢复原点的对象续跑时跳过，中途恢复失败可在相同数据选择下重试，不重复备份已处理的数据或重新清零。

## 四、<span id="verification">验证与边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[隔离回归](../../../../测试/部署/反部署/验证反部署.mjs/README.md)覆盖原件恢复、新增依赖撤回、数据及密钥备份、清零、指纹冲突、备份失败、PID复用、软链接、取消和并发锁；只在临时目录执行。真实目标系统、TiDB、断电、公网、用户自建服务和付费订阅分别验收。

本入口不撤销用户自行配置的DNS、域名预留、订阅或系统服务；原部署未安装这些对象。手工隧道撤回及常驻项处理仍见[本系统停止说明](../README.md#local-tunnel)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
