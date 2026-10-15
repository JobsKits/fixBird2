# 原型账务模块

当前账本只记录明确标记 `mode=simulated`、`simulated=true` 的演示收款和人工核销。人工核销表示演示台账的人工确认，不执行银行付款。微信、支付宝和聚合支付尚未配置，调用真实收款不会生成已收或已付记录；`mode=actual` 查询保留独立的真实账本空间，目前为空。

## 记账与业务原子性

金额统一使用整数分。订单收款借记平台资金，贷记师傅应付和平台收入；核销借记师傅应付，贷记平台资金。每份凭证借贷相等，师傅分润与平台收入之和等于订单收款。事件键按订单收款或结算核销唯一，同键同金额返回第一份凭证，同键不同金额或参与人拒绝覆盖。

- 内存仓储先取得业务锁，再调用 `Memory.AppendWith`；回调只提交已经验证的业务赋值，不在回调内取得业务锁，不在赋值后返回错误。
- [TiDB](https://docs.pingcap.com/tidb/stable/transaction-overview) 仓储在订单、支付、结算的同一个 `sql.Tx` 中调用 `TiDB.AppendTx`，由外层提交或回滚。禁止业务提交后再独立追加账本。
- `005_ledger.sql` 新增凭证与分录表。启动时 `Backfill` 按旧 `manual_demo/demo_paid` 收款、结算记录的稳定事件键采纳旧记录，并保留金额与时间；异常或孤立旧收款拒绝部分采纳。单次旧记录超过10000条会停止，需另写分批迁移。

账本接口没有删除或修改操作。内部冲正能力生成反向分录，原凭证保持不变，状态由冲正关系推导；收款在有效核销存在时不能冲正。HTTP 尚未开放冲正写入口，避免账本冲正而订单、支付、结算状态未一起修改。

## 只读 API

管理员使用 `GET /api/v1/admin/ledger/journals`、`/summary`、`/export.csv`。个人使用 `GET /api/v1/ledger/journals`、`/summary`（兼容 `/api/v1/me/ledger/...`）；客户与师傅只读本人记录。所有账务接口要求服务端会话，不能以 `X-Actor-*` 头或匿名演示身份查账。

筛选支持 `mode`（默认 `simulated`）、`kind`、`status`、`channel`、`orderId`、`customerId`、`workerId`、RFC3339 的 `from` / `to`。时间范围为 `[from,to)`。列表 `limit` 默认50、上限200；响应为数组，下一页游标在 `X-Next-Cursor` 中，调用方视为不透明值。

汇总固定 `currency=CNY`、`scope=filtered_movements`，覆盖全部筛选结果，不受列表页大小或游标影响。`platformFundsCents`、`workerPayableCents` 是当前筛选范围的净发生额，不是银行余额，也不含筛选期外期初余额；按时间、类型或凭证状态筛选可能出现负净发生额。

CSV 按完整筛选范围导出，不按当前列表分页；每条分录一行，含模拟标记，UTF-8 BOM，文本字段防公式注入。超过10000份凭证返回413，要求缩小范围，禁止静默截断。

## 验证

`go test -race ./internal/ledger ./internal/httpapi` 检查借贷平衡、去重并发、冲正顺序、权限、分页和导出。TiDB 契约测试仅在显式设置 `REPAIR_TEST_TIDB_DSN` 时启用；该 DSN 必须指向回环地址及 `repair_test_` 前缀，测试新建并清理独立子数据库，禁止使用现有部署数据。
