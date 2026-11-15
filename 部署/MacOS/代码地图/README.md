# <span id="前言">MacOS 部署代码地图</span>

![Jobs出品，必属精品](../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、真实入口](#jobs-toc-heading-1)
- [二、生命周期与边界](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

> 按当前系统入口定位，不复制其它系统业务实现。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、真实入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 文件 | 定位符号与职责 |
| --- | --- |
| [【MacOS】双击部署（快捷入口）.command](<../【MacOS】双击部署（快捷入口）.command>) | 本系统唯一部署快捷入口；只定位并调用 Deployment 内规范实现，复用自述与确认 |
| [【MacOS】双击反部署（快捷入口）.command](<../【MacOS】双击反部署（快捷入口）.command>) | 独立反部署快捷入口；只定位并调用 Undeployment 内配对实现，保留原点核验、备份默认／清零选择与确认 |
| [【MacOS】启动维修工作台.command](<../Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command>) | main、resolve_machine_paths、install_cached_tool、configure_paths、configure_go_module_source、build_workbench；deploy_state_begin_selected、deploy_state_acquire_handoff、deploy_state_handoff_previous、deploy_state_start_guardian 负责停旧接管与会话守护；run_session_child、wait_session_child_ready 负责子会话身份登记、启动屏障及回收；prepare_access_qr、show_access_qr、expire_access_qr、start_browser_menu、handle_browser_menu_result、monitor_processes 负责访问、扫码与持续监测 |
| [【MacOS】反部署维修工作台.command](<../Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command>) | 原点清单、PID身份、备份／清零、资源指纹与原件恢复 |

`prepare_dependency_resolver`、`resolve_latest_asset`、`resolve_latest_tool`、`tool_version`、`tool_at_least` 负责官方latest稳定版与多缓存语义择新；`download_verified` 对临时网络错误持续退避。`run_dependency_command`、`dependency_command_worker`、`cleanup_dependency_commands` 管理本轮短作业及取消回收。`prepare_module_copy`、`check_business_dependencies`、`check_module_updates` 通过外部 `module.mod/module.sum` 报告业务更新，构建保留readonly；`configure_go_module_source` 保留显式模块源与私库策略。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、生命周期与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

平台目录分别提供“部署”和“反部署”两种独立快捷入口，只转交 `Deployment/` 与 `Undeployment/` 中各自唯一的规范实现；反部署复用原点核验、数据备份默认／清零选择及危险确认。部署入口先展示自述并回车，再用 [**fzf**](https://github.com/junegunn/fzf) 的 `↑`／`↓` 与回车选择本地穿透或服务器模式，`Esc` 取消。本地直接采用公开演示，再按回车确认公开，不收邮箱或要求输入 `PUBLIC`；取消在接管前保留旧实例。此调整仅适用于 MacOS，其他平台保留各自访问流程。只读检查／计划不下载、不创建文件、不启动业务。菜单／解析器可按静态锁引导；选定模式后通过官方稳定发行版元数据核对平台、版本和摘要，只有版本达标且功能健康才复用；公共 SDK 与 Go 缓存位于机器环境，业务运行资料位于本项目独立用户目录。

构建子进程在未自定义 GOPROXY 时使用国内镜像、官方镜像和源码直取的网络错误回退链；显式环境及 Go 用户配置保留，校验策略不变。构建输出同步终端与日志，失败不替换旧产物且停止启动。对应[隔离构建回归](../../../测试/部署/MacOS/【MacOS】验证工作台构建.command/README.md)不连接公网或业务实例。

`prepare_fzf` 在模式选择前只读复用健康工具，缺失时将已校验选择器放入本次会话的 `RUN_DIR/bootstrap-environment`，不提前写入旧部署专属缓存；临时资源随本次 session 登记。`deploy_state_acquire_handoff`／`deploy_state_release_handoff` 串行化接管，`deploy_state_handoff_previous` 通过 `deploy_state_same_process`／`deploy_state_stop_identity` 核对并停止旧实例，`deploy_state_begin_selected` 在确认后编排交接，`deploy_state_start_guardian` 建立独立会话守护。

`run_session_child` 在实际后端、隧道和菜单启动前由监督子进程自行登记身份，`wait_session_child_ready` 等待与本轮 PID 匹配的启动屏障；父入口在登记间隙退出时，独立守护仍能按记录找到监督子进程并回收其直接子进程。

本次公网地址就绪后，后台fzf列出公网／本机入口，选择后调用默认浏览器并再次显示菜单；服务器模式列本机入口及二维码页面，回环码明确仅本机。Esc仅收起菜单，回车重新打开；Ctrl+C及本次后端／隧道退出时统一回收菜单和服务子进程。浏览器打开失败允许重选，不中断服务；隔离回归同时验证菜单选择与进程生命周期。

回环健康检查与后端合同一致，使用 `/api/v38/healthz`。模式及本地公开确认完成后，先核对登记的项目归属、PID、启动时间与命令行，再停止本项目旧部署，等待退出封存、解锁及端口释放后启动新一轮；反部署作业、未知归属或身份冲突保留并报告，不按名称或端口停止其他服务。退出清理与独立会话守护覆盖 `HUP`、入口或终端父进程异常结束，按本轮身份回收后端、隧道和菜单，标记二维码失效并释放本轮锁，保留数据、密钥、配置及首轮原点；只读检查与接管前取消保留旧实例，接管后的失败不承诺恢复旧进程。

`Undeployment/` 提供与部署配对的反部署脚本，按原点清单核验资源。配对反部署复用首次原点；本项目专属依赖可撤回，已有共享 SDK 保留。数据默认备份并核验，清零需明确选择与复核；冲突和失败保留现场。正式隔离入口见[反部署回归](../../../测试/部署/反部署/验证反部署.mjs/README.md)。

完整版本策略见[工具更新与业务依赖检查](../../README.md#tool-updates)。

入口与操作见 [系统说明](../README.md)，通用路径见 [环境说明](../../README.md#machine-environment)。


访问地址由[共用离线二维码工具](../../公共组件/地址二维码/README.md)生成，前端用户／工程师工作台 `/` 与后台管理网页 `/admin/` 分别编码为两张二维码，与对应完整 URL 一致。终端不足宽度时菜单打开 HTML；回环明确仅本机。地址变化与退出先使旧页失效；产物属于本次 session，按原点清单封存并由配对反部署回收。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
