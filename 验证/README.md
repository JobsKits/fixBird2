# 验证入口

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

正式检查与历史业务基线的验证入口集中在本目录。

## 一、<span id="commands">正式检查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从项目根目录运行：

```sh
node --test 前端/Web网页/维修工作台/tests/*.test.cjs 后端/管理后台页面/tests/*.test.cjs 前端/Web网页/旧版用户网页/tests/*.test.cjs
node ./验证/验证工作台.mjs
```

工作台 HTTP 验证创建自己的临时服务与数据，不连接当前实例。Go 工具路径可通过 `GO_BIN` 指定。

## 二、<span id="history">旧版与历史证据</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[旧版基线说明](./旧版基线/README.md) 对应旧 API；V3.8 业务当前问题见 [五次回归报告](../docs/五次回归报告-2026-10-15.md)。

`docs/` 内按日期保存的原始诊断脚本、日志及哈希清单保留原样；其中旧路径的对应关系见 [目录整理说明](../docs/目录整理说明-2026-10-15.md)。历史诊断脚本需要按映射在隔离副本调整后运行，不直接作为当前验证入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
