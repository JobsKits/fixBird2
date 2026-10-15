# 后端目录说明

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

业务服务器使用同一份 [**Go**](https://go.dev/) 源码；系统差异集中到部署目录。

## 一、<span id="contents">目录职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目录 | 内容 |
| --- | --- |
| [Go 服务端](./Go服务端/README.md) | 单一 Go module，新工作台及旧 API 基线 |
| [管理后台页面](./管理后台页面/README.md) | 旧管理后台网页源码，独立于 Go 业务代码 |
| [部署](./部署/README.md) | 各服务器系统的部署文档、部署与反部署入口 |

## 二、<span id="boundary">维护边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

不要为不同操作系统复制 Go 业务源码；按目标系统及架构分别构建。管理后台页面按用户确认的目录归入后端，仍是浏览器前端代码。当前运行入口与平台验证边界见 [根说明](../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
