# <span id="前言">Windows 部署依赖更新隔离验证</span>

![项目图标](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行方式](#jobs-toc-heading-1)
- [二、验证内容](#jobs-toc-heading-2)
- [三、结果与边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行方式 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

使用已有 PowerShell 5.1+、Go 1.24+ 和按当前宿主编译的[依赖版本解析器](../../../../部署/公共组件/依赖版本/README.md)。不安装工具。先按[解析器验证说明](../../依赖版本/README.md)构建本机解析器，再在本包运行：

```powershell
& '.\【Windows】验证依赖更新.ps1' -Resolver '<已有本机解析器绝对路径>' -Go '<已有Go绝对路径>'
```

阅读自述后回车开始，其它输入取消；自动化另传 `-Run`。所有项目路径从脚本位置解析，包含中文和空格的 SDK 路径完整传参。解析器必须是当前宿主的原生程序；在 MacOS 上使用 PowerShell 7 验证时，不能传 Windows PE 成品。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、验证内容 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

共 12 组，点载[真实 Windows 部署脚本](../../../../部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1)，保留实际版本选择和业务报告调用逻辑：

- `-Check`／`-Plan` 不调用工具或创建环境、运行目录。
- 官方元数据退出 75 退避重试，参数携带正确平台与架构，仅 Go 传 `--minimum-go`；错误元数据、坏摘要立即停止。
- PATH 旧版不跳过检查，全部缓存按真实语义版本择新，项目缓存指纹失配不复用；显式旧版停止且原文件不覆盖。
- 官方无匹配成品时，须显式指定兼容的原生达标工具；不下载其它架构。
- 下载临时超时重试并移除本次部分文件，摘要失败不重试。
- 公开穿透不要求邮箱能力；私有穿透须额外支持邮箱，两个模式均须支持 URL、会话配置及禁止运行中自动更新。
- 本轮进程捕获保留退出码和完整日志，超时请求回收，日志封存失败停止。
- 源模块生成独立 `module.mod`／`module.sum`；真实 Go 和真实解析器在无外部依赖、关闭模块网络的临时模块执行报告，验证成功与完整性错误 2、查询错误 3。
- 业务库报告成功或 3 类失败检查两个模块，2 类完整性错误停止；取消传播到部署清理，查询失败不标作已是最新。

网络、下载、Windows PE 探针及拥有进程会话使用替身；真实版本比较器、Go 模块报告与文件副本在当前宿主执行。只写系统临时目录，不修改源码锁、用户 SDK、运行数据或系统配置，不联网，不运行服务、隧道或 Windows Job Object。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、结果与边界 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

各组输出 `PASS`。成功清理本次夹具；失败保留临时目录及 `resolver.stderr`，路径显示在终端。进程环境变量在结束后恢复。

本轮 MacOS／PowerShell 7 跨宿主夹具 12／12 通过；不能替代 Windows 实机的 PE 执行、Job Object 子树回收、ACL、网络下载、SDK 安装及真实部署验收。[Shell 五平台专项](../../依赖更新/验证依赖更新.mjs/README.md)与[解析器专项](../../依赖版本/README.md)分别记录其验证边界。

<a id="🔚" href="#前言">返回前言</a>
