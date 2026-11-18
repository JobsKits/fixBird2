# 啄木鸟维修平台 · MacOS 原生桌面端

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与构建](#run)
- [二、功能、数据与生命周期](#features)
- [三、代码地图与验收](#code-map)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[**MacOS**](https://www.apple.com/macos/) 桌面界面由 [**SwiftUI**](https://developer.apple.com/xcode/swiftui/) 原生构建。控件、窗口、列表、日期、主题及手写签名均在本机运行，直接请求现有 API。与 iOS 共用 Jobs 自有 Foundation 业务模型、响应校验、权限、请求键及独立合成演示，Mac 网络适配使用原生 URLSession；不依赖 iOS 私库或网页容器。

## 一、<span id="run">运行与构建</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 运行 [啄木鸟维修平台.app](./Dist/啄木鸟维修平台.app)。App 自含资源，可单独复制；最低 MacOS 13，发布包为 Apple Silicon／Intel 通用架构。本机验证为 Apple Silicon，Intel 只完成交叉编译。
- 修改源码后运行 [构建入口](./Scripts/【MacOS】构建桌面端.command/README.md)。需要本机 [**Xcode**](https://developer.apple.com/xcode/) 命令行工具；源码引用从脚本位置解析，不依赖启动目录。项目只交付源码、资源、构建入口及成品，不附带公共 SDK。
- 默认连接 `http://127.0.0.1:8098`，超时2.5秒，可在设置修改为0.5～30秒。正式联调使用可信 HTTPS；后端部署仍走项目 [部署入口](../../../../部署/README.md)。原生客户端不能完成邮件验证码网页访问门禁，内网穿透的原生联调方式查部署说明。
- 登录、注册与忘记密码使用三张等高认证卡，侧边切换、右侧表单独立滚动；侧卡图标40pt、标题24pt，图标在上、文字在下，组合水平／垂直居中；长译文最多两行居中并适度缩放，选中背景与前景同步；输入框42px，验证码按钮同高、纸飞机图标及发送中状态；密码眼睛切换，键入／粘贴与提交均禁止表情符号。回环本地演示才显示角色与预填明文凭据；远程或已确认正式环境不显示演示入口。服务端优先，真正断网时本地演示仍能完成验证码、临时客户注册与找回；错误密码及真实401不会回退成功。

## 二、<span id="features">功能、数据与生命周期</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 入口 | 当前行为与默认值 | 持久化与生命周期 |
| --- | --- | --- |
| 登录／注册／找回 | Bearer会话；正常邮箱验证码注册与密码重置成功回登录；密码按共享Unicode18精确范围拦截表情、保留普通文字及ASCII标点，错误后需合法编辑才能提交；本地演示上方角色、下方预填明文密码，可眼睛切换 | 密码与令牌仅内存；临时注册客户独立公司／空资料，验证码10分钟、60秒冷却和5次；切账号清理、迟到结果隔离 |
| 工单 | 搜索与状态联合过滤、每页30条、加载更多；演示采用相同业务字段和角色范围；汇总只计算当前加载的筛选结果；列表从1连续编号并显示创建时间，详情显示创建／更新时间；新建寄修／上门／销售 | 真实资料不写本地磁盘；刷新保留条件，空态可重新加载；被过滤选择清空详情，最新选择序号阻止旧结果覆盖 |
| 三张演示单设备资料 | 待受理两图、待客户确认及待执行各一图一视频；112×74缩略图、视频封面与播放入口，明确演示参考 | `WBDemoMediaSeed`只对固定合成种子挂载随包原件；按当前身份、资源白名单、长度与SHA解析，真实／新建工单不继承，服务恢复采用真实返回 |
| 客户联动与新建媒体 | 客户／账户／企业三个受控下拉，选老客户自动填账户与企业；管理员／调度可在各菜单新建，多账户／企业按客户分组；设备可加图／视频、预览和移除 | 账户／企业由服务端生成并持久；原件通过文件流上传、uploadId随单原子关联，不设应用大小／数量上限；支持选择和拖入、进度／取消、临时磁盘预览及SHA核验；身份／来源变化关闭旧表单，失败保留草稿与原请求键 |
| 当前可办理 | 根据服务端 `allowedActions` 展示43项业务动作的原生表单；整数分、版本及幂等键提交 | 未知写保留原意图键，需核对后按原内容重试；拒绝不生成成功记录 |
| 客户签署 | 展示报价与先款、预付款、自动验收条款，明确确认后实际手写生成PNG原件 | 报价版本只读；开页身份／服务／数据来源变化不能继续提交；演示不伪造签署成功 |
| 日期 | 业务选择及列表展示按上海时区与公历，日期／时分随所选语言格式化；截止日取当日23:59:59 | 工单与新借出时间取真实记录；旧借还缺失显示“时间未记录”，不以当前时间补造；签署和日期由服务端校验 |
| 库存借还 | 配件卡片可点击看SKU、可用／隔离与关联借还；借还整行灰色选中、从1连续编号并显示借出／到期时间，详情看原图，借出与部分完好／隔离归还均附图片，可补录 | 原件鉴权下载，列表只含元数据；单借单图片上限仍为8张／32MiB，单图8MiB；独立样例有明确标注的借还图片，不补传真实服务 |
| 设置 | 外观／连接靠上分组；语言与主题左对齐；弹出卡保存成功即关闭，校验失败保留 | 语言、主题即时保存；地址／超时仅保存按钮提交 |
| 语言／主题 | 简中、繁中、藏、英、日、法、西、德、俄、韩；白天／黑夜／跟随系统，默认简中与跟随系统 | UserDefaults保存语言、主题、服务地址与超时；系统主题由SwiftUI跟随 |
| API回退 | 页面刷新与动作先正常请求；仅本地演示门禁允许网络失败后采用独立合成样例，后续成功响应恢复真数据 | 演示只驻内存，不把真实失败写入改造成同身份本地成功，不自动补传演示记录 |
| 图像 | 本地项目Logo与示例设备PNG／MP4随App打包；签名为实际输入 | 没有外链图片依赖；来源、作者、转换及许可在共享契约README和随包media-seed.json的credits |

当前桌面包含工单主线、财务与余项等原生表单及库存借还；新建工单支持设备图／视频，普通证据办理入口仍以文字归档为主，个人日志、审计导出与采购专项界面仍使用现有 Web。动作具备服务端接口不代表每个复杂动作均能离线演示；未覆盖的演示动作会明确拒绝并要求连接服务。

## 三、<span id="code-map">代码地图与验收</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 职责 |
| --- | --- |
| [RepairDesktopApp.swift](./Sources/RepairDesktopApp.swift) | 原生窗口、语言环境、系统主题 |
| [DesktopView.swift](./Sources/DesktopView.swift) | 登录、工单、详情、库存、设置与空态 |
| [DesktopModel.swift](./Sources/DesktopModel.swift) | WBStore观察、状态与角色搜索投影、当前加载汇总、详情选择防迟到、回环本地演示探测与图片鉴权 |
| [WBDemoMediaSeed.swift](../../移动端/iOS/App/Data/WBDemoMediaSeed/WBDemoMediaSeed.swift) | 仅Mac固定合成工单的随包设备资料元数据 |
| [DesktopAuthView.swift](./Sources/DesktopAuthView.swift)／[DesktopPasswordField.swift](./Sources/DesktopPasswordField.swift)／[DesktopLocalDemoAuth.swift](./Sources/DesktopLocalDemoAuth.swift) | 等高认证卡、密码眼睛与本地隔离验证码账户 |
| [DesktopInventoryView.swift](./Sources/DesktopInventoryView.swift)／[DesktopLoanProofForm.swift](./Sources/DesktopLoanProofForm.swift)／[DesktopLoanProofTile.swift](./Sources/DesktopLoanProofTile.swift) | 可选配件详情、灰色借还选择、部分归还与图片凭据原件 |
| [DesktopPasswordPolicy.swift](./Sources/DesktopPasswordPolicy.swift)／[DesktopTimestamp.swift](./Sources/DesktopTimestamp.swift) | 共享Unicode密码策略、完整字符过滤、上海时区与语言日期格式 |
| [DesktopSettingsView.swift](./Sources/DesktopSettingsView.swift)／[DesktopLogo.swift](./Sources/DesktopLogo.swift) | 左对齐设置、保存关闭与本地品牌资源 |
| [DesktopAction.swift](./Sources/DesktopAction.swift)／[DesktopActionForm.swift](./Sources/DesktopActionForm.swift) | 共享动作元数据驱动的原生表单、提交上下文 |
| [DesktopSignature.swift](./Sources/DesktopSignature.swift) | 实际手写及PNG输出 |
| [DesktopCreateForm.swift](./Sources/DesktopCreateForm.swift)／[DesktopLoanForm.swift](./Sources/DesktopLoanForm.swift) | 新建与借出表单 |
| [DesktopCustomerDirectory.swift](./Sources/DesktopCustomerDirectory.swift)／[DesktopDirectoryEditor.swift](./Sources/DesktopDirectoryEditor.swift) | 客户／账户／企业关联及授权新建，独立演示关系只在内存 |
| [DesktopDeviceMedia.swift](./Sources/DesktopDeviceMedia.swift)／[DesktopOrderUploadDraft.swift](./Sources/DesktopOrderUploadDraft.swift)／[DesktopFileTransfer.swift](./Sources/DesktopFileTransfer.swift) | 选择与拖入、受控磁盘副本、分块SHA、原生文件流上传与取消、uploadId草稿 |
| [DesktopDeviceEvidenceView.swift](./Sources/DesktopDeviceEvidenceView.swift)／[共享媒体确认](../../移动端/iOS/App/Data/WBInitialMedia/WBInitialMedia.swift) | 已有工单私有原件流下载及系统预览、原子创建回执与SHA核对 |
| [WBJobsTransport.swift](./Sources/WBJobsTransport.swift)／[DesktopRedirectPolicy.swift](./Sources/DesktopRedirectPolicy.swift) | 原生HTTP、短超时、JSON、拒绝重定向 |
| [共用业务源码](../../移动端/iOS/App/Data) | WBStore、合同校验、独立演示、模型；构建仅引用自有Foundation源码 |
| [原生共享契约](../原生共享契约/README.md) | 动作字段、十语补充、合成夹具 |

当前构建、运行与真实HTTP集成结果统一见 [桌面资产盘点](../../../../项目相关报告/PC原生桌面资产盘点.md)。[测试源码与执行](../../../../测试/前端/PC端/原生桌面端/README.md)区分业务合同、原生传输及目标系统UI验收。Resources内SourceManifest／ResourceManifest分别核对编译源码与打包资源。本机签名为ad-hoc，尚未进行Developer ID签名、公证、另一台电脑隔离启动或正式发布。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
