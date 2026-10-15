# 独立聊天模块预留

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

用户于 2026-10-05 指定聊天 [**IM**](https://en.wikipedia.org/wiki/Instant_messaging) 在下一版本实现，并与维修业务解耦。这里仅提供关联入口的接口草案，没有聊天实现、路由、数据表或消息发送能力。

## 一、模块边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`contracts.go` 的 `Gateway` 是应用层调用入口。参与人使用账号标识；`BusinessReference` 只携带业务类型和 ID，不导入订单、审核、账务服务。后续身份检查通过独立端口注入，不能信任客户端传入的参与人权限。

聊天模块独立负责会话、消息、附件、实时连接及推送适配；具体功能、存储和服务选择在下一版设计时确认。订单和账务服务不导入本模块，不增加聊天专用字段或连接管理代码。聊天服务也不能修改订单付款、结算或审核状态。

## 二、后续接入 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

各端采用独立聊天功能目录与数据接口；应用层完成账号与业务引用的适配。可替换自建或第三方聊天实现。完整计划见[心愿单](../../../../docs/心愿单.md)。当前接口不承诺消息协议或 API 兼容性，发布聊天版本前再定稿。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
