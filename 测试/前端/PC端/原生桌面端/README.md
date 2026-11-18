# PC 原生桌面 · 客户端合同验证

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、执行入口](#run)
- [二、覆盖与边界](#coverage)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

测试复用真实原生客户端业务与传输实现，使用独立合成后端。执行会在指定服务创建合成工单和备注，必须使用本人隔离测试环境，不能指向正式业务服务。目标系统UI、签名与分发分别验收。

## 一、<span id="run">执行入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在项目根执行，服务地址按本人隔离后端替换：

```shell
xcrun swiftc -D DEBUG -parse-as-library \
  '测试/前端/PC端/原生桌面端/MacOS/DesktopContractSmoke.swift' \
  '代码/前端/PC端/MacOS/Sources/WBJobsTransport.swift' \
  '代码/前端/PC端/MacOS/Sources/DesktopRedirectPolicy.swift' \
  $(rg --files '代码/前端/移动端/iOS/App/Data' -g '*.swift' | rg -v '/WBJobsTransport/') \
  -o /tmp/repair-desktop-smoke
/tmp/repair-desktop-smoke http://127.0.0.1:18201

dotnet run --project '测试/前端/PC端/原生桌面端/Windows/ContractSmoke.csproj' -- http://127.0.0.1:18201
```

Swift测试需要本机Xcode命令行工具；C#合同驱动用本机.NET 11，仅为无图形的测试宿主，产品本身仍为.NET 10 WPF。测试来源分别是本仓真实 `WBStore + WBJobsTransport` 与 `WorkbenchClient.cs`，不替代真实业务实现。

C#不传地址时仅执行协议、离线认证／借还和流式文件夹具，不连接现有服务。传入地址后可追加合成PNG、有效MP4及大MP4三个路径，运行真实注册／找回、客户多企业多账号、图片借还、原件和流式设备上传验收：

```shell
dotnet run --project '测试/前端/PC端/原生桌面端/Windows/ContractSmoke.csproj' -- \
  http://127.0.0.1:18301 /tmp/synthetic-proof.png /tmp/synthetic-small.mp4 /tmp/synthetic-large.mp4
```

其中大MP4应超过旧32MiB边界，并保持真实有效容器。`Windows/StreamingSmoke.cs`直接复用产品流式实现，使用有界缓冲与临时磁盘，测试结束删除自身夹具，不触碰用户原件。

密码字符策略有不联网专项，直接编译当前Windows产品策略与共享Unicode范围，不运行其它合同夹具：

```shell
dotnet run --project '测试/前端/PC端/原生桌面端/Windows/ContractSmoke.csproj' -- --password-only
```

此专项核对1447个Unicode 18 Emoji码点、普通十语文字／ASCII标点、裸心形、旗帜／肤色／ZWJ／tag／keycap／VS16，以及登录／注册／找回／目录账户在发出HTTP前拒绝。WPF键入、粘贴、明密文切换和发送验证码按钮仍需Windows实际界面验证。

Mac密码过滤与上海时间解析复用实际产品源码，不联网；在项目根执行：

```shell
input_review_dir="$(mktemp -d)"
cp '代码/前端/PC端/原生共享契约/password-emoji-ranges.json' "$input_review_dir/"
xcrun swiftc -parse-as-library \
  '代码/前端/PC端/MacOS/Sources/DesktopPasswordPolicy.swift' \
  '代码/前端/PC端/MacOS/Sources/DesktopTimestamp.swift' \
  '测试/前端/PC端/原生桌面端/MacOS/DesktopInputPolicyTests.swift' \
  -o "$input_review_dir/InputPolicyTests"
"$input_review_dir/InputPolicyTests"
```

1508项检查通过，覆盖全量官方码点、完整字符过滤、普通文字／数字、局部组合符例外、纳秒ISO时间、上海时区与缺失时间。它不代替真实输入控件和目标系统界面验收。

借还图片与新建媒体另有独立Foundation专项；无需启动后端，不使用已有用户数据，在项目根执行：

```shell
node './测试/前端/PC端/原生桌面端/MacOS/验证媒体合同.mjs'
```

该入口从脚本实际位置解析项目，编译当前共享Data源码及既有 `WBFixture/WBStubTransport`，仅在系统临时目录产生测试可执行文件，不修改应用源码、工程或成品。不会重复运行原 `WBDataRunner`；真实HTTP、UI手势和附件选取仍分别验收。

工单筛选使用当前桌面模型与受控传输回归，覆盖状态＋搜索、角色字段、分页、空结果和迟到详情；不等同真实HTTP端到端筛选验收：

```shell
node './测试/前端/PC端/原生桌面端/MacOS/工单筛选验证.mjs'
```

三张预埋合成工单的设备图片／视频另有本地原件回归，不启动后端或构建主App：

```shell
node './测试/前端/PC端/原生桌面端/MacOS/预埋设备媒体验证.mjs'
```

该入口编译实际合成模型和Mac原件映射，把四个共享媒体与元数据复制到本次系统临时目录；验证三张图片可解码、视频有可播放轨道与有效时长、缩略图／视频封面、大小与SHA、身份隔离、供应商／新建／服务端工单不自动植入，以及导入引用清除和资源损坏拒绝。不会改共享素材或现有用户资料。

## 二、<span id="coverage">覆盖与边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 场景 | 当前结果 |
| --- | --- |
| Mac原生真实HTTP | admin登录、完整详情、新建、备注与版本推进、401不回退、断网合成隔离通过 |
| Mac工单过滤 | [DesktopOrderFilterSmoke.swift](./MacOS/DesktopOrderFilterSmoke.swift)验证离线三单到待受理一单、联合搜索、角色可搜索字段、刷新／清空条件、当前加载汇总、详情选择和迟到结果；受控API参数与30＋1分页通过。实际窗口另确认待受理仅一单 |
| Mac客户目录与设备媒体 | `MacOS/DesktopCustomerMediaSmoke.swift`复用实际WBStore/原生传输，独立服务新建客户、第二企业／账户、关联工单及真实PNG／MP4原件，按SHA确认并拒绝缺附件响应 |
| Mac流式设备附件 | [DesktopStreamingMediaSmoke.swift](./MacOS/DesktopStreamingMediaSmoke.swift)实际通过9件35+MiB原件、超过旧8MiB图片／16MiB视频边界、小于8KiB元数据JSON、同键上传、uploadId原子建单与SHA、磁盘流下载、已绑定删除拒绝、未绑定取消／删除、任务取消及本地原件引用清理。编译带入`DesktopDeviceMedia.swift`、`DesktopFileTransfer.swift`、`DesktopOrderUploadDraft.swift`、原生传输和全部自有Foundation数据源码；两个运行参数是隔离回环服务地址及本人合成有效MP4，禁止日常8098 |
| Mac预埋设备媒体 | [DesktopBundledMediaSmoke.swift](./MacOS/DesktopBundledMediaSmoke.swift)验证三张合成工单的6个资料入口、3张可解码图片／13.8秒可播放视频轨道、缩略图／封面、SHA、跨身份引用拒绝、供应商／新建／服务端样本排除、导入引用生命周期与损坏拒绝；临时副本执行。实际窗口已显示待受理两图，系统播放器点验因界面工具超时未完成 |
| Windows客户端真实HTTP | 同项及搜索通过；在Mac的无GUI合同宿主运行 |
| Windows协议异常与并发 | 503独立回退、认证actor自动恢复、未知写同键重试、403不伪成功、迟到分页排除、401清会话通过 |
| Windows密码字符策略 | `Windows/PasswordPolicySmoke.cs`专项1582项检查通过，直接复用产品`PasswordCharacterPolicy.cs`及共享Unicode 18范围；登录／注册／找回／目录提交拒绝均在HTTP前验证，保留`#*0-9`、普通多语文字和与`©®™`分开的印度文字ZWJ，不把整段密码中的无关字符混判为Emoji组合。仅Mac无GUI执行，WPF键入／粘贴与控件反馈未实机验收 |
| Windows状态与样例媒体 | `Windows/OrderFilterSmoke.cs`复用当前客户端源码：三单六附件原件／SHA与缩略图／视频封面、真实数据不注入样例、新建不继承附件、状态＋搜索／刷新／空结果、32条本地分页／65条API夹具、条件变化回第1页、迟到旧页拒绝、失败条件回滚和服务恢复不混数据通过。Mac无GUI执行，未外推WPF视频解码或鼠标验收 |
| Windows流式设备附件 | 40MiB协议夹具和超过2GiB的Int64选择通过；64KiB传输块、MIME／文件名／Bearer、丢响应同键重放、取消、源文件变化拒绝、上传／下载SHA256、本地临时磁盘原子关联与自有副本清理通过。真实隔离服务50,338,177字节有效MP4原件往返及9个附件建单通过；仅Mac无GUI合同宿主执行 |
| 共享Foundation媒体专项 | 5组通过、失败0、跳过0：真实借还响应拒绝原件字段泄漏、重复文件ID、非法元数据及数量／字节超限；演示部分归还和独立跟踪守恒；合并图片32MiB／8图边界失败保持库存与版本；新建回执缺失或SHA不符保持未知且沿用原请求键；附件回执一一对应及删除记录拒绝 |
| 目标系统界面 | Mac限定界面实际运行见[资产盘点](../../../../项目相关报告/PC原生桌面资产盘点.md)；Windows图形运行未执行 |

源码、构建成品、设备运行和生产验收不互相替代。真实支付、敏感资料、正式发布、公证与Windows分发另验。

客户媒体驱动与普通Mac驱动分开编译（同样带入WBJobsTransport、DesktopRedirectPolicy和全部自有Foundation数据源码），参数为独立回环端口、合成PNG文件、合成MP4文件，禁止日常8098。后端目录／媒体权限、限额、原子回滚、重启、幂等及大请求体回归在[外置Go用例](../../../后端/单元/internal/workbench/customer_directory_test.go)和[设备媒体用例](../../../后端/单元/internal/workbench/order_media_test.go)，通过既有后端overlay运行器执行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
