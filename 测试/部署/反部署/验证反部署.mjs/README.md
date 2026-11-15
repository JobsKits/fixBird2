# <span id="前言">配对反部署隔离回归</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行](#jobs-toc-heading-1)
- [二、覆盖与边界](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

> 使用临时项目、假程序与数据核验MacOS和四Linux入口；不下载工具、不连接数据库、不操作真实Runtime。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

需要已有[**Node.js**](https://nodejs.org/)及本机Bash、zsh、SHA256基础工具。在本目录执行：

```shell
node './验证反部署.mjs' --run
```

无参数只展示用途。测试从自身位置定位项目，不依赖调用目录。成功清理本次临时目录，失败保留路径和终端诊断，不生成仓内日期化报告。

仅核验 MacOS 入口与生命周期时执行：

```shell
node './验证反部署.mjs' --run --macos-only
```

每组子进程清除继承的 `WB_*` 配置，显式注入本组临时路径，并使用系统基础命令 PATH，避免操作者已有部署参数进入夹具。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、覆盖与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 五系统部署／反部署脚本语法，以及中文空格项目路径、首次原点和原程序／依赖恢复。
- 文件数据及32字节匹配密钥默认备份并校验；显式清零及本项目新增SDK撤回，既有共享SDK保持。
- MacOS 选定清零并核对范围后，回车确认；空格、文字、EOF、菜单取消及选择器失败均不进入执行。备份模式无需额外文字输入。
- 人工改动指纹、备份复制失败、密钥解密验证失败、复制期间源变化、未登记会话内容、PID复用、软链接、取消和并发操作锁均阻断删除。
- 第一项原件恢复后第二项复制失败保留检查点，同一操作再次运行可继续恢复原点。
- TiDB 备份模式的清零命令必须绑定已验证备份引用，参数路径中的中文和空格保持完整。
- MacOS 使用真实监督子进程、`ps` 身份和随机回环 TCP 监听，核验旧终端仍开着时自动停旧并复用端口，取消重启保留原实例，`HUP`／`TERM` 结束、主入口 `SIGKILL` 及宿主父进程异常结束后的服务与操作锁回收。
- 旧版 PID-only 失效锁可在同项目清单匹配后恢复；PID 复用不误停其它进程，反部署事务与未知归属锁保留。两个新入口并发启动时串行交接，最终仅保留一轮；退出后业务数据标记保持原值。
- Linux入口在本机Bash加载函数隔离验证；不是各发行版实机部署。TiDB事务、密钥及失败边界由[后端正式测试](../../../后端/运行测试.py/README.md)覆盖；未连接真实TiDB。真实公网、断电及生产恢复另验。

生命周期检查仅在 MacOS 主机执行，不建立公网隧道，不打开或关闭真实终端窗口；回环测试监听不使用业务固定端口。真实窗口关闭、手机扫码及公网登录仍需实际访问验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
