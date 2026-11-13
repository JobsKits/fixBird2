# 鸿蒙原生维修工作台

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、第一次打开：照着点击即可](#quick-start)
- [二、日常怎么用](#using)
- [三、已实现范围与回退](#coverage)
- [四、源码入口](#source)
- [五、测试方法与验收边界](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录使用 [**ArkTS**](https://developer.huawei.com/consumer/cn/arkts/)／[**ArkUI**](https://developer.huawei.com/consumer/cn/arkui/) 编写 [**HarmonyOS**](https://developer.huawei.com/consumer/cn/) Stage 原生工程，面向手机和平板，直接连接 `/api/v38` 服务。目录包含源码、工程配置和合同检查程序；HAP 构建、签名与鸿蒙设备运行需要官方 SDK 环境，当前未完成目标环境验收。

想先熟悉业务且暂不安装开发工具，可从 [项目首页](../../../../README.md) 打开网页工作台。运行鸿蒙原生 App 按下文操作。

## 一、<span id="quick-start">第一次打开：照着点击即可</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

1、安装华为官方 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)，在首次启动向导安装 HarmonyOS SDK。工程最低 API 为 `5.0.0(12)`；让 IDE 完成必要的 SDK／构建插件匹配与同步。

2、欢迎页点击 **Open**，选择当前包含 `build-profile.json5` 的“鸿蒙”文件夹，不要只打开 `entry`。等待右下角同步结束。

3、在 **Tools → Device Manager** 新建／启动 HarmonyOS 手机或平板模拟器；也可连接已开启开发者模式的鸿蒙手机。真机运行需在 **File → Project Structure → Signing Configs** 登录华为开发者账号并按 IDE 指引配置自动签名。证书与本机 SDK 目录不放入仓库。

4、顶部选择 `entry` 和目标设备，点击绿色运行三角。当前环境缺少鸿蒙 SDK，这一步仍需在装有官方工具的机器上编译验收；遇到错误请保留 Build 面板日志。

5、App 出现后，直接点 **客户演示／工程师演示／公司演示** 即可查看合成资料。进入工单，点“查看与办理”，按实际阶段操作。演示角色各自使用独立台账，切换角色会重新开始。

6、看真实服务资料时，点 **连接设置**，填已部署的服务器根地址，保存后登录。当前电脑演示后端只允许回环监听，不能直接用电脑 Wi-Fi IP 连接；真机上的 `127.0.0.1` 也只指手机自身。跨设备联调需要维护者提供设备可达的可信 HTTPS 服务，不能仅改 App 地址就认为已经联通。

本地合成服务账号可用 `customer`（客户）、`engineer`（工程师）、`admin`（管理员），密码见 [项目演示账号](../../../../README.md#demo-accounts)。也接受服务端实际配置的账号。正式环境使用有效 HTTPS 地址与自己的账号。

## 二、<span id="using">日常怎么用</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目标 | 点击顺序与填写事项 |
| --- | --- |
| 客户报修 | 工单 → 新增工单 → 选择寄修／上门／销售 → 填客户、项目、设备和问题 → 确认提交。客户自己报修时客户账号 ID／企业 ID 可留空，由服务端按当前身份绑定 |
| 找一张工单 | 工单 → 输入工单号、客户或设备 → 搜索；也可选择阶段，使用上一页／下一页 |
| 了解进度与欠项 | 查看与办理 → 查看阶段、下一步、未办妥事项、报价、已核实净收和待收金额 |
| 工程师办理 | 工程师账号登录 → 打开分派给自己的工单 → 按当前出现的事项办理检测、报价、维修、完工；按钮由服务端返回的角色与阶段权限控制 |
| 签署报价／验收 | 当前授权客户登录 → 待确认／待验收工单 → 核对条款、金额、质保和先款约定 → 实际手写 → 确认提交。验收不通过要填具体异议 |
| 归档资料 | 工单 → 归档文字资料，或“选择文件归档”。系统 Picker 选择单份大于0且不超过1MB的 PNG/JPG/GIF/PDF/TXT/MP3/WAV/OGG/MP4 原件；内容和权限由服务端继续核验 |
| 票款登记 | 授权人员打开工单，分别执行现金登记、财务核实、内部交接、资料发送或发票登记。资料／发票通过勾选引用已归档原件 |
| 配件与借还 | 库存借还 → 查看可用／隔离数量 → 授权仓库办理借出、归还、采购收货；耗用、处置、转独立跟踪按管理员权限显示 |
| 换服务器／退出 | 设置 → 保存并重新登录／退出当前账号。更换连接后清空旧会话与页面 |

设置中的语言选择器和外观按钮即时切换界面。语言提供简体中文、繁体中文、藏文、英文、日文、法文、西班牙文、德文、俄文与韩文；主题提供白天、黑夜与跟随系统，选择保存在本机偏好中。业务名称、客户输入和服务端业务正文保持原值。界面文案以[共享语言目录](../../共享组件/Resources/ui-l10n.json)为源，打包资源随应用离线读取。

金额填“元”，程序按十进制精确转换为整数“分”。时间字段展示含时区完整示例，按实际发生时间填写。账号、配件等 ID 必须来自现有授权记录；内部代录、成本审核等专业动作目前仍有 ID 输入项，建议由熟悉业务的管理员办理。

维修仅在报价明确约定“先款开修”时检查约定预付款，单有预付款金额不等于约定先款。销售现款出库及其它执行条件继续由服务端校验。现金登记不等于真实支付渠道扣款。

## 三、<span id="coverage">已实现范围与回退</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

源码包含登录、连接持久化、搜索／阶段筛选／服务器分页、详情、新建、43项工单动作表单目录、Canvas 手写、系统文件选择归档、票款操作、库存／借还／采购和空态重载。详情重点展示当前报价、现金、未办事项及归档资料；完整历史审计、历史签名预览与原件下载仍使用网页工作台。未接入地图、真实支付、认证电子签或独立聊天。

页面进入、重载和演示办理前尝试读取 API；默认超时 `2500ms`，可调至 `500～10000ms`。成功读取采用服务端资料，网络／响应问题回退独立合成台账。保留有效真实会话时，后续成功重载自动恢复服务资料，并要求重新从真实列表选单。HTTP 401 清除授权、资料和未决请求，要求重新登录。

真实写入带版本与 `Idempotency-Key`。超时或坏成功响应保留同一次提交意图，提示结果未知；原内容重试沿用原键，不把未知结果改成演示成功。已知拒绝显示服务端原因。密码、Token和真实资料只在内存中，偏好设置只保存连接地址、超时、语言和外观。

无服务器时，本地演示录单、受理、检测、报价、审核、备注、文字事实和异议等有限动作。签署、财务及复杂库存变更需要服务器，离线时明确拒绝产生这些事实。切演示角色重新生成样例，不做正式业务离线同步。本地Logo复用项目已有 [RepairLogo.png](../../PC端/Web/维修工作台/assets/RepairLogo.png)，无需外部图片请求。

## 四、<span id="source">源码入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 路径 | 职责 |
| --- | --- |
| `AppScope/`、`entry/src/main/module.json5` | 标识、手机／平板目标、网络权限与启动页 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | Stage UIAbility入口 |
| `entry/src/main/ets/pages/Index.ets` | 原生页面、响应式宽度、表单、Canvas和文件操作 |
| `entry/src/main/ets/core/Models.ets` | 身份锚点、整数金额、详情／分页及库存响应校验 |
| `entry/src/main/ets/core/ActionCatalog.ets` | 动作标题、字段目录、金额／日期／发送校验 |
| `entry/src/main/ets/core/WorkbenchStore.ets` | 会话代次、读取回退、迟到响应与未知写保护 |
| `entry/src/main/ets/core/DemoLedger.ets` | 独立合成样例与有限演示规则 |
| `entry/src/main/ets/platform/` | NetworkKit HTTP与系统文件Picker |
| `测试/前端/移动端/鸿蒙/regression.mjs`（仓库相对路径） | 数据合同与隔离 HTTP 检查 |

项目引用均为相对路径，未固化本机 SDK、证书或仓库位置。接口以 [工作台合同](../../../后端/README.md#api-contract) 为准。后端业务条件和客户端操作分别核验，项目级要求见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。

## 五、<span id="validation">测试方法与验收边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Node.js**](https://nodejs.org/) 24及以上版本，从当前鸿蒙工程根目录打开终端执行外置检查：

```shell
node ../../../../测试/前端/移动端/鸿蒙/regression.mjs
```

验证自己明确指定的隔离服务时带服务地址运行；程序会创建合成工单和文字资料，不要指向生产环境：

```shell
REPAIR_TEST_BASE=http://127.0.0.1:18938 \
  node ../../../../测试/前端/移动端/鸿蒙/regression.mjs
```

合同程序覆盖身份、金额、动作、响应校验、回退与故障恢复；显式配置隔离服务时还检查真实 HTTP。合同检查运行于 Node.js，不能替代 ArkTS／ArkUI 编译、HAP 安装及设备交互。测试与安装产物分别收口 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)和[交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

待目标环境验证：DevEco导入、SDK插件同步、ArkTS／ArkUI编译、签名HAP、手机／平板启动、Canvas手势和PNG、文件供应商URI、网络权限、前后台／系统返回、无障碍与暗色主题。当前没有已签名安装包。

官方参考：[网络请求](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http)、[Stage/UIAbility](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-overview)、[原生HTTP接口](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-network-kit/js-apis-http.md)、[Canvas接口](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-arkui/arkui-ts/ts-canvasrenderingcontext2d.md)、[系统文件Picker](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-core-file-kit/js-apis-file-picker.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
