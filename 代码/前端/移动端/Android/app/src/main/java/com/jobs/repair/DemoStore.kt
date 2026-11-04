package com.jobs.repair

import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime
import java.util.UUID

/** 只操作程序生成的样例，不从服务器私有快照复制资料。 */
class DemoStore(user: String, private val environment: String = "default") {
    companion object {
        const val password = "Demo-Repair-2026!"
        val users = listOf("admin", "dispatcher", "engineer", "outsource", "warehouse", "qc", "finance", "customer", "customer-peer", "customer-b", "supplier")
        val roles = setOf("admin", "dispatcher", "engineer", "outsource", "warehouse", "qc", "finance", "customer", "supplier")
        private val stores = mutableMapOf<String, JSONObject>()
    }
    val actor = json("id" to user, "username" to user, "name" to user, "role" to if (user.startsWith("customer")) "customer" else user, "companyId" to if (user == "customer-b") "company-b" else if (user.startsWith("customer")) "company-a" else "internal", "status" to "active", "authVersion" to 1)
    private val role get() = actor.getString("role")
    private var state: JSONObject
        get() = stores.getValue(environment)
        set(value) { stores[environment] = value }
    private val replay = mutableMapOf<String, Pair<String, JSONObject>>()
    init { if (stores[environment] == null) stores[environment] = seed() }
    private fun reject(condition: Boolean, message: String) { if (!condition) throw Rejection(422, message) }
    private fun id(prefix: String) = prefix + UUID.randomUUID().toString().take(8)
    private fun visible(o: JSONObject): Boolean = when (role) {
        "customer" -> o.optString("customerId") == actor.getString("id") && o.optString("companyId") == actor.getString("companyId")
        "engineer", "outsource" -> o.optString("assigneeId") == actor.getString("id")
        "supplier" -> false
        else -> true
    }
    private fun newOrder(body: JSONObject, forActor: Boolean = true): JSONObject {
        val o = body.copyJSON()
        if (forActor && role == "customer") { o.put("customerId", actor.getString("id")); o.put("companyId", actor.getString("companyId")) }
        reject(o.optString("device").isNotBlank() && o.optString("description").isNotBlank(), "设备与需求必填")
        reject(o.optString("type") in listOf("mail", "onsite", "sale"), "服务类型无效")
        reject(o.optString("customerId") in listOf("customer", "customer-peer", "customer-b"), "请选择有效客户")
        val company = if (o.optString("customerId") == "customer-b") "company-b" else "company-a"
        reject(o.optString("companyId") == company, "客户与企业不匹配")
        o.put("id", id("demo_")); o.put("number", "演示-${System.currentTimeMillis().toString().takeLast(6)}")
        o.put("version", 1); o.put("status", "pending_intake"); o.put("createdAt", nowISO()); o.put("updatedAt", nowISO())
        o.put("quote", json("version" to 0, "amountCents" to 0, "prepayCents" to 0, "approved" to false, "signed" to false))
        o.put("documents", json("requirement" to "unknown", "prepared" to false, "sent" to false)); o.put("invoiceRequirement", "unknown")
        listOf("cash", "invoices", "evidence", "events", "visits", "outsource", "costs", "commissions", "issues", "obligations", "quoteHistory", "acceptanceRecords").forEach { o.put(it, JSONArray()) }
        return o
    }
    private fun seed(): JSONObject {
        val orders = JSONArray()
        listOf("变频水泵控制柜", "工业控制主板", "门禁控制板").forEachIndexed { index, device ->
            val o = newOrder(json("type" to if (index == 0) "onsite" else "mail", "customer" to "海棠物业（合成）", "customerId" to "customer", "companyId" to "company-a", "project" to "合成演示项目", "device" to device, "description" to "设备异常，请检测维修"), false)
            o.put("id", "demo_sample_$index"); o.put("ownerId", "dispatcher"); o.put("assigneeId", "engineer")
            if (index > 0) {
                o.put("status", if (index == 1) "pending_customer_confirmation" else "repairing")
                o.put("quote", json("version" to 1, "amountCents" to 68000, "prepayCents" to 0, "description" to "合成维修与调试", "warrantyMonths" to 3, "paymentTerms" to "credit", "validUntil" to OffsetDateTime.now().plusDays(7).toString(), "approved" to true, "signed" to (index == 2), "startRequiresPrepayment" to false))
            }
            orders.put(o)
        }
        return json("orders" to orders, "parts" to JSONArray().put(json("id" to "part-board", "name" to "工业控制主板", "sku" to "PCB-38", "available" to 28, "quarantine" to 1)).put(json("id" to "part-sensor", "name" to "温度传感器", "sku" to "SNS-24", "available" to 64, "quarantine" to 0)), "loans" to JSONArray(), "purchases" to JSONArray(), "settings" to json("companyAddress" to "上海市示范路38号（合成）", "companyReceiver" to "演示收件人", "companyPhone" to "000-00000000"))
    }
    private fun net(o: JSONObject): Long = o.array("cash").objects().filter { it.optBoolean("verified") }.sumOf { it.optLong("amountCents") * if (it.optString("kind") == "refund") -1 else 1 }
    private fun view(original: JSONObject): JSONObject {
        val o = original.copyJSON()
        val due = o.optLong("receivableCents", o.optJSONObject("quote")?.optLong("amountCents") ?: 0L)
        val missing = JSONArray()
        if (o.optString("outcome").isBlank()) missing.put("履约未确认结束")
        if (due != net(o)) missing.put("应收与核实净收款未对齐")
        if (o.array("cash").objects().any { !it.optBoolean("verified") || !it.optBoolean("handedOver") }) missing.put("现金核实与交接未齐")
        if (o.optJSONObject("documents")?.optString("requirement") == "unknown" || o.optString("invoiceRequirement") == "unknown") missing.put("资料 / 发票约定待确认")
        if (o.optJSONObject("documents")?.let { it.optString("requirement") == "required" && !it.optBoolean("sent") } == true) missing.put("资料尚未发送")
        if (o.optString("invoiceRequirement") == "required" && o.array("invoices").objects().filter { !it.optBoolean("voided") }.sumOf { it.optLong("amountCents") } < o.optLong("invoiceDueCents")) missing.put("应开发票未齐")
        if (listOf("issues", "obligations").any { key -> o.array(key).objects().any { !it.optBoolean("resolved") } }) missing.put("异议 / 余项待办")
        if (state.array("loans").objects().any { it.optString("orderId") == o.optString("id") && it.optInt("outstanding") > it.array("transfers").objects().sumOf { transfer -> transfer.optInt("quantity") } }) missing.put("借用配件待归还")
        if (o.array("commissions").objects().any { !it.optBoolean("settled") }) missing.put("提成待结算")
        if (o.optString("outcome").isNotBlank() && o.optString("status") != "completed") o.put("status", if (missing.length() == 0) "pending_completion" else "settling")
        o.put("summary", json("collectedCents" to net(o), "receivableCents" to due, "remainingCents" to (due - net(o)).coerceAtLeast(0), "missing" to missing, "nextTask" to if (missing.length() > 0) missing.optString(0) else "核对后整单完结", "warrantyLabel" to if (o.has("warranty")) "已起保" else "未起保"))
        if (role !in listOf("admin", "dispatcher", "finance")) { o.put("commissions", JSONArray()); o.put("costs", JSONArray(o.array("costs").objects().filter { it.optString("ownerId") == actor.getString("id") })); if (role != "engineer") o.remove("remark") }
        if (role in listOf("customer", "supplier", "outsource")) { listOf("cash", "visits", "outsource", "obligations").forEach { key -> if (key == "cash") o.put(key, JSONArray(o.array(key).objects().filter { it.optBoolean("verified") })) else o.put(key, JSONArray()) } }
        o.put("allowedActions", JSONArray(actions(original)))
        return o
    }
    fun bootstrap(): JSONObject = state.copyJSON().apply {
        put("actor", actor.copyJSON()); put("orders", JSONArray(state.array("orders").objects().filter(::visible).map(::view)))
        if (role !in listOf("admin", "dispatcher", "engineer", "warehouse", "qc", "finance")) put("parts", JSONArray())
        if (role !in listOf("admin", "warehouse", "dispatcher")) put("loans", JSONArray(if (role == "engineer") state.array("loans").objects().filter { it.optString("borrowerId") == actor.getString("id") } else emptyList<JSONObject>()))
        if (role !in listOf("admin", "warehouse", "finance", "dispatcher")) put("purchases", JSONArray(if (role == "supplier") state.array("purchases").objects().filter { it.optString("supplier") in listOf(actor.getString("id"), actor.getString("name")) } else emptyList<JSONObject>()))
    }
    fun orders(q: String, status: String, page: Int): JSONObject {
        val rows = state.array("orders").objects().filter(::visible).map(::view).filter { (q.isBlank() || listOf("number", "device", "project", "customer").any { key -> it.optString(key).contains(q, true) }) && (status.isBlank() || it.optString("status") == status) }
        return json("items" to JSONArray(rows.drop((page - 1) * 30).take(30)), "total" to rows.size, "page" to page, "totalPages" to (rows.size + 29) / 30)
    }
    fun detail(id: String): JSONObject = view(state.array("orders").objects().firstOrNull { it.optString("id") == id && visible(it) } ?: throw Rejection(404, "演示工单不存在或没有权限"))
    private fun actions(o: JSONObject): List<String> {
        val company = listOf("admin", "dispatcher")
        val permissions = mapOf("sign_quote" to listOf("customer"), "accept" to listOf("customer"), "intake" to company, "assign" to company, "approve_quote" to company, "failure" to company, "complete" to company, "reopen" to company, "rework" to company, "requirements" to company, "outsource" to company, "obligation" to company, "resolve_issue" to company, "review_acceptance" to company, "handover_contact" to company)
        val warehouse = listOf("receive", "stock_ready", "dispatch")
        val finance = listOf("verify_cash", "handover_cash", "invoice", "void_invoice", "adjust_receivable", "approve_cost", "commission", "settle_commission")
        val stages = mapOf("intake" to "pending_intake", "diagnose" to "pending_arrangement", "approve_quote" to "diagnosis_quotation", "sign_quote" to "pending_customer_confirmation", "start" to "pending_execution", "finish" to "repairing", "qc" to "pending_quality_check", "stock_ready" to "pending_execution", "dispatch" to "pending_delivery", "deliver" to "pending_delivery", "accept" to "pending_acceptance", "complete" to "pending_completion", "reopen" to "completed")
        return Forms.all.map { it.key }.filter { action ->
            val allowed = permissions[action] ?: when (action) {
                in warehouse -> listOf("admin", "warehouse")
                in finance -> listOf("admin", "finance")
                "quote", "diagnose", "report" -> listOf("admin", "dispatcher", "engineer", "outsource")
                "start", "finish", "start_visit" -> listOf("admin", "engineer", "outsource")
                "qc" -> listOf("admin", "qc")
                "deliver" -> listOf("admin", "warehouse", "engineer", "dispatcher")
                "documents" -> listOf("admin", "dispatcher", "finance")
                "cash", "cost" -> listOf("admin", "dispatcher", "engineer", "warehouse", "finance")
                "remark", "resolve_obligation" -> listOf("admin", "dispatcher", "engineer", "warehouse", "qc", "finance")
                "visit" -> listOf("admin", "dispatcher", "engineer")
                else -> roles.filter { it != "supplier" }
            }
            role in allowed && (stages[action] == null || stages[action] == o.optString("status")) &&
                (o.optString("status") != "completed" || action in listOf("reopen", "rework", "remark", "evidence", "delete_evidence", "handover_contact")) &&
                (action != "start" || o.optString("type") != "sale") && (action != "stock_ready" || o.optString("type") == "sale") &&
                (action != "failure" || o.optString("outcome").isBlank()) && (action != "rework" || o.optString("outcome") == "accepted") &&
                (action != "review_acceptance") && (action !in listOf("visit", "start_visit") || o.optString("type") == "onsite") &&
                (action != "receive" || o.optString("status") in listOf("pending_arrangement", "pending_quality_check")) &&
                (action != "report" || o.optString("status") == "diagnosis_quotation") &&
                (action != "quote" || o.optString("status") in listOf("diagnosis_quotation", "pending_customer_confirmation", "pending_execution"))
        }
    }
    fun write(path: String, body: JSONObject, key: String): JSONObject {
        replay[key]?.let { reject(it.first == path + body.toString(), "请求键内容冲突"); return it.second.copyJSON() }
        val before = state
        state = state.copyJSON()
        try {
            val result = when {
                path == "/orders" -> { reject(role in listOf("admin", "dispatcher", "customer"), "当前角色不能创建工单"); newOrder(body).also { state.array("orders").put(it) }.let(::view) }
                path.startsWith("/orders/") -> orderAction(path.split('/')[2], body)
                path == "/loans" || path.startsWith("/loans/") || path == "/purchases" || path.startsWith("/purchases/") -> inventory(path, body)
                else -> throw Rejection(422, "此操作请连接服务器办理")
            }
            replay[key] = (path + body.toString()) to result.copyJSON()
            return result
        } catch (error: Exception) { state = before; throw error }
    }
    private fun row(array: JSONArray, id: String): JSONObject = array.objects().firstOrNull { it.optString("id") == id } ?: throw Rejection(422, "记录 ID 不存在")
    private fun orderAction(orderId: String, body: JSONObject): JSONObject {
        val o = state.array("orders").objects().firstOrNull { it.optString("id") == orderId && visible(it) } ?: throw Rejection(404, "没有此工单权限")
        val action = body.optString("type"); val p = body.optJSONObject("payload") ?: JSONObject()
        reject(body.optInt("version") == o.getInt("version"), "工单已更新，请重载详情")
        reject(action in actions(view(o)), "当前角色或阶段不能办理")
        val quote = o.optJSONObject("quote") ?: JSONObject()
        val unresolved = o.array("issues").objects().any { !it.optBoolean("resolved") }
        fun event(array: String, prefix: String): JSONObject = p.copyJSON().put("id", id(prefix)).also { o.array(array).put(it) }
        fun resolve(array: String, field: String) { val item = row(o.array(array), p.optString(field)); reject(!item.optBoolean("resolved"), "事项已办理"); item.put("resolved", true); item.put("resolution", p.optString("note")) }
        when (action) {
            "intake" -> { reject(p.optString("ownerId") in users && p.optString("assigneeId") in listOf("engineer", "outsource"), "请选择有效责任人 / 执行人"); o.put("ownerId", p.getString("ownerId")); o.put("assigneeId", p.getString("assigneeId")); o.put("status", "pending_arrangement") }
            "assign" -> { reject(p.optString("assigneeId") in listOf("engineer", "outsource"), "执行人无效"); o.put("assigneeId", p.getString("assigneeId")) }
            "diagnose" -> o.put("status", "diagnosis_quotation")
            "quote" -> { val amount = p.optLong("amountCents"); val prepay = p.optLong("prepayCents"); reject(amount > 0 || (o.optBoolean("freeRework") && amount == 0L), "报价须大于零，免费返修可为零"); reject(prepay in 0..amount && (!p.optBoolean("startRequiresPrepayment") || prepay > 0), "预付款须合法且不超过总额"); reject(OffsetDateTime.parse(p.getString("validUntil")).isAfter(OffsetDateTime.now()), "报价有效期须晚于现在"); o.array("quoteHistory").put(quote.copyJSON()); o.put("quote", p.copyJSON().put("version", quote.optInt("version") + 1).put("approved", false).put("signed", false)); o.put("receivableCents", amount); o.put("status", "diagnosis_quotation") }
            "approve_quote" -> { reject(quote.optInt("version") > 0, "请先制定报价"); quote.put("approved", true); o.put("status", "pending_customer_confirmation") }
            "sign_quote" -> { reject(quote.optBoolean("approved") && p.optInt("quoteVersion") == quote.optInt("version") && p.optString("signature").startsWith("data:image/png;base64,"), "须签署当前已审核报价"); reject(OffsetDateTime.parse(quote.getString("validUntil")).isAfter(OffsetDateTime.now()), "报价已过期"); quote.put("signed", true); quote.put("signature", p.getString("signature")); quote.put("signedAt", nowISO()); o.put("status", "pending_execution") }
            "start", "stock_ready" -> { reject(quote.optBoolean("approved") && quote.optBoolean("signed") && !unresolved, "报价未签署或存在异议"); val required = if (o.optString("type") == "sale" && quote.optString("paymentTerms") == "cash") quote.optLong("amountCents") else if (o.optString("type") == "sale" || quote.optBoolean("startRequiresPrepayment")) quote.optLong("prepayCents") else 0; reject(net(o) >= required, "约定执行前款项未核实"); if (action == "stock_ready") { val part = row(state.array("parts"), p.optString("partId")); val quantity = p.optInt("quantity"); reject(quantity > 0 && part.optInt("available") >= quantity, "可用库存不足"); part.put("available", part.getInt("available") - quantity) }; o.put("status", if (action == "start") "repairing" else "pending_delivery") }
            "finish" -> o.put("status", "pending_quality_check")
            "qc" -> o.put("status", if (p.optBoolean("passed")) "pending_delivery" else "repairing")
            "deliver" -> { reject(!OffsetDateTime.parse(p.getString("deliveredAt")).isBefore(OffsetDateTime.parse(o.getString("createdAt"))), "交付不得早于工单创建"); o.put("deliveredAt", p.getString("deliveredAt")); o.put("status", "pending_acceptance") }
            "accept" -> { reject(p.optString("signature").startsWith("data:image/png;base64,"), "请手写签名"); reject(!p.optBoolean("passed") || !unresolved, "未结异议阻止通过"); event("acceptanceRecords", "sign_").put("signedAt", nowISO()).put("signerId", actor.getString("id")); if (p.optBoolean("passed")) { o.put("outcome", "accepted"); o.put("acceptedAt", nowISO()); o.put("warranty", json("startsAt" to nowISO(), "endsAt" to OffsetDateTime.now().plusMonths(quote.optInt("warrantyMonths").toLong()).toString())); o.put("status", "settling") } else event("issues", "issue_").put("resolved", false) }
            "cash" -> { reject(p.optLong("amountCents") > 0 && p.optString("kind") in listOf("receipt", "refund"), "金额 / 款项方向无效"); event("cash", "cash_").put("collector", actor.getString("id")).put("verified", false).put("handedOver", false) }
            "verify_cash" -> { val cash = row(o.array("cash"), p.optString("cashId")); reject(!cash.optBoolean("verified"), "已核实"); reject(cash.optString("kind") != "refund" || cash.optLong("amountCents") <= net(o), "退款不能超过已核实净收款"); cash.put("verified", true) }
            "handover_cash" -> { val cash = row(o.array("cash"), p.optString("cashId")); reject(cash.optBoolean("verified"), "请先核实"); cash.put("handedOver", true) }
            "requirements" -> { o.getJSONObject("documents").put("requirement", p.optString("documentRequirement")).put("reason", p.optString("documentReason")); o.put("invoiceRequirement", p.optString("invoiceRequirement")); o.put("invoiceDueCents", p.optLong("invoiceDueCents")); o.put("invoiceReason", p.optString("invoiceReason")) }
            "documents" -> {
                val ids = p.array("files")
                val validFiles = ids.length() > 0 && (0 until ids.length()).all { index -> o.array("evidence").objects().any { it.optString("id") == ids.optString(index) && !it.optBoolean("deleted") && (it.optString("text").isNotBlank() || it.optString("data").isNotBlank()) } }
                reject(!p.optBoolean("prepared") || validFiles, "制作资料须引用有效证据附件")
                reject(!p.optBoolean("sent") || p.optBoolean("prepared") && p.optString("recipient").isNotBlank() && validFiles, "发送须有已制作资料、附件和接收对象")
                p.keys().forEach { o.getJSONObject("documents").put(it, p.get(it)) }
            }
            "invoice" -> { reject(o.optString("invoiceRequirement") == "required", "当前没有开票约定"); reject(o.array("invoices").objects().none { it.optString("number") == p.optString("number") && !it.optBoolean("voided") }, "票号重复"); reject(p.array("files").length() > 0 && p.array("files").let { ids -> (0 until ids.length()).all { n -> o.array("evidence").objects().any { it.optString("id") == ids.optString(n) && it.optString("mime") in listOf("application/pdf", "image/png", "image/jpeg") && it.optString("data").isNotBlank() } } }, "请引用已上传的发票原件"); event("invoices", "invoice_").put("voided", false) }
            "void_invoice" -> row(o.array("invoices"), p.optString("invoiceId")).put("voided", true)
            "adjust_receivable" -> { reject(p.optLong("amountCents") >= 0, "应收不得为负"); o.put("receivableCents", p.optLong("amountCents")) }
            "remark" -> { if (p.has("remark") && role !in listOf("qc", "warehouse")) o.put("remark", p.get("remark")); if (p.has("customerNote")) o.put("customerNote", p.get("customerNote")) }
            "evidence" -> event("evidence", "ev_").put("uploaderId", actor.getString("id")).put("createdAt", nowISO())
            "delete_evidence" -> row(o.array("evidence"), p.optString("evidenceId")).put("deleted", true)
            "issue" -> event("issues", "issue_").put("resolved", false)
            "resolve_issue" -> resolve("issues", "issueId")
            "obligation" -> event("obligations", "task_").put("resolved", false)
            "resolve_obligation" -> { val task = row(o.array("obligations"), p.optString("obligationId")); reject(role in listOf("admin", "dispatcher") || task.optString("ownerId") == actor.getString("id"), "只能办妥本人余项"); resolve("obligations", "obligationId") }
            "visit" -> if (p.optString("id").isBlank()) event("visits", "visit_") else row(o.array("visits"), p.getString("id")).apply { p.keys().forEach { put(it, p.get(it)) } }
            "start_visit" -> row(o.array("visits"), p.optString("visitId")).put("startedAt", nowISO())
            "outsource" -> event("outsource", "out_")
            "cost" -> event("costs", "cost_").put("ownerId", actor.getString("id")).put("approved", false)
            "approve_cost" -> row(o.array("costs"), p.optString("costId")).put("approved", true)
            "commission" -> event("commissions", "commission_").put("settled", false)
            "settle_commission" -> row(o.array("commissions"), p.optString("commissionId")).put("settled", true)
            "failure" -> {
                reject(o.optString("outcome").isBlank(), "已有履约结果")
                o.put("outcome", "failed"); o.put("failureReason", p.optString("reason")); o.put("status", "settling"); o.put("receivableCents", p.optLong("amountCents"))
                if (p.optBoolean("returnRequired")) o.array("obligations").put(json("id" to id("return_"), "title" to "核实设备退件及客户实收", "ownerId" to "warehouse", "dueAt" to OffsetDateTime.now().plusDays(2).toString(), "resolved" to false))
            }
            "complete" -> { reject(view(o).getJSONObject("summary").array("missing").length() == 0, "还有未办缺项"); o.put("status", "completed") }
            "reopen" -> o.put("status", "settling")
            "rework" -> { if (p.optBoolean("free")) reject(o.optJSONObject("warranty")?.optString("endsAt")?.let { OffsetDateTime.parse(it).isAfter(OffsetDateTime.now()) } == true, "免费返修须在有效质保内"); val child = newOrder(json("type" to o.optString("type"), "customer" to o.optString("customer"), "customerId" to o.optString("customerId"), "companyId" to o.optString("companyId"), "device" to o.optString("device"), "description" to p.optString("note").ifBlank { "返修检测" }, "originalOrderId" to o.getString("id"))).put("freeRework", p.optBoolean("free")); state.array("orders").put(child); return view(child) }
            "handover_contact" -> { reject(p.optString("customerId") in listOf("customer", "customer-peer") && o.optString("companyId") == "company-a", "新经办人须属于同企业"); o.put("customerId", p.getString("customerId")) }
            "receive", "report", "dispatch" -> Unit
            else -> throw Rejection(422, "此动作请连接服务器办理")
        }
        o.put("version", o.getInt("version") + 1); o.put("updatedAt", nowISO())
        o.array("events").put(json("id" to id("event_"), "title" to Forms.titles[action], "note" to p.optString("note"), "at" to nowISO(), "actorName" to actor.getString("name")))
        val result = view(o); o.put("status", result.getString("status")); return result
    }
    private fun inventory(path: String, body: JSONObject): JSONObject {
        reject(role in listOf("admin", "warehouse", "dispatcher", "engineer"), "当前角色没有库存操作权限")
        val quantity = if (body.has("payload")) body.getJSONObject("payload").optInt("quantity") else body.optInt("quantity")
        reject(quantity > 0, "数量必须大于零")
        if (path == "/loans") {
            reject(role in listOf("admin", "warehouse"), "只有仓库 / 管理员可以借出")
            reject(body.optString("note").isNotBlank(), "请填写借出交接依据")
            reject(body.optString("borrowerId") == "engineer", "责任人须为有效工程师")
            val part = row(state.array("parts"), body.optString("partId")); reject(part.optInt("available") >= quantity, "库存不足")
            if (body.optString("orderId").isNotBlank()) reject(detail(body.getString("orderId")).optString("status") != "completed", "已完结工单须先重开")
            part.put("available", part.getInt("available") - quantity)
            return body.copyJSON().put("id", id("loan_")).put("version", 1).put("partName", part.optString("name")).put("outstanding", quantity).put("transfers", JSONArray()).also { state.array("loans").put(it) }
        }
        if (path == "/purchases") { reject(role in listOf("admin", "warehouse", "dispatcher"), "只有管理员 / 仓库 / 调度可采购"); reject(body.optString("supplier").isNotBlank() && body.optString("note").isNotBlank() && body.optLong("unitCents") > 0, "采购须有供应商、单价及批准依据"); row(state.array("parts"), body.optString("partId")); return body.copyJSON().put("id", id("purchase_")).put("version", 1).put("received", 0).also { state.array("purchases").put(it) } }
        val purchase = path.startsWith("/purchases/")
        val item = row(state.array(if (purchase) "purchases" else "loans"), path.split('/')[2])
        reject(body.optInt("version") == item.optInt("version"), "记录已更新，请重载")
        val part = row(state.array("parts"), item.optString("partId"))
        if (purchase) { reject(role in listOf("admin", "warehouse") && item.optInt("received") + quantity <= item.optInt("quantity") && body.optString("note").isNotBlank(), "无权收货、超出采购数或缺收货依据"); item.put("received", item.optInt("received") + quantity); part.put("available", part.getInt("available") + quantity) }
        else {
            val type = body.optString("type"); val p = body.getJSONObject("payload")
            reject(quantity <= item.optInt("outstanding"), "超过尚欠数量")
            if (type == "return") {
                reject(role in listOf("admin", "warehouse"), "归还须仓库 / 管理员验收")
                reject(p.optString("condition") in listOf("good", "quarantine"), "归还状态无效")
                val field = if (p.optString("condition") == "good") "available" else "quarantine"
                part.put(field, part.optInt(field) + quantity)
                val returned = if (field == "available") "returnedGood" else "returnedQuarantine"
                item.put(returned, item.optInt(returned) + quantity)
            }
            else {
                reject(role == "admin" && p.optString("reason").isNotBlank(), "耗用 / 处置 / 转跟踪须管理员批准及原因")
                reject(type in listOf("consume", "dispose", "transfer"), "借还动作无效")
                if (type == "consume") reject(item.optString("orderId").isNotBlank(), "维修耗用必须关联工单")
                if (type == "transfer") {
                    reject(p.optString("ownerId") in listOf("admin", "warehouse", "engineer") && p.optString("dueAt").isNotBlank(), "独立跟踪须有有效责任人及截止时间")
                    val transfers = item.array("transfers")
                    reject(quantity <= item.optInt("outstanding") - transfers.objects().sumOf { it.optInt("quantity") }, "此数量已转独立跟踪")
                    transfers.put(json("quantity" to quantity, "ownerId" to p.getString("ownerId"), "dueAt" to p.getString("dueAt"), "reason" to p.getString("reason"), "at" to nowISO()))
                    item.put("transfers", transfers)
                }
            }
            if (type != "transfer") {
                item.put("outstanding", item.getInt("outstanding") - quantity)
                if (type in listOf("consume", "dispose")) { val field = if (type == "consume") "consumed" else "disposed"; item.put(field, item.optInt(field) + quantity) }
                var remaining = quantity
                item.array("transfers").objects().forEach { transfer ->
                    val cleared = minOf(remaining, transfer.optInt("quantity"))
                    transfer.put("quantity", transfer.optInt("quantity") - cleared)
                    remaining -= cleared
                }
            }
        }
        item.put("version", item.getInt("version") + 1); return item.copyJSON()
    }
}
