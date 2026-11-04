# <span id="前言">V3.8 共享 Flutter 业务包</span>

![啄木鸟维修平台](./assets/RepairLogo.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、职责](#section-1)
- [二、验证命令](#section-2)
- [三、业务与边界](#section-3)

</details>
<!-- jobs-toc:end -->

---

## 一、<span id="section-1">职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本目录被 [用户端](../../移动端/Flutter/README.md) 和 [管理端](../../后台管理端/Flutter/README.md) 以相对 `path` 依赖复用，使用 [**Flutter**](https://flutter.dev/)／[**Dart**](https://dart.dev)。源码导入均为相对 URI 或已声明包，不依赖开发者电脑路径。复制项目时需连同两个 App、共享包及共享契约一起复制。

- `lib/src/contract.dart`：共享表单规范、身份锚点、工单和嵌套现金校验。
- `lib/src/store.dart`：真实 API、会话／读取顺序／请求键、服务恢复、环境双地址、账号与审计。
- `lib/src/demo.dart`：独立合成台账与演示守卫，不复制真实业务数据。
- `lib/src/app.dart`：响应式页面、完整详情、角色可用操作、主题与导出。
- `lib/src/form.dart`：原生表单、手写 PNG 签名、本地文件选择与上传。
- `assets/`：本地 Logo、中文字体、许可及共享契约副本。来源见 [素材来源](./assets/README.md)。

## 二、<span id="section-2">验证命令</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从当前共享包根目录运行，保留资源加载上下文：

```sh
dart analyze --format machine
flutter test ../../../../测试/前端/共享组件/Flutter/单元/workbench_test.dart \
  --reporter expanded
```

需要单独启动隔离 Go 工作台后，执行真实请求验证；只允许显式传入本机回环端口，使用合成账号，测试会新建合成订单：

```sh
flutter test ../../../../测试/前端/共享组件/Flutter/接口/real_api_test.dart \
  --dart-define=API_TEST_URL=http://127.0.0.1:18938 \
  --reporter expanded
```

静态分析使用 `dart analyze --format machine`；遇到包装命令的 SDK／中文路径异常时，先保留诊断，再直接检查同一份源码。共享依赖改变后，需要在两个 App 分别执行 `flutter pub get` 刷新各自锁文件。

[金额 Web 探针](../../../../测试/前端/共享组件/Flutter/接口/web_money_probe.dart) 运行实际 `DemoLedger`，用于补充 Dart2JS 与 VM 数值差异检查。金额边界采用可精确表示的十进制整数；Web 数值、Widget 布局和实体浏览器分别验证，不互相替代。界面显式使用标准视觉密度，移动端大金额单行缩放，卡片数值行保持等高。现有 Widget 用例检查窄屏／桌面、按钮可见尺寸和大金额布局。具体执行结果统一见 [测试与验收](../../../../测试/测试与分级验收/测试与分级验收.md)。

## 三、<span id="section-3">业务与边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

真实数据全部由 Go 服务裁决：报价、签署、财务、库存、权限、版本和幂等都不由前端放行。真实写入失败或结果未知时保留表单和请求意图，不改为演示成功。网络／解析失败后切换到另一份合成资料，后续成功读取自动恢复服务数据；401清除身份和私有资料。

本地演示覆盖主要维修、票款资料、余项、借还采购的基础路径，暂不完整模拟销售出库、发票原件、转包、成本提成及返修等复杂逻辑，对应操作会明确拒绝。真实API表单覆盖当前43种动作，并通过 `allowedActions` 展示；编号可从对应记录复制。上传单文件限制8MB；不要在合成演示中提交真实客户隐私资料。

两个 App 的 Web 包分别通过 `/admin-flutter/`、`/client-flutter/` 同源提供；各自执行 `flutter pub get` 后构建。共享本地 Logo、中文字体与许可随包提供，不依赖外链图片。Android 工程配置采用 Gradle 8.14、AGP 8.13.2、Kotlin 2.2.20、SDK 36、NDK 28.2.13676358，最低 API 24；工具链版本和签名产物按实际环境登记。

Android／iOS 正式签名分发、实体设备、完整需求和生产数据库需独立验收。源码检查、Widget 测试或合成 API 用例不能代替设备权限、触控操作及生产运行证据。交付范围见 [交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
