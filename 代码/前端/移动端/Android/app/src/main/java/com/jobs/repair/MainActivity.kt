package com.jobs.repair

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Bundle
import android.os.Build
import android.view.WindowInsets
import android.provider.OpenableColumns
import android.text.InputType
import android.util.Base64
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.concurrent.Executors

/** 业务界面全部使用 Android 原生控件，窄屏纵排，大屏限制阅读宽度。 */
class MainActivity : Activity() {
    private val repository = Repository()
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var root: LinearLayout
    private lateinit var body: LinearLayout
    private var busy = false
    private var destroyed = false
    private var tab = "首页"
    private var selected: JSONObject? = null
    private var query = ""
    private var status = ""
    private var page = 1
    private var totalPages = 1
    private var rows = JSONArray()
    private var pendingFileOrder: JSONObject? = null
    private var pendingDownload: ByteArray? = null
    private var activeForm: AlertDialog? = null
    private var activeSettings: AlertDialog? = null
    private var pendingAppearance = false
    private var loginUsername = "customer"
    private var loginPassword = DemoStore.password
    private var loginInputs: Pair<EditText, EditText>? = null
    private val languages = listOf("zh-Hans" to "简体中文", "zh-Hant" to "繁體中文", "bo" to "བོད་ཡིག", "en" to "English", "ja" to "日本語", "fr" to "Français", "es" to "Español", "de" to "Deutsch", "ru" to "Русский", "ko" to "한국어")
    private val interfaceCatalog by lazy {
        runCatching { assets.open("ui-l10n.json").bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()).optJSONObject("messages") } }.getOrNull()
    }
    private fun tr(value: String): String {
        val code = getPreferences(MODE_PRIVATE).getString("language", "zh-Hans") ?: "zh-Hans"
        return interfaceCatalog?.optJSONObject(code)?.optString(value, value) ?: value
    }
    private fun literal(value: String): String {
        val direct = tr(value)
        if (direct != value) return if (value.trim() != value) value.replace(value.trim(), direct.trim()) else direct
        if (value.isBlank()) return value
        val code = getPreferences(MODE_PRIVATE).getString("language", "zh-Hans") ?: "zh-Hans"
        val messages = interfaceCatalog?.optJSONObject(code) ?: return value
        val key = messages.keys().asSequence().firstOrNull { it.trim() == value.trim() } ?: return value
        return value.takeWhile(Char::isWhitespace) + messages.optString(key, value).trim() + value.takeLastWhile(Char::isWhitespace)
    }
    // Only source literals use token lookup; customer-entered strings use exact lookup.
    private fun staticText(value: String): String {
        val direct = literal(value)
        if (direct != value) return direct
        val result = StringBuilder()
        var start = 0
        Regex("[\\s\\p{P}]+").findAll(value).forEach { match ->
            result.append(literal(value.substring(start, match.range.first)))
            result.append(match.value)
            start = match.range.last + 1
        }
        return result.append(literal(value.substring(start))).toString()
    }
    private val themedContext get() = ContextThemeWrapper(this, if (dark) android.R.style.Theme_Material_NoActionBar else android.R.style.Theme_Material_Light_NoActionBar)
    private val dark: Boolean
        get() = when (getPreferences(MODE_PRIVATE).getString("appearance", "system")) {
            "dark" -> true
            "light" -> false
            else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        }
    private val green get() = Color.parseColor(if (dark) "#8CCBA8" else "#0F5144")
    private val ink get() = Color.parseColor(if (dark) "#EFF6F1" else "#152820")
    private val muted get() = Color.parseColor(if (dark) "#B5C7BB" else "#53675D")
    private val canvas get() = Color.parseColor(if (dark) "#101C18" else "#F3F6F4")
    private val surface get() = Color.parseColor(if (dark) "#192A22" else "#FFFFFF")
    private val soft get() = Color.parseColor(if (dark) "#233E2F" else "#E9F2ED")
    private val outline get() = Color.parseColor(if (dark) "#3B5345" else "#D8E3DC")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val saved = getPreferences(MODE_PRIVATE).getString("endpoint", "http://10.0.2.2:8098")!!
        runCatching { repository.configure(saved) }
        render()
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (getPreferences(MODE_PRIVATE).getString("appearance", "system") != "system") return
        if (activeForm?.isShowing == true || activeSettings?.isShowing == true) {
            // Keep the current business form and its input intact until it closes.
            pendingAppearance = true
        } else {
            render()
        }
    }
    private fun applyPendingAppearance() {
        if (pendingAppearance && !destroyed) {
            pendingAppearance = false
            render()
        }
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun column(): LinearLayout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
    private fun text(value: String, size: Float = 15f, color: Int = ink): TextView = TextView(this).apply {
        text = tr(value)
        textSize = size
        setTextColor(color)
        setPadding(0, dp(4), 0, dp(4))
        setLineSpacing(dp(3).toFloat(), 1.1f)
        setTextIsSelectable(true)
    }
    private fun button(title: String, primary: Boolean = false, callback: () -> Unit): Button = Button(this).apply {
        text = tr(title)
        isAllCaps = false
        textSize = 15f
        minHeight = dp(48)
        minimumHeight = dp(48)
        gravity = Gravity.CENTER
        setPadding(dp(16), dp(12), dp(16), dp(12))
        setTextColor(if (primary) Color.WHITE else green)
        setTypeface(typeface, Typeface.BOLD)
        background = RippleDrawable(ColorStateList.valueOf(outline), GradientDrawable().apply {
            setColor(if (primary) Color.parseColor("#0F5144") else soft)
            cornerRadius = dp(10).toFloat()
        }, null)
        layoutParams = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(4); bottomMargin = dp(8) }
        setOnClickListener { if (!busy) callback() }
    }
    private fun styleDialogControls(dialog: AlertDialog) {
        dialog.window?.setBackgroundDrawable(GradientDrawable().apply {
            setColor(surface)
            cornerRadius = dp(16).toFloat()
        })
        listOf(AlertDialog.BUTTON_POSITIVE, AlertDialog.BUTTON_NEGATIVE).forEach { id ->
            dialog.getButton(id)?.apply {
                isAllCaps = false
                maxLines = 2
                textSize = 14f
                minHeight = dp(48)
                setTextColor(green)
            }
        }
    }
    private fun settingsButton(): Button = button("⚙") { environment() }.apply {
        textSize = 24f
        contentDescription = tr("服务器与超时设置")
        tooltipText = contentDescription
        setPadding(0, 0, 0, 0)
        layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
    }
    private fun input(hint: String, value: String = ""): EditText = EditText(this).apply {
        this.hint = tr(hint)
        setText(value)
        textSize = 16f
        setSingleLine(false)
        setTextColor(ink)
        setHintTextColor(muted)
        minHeight = dp(52)
        setPadding(dp(14), dp(12), dp(14), dp(12))
        background = GradientDrawable().apply { setColor(surface); cornerRadius = dp(10).toFloat(); setStroke(dp(1), outline) }
        layoutParams = LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(12) }
    }
    private fun card(title: String, subtitle: String = "", click: (() -> Unit)? = null): LinearLayout = column().apply {
        setPadding(dp(20), dp(16), dp(20), dp(16))
        background = GradientDrawable().apply { setColor(surface); cornerRadius = dp(16).toFloat() }
        layoutParams = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(4); bottomMargin = dp(12) }
        addView(text(title, 18f).apply { setTypeface(typeface, Typeface.BOLD) })
        if (subtitle.isNotBlank()) addView(text(subtitle, 14f, muted))
        if (click != null) { addView(button("查看详情与办理", callback = click)) }
    }
    private fun heading(title: String, subtitle: String = "") {
        body.addView(text(title, 28f).apply { setTypeface(typeface, Typeface.BOLD); setPadding(0, dp(16), 0, dp(8)) })
        if (subtitle.isNotBlank()) body.addView(text(subtitle, 15f, muted).apply { setPadding(0, 0, 0, dp(16)) })
    }
    private fun toast(message: String) { Toast.makeText(this, tr(message), Toast.LENGTH_LONG).show() }
    private fun empty(title: String, reload: () -> Unit) { body.addView(card(tr("暂无{title}").replace("{title}", tr(title)), "当前条件下没有可见记录。可调整筛选，或重新加载。")); body.addView(button("重新加载", callback = reload)) }
    private fun async(task: () -> Unit, success: () -> Unit = { render() }) {
        if (busy) return
        busy = true
        worker.execute {
            val error = runCatching(task).exceptionOrNull()
            runOnUiThread {
                busy = false
                if (!destroyed) {
                    if (error != null) {
                        toast(error.message ?: "操作未完成")
                        if (repository.actor == null) {
                            activeForm?.dismiss()
                            activeForm = null
                            selected = null
                            rows = JSONArray()
                            pendingDownload = null
                            render()
                        }
                    }
                    else success()
                }
            }
        }
    }

    private fun render() {
        loginInputs?.let { (username, password) ->
            loginUsername = username.text.toString()
            if (repository.actor == null) loginPassword = password.text.toString()
        }
        if (repository.actor != null) loginPassword = ""
        loginInputs = null
        root = column().apply { setBackgroundColor(canvas); fitsSystemWindows = true }
        setContentView(root)
        window.statusBarColor = canvas
        window.navigationBarColor = canvas
        if (Build.VERSION.SDK_INT >= 30) {
            val lightBars = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (dark) 0 else lightBars, lightBars)
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        val header = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL; setPadding(dp(20), dp(16), dp(20), dp(16)); setBackgroundColor(surface) }
        header.addView(ImageView(this).apply { setImageResource(com.jobs.repair.R.drawable.repair_logo); contentDescription = tr("啄木鸟维修标志") }, LinearLayout.LayoutParams(dp(44), dp(44)).apply { marginEnd = dp(12) })
        header.addView(column().apply {
            addView(text("啄木鸟 · 维修服务", 20f).apply { setTypeface(typeface, Typeface.BOLD) })
            addView(text(if (repository.actor == null) "维修进度与工单协作" else repository.actor!!.optString("name") + " · " + tr(if (repository.demo) "独立演示" else "服务器已连接"), 13f, muted))
        }, LinearLayout.LayoutParams(0, -2, 1f))
        root.addView(header)
        val scroll = ScrollView(this)
        val frame = FrameLayout(this)
        body = column().apply { setPadding(dp(20), dp(8), dp(20), dp(24)) }
        frame.addView(body, FrameLayout.LayoutParams(minOf(resources.displayMetrics.widthPixels, dp(900)), -2, Gravity.CENTER_HORIZONTAL))
        scroll.addView(frame)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        if (repository.actor == null) { login(); return }
        if (selected != null) { detail(); return }
        if (repository.message.isNotBlank()) body.addView(text(repository.message, 13f, muted))
        when (tab) { "首页" -> home(); "工单" -> orders(); "库存" -> inventory(); "我的" -> profile() }
        val navigation = LinearLayout(this).apply { setPadding(dp(12), dp(8), dp(12), dp(8)); setBackgroundColor(surface) }
        listOf("首页", "工单", "库存", "我的").forEach { title ->
            navigation.addView(button(title, primary = title == tab) { tab = title; if (title == "工单") loadOrders() else render() }.apply { textSize = 13f; setPadding(dp(6), dp(8), dp(6), dp(8)); minHeight = dp(56); maxLines = 2 }, LinearLayout.LayoutParams(0, -2, 1f))
        }
        root.addView(navigation)
    }

    private fun login() {
        heading("每一单维修，心中有数", "提交需求、跟进进度、确认报价与验收。可先浏览独立演示。")
        val username = input("账号", loginUsername)
        val password = input("密码", loginPassword).apply { inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD }
        loginInputs = username to password
        body.addView(text("账号")); body.addView(username); body.addView(text("密码")); body.addView(password)
        body.addView(button("登录并进入工作台", primary = true) { async({ repository.login(username.text.toString(), password.text.toString()); rows = repository.snapshot.array("orders") }) })
        body.addView(button("选择示例角色") { AlertDialog.Builder(themedContext).setTitle(tr("示例账号（合成数据）")).setItems(DemoStore.users.toTypedArray()) { _, index -> username.setText(DemoStore.users[index]); password.setText(DemoStore.password) }.show().also(::styleDialogControls) })
        body.addView(card("第一次使用", "1、保留示例密码，点击登录。\n2、服务器不可用时自动进入可操作的独立演示。\n3、点击工单卡片，再点击页面底部的业务操作。\n4、连接真实服务器后刷新，服务器数据会自动替换演示。"))
        body.addView(settingsButton())
    }
    private fun home() {
        heading("今日工作台", "当前资料仅按登录身份展示")
        body.addView(button("刷新资料") { async({ repository.refresh(); rows = repository.snapshot.array("orders") }) })
        val orders = repository.snapshot.array("orders").objects()
        val metrics = repository.snapshot.optJSONObject("metrics")
        body.addView(card(tr("进行中工单") + " · " + (metrics?.optInt("openCount") ?: orders.count { it.optString("status") != "completed" }), "待办 / 缺项可在每张工单的详情中查看"))
        if (repository.actor!!.optString("role") in listOf("customer", "admin", "dispatcher")) body.addView(button("提交新需求", primary = true) { create() })
        if (orders.isEmpty()) empty("工单") { loadOrders() }
        else orders.take(5).forEach { order -> orderCard(order) }
        body.addView(card("办理顺序", "提交需求 → 公司受理 → 检测报价 → 公司审核 → 客户手写签署 → 执行与质检 → 交付验收 → 资料、票款和余项齐备 → 完结。\n维修仅在报价明确约定先款时要求先核实预付款。"))
    }
    private fun orderCard(order: JSONObject) {
        body.addView(card(order.optString("device"), "${order.optString("number")} · ${tr(Forms.states[order.optString("status")] ?: order.optString("status"))}\n${order.optString("project")}\n${order.optJSONObject("summary")?.optString("nextTask") ?: tr("查看详情")}") { open(order.optString("id")) })
    }
    private fun loadOrders() { async({ val result = repository.orders(query, status, page); rows = result.array("items"); totalPages = result.optInt("totalPages").coerceAtLeast(1); tab = "工单" }) }
    private fun orders() {
        heading("我的工单", "搜索设备、客户、项目或编号")
        val search = input("输入关键词", query)
        body.addView(search)
        val spinner = Spinner(this)
        val keys = listOf("") + Forms.states.keys
        spinner.adapter = ArrayAdapter(themedContext, android.R.layout.simple_spinner_dropdown_item, (listOf("全部阶段") + Forms.states.values).map(::tr))
        spinner.setSelection(keys.indexOf(status).coerceAtLeast(0))
        body.addView(spinner)
        body.addView(button("查询 / 重新加载") { query = search.text.toString(); status = keys[spinner.selectedItemPosition]; page = 1; loadOrders() })
        if (repository.actor!!.optString("role") in listOf("customer", "admin", "dispatcher")) body.addView(button("＋ 提交新需求") { create() })
        if (rows.length() == 0) empty("工单") { loadOrders() } else rows.objects().forEach(::orderCard)
        body.addView(text(tr("第 \$page / \$totalPages 页").replace("\$page", page.toString()).replace("\$totalPages", totalPages.toString())))
        if (page > 1) body.addView(button("上一页") { page--; loadOrders() })
        if (page < totalPages) body.addView(button("下一页") { page++; loadOrders() })
    }
    private fun open(id: String) { async({ selected = repository.detail(id) }) }
    private fun detail() {
        val order = selected!!
        body.addView(button("← 返回工单列表") { selected = null; tab = "工单"; loadOrders() })
        heading(order.optString("device"), ((order.optString("number")).toString() + staticText(" · 版本 ") + (order.optInt("version")).toString() + "\nID：" + (order.optString("id")).toString()))
        body.addView(text(Forms.states[order.optString("status")] ?: order.optString("status"), 18f, green))
        body.addView(button("重新加载详情") { open(order.getString("id")) })
        body.addView(card("需求与客户", ((order.optString("customer")).toString() + "\n" + (order.optString("project")).toString() + "\n" + (order.optString("description")).toString() + staticText("\n对客备注：") + (order.optString("customerNote")).toString() + "\n" + (if (order.has("remark")) (staticText("内部备注：") + (order.optString("remark")).toString()) else "").toString())))
        val quote = order.optJSONObject("quote")
        body.addView(card("报价与确认", if (quote != null && quote.optInt("version") > 0) ((tr("报价版本")).toString() + " " + (quote.optInt("version")).toString() + " · " + (money(quote.optLong("amountCents"))).toString() + "\n" + (quote.optString("description")).toString() + staticText("\n质保 ") + (quote.optInt("warrantyMonths")).toString() + staticText(" 个月 · ") + (tr(Forms.choiceLabels[quote.optString("paymentTerms")].orEmpty())).toString() + staticText("\n预付 ") + (money(quote.optLong("prepayCents"))).toString() + " · " + (tr(if (quote.optBoolean("startRequiresPrepayment")) "明确先款开修" else "未约定先款开修")).toString() + staticText("\n公司审核：") + (yes(quote.optBoolean("approved"))).toString() + staticText(" · 客户签署：") + (yes(quote.optBoolean("signed"))).toString() + staticText("\n有效至 ") + (quote.optString("validUntil")).toString()) else tr("尚未报价")))
        order.optJSONObject("summary")?.let { summary -> body.addView(card("结算与缺项", (staticText("应收 ") + (money(summary.optLong("receivableCents"))).toString() + staticText(" · 已核实净收 ") + (money(summary.optLong("collectedCents"))).toString() + staticText("\n剩余 ") + (money(summary.optLong("remainingCents"))).toString() + "\n" + (summary.array("missing").let { a -> (0 until a.length()).joinToString("\n") { a.optString(it) } }.ifBlank { tr("当前无未办缺项") }).toString()))) }
        val sections = linkedMapOf("cash" to "收退款记录", "invoices" to "发票记录", "evidence" to "证据附件", "issues" to "客户异议", "obligations" to "未办余项", "visits" to "上门安排", "costs" to "成本", "commissions" to "提成", "acceptanceRecords" to "验收签署历史", "events" to "办理记录")
        sections.forEach { (key, title) ->
            val values = order.array(key).objects()
            val section = card(title, if (values.isEmpty()) "暂无记录，可重新加载详情" else "")
            values.forEach { value ->
                section.addView(text(record(value), 14f))
                if (key == "evidence" && !value.optBoolean("deleted") && !repository.demo) section.addView(button((staticText("保存附件 ") + (value.optString("name")).toString())) { async({ pendingDownload = repository.download("/orders/${order.getString("id")}/evidence/${value.getString("id")}") }, { saveDocument(value.optString("name", "附件"), value.optString("mime", "application/octet-stream")) }) })
            }
            body.addView(section)
        }
        order.optJSONObject("documents")?.let { body.addView(card("付款资料", record(it))) }
        heading("当前可办理", "操作入口按角色和阶段提供；服务器再次核验业务条件。")
        val actions = order.array("allowedActions")
        if (actions.length() == 0) body.addView(text("当前没有可办理动作"))
        Forms.all.filter { form -> (0 until actions.length()).any { actions.optString(it) == form.key } }.forEach { action -> body.addView(button(action.title) { actionForm(action, order) }) }
        if ((0 until actions.length()).any { actions.optString(it) == "evidence" }) body.addView(button("上传图片 / PDF / 音视频原件") { pendingFileOrder = order; startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "*/*"; putExtra(Intent.EXTRA_MIME_TYPES, supportedMIME); addCategory(Intent.CATEGORY_OPENABLE) }, 101) })
    }

    private fun defaults(order: JSONObject? = null): JSONObject = json("customer" to "海棠物业（合成）", "customerId" to if (repository.actor!!.optString("role") == "customer") repository.actor!!.optString("id") else "customer", "companyId" to if (repository.actor!!.optString("role") == "customer") repository.actor!!.optString("companyId") else "company-a", "ownerId" to "dispatcher", "assigneeId" to "engineer", "borrowerId" to "engineer", "dueAt" to OffsetDateTime.now().plusDays(7).toString(), "validUntil" to OffsetDateTime.now().plusDays(7).toString(), "occurredAt" to nowISO(), "deliveredAt" to nowISO(), "plannedAt" to OffsetDateTime.now().plusDays(1).toString(), "quoteVersion" to (order?.optJSONObject("quote")?.optInt("version") ?: 1), "warrantyMonths" to 3, "quantity" to 1, "prepayCents" to 0, "invoiceDueCents" to 0)
    private fun create() { form(Forms.create, defaults()) { payload, done -> async({ selected = repository.write("/orders", payload) }, { done(); render() }) } }
    private fun actionForm(action: ActionForm, order: JSONObject) {
        val initial = defaults(order)
        if (action.key == "remark") { initial.put("remark", order.optString("remark")); initial.put("customerNote", order.optString("customerNote")) }
        form(action, initial, action.key in listOf("accept", "sign_quote")) { payload, done ->
            if (action.key == "accept" && !payload.optBoolean("passed")) require(payload.optString("note").isNotBlank()) { "不通过验收时请填写异议内容" }
            if (action.key == "requirements") {
                require(payload.optString("documentRequirement") == "unknown" || payload.optString("documentReason").isNotBlank()) { "请填写资料约定说明" }
                require(payload.optString("invoiceRequirement") == "unknown" || payload.optString("invoiceReason").isNotBlank()) { "请填写发票约定说明" }
            }
            if (action.key == "evidence") { payload.put("kind", "text"); payload.put("mime", "text/plain") }
            async({ selected = repository.write("/orders/${order.getString("id")}/actions", json("type" to action.key, "version" to order.getInt("version"), "payload" to payload)) }, { done(); render() })
        }
    }
    private fun form(spec: ActionForm, defaults: JSONObject = JSONObject(), signature: Boolean = false, submit: (JSONObject, () -> Unit) -> Unit) {
        val fields = column().apply { setPadding(dp(20), dp(8), dp(20), dp(8)) }
        val readers = linkedMapOf<Field, () -> Any>()
        spec.fields.forEach { field ->
            if (field.key == "remark" && repository.actor!!.optString("role") in listOf("qc", "warehouse")) return@forEach
            fields.addView(text(tr(field.title) + if (field.required && field.kind != "bool") " *" else "", 14f))
            val relations = relationChoices(field.key)
            if (field.kind == "text" && relations.isNotEmpty()) {
                val choices = if (field.required) relations else listOf("" to tr("不关联 / 留空")) + relations
                val chooser = Spinner(this)
                chooser.adapter = ArrayAdapter(themedContext, android.R.layout.simple_spinner_dropdown_item, choices.map { it.second })
                chooser.setSelection(choices.indexOfFirst { it.first == defaults.optString(field.key) }.coerceAtLeast(0))
                fields.addView(chooser)
                readers[field] = { choices[chooser.selectedItemPosition].first }
                return@forEach
            }
            when (field.kind) {
                "bool" -> { val view = CheckBox(this).apply { text = tr(field.title); setTextColor(ink); isChecked = defaults.optBoolean(field.key, field.key == "passed") }; fields.addView(view); readers[field] = { view.isChecked } }
                "choice" -> { val view = Spinner(this); view.adapter = ArrayAdapter(themedContext, android.R.layout.simple_spinner_dropdown_item, field.choices.map { tr(Forms.choiceLabels[it] ?: it) }); view.setSelection(field.choices.indexOf(defaults.optString(field.key)).coerceAtLeast(0)); fields.addView(view); readers[field] = { field.choices[view.selectedItemPosition] } }
                else -> {
                    val value = if (defaults.has(field.key)) if (field.kind == "money") BigDecimal.valueOf(defaults.optLong(field.key), 2).toPlainString() else defaults.optString(field.key) else ""
                    val view = input(if (field.kind == "date") "例如 2026-10-30T10:00:00+08:00" else field.title, value)
                    if (field.kind in listOf("int", "money")) view.inputType = InputType.TYPE_CLASS_NUMBER or if (field.kind == "money") InputType.TYPE_NUMBER_FLAG_DECIMAL else 0
                    fields.addView(view)
                    readers[field] = {
                        val raw = view.text.toString().trim()
                        require(!field.required || raw.isNotBlank()) { (tr("请输入") + ": " + tr(field.title)) }
                        when (field.kind) {
                            "money" -> { val result = BigDecimal(raw.ifBlank { "0" }).movePointRight(2).longValueExact(); require(result >= 0) { "金额不得为负" }; result }
                            "int" -> raw.ifBlank { "0" }.toInt().also { require(it >= 0) { "数量不得为负" } }
                            "ids" -> JSONArray(raw.split(',', '，').map(String::trim).filter(String::isNotEmpty))
                            "date" -> OffsetDateTime.parse(raw).toString()
                            else -> raw
                        }
                    }
                }
            }
        }
        val ink = if (signature) SignatureView(this) else null
        if (ink != null) { fields.addView(text("核对以上报价 / 验收事实后，在白色区域手写签名")); fields.addView(ink, LinearLayout.LayoutParams(-1, dp(180))); fields.addView(button("清空签名") { ink.clear() }) }
        val scroll = ScrollView(this).apply { addView(fields) }
        val dialog = AlertDialog.Builder(themedContext).setTitle(tr(spec.title)).setView(scroll).setNegativeButton(tr("取消"), null).setPositiveButton(tr("确认提交"), null).create()
        activeForm = dialog
        dialog.setOnDismissListener {
            if (activeForm === dialog) activeForm = null
            applyPendingAppearance()
        }
        dialog.setOnShowListener {
            styleDialogControls(dialog)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                if (!busy) {
                    try {
                        val payload = JSONObject()
                        readers.forEach { (field, read) -> payload.put(field.key, read()) }
                        if (ink != null) payload.put("signature", ink.dataURL())
                        submit(payload) { dialog.dismiss() }
                    } catch (error: Exception) { toast(error.message ?: "请检查填写内容") }
                }
            }
        }
        dialog.show()
    }
    private fun relationChoices(key: String): List<Pair<String, String>> {
        val users = mapOf("admin" to "公司负责人", "dispatcher" to "客服调度", "engineer" to "自有工程师", "outsource" to "外包人员", "warehouse" to "仓库", "finance" to "财务", "qc" to "质检", "customer" to "海棠当前经办人", "customer-peer" to "海棠接替经办人", "customer-b" to "青禾经办人")
        val accounts = when (key) { "assigneeId" -> listOf("engineer", "outsource"); "borrowerId" -> listOf("engineer"); "ownerId" -> listOf("dispatcher", "engineer", "warehouse", "finance", "qc"); else -> emptyList() }
        if (repository.demo && accounts.isNotEmpty()) return accounts.map { it to "${users[it]}（$it）" }
        val source = when (key) {
            "partId" -> repository.snapshot.array("parts")
            "orderId" -> repository.snapshot.array("orders")
            "cashId" -> selected?.array("cash")
            "invoiceId" -> selected?.array("invoices")
            "evidenceId" -> selected?.array("evidence")
            "issueId" -> selected?.array("issues")
            "obligationId" -> selected?.array("obligations")
            "visitId" -> selected?.array("visits")
            "costId" -> selected?.array("costs")
            "commissionId" -> selected?.array("commissions")
            else -> null
        }
        return source?.objects()?.filter { !it.optBoolean("deleted") }?.map { item ->
            val label = listOf("name", "device", "number", "title", "purpose", "note", "person", "plannedAt").map { item.optString(it) }.firstOrNull { it.isNotBlank() } ?: item.optString("id")
            item.optString("id") to "$label（${item.optString("id")}）"
        } ?: emptyList()
    }
    private fun inventory() {
        heading("配件与借还", "客户无内部库存权限。借出、归还及处置由对应岗位办理。")
        body.addView(button("重新加载库存") { async({ repository.refresh() }) })
        val role = repository.actor!!.optString("role")
        if (role in listOf("admin", "warehouse")) body.addView(button("＋ 借用配件") { form(Forms.loan, defaults()) { payload, done -> async({ repository.write("/loans", payload); repository.refresh() }, { done(); render() }) } })
        if (role in listOf("admin", "warehouse", "dispatcher")) body.addView(button("＋ 新建采购") { form(Forms.purchase, defaults()) { payload, done -> async({ repository.write("/purchases", payload); repository.refresh() }, { done(); render() }) } })
        listOf("parts" to "配件库存", "loans" to "借还记录", "purchases" to "采购记录").forEach { (key, title) ->
            heading(title)
            val values = repository.snapshot.array(key).objects()
            if (values.isEmpty()) empty(title) { async({ repository.refresh() }) }
            values.forEach { value ->
                val item = card(value.optString("name", value.optString("partName", value.optString("id"))), record(value))
                if (key == "loans" && role in listOf("admin", "warehouse")) item.addView(button("归还入库") { loanAction(value, "return") })
                if (key == "loans" && role == "admin") listOf("consume" to "批准耗用", "dispose" to "批准处置", "transfer" to "转独立跟踪").forEach { (type, label) -> item.addView(button(label) { loanAction(value, type) }) }
                if (key == "purchases" && role in listOf("admin", "warehouse")) item.addView(button("分批收货") { val spec = ActionForm("receive_purchase", "采购收货", listOf(Field("quantity", "本次数量", "int"), Field("note", "收货说明"))); form(spec) { payload, done -> payload.put("version", value.optInt("version")); async({ repository.write("/purchases/${value.getString("id")}/receive", payload); repository.refresh() }, { done(); render() }) } })
                body.addView(item)
            }
        }
    }
    private fun loanAction(loan: JSONObject, action: String) {
        val fields = mutableListOf(Field("quantity", "本次数量", "int"))
        if (action == "return") fields.add(Field("condition", "归还状态", "choice", listOf("good", "quarantine"))) else fields.add(Field("reason", "批准原因"))
        if (action == "transfer") { fields.add(Field("ownerId", "后续责任人账号 ID")); fields.add(Field("dueAt", "后续截止时间", "date")) }
        form(ActionForm(action, "办理借还", fields), defaults()) { payload, done -> async({ repository.write("/loans/${loan.getString("id")}/actions", json("type" to action, "version" to loan.getInt("version"), "payload" to payload)); repository.refresh() }, { done(); render() }) }
    }
    private fun profile() {
        heading("我的与帮助")
        body.addView(card("当前身份", (staticText("账号：") + (repository.actor!!.optString("username")).toString() + staticText("\n角色：") + (repository.actor!!.optString("role")).toString() + staticText("\n企业：") + (repository.actor!!.optString("companyId")).toString() + staticText("\n服务器：") + (repository.endpoint).toString())))
        body.addView(settingsButton())
        body.addView(button("导出当前授权资料") { async({ pendingDownload = repository.export().toString(2).toByteArray() }, { saveDocument(("维修资料-" + (System.currentTimeMillis()).toString() + ".json"), "application/json") }) })
        body.addView(card("常用操作", "客户：提交需求 → 查看公司报价 → 签署报价 → 交付后验收。\n工程师：打开分派工单 → 检测报告 / 报价 → 开修 → 完工 → 跟进质检。\n财务：在工单详情核实现金、交接、开票与结算。\n库存：先核对配件 ID 和可用数量，再办理借还。\n每次提交若提示结果不确定，请保留原表单按相同内容重试。"))
        body.addView(card("数据说明", "服务器响应成功后使用服务器资料；网络不可用时可用合成账号体验独立演示。演示数据仅存在本次应用进程，退出后可能重置，不会上传。业务拒绝会直接提示，不能在演示里绕过真实权限。当前未接真实支付、地图或认证电子签。"))
        body.addView(button("退出 / 切换角色") { async({ repository.logout(); selected = null; rows = JSONArray() }) })
    }
    private fun environment() {
        val fields = column().apply { setPadding(dp(20), 0, dp(20), 0) }
        val address = input("服务器根地址", repository.endpoint)
        val timeout = input("请求超时（毫秒）", repository.timeoutMillis.toString()).apply { inputType = InputType.TYPE_CLASS_NUMBER }
        fields.addView(button("语言") {
            AlertDialog.Builder(themedContext).setTitle(tr("语言")).setSingleChoiceItems(languages.map { it.second }.toTypedArray(), languages.indexOfFirst { it.first == getPreferences(MODE_PRIVATE).getString("language", "zh-Hans") }) { dialog, index ->
                getPreferences(MODE_PRIVATE).edit().putString("language", languages[index].first).apply()
                dialog.dismiss()
                activeSettings?.dismiss()
                render()
            }.show().also(::styleDialogControls)
        })
        fields.addView(text("外观", 16f))
        fields.addView(button("白天 / 黑夜 / 跟随系统") {
            AlertDialog.Builder(themedContext).setTitle(tr("外观")).setSingleChoiceItems(arrayOf("跟随系统", "白天", "黑夜").map(::tr).toTypedArray(), listOf("system", "light", "dark").indexOf(getPreferences(MODE_PRIVATE).getString("appearance", "system"))) { dialog, index ->
                getPreferences(MODE_PRIVATE).edit().putString("appearance", listOf("system", "light", "dark")[index]).apply()
                dialog.dismiss()
                activeSettings?.dismiss()
                render()
            }.show().also(::styleDialogControls)
        })
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) fields.addView(text("Android 模拟器使用 10.0.2.2 访问电脑；真机填写电脑局域网地址。HTTP 仅调试构建开放。", 13f, muted))
        fields.addView(text("切换地址会退出当前身份并清除私有资料。真机填写电脑局域网 IP；正式构建使用 HTTPS。")); fields.addView(address); fields.addView(timeout)
        activeSettings = AlertDialog.Builder(themedContext).setTitle(tr("连接服务器")).setView(fields).setNegativeButton(tr("取消"), null).setPositiveButton(tr("保存并重新登录")) { _, _ ->
            runCatching {
                val value = timeout.text.toString().toInt(); require(value in 500..10000) { "超时需在500—10000毫秒之间" }
                repository.configure(address.text.toString()); repository.timeoutMillis = value
                getPreferences(MODE_PRIVATE).edit().putString("endpoint", repository.endpoint).apply()
                selected = null; rows = JSONArray(); render()
            }.onFailure { toast(it.message ?: "地址无效") }
        }.show().also(::styleDialogControls).also { dialog ->
            dialog.setOnDismissListener {
                if (activeSettings === dialog) activeSettings = null
                applyPendingAppearance()
            }
        }
    }

    private fun record(value: JSONObject): String {
        val labels = mapOf("id" to "ID", "name" to "名称", "title" to "内容", "number" to "号码", "note" to "说明", "text" to "文字", "amountCents" to "金额", "kind" to "类型", "quantity" to "总数量", "available" to "可用", "quarantine" to "隔离", "outstanding" to "尚欠", "received" to "已收货", "verified" to "已核实", "handedOver" to "已交接", "resolved" to "已解决", "settled" to "已结算", "voided" to "已红冲", "borrowerId" to "借用人", "ownerId" to "责任人", "partId" to "配件ID", "supplier" to "供应商", "at" to "时间", "dueAt" to "截止", "occurredAt" to "发生时间", "plannedAt" to "预约时间", "signedAt" to "签署时间", "passed" to "通过", "recipient" to "接收人", "requirement" to "要求", "prepared" to "已制作", "sent" to "已发送", "files" to "附件ID", "mime" to "文件类型", "actorName" to "经办人", "signerName" to "签署人", "version" to "版本")
        return value.keys().asSequence().filter { it in labels }.joinToString("\n") { key ->
            val raw = value.opt(key)
            val rendered = when { raw is Boolean -> yes(raw); key.endsWith("Cents") -> money(value.optLong(key)); raw is JSONArray -> (0 until raw.length()).joinToString("、") { raw.optString(it) }; else -> Forms.choiceLabels[raw?.toString()]?.let(::tr) ?: raw?.toString().orEmpty() }
            "${tr(labels[key].orEmpty())}：$rendered"
        }
    }
    private fun money(cents: Long): String = "¥" + BigDecimal.valueOf(cents, 2).toPlainString()
    private fun yes(value: Boolean): String = tr(if (value) "是" else "否")
    private fun saveDocument(name: String, mime: String) { startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply { type = mime; putExtra(Intent.EXTRA_TITLE, name); addCategory(Intent.CATEGORY_OPENABLE) }, 102) }

    @Deprecated("Platform activity result API retained to avoid third party dependencies")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || data?.data == null) return
        val uri = data.data!!
        if (requestCode == 102) { val bytes = pendingDownload ?: return; pendingDownload = null; async({ contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IllegalStateException("无法写入此位置") }, { toast("已保存文件") }); return }
        if (requestCode != 101) return
        val order = pendingFileOrder ?: return
        pendingFileOrder = null
        async({
            val bytes = contentResolver.openInputStream(uri)?.use { it.readLimited(6 * 1024 * 1024) } ?: throw IllegalStateException("无法读取文件")
            require(bytes.size <= 6 * 1024 * 1024) { "原件不能超过6MB" }
            val mime = contentResolver.getType(uri) ?: "application/octet-stream"
            validateUpload(mime, bytes)
            val kind = when { mime.startsWith("image/") -> "image"; mime.startsWith("video/") -> "video"; mime.startsWith("audio/") -> "audio"; else -> "document" }
            var name = "附件"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) name = it.getString(0) }
            val payload = json("name" to name, "kind" to kind, "mime" to mime, "data" to Base64.encodeToString(bytes, Base64.NO_WRAP))
            selected = repository.write("/orders/${order.getString("id")}/actions", json("type" to "evidence", "version" to order.getInt("version"), "payload" to payload))
        })
    }
    @Deprecated("Platform back callback")
    override fun onBackPressed() { if (selected != null) { selected = null; tab = "工单"; loadOrders() } else if (tab != "首页") { tab = "首页"; render() } else super.onBackPressed() }
    override fun onDestroy() { destroyed = true; worker.shutdownNow(); super.onDestroy() }
}
