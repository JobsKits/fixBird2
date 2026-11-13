# <span id="前言">V3.8 验证入口</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、网页和HTTP](#jobs-toc-heading-1)
- [二、各端与范围](#jobs-toc-heading-2)
- [三、部署入口](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

所有测试使用合成资料。用例、目标环境、三级验收和执行状态统一见 [测试与验收](测试与分级验收/测试与分级验收.md)；待处理边界见 [当前问题清单](../需求/当前问题清单/当前问题清单.md)。微信端专项核心和隔离Go合成接口结果见[微信端验证](前端/微信小程序/README.md)；完整业务与平台验收仍按目标环境执行。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、网页和HTTP <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从项目根运行：

```sh
node --test 测试/前端/PC端/Web/*.test.cjs
node --test 测试/前端/后台管理端/Web/单元/*.test.mjs
node 测试/后端/接口/验证工作台.mjs
```

`验证工作台.mjs` 创建临时后端、独立回环端口和合成数据，退出时停止并清理自身资源，不连接日常实例。`验证管理端.mjs` 使用显式 `WB_INTEGRATION_URL`，只允许 `127.0.0.1` 的独立端口且拒绝 8098／8099，调用真实 Web 管理 Store 验证登录、工单、库存、权限等链路；执行前先准备独立合成服务。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、各端与范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

[**微信小程序**](前端/微信小程序/README.md)、[**Go**](https://go.dev/)、[**Flutter**](https://flutter.dev/)、[**Android**](https://developer.android.com/)、[**鸿蒙**](https://developer.huawei.com/consumer/cn/) 和 [**iOS**](https://developer.apple.com/ios/) 的工具要求与命令见各端 README。核心合同、真实网络联调、原生构建和设备 UI 分别验收；当前问题须关联专门复现与合法对照，不能用其他通过项抵消。

后端原单测由[外置 Go 测试入口](./后端/运行测试.py/README.md)通过临时 overlay 运行；测试体保留在外层测试目录，代码目录不生成副本。

Flutter 共享包的[单元与 Widget 用例](./前端/共享组件/Flutter/单元/workbench_test.dart)从共享包工程运行，命令见[共享包说明](../代码/前端/共享组件/Flutter/README.md#section-2)。390／1200 宽度的管理页及登录页截图写入 `测试/前端/共享组件/Flutter/证据/`；用例从运行目录向上查找共享包配置与测试入口标记，定位项目根后自动创建证据目录，每次覆盖同名当前截图，不向代码目录或日期化目录写入证据。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、部署入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

[访问二维码隔离验证](./部署/二维码/验证访问二维码.mjs/README.md)在临时目录调用真实二维码工具及各平台部署函数，检查各端地址、离线页面、窄终端回退、二维码失败保留服务、URL变化后旧页失效与反部署会话归属；不连接日常服务或真实隧道。

[MacOS 构建与网页菜单隔离验证](./部署/MacOS/【MacOS】验证工作台构建.command/README.md)使用假工具检查依赖源、失败退出码、旧产物保护、日志、健康接口，以及公网／本机地址选择、打开失败重选、取消保留服务和本次进程回收；不下载依赖或启动真实业务。

[Windows 网页菜单隔离验证](./部署/Windows/【Windows】验证网页菜单.ps1/README.md)使用会话、选择器及浏览器替身检查地址映射、反复选择、打开失败、收起菜单和服务退出清理。MacOS终端交互、各端隔离验证、真实构建、本机健康与公网穿透分别验收；替身结果不代表Windows或Linux目标机验收。

[MacOS／Linux 配对反部署隔离验证](./部署/反部署/验证反部署.mjs/README.md)检查首次原点、原程序与依赖恢复、默认配对备份、清零、专属 SDK 撤回、共享工具保留、指纹冲突、备份失败、PID 身份、取消及并发保护。所有资源来自临时工程，不处理日常 Runtime。

[Windows 配对反部署隔离验证](./部署/Windows/【Windows】验证反部署.ps1/README.md)检查 Windows 原点清单、数据备份及清零、恢复重试、路径边界、摘要冲突和 PID 身份；跨宿主 PowerShell 验证使用权限及进程替身，不代替 Windows 原生 ACL、Job Object、原生工具及真实数据库验收。

两套入口均以假工具和合成数据执行，部署／反部署脚本的只读检查不产生安装或清理副作用。真实服务、SDK 安装、数据库与数据备份介质，继续按[部署与反部署说明](../部署/README.md#undeployment)在目标环境分别验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
