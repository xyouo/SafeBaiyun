package cn.huacheng.safebaiyun.unlock

import cn.huacheng.safebaiyun.util.ByteUtil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

data class RemoteDoorDevice(
    val address: String,
    val mac: String,
    val key: String
) {
    fun toDevice(): Device {
        return Device(
            id = UUID.randomUUID().toString(),
            name = address.ifBlank { DataRepo.generateUniqueName() },
            mac = ByteUtil.normalizeMac(mac),
            key = key.trim().uppercase()
        )
    }
}

object EntranceGuardApi {
    private const val BASE_URL = "https://www.pinganbaiyun.cn"
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchDevices(phone: String, idCard: String): List<RemoteDoorDevice> = withContext(Dispatchers.IO) {
        val normalizedPhone = phone.trim()
        val normalizedIdCard = idCard.trim().uppercase()
        require(normalizedPhone.isNotEmpty() && normalizedIdCard.isNotEmpty()) {
            "Please enter phone and ID card"
        }

        val auth = login(normalizedPhone, normalizedIdCard)
        try {
            val response = request(
                path = "/baiyunuser/entranceguard/getList",
                payload = buildJsonObject {
                    put("pageNum", 0)
                    put("pages", 0)
                    put("pageSize", 0)
                },
                extraHeaders = mapOf(
                    "TOKEN" to auth.token,
                    "LOGIN_USER" to auth.loginUser
                )
            )
            parseDoorDevices(response)
        } finally {
            runCatching { logout(auth) }
        }
    }

    private data class Auth(val token: String, val loginUser: String, val phone: String)

    private fun login(phone: String, idCard: String): Auth {
        val response = request(
            path = "/baiyunuser/account/login/v1",
            payload = buildJsonObject {
                put("sex", 0)
                put("idcardNo", idCard)
                put("deviceInfo", buildJsonObject {
                    put("osVersion", android.os.Build.VERSION.RELEASE ?: "14")
                    put("wifiMac", "02:00:00:00:00:00")
                    put("brand", android.os.Build.BRAND ?: "Android")
                    put("os", 1)
                    put("udid", UUID.randomUUID().toString())
                    put("appVersion", "1.3.6")
                    put("imsi", "46015")
                    put("model", android.os.Build.MODEL ?: "Android")
                })
                put("faceUploadCount", 0)
                put("isreal", 0)
                put("age", 0)
                put("appVersion", "1.3.6")
                put("phone", phone)
            }
        )

        val code = response["code"].stringValue()
        val state = response["state"].boolValue()
        if (state != true || code != "0000") {
            throw IllegalStateException(response["msg"].stringValue() ?: "Login failed")
        }
        val token = response["extension"].stringValue().orEmpty()
        val loginUser = response["obj"]?.jsonObjectOrNull()?.get("id").stringValue().orEmpty()
        if (token.isBlank() || loginUser.isBlank()) {
            throw IllegalStateException("Missing login user info")
        }
        return Auth(token = token, loginUser = loginUser, phone = phone)
    }

    private fun logout(auth: Auth) {
        request(
            path = "/baiyunuser/account/loginOut",
            payload = buildJsonObject { put("phone", auth.phone) },
            extraHeaders = mapOf(
                "TOKEN" to auth.token,
                "LOGIN_USER" to auth.loginUser
            )
        )
    }

    private fun request(
        path: String,
        payload: JsonObject,
        extraHeaders: Map<String, String> = emptyMap()
    ): JsonObject {
        val connection = (URL(BASE_URL + path).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 20000
            doOutput = true
            setRequestProperty("Host", "www.pinganbaiyun.cn")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "*/*")
            setRequestProperty("Accept-Language", "zh-Hans-CN;q=1, en-US;q=0.9")
            extraHeaders.forEach { (key, value) -> setRequestProperty(key, value) }
        }

        OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
            writer.write(payload.toString())
        }

        val body = if (connection.responseCode in 200..299) {
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } else {
            connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        }
        connection.disconnect()
        if (body.isBlank()) throw IllegalStateException("Request failed")
        return json.parseToJsonElement(body).jsonObject
    }

    private fun parseDoorDevices(response: JsonObject): List<RemoteDoorDevice> {
        return collectDoorRecords(response).mapNotNull { record ->
            val address = record["address"].stringValue() ?: record["name"].stringValue() ?: ""
            val mac = record["macNum"].stringValue() ?: return@mapNotNull null
            val key = record["productKey"].stringValue() ?: return@mapNotNull null
            if (ByteUtil.macToBytes(mac).size != 6 || ByteUtil.hexToBytesOrNull(key)?.isNotEmpty() != true) {
                return@mapNotNull null
            }
            RemoteDoorDevice(
                address = address.trim(),
                mac = ByteUtil.normalizeMac(mac),
                key = key.trim().uppercase()
            )
        }.distinctBy { it.mac + it.key }
    }

    private fun collectDoorRecords(value: JsonElement): List<JsonObject> {
        return when (value) {
            is JsonArray -> value.flatMap { collectDoorRecords(it) }
            is JsonObject -> {
                val records = mutableListOf<JsonObject>()
                value["data_list"]?.let { records.addAll(collectDoorRecords(it)) }
                value["obj"]?.let { records.addAll(collectDoorRecords(it)) }
                if (value.containsKey("macNum") || value.containsKey("productKey")) records.add(value)
                records
            }
            else -> emptyList()
        }
    }

    private fun JsonElement?.stringValue(): String? {
        return when (this) {
            is JsonPrimitive -> contentOrNull
            else -> null
        }
    }

    private fun JsonElement?.boolValue(): Boolean? {
        return when (this) {
            is JsonPrimitive -> booleanOrNull ?: runCatching { int != 0 }.getOrNull()
            else -> null
        }
    }

    private fun JsonElement?.jsonObjectOrNull(): JsonObject? = this as? JsonObject
}
