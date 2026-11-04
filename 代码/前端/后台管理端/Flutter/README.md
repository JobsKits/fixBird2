# <span id="前言">啄木鸟管理工作台 · Flutter</span>

![啄木鸟维修平台](../../共享组件/Flutter/assets/RepairLogo.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、不懂代码怎么开始](#section-1)
- [二、维护者生成网页包](#section-2)
- [三、两套后台如何保持一致](#section-3)

</details>
<!-- jobs-toc:end -->

## 一、<span id="section-1">不懂代码怎么开始</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先运行 [MacOS 部署入口](../../../../部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command)，再在浏览器打开显示地址的 `/admin-flutter/`。普通 Web 管理端入口为 `/admin/`。两套管理端使用同一份页面规范：概览、工单、库存借还、采购、设置；桌面侧栏，手机横向导航，页面字段与办理动作一致。首次需要维护者生成下面的网页包。

1、负责人选择「公司负责人」，调度选择「客服调度」，财务选择「财务人员」。合成账号密码 `Demo-Repair-2026!`。

2、先在「概览」查看进行中、结算中、待收金额及待办，再点「新建工单」填写客户和设备。点工单卡片进入完整详情，按当前阶段办理。

3、调度受理与指派，工程师检测、报价和维修；客户签署报价并验收；财务核实票款和资料；负责人确认缺项清空后完结。

4、仓库使用「库存借还」「采购」，可登记借用、归还、采购和分批收货。账号停用和审计日志在「设置」里，需真实服务和管理员身份。

5、服务暂不可用时页面自动展示独立合成演示。此时复杂动作可能提示「请连接服务办理」。服务恢复后点击「重新加载」自动替换为真实资料，演示操作不会同步。

## 二、<span id="section-2">维护者生成网页包</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录打开终端：

```sh
flutter pub get
flutter build web \
  --base-href /admin-flutter/ \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  --output Dist/Web
```

产物在 `Dist/Web/`，Go 服务通过 `/admin-flutter/` 同源加载。不要双击 `Dist/Web/index.html`；浏览器的 `file://` 限制会阻止加载应用。单独 `flutter run -d chrome` 与 API 分属两个源，而当前 Go 服务不开放跨源 CORS；真实网页联调使用同源入口。

项目包含 Android／iOS 平台目录，由维护者使用 Android Studio / Xcode 选择设备并执行 `flutter run`。测试与线上服务地址分别在「设置」保存；换地址会退出旧会话。线上使用 HTTPS，Android Debug 可用开发明文地址，Release 默认不开放明文。默认请求超时 2.5 秒，维护者可通过共享包请求配置调整。

## 三、<span id="section-3">两套后台如何保持一致</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[共享契约](../共享契约/admin-ui.json) 定义导航、色值、断点、字段、43种动作、库存采购表单及合成种子。Flutter 包内保留逐字节相同的副本，回归测试检查两份一致。Web 使用 HTML/CSS/JavaScript，Flutter 使用 Dart 原生 Widget；都直接请求 `/api/v38`。

金额按元输入、API使用整数分。签名由手写画板生成 PNG；文件从本机选取后以 base64 上传。支持空态重载、真实分页、导出身份核对、未知提交请求键重试、401全局撤销和旧会话迟到响应隔离。深浅主题、完整功能和验证范围见 [共享 Flutter 包](../../共享组件/Flutter/README.md)。

Android 工程配置采用 Gradle 8.14、AGP 8.13.2、Kotlin 2.2.20、SDK 36、NDK 28.2.13676358，目标 API 24—36。兼容性与工具链维护提示需在实际构建时核对。`build/app/outputs/flutter-apk/app-debug.apk` 为本地生成的调试包，源码交接须重建；正式签名、实体设备安装与移动端界面尚需验收，iOS Flutter 也需独立构建与签名。各端证据与状态见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)，分发范围见 [交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
