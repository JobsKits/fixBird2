# 啄木鸟维修平台 · WindowsOS 原生桌面端

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与构建](#run)
- [二、功能与数据边界](#features)
- [三、代码地图与验证](#code-map)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[**Windows**](https://www.microsoft.com/windows) 桌面界面由 [**C#**](https://learn.microsoft.com/dotnet/csharp/)／[**WPF**](https://learn.microsoft.com/dotnet/desktop/wpf/) 原生构建。原生窗口、列表、表单、日期及InkCanvas手写签署直接调用工作台 API。与 Mac 端仅共享业务元数据、十语文案和合成夹具，两端分别实现原生界面。

## 一、<span id="run">运行与构建</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 将完整 [win-x64目录](./Dist/win-x64) 复制到 Windows x64 机器，双击 `RepairDesktop.exe`；保留同级 `Resources/`。产物自含.NET运行时，无需Python。当前包在Mac完成交叉发布，Windows真实启动／鼠标／字体／系统主题尚未验收。
- `SourceManifest.sha256`／`ResourceManifest.sha256`分别记录当前相对源码与随包资源摘要；16项源码／工程记录、14项资源均已逐项核对，资源与工程引用来源逐字节相同。EXE已核对为PE32+ GUI x86-64；这些检查不替代Windows界面运行验收。
- 源码入口 [RepairDesktop.csproj](./RepairDesktop.csproj)，用Visual Studio或 [构建脚本](./Scripts/【Windows】构建桌面端.ps1/README.md) 重新发布；需要.NET 10或以上SDK。首次构建只下载官方NuGet包，不自动安装SDK或修改系统服务。
- 默认 `http://127.0.0.1:8098`、2.5秒超时，可在设置修改。可信HTTPS服务及原生内网联调见 [部署说明](../../../../部署/README.md)。账户、签署与数据规则同 [接口合同](../../../后端/README.md#api-contract)。

## 二、<span id="features">功能与数据边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

原生端提供登录／注册／忘记密码三张独立卡片、工单搜索与30条分页、完整详情、受控客户目录新建、设备图片／视频、43项动作表单、实际签署、带图片原件的库存借还、十语言与三主题。签署展示冻结条款、报价版本只读、显式确认并核对开页上下文。业务截止日按上海时区当日23:59:59提交。

工单列表可将状态和搜索词组合使用；点击搜索或按Enter应用，切状态沿用当前输入词，刷新及加载更多保留已应用条件，每页30条。改变任一条件从第1页重新请求，分页去重并忽略旧条件的迟到响应；失败保留原已应用条件及列表。独立演示按相同业务字段、角色范围和状态过滤，不搜索附件／事件JSON。列表只显示“当前已加载工单”数量，不冒充服务总数；当前选择被过滤或动作后的状态移出列表时，详情同步清空，不能继续显示旧单。

工单、借还记录及配件详情内的关联借还记录在列表最前显示从1起的连续序号，工单加载下一页后连续编号。工单显示真实创建时间（缺失时可回退更新时间），借还显示真实借出时间和归还期限；详情、业务记录与图片凭据统一按上海时区、所选语言的日期与时分显示。旧记录缺少有效时间时明确显示“时间未记录”，不以当前时间补造；本地演示新建及实际操作只在动作成功时记录时间。

三张既有本地合成单由 `media-seed.json` 挂载示例设备资料：待受理两图、待客户确认一图一视频、待执行一图一视频，明确标为演示参考。详情直接显示可点击图片缩略图和视频封面／播放入口，视频打开后由原生MediaElement播放，保留播放／暂停；图片按预览尺寸解码。元数据保留真实大小和SHA256，原件从打包资源装入当前演示身份的独立缓存，预览仍经临时原件及摘要核验，关闭清理临时文件。退出清缓存、服务恢复使用真实返回；真实工单和新建演示工单均不会自动继承这些示例附件。素材归属、转换和许可随包 `Resources/media-seed.json` 的credits提供。

设置保存在当前用户本地应用数据 `Jobs/RepairDesktop/preferences.json`，仅包含语言、主题、API根地址及超时；账号密码、Bearer令牌与真实业务数据仅在内存。关闭窗口结束客户端；不会停止后端服务。

首次连接、刷新与写入正常请求API。只有精确回环地址且健康响应明确为合成演示，或该本地服务真正不可达且从未明确为正式环境，才显示上方角色选择、下方预填凭据和独立演示回退；本地Demo默认明文，可通过原生绘制的眼睛隐藏。远程正式地址没有Demo入口和演示凭据预填，失败不自动变成演示。401撤销资料与会话；403／409／422保留拒绝语义。未知写入保留相同内容的请求键，供核对后重试。正常在线注册／重置直接请求后端，成功回登录。演示临时注册资料仅驻内存，验证码有10分钟期限、60秒冷却和5次尝试限制，密码盐哈希。

工单客户、账号、企业均来自受控目录下拉，联动选择并分别提供“新建”，真实账户仅管理员／调度可创建，不把任意文字转换为客户ID。紧凑两列新建表单按内容计算高度；选择器或内容区拖入图片／视频均只保留文件元数据。设备附件不设应用大小或数量上限，使用64KiB缓冲逐个传原件到`order-uploads`，核对服务端长度与SHA256后用`uploadId`随工单原子关联；不把大文件转为Base64或整段读入托管内存。上传显示进度并允许取消，同一文件丢响应重试沿用原请求键，未知建单结果保留冻结引用供核对重试；已上传未绑定原件在移除或取消窗口时尝试清理。本地独立演示同样流复制到自有临时磁盘，并核对摘要，关闭应用清理临时副本，原始选择文件不删除。

详情下载原件也采用文件流和SHA256校验，原生进度卡可取消。预览交由Windows原生图片解码器／MediaElement，图片按预览尺寸解码，视频解码能力由目标系统提供；关闭预览后清理自有临时文件。文件格式与内容完整性仍由服务器检查，实际传输受磁盘、网络和操作系统资源约束。

借出和归还均要求至少一张实际选择的图片，支持PNG／JPEG／GIF，单图8MiB、每借单8图／32MiB，提交前预览。配件与借还记录分别用明确的选择类型管理，整行灰色选中；配件详情只显示真实SKU、可用／隔离数量和关联借还记录，关联记录可点入。借还详情显示借出／归还凭据并鉴权读取原件。独立演示带原创明确标记的2件借出／1件归还图片，也可实际录入图片和部分归还；演示不补传真实服务、不伪造客户签署与票款成功。

十语言与Mac相同，默认简中、跟随系统。认证三门使用同一560逻辑像素高外框，左侧三入口等分填满；入口文字26逻辑像素，登录／注册／找回分别配42×42原生矢量图标，图标在上、标题在下且组合水平／垂直居中，左轨260逻辑像素宽，德俄等长文自然换行并居中，图标随选中态及主题变色。右卡不重复显示标题，输入框至少42逻辑像素高；验证码按钮42逻辑像素高，纸飞机与文字居中，发送中改变文案并禁用，长表单内部滚动。认证及目录账户的密码／确认框统一按共享Unicode 18策略拒绝表情，明密文键入、粘贴与完整值同步均校验并显示提示，提交和请求前再次拒绝，保留普通文字、数字及标点；1582项策略检查通过，Windows控件交互另验。700ms位置切换遵循系统减少动态效果与高对比偏好；角色、账号及密码草稿仅内存。顶栏姓名与角色相同时仅显示一次。设置弹卡按“外观／连接”靠上分组，语言及主题左对齐；成功写入偏好后关闭，失败保留弹卡和错误。系统主题变化自动跟随。动态列表都有完整空态和重载按钮，Logo由本地资源提供。已支持初始设备图视频与借还图片；通用证据批量管理、个人日志、审计导出和采购专项界面仍使用现有 Web。各端源码与实际验收分别登记。

## 三、<span id="code-map">代码地图与验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 职责 |
| --- | --- |
| [Program.cs](./Sources/Program.cs) | WPF原生程序入口 |
| [MainWindow.cs](./Sources/MainWindow.cs) | 分页、整行选中、工单／配件／借还详情与保存即关的分组设置 |
| [NativeAuthenticationView.cs](./Sources/NativeAuthenticationView.cs)／[NativePasswordField.cs](./Sources/NativePasswordField.cs) | 独立认证卡、位置切换、角色预填与原生眼睛 |
| [PasswordCharacterPolicy.cs](./Sources/PasswordCharacterPolicy.cs) | 读取随包Unicode 18数值范围，统一密码字符与Emoji组合校验 |
| [NativeOrderDialog.cs](./Sources/NativeOrderDialog.cs)／[NativeDeviceFile.cs](./Sources/NativeDeviceFile.cs) | 受控客户三联动、设备文件拖入、流式上传进度／取消与冻结重试 |
| [WorkbenchClient.Streaming.cs](./Sources/WorkbenchClient.Streaming.cs)／[NativeTransferStream.cs](./Sources/NativeTransferStream.cs) | 原件上传／下载、64KiB摘要、Int64大小、临时磁盘与身份生命周期 |
| [NativeDownloadDialog.cs](./Sources/NativeDownloadDialog.cs) | 原生下载进度卡与取消 |
| [NativeLoanDialog.cs](./Sources/NativeLoanDialog.cs)／[NativeMediaPreview.cs](./Sources/NativeMediaPreview.cs) | 图片凭据、原生图片与视频预览 |
| [LocalDemoAuthentication.cs](./Sources/LocalDemoAuthentication.cs) | 独立本地演示验证码、盐哈希临时账户，无落盘口令 |
| [ActionWindow.cs](./Sources/ActionWindow.cs) | 原生动作表单、InkCanvas签署、上下文与日期 |
| [WorkbenchClient.cs](./Sources/WorkbenchClient.cs) | HTTP／认证、会话锚、状态＋搜索分页、读取版本、幂等键、独立演示种子媒体与自动恢复 |
| [原生共享契约](../原生共享契约/README.md) | 动作表单、十语言与合成夹具 |

[桌面资产盘点](../../../../项目相关报告/PC原生桌面资产盘点.md)登记构建、真实HTTP客户端验证和目标系统未验项；[合同测试](../../../../测试/前端/PC端/原生桌面端/README.md)复用本端真实客户端源码，在Mac CLI运行不代表WPF已经在Windows运行。成品未Authenticode签名，SmartScreen与真实分发另验。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
