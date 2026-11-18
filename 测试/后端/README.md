# <span id="前言">后端测试</span>

![Jobs出品，必属精品](../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、入口](#jobs-toc-heading-1)

</details>
<!-- jobs-toc:end -->

---

> 单元测试保持原 Go 包上下文；HTTP 验证使用独立合成数据和临时端口。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- [Go 单元运行器](./运行测试.py/README.md)：外置Go测试，默认覆盖启动静态路由包及业务包。
- [HTTP 验证](./接口/验证工作台.mjs)：构建独立后端并验证真实回环业务；执行前需已有 Go、Node.js 及锁定依赖。本轮目录整理未运行此服务流程。
- [普通认证回归](./单元/internal/workbench/auth_test.go)：验证码、公开客户注册、邮箱登录、密码重置、旧会话撤销、限流、单次消费、企业隔离与保存失败回滚；真实SMTP投递另验。
- [密码表情策略回归](./单元/internal/workbench/password_policy_test.go)：普通文字／ASCII保留、默认表情／心形／旗帜／肤色／ZWJ／键帽拒绝、Unicode18共用表全量一致；注册／重置／新客户账户及旧表情hash登录API拒绝，失败不消费验证码或修改凭据／会话。
- [借出时间回归](./单元/internal/workbench/loan_created_at_test.go)：服务端真实创建时间持久化、重试／归还／列表／重启保留，拒客户端伪造，旧单无时间保持未知。
- [借还图片回归](./单元/internal/workbench/loan_files_test.go)：原子借还／补录、授权原件、公共投影、旧端兼容、图片格式／尺寸／数量与合计大小限制。
- [设备流式原件回归](./单元/internal/workbench/order_uploads_test.go)：分块认证、篡改／截断／重排／尾随、取消清理、持久失败回滚、账号授权、绑定原子性、删除提交前保全／提交后清理、重启孤件回收与完整旁件备份恢复。

单元测试、接口流程、专用 TiDB、目标机与生产部署分别验收；不使用现有实例或真实客户资料。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
