# Android 合同检查

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、覆盖范围](#coverage)
- [二、执行方式](#commands)
- [三、设备与交付边界](#acceptance)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录提供独立 JVM 合同检查，复用客户端的 Repository／DemoStore，通过临时 HTTP 夹具验证身份、业务边界和故障恢复，不要求 Android 设备。客户端构建与操作见 [Android 说明](../../../../代码/前端/移动端/Android/README.md)，项目级验收见 [测试与验收](../../../测试与分级验收/测试与分级验收.md)。

## 一、<span id="coverage">覆盖范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 检查层 | 主要场景 |
| --- | --- |
| 合成台账与临时 HTTP | 同企业经办人隔离、跨企业拒绝、内部库存脱敏、禁止代签、预付上限、幂等重试、借还及转跟踪守恒、超额退款、43 类动作及字段合同、文件 MIME／魔数 |
| 会话与响应 | 登录身份锚点、旧动作版本、导出身份不匹配、嵌套库存坏 2xx、概览隔离、服务恢复、401 清理、环境切换与准确演示凭据 |
| 显式隔离 Go 服务 | 登录／概览／分页、新建与重读、动作版本推进、旧版本 409、PNG 签署与空白拒绝、采购分批收货／借还、跨企业拒绝及退出 |

真实 HTTP 签名样例仅检查格式和业务规则，不能代替实际操作 Android Canvas 控件。临时服务内创建的工单、采购及库存必须使用合成资料；测试不得指向正式业务数据。

## 二、<span id="commands">执行方式</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录执行纯 JVM 检查：

```shell
'../../../../代码/前端/移动端/Android/gradlew' -p . contractChecks
```

仅向自己明确启动的隔离 Go 服务传入根地址；以下示例要求对应端口确实是专用测试实例：

```shell
REPAIR_LIVE_URL='http://127.0.0.1:18938' \
  '../../../../代码/前端/移动端/Android/gradlew' -p . contractChecks
```

Android APK 与 Lint 从当前测试目录进入对应源码工程后运行，SDK 路径由 Android Studio 的 `local.properties` 管理，不固化开发机位置：

```shell
cd '../../../../代码/前端/移动端/Android'
./gradlew assembleDebug lintDebug
```

Windows 从当前测试目录使用 `& '../../../../代码/前端/移动端/Android/gradlew.bat' -p . contractChecks`；进入源码工程后执行 `gradlew.bat assembleDebug lintDebug`。Gradle 依赖从官方仓库解析；遇到下载或 TLS 故障时保留具体错误，核对网络和缓存，不修改全局代理或将临时依赖仓写成项目运行前提。

## 三、<span id="acceptance">设备与交付边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

独立 JVM 检查、APK 构建、Lint、安装与业务交互分别记录。设备验收覆盖最低和目标系统、触控签名、系统文件选择与另存为、横竖屏、TalkBack、401 撤回当前表单与私有内容。Lint 告警逐项评估，不能把构建成功写成零告警或设备通过。

调试包位于 `../../../../代码/前端/移动端/Android/app/build/outputs/apk/debug/app-debug.apk`；正式签名、分发和设备权限需要单独验证。构建目录、`.gradle`、`.kotlin`、`local.properties` 与临时依赖不作为源码交付。检查实现与配置保留在本目录，当前执行状态及产物清单统一见 [测试与验收](../../../测试与分级验收/测试与分级验收.md)和[交付清单](../../../../需求/交付与运维清单/交付与运维清单.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
