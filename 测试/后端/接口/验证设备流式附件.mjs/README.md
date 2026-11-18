# 设备附件流式 HTTP 验证

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、执行与依赖](#run)
- [二、验证范围](#coverage)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本入口从当前源码构建临时后端，自动选择独立回环端口、临时运行目录和合成账号；不连接已有服务，不安装SDK，不读取用户业务数据。所有生成图片与视频仅为测试，结束停止本次服务，成功时清理本次临时目录，失败保留诊断目录。

## 一、<span id="run">执行与依赖</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

需要现有Node.js、Go及FFmpeg；从任意工作目录运行同目录 `验证设备流式附件.mjs`。未在PATH时，用 `GO_BIN`／`FFMPEG_BIN` 显式指定已安装工具；可用 `WB_STREAM_TEST_BINARY` 指定当前源码已构建的后端以省去重复构建。

```shell
node './验证设备流式附件.mjs'
```

运行期间在系统临时目录生成真实可播放的短视频，并按ISO-BMFF规范追加48MiB `free` 盒以超过旧附件上限；用文件流发送与流式SHA-256核对，不把整个视频读入JavaScript内存。文件名、URL和临时路径均在运行时解析，不固化开发机目录。

## 二、<span id="coverage">验证范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

验证未认证拒绝、大于旧16／32MiB媒体流上传、相同请求键返回同一凭据、不同内容同键拒绝、跨账号绑定／删除隔离、错误元数据失败原子性、十个媒体同时建单、回执不泄漏原件或存储字段、订单原键重试、原件私有下载摘要一致、已绑定不能取消、未绑定取消及进程重启后持久化。

HTTP结果、服务内部加密／备份专项与原生界面分别验收。当前执行结果集中到[桌面资产盘点](../../../../项目相关报告/PC原生桌面资产盘点.md)，不将此测试外推为公网容量、无限物理磁盘、邮箱正式发送或Windows图形运行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
