# <span id="前言">后端外置 Go 测试</span>

![Jobs出品，必属精品](../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行方式](#jobs-toc-heading-1)
- [二、依赖与输出](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

> 通过临时 overlay 保持原包上下文，业务源码与测试源码分别存放。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从项目根执行，只读列出映射：

```sh
python3 './测试/后端/运行测试.py/运行测试.py' --list
```

明确执行已有工具及依赖：

```sh
python3 './测试/后端/运行测试.py/运行测试.py' --run
python3 './测试/后端/运行测试.py/运行测试.py' --run --race --vet
```

`--go` 指定已有 Go 路径；相对路径以项目根为准。`--package ./cmd/workbench` 或 `--package ./internal/workbench` 限定包，可重复。默认执行两个包。无参数时先展示自述并等待回车；无交互输入则停止，CI 使用 `--run` 明确执行。
## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、依赖与输出 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行器只使用 Python 标准库及现存健康 [**Go**](https://go.dev/)；按 `--go`、`GO_BIN`、PATH、`WB_ENV_ROOT` 机器 SDK 查找，不安装或下载。测试以 `GOPROXY=off`、`GOSUMDB=off`、`GOTOOLCHAIN=local` 和 `-mod=readonly` 执行，缺少已锁定依赖直接失败；已有显式 Go 缓存变量优先，默认缓存为机器公共环境。

测试文件物理位置在 [单元](../单元/)，运行器创建系统临时 `Overlay.json`，映射到原 Go module 包位置；临时映射随运行结束清理，源码内不产生测试副本。结果显示在终端，退出码保留；不生成仓内历史报告，不连接现有业务实例。TiDB 连接用例仍需独立 `WB_TEST_TIDB_DSN`，未提供时由原用例明确跳过。`--race` 需要现有 CGO 环境；测试通过不等同正式数据库、目标机或公网部署验收。

[文件写锁回归](../单元/internal/workbench/writer_lock_test.go)使用真实Go子进程和临时数据，覆盖强制退出后的重开、正常释放、旧PID残留恢复、活PID及无效标记保护，以及两个进程竞争时只允许一个写入者；不连接已有业务目录或删除实际运行数据。


<!-- jobs-language-terminal-style-v1 -->

**终端配色保护：** `运行测试.py` 直接运行时，在可可靠保存与恢复配色的交互终端中临时使用黑底白字和统一强调色；正常退出、失败及可捕获中断后恢复进入前的配色，保留原业务清理和退出状态。导入本文件不接管终端；无法可靠保护、纯文本模式或无交互终端时按纯文本约定降级。运行中另行修改的颜色会保留并报告冲突，强制终止后可按运行提示使用独立恢复入口。 模块启动等无法安全重复初始化的场景不重启原程序。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
