# [**Go**](https://go.dev/) 服务端 · V3.8 与旧版 API

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

本目录保存一份通用 [**Go**](https://go.dev/) 源码，供不同操作系统部署使用；部署／启动资料位于 [后端部署](../部署/README.md)，不把业务源码按系统复制。当前主入口为 `cmd/workbench` 与 `internal/workbench`，提供 `/api/v38`；`cmd/api`、`cmd/migrate` 和其余旧业务包保留 `/api/v1` 历史基线，不能混用配置、账号及迁移。

第五轮确认的 17 组 P2 仍未修复；这次只整理目录与入口引用，业务范围及原始证据见 [实现范围](../../docs/实现范围.md) 与 [五次回归报告](../../docs/五次回归报告-2026-10-15.md)。旧接口文档不代表 V3.8 的实现或生产验收。

[V3.8 入口](#workbench-entry) · [旧版运行](#legacy-run) · [旧接口合同](#legacy-api) · [旧版验证](#legacy-tests) · [身份与扫码](#legacy-identity) · [账务](#legacy-ledger)

## 一、<span id="workbench-entry">当前 V3.8 入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目录／配置 | 职责 |
| --- | --- |
| `cmd/workbench` | V3.8 启动、备份／隔离恢复 CLI、回环服务和定时任务 |
| `internal/workbench` | 工单、报价／签署、履约、现金／发票、借还、账号、审计及加密存储 |
| `migrations-workbench` | 当前快照表资料，不能用旧 `migrations` 代替 |
| `../../前端/Web网页/维修工作台` | 当前统一网页，根路径由 V3.8 服务托管 |
| `WB_*` | V3.8 配置前缀；与下文旧接口的 `APP_ADDR/TIDB_DSN` 分开 |

macOS 默认使用项目根目录启动入口，详见 [当前启动脚本](../部署/macOS/deployment/【MacOS】启动维修工作台.command/README.md)。其它操作系统目前只有资料预留，通用源码可使用匹配平台的 Go 手动构建；不据此宣称已有对应自动部署脚本。

以下手工命令以本 README 所在目录为工作目录，使用独立演示数据；确认构建成功后再执行启动代码块：

```sh
mkdir -p '../../.runtime'
go build -o '../../.runtime/workbench' ./cmd/workbench
```

```sh
WB_ADDR=127.0.0.1:8098 \
WB_DATA_DIR='../../.runtime/data' \
WB_KEY_FILE='../../.runtime/keys/storage.key' \
WB_WEB_DIR='../../前端/Web网页/维修工作台' \
WB_TIDB_DSN='' \
WB_BACKUP_DIR='' \
'../../.runtime/workbench'
```

数据和密钥按配置位置保存，移动源码不搬动运行数据。文件／TiDB 存储、同源网页、备份恢复及其它系统的手动运行方式见 [总部署文档](../../部署文档.md)；API 规则见 [V3.8 合同](../../docs/workbench-contract.md)。上述命令不执行旧迁移或迁移既有数据库。

## 二、<span id="legacy-run">旧版 API 目录与运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

后端使用 [**Go**](https://go.dev/) 的HTTP服务、领域服务、仓储接口和 [**MySQL**](https://www.mysql.com/) 协议驱动连接 [**TiDB**](https://docs.pingcap.com/tidb/stable/)。默认使用内存演示仓储；配置数据源后使用持久化仓储。演示收款只记账，不实际扣款或转账。

用户／师傅账号采用账号密码与独立 Bearer 会话，主管理员由程序首次自动创建，后台账号在设置中新增。师傅上传私有图片资料，管理员人工通过或驳回；通过后才能接单。固定匿名订单演示可单独关闭。真实支付和生产数据库运行方案仍待后续阶段；`DEMO_MODE=false` 继续拒绝启动。

下列章节仅描述保留的旧 `/api/v1` 基线；V3.8 使用上节入口。

| 目录 | 职责 |
| --- | --- |
| `cmd/api` | 配置、仓储初始化、HTTP服务和优雅退出 |
| `cmd/migrate`、`internal/migration` | 版本迁移、校验和、迁移锁与独立种子执行 |
| `internal/domain`、`internal/service` | 状态、金额、输入规则、下单幂等与工单转换 |
| `internal/repository` | 内存／TiDB实现、过滤分页、事务及汇总 |
| `internal/identity`、`internal/workers` | 账号会话、独立设备、扫码授权／私有图片与人工审核 |
| `internal/ledger` | 平衡流水、事件去重、本人查询、汇总与 CSV 导出 |
| `internal/im` | 下一版本聊天模块边界，没有运行实现 |
| `internal/payment`、`internal/httpapi` | 支付Gateway占位／路由、JSON边界、错误码和健康检查 |
| `migrations`、`seeds` | 版本SQL／不覆盖原数据的演示种子 |
| `api/openapi.yaml` | 共享API、状态、金额与重试契约 |

`go.mod` 声明最低 Go 1.24.0；使用匹配本机的已有工具链。以下旧服务命令的工作目录为本 README 所在的 `后端/Go服务端/`。

```sh
cp .env.example .env
# 修改 .env 后，在当前 shell 加载配置。
set -a
source .env
set +a
go mod download
# 仅设置 TIDB_DSN 时需要迁移；空数据源使用内存。
go run ./cmd/migrate
go run ./cmd/api
```

本桌面交付的 [部署目录](../部署/README.md) 只包含当前 macOS 启动脚本及其它系统预留资料，未提供旧 API 的完整容器／集群部署包。旧服务须另行核对环境、迁移和数据源，不因目录存在即视为已部署。

| 配置 | 默认值／语义 |
| --- | --- |
| `APP_ADDR` | `127.0.0.1:8080`；端口须1—65535 |
| `ADMIN_WEB_DIR` | `../管理后台页面` |
| `TIDB_DSN` | 空时使用内存，重启丢失账号、会话、订单、图片元数据和账本 |
| `WEB_DIR` | `../../前端/Web网页/旧版用户网页`；PC 扫码入口 `/portal/` |
| `WORKER_ASSET_DIR` | `./private-uploads`；私有审核图片目录 |
| `ADMIN_BOOTSTRAP_USERNAME/PASSWORD` | 仅兼容旧环境的额外初始化账号；默认主管理员自动创建，无需填写；已有账号不覆盖 |
| `SESSION_TTL_HOURS` | 默认 24，可配置 1—168；每设备独立有效期 |
| `ALLOW_ANONYMOUS_DEMO` | `true`；仅固定 customer-demo／worker-demo 的订单演示 |
| `DEMO_MODE` | `true`；`false`仍拒绝启动 |
| `ALLOW_DEMO_NETWORK` | `false`；容器`:8080`／受控局域网须显式`true` |
| `SEED_DEMO_DATA` | `true`；种子只INSERT IGNORE，不修改已有师傅 |

初始化管理员不会覆盖已有密码或把普通账号提升为管理员。宿主端口仍默认回环绑定，受控局域网只用于联调；数据库权限、HTTPS、备份和生产运维仍需另行配置。私有文件和数据库中的图片元数据必须配套保留。

## 三、<span id="legacy-api">旧 API 与跨端约定</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

完整 [**OpenAPI**](https://spec.openapis.org/oas/latest.html) 见 [`api/openapi.yaml`](./api/openapi.yaml)。列表继续返回数组，空数据是 `[]`。

- 正常接口使用 `Authorization: Bearer <token>`，账号和角色由服务端会话确定。认证头无效时401，不降级为匿名。管理员、审核资料、图片和账务始终要求真实会话，不能用角色头伪造。
- 开启匿名演示时仅允许固定 `customer-demo`／`worker-demo` 的订单流程，不能指定任意主体或管理员。关闭后业务接口均需登录。
- 分类暂保留现有9个中文名称；设备1—160、故障1—4000、地址1—500字符，去除首尾空白。预约时间允许空字符串表示协商，非空须RFC3339并含时区，规范化为UTC；例如`2026-10-10T10:00:00+08:00`。
- JSON正文限64 KiB，禁止未知字段及尾随第二对象；超限413，非法输入400。无负载动作允许空正文或`{}`，报价必须提供`quoteCents`。
- 订单列表支持`limit=1..200`（默认100）、`cursor`、`status`。仓储按主体过滤，按`createdAt`和`id`降序稳定分页；下一页放在`X-Next-Cursor`，不存在表示结束。翻页保持端点、身份与筛选一致；状态变化重新刷新首屏。
- 管理订单、师傅、结算各查询自己的数据，看板独立聚合全量指标，不受limit影响。师傅分页按ID降序。
- 错误新增稳定`code`及人类可读`message`，保留旧`error`。响应含`X-Request-ID`，错误正文也含`requestId`。常见code：`invalid_input/forbidden/not_found/invalid_state/idempotency_conflict/body_too_large/retryable/request_timeout`。

### 3.1、创建重试与幂等 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

下单POST使用 `Idempotency-Key`，限制1—128位可见ASCII字符。作用域为客户ID＋key；相同key及规范化正文返回同一订单ID与最新状态（201），同key换正文409。未提供key兼容旧客户端，但没有重复创建保护。

TiDB把请求映射与订单写入同一事务，唯一键保护并发创建；内存由同一锁保护。响应丢失、503 `retryable`或超时后，保留原key再请求取得结果，不能换新key把未知结果当失败重建。新订单或明确修改内容才用新key。客户端演示写入不得自动重放为真实订单。

### 3.2、金额与支付边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

报价为整数人民币分，范围1—100000000分（最多100万元）。演示先算师傅份额：`(amountCents * 85 + 50) / 100`整数除法，平台取差额；10分拆为师傅9／平台1。金额范围与汇总溢出均检查；保存规则版本`demo-worker85-half-up-v1`。旧完成记录保留原金额及空版本，不改历史数据。85／15是演示参数。

演示收款在TiDB事务中推进订单、写支付／唯一结算并追加模拟收款分录；已完成的演示收款重复调用返回原订单200，不多记账，也不覆盖已有结算核销状态。人工核销在同事务更新演示状态并追加模拟核销分录，首次／重复均204，缺失404，不会真实转账。

支付意图先校验归属、待付款状态与服务端金额。三个渠道均501 `payment_not_configured`；不存在订单404，非本人403，状态不适合409。接口保留完整Gateway结果和稳定JSON字段，不提供真实凭据、渠道或回调。真实支付接入后再衔接渠道回调、退款、对账和真实结算，当前不做实际资金操作。

## 四、健康、时限与迁移 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`GET /healthz`仅存活；`GET /readyz`在2秒内检查仓储／DB连接、必要列和完成版本，返回200或503。startup/liveness用前者、readiness用后者，不能因短暂DB故障反复重启。

HTTP处理预算8秒、请求头5秒、总读取10秒、写响应12秒、空闲60秒；业务DB操作3秒，驱动连接／读／写缺省各5秒。超时可能是结果未知，创建重试保留key。

迁移按`NNN_name.sql`排序，记录版本、SHA256、dirty及完成时间。数据库lease锁限制并发，整次迁移2分钟，锁租约5分钟、每条SQL前续租。已执行SQL不可原地改写，新增变更用新版本。

- 001建表，002幂等表，003分润版本列，004账号／设备／扫码／师傅资料与图片元数据，005账务流水与分录。首次接管旧无版本schema，通过CREATE IF NOT EXISTS和ADD COLUMN IF NOT EXISTS保留记录，并建立版本基线。
- DDL不能整体事务回滚，失败保留dirty，启动拒绝自动继续。先核查失败SQL和schema，确认部分执行能够安全重复，再显式恢复；不能改checksum或删元数据掩盖失败。
- 内置SQL可重复执行；未来迁移需单独评估续跑与备份。切分识别引号、分号及普通注释，不支持DELIMITER、存储过程或可执行注释。
- `seeds/demo.sql`独立运行；`SEED_DEMO_DATA=false`／`-seed-demo=false`跳过。INSERT IGNORE保留既有师傅资料。不会自动恢复备份或把Docker数据迁往Kubernetes。

```sh
# 检查dirty版本后明确恢复，示例文件名替换为实际失败版本。
go run ./cmd/migrate -resume 003_profit_rule.sql
# 仅schema，不插入演示数据。
go run ./cmd/migrate -seed-demo=false
```

## 五、<span id="legacy-tests">旧版验证与扩展</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```sh
go test -race ./...
go vet ./...
gofmt -l cmd internal
```

默认测试不连接现有实例。TiDB契约测试仅在显式设置变量时运行：必须是回环TCP、数据库名以`repair_test_`开头的独立测试实例。

```sh
REPAIR_TEST_TIDB_DSN='root@tcp(127.0.0.1:临时测试端口)/repair_test_local?parseTime=true&tls=false' \
  go test -race -count=1 ./internal/repository
```

测试创建单独`repair_test_contract_*`数据库，结束时删除自己创建的数据库；**不要指向业务数据库所在实例**。覆盖内存、TiDB悲观／乐观事务、过滤分页、并发幂等／接单／收款、重复人工核销；迁移覆盖新建／重复、旧schema采纳、checksum、dirty恢复、并发锁与seed不覆盖。示例端口替换为专用TiDB端口，不是API的8080／8081。

后续保持模块清楚的单体。账号和人工审核是首期基础能力，不包含 OCR、第三方实名核验或支付机构资质认证。真实资金操作、生产数据库运行、备份恢复和上线监控按后续阶段推进，见[心愿单](../../docs/心愿单.md)。

## 六、<span id="legacy-identity">旧版登录设备、扫码与人工审核</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

公开注册只允许 customer／worker；后台账号由已登录管理员在设置中创建，权限为 admin（管理员）或 operator（普通账号）。默认主管理员首次启动自动初始化为 `admin / admin`，重复启动不覆盖已有密码或状态。普通账号不能审核身份、创建账号、重置他人密码或封停账号；允许处理工单、查询账务及修改自己的密码。新增账号不创建会话；注册／登录返回 token、expiresAt、user 和 session；GET /api/v1/auth/me 返回当前用户并附设备会话信息。`/api/v1/admin/accounts` 分页查询全部后台和移动账号，管理员可新增后台账号；`/{username}/password` 重置任意用户密码，`/{username}/status` 封停或解封账号，禁止封停自己。`POST /api/v1/auth/password` 核对当前密码后修改自己的密码。`POST /api/v1/auth/recovery-code` 生成仅显示一次的恢复码；忘记密码可用 `POST /api/v1/auth/password-reset` 验证并消费恢复码。封停、修改或重置密码都会撤销所有旧会话和已授权二维码；解封不会复活旧会话。账号及密码操作失败不伪造本地成功。

密码使用随机盐的 PBKDF2-SHA256 600000次派生，数据库不保存明文密码或明文会话 token。

手机登录发送 device.kind=mobile，密码认证后的手机会话具有 manage_devices／authorize_qr。桌面密码或扫码会话没有这两项能力；扫码不可通过声称 mobile 自行提升权限。设备类型是客户端标识，不提供硬件可信证明。每个设备 token 独立；logout 只撤销当前 token，手机下线不影响 PC。手机可通过 GET /auth/devices 和 DELETE /auth/devices/{id} 查看／撤销本人指定设备（以上路径均加 /api/v1）。

PC 创建两分钟扫码请求，保留私有 pollToken，本地将 qrPayload 生成二维码；手机扫描后 inspect 核对设备信息，明确 approve／reject。二维码不含 Bearer token。PC poll 在批准后原子兑换一次独立会话，重复返回 consumed；领取响应丢失需要重新扫码，不能把 pending／consumed 当成功。未配置服务时不能模拟认证或授权成功。

师傅以 multipart 单个 file 上传 JPEG／PNG：服务端校验实际格式、尺寸与完整解码，最多5 MiB；图片仅本人／管理员读取。申请包含展示名、联系电话、区域、技能、说明、1—6个本人图片ID与 expectedRevision；首次版本为0。管理员查询申请后以 decision、note、expectedRevision 审核，驳回必填原因；过期版本409。重新提交回到 pending 并暂停新接单，已领取工单继续履约。

## 七、<span id="legacy-ledger">旧版账务查询与后续接入</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

收款借记平台资金、贷记师傅待结算与平台收入；核销借记师傅待结算、贷记平台资金。金额全部为整数分，每条流水借贷相等。订单／支付／结算和账本写入同锁或同一 TiDB 事务，唯一事件键防止重复记账。流水不可原地改金额；内部保留冲正能力，但没有开放冲正写 API，避免业务状态与账本分离。

旧的演示收款和已核销结算在启动时幂等补录历史流水，保留演示来源。真实微信／支付宝／聚合渠道仍501，不产生到账或付款流水。

| 接口（均 /api/v1） | 范围 |
| --- | --- |
| GET /admin/ledger/journals、/summary | 管理员查账／筛选汇总 |
| GET /admin/ledger/export.csv | 管理员导出筛选范围，最多10000条，超限需缩小范围 |
| GET /ledger/journals、/summary | 当前用户或师傅本人；/me/ledger/ 同合同兼容入口 |

查询支持 mode=simulated／actual（模拟／真实隔离）、kind、status、channel、orderId、customerId、workerId、from／to、limit／cursor。个人接口强制本人范围，不能越权筛选他人。时间使用RFC3339，范围为[from,to)，列表按 occurredAt／id 分页，X-Next-Cursor 返回下一页。汇总覆盖全部筛选结果，不受列表页大小影响。

scope=filtered_movements 表示筛选范围的发生额：收款、平台收入、师傅应得、核销，以及平台资金／待结算借贷净发生额；这些不是银行余额，日期筛选不包含期初。CSV 保留账本来源和关联标识，并处理公式注入字符。真实渠道尚未接入，因此 actual 当前为空，不把模拟账转换为真实账。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
