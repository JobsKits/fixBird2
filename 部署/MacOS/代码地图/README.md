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
| [【MacOS】启动维修工作台.command](<../Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command>) | main、resolve_machine_paths、install_cached_tool、configure_paths、configure_go_module_source、build_workbench、prepare_access_qr、show_access_qr、expire_access_qr、start_browser_menu、handle_browser_menu_result、monitor_processes |
| [【MacOS】反部署维修工作台.command](<../Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command>) | 原点清单、PID身份、备份／清零、资源指纹与原件恢复 |

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、生命周期与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

平台目录分别提供“部署”和“反部署”两种独立快捷入口，只转交 `Deployment/` 与 `Undeployment/` 中各自唯一的规范实现；反部署复用原点核验、数据备份默认／清零选择及危险确认。部署入口先展示自述并确认，再用 fzf 选择本地穿透或服务器模式；只读检查／计划不下载、不创建文件、不启动业务。工具按锁清单核对平台、版本和摘要，优先复用健康工具；公共 SDK 与 Go 缓存位于机器环境，业务运行资料位于本项目独立用户目录。

构建子进程在未自定义 GOPROXY 时使用国内镜像、官方镜像和源码直取的网络错误回退链；显式环境及 Go 用户配置保留，校验策略不变。构建输出同步终端与日志，失败不替换旧产物且停止启动。对应[隔离构建回归](../../../测试/部署/MacOS/【MacOS】验证工作台构建.command/README.md)不连接公网或业务实例。

本次公网地址就绪后，后台fzf列出公网／本机入口，选择后调用默认浏览器并再次显示菜单；服务器模式列本机入口及二维码页面，回环码明确仅本机。Esc仅收起菜单，回车重新打开；Ctrl+C及本次后端／隧道退出时统一回收菜单和服务子进程。浏览器打开失败允许重选，不中断服务；隔离回归同时验证菜单选择与进程生命周期。

回环健康检查与后端合同一致，使用 `/api/v38/healthz`。确认、邮箱门禁、PUBLIC 明确授权、端口归属、本次子进程清理及保留数据的行为沿用现有实现。`Undeployment/` 提供与部署配对的反部署脚本，按原点清单核验资源。配对反部署复用首次原点；本项目专属依赖可撤回，已有共享SDK保留。数据默认备份并核验，清零需明确选择与复核；冲突和失败保留现场。正式隔离入口见[反部署回归](../../../测试/部署/反部署/验证反部署.mjs/README.md)。

入口与操作见 [系统说明](../README.md)，通用路径见 [环境说明](../../README.md#machine-environment)。


访问地址由[共用离线二维码工具](../../公共组件/地址二维码/README.md)生成，用户／工程师工作台与管理端分别编码。终端不足宽度时菜单打开HTML；回环明确仅本机。地址变化与退出先使旧页失效；产物属于本次session，按原点清单封存并由配对反部署回收。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
