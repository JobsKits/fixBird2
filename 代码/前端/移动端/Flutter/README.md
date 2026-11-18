# <span id="前言">啄木鸟维修平台 · Flutter 用户端</span>

![啄木鸟维修平台](../../共享组件/Flutter/assets/RepairLogo.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、普通使用者先看这里](#section-1)
- [二、交给维护者的启动步骤](#section-2)
- [三、功能与范围](#section-3)
- [四、验证](#section-4)

</details>
<!-- jobs-toc:end -->

## 一、<span id="section-1">普通使用者先看这里</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这个版本面向物业客户与工程师，和 iOS 原生客户端连接同一套 V3.8 服务。无需理解代码，先运行 [MacOS 部署入口](../../../../部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command)，再打开其显示的地址。Flutter 用户端入口为该地址后面的 `/client-flutter/`，管理端为 `/admin-flutter/`。首次使用先由维护者按下节生成网页包；未生成时页面会明确提示。

1、客户选择「海棠物业联系人」，工程师选择「自有工程师」。合成账号密码统一为 `Demo-Repair-2026!`。

2、在「工单」查看进度，点击卡片进入详情。客户可新建寄修、上门或销售需求；工程师按当前工单提供的按钮办理检测、报价、开修、完修等动作。

3、报价签署与验收需要在签名框内手写。钱按「元」填写，最多两位小数。办理收退款只是业务登记，不会真实扣款。

4、页面显示「服务端数据」时，保存必须由服务端确认；显示「独立合成演示」时，操作只影响本机当前会话的合成资料。刷新会继续连接服务，成功后自动用真实资料替换。演示记录不上传。

5、没有记录时点击「重新加载」，或取消搜索、状态筛选。401会清除身份并要求重新登录；保存超时保留表单，用相同内容重试，避免重复登记。

## 二、<span id="section-2">交给维护者的启动步骤</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录打开终端，执行：

```sh
flutter pub get
flutter build web \
  --base-href /client-flutter/ \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  --output Dist/Web
```

构建目录为 `Dist/Web/`，由项目 Go 服务通过 `/client-flutter/` 同源提供。工程工具链采用 [**Flutter**](https://flutter.dev/)／[**Dart**](https://dart.dev)，具体 SDK 版本由构建环境记录。`--no-wasm-dry-run` 关闭可选 WASM 兼容性预演，上述命令生成 JavaScript 版 Flutter Web。

本工程同时含 `android/`、`ios/` 平台工程，可在 Android Studio / Xcode 选择设备，由维护者运行 `flutter run`。当前演示后端只允许回环监听，手机不能直接用电脑局域网地址连接。Android USB 调试可执行 `adb reverse tcp:8098 tcp:8098`，再填 `http://127.0.0.1:8098`；模拟器访问宿主机通常使用 `http://10.0.2.2:8098`，仍需核对实际网络映射。iOS 模拟器可用 Mac 回环地址；跨设备使用需另行部署可信 HTTPS 服务。测试、线上两个地址在「设置 → 切换服务地址」分别保存，切换后重新登录。Android Release 默认拒绝明文 HTTP，Debug 支持本机开发地址；iOS 已提供本地网络说明与 ATS 配置。

单独执行 `flutter run -d chrome` 是另一个源，Go 当前不放开跨源 CORS，不能把跨源登录失败当作真实API已联通；正式网页联调使用上述同源路径。更换浏览器／清除应用数据会清除已保存的地址。账号密码与令牌不持久化。

## 三、<span id="section-3">功能与范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

客户端复用 [共享 Flutter 业务包](../../共享组件/Flutter/README.md)，提供工单搜索、状态筛选、分页、完整详情、43类 API 动作表单、原生手写签名、文件选择与上传、收退款与资料查询、白天／黑夜／跟随系统主题。公司授权角色还能查看库存、借还与采购；具体权限和状态由服务端决定。

独立演示覆盖主要维修链、录单、收退款、资料、异议、余项、借还与采购。复杂发票原件核对、转包、提成、返修等未完整模拟的动作会明确拒绝并提示连接服务办理，不伪报成功。不是完整生产验收；Android／iOS 真机安装与设备权限需按实际测试记录判断。

## 四、<span id="section-4">验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

共享包的测试与真实 API 验证方法见 [共享包说明](../../共享组件/Flutter/README.md)。本应用与管理后台采用独立入口，业务实现、视觉参数与表单定义保持同源，二者默认登录身份与导航范围不同。

Android 调试包构建入口为 `flutter build apk --debug`，产物位于 `build/app/outputs/flutter-apk/app-debug.apk`。工程配置采用 Gradle 8.14、AGP 8.13.2、Kotlin 2.2.20、Android SDK 36、NDK 28.2.13676358，最低 API 24；锁定配置见 `android/`。调试签名、正式签名、设备安装、原生权限和完整界面分别验收，当前交付范围见 [交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)，测试要求见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
