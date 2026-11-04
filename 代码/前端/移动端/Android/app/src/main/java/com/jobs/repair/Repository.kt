package com.jobs.repair

import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.io.InputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.time.OffsetDateTime
import java.util.UUID

fun JSONArray.objects(): List<JSONObject> = (0 until length()).mapNotNull { optJSONObject(it) }
fun JSONObject.array(key: String): JSONArray = optJSONArray(key) ?: JSONArray()
fun JSONObject.copyJSON(): JSONObject = JSONObject(toString())
fun json(vararg pairs: Pair<String, Any?>): JSONObject = JSONObject().apply { pairs.forEach { put(it.first, it.second ?: JSONObject.NULL) } }
fun nowISO(): String = OffsetDateTime.now().toString()
val supportedMIME = arrayOf("image/png", "image/jpeg", "image/gif", "application/pdf", "text/plain", "audio/mpeg", "audio/wav", "audio/ogg", "video/mp4")
fun validateUpload(mime: String, bytes: ByteArray) {
    require(mime in supportedMIME && bytes.isNotEmpty() && bytes.size <= 6 * 1024 * 1024) { "请选择PNG/JPG/GIF/PDF/TXT/MP3/WAV/OGG/MP4原件，最大6MB" }
    fun prefix(value: String) = bytes.take(value.length).toByteArray().contentEquals(value.toByteArray(Charsets.US_ASCII))
    val matches = when (mime) {
        "image/png" -> bytes.take(8).toByteArray().contentEquals(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10))
        "image/jpeg" -> bytes.size > 2 && bytes[0] == (-1).toByte() && bytes[1] == (-40).toByte()
        "image/gif" -> prefix("GIF87a") || prefix("GIF89a")
        "application/pdf" -> prefix("%PDF-")
        "audio/mpeg" -> prefix("ID3")
        "audio/wav" -> prefix("RIFF")
        "audio/ogg" -> prefix("OggS")
        "video/mp4" -> bytes.size > 12 && String(bytes.copyOfRange(4, 8), Charsets.US_ASCII) == "ftyp"
        "text/plain" -> runCatching { Charsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(bytes)); bytes.none { it == 0.toByte() } }.getOrDefault(false)
        else -> false
    }
    require(matches) { "文件内容与所选类型不一致，请选择原始文件" }
}
fun InputStream.readLimited(limit: Int): ByteArray {
    val output = ByteArrayOutputStream()
    val buffer = ByteArray(8192)
    var count = read(buffer)
    while (count >= 0) {
        if (output.size() + count > limit) throw IOException("文件或响应超过大小限制")
        output.write(buffer, 0, count)
        count = read(buffer)
    }
    return output.toByteArray()
}
class Rejection(val status: Int, message: String) : Exception(message)
class InvalidResponse(message: String) : IOException(message)

/** 真实响应与合成演示分离；网络未知时保留请求键，业务拒绝不伪装成成功。 */
class Repository {
    var endpoint = "http://10.0.2.2:8098"
        private set
    var timeoutMillis = 2200
    var actor: JSONObject? = null
        private set
    var snapshot = JSONObject()
        private set
    var demo = false
        private set
    var message = ""
    private var token = ""
    private var username = ""
    private var password = ""
    private var anchor: JSONObject? = null
    private var local: DemoStore? = null
    private val unknownWrites = mutableMapOf<String, String>()
    var generation = 0
        private set

    fun configure(value: String) {
        val uri = URI(value.trim().trimEnd('/'))
        require(uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.rawQuery == null && uri.rawFragment == null && (uri.path.isNullOrEmpty() || uri.path == "/")) { "请填写服务器根地址，例如 http://10.0.2.2:8098" }
        logoutLocal()
        endpoint = uri.toString().trimEnd('/')
    }

    fun login(user: String, pass: String) {
        logoutLocal()
        username = user.trim()
        password = pass
        try {
            authenticate()
            refresh()
        } catch (error: IOException) {
            enterDemo(error)
        }
    }

    private fun authenticate() {
        val result = request("POST", "/login", json("username" to username, "password" to password))
        val identity = result.optJSONObject("actor") ?: throw InvalidResponse("登录身份缺失")
        validateActor(identity)
        val credential = result.optString("token")
        if (credential.isBlank()) throw InvalidResponse("登录凭证缺失")
        token = credential
        anchor = identity.copyJSON()
    }

    private fun validateActor(value: JSONObject) {
        if (value.optString("status") != "active" || value.optString("id").isBlank() || value.optString("role") !in DemoStore.roles || value.optInt("authVersion") < 1 || value.optString("companyId").isBlank()) throw InvalidResponse("服务器身份字段无效")
    }

    private fun validateIdentity(value: JSONObject) {
        validateActor(value)
        val expected = anchor ?: throw InvalidResponse("缺少登录身份")
        if (listOf("id", "role", "companyId", "authVersion").any { value.opt(it)?.toString() != expected.opt(it)?.toString() }) throw InvalidResponse("返回身份与登录身份不一致")
    }

    fun refresh() {
        try {
            if (token.isBlank()) authenticate()
            val result = request("GET", "/bootstrap")
            val identity = result.optJSONObject("actor") ?: throw InvalidResponse("概览身份缺失")
            validateIdentity(identity)
            listOf("orders", "parts", "loans", "purchases").forEach { if (result.optJSONArray(it) == null) throw InvalidResponse("概览列表 $it 缺失") }
            result.array("orders").objects().forEach(::validateOrder)
            actor = identity
            snapshot = result
            demo = false
            message = "已连接服务器 · 数据已刷新"
        } catch (error: IOException) {
            enterDemo(error)
        }
    }

    private fun enterDemo(error: IOException) {
        if (username !in DemoStore.users || password != DemoStore.password) throw Rejection(0, "服务器未连接；请选择示例账号并输入演示密码")
        if (local == null) local = DemoStore(username, endpoint)
        actor = local!!.actor.copyJSON()
        snapshot = local!!.bootstrap()
        demo = true
        message = "独立演示 · ${error.message ?: "服务器暂不可用"} · 演示操作不会上传"
    }

    fun orders(query: String = "", status: String = "", page: Int = 1): JSONObject {
        try {
            if (token.isBlank()) authenticate()
            if (demo) { refresh(); if (demo) return local!!.orders(query, status, page) }
            val q = java.net.URLEncoder.encode(query, "UTF-8")
            val result = request("GET", "/orders?page=$page&pageSize=30&q=$q&status=$status")
            val rows = result.optJSONArray("items") ?: throw InvalidResponse("工单列表缺失")
            rows.objects().forEach(::validateOrder)
            if (result.optInt("page") != page || result.optInt("totalPages", -1) < 0) throw InvalidResponse("分页字段无效")
            return result
        } catch (error: IOException) {
            enterDemo(error)
            return local!!.orders(query, status, page)
        }
    }

    fun detail(id: String): JSONObject {
        if (demo) {
            try {
                if (token.isBlank()) authenticate()
                refresh()
                if (!demo) throw Rejection(0, "服务器已恢复，请返回列表重新选择真实工单")
            } catch (error: IOException) { enterDemo(error) }
            return local!!.detail(id)
        }
        return request("GET", "/orders/$id").also { validateOrder(it); if (it.optString("id") != id || it.optBoolean("isSummary")) throw InvalidResponse("详情上下文不匹配") }
    }

    fun write(path: String, body: JSONObject): JSONObject {
        val signature = path + "\n" + body.toString()
        val key = unknownWrites.getOrPut(signature) { UUID.randomUUID().toString() }
        try {
            if (token.isBlank()) authenticate()
            if (demo) {
                refresh()
                if (!demo) throw Rejection(0, "服务器已恢复，请重新打开真实资料后办理；演示数据不会自动上传")
            }
            val response = request("POST", path, body, key)
            if (path.startsWith("/orders")) {
                validateOrder(response)
                val sourceId = path.removePrefix("/orders/").substringBefore('/')
                if (body.optString("type") == "rework") {
                    if (response.optString("id") == sourceId || response.optString("originalOrderId") != sourceId) throw InvalidResponse("返修响应不匹配")
                } else if (path.endsWith("/actions") && (response.optString("id") != sourceId || response.optInt("version") <= body.optInt("version"))) throw InvalidResponse("动作未返回更新后的当前工单")
            }
            if (path.startsWith("/loans") || path.startsWith("/purchases")) {
                validateInventory(response, path.startsWith("/loans"))
                if (body.has("version") && (response.optString("id") != path.split('/')[2] || response.optInt("version") <= body.optInt("version"))) throw InvalidResponse("库存动作响应上下文不匹配")
            }
            unknownWrites.remove(signature)
            message = "服务器已保存"
            return response
        } catch (error: Rejection) {
            unknownWrites.remove(signature)
            throw error
        } catch (error: IOException) {
            if (!demo) throw Rejection(0, "提交结果暂不确定，请保留表单并用相同内容重试，或刷新核对。${error.message}")
            val result = local!!.write(path, body, key)
            snapshot = local!!.bootstrap()
            message = "已保存到独立演示；未上传服务器"
            return result
        }
    }

    fun export(): JSONObject {
        if (demo) return local!!.bootstrap().put("demo", true)
        return request("GET", "/export").also { validateIdentity(it.optJSONObject("actor") ?: throw InvalidResponse("导出身份缺失")) }
    }

    fun download(path: String): ByteArray = raw("GET", path, null, null).second

    fun logout() {
        try { if (token.isNotBlank()) request("POST", "/logout", JSONObject()) } finally { logoutLocal() }
    }

    fun logoutLocal() {
        generation++
        token = ""
        username = ""
        password = ""
        actor = null
        anchor = null
        local = null
        snapshot = JSONObject()
        demo = false
        unknownWrites.clear()
    }

    private fun validateOrder(value: JSONObject) {
        if (value.optString("id").isBlank() || !validInteger(value.opt("version")) || value.optInt("version") < 1 || value.optString("status") !in Forms.states) throw InvalidResponse("工单结构不完整")
        for (cash in value.array("cash").objects()) {
            if (cash.optString("id").isBlank() || cash.optString("kind") !in listOf("receipt", "refund") || !validInteger(cash.opt("amountCents"))) throw InvalidResponse("现金数据无效")
        }
    }
    private fun validInteger(value: Any?): Boolean = value is Number && runCatching { value.toString().toBigDecimal().longValueExact() >= 0 }.getOrDefault(false)
    private fun validateInventory(value: JSONObject, loan: Boolean) {
        val numeric = if (loan) listOf("version", "quantity", "outstanding", "returnedGood", "returnedQuarantine", "consumed", "disposed") else listOf("version", "quantity", "received", "unitCents")
        if (value.optString("id").isBlank() || value.optString("partId").isBlank() || numeric.any { !validInteger(value.opt(it)) } || value.optInt("version") < 1 || value.optInt("quantity") < 1) throw InvalidResponse("库存响应字段不完整")
        if (loan && (value.optString("borrowerId").isBlank() || value.optInt("outstanding") > value.optInt("quantity"))) throw InvalidResponse("借用响应无效")
        if (!loan && value.optInt("received") > value.optInt("quantity")) throw InvalidResponse("采购响应无效")
    }

    private fun request(method: String, path: String, body: JSONObject? = null, key: String? = null): JSONObject {
        val bytes = raw(method, path, body, key).second
        return try { JSONObject(String(bytes, Charsets.UTF_8)) } catch (_: Exception) { throw InvalidResponse("服务器响应无法解析") }
    }

    private fun raw(method: String, path: String, body: JSONObject?, key: String?): Pair<Int, ByteArray> {
        val connection = URL(endpoint + "/api/v38" + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = timeoutMillis
            connection.readTimeout = timeoutMillis
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Accept", "application/json")
            if (token.isNotBlank()) connection.setRequestProperty("Authorization", "Bearer $token")
            if (key != null) connection.setRequestProperty("Idempotency-Key", key)
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val input = if (status in 200..299) connection.inputStream else connection.errorStream
            val bytes = input?.use { it.readLimited(12 * 1024 * 1024) } ?: ByteArray(0)
            if (status !in 200..299) {
                val hint = try { JSONObject(String(bytes)).optString("message") } catch (_: Exception) { "服务器拒绝了此次请求" }
                if (status == 401 && path != "/login") logoutLocal()
                throw Rejection(status, hint.ifBlank { "请求失败（$status）" })
            }
            return status to bytes
        } finally { connection.disconnect() }
    }
}
