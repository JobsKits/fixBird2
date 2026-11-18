# 后端目录说明

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、目录职责](#contents)
- [二、维护边界](#boundary)
- [三、工作台接口契约](#api-contract)
  - [3.1、身份与提交规则](#identity-contract)
  - [3.2、分页、详情与字段](#read-contract)
    - [3.2.1、职责读取矩阵](#field-permissions)
  - [3.3、工单、借还与采购动作](#action-contract)
    - [3.3.1、备注字段 patch](#remark-patch-contract)
    - [3.3.2、余项办理](#obligation-resolution-contract)
    - [3.3.3、先款约定与执行门槛](#execution-payment-contract)
    - [3.3.4、验收签署与质保日历](#acceptance-history-contract)
  - [3.4、设置、账号与安全审计](#audit-contract)
  - [3.5、幂等持久化与隔离恢复](#persistence-contract)
  - [3.6、网页响应校验与离线行为](#client-contract)
  - [3.7、个人工作日志与独立事件提醒](#work-log-contract)
  - [3.8、库存明细与采购私有附件](#inventory-purchase-contract)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

业务服务器使用同一份 [**Go**](https://go.dev/) 源码；系统差异集中到部署目录。

## 一、<span id="contents">目录职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目录 | 内容 |
| --- | --- |
| [Go 服务端](./后端代码/README.md) | 单一 Go module，仅当前 V3.8 API |
| [管理后台页面](../前端/后台管理端/README.md) | Flutter 与 Web 两套管理客户端，共用界面规范 |
| [部署](../../部署/README.md) | 各服务器系统的部署文档、部署与反部署入口 |

## 二、<span id="boundary">维护边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

不要为不同操作系统复制 Go 业务源码；按目标系统及架构分别构建。管理后台页面位于 `../前端/后台管理端/`，仍是浏览器前端代码。当前运行入口与平台验证边界见 [根说明](../../README.md)。

## 三、<span id="api-contract">工作台接口契约</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[工作台接口约定](#identity-contract)是当前后端行为合同。管理端 UI 共享契约另归[前端后台管理端](../前端/后台管理端/共享契约/admin-ui.json)，两者职责不同。

后端使用 [**Go**](https://go.dev/)，提供本机加密演示存储与 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 适配。实际字段及校验以 `./后端代码/internal/workbench/models.go`、`actions.go` 与 `http.go` 为准；运行范围见 [实现范围](../../需求/技术方案与实现范围/技术方案与实现范围.md)。

[身份与提交](#identity-contract) · [分页与读取](#read-contract) · [职责矩阵](#field-permissions) · [业务动作](#action-contract) · [审计](#audit-contract) · [存储与恢复](#persistence-contract) · [网页与离线](#client-contract)

### 3.1、<span id="identity-contract">身份与提交规则</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

管理端Flutter／Web及用户端iOS／Flutter／Android／鸿蒙／微信小程序统一使用本合同。各端实现与验收范围见 [交付清单](../../需求/交付与运维清单/交付与运维清单.md)。

Base `/api/v38`，JSON；钱用整数分，版本用正整数。入口为 `代码/后端/后端代码/cmd/workbench` 和 `代码/前端/PC端/Web/维修工作台/`。业务写请求带 `Idempotency-Key`；登录／退出按各自会话接口执行。证据原件下载返回文件，其余接口采用 JSON。错误 `{error,message}`，401/403/409/422 不作为成功。

持久化接口：`Load() ([]byte,error)`（首次返回 nil,nil）、`Save([]byte) error`。业务入口 `workbench.New(p Persistence) (*Service,error)`、`svc.Handler(webDir string) http.Handler`。业务提交先克隆、校验，再原子保存和交换内存状态；失败不留下半套主状态／明细。

登录 `POST /login {username,password}` => `{token,actor}`；Bearer token；GET `/session` => actor；POST `/logout`。合成账号见 [演示账号](../../README.md#demo-accounts)。`customer-b` 检查跨公司隔离，`customer-peer` 检查同企业当前经办人交接。token 仅保存在服务内存；账号 `authVersion` 变化撤销旧会话，启用账号也不会复活停用前会话。

普通账号可按下表注册和通过绑定邮箱重置密码；登录字段 `username` 同时接受用户名或已绑定邮箱。既有账号的可选持久字段 `Account.email` 缺省为空，继续按原用户名登录；不会猜测或自动绑定邮箱。公开注册只创建独立企业的 `customer`，不接受角色、企业或授权版本字段，也不自动登录。内部账号仍由既有管理流程维护。

| 普通认证接口 | 输入与结果 |
| --- | --- |
| `POST /auth/email-code` | `{email,purpose:"register"\|"reset_password"}` → `{ok,message,expiresIn:600,retryAfter:60,delivery:"email"\|"demo",demoCode?}` |
| `POST /register` | `{username,name?,email,code,password,confirmPassword}` → 201 `{ok,message,actor}`；空姓名使用用户名 |
| `POST /reset-password` | `{email,code,password,confirmPassword}` → `{ok,message}`；成功后清除此账号全部会话并推进 `authVersion` |

用户名为3～32个字母、汉字、数字、下划线或短横线；密码至少8个字符、最多256字节，两次输入一致。注册、邮箱找回重置、客户目录创建账户及登录均拒绝表情符号，返回422 `invalid_password` 与“密码不能包含表情符号”；两次密码输入均校验，拒绝时不消费验证码、不写新凭据、不推进授权版本或撤销已有会话。ASCII数字、`#`、`*`、普通标点、中外文字及文本呈现的 `©®™` 保留；心形、旗帜、肤色、ZWJ表情、键帽与显式表情呈现选择符均拒绝。含普通文字的ZWJ连字不因同时含数字而误判。旧普通密码摘要保持原样；旧表情密码不能再登录，可通过绑定邮箱重置，不自动改写历史凭据。邮箱规范化为小写且唯一。验证码分用途、10分钟有效、最多5次错误尝试、成功后单次消费；同邮箱同用途60秒后可重发，同连接来源10分钟最多20次发送，内存挑战及速率表均有总量上限。注册／重置先克隆、校验并原子持久化，再消费验证码；保存失败不创建半个账号、不改密码、不提前撤销会话，同码可重试。验证码仅保存内存摘要，重启后需重新申请。

密码表情属性依据 [**Unicode Emoji 18.0**](https://www.unicode.org/Public/18.0.0/ucd/emoji/emoji-data.txt) 与 [UTS #51](https://www.unicode.org/reports/tr51/tr51-31.html)，固定表来自[桌面共用契约](../前端/PC端/原生共享契约/password-emoji-ranges.json)，[Unicode许可](../前端/PC端/原生共享契约/Unicode-LICENSE.txt)随源码保留。生成的Go静态表不依赖宿主字符库或网络；非ASCII `Emoji` 属性码点除上述三个文本符号外均拒绝。三个符号仅在后续局部序列连接ZWJ或tag时拒绝，中间允许组合标记与ZWNJ；遇普通文字或数字结束该序列，因此 `©123क्‍ष` 保留，`©‍`、`©́‍` 拒绝。正式[密码策略回归](../../测试/后端/单元/internal/workbench/password_policy_test.go)核对共用表全量范围及API原子性；当前没有独立改密码端点，新增入口须复用同一策略。

仅当持久状态明确为 Demo、HTTP 连接来源与 Host 均为本机回环、没有转发来源头且未配置SMTP时，接口返回 `delivery:"demo"` 与 `demoCode`。其它情况必须真实发送邮件；未配置或投递失败返回503 `email_unavailable`，不报告假成功、不回显验证码或SMTP诊断。配置由当前后端进程的 `WB_SMTP_HOST`、`WB_SMTP_PORT`（默认587）、`WB_SMTP_FROM`、`WB_SMTP_USERNAME`、`WB_SMTP_PASSWORD`、`WB_SMTP_TLS_MODE`（默认 `starttls`，可选 `implicit`）提供；只使用标准库SMTP、至少TLS 1.2及证书校验，不自动安装服务或改变系统网络。真实邮箱投递与生产运维另行验收。

`GET /healthz` 的 `mode` 取自当前持久状态：`settings.demo=true` 为 `synthetic_demo`，否则为 `production`。两套后台仅在明确的 Demo 标识下自动使用 `admin / 1234` 建立会话；该密码仅对 Demo 中有效的管理员生效，不启用停用账号、不开放匿名业务 API。正式与未知环境均要求人工登录，失联不能降级为免登录。

网页以成功登录返回的身份为当前会话基准。后续快照的 `actor` 必须为 `active`，且 `id/role/companyId/authVersion` 与该基准一致，才可采用其资料；不会用快照中的另一个身份替换当前会话。切换账号期间的展示与恢复行为见 [网页与离线](#client-contract)。

账号状态只接受 `active/disabled`，只有明确 `active` 的有效账号可登录、鉴权、读取及写入；空状态、未知状态和待定状态都不取得授权。启动要求完整账号身份与凭据元数据：稳定 ID、登录名、姓名、企业、合法角色与状态、正整数 `authVersion`、盐及有效摘要。账号清单为空、必要字段缺失、ID／登录名重复或授权结构非法时拒绝启动，不默认激活或替换既有凭据。隔离恢复还须满足 [最新授权约束](#persistence-contract)。

时间字段使用含时区的 RFC3339，例如 `2026-10-14T10:30:00+08:00`，金额使用整数分。拒绝未知请求字段。全部业务变更需要请求键，既有相同键与内容不重复记账；相同键不同内容返回 409。

### 3.2、<span id="read-contract">分页、详情与字段</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 接口 | 返回与范围 |
| --- | --- |
| `GET /bootstrap` | `{actor,states,orders,orderPage,metrics,capacity,parts,loans,purchases,settings}`；默认首 30 条轻量工单，按当前身份与企业过滤 |
| `GET /orders?page=1&pageSize=30&q=&status=&filter=&documents=&payment=` | `{items,total,page,pageSize,totalPages}`；服务器搜索、筛选、分页，每页最多 200 条 |
| `GET /orders/{id}` | 当前授权的完整 Order |
| `GET /customer-directory` | `{customers:[{id,name,accounts:[Actor],companies:[{id,name}]}],canManage}`；管理员／调度读目录，客户只读本人账户与所属企业，其他角色拒绝 |
| `GET /export` | 管理员／调度／财务／客户的完整授权数据包；其他角色拒绝 |

`orderPage` 包含 `page,pageSize,total,totalPages`。`metrics` 包含 `openCount,settlingCount,remainingCents,readyCount,tasksCount,blockedCount`，按完整可见范围计算，不只统计当前页。`capacity` 包含 `requestCount,threshold,warning,mode`，`threshold=10000`、累计 8000 键开始预警；不是停止写入上限。

分页摘要带 `isSummary=true`，`events/evidence/quoteHistory/costs/commissions` 为空，不含 `acceptanceRecords`，报价签名和验收签名为空，不提供完整响应图。客户端打开详情须重新 GET 详情，不能将摘要当成完整记录。完整详情、授权导出及写响应继续按 [职责矩阵](#field-permissions) 返回必要字段。库存、借还与采购列表暂未分页，仍随 bootstrap 返回。

Order JSON：`id,number,version,type`（mail/onsite/sale）、`customer,customerId,companyId,project,device,description,status,outcome,ownerId,assigneeId,createdAt,updatedAt,remark,customerNote,quote,documents,invoices,cash,evidence,events,visits,outsource,costs,commissions,issues,obligations,warranty,originalOrderId,summary`，可选 `acceptanceRecords`，旧快照无此字段仍可读取。

quote：`version,amountCents,description,warrantyMonths,paymentTerms`（cash/credit）、`prepayCents,startRequiresPrepayment,validUntil,approved,signed,signature,signer,signedAt,autoAccept`。`startRequiresPrepayment` 为明确约定的维修先款开修开关，缺省及旧快照未提供时为 false；预付款金额本身不等于先款约定。
documents：`requirement`（unknown/required/none）、`reason,version,prepared,sent,recipient,files`（evidence IDs）。
invoice条目：`id,number,amountCents,files,voided`；Order `invoiceRequirement,invoiceReason,invoiceDueCents`。
cash条目：`id,amountCents,kind`（receipt/refund）、`purpose,receipt,collector,occurredAt,verified,handedOver`。
evidence条目：`id,name,kind`（text/image/video/audio/document）、`text,mime,uploaderId,createdAt,deleted,stage`。GET `/orders/{id}/evidence/{evidenceId}` 鉴权下载原件。上传包含在 evidence action payload `{name,kind,text,mime,data}`（base64，无 data URL）。
summary：`documentStatus,invoiceStatus,collectedCents,receivableCents,remainingCents,overpaidCents,pendingCashCents,invoiceCents,nextTask,missing`（string[]）、`warrantyLabel`；服务端派生，客户端只读。

`acceptanceRecords` 为只追加的人工验收签署历史，每条含 `id,passed,signature,signerId,signerName,signedAt,note,quoteVersion,orderVersion`，不通过时另含对应新异议的 `issueId`。`signature` 是已校验的 PNG data URL，`signedAt` 为含时区时间，`orderVersion` 是本次提交后的工单版本。当前客户经办人及 `admin/dispatcher/finance` 可在授权完整详情、动作响应和导出中读取记录与原件；其他角色不读取，摘要不带记录。历史签署者身份不会随经办人交接被改写，但旧客户不因曾签署而保留当前读取权限。

#### 3.2.1、<span id="field-permissions">职责读取矩阵</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 角色 | 成本／提成 | 现金与内部资料 |
| --- | --- | --- |
| `admin/dispatcher/finance` | 全部 | 授权工单完整财务、内部备注、行程、转包及余项 |
| `engineer` | 仅 `OwnerID` 为本人的成本；无提成 | 本人登记现金及待核实金额、已核实对客收款；保留维修备注、行程与本人余项 |
| `warehouse` | 仅 `OwnerID` 为本人的成本；无提成 | 本人登记现金及待核实金额、已核实对客收款；无内部备注／行程／转包明细，保留本人余项 |
| `qc` | 无成本、提成 | 已核实对客收款；无内部备注／行程／转包明细，保留本人余项 |
| 客户／外包／供应商 | 无成本、提成 | 沿用外部脱敏，只读其工单授权和对客资料；供应商不获维修工单权限 |

工程师／外包还须为当前 `assigneeId`，客户须同时符合当前 `customerId` 与企业，不因同企业自动获得另一联系人工单。非完整财务角色不读他人待核实现金及经办身份。本人登记成本事件保留，他人成本及提成事件移除；财务审核、现金核实／交接、发票、红冲、应收调整与资料办理事件的内部 `note` 不返回。

备注写入与读取使用同一职责边界，详见 [备注字段 patch](#remark-patch-contract)。财务可读完整余项，不代表可代办他人余项；办理条件见 [余项办理](#obligation-resolution-contract)。

证据元数据与原件下载使用同一职责判断，先校验工单可见，已删证据不可读。公开资料及本人上传资料可读；其他私有资料按阶段放行：工程师可读收件、检测报价、待客户确认、待执行、维修、质检及待交付；仓库可读收件、待执行、质检、待交付与待验收；QC 可读检测报价、维修与质检。未公开的付款资料／发票引用仅完整财务角色与上传人可读，未知阶段默认拒绝。当前附件没有正式用途分类，阶段不能证明内容属性，真实敏感资料仍需用途与授权模型。

### 3.3、<span id="action-contract">工单、借还与采购动作</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

POST `/orders` => Order。创建与业务动作都有权限及幂等校验，已有对象变更还须提供当前版本。

创建字段为 `{type,customer,customerId,companyId,project,device,description,remark?,customerNote?,files?}`。`customerId` 必须是真实有效的客户Actor稳定ID，`companyId` 必须与该账户当前所属企业一致；客户本人提交时服务端固定为本人和本企业。不能把下拉显示名或任意新字符串当作账号／授权企业。

客户档案通过 `POST /customer-directory` 原子维护，仅 `admin/dispatcher` 可写，需请求键。输入 `{operation:"customer"|"company"|"account",customerId?,name?,companyName?,companyId?,username?,accountName?,password?,confirmPassword?}`：新建客户填写客户名，可同时带首家企业名和初始账户完整创建；新企业填写已有客户ID和企业名；新账户填写已有客户ID、该客户的企业ID、唯一用户名及至少8字符的一致密码，显示名缺省使用客户名。响应为当前授权目录，并附 `id/customerId/accountId/companyId` 供端侧联动选择。新账户只能是 `customer`，不接受任意角色或授权版本；密码只用于生成独立盐摘要，不返回、不进入日志。客户分组持久为 `State.customers`，包含多账户及多企业，Actor当前单企业权限保持原语义；旧快照无需改写，目录从现有客户账户／工单补足当前分组。

设备图片／视频不设置应用单件大小、合计大小或数量上限，支持PNG／JPEG／GIF／WebP与MP4／MOV／WebM。原生端先 `POST /order-uploads` 上传原始文件流：Bearer与1—128字符的 `Idempotency-Key` 必填，`Content-Type` 为原件MIME，`X-File-Name` 为UTF-8百分号编码文件名；请求体是原始字节，可使用chunked。201响应仅含 `{id,name,mime,size,sha256}`，`size` 为64位字节数。同一账号／企业／授权版本的同键同原件返回同一ID，异内容409；中断上传清除临时文件，成功但回执丢失时使用原键重传取得原ID。

建单 `files` 使用 `[{uploadId}]`，也可附 `name/mime/size/sha256` 逐项核对。仅能绑定本账号当前企业与授权版本的未取消、未绑定原件；整单保存失败时全部绑定回滚，可用原意图重试。`DELETE /order-uploads/{id}` 可重复取消自己的未绑定原件并清除旁件，已绑定返回409；未知或他人原件返回404。未绑定原件不自动过期，草稿关闭时由客户端取消已知ID；尚未知ID的成功上传先用原键取回回执再取消。

旧端 `[{name,mime,dataBase64}]` 仍兼容，Base64不带data URL前缀，设备建单取消原45MiB请求上限；该兼容路径仍会在内存处理JSON，新原生端应使用流式接口。实际格式／视频容器校验失败时不创建空工单。响应Evidence仅含元数据、`size/sha256`与证据ID，剥离原件与私有旁件标识；下载沿用 `/orders/{id}/evidence/{evidenceId}` 的当前工单授权及审计。流式上传／下载单请求清除固定读写deadline，仍响应连接断开与Context取消；普通JSON和借还图片接口保持各自限制。部署反向代理如设置请求大小或传输时限，需同步为原件路由配置，不能将基础设施限制误写为应用上限。

POST `/orders/{id}/actions` => Order，body `{type,version,payload}`。当前实现动作 type：

- intake `{ownerId,assigneeId}`；receive `{note}`；assign `{assigneeId}`；diagnose `{note}`；report `{note}`。
- quote `{amountCents,description,warrantyMonths,paymentTerms,prepayCents,startRequiresPrepayment,validUntil,autoAccept}`；approve_quote `{note}`；sign_quote `{signature,quoteVersion}`（signature是canvas PNG data URL，检查空白；仅客户本人）。
- start `{note}`；finish `{note}`；qc `{passed,note}`；stock_ready `{partId,quantity}`（销售）；dispatch `{carrier,tracking,note}`；deliver `{note,deliveredAt}`；accept `{signature,passed,note}`。
- requirements `{documentRequirement,documentReason,invoiceRequirement,invoiceReason,invoiceDueCents}`；documents `{prepared,sent,recipient,files}`。
- cash `{amountCents,kind,purpose,receipt,occurredAt}`；verify_cash `{cashId}`；handover_cash `{cashId}`；invoice `{number,amountCents,files}`；void_invoice `{invoiceId,reason}`；adjust_receivable `{amountCents,reason}`。
- remark `{remark,customerNote}`；evidence `{...}`；delete_evidence `{evidenceId,reason}`。
- issue `{note,ownerId,dueAt}`；resolve_issue `{issueId,note}`；failure `{reason,note,amountCents,returnRequired}`（reason customer_refused/company_refused/unrepairable/cancelled/negotiated）；obligation `{title,ownerId,dueAt}`；resolve_obligation `{obligationId,note}`。
- visit `{id,plannedAt,feeMemo,note,reason}`；start_visit `{visitId}`；outsource `{provider,contact,destination,note}`；cost `{category,amountCents,note}`；approve_cost `{costId}`；commission `{person,amountCents,note}`；settle_commission `{commissionId,note}`。
- complete `{note}`；reopen `{reason}`；rework `{note,free}` 返回新子Order。
- review_acceptance `{note}`：公司负责人核实停机期间线下异议后恢复验收扫描；handover_contact `{customerId,reason}`：同企业有效经办人接替，保留旧签署快照并撤销旧联系人此单权限。

#### 3.3.1、<span id="remark-patch-contract">备注字段 patch</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`remark` 动作的 `{remark,customerNote}` 是按字段提交的 patch：省略字段或提交 `null` 均保留原值，仅校验实际准备写入的字段，不能把脱敏响应里的空备注或未显示字段当成清空指令。授权角色显式提交空字符串可以清空该字段；未被修改的旧字段不会因已有长度问题而被覆盖。

| 角色 | 内部 `remark` | 对客 `customerNote` |
| --- | --- | --- |
| `admin/dispatcher/finance` | 可读、可写；显式空串可清空 | 可读、可写；显式空串可清空 |
| 当前执行工程师 | 在可见工单可读、可写；显式空串可清空 | 可读、可写；显式空串可清空 |
| `qc/warehouse` | 不读取、不修改；省略、`null` 或旧客户端空串均保留，非空（含纯空白）提交返回 403 | 可读、可写；显式空串可清空 |
| 客户／外包／供应商 | `remark` 动作本身拒绝 | 不能通过 `remark` 动作修改；读取仍服从工单权限 |

独立合成演示的 `remark` 动作采用本节字段更新语义和角色矩阵，包含 `finance` 的备注权限。两字段只接受字符串或 `null`；字段类型或权限错误时整次拒绝，保留原工单台账、版本与事件。

#### 3.3.2、<span id="obligation-resolution-contract">余项办理</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`resolve_obligation {obligationId,note}` 仅向管理员、调度、工程师、仓库、质检及财务开放角色入口，并继续检查具体任务：当前任务责任人，或 `admin/dispatcher`，才可将未完成任务标为办妥。财务不得因可读全部余项而代办他人；客户、外包、供应商不获得该动作。`allowedActions` 只有在当前账号至少有一项可办理的未完成余项时才包含此动作，指定他人未获办理授权的余项仍返回 403，不推进状态、不留下半套业务变更。

POST `/loans {orderId,partId,quantity,borrowerId,dueAt,note}` => Loan；POST `/loans/{id}/actions {type,version,payload}`，return `{quantity,condition}` good/quarantine；consume/dispose `{quantity,reason}`；transfer `{quantity,ownerId,dueAt,reason}`。Loan `id,version,orderId,partId,partName,quantity,returnedGood,returnedQuarantine,consumed,disposed,outstanding,borrowerId,createdAt?,dueAt,note`。新借出由服务端本次事务时钟写入 `createdAt`，表示实际借出记录创建时间，随快照持久化并在列表、配件明细、幂等重试及重启后保持；客户端不能传入伪造。旧单缺失则省略，展示应标为时间未记录，不以读取时当前时间、到期时间或图片补录时间回填；后续归还与转交不改写借出时间。

借出输入和 return payload 可同时提交 `attachments:[{name,mime,dataBase64}]`；return 另支持 `note`。原生新表单必须选择至少一张实际图片，显式空数组返回422；旧客户端省略此字段保持原接口语义，旧记录无图显示“未登记”，不据此补造历史凭据。图片与本次数量、库存、版本在同一事务提交，任一校验或保存失败整次回滚；未知写结果按原 `Idempotency-Key` 核对重试。

Loan 的可选 `files` 元数据含 `id,name,mime,size,uploaderId,createdAt,stage,quantity,condition?,note?`，其中 `stage` 为 `borrow/return`。只接受PNG／JPEG／GIF原件，核对MIME、魔数和有效尺寸，单图最多8MiB、单边8192像素、总像素3200万，每借用单全部阶段合计最多8图／32MiB；借还JSON请求上限45MiB以容纳base64。原件随私有快照保存，所有公开列表、明细及幂等重试投影均剥离 `dataBase64`。

`GET /loans/{id}/files/{fileId}` 必须带Bearer，返回图片原件；管理员、仓库、调度与当前借用工程师可读，沿用借用台账权限，不提供公开URL。旧单补录使用 `POST /loans/{id}/files {version,stage,quantity,condition?,note,attachments:[...]}`，仅管理员／仓库可写，成功版本加一且不改变库存；归还阶段的补录数量不能超过该成色已实际归还的数量。原件读取先保存必要审计，保存审计失败时拒绝下载。

Part `id,name,sku,available,quarantine`；POST `/purchases {supplier,partId,quantity,unitCents,note,attachments?}` => Purchase；POST `/purchases/{id}/receive {version,quantity,note}` => Purchase；Purchase `id,version,supplier,partId,quantity,received,unitCents,note,files?`。库存明细与采购附件的字段、权限及原件路径见[专节](#inventory-purchase-contract)。

POST `/auto-accept` 受控执行到期扫描（停机异议待核实）；GET `/healthz`。后台在启动和每分钟执行同一验收校验，不绘制客户签章。

#### 3.3.3、<span id="execution-payment-contract">先款约定与执行门槛</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

维修单仅在明确约定 `startRequiresPrepayment=true` 时，要求约定预付款已由财务核实后才允许开修；未约定时不因尚未收款或未核实全额款项而拦截开修。报价和客户签署前展示该约定，修改约定须形成当前报价版本并重新确认。

明确先款约定需提供大于零且不超过报价总额的 `prepayCents`；判断使用核实收款减去核实退款的净额，不把现金登记当成已核实，也不把内部交接重复计入收款。无先款约定时仍可协商、登记预付款，其金额不自动构成开修门槛。

销售的现款条款继续要求核实全款才可出库；销售账期条款保留其已约定预付款门槛。所有执行动作仍须满足当前公司审核、客户有效签署、异议、角色及阶段等前置条件，不能因付款口径澄清而跳过这些检查。

#### 3.3.4、<span id="acceptance-history-contract">验收签署与质保日历</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

有效人工 `accept` 事务成功时追加一条签署记录。`passed=false` 保留此次签名及文字异议，主阶段仍待验收，不写验收通过时间、不起保；整改后通过只追加新记录，不能覆盖之前拒绝的原件。校验失败或未解决异议时尝试通过，不追加记录。相同请求键重试不重复签署，返回时继续核对当前工单授权。

签署历史随加密持久化及备份保存，不放入可由普通证据删除动作删除的附件清单。隔离恢复仍按备份时点恢复业务事实，保持最新账号与工单授权；不能据此宣称恢复了备份之后的签署，也不能补造缺失原件。

人工和自动验收以 `Asia/Shanghai` 的自然日计算质保。起算日按正整数日历月相加，目标月无同日时取月末；截止日当日全天有效，次日零点起显示到期。演示和服务端使用同一日历口径；不自动回写已有持久化质保截止值，既有已确认约定仍需按原记录核对。

### 3.4、<span id="audit-contract">设置、账号与安全审计</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

POST `/settings` 仅管理员，字段 `{companyAddress,companyReceiver,companyPhone,reminderHours,remarkLimit}`，服务端返回演示标记。GET `/accounts` 仅管理员返回账号元数据；POST `/accounts/{id}/status` `{status,reason}`，status 为 active／disabled，不允许停用自己。账号状态与原因、操作人、前后状态及授权版本的审计同事务提交；保存失败不更改账号。

GET `/audit?page=1&pageSize=30` 仅管理员，返回 `{items,total,page,pageSize}`，按最新在前分页；设置页提供查看、翻页、空态和重载。AuditEvent 字段为 `id,actorId,actorRole,type,resource,resourceIds,result,at,reason,before,after,authBefore,authAfter`；`resourceIds` 等扩展字段按事件需要提供，不记录密码、token、原件正文或完整请求。

HTTP 登录成功／失败、鉴权拒绝、退出、完整工单详情、原件下载、导出及账号状态变更有应用审计。完整详情、原件下载、导出先持久保存审计再返回资料，持久化失败即拒绝。已处理请求重试重建当前完整工单时，也先保存 `idempotent_order_read` 审计；失败不放出当前资料、不重新办理原业务。成功重试只增加读取审计，不重复账号状态等原业务审计。列表／bootstrap 在业务锁内重查当前账号授权，不额外生成每条摘要的批量审计。审计当前保存在加密应用快照内，未交付独立运维审计或不可篡改副本。

`/securityz` 位于 API 前缀外，返回不含路径或凭据的定时备份配置与成功／失败状态。证据内容仅在鉴权原件接口下载；发票附件只接受存续 PDF／图片文件，不能用文字说明代替。

### 3.5、<span id="persistence-contract">幂等持久化与隔离恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

所有已处理请求保留键、内容摘要、状态与时间；工单／借用／采购的历史响应压缩成稳定 ID，重试重新检查当前权限并重建最新响应。旧完整响应在启动时兼容压缩，随后续快照保存；不删除关键请求键，不再次执行已处理请求。同一次意图使用原键，明确成功后的另一笔合法同内容操作使用新键。8,000 键预警／10,000 键参考阈值不代表已验收生产容量。

删除已绑定设备证据时，先原子保存删除墓碑并撤销旁件引用，保存成功后才清除无存续引用的原件；保存失败保留原件。文件模式默认独占目录启动时会回收中断临时件和未提交孤件；自定义共享目录及TiDB目录不在启动时全目录清理，避免影响其它活写入者。已删除原件不进入新备份，旧备份恢复按最新删除墓碑禁止复活。

设备流式原件以64KiB认证帧加密保存，快照只保存元数据／绑定；每帧校验位置、长度及内容，结束帧和原件SHA-256防止截断、重排和尾随。文件模式默认使用数据目录内 `order-media/`；TiDB默认使用密钥所在目录内 `order-media/`，可通过显式 `WB_ORDER_MEDIA_DIR` 指定私有原件目录；数据库备份不能替代该目录。部署应给原件目录预留磁盘容量并保持非公开访问。

备份必须一起携带主文件、`.manifest.json`及存在时的同名 `.media/` 加密原件目录，密钥单独配对保管。旁件先校验解密／原始摘要，再流式复制并写入密文摘要清单；缺失、损坏的原件拒绝备份或恢复。恢复先在临时隔离目录完成旁件验证和快照写入，再原子发布新目标；恢复后原件在目标 `order-media/`，启动时应移除在线源的 `WB_ORDER_MEDIA_DIR` 覆盖或明确指定恢复目标。旧版仅内联快照无需旁件仍可恢复；未绑定上传凭据不会由旧备份复活。

文件恢复要求新目标、原密钥、备份及清单、最新源。按稳定工单 ID 合并当前 `customerId/companyId/assigneeId/ownerId` 和账号授权，按工单／证据 ID 合并删除约束；缺少任何旧工单／证据的当前约束则拒绝。审计按稳定 ID 合并并增加恢复记录，旧会话不复用；业务事实仍来自备份点。详见 [恢复操作与限制](../../部署/README.md#isolated-restore)。

最新账号必须通过完整结构、角色、状态、凭据元数据及重复 ID／登录名校验，所有备份账号 ID 都须有最新约束；工单客户与企业必须匹配有效来源，非空负责人／执行人 ID 必须有对应账号。结构缺失或非法时，恢复在创建目标前拒绝，不能凭默认值放开授权。

恢复合并备份与最新源中所有已知已消费请求的键和原内容摘要。共享键的 hash／状态冲突，或最新消费记录缺失、损坏，则拒绝恢复。`CachedRequest.recoveryState` 保存恢复判定，连续备份／再次恢复仍保留核对标记，同键异内容继续返回 409。

| 恢复后请求来源 | 重试合同 |
| --- | --- |
| 备份内已有、没有核对标记的正常键 | 不重执行业务；按当前授权重建结果，完整工单读取仍须先保存审计 |
| 最新源仅有的账号状态键，且可信提交作用域与账号匹配 | `current_authorization`：返回已合并的当前账号授权，不重新停用／启用，不重复业务审计 |
| 最新源仅有的其它业务键，包括现金、借还、采购和工单交接动作 | `reconciliation_required`：返回 409／`recovery_reconciliation_required`，不把旧备份资源冒充已恢复结果，不重执行业务 |
| 原资源在备份中不存在，或键已带核对标记 | 保留已消费键；继续明确拒绝自动重放，核对标记不会因再次备份／恢复而清除 |

工单授权虽取最新约束，工单业务版本与资金／库存事实仍可能回到备份点。不能直接把所有最新请求键解释为成功恢复，也不能丢掉这些键后用旧版本重新执行。需由负责人核对恢复差异，再以新的请求意图补录已确认的缺失事实；已撤权账号仍无法读取工单重试结果。请求分类依据持久化记录中的实际账号／接口／资源作用域，重试仍检查当前角色，不依据客户端请求键后缀里的相似路径文字。

当前持久化仍是加密聚合快照；规范化关系表、独立媒体、独立运维审计、最新源损失后的全灾备和 TiDB 完整恢复尚未交付。

### 3.6、<span id="client-contract">网页响应校验与离线行为</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

前端用合成样例立即渲染，每次进入与刷新正常请求，HTTP 成功且资源字段／类型／关联校验通过才采用服务器结果。读取失败或错误的 2xx 切换独立合成副本并明确来源；服务恢复后由后续有效响应自动覆盖。写入超时、不可解析或结构错误的 2xx 视为结果未知，保留输入与原请求意图，不报保存成功、不自动重放、不复制真实表单／签名／附件到演示。

开始登录即清除上一账号的工单、概览、设置、账号与审计资料，关闭旧详情和表单，并使旧请求结果失效；认证等待期间只展示独立合成样例。登录成功后先显示当前身份的空列表与零概览，再读取授权资料，不能复用上一账号的业务快照或认证期间打开的合成表单。完整配置尚未加载时不开放配置保存。

导航列表先于概览快照返回时，可展示当前会话的列表；迟到快照只更新同一会话的全局指标和配置，保留导航得到的列表与分页，不以旧列表覆盖。同一会话的概览失败仍须处理，不能因列表序号已改变而吞掉错误、长期把尚未加载的概览作为真实 0；身份切换后的迟到响应不能再更新页面。

读取失败回退时清除真实资料及详情、附件、表单的在途结果。非 401 错误保留已认证会话，后续重新加载或导航会继续尝试服务；响应身份与当前会话一致后恢复真实资料，恢复期间也不把合成工单拼入真实快照。当前会话的任一接口返回 401 均清除会话和旧授权资料并要求重新登录，包含详情、原件、导出和写操作，不能仅显示局部错误；旧会话的迟到 401 不撤销新身份。手动选择独立演示或切换服务地址同样退出原会话。

响应校验须覆盖实际渲染消费的嵌套记录与摘要类型，非法库存条目或缺失 `summary.missing` 等结构在写入当前快照或详情缓存前拒绝，详情保留完整错误与重载入口。未知提交结果的请求键属于原提交意图，打开无关弹窗不清除它；明确成功后另一笔合法同内容操作使用新键。

API 地址留空表示当前页面地址；只接受同源且不含凭据、路径、查询或片段的地址。切换服务／端口需打开目标网页后登录。`file://` 仅离线合成预览，不发 API 请求。动态列表有空态与重载，工单分页、筛选与完整详情由服务器读取；角色切换重新登录，权限由服务端检查。

### 3.7、<span id="work-log-contract">个人工作日志与独立事件提醒</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本轮范围为 Web 与后端，App 顶部 tips 后续实现。产品要求、字段、媒体类型、时区及验收以[个人日志需求](../../需求/项目需求与开发评审/项目需求与开发评审.md#personal-work-log)与[接口数据设计](../../需求/项目需求与开发评审/项目需求与开发评审.md#work-log-design)为统一详细定义；以下路径均在 `/api/v38` 下，不据源码具备能力推断真实公网或跨端验收已通过。

- 日志入口为 `GET /work-logs`、`GET/PUT/DELETE /work-logs/{date}`、`POST /work-logs/{date}/media` 与 `GET /work-log-media/{id}`。仅本人编辑所选合法日期，默认打开今日；管理员可显式选择他人日志只读。普通账号不能跨账户读取、修改或下载原件，同企业及工单授权不能扩大个人日志权限。
- 按月查询继续使用 `month=YYYY-MM`；全部日志使用 `scope=all&page=1&pageSize=20`，按日期降序跨月份分页，页容量1—100，响应保留账户／时区／只读元数据并含 `scope,page,pageSize,total,hasMore,items`。两者均可带 `ownerId,timeZone`，不返回删除墓碑。
- 本人删除提交 `{version,timeZone}`，成功返回 `{ok,ownerId,date,version,deleted:true}`。删除清正文及所属媒体并保留递增版本墓碑，旧版本不能覆盖删除后重建；缓存响应及私密重试按当前资源重建，不重新暴露删除前正文或原件。管理员不能代删他人，不连带删除其他日志、独立提醒或已另存副本，既有备份不由界面删除自动撤销。
- 提醒入口为 `GET/POST /reminders`、`PUT/DELETE /reminders/{id}` 与 `POST /reminders/{id}/fire`。独立提醒仅当前账户可读写和到期认领，管理员查看他人日志也不取得其提醒权限；`fire` 原子检查归属、到期、版本与状态，多标签页不重复触发同一版本。关闭站内提示不自动完成待办，页面关闭后不承诺系统级送达。
- 媒体通过鉴权接口上传／读取 Base64 内容，不公开静态 URL；列表只含元数据，个人原始内容不进入工单 `bootstrap` 或 `export`。`WB_JOURNAL_MEDIA_MAX_BYTES` 默认16 MiB、硬上限32 MiB；图片另受固定8 MiB上限，与配置取小。每日日志8个附件、合计32 MiB为当前工程限额，不能外推生产容量。
- 日志、媒体与提醒随加密聚合快照原子持久化，使用对象版本与稳定请求键；保存失败不交换内存状态，旧快照按空集合兼容。未登录、停用、会话失效及越权请求继续拒绝；日志正文按纯文本处理，账号切换不能复用另一账户内容。

### 3.8、<span id="inventory-purchase-contract">库存明细与采购私有附件</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

详细请求／响应和验收见[库存采购接口设计](../../需求/项目需求与开发评审/项目需求与开发评审.md#inventory-purchase-design)，以下路径均位于 `/api/v38`。

- `GET /parts/{id}` 返回 `{part,loans,purchases}`，仅内部角色可读；管理员／仓库／调度可看该配件全部借还，工程师仅本人借还，关联采购按采购原权限过滤。
- `GET /purchases/{id}`、`GET /purchases/{id}/attachments/{fileId}` 继承采购读取授权：管理员／仓库／财务／调度，或 `supplier` 与当前供应商账户 ID／名称匹配；未授权目标不返回资料。原件下载先持久化读取审计，返回二进制、`no-store` 与附件下载头，网页图片预览也经过同一鉴权接口。
- 创建采购可带 `attachments:[{name,mime,dataBase64}]`；`POST /purchases/{id}/attachments` 提交 `{version,name,mime,dataBase64}` 追加并递增采购版本，均限管理员／仓库／调度。沿用稳定请求键、严格输入、版本冲突及事务回滚；附件不更改库存数量。
- `files` 只含 `{id,name,mime,size,uploaderId,createdAt}`，创建／收货／详情／bootstrap／幂等重试全部使用去原件视图。单件8 MiB、每单8件且原件合计32 MiB，JSON 请求体仍限12 MiB（含 Base64 膨胀）。支持 PNG／JPEG／GIF／WebP、PDF、TXT／CSV、DOCX／XLSX／PPTX，声明类型须与实际格式匹配；不接受 HTML／SVG、路径文件名或伪装可执行内容，不提供公开静态原件或内联文档执行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
