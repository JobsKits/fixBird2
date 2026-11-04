package com.jobs.repair

import com.sun.net.httpserver.HttpServer
import org.json.JSONArray
import org.json.JSONObject
import java.net.InetSocketAddress
import java.util.UUID

fun main() {
    var checks = 0
    fun checkCase(name: String, check: () -> Unit) { check(); checks++; println("PASS $name") }
    fun denied(check: () -> Unit) { try { check(); error("expected rejection") } catch (_: Rejection) { } }
    fun action(store: DemoStore, id: String, type: String, payload: JSONObject, key: String = UUID.randomUUID().toString()): JSONObject = store.write("/orders/$id/actions", json("type" to type, "version" to store.detail(id).getInt("version"), "payload" to payload), key)
    val environment = UUID.randomUUID().toString()
    val admin = DemoStore("admin", environment)
    val customer = DemoStore("customer", environment)
    val peer = DemoStore("customer-peer", environment)
    val other = DemoStore("customer-b", environment)
    checkCase("same-enterprise contacts do not inherit current-contact orders") { check(customer.bootstrap().array("orders").length() == 3); check(peer.bootstrap().array("orders").length() == 0) }
    checkCase("cross-company synthetic records are isolated") { check(other.bootstrap().array("orders").length() == 0); denied { other.detail("demo_sample_0") } }
    checkCase("customer does not receive internal stock or remarks") { check(customer.bootstrap().array("parts").length() == 0); check(!customer.detail("demo_sample_0").has("remark")) }
    checkCase("admin cannot impersonate quote signature") { denied { action(admin, "demo_sample_1", "sign_quote", json("quoteVersion" to 1, "signature" to "data:image/png;base64,fixture")) } }
    checkCase("invalid prepayment is atomic") {
        action(admin, "demo_sample_0", "intake", json("ownerId" to "dispatcher", "assigneeId" to "engineer"))
        action(admin, "demo_sample_0", "diagnose", JSONObject())
        val before = admin.detail("demo_sample_0").getInt("version")
        denied { action(admin, "demo_sample_0", "quote", json("amountCents" to 10000, "prepayCents" to 20000, "validUntil" to "2099-12-31T12:00:00+08:00")) }
        check(admin.detail("demo_sample_0").getInt("version") == before)
    }
    checkCase("unknown-key retry does not duplicate mutation") {
        val original = admin.detail("demo_sample_0")
        val body = json("type" to "remark", "version" to original.getInt("version"), "payload" to json("customerNote" to "幂等测试"))
        val first = admin.write("/orders/demo_sample_0/actions", body, "same-key")
        val retry = admin.write("/orders/demo_sample_0/actions", body, "same-key")
        check(first.getInt("version") == retry.getInt("version")); check(admin.detail("demo_sample_0").getInt("version") == first.getInt("version"))
        denied { admin.write("/orders/demo_sample_0/actions", body.copyJSON().put("version", 999), "same-key") }
    }
    checkCase("loan quantity and inventory are conserved") {
        val loan = admin.write("/loans", json("partId" to "part-board", "borrowerId" to "engineer", "quantity" to 3, "orderId" to "", "dueAt" to "2099-12-31T12:00:00+08:00", "note" to "仓库批准交接"), "loan-key")
        check(admin.bootstrap().array("parts").getJSONObject(0).getInt("available") == 25)
        denied { admin.write("/loans/${loan.getString("id")}/actions", json("type" to "consume", "version" to 1, "payload" to json("quantity" to 1, "reason" to "无工单禁止耗用")), "bad-consume") }
        val returned = admin.write("/loans/${loan.getString("id")}/actions", json("type" to "return", "version" to 1, "payload" to json("quantity" to 2, "condition" to "good")), "return-key")
        check(returned.getInt("outstanding") == 1); check(admin.bootstrap().array("parts").getJSONObject(0).getInt("available") == 27)
        val transferred = admin.write("/loans/${loan.getString("id")}/actions", json("type" to "transfer", "version" to 2, "payload" to json("quantity" to 1, "reason" to "转独立跟踪", "ownerId" to "warehouse", "dueAt" to "2099-12-31T12:00:00+08:00")), "transfer-key")
        check(transferred.getInt("outstanding") == 1)
        check(transferred.array("transfers").getJSONObject(0).getInt("quantity") == 1)
        check(admin.bootstrap().array("loans").length() == 1)
    }
    checkCase("over-refund cannot become verified money") {
        action(admin, "demo_sample_0", "cash", json("amountCents" to 50000, "kind" to "receipt"))
        val receipt = admin.detail("demo_sample_0").array("cash").getJSONObject(0).getString("id")
        action(admin, "demo_sample_0", "verify_cash", json("cashId" to receipt))
        action(admin, "demo_sample_0", "cash", json("amountCents" to 50100, "kind" to "refund"))
        val refund = admin.detail("demo_sample_0").array("cash").getJSONObject(1).getString("id")
        denied { action(admin, "demo_sample_0", "verify_cash", json("cashId" to refund)) }
        check(admin.detail("demo_sample_0").getJSONObject("summary").getLong("collectedCents") == 50000L)
    }
    checkCase("all 43 contract action forms have unique API names") { check(Forms.all.size == 43); check(Forms.all.map { it.key }.distinct().size == 43) }
    checkCase("native action payload fields match Go strict decoder") {
        val source = java.io.File("../../../../代码/后端/后端代码/internal/workbench/actions.go").readText()
        val payload = source.substringAfter("type actionPayload struct {").substringBefore("\n}")
        val allowed = Regex("json:\"([^\"]+)\"").findAll(payload).map { it.groupValues[1] }.toSet()
        check(Forms.all.flatMap { it.fields }.all { it.key in allowed })
        check(Forms.all.filter { it.key in listOf("sign_quote", "accept") }.size == 2)
    }
    checkCase("file MIME and bytes agree before native upload") {
        validateUpload("application/pdf", "%PDF-1.4\nfixture".toByteArray())
        try { validateUpload("image/png", "not-a-png".toByteArray()); error("expected MIME rejection") } catch (_: IllegalArgumentException) { }
        try { validateUpload("application/octet-stream", byteArrayOf(1, 2, 3)); error("expected MIME rejection") } catch (_: IllegalArgumentException) { }
    }

    var mode = "valid"
    val keys = mutableListOf<String>()
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val actor = json("id" to "customer", "role" to "customer", "companyId" to "company-a", "status" to "active", "authVersion" to 1)
    val realOrder = json("id" to "real_private", "status" to "pending_intake", "version" to 5)
    val bootstrap = json("actor" to actor, "orders" to JSONArray().put(realOrder), "parts" to JSONArray(), "loans" to JSONArray(), "purchases" to JSONArray())
    server.createContext("/api/v38") { exchange ->
        val path = exchange.requestURI.path
        var status = 200
        val result: String = when {
            path.endsWith("/login") -> json("token" to "fixture-token", "actor" to actor).toString()
            path.endsWith("/bootstrap") && mode == "bad-identity" -> bootstrap.copyJSON().put("actor", actor.copyJSON().put("id", "another")).toString()
            path.endsWith("/bootstrap") && mode == "401" -> { status = 401; json("message" to "会话已撤销").toString() }
            path.endsWith("/bootstrap") && mode == "broken" -> "not-json"
            path.endsWith("/bootstrap") -> bootstrap.toString()
            path.endsWith("/actions") -> { keys += exchange.requestHeaders.getFirst("Idempotency-Key"); realOrder.toString() }
            path.endsWith("/export") -> bootstrap.copyJSON().put("actor", actor.copyJSON().put("role", "admin")).toString()
            else -> json("ok" to true).toString()
        }
        exchange.requestBody.close()
        val bytes = result.toByteArray()
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }
    server.start()
    try {
        val repository = Repository()
        repository.configure("http://127.0.0.1:${server.address.port}")
        checkCase("real login and bootstrap establish identity anchor") { repository.login("customer", DemoStore.password); check(!repository.demo); check(repository.snapshot.array("orders").getJSONObject(0).getString("id") == "real_private") }
        checkCase("bad action version retains idempotency key for retry") {
            val body = json("type" to "remark", "version" to 5, "payload" to json("customerNote" to "test"))
            denied { repository.write("/orders/real_private/actions", body) }; denied { repository.write("/orders/real_private/actions", body) }
            check(keys.size == 2 && keys[0] == keys[1])
        }
        checkCase("wrong export actor is rejected") { try { repository.export(); error("expected invalid identity") } catch (_: InvalidResponse) { } }
        checkCase("shallow inventory 2xx cannot close a write as successful") { denied { repository.write("/loans", json("quantity" to 1)) } }
        checkCase("bad bootstrap never imports another account and uses synthetic data") { mode = "bad-identity"; repository.refresh(); check(repository.demo); check(repository.snapshot.array("orders").objects().none { it.getString("id") == "real_private" }) }
        checkCase("later successful refresh automatically restores real data") { mode = "valid"; repository.refresh(); check(!repository.demo); check(repository.snapshot.array("orders").getJSONObject(0).getString("id") == "real_private") }
        checkCase("401 revokes identity and all private state") { mode = "401"; denied { repository.refresh() }; check(repository.actor == null); check(repository.snapshot.length() == 0) }
        checkCase("environment switch discards credentials and private records") { mode = "valid"; repository.login("customer", DemoStore.password); repository.configure("http://127.0.0.1:1"); check(repository.actor == null); check(repository.snapshot.length() == 0) }
        checkCase("offline demo is available only for exact synthetic credentials") { repository.login("customer", DemoStore.password); check(repository.demo); denied { repository.login("unknown-user", "wrong") } }
    } finally { server.stop(0) }
    System.getenv("REPAIR_LIVE_URL")?.takeIf { it.isNotBlank() }?.let { address ->
        val live = Repository()
        live.configure(address)
        live.timeoutMillis = 10000
        checkCase("live Go login bootstrap and server pagination") {
            live.login("admin", DemoStore.password)
            check(!live.demo)
            check(live.orders().optInt("total") >= 1)
        }
        var created = JSONObject()
        checkCase("live Go creates a synthetic order with exact native payload") {
            created = live.write("/orders", json("type" to "mail", "customer" to "Android合同回归合成客户", "customerId" to "customer", "companyId" to "company-a", "project" to "Android原生端回归", "device" to "Android回归控制板", "description" to "隔离Go上的客户端真实HTTP链路"))
            check(created.optInt("version") == 1)
            check(live.detail(created.getString("id")).getString("device") == "Android回归控制板")
        }
        checkCase("live Go action advances version and details agree") {
            val result = live.write("/orders/${created.getString("id")}/actions", json("type" to "remark", "version" to created.getInt("version"), "payload" to json("customerNote" to "原生客户端真实提交")))
            check(result.getInt("version") > created.getInt("version"))
            check(live.detail(created.getString("id")).getString("customerNote") == "原生客户端真实提交")
        }
        checkCase("live Go rejects stale version without local success") {
            denied { live.write("/orders/${created.getString("id")}/actions", json("type" to "remark", "version" to 1, "payload" to json("customerNote" to "不得覆盖"))) }
            check(!live.demo)
        }
        checkCase("live Go quote signature accepts native PNG dimensions and rejects blank") {
            val id = created.getString("id")
            fun submit(type: String, payload: JSONObject) = live.write("/orders/$id/actions", json("type" to type, "version" to live.detail(id).getInt("version"), "payload" to payload))
            submit("intake", json("ownerId" to "dispatcher", "assigneeId" to "engineer"))
            submit("diagnose", json("note" to "原生端回归检测"))
            submit("quote", json("amountCents" to 68000, "description" to "合成维修范围", "warrantyMonths" to 3, "paymentTerms" to "credit", "prepayCents" to 0, "startRequiresPrepayment" to false, "validUntil" to "2099-12-31T12:00:00+08:00", "autoAccept" to false))
            submit("approve_quote", json("note" to "回归审核"))
            live.login("customer", DemoStore.password)
            val image = java.awt.image.BufferedImage(640, 240, java.awt.image.BufferedImage.TYPE_INT_RGB)
            val graphics = image.createGraphics()
            graphics.color = java.awt.Color.WHITE; graphics.fillRect(0, 0, 640, 240)
            fun encoded(): String { val bytes = java.io.ByteArrayOutputStream(); javax.imageio.ImageIO.write(image, "png", bytes); return "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(bytes.toByteArray()) }
            denied { submit("sign_quote", json("quoteVersion" to 1, "signature" to encoded())) }
            graphics.color = java.awt.Color.BLACK; graphics.stroke = java.awt.BasicStroke(5f); graphics.drawLine(40, 170, 420, 65); graphics.dispose()
            check(submit("sign_quote", json("quoteVersion" to 1, "signature" to encoded())).getJSONObject("quote").getBoolean("signed"))
            live.login("admin", DemoStore.password)
        }
        checkCase("live Go inventory payloads and full response validation") {
            val purchase = live.write("/purchases", json("supplier" to "supplier", "partId" to "part-board", "quantity" to 2, "unitCents" to 10000, "note" to "Android回归批准"))
            val received = live.write("/purchases/${purchase.getString("id")}/receive", json("version" to purchase.getInt("version"), "quantity" to 1, "note" to "Android回归实收"))
            check(received.getInt("received") == 1)
            val loan = live.write("/loans", json("partId" to "part-board", "quantity" to 1, "borrowerId" to "engineer", "dueAt" to "2099-12-31T12:00:00+08:00", "note" to "Android回归借出"))
            val returned = live.write("/loans/${loan.getString("id")}/actions", json("type" to "return", "version" to loan.getInt("version"), "payload" to json("quantity" to 1, "condition" to "good")))
            check(returned.getInt("outstanding") == 0)
        }
        checkCase("live Go scoped customer reads and revoked logout") {
            live.login("customer-b", DemoStore.password)
            denied { live.detail(created.getString("id")) }
            live.logout()
            check(live.actor == null)
        }
    }
    println("RESULT: $checks contract scenarios passed; no device UI assertions claimed")
}
