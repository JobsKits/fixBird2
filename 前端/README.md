# 前端目录说明

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

客户端按平台分别管理，各端通过服务端接口共享业务能力。目前已有网页和 [**iOS**](https://developer.apple.com/ios/) 原生客户端，其它端保留结构。

## 一、<span id="platforms">平台目录</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目录 | 状态 |
| --- | --- |
| [iOS](./iOS/README.md) | 已实现 [**Swift**](https://www.swift.org/) 原生客户端、工作区与数据测试；运行验收范围见 [本轮报告](../iOS实现与验证-2026-10-15.md) |
| [Android](./Android/README.md) | 预留，无原生工程 |
| [鸿蒙](./鸿蒙/README.md) | 预留，无原生工程 |
| [微信小程序](./微信小程序/README.md) | 预留，无小程序工程 |
| [Web 网页](./Web网页/README.md) | 维修工作台与旧版用户网页源码 |

## 二、<span id="contract">接口与演示</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

新工作台与 iOS 原生客户端使用 `/api/v38`，旧版网页使用旧接口；不要混用。网页请求、超时回退、空态和离线预览说明见 [部署总文档](../部署文档.md#offline)。iOS 通过 JobsNetworking 请求服务，独立合成演示与真实会话隔离，签署、借还过账及财务等动作须服务端确认；配置、Files 原件上传、主题与构建说明见 [iOS README](./iOS/README.md)。

增加原生端没有修复 [第五轮确认的 17 组 P2](../docs/五次回归报告-2026-10-15.md)，也不代表 Android、鸿蒙或微信小程序已实现。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
