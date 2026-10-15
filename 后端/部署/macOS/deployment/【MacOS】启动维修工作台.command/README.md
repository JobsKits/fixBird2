# [**MacOS**](https://www.apple.com/macos/) 维修工作台启动入口

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

`./【MacOS】启动维修工作台.command` 负责构建 [**Go**](https://go.dev/) 新工作台并在本机回环地址运行。项目根目录保留相对软链接，双击即可发现入口。

## 一、<span id="script-use">运行方式与行为</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

双击脚本，先阅读内置自述，按回车继续；按 `Ctrl+C` 取消。启动后浏览器访问 [本机工作台](http://127.0.0.1:8098/)，按 `Ctrl+C` 停止。

终端运行：

```zsh
/bin/zsh './【MacOS】启动维修工作台.command'
```

入口按自身真实位置定位项目，支持中文、空格及根目录软链接。脚本位于部署目录的独立包内，解析真实位置后退五级定位项目根目录。确认前只展示说明；确认后查找已有 Go、检查源码和网页、构建 `../../../../../.runtime/workbench` 并运行。

## 二、<span id="script-dependencies">依赖与配置</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 配置 | 行为 |
| --- | --- |
| `GO_BIN` | 显式指定已有 Go，配置损坏时直接停止；相对路径按项目根目录解析 |
| `PATH` | 未设 GO_BIN 时检查现有健康 Go |
| `../../../../../Tools/go/bin/go` | PATH 不可用时使用项目内便携 Go |
| `../../../../../后端/Go服务端` | 当前 Go 源码与 `cmd/workbench` 构建入口 |
| `WB_ADDR` | 默认 `127.0.0.1:8098`，仅允许回环主机与有效端口 |
| `WB_DATA_DIR`、`WB_WEB_DIR` | 默认项目根目录 `.runtime/data`、`前端/Web网页/维修工作台`；相对配置按项目根目录解析 |
| `WB_KEY_FILE` | 交由后端；相对路径按项目根目录解析，不要将密钥放入公开日志 |
| `WB_TIDB_DSN`、`WB_REQUIRE_DB_TLS` | 交由后端；指定数据库会初始化快照表，不要使用生产目标或公开 DSN |
| `WB_BACKUP_DIR`、`WB_BACKUP_INTERVAL_MINUTES` | 相对备份路径按项目根目录解析；未配置目标时不启用独立定时备份，间隔默认 1440 分钟 |
| `NO_COLOR` | 改用纯文本展示 |

脚本不执行工具安装、升级、容器部署或旧服务重部署。后端会初始化明确配置的演示存储并写入业务／备份，仅应使用专用目标。完整跨平台运行与数据说明见 [项目 README](../../../../../README.md) 和 [部署文档](../../../../../部署文档.md)；系统入口见 [macOS 部署资料](../../部署文档.md)。

## 三、<span id="script-logs">日志、风险与验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

日志位于系统临时目录中的 `【MacOS】启动维修工作台.log`，确认启动后初始化，终端输出同步保存。默认保留既有业务数据。只有本项目的新工作台进程由此入口启动；停止不会删除数据。

默认账号与明文回环连接供合成数据演示。真实资料须先落实可信加密连接、最小授权、独立密钥保管与独立备份恢复；默认同盘数据与密钥不能抵御整机损失。

静态检查：

```zsh
/bin/zsh -n './【MacOS】启动维修工作台.command'
```

目录调整后的入口仅做语法及直接路径／根软链接解析检查，没有通过双击启动或重新编译业务服务来验证。历史业务验证状态见 [实现范围](../../../../../docs/实现范围.md#verified)。构建失败不会启动旧二进制；端口被占用时更换回环端口，不停止现有服务。

当前没有自动反部署脚本。停止本入口自己运行的前台服务使用 `Ctrl+C`，保留既有 `.runtime`、密钥、附件、配置和备份；部署资料中的目录预留不代表已经实现卸载或数据删除，详见 [停止与反部署说明](../../undeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
