# 微信端专项验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行入口](#entry)
- [二、真实服务与结果边界](#integration)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录只验证微信端实际请求和表单模块；不启动微信开发者工具，不进行手机、体验版、提审或发布。

## 一、<span id="entry">运行入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从本目录运行[mini.test.cjs](./mini.test.cjs/README.md)：

```shell
node --test ./mini.test.cjs/mini.test.cjs
```

使用Node内置测试运行器，无需npm依赖。10项核心用例通过受控传输替身验证成功读取、断网回退、恢复覆盖、会话撤销、旧刷新／详情／退出、未知提交原键、HTTP500和改变正文阻断、1MB附件不经setData、WXML指令及事件入口。

## 二、<span id="integration">真实服务与结果边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

设置 `REPAIR_TEST_BASE` 为独立Go合成服务根地址可再执行一项真实HTTP业务用例：登录、分页、新建、详情、版本化备注动作、退出。只接受127.0.0.1独立端口，拒绝8098／8099，测试会新建合成工单。没有配置时该项明确跳过。核心替身、真实Go接口、微信工具和手机证据分别登记，不能互相代替。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
