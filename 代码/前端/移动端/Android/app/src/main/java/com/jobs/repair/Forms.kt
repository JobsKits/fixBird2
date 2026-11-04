package com.jobs.repair

data class Field(val key: String, val title: String, val kind: String = "text", val choices: List<String> = emptyList(), val required: Boolean = true)
data class ActionForm(val key: String, val title: String, val fields: List<Field>)

/** 同一字段同时驱动原生表单和请求，避免界面名字与接口字段错位。 */
object Forms {
    private fun f(key: String, title: String, kind: String = "text", required: Boolean = true) = Field(key, title, kind, required = required)
    private fun e(key: String, title: String, vararg choices: String) = Field(key, title, "choice", choices.toList())
    private fun a(key: String, title: String, vararg fields: Field): ActionForm {
        val noteRequired = key in listOf("receive", "report", "finish", "qc", "deliver", "failure", "cost", "commission", "settle_commission", "rework", "loan", "purchase")
        return ActionForm(key, title, fields.map { if (it.key == "note" && noteRequired) it.copy(required = true) else it })
    }
    private val note = f("note", "办理说明", required = false)
    private val reason = f("reason", "原因")
    private val owner = f("ownerId", "责任人账号 ID")
    private val due = f("dueAt", "截止时间", "date")
    private val amount = f("amountCents", "金额（元）", "money")
    private val quantity = f("quantity", "数量", "int")
    private val files = f("files", "附件 ID（多个用逗号分隔）", "ids", required = false)
    val create = a("create", "提交新需求", e("type", "服务类型", "mail", "onsite", "sale"), f("customer", "客户名称"), f("customerId", "客户账号 ID"), f("companyId", "企业 ID"), f("project", "项目 / 地址", required = false), f("device", "设备 / 配件"), f("description", "故障 / 需求"), f("customerNote", "对客备注", required = false))
    val loan = a("loan", "借用配件", f("orderId", "关联工单 ID", required = false), f("partId", "配件 ID"), quantity, f("borrowerId", "借用工程师账号 ID"), due, note)
    val purchase = a("purchase", "采购配件", f("supplier", "供应商"), f("partId", "配件 ID"), quantity, f("unitCents", "单价（元）", "money"), note)
    val all = listOf(
        a("intake", "受理并分派", owner, f("assigneeId", "执行人账号 ID")),
        a("receive", "登记收件", note), a("assign", "调整执行人", f("assigneeId", "执行人账号 ID")),
        a("diagnose", "开始检测", note), a("report", "检测报告", note),
        a("quote", "制定报价", amount, f("description", "报价范围"), f("warrantyMonths", "质保月数", "int"), e("paymentTerms", "付款条款", "cash", "credit"), f("prepayCents", "约定预付（元）", "money"), f("startRequiresPrepayment", "明确先款开修", "bool"), f("validUntil", "报价有效期", "date"), f("autoAccept", "约定到期自动验收", "bool")),
        a("approve_quote", "公司审核报价", note), a("sign_quote", "签署报价", f("quoteVersion", "当前报价版本", "int")),
        a("start", "开始维修", note), a("finish", "维修完成", note), a("qc", "质检", f("passed", "质检通过", "bool"), note),
        a("stock_ready", "销售备货", f("partId", "配件 ID"), quantity),
        a("dispatch", "登记发货", f("carrier", "承运方"), f("tracking", "运单号", required = false), note),
        a("deliver", "确认交付", f("deliveredAt", "实际交付时间", "date"), note),
        a("accept", "客户验收", f("passed", "验收通过", "bool"), note),
        a("requirements", "确认资料与发票约定", e("documentRequirement", "资料要求", "unknown", "required", "none"), f("documentReason", "资料约定说明", required = false), e("invoiceRequirement", "发票要求", "unknown", "required", "none"), f("invoiceReason", "发票约定说明", required = false), f("invoiceDueCents", "应开票金额（元）", "money")),
        a("documents", "办理资料", f("prepared", "已制作", "bool"), f("sent", "已发送", "bool"), f("recipient", "接收对象", required = false), files),
        a("cash", "登记收退款", amount, e("kind", "方向", "receipt", "refund"), f("purpose", "款项用途"), f("receipt", "凭证说明"), f("occurredAt", "发生时间", "date")),
        a("verify_cash", "核实收退款", f("cashId", "现金记录 ID")), a("handover_cash", "现金内部交接", f("cashId", "现金记录 ID")),
        a("invoice", "登记发票", f("number", "发票号码"), amount, files.copy(required = true)), a("void_invoice", "红冲发票", f("invoiceId", "发票 ID"), reason),
        a("adjust_receivable", "调整应收", amount, reason),
        a("remark", "编辑备注", f("remark", "内部备注", required = false), f("customerNote", "对客备注", required = false)),
        a("evidence", "添加文字证据", f("name", "名称"), f("text", "内容")), a("delete_evidence", "删除证据", f("evidenceId", "证据 ID"), reason),
        a("issue", "提出异议", f("note", "异议内容"), owner, due), a("resolve_issue", "解决异议", f("issueId", "异议 ID"), f("note", "处理结论")),
        a("failure", "结束履约", e("reason", "履约结果", "customer_refused", "company_refused", "unrepairable", "cancelled", "negotiated"), note, amount, f("returnRequired", "需退还设备", "bool")),
        a("obligation", "添加余项", f("title", "余项内容"), owner, due), a("resolve_obligation", "办妥余项", f("obligationId", "余项 ID"), f("note", "办理结论")),
        a("visit", "预约上门", f("id", "已有预约 ID（新建留空）", required = false), f("plannedAt", "预约时间", "date"), f("feeMemo", "上门费用约定"), note, f("reason", "调整原因", required = false)),
        a("start_visit", "开始上门", f("visitId", "预约 ID")), a("outsource", "登记转包", f("provider", "外包方"), f("contact", "联系方式"), f("destination", "设备去向"), note),
        a("cost", "登记成本", f("category", "成本分类"), amount, note), a("approve_cost", "核实成本", f("costId", "成本 ID")),
        a("commission", "登记提成", f("person", "提成人"), amount, note), a("settle_commission", "结算提成", f("commissionId", "提成 ID"), note),
        a("complete", "整单完结", note), a("reopen", "重新打开", reason), a("rework", "创建返修单", note, f("free", "有效质保内免费", "bool")),
        a("review_acceptance", "核实恢复验收", f("note", "停机异议核实依据")), a("handover_contact", "移交客户经办人", f("customerId", "新经办人账号 ID"), reason)
    )
    val titles = all.associate { it.key to it.title }
    val states = linkedMapOf("pending_intake" to "待受理", "pending_arrangement" to "待安排", "diagnosis_quotation" to "检测 / 报价中", "pending_customer_confirmation" to "待客户确认", "pending_execution" to "待执行", "repairing" to "维修中", "pending_quality_check" to "待质检", "pending_delivery" to "待交付", "pending_acceptance" to "待验收", "settling" to "结算中", "pending_completion" to "待完结", "completed" to "已完结")
    val choiceLabels = mapOf("mail" to "寄修", "onsite" to "上门", "sale" to "配件销售", "cash" to "现款", "credit" to "账期", "unknown" to "待确认", "required" to "需要", "none" to "无需", "receipt" to "收款", "refund" to "退款", "good" to "完好", "quarantine" to "隔离", "customer_refused" to "客户拒绝", "company_refused" to "公司拒绝", "unrepairable" to "不能修", "cancelled" to "取消", "negotiated" to "协商终止")
}
