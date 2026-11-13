# Android 客户端

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、第一次使用：不需要看代码](#quickstart)
- [二、连接服务器](#connect)
- [三、页面与业务](#features)
- [四、网络失败与演示](#fallback)
- [五、开发与验证](#development)
- [六、常见问题](#help)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录是可构建的 [**Android**](https://developer.android.com/) 原生工程，使用 [**Kotlin**](https://kotlinlang.org/) 与系统原生控件。客户、工程师及公司各岗位使用同一客户端，界面按身份展示授权资料和办理入口，接口沿用 [V3.8 合同](../../../后端/README.md#api-contract)。

## 一、<span id="quickstart">第一次使用：不需要看代码</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

1、打开 [**Android Studio**](https://developer.android.com/studio)，点击 **Open**，选择本目录 `代码/前端/移动端/Android`，等待同步完成。首次同步会联网下载编译依赖。

2、点击 **Device Manager → Create Device**，选择手机和 Android8.0或以上镜像，创建后启动；也可连接已开启 USB 调试的 Android 手机。

3、顶部运行配置选 **app**、设备选刚才的模拟器或手机，点击绿色 **▶ Run**。

4、应用里保留账号 `customer`、密码 `Demo-Repair-2026!`，点击 **登录并进入工作台**。服务器没启动也能进入独立演示。点击 **选择示例角色** 可改用 `engineer`、`warehouse`、`finance`、`admin` 等岗位。

5、点击工单卡片上的 **查看详情与办理**，向下滚动至 **当前可办理**，按表单提示提交。报价签署和客户验收须在白色区域实际手写签名。金额单位为“元”，程序发送整数分；日期需带时区，常用值已预填。

6、在 **我的 → 退出 / 切换角色** 换岗继续。各角色按权限共享当前环境的合成业务台账；演示数据仅在当前应用进程中存在，进程结束后重置，不适合保存正式资料。

本机调试包输出在 `app/build/outputs/apk/debug/app-debug.apk`，使用调试证书签署。发布需要公司正式签名，不能将调试包直接上架。

## 二、<span id="connect">连接服务器</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

登录页 **设置服务器地址** 或 **我的 → 服务器与超时设置** 可填写服务器根地址，不追加 `/api/v38`。切换地址会退出并清除原身份资料。

| 使用位置 | 地址示例 | 注意 |
| --- | --- | --- |
| Android Studio 模拟器访问电脑 | `http://10.0.2.2:8098` | 默认已填，启动 Go 服务后登录 |
| 同一 Wi-Fi 的实体手机 | `http://电脑局域网IP:8098` | 服务须监听可达网卡，防火墙放行端口，用隔离演示数据验证 |
| 已部署服务 | `https://维修服务域名` | 使用有效证书及实际账号 |

模拟器的 `127.0.0.1` 指模拟器自身。HTTP 只在调试构建开放，正式构建只允许 HTTPS。连接和读取超时默认2200毫秒，可调整为500—10000毫秒。服务启动及网络边界见 [部署说明](../../../../部署/README.md)。客户端不修改代理、防火墙或已有服务。

## 三、<span id="features">页面与业务</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 功能 | 当前能力 |
| --- | --- |
| 首页与工单 | 进行中概览、新需求、服务端搜索 / 阶段筛选 / 每页30条分页、完整空态与重新加载 |
| 完整详情 | 报价版本 / 先款约定、结算缺项、资料 / 票款、异议 / 余项、上门 / 成本 / 提成、验收历史与办理记录 |
| 工单办理 | 对接合同43类动作：受理分派、检测报价、审核签署、维修质检、交付验收、资料票款、证据异议、余项行程、外包成本提成、完结重开返修及经办人交接 |
| 手写签名 | 原生 Canvas、清空、PNG编码与空白拒绝；不代客户绘制印章 |
| 附件 | 系统文件选择器上传图片 / PDF / 文字 / 受支持音视频，上限6MB；鉴权下载后通过系统“另存为”保存 |
| 库存 | 配件、借用、完好 / 隔离归还、管理员批准耗用 / 处置 / 独立跟踪、采购及分批收货 |
| 我的 | 十语与三态外观、环境与短超时设置、授权资料导出、帮助、退出与角色切换 |

登录页齿轮或“我的”进入连接设置，点击“语言”选择界面语言，点击外观按钮选择主题；选择后立即生效。跟随系统切换时保留登录输入和内存会话；正在编辑的业务或连接弹窗保留当前输入，关闭后应用新外观。语言提供简体中文、繁体中文、藏文、英文、日文、法文、西班牙文、德文、俄文与韩文；主题提供白天、黑夜与跟随系统，选择保存在本机偏好中。业务名称、客户输入和服务端业务正文保持原值。界面文案以[共享语言目录](../../共享组件/Resources/ui-l10n.json)为源，打包资源随应用离线读取。

权限、阶段、版本、现金与结算条件由服务器再次校验。此客户端不提供管理后台的账号启停和安全审计页面。维修仅明确约定先款时要求核实预付，现款销售仍须核实全款。当前不接真实支付；手写签名不等于认证电子签。地图、物流、短信、AI、聊天按项目整体范围实施。

## 四、<span id="fallback">网络失败与演示</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

刷新和写入均先正常请求 API。成功采用服务器资料；网络失败、超时或读取响应无法解析时，只有准确示例账号与演示密码可进入独立合成台账，界面明确标为 **独立演示**。演示不复制真实客户资料、不自动上传；下一次刷新成功会自动使用服务器数据。

真实写入若发送后丢失响应，界面提示“提交结果暂不确定”，保留表单及相同请求键；按相同内容重试或刷新核对，避免重复入账。401 撤销身份并清空私有资料；403 / 409 / 422 等业务拒绝直接显示原因。采用响应前核对身份、工单ID、动作版本与返修父引用。

本地演示覆盖主要顺序及借还、退款、资料票款守卫；停机恢复验收、自动扫描、正式安全审计、文件内容鉴定和完整持久化恢复仍由服务器负责。演示通过不能替代后端及实体设备验收。

## 五、<span id="development">开发与验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

工具链为 API35、AGP8.9.1、Kotlin2.2.20、Gradle8.14，最低 API26。使用 Android Studio 自带 JDK 或兼容 JDK17以上，依据 [AGP官方兼容说明](https://developer.android.com/build/releases/agp-8-9-0-release-notes)与 [JDK配置说明](https://developer.android.com/build/jdks)。网络和文件IO在后台工作线程执行。

在本目录打开终端：

```shell
./gradlew assembleDebug lintDebug
```

Windows 使用 `gradlew.bat assembleDebug lintDebug`。Android Studio 按本机环境建立 `local.properties`，该文件不入库；源码不绑定开发机路径。

独立 JVM 合同回归运行真实 Repository / DemoStore，启动临时HTTP夹具验证身份、失败与恢复，无需设备；从当前 Android 工程根运行：

```shell
./gradlew \
  -p '../../../../测试/前端/移动端/Android' \
  contractChecks
```

可通过 `REPAIR_LIVE_URL` 给回归传入隔离 Go 服务根地址以增加真实HTTP链路。回归会新建合成工单，应使用专门测试服务，不指向正式数据。

源码入口在 `app/src/main/java/com/jobs/repair/`：`MainActivity.kt` 负责页面，`Forms.kt` 定义43类动作表单，`Repository.kt` 负责网络 / 身份 / 请求键，`DemoStore.kt` 管合成台账，`SignatureView.kt` 提供签名。结果及限制见 [验证说明](../../../../测试/前端/移动端/Android/README.md)。

应用图标与页首标志复用项目既有 `代码/前端/PC端/Web/维修工作台/assets/RepairLogo.png`，随应用打包在 `app/src/main/res/drawable/repair_logo.png`，离线不依赖网络图片。

## 六、<span id="help">常见问题</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 现象 | 快速处理 |
| --- | --- |
| 同步依赖失败 | 确认可访问 Google Maven、Maven Central 和 Gradle 发行站点，再点 Retry；不自动改系统代理 |
| Run没有可选设备 | Device Manager创建并启动设备，或连接开启USB调试的手机 |
| 页面显示独立演示 | 核对服务器地址后刷新，真机用电脑局域网IP |
| 权限不足 | 换对应岗位；管理员不能代客户签署 |
| 记录已更新 | 取消旧表单、重新加载详情后办理 |
| 提交结果暂不确定 | 保留原表单同内容重试，或刷新核对 |

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
