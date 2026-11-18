# <span id="前言">后端业务单元代码地图</span>

![Jobs出品，必属精品](../../../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、业务实现定位](#jobs-toc-heading-1)
- [二、外置测试定位](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

> 保留当前 V3.8 业务文件、符号与测试的定位关系。


本目录定位所属开发单元的源码、配置与测试，跨单元通过相对链接协作。

`Handler` 的健康接口从 `Settings.Demo` 返回环境标识；`login` 中的 `admin / 1234` 仅对明确 Demo 的有效管理员生效，边界回归见外置 `admin_demo_gate_test.go`。

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、业务实现定位 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 文件 | 职责 | 关键符号 |
| --- | --- | --- |
| [models.go](../models.go) | 聚合业务类型、整数金额、报价先款约定、验收原件历史与持久化合同 | `Actor`、`Quote.StartRequiresPrepayment`、`AcceptanceRecord`、`Order`、`Summary`、`State`、`Persistence` |
| [service.go](../service.go) | 启动迁移、会话、原子写入、工单可见性与派生状态 | `New`、`activeActor`、`validateAccounts`、`authenticate`、`transact`、`validateState`、`visible`、`refresh`、`view` |
| [auth.go](../auth.go)、[auth_mail.go](../auth_mail.go) | 普通邮箱验证码、独立客户注册、绑定邮箱重置及安全SMTP投递 | `registerPublicAuth`、`requestAuthCode`、`applyPublicAuth`、`localAuthRequest`、`deliverAuthEmail` |
| [password_policy.go](../password_policy.go)、[Unicode静态表](../password_emoji_data.go) | 登录／新密码及确认字段统一拒表情，保留普通文字及ASCII；静态表与桌面Unicode18契约全量核对 | `validatePasswordEmoji`、`passwordContainsEmoji` |
| [http.go](../http.go) | 路由、严格输入解析、鉴权、写包装、导出与附件下载 | `Handler`、`decodeStrict`、`write`、`bootstrap`、`listOrders`、`downloadEvidence` |
| [actions.go](../actions.go) | 工单创建及受理、报价、签署历史追加、先款执行门槛、票款与完结动作 | `createOrder`、`act`、`executionReady`、`validSignature`、`acceptance`、`actionPermission`、`allowedActions` |
| [customer_directory.go](../customer_directory.go) | 客户分组、多账户／企业、授权新建、旧账户目录、客户本人投影与持久约束 | `CustomerProfile`、`registerCustomerDirectoryRoutes`、`mutateCustomerDirectory`、`validateCustomerDirectory` |
| [order_media.go](../order_media.go) | 创建工单时图片／视频原件校验，无设备大小／数量上限、同事务绑定与旧Base64兼容 | `OrderMediaInput`、`initialOrderMedia`、`validOrderVideo` |
| [order_uploads.go](../order_uploads.go) | 原件流式上传、账号／企业／授权绑定、同键回执、取消、64KiB认证帧及私有下载读取 | `OrderUpload`、`uploadOrderMedia`、`cancelOrderUpload`、`bindOrderUpload`、`orderMediaStore`、`clearMediaDeadlines`、`cleanupRemovedOrderMedia`、`cleanupAbandonedOrderMedia` |
| [order_media_backup.go](../order_media_backup.go) | 原件旁件备份、密文清单与流式校验、隔离恢复 | `BackupMedia`、`backupOrderMedia`、`restoreOrderMedia`、`verifyMedia` |
| [calendar.go](../calendar.go) | 中国日期加日历月、月底截断与质保截止日全天有效 | `warrantyEnd`、`warrantyActive` |
| [journal.go](../journal.go) | 账户私密日志、月历与跨月分页、版本删除墓碑、管理员只读、受限媒体及鉴权原件 | `readWorkLogs`、`readAllWorkLogs`、`deleteWorkLog`、`updateWorkLog`、`appendJournalMedia`、`downloadJournalMedia`、`journalView` |
| [reminders.go](../reminders.go)、[personal_validation.go](../personal_validation.go) | 本人事件提醒、到期原子认领、当前版本与持久状态校验 | `registerPersonalRoutes`、`saveReminder`、`fireReminder`、`replayPersonalRequest`、`validatePersonalState` |
| [query.go](../query.go) | 按权限检索、30 条默认摘要页、剔除签署原件、全范围概览 | `OrderQuery`、`parseOrderQuery`、`queryOrders`、`orderSummary`、`dashboard`、`visiblePendingCash` |
| [permissions.go](../permissions.go) | 职责字段与签署历史过滤、本人成本／现金范围、证据用途读取 | `readsFinancialDetails`、`filterOrderFields`、`filterFinancialTasks`、`canReadEvidence`、`canEditInternalRemark`、`canResolveObligation` |
| [idempotency.go](../idempotency.go) | 保留请求键与摘要、压缩历史响应、按当前授权重建重试结果 | `compactRequests`、`compactResponse`、`replayRequest`、`validateCachedRequest`、`capacity` |
| [audit.go](../audit.go) | 必要审计元数据、保存失败时拒绝读取、当前授权复核 | `AuditEvent`、`appendAudit`、`auditLocked`、`audit`、`currentActorLocked` |
| [inventory.go](../inventory.go) | 配件借还真实创建时间、采购与分批收货；手动触发自动验收入口；旧借出时间缺失保持未知 | `createLoan`、`loanAction`、`createPurchase`、`receivePurchase`、`autoAccept` |
| [inventory_files.go](../inventory_files.go) | 授权库存／采购明细、采购私有附件校验、原件视图剥离及鉴权下载 | `registerInventoryRoutes`、`PurchaseFile`、`canReadPurchase`、`purchaseView`、`validPurchaseFile`、`validatePurchaseFileSet` |
| [loan_files.go](../loan_files.go) | 借还图片与数量／阶段关联、原子追加、旧单补录、私有原件投影与鉴权下载 | `LoanFile`、`appendLoanFiles`、`validateLoanFiles`、`loanView`、`canReadLoan`、`registerLoanFileRoutes` |
| [tasks.go](../tasks.go) | 自然日验收扫描与定时调度 | `SweepAutoAcceptance`、`RunScheduledTasks` |
| [storage.go](../storage.go) | 加密文件、独占写锁、原子落盘、隔离恢复与约束合并 | `NewFilePersistence`、`atomicWrite`、`WriteBackup`、`RestoreBackup`、`mergeRestrictions`、`recoveryAccounts`、`mergeRecoveryRequests`、`mergeRecoveryAudit` |
| [writer_lock.go](../writer_lock.go)、[Unix锁](../writer_lock_unix.go)、[Windows锁](../writer_lock_windows.go) | 持久内核排他锁、旧PID锁的串行恢复；只有确认占用进程不存在才回收 | `acquireWriterLock`、`recoverAbandonedWriterLock`、`readWriterLock`、`lockWriterGuard`、`writerProcessDead` |
| [storage_tidb.go](../storage_tidb.go) | [**TiDB**](https://docs.pingcap.com/tidb/stable/) 加密聚合快照、revision CAS、TLS 配置检查 | `NewTiDBPersistence`、`Load`、`Save` |
| [seed.go](../seed.go) | 受控合成账号、样例工单与签名 | `seedState`、`syntheticSignature` |
## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、外置测试定位 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 覆盖范围 | 原有用例 |
| --- | --- |
| 工单流程、金额、签署、完结、借还与基础权限 | [business_test.go](../../../../../../测试/后端/单元/internal/workbench/business_test.go) |
| 客户多账户／企业、新建真实客户凭据、跨户投影、重启、幂等与失败回滚 | [customer_directory_test.go](../../../../../../测试/后端/单元/internal/workbench/customer_directory_test.go) |
| 设备图／视频原子创建、当前授权原件、伪类型／路径、旧内联兼容及超过12MiB真实HTTP | [order_media_test.go](../../../../../../测试/后端/单元/internal/workbench/order_media_test.go) |
| GCM帧篡改／截断／重排／尾随、取消清理、绑定／删除失败回滚、提交后旁件清理、重启孤件清理与完整旁件备份恢复 | [order_uploads_test.go](../../../../../../测试/后端/单元/internal/workbench/order_uploads_test.go) |
| 邮箱注册、找回、真实登录、权限与企业隔离、SMTP不可用、限流／过期／单次消费及保存失败回滚 | [auth_test.go](../../../../../../测试/后端/单元/internal/workbench/auth_test.go) |
| 密码表情序列与普通文字、共用Unicode表一致、注册／重置／目录账户API及旧hash登录策略，失败不改凭据或消费验证码 | [password_policy_test.go](../../../../../../测试/后端/单元/internal/workbench/password_policy_test.go) |
| 借出真实创建时间、幂等／归还／列表／重启保留、拒客户端伪造及旧单不补造时间 | [loan_created_at_test.go](../../../../../../测试/后端/单元/internal/workbench/loan_created_at_test.go) |
| 借还图片权限／原件剥离、幂等、数量与库存原子性、失败重试、旧端兼容、补录、尺寸与总量限制 | [loan_files_test.go](../../../../../../测试/后端/单元/internal/workbench/loan_files_test.go) |
| 私密日志、历史日期、跨月分页、删除／重建版本、媒体与旧重试隐私、加密重启及并发单次提醒 | [personal_test.go](../../../../../../测试/后端/单元/internal/workbench/personal_test.go) |
| 库存关联角色过滤、采购原件投影／下载、附件校验／幂等／版本／回滚与加密重启 | [inventory_files_test.go](../../../../../../测试/后端/单元/internal/workbench/inventory_files_test.go) |
| 中国日历月、闰年、UTC 日界、截止日全天及输入原子性 | [calendar_acceptance_regression_test.go](../../../../../../测试/后端/单元/internal/workbench/calendar_acceptance_regression_test.go) |
| 不通过／后续通过签署原件、角色过滤、重试、重启与备份恢复 | [acceptance_history_test.go](../../../../../../测试/后端/单元/internal/workbench/acceptance_history_test.go) |
| 明确约定维修先款、净收款、销售门槛与非法输入拒绝 | [prepayment_contract_test.go](../../../../../../测试/后端/单元/internal/workbench/prepayment_contract_test.go) |
| 字段级备注更新、任务责任人、重试读取审计 | [permissions_write_test.go](../../../../../../测试/后端/单元/internal/workbench/permissions_write_test.go)、[permissions_cross_test.go](../../../../../../测试/后端/单元/internal/workbench/permissions_cross_test.go) |
| 恢复已消费请求与账户完整性、跨次恢复约束 | [recovery_regression_test.go](../../../../../../测试/后端/单元/internal/workbench/recovery_regression_test.go)、[recovery_boundary_test.go](../../../../../../测试/后端/单元/internal/workbench/recovery_boundary_test.go) |
| 职责字段与证据读取矩阵 | [permissions_test.go](../../../../../../测试/后端/单元/internal/workbench/permissions_test.go) |
| 审计、幂等兼容、参考容量、摘要分页与读取授权复核 | [regression_fix_test.go](../../../../../../测试/后端/单元/internal/workbench/regression_fix_test.go)、[retry_audit_test.go](../../../../../../测试/后端/单元/internal/workbench/retry_audit_test.go) |
| 加密、写锁、备份、当前工单授权及审计合并 | [storage_test.go](../../../../../../测试/后端/单元/internal/workbench/storage_test.go)、[storage_authorization_test.go](../../../../../../测试/后端/单元/internal/workbench/storage_authorization_test.go)、[storage_audit_test.go](../../../../../../测试/后端/单元/internal/workbench/storage_audit_test.go) |
| 异常退出后的重开、活旧PID和坏锁保护、双进程并发独占 | [writer_lock_test.go](../../../../../../测试/后端/单元/internal/workbench/writer_lock_test.go)，通过真实Go子进程与独立临时数据验证 |
| TiDB 加密 CAS、重启与 TLS 配置拒绝 | [storage_tidb_test.go](../../../../../../测试/后端/单元/internal/workbench/storage_tidb_test.go)；连接测试需独立 `WB_TEST_TIDB_DSN` |

测试物理源保留在外层，执行机制见 [运行器](../../../../../../测试/后端/运行测试.py/README.md)。本轮目录整理未修改这些业务实现与原用例内容。

本地图对应的索引位于 `../../../.codegraph/`，配置为 [codegraph.json](../../../codegraph.json)。查询的 `projectPath` 指向该代码单元，源码变更后只同步这个单元；项目根不维护混合索引。索引排除第三方、手工私库、生成产物、缓存及文档，地图本身继续保留外置测试和跨端入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
