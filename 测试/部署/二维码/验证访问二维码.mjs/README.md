# 部署访问二维码隔离验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、执行方式](#jobs-toc-heading-2)
- [二、覆盖与边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

`./验证访问二维码.mjs` 运行各系统真实部署二维码函数，使用临时目录和已准备的 [**Go**](https://go.dev/) 依赖；不连接日常业务、隧道或真实浏览器。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、执行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

需要 Node.js、健康 Go、已按 `go.sum` 准备的 go-qrcode 模块及 PowerShell；MacOS 使用系统 zsh／Bash。Go 可用 `GO_BIN` 指定，PowerShell 可用 `PWSH_BIN` 指定，模块与构建缓存沿用当前 Go 环境。测试设置 `GOPROXY=off`，依赖缺失时直接报告，不自动下载。

```shell
node './验证访问二维码.mjs' --run
```

不传 `--run` 只显示用途，不写文件。明确开始后只写系统临时目录；成功清理本次夹具，失败保留完整位置，Ctrl+C可取消。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、覆盖与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 构建独立锁定模块；MacOS与四个Linux部署副本调用真实工具生成HTML／SVG／PNG。
- 用户／工程师工作台与管理端保留同源地址，回环入口标记“仅本机，手机不可用”。
- 实际菜单函数将“打开扫码页面”映射到当前HTML，通过假浏览器记录目标；地址变化后旧页失效、生成新页，退出标记失效。
- 工具失败保留URL，假后端仍存活；非TTY日志不残留ANSI。
- PowerShell跨宿主执行真实生成、地址变化、失效、失败与回环逻辑；Windows原生进程管理、ACL与各Linux目标机安装仍按原系统验证。

[工具说明与来源](../../../../部署/公共组件/地址二维码/README.md)记录固定依赖、静区和不编码凭据约束。二维码解码、终端实机扫码与手机外网登录／写入／重读需分别核验；此脚本不把页面生成或替身结果当作公网验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
