# 啄木鸟维修平台 · V3.8

![Jobs出品，必属精品](./代码/前端/PC端/Web/维修工作台/assets/RepairLogo.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、最快开始](#startup)
  - [1.1、本地部署＋内网穿透](#local-tunnel)
- [二、目录与端侧入口](#directory)
- [三、演示角色与功能](#demo-accounts)
- [四、连接、离线与数据](#configuration)
- [五、验证与范围](#verification)
- [六、工程维护](#maintenance)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

面向客户、调度、工程师、仓库、质检与财务的维修／配件工作平台。**先看 [零基础使用说明](./代码/README.md#usage-guide)**，无需读源码即可熟悉演示流程。本项目处于开发验证阶段，使用合成账号及样例；真实支付未接入。

本仓维护 `/api/v38` 业务。管理后台分别使用 [**Flutter**](https://flutter.dev/) 与原生 Web 技术实现；用户／工程师端提供现有 [**Swift**](https://www.swift.org/) iOS、Flutter、[**Kotlin**](https://kotlinlang.org/) Android 与 [**ArkTS**](https://developer.huawei.com/consumer/cn/arkts/) 鸿蒙工程，以及[**微信小程序**](https://developers.weixin.qq.com/miniprogram/dev/framework/)官方原生独立工程。各端源码、构建与设备验收边界见 [交付清单](./需求/交付与运维清单/交付与运维清单.md)。项目规范入口为 [项目需求与开发评审](./需求/项目需求与开发评审/项目需求与开发评审.md)。

## 一、<span id="startup">最快开始</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

1、MacOS 双击 `部署/MacOS/【MacOS】双击部署（快捷入口）.command`，阅读终端提示后按回车，保持终端打开。

2、浏览器打开 [Web 管理后台](http://127.0.0.1:8098/admin/)；[维修协同工作台](http://127.0.0.1:8098/) 继续可用。

3、选“公司负责人”，密码 `Demo-Repair-2026!`，从“新建工单”开始。用不同角色重新登录可检查职责差异。

4、停止时回到终端按 `Ctrl+C`。演示数据和密钥默认留在机器专属 `WB_RUNTIME_DIR`（MacOS 为 `$HOME/Library/Application Support/JobsSoftwareProjects/RepairWorkbench/Runtime`），不要在不备份密钥的情况下只迁移数据文件。

网页可独立演示：在本仓打开终端执行以下命令，再访问 [独立演示管理后台](http://127.0.0.1:8099/admin/)。只需已安装 [**Node.js**](https://nodejs.org/)；服务端 API 会明确返回未连接。

```sh
node './代码/前端/PC端/Web/离线预览.mjs'
```

### 1.1、<span id="local-tunnel">本地部署＋内网穿透</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

前期少量访问可复用现有电脑，无需先采购云主机。运行本系统部署入口，阅读说明并按回车后，通过 [**fzf**](https://github.com/junegunn/fzf) 选择“本地部署＋内网穿透”或“服务器部署”；方向键选择、回车确认，Esc 取消。脚本优先复用健康工具，只在缺失时准备当前模式所需工具。

1、MacOS 可双击 `部署/MacOS/【MacOS】双击部署（快捷入口）.command`；Windows 和 Linux 从[系统快捷入口索引](./部署/README.md#deployment-shortcuts)进入本系统文件夹，双击标有“部署（快捷入口）”的文件。“本地部署＋内网穿透”会构建并启动 `127.0.0.1:8098`，通过健康检查后再启动免费 [**Cloudflare Quick Tunnel**](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)，输出本次随机 HTTPS 地址。默认文件模式不要求安装 TiDB。不要把离线预览端口 `8099` 当作后端。

2、维修项目保留演示账户，本地穿透默认使用邮箱门禁；需要原生客户端直连时，按脚本提示明确选择公开的合成数据演示。每个项目使用独立域名整站转发，网页、API 和文件保持同源。与陈泉羽项目同机时，另用一条隧道指向其 `127.0.0.1:8080`，数据目录分别保留。

3、先用免费随机地址联调，需要固定地址时再按详解使用 [**cpolar**](https://www.cpolar.com/) 或命名隧道。cpolar 同机多隧道使用同一客户端进程，保留公网 Host，不默认改写为 localhost。用手机关闭 Wi-Fi 后验证登录、真实写入并刷新重读、上传及授权下载；页面的缓存或本地演示回退不能作为穿透成功证据。

4、脚本管理的本地模式保持终端运行，按 Ctrl+C 退出时回收本次启动的隧道和服务，保留数据、匹配密钥与备份。“服务器部署”沿用服务器运行流程，不启动公网隧道。需要完整恢复原环境时，先看本系统反部署说明，再选择独立的“反部署（快捷入口）”；默认备份验证后清理源数据，清零须另行明确选择与确认。电脑睡眠、合盖、断网及重启期间无法持续对外服务；大陆网络可达性和双项目同机容量仍需实际验收。

完整步骤、费用边界、固定域名与排查见[本地部署＋内网穿透详解](./部署/README.md#local-tunnel)；平台操作分别见 [MacOS](./部署/MacOS/README.md#local-tunnel)、[Windows](./部署/Windows/README.md#local-tunnel) 和[系统部署索引](./部署/README.md#local-tunnel)。

## 二、<span id="directory">目录与端侧入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

项目 Git 根下按 `代码/`、`测试/`、`需求/`、`部署/` 四个并列目录组织；代码、测试、需求三个主目录一级仅保留 `README.md` 与子目录，部署根可保留公共工具锁清单。`代码/` 下分前端、后端，前端再按具体端与技术分工；每个独立工程和操作系统部署单元就近维护代码地图，入口见[开发单元导航](./代码/README.md#unit-code-maps)。公共 SDK、依赖和缓存按具体机器／操作系统准备，项目只保留声明、锁文件、配置和环境准备入口；[机器环境说明](./部署/README.md#machine-environment)列出机器目录和可显式覆盖的参数。

| 位置 | 用途 |
| --- | --- |
| [项目规范](./需求/项目需求与开发评审/项目需求与开发评审.md) | 需求、技术评审、三级验收、部署与交接总入口 |
| [使用说明](./代码/README.md#usage-guide) | 非开发人员的演示步骤、角色、故障处理 |
| [管理后台 Web](./代码/前端/后台管理端/Web/README.md) | 浏览器管理端，适配手机和桌面 |
| [管理后台 Flutter](./代码/前端/后台管理端/Flutter/README.md) | 独立 Flutter 管理端，适配手机和桌面 |
| [管理共享契约](./代码/前端/后台管理端/共享契约/admin-ui.json) | 两套管理端共同的导航、视觉值、字段、43 类动作和合成数据 |
| [前端 Flutter](./代码/前端/移动端/Flutter/README.md) | 用户／工程师 Flutter 应用 |
| [iOS 原生](./代码/前端/移动端/iOS/README.md) | Swift 原生工程、JobsByPods 与独立 Podfile.deps |
| [Android 原生](./代码/前端/移动端/Android/README.md) | Kotlin 原生工程 |
| [鸿蒙原生](./代码/前端/移动端/鸿蒙/README.md) | ArkTS／ArkUI Stage 工程 |
| [微信小程序](./代码/前端/微信小程序/README.md) | 官方原生 JavaScript／WXML／WXSS／JSON；工单、合同表单、签名、附件与库存 |
| [维修工作台 Web](./代码/前端/PC端/Web/README.md) | 业务网页与离线预览入口 |
| [Go 服务端](./代码/后端/后端代码/README.md) | 单份通用业务代码、加密快照及 TiDB 适配 |
| [验证](./测试/README.md) | HTTP 流程与各端回归入口 |
| [部署](./部署/README.md) | 数据、备份、配置和操作系统边界 |
| [开发单元导航](./代码/README.md#unit-code-maps) | 分别进入各端、Go 后端和操作系统部署单元自己的地图 |
| [需求](<./需求/物业设备维修服务平台PRD/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md>) | 当前 V3.8 产品需求，需求目标不等于全部已验收 |

前端与后端各用独立工程；所有客户端调用同一份 Go 服务端，不按平台复制业务服务。Flutter 两应用通过 `代码/前端/共享组件/Flutter` 复用业务和原生组件；管理 Web 另用 JavaScript 实现并读取同一 JSON 契约。微信小程序是本期独立交付端，沿用同一 API 与合成资料隔离规则；MacOS、Windows 和四个 Linux 发行版具备交互部署入口，实际系统验收与卸载边界见 [部署索引](./部署/README.md)。

## 三、<span id="demo-accounts">演示角色与功能</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

所有合成账号密码均为 `Demo-Repair-2026!`，仅作演示。

| 账号 | 职责 |
| --- | --- |
| `admin` | 公司负责人：管理、批准、账号状态及审计 |
| `dispatcher` | 调度：受理、安排、交付协调 |
| `engineer` | 工程师：检测、执行、本人任务 |
| `warehouse` | 仓库：库存、借还、采购收货 |
| `qc` | 质检：检查及客户说明 |
| `finance` | 财务：款项核实、交接、发票及结算 |
| `customer` | 海棠物业经办人：本人授权工单、报价签署、验收 |
| `customer-b` | 青禾物业经办人：跨企业隔离检查 |
| `customer-peer` | 同企业另一经办人：交接授权检查；在原工作台可输入账号 |
| `outsource` / `supplier` | 一手外包／供应商的授权读取和办理 |

业务包含工单受理、寄修／上门／销售、检测、版本化报价、客户手写签署、维修、质检、交付、验收、收退款、发票、资料、借还采购、异议与余项、完结重开、返修、权限与审计。各新端通过服务端 `allowedActions` 展示合法动作；原件和历史记录按职责过滤。各端有限离线动作范围见就近 README，不能把一个端可演示的动作视作所有端已完成联调。

维修只有报价明确 `startRequiresPrepayment=true` 时先核实约定预付款；字段缺省为 false。现款销售仍需按冻结报价核实全款。

## 四、<span id="configuration">连接、离线与数据</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

页面读取和写入优先请求 API；短超时失败可进入独立合成演示。服务恢复后后续刷新重新采用真实响应。演示副本不会自动上传或合并进真实台账。401／403 等明确拒绝不能伪装成功；真实提交结果未知时保留表单与请求键供同键核对。

本机服务默认只监听回环 `127.0.0.1:8098`，不可直接给手机填电脑回环地址。模拟器、Android USB 端口转发和远程服务器的区别见使用说明；正式多机服务需要部署到可信 HTTPS 环境。测试／线上地址分别保存，切换时清会话，线上地址不预填为某台开发机。

沿用本地打包 Logo；新增界面使用文字导航和原生控件，无运行时外链图片依赖。离线预览不要求先部署服务器；动态列表提供完整空态和重载入口。

后端 `WB_DATA_DIR`、`WB_KEY_FILE`、`WB_WEB_DIR`、`WB_ADMIN_DIR`、`WB_ADMIN_FLUTTER_DIR`、`WB_CLIENT_FLUTTER_DIR`、`WB_ADMIN_CONTRACT_DIR`、`WB_TIDB_DSN`、`WB_BACKUP_DIR` 与 `WB_BACKUP_INTERVAL_MINUTES` 按需配置。部署入口按自身位置解析项目资料，按目标机器标准位置或显式参数发现环境和运行数据。Flutter 管理端 web 构建后由 `/admin-flutter/` 托管，构建时使用 `--base-href /admin-flutter/`。

## 五、<span id="verification">验证与范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

验证范围、分级验收、环境指标与用例见 [测试与验收](./测试/测试与分级验收/测试与分级验收.md)，执行入口见 [验证说明](./测试/README.md)。源码、构建、设备业务与正式发布分别登记，不以离线演示代替真实业务验收。

当前有 17 组 P2 问题，按后端、网页响应保护和独立演示列在 [当前问题清单](./需求/当前问题清单/当前问题清单.md)。生产身份、可信加密链路、完整灾备、关系明细、分批履约及实际渠道接入仍需按交付范围实施。

## 六、<span id="maintenance">工程维护</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

修改业务先看 [项目需求与开发评审](./需求/项目需求与开发评审/项目需求与开发评审.md)、接口合同和代码地图，源码修改后仅同步所属具体端／语言工程的 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 索引。`.codegraph/` 与配置位于具体代码开发单元，项目根只通过[开发单元导航](./代码/README.md#unit-code-maps)定位。第三方 Pods、供应商与生成代码遵守原有维护边界。工具链、构建产物和密钥不进入源码交付。文档维护当前版本的能力、操作和限制，不追加更新日志或过程报告。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
