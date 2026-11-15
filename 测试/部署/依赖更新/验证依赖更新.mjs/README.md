# <span id="前言">Shell 部署依赖更新隔离验证</span>

![项目图标](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行入口](#jobs-toc-heading-1)
- [二、验证范围](#jobs-toc-heading-2)
- [三、结果与保留](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行入口 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

本包在MacOS宿主使用Node.js 20+、zsh、Bash与系统tar，加载五个Shell系统部署入口的真实函数。所有工程、工具、归档和进程都是临时夹具；不联网、不安装SDK、不运行真实业务或公网隧道。Windows逻辑由[独立专项](../../Windows/【Windows】验证依赖更新.ps1/README.md)验证。

先用已有健康Go在临时目录构建标准库[解析器](../../../../部署/公共组件/依赖版本/README.md)，再把路径显式传入测试。以本README所在目录为例：

```sh
test_resolver_dir="$(mktemp -d "${TMPDIR:-/tmp}/repair-version-test.XXXXXX")"
GOTOOLCHAIN=local GOWORK=off go -C '../../../../部署/公共组件/依赖版本' build -mod=readonly -o "$test_resolver_dir/resolver" .
node './验证依赖更新.mjs' --run --resolver "$test_resolver_dir/resolver"
```

无`--run`或解析器路径时只显示用途，不隐式构建、查询或部署。测试依赖已经可用的Go，不自动安装或升级测试环境。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、验证范围 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

- 每次选择后查询官方目标；健康旧PATH不能跳过，多个缓存按实际语义版本择新。
- 显式旧工具保留原文件并停止；不支持的平台成品只能由明确提供的匹配工具满足。
- 元数据临时故障与下载503可以重试；格式错误、坏SHA停止，不回旧锁伪称最新版。
- server模式不查cloudflared，local模式查；只有Go查询附带minimum-go参数。
- 使用真实解析器的比较与module-report子模式，假Go输出实际JSON流；核对外部module.mod/module.sum、更新报告、源码锁字节保留、失败未完成、短超时子树回收，以及源码变化停止后续构建。
- SDK查询／下载期间仅向父入口发送TERM，核对本轮监督和实际子进程回收、没有继续构建。
- 模拟目标平台的check／plan函数不编解析器、不下载或写缓存；真实入口的跨宿主平台／发行版拒绝也保持无写入。

官方元数据响应是隔离替身；预发布排除、来源与摘要规则由[解析器单元测试](../../../../部署/公共组件/依赖版本/README.md)验证。夹具通过不代表Linux／Windows原生SDK下载或实机部署通过。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、结果与保留 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

运行中逐项输出PASS；最后输出通过数量和本次`repair-dependency-check-*`临时目录。成功或失败均保留合成夹具与日志以便核对，只回收本组进程，不操作用户已有环境。已有／新建／共享缓存、后续修改与反部署撤回见[原点回归](../../反部署/验证反部署.mjs/README.md)。Mac构建与菜单见[既有构建回归](../../MacOS/【MacOS】验证工作台构建.command/README.md)。

<a id="🔚" href="#前言">返回前言</a>
