# 服务器系统部署目录

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

每个系统在自身目录管理部署文档、`deployment/` 和 `undeployment/`。

## 一、<span id="systems">系统入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 系统 | 资料 | 当前脚本状态 |
| --- | --- | --- |
| macOS | [部署文档](./macOS/部署文档.md) | 已有本机前台启动脚本 |
| Ubuntu | [部署文档](./Linux/Ubuntu/部署文档.md) | 部署、反部署脚本预留 |
| Debian | [部署文档](./Linux/Debian/部署文档.md) | 部署、反部署脚本预留 |
| Rocky Linux | [部署文档](./Linux/RockyLinux/部署文档.md) | 部署、反部署脚本预留 |
| Alibaba Cloud Linux | [部署文档](./Linux/AlibabaCloudLinux/部署文档.md) | 部署、反部署脚本预留 |
| Windows | [部署文档](./Windows/部署文档.md) | 部署、反部署脚本预留；后续仅用 PS1 |

## 二、<span id="policy">源码与数据约定</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

各系统构建同一份 [Go 服务端](../Go服务端/README.md)，不复制业务实现。通用环境变量、手动前台运行及验证边界见 [部署总文档](../../部署文档.md)。

反部署须让运行者明确选择保留或删除业务数据，默认保留；保留必须覆盖加密数据、匹配密钥、附件、配置及必要备份，不能只留密文。删除需要明确确认，并逐项展示范围。当前尚无自动反部署脚本，不以占位 README 代替脚本能力。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
