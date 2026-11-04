# <span id="前言">管理后台 · Flutter 与 Web</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口](#jobs-toc-heading-1)
- [二、操作者入口](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

[**Flutter**](https://flutter.dev/) 与标准 Web 两套独立实现共用 [界面契约](./共享契约/admin-ui.json)：相同导航、色值、900px 响应式断点、表单字段、43 个业务动作和合成种子。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 实现 | 使用 |
| --- | --- |
| [Web](./Web/README.md) | 启动 Go 服务后访问 /admin/，不需额外编译网页 |
| [Flutter](./Flutter/README.md) | 独立应用；web 构建后访问 /admin-flutter/ |

两者调用同一 `/api/v38` API。业务字段和外观规范一致，具体渲染、有限离线动作及目标端验收见 [测试与验收](../../../测试/测试与分级验收/测试与分级验收.md)，产品包与未完成范围见 [交付清单](../../../需求/交付与运维清单/交付与运维清单.md)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、操作者入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

不熟悉代码请先看 [零基础使用说明](../../README.md#usage-guide)。测试／线上地址分开保存；短超时回退独立演示；真实写结果未知保留请求键；401清会话。复杂离线动作明确拒绝，不能伪造服务端成功。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
