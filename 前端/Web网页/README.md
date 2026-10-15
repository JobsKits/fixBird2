# Web 网页目录说明

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本目录管理浏览器端源码及独立离线预览入口。

## 一、<span id="contents">目录职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 路径 | 用途 |
| --- | --- |
| `维修工作台/` | V3.8 主页面、合成演示数据与正式网页测试 |
| [旧版用户网页](./旧版用户网页/README.md) | 保留旧业务基线，使用旧接口 |
| [离线预览.mjs](./离线预览.mjs) | 只公开维修工作台静态资源，API 返回 503 |

## 二、<span id="run">运行与验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从项目根目录运行：

```sh
node ./前端/Web网页/离线预览.mjs
```

默认访问 `http://127.0.0.1:8099/`，按 `Ctrl+C` 停止。联通新 Go 服务端的运行方式见 [部署总文档](../../部署文档.md)。当前待修问题见 [五次回归报告](../../docs/五次回归报告-2026-10-15.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
