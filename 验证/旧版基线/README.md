# 旧版业务基线验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本目录保留旧版用户网页、管理后台与旧 API 的验证工具，路径已适配当前目录。当前维修工作台使用 [工作台验证入口](../验证工作台.mjs)，从项目根执行 `node 验证/验证工作台.mjs`；本目录的旧 API 场景不能代替 V3.8 新工作台验收。

默认统一入口检查语法、正式测试及独立临时内存 API，不安装依赖、不部署、不卸载、不打包原生应用。显式的 `smoke-api.mjs --tidb` 另行创建并迁移自己的临时测试库，不能连接业务实例。

## 一、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

准备 [**Node.js**](https://nodejs.org)、满足 [Go 模块声明](../../后端/Go服务端/go.mod) 的 [**Go**](https://go.dev/)、`gofmt`；非 Windows 平台还需 `bash` 和 `zsh`。在本 README 所在目录运行：

```sh
node ./validate.mjs
```

只检查部署目录内脚本的语法，不执行部署内容：

```sh
node ./validate.mjs --scripts-only
```

入口从自身位置定位项目根，不依赖启动时的工作目录。`GO_BINARY`、`GOFMT_BINARY` 可指定已有工具的绝对路径，`POWERSHELL_BINARY` 可指定已有 [**PowerShell**](https://learn.microsoft.com/powershell/)；入口不下载工具。

`--require-powershell` 将本机缺少 PowerShell 视为失败。当前副本没有原生 iOS 工程，完整运行会单列“原生能力未提供”，不执行空参数的 Swift 解析，也不把该项计为通过；`--require-ios` 会因此返回失败。`--scripts-only` 不请求原生验证。

退出码非零表示失败；控制台分别显示失败、跳过及未提供的原生能力数。缺少某个平台工具不代表该平台已验证通过。

## 二、检查范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 范围 | 入口及边界 |
| --- | --- |
| Go | [服务端模块](../../后端/Go服务端/) 的格式、单元测试、竞态检查与静态检查；测试包串行，包内并发合同仍执行 |
| 管理后台页面 | [管理后台测试](../../后端/管理后台页面/tests/) 的业务、故障和异步边界及 JavaScript 语法 |
| 旧版用户网页 | [用户网页测试](../../前端/Web网页/旧版用户网页/tests/) 的认证、设备、扫码和环境隔离及 JavaScript 语法；不解析第三方压缩资源 |
| 部署材料 | 扫描 [部署目录](../../后端/部署/) 已有脚本的 Shell 语法、PowerShell UTF-8 BOM／AST；不执行安装或卸载。预留空目录不代表对应平台脚本已实现 |
| 原生客户端 | 当前未提供工程，不把预留目录当作可构建应用或实体设备验证 |
| 旧版 HTTP | 临时构建 `cmd/api`，使用独立回环端口、合成账号及临时附件；默认内存模式，不连接已有 API |

`parse-powershell.ps1` 只调用 Parser，不执行扫描到的脚本。部署目录若另有 `Tests/validate-targets.sh` 或 `Tests/validate-windows.ps1`，统一入口可运行对应模拟回归；当前预留目录没有这些测试实现。

`smoke-api.mjs` 覆盖旧版注册／登录、私有图片、人工审核、扫码授权、设备撤销、下单、并发同键、角色隔离、工单流转、模拟收款、账本与导出。默认清空子进程 `TIDB_DSN`，退出时清理自己启动的进程及临时构建目录；不读取或覆盖根目录既有 `.runtime`。

## 三、独立数据库与适用边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

专用本机 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 测试实例准备好后，才可在本目录显式执行：

```sh
REPAIR_TEST_TIDB_DSN='root@tcp(127.0.0.1:测试端口)/repair_test_probe' \
  node ./smoke-api.mjs --tidb
```

只接受回环主机及 `repair_test_` 前缀；脚本新建随机测试库，在自己的库中迁移且不加载种子，结束删除该库。它不迁移传入名称的数据库，也不安装或启动数据库。

本桌面副本未提供远端 CI 工作流，不宣称已有 [**GitHub Actions**](https://docs.github.com/actions) 运行结果。语法、模拟及本机 HTTP 不能代替各系统真实安装、原生应用和实体设备验收；当前未实现的问题以 [第五轮回归报告](../../docs/五次回归报告-2026-10-15.md) 为准。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
