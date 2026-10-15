# V3.8 工作台接口约定

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

后端使用 [**Go**](https://go.dev/)，提供本机加密演示存储与 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 适配。实际字段及校验以 `../后端/Go服务端/internal/workbench/models.go`、`actions.go` 与 `http.go` 为准；运行范围见 [实现范围](./实现范围.md)。

[身份与提交](#identity-contract) · [分页与读取](#read-contract) · [职责矩阵](#field-permissions) · [业务动作](#action-contract) · [审计](#audit-contract) · [存储与恢复](#persistence-contract) · [网页与离线](#client-contract)

## 一、<span id="identity-contract">身份与提交规则</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Base `/api/v38`，JSON；钱用整数分，版本用正整数。新入口 `后端/Go服务端/cmd/workbench` 和 `前端/Web网页/维修工作台/`，旧入口合同保留。业务写请求带 `Idempotency-Key`；登录／退出按各自会话接口执行。证据原件下载返回文件，其余接口采用 JSON。错误 `{error,message}`，401/403/409/422 不作为成功。

持久化接口：`Load() ([]byte,error)`（首次返回 nil,nil）、`Save([]byte) error`。业务入口 `workbench.New(p Persistence) (*Service,error)`、`svc.Handler(webDir string) http.Handler`。业务提交先克隆、校验，再原子保存和交换内存状态；失败不留下半套主状态／明细。

登录 `POST /login {username,password}` => `{token,actor}`；Bearer token；GET `/session` => actor；POST `/logout`。合成账号见 [演示账号](../README.md#demo-accounts)。`customer-b` 检查跨公司隔离，`customer-peer` 检查同企业当前经办人交接。token 仅保存在服务内存；账号 `authVersion` 变化撤销旧会话，启用账号也不会复活停用前会话。

网页以成功登录返回的身份为当前会话基准。后续快照的 `actor` 必须为 `active`，且 `id/role/companyId/authVersion` 与该基准一致，才可采用其资料；不会用快照中的另一个身份替换当前会话。切换账号期间的展示与恢复行为见 [网页与离线](#client-contract)。

账号状态只接受 `active/disabled`，只有明确 `active` 的有效账号可登录、鉴权、读取及写入；空状态、未知状态和待定状态都不取得授权。启动要求完整账号身份与凭据元数据：稳定 ID、登录名、姓名、企业、合法角色与状态、正整数 `authVersion`、盐及有效摘要。账号清单为空、必要字段缺失、ID／登录名重复或授权结构非法时拒绝启动，不默认激活或替换既有凭据。隔离恢复还须满足 [最新授权约束](#persistence-contract)。

时间字段使用含时区的 RFC3339，例如 `2026-10-14T10:30:00+08:00`，金额使用整数分。拒绝未知请求字段。全部业务变更需要请求键，既有相同键与内容不重复记账；相同键不同内容返回 409。

## 二、<span id="read-contract">分页、详情与字段</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 接口 | 返回与范围 |
| --- | --- |
| `GET /bootstrap` | `{actor,states,orders,orderPage,metrics,capacity,parts,loans,purchases,settings}`；默认首 30 条轻量工单，按当前身份与企业过滤 |
| `GET /orders?page=1&pageSize=30&q=&status=&filter=&documents=&payment=` | `{items,total,page,pageSize,totalPages}`；服务器搜索、筛选、分页，每页最多 200 条 |
| `GET /orders/{id}` | 当前授权的完整 Order |
| `GET /export` | 管理员／调度／财务／客户的完整授权数据包；其他角色拒绝 |

`orderPage` 包含 `page,pageSize,total,totalPages`。`metrics` 包含 `openCount,settlingCount,remainingCents,readyCount,tasksCount,blockedCount`，按完整可见范围计算，不只统计当前页。`capacity` 包含 `requestCount,threshold,warning,mode`，`threshold=10000`、累计 8000 键开始预警；不是停止写入上限。

分页摘要带 `isSummary=true`，`events/evidence/quoteHistory/costs/commissions` 为空，不含 `acceptanceRecords`，报价签名和验收签名为空，不提供完整响应图。客户端打开详情须重新 GET 详情，不能将摘要当成完整记录。完整详情、授权导出及写响应继续按 [职责矩阵](#field-permissions) 返回必要字段。库存、借还与采购列表暂未分页，仍随 bootstrap 返回。

Order JSON：`id,number,version,type`（mail/onsite/sale）、`customer,customerId,companyId,project,device,description,status,outcome,ownerId,assigneeId,createdAt,updatedAt,remark,customerNote,quote,documents,invoices,cash,evidence,events,visits,outsource,costs,commissions,issues,obligations,warranty,originalOrderId,summary`，新增可选 `acceptanceRecords`，旧快照无此字段仍可读取。

quote：`version,amountCents,description,warrantyMonths,paymentTerms`（cash/credit）、`prepayCents,startRequiresPrepayment,validUntil,approved,signed,signature,signer,signedAt,autoAccept`。`startRequiresPrepayment` 为明确约定的维修先款开修开关，缺省及旧快照未提供时为 false；预付款金额本身不等于先款约定。
documents：`requirement`（unknown/required/none）、`reason,version,prepared,sent,recipient,files`（evidence IDs）。
invoice条目：`id,number,amountCents,files,voided`；Order `invoiceRequirement,invoiceReason,invoiceDueCents`。
cash条目：`id,amountCents,kind`（receipt/refund）、`purpose,receipt,collector,occurredAt,verified,handedOver`。
evidence条目：`id,name,kind`（text/image/video/audio/document）、`text,mime,uploaderId,createdAt,deleted,stage`。GET `/orders/{id}/evidence/{evidenceId}` 鉴权下载原件。上传包含在 evidence action payload `{name,kind,text,mime,data}`（base64，无 data URL）。
summary：`documentStatus,invoiceStatus,collectedCents,receivableCents,remainingCents,overpaidCents,pendingCashCents,invoiceCents,nextTask,missing`（string[]）、`warrantyLabel`；服务端派生，客户端只读。

`acceptanceRecords` 为只追加的人工验收签署历史，每条含 `id,passed,signature,signerId,signerName,signedAt,note,quoteVersion,orderVersion`，不通过时另含对应新异议的 `issueId`。`signature` 是已校验的 PNG data URL，`signedAt` 为含时区时间，`orderVersion` 是本次提交后的工单版本。当前客户经办人及 `admin/dispatcher/finance` 可在授权完整详情、动作响应和导出中读取记录与原件；其他角色不读取，摘要不带记录。历史签署者身份不会随经办人交接被改写，但旧客户不因曾签署而保留当前读取权限。

### 2.1、<span id="field-permissions">职责读取矩阵</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

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

## 三、<span id="action-contract">工单、借还与采购动作</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

POST `/orders` => Order。创建与业务动作都有权限及幂等校验，已有对象变更还须提供当前版本。

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

### 3.1、<span id="remark-patch-contract">备注字段 patch</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`remark` 动作的 `{remark,customerNote}` 是按字段提交的 patch：省略字段或提交 `null` 均保留原值，仅校验实际准备写入的字段，不能把脱敏响应里的空备注或未显示字段当成清空指令。授权角色显式提交空字符串可以清空该字段；未被修改的旧字段不会因已有长度问题而被覆盖。

| 角色 | 内部 `remark` | 对客 `customerNote` |
| --- | --- | --- |
| `admin/dispatcher/finance` | 可读、可写；显式空串可清空 | 可读、可写；显式空串可清空 |
| 当前执行工程师 | 在可见工单可读、可写；显式空串可清空 | 可读、可写；显式空串可清空 |
| `qc/warehouse` | 不读取、不修改；省略、`null` 或旧客户端空串均保留，非空（含纯空白）提交返回 403 | 可读、可写；显式空串可清空 |
| 客户／外包／供应商 | `remark` 动作本身拒绝 | 不能通过 `remark` 动作修改；读取仍服从工单权限 |

独立合成演示的 `remark` 动作采用本节字段更新语义和角色矩阵，包含 `finance` 的备注权限。两字段只接受字符串或 `null`；字段类型或权限错误时整次拒绝，保留原工单台账、版本与事件。

### 3.2、<span id="obligation-resolution-contract">余项办理</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`resolve_obligation {obligationId,note}` 仅向管理员、调度、工程师、仓库、质检及财务开放角色入口，并继续检查具体任务：当前任务责任人，或 `admin/dispatcher`，才可将未完成任务标为办妥。财务不得因可读全部余项而代办他人；客户、外包、供应商不获得该动作。`allowedActions` 只有在当前账号至少有一项可办理的未完成余项时才包含此动作，指定他人未获办理授权的余项仍返回 403，不推进状态、不留下半套业务变更。

POST `/loans {orderId,partId,quantity,borrowerId,dueAt,note}` => Loan；POST `/loans/{id}/actions {type,version,payload}`，return `{quantity,condition}` good/quarantine；consume/dispose `{quantity,reason}`；transfer `{quantity,ownerId,dueAt,reason}`。Loan `id,version,orderId,partId,partName,quantity,returnedGood,returnedQuarantine,consumed,disposed,outstanding,borrowerId,dueAt,note`。

Part `id,name,sku,available,quarantine`；POST `/purchases {supplier,partId,quantity,unitCents,note}` => Purchase；POST `/purchases/{id}/receive {version,quantity,note}` => Purchase；Purchase `id,version,supplier,partId,quantity,received,unitCents,note`。

POST `/auto-accept` 受控执行到期扫描（停机异议待核实）；GET `/healthz`。后台在启动和每分钟执行同一验收校验，不绘制客户签章。

### 3.3、<span id="execution-payment-contract">先款约定与执行门槛</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

2026-10-15 用户确认：维修单仅在明确约定 `startRequiresPrepayment=true` 时，要求约定预付款已由财务核实后才允许开修；未约定时不因尚未收款或未核实全额款项而拦截开修。报价和客户签署前展示该约定，修改约定须形成当前报价版本并重新确认。

明确先款约定需提供大于零且不超过报价总额的 `prepayCents`；判断使用核实收款减去核实退款的净额，不把现金登记当成已核实，也不把内部交接重复计入收款。无先款约定时仍可协商、登记预付款，其金额不自动构成开修门槛。

销售的现款条款继续要求核实全款才可出库；销售账期条款保留其已约定预付款门槛。所有执行动作仍须满足当前公司审核、客户有效签署、异议、角色及阶段等前置条件，不能因付款口径澄清而跳过这些检查。

### 3.4、<span id="acceptance-history-contract">验收签署与质保日历</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

有效人工 `accept` 事务成功时追加一条签署记录。`passed=false` 保留此次签名及文字异议，主阶段仍待验收，不写验收通过时间、不起保；整改后通过只追加新记录，不能覆盖之前拒绝的原件。校验失败或未解决异议时尝试通过，不追加记录。相同请求键重试不重复签署，返回时继续核对当前工单授权。

签署历史随加密持久化及备份保存，不放入可由普通证据删除动作删除的附件清单。隔离恢复仍按备份时点恢复业务事实，保持最新账号与工单授权；不能据此宣称恢复了备份之后的签署，也不能补造修复前已经丢失的原件。

人工和自动验收以 `Asia/Shanghai` 的自然日计算质保。起算日按正整数日历月相加，目标月无同日时取月末；截止日当日全天有效，次日零点起显示到期。演示和服务端使用同一日历口径；不自动回写已有持久化质保截止值，既有已确认约定仍需按原记录核对。

## 四、<span id="audit-contract">设置、账号与安全审计</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

POST `/settings` 仅管理员，字段 `{companyAddress,companyReceiver,companyPhone,reminderHours,remarkLimit}`，服务端返回演示标记。GET `/accounts` 仅管理员返回账号元数据；POST `/accounts/{id}/status` `{status,reason}`，status 为 active／disabled，不允许停用自己。账号状态与原因、操作人、前后状态及授权版本的审计同事务提交；保存失败不更改账号。

GET `/audit?page=1&pageSize=30` 仅管理员，返回 `{items,total,page,pageSize}`，按最新在前分页；设置页提供查看、翻页、空态和重载。AuditEvent 字段为 `id,actorId,actorRole,type,resource,resourceIds,result,at,reason,before,after,authBefore,authAfter`；`resourceIds` 等扩展字段按事件需要提供，不记录密码、token、原件正文或完整请求。

HTTP 登录成功／失败、鉴权拒绝、退出、完整工单详情、原件下载、导出及账号状态变更有应用审计。完整详情、原件下载、导出先持久保存审计再返回资料，持久化失败即拒绝。已处理请求重试重建当前完整工单时，也先保存 `idempotent_order_read` 审计；失败不放出当前资料、不重新办理原业务。成功重试只增加读取审计，不重复账号状态等原业务审计。列表／bootstrap 在业务锁内重查当前账号授权，不额外生成每条摘要的批量审计。审计当前保存在加密应用快照内，未交付独立运维审计或不可篡改副本。

`/securityz` 位于 API 前缀外，返回不含路径或凭据的定时备份配置与成功／失败状态。证据内容仅在鉴权原件接口下载；发票附件只接受存续 PDF／图片文件，不能用文字说明代替。

## 五、<span id="persistence-contract">幂等持久化与隔离恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

所有已处理请求保留键、内容摘要、状态与时间；工单／借用／采购的历史响应压缩成稳定 ID，重试重新检查当前权限并重建最新响应。旧完整响应在启动时兼容压缩，随后续快照保存；不删除关键请求键，不再次执行已处理请求。同一次意图使用原键，明确成功后的另一笔合法同内容操作使用新键。移除原 10,000 键硬停，8,000 预警／10,000 参考阈值不代表已验收生产容量。

文件恢复要求新目标、原密钥、备份及清单、最新源。按稳定工单 ID 合并当前 `customerId/companyId/assigneeId/ownerId` 和账号授权，按工单／证据 ID 合并删除约束；缺少任何旧工单／证据的当前约束则拒绝。审计按稳定 ID 合并并增加恢复记录，旧会话不复用；业务事实仍来自备份点。详见 [恢复操作与限制](../部署文档.md#isolated-restore)。

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

## 六、<span id="client-contract">网页响应校验与离线行为</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

前端用合成样例立即渲染，每次进入与刷新正常请求，HTTP 成功且资源字段／类型／关联校验通过才采用服务器结果。读取失败或错误的 2xx 切换独立合成副本并明确来源；服务恢复后由后续有效响应自动覆盖。写入超时、不可解析或结构错误的 2xx 视为结果未知，保留输入与原请求意图，不报保存成功、不自动重放、不复制真实表单／签名／附件到演示。

开始登录即清除上一账号的工单、概览、设置、账号与审计资料，关闭旧详情和表单，并使旧请求结果失效；认证等待期间只展示独立合成样例。登录成功后先显示当前身份的空列表与零概览，再读取授权资料，不能复用上一账号的业务快照或认证期间打开的合成表单。完整配置尚未加载时不开放配置保存。

导航列表先于概览快照返回时，可展示当前会话的列表；迟到快照只更新同一会话的全局指标和配置，保留导航得到的列表与分页，不以旧列表覆盖。同一会话的概览失败仍须处理，不能因列表序号已改变而吞掉错误、长期把尚未加载的概览作为真实 0；身份切换后的迟到响应不能再更新页面。

读取失败回退时清除真实资料及详情、附件、表单的在途结果。非 401 错误保留已认证会话，后续重新加载或导航会继续尝试服务；响应身份与当前会话一致后恢复真实资料，恢复期间也不把合成工单拼入真实快照。当前会话的任一接口返回 401 均清除会话和旧授权资料并要求重新登录，包含详情、原件、导出和写操作，不能仅显示局部错误；旧会话的迟到 401 不撤销新身份。手动选择独立演示或切换服务地址同样退出原会话。

响应校验须覆盖实际渲染消费的嵌套记录与摘要类型，非法库存条目或缺失 `summary.missing` 等结构在写入当前快照或详情缓存前拒绝，详情保留完整错误与重载入口。未知提交结果的请求键属于原提交意图，打开无关弹窗不清除它；明确成功后另一笔合法同内容操作使用新键。

API 地址留空表示当前页面地址；只接受同源且不含凭据、路径、查询或片段的地址。切换服务／端口需打开目标网页后登录。`file://` 仅离线合成预览，不发 API 请求。动态列表有空态与重载，工单分页、筛选与完整详情由服务器读取；角色切换重新登录，权限由服务端检查。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
