package cn.huacheng.safebaiyun.unlock

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import cn.huacheng.safebaiyun.util.ContextHolder
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.UUID

@Serializable
data class Device(
    val id: String,
    val name: String,
    val mac: String,
    val key: String
)

@Serializable
private data class DeviceExport(
    val name: String,
    val mac: String,
    val key: String
)

object DataRepo {

    private val json = Json { ignoreUnknownKeys = true }
    private val exportJson = Json { prettyPrint = true; ignoreUnknownKeys = true }

    private val preferences: SharedPreferences by lazy {
        ContextHolder.get().getSharedPreferences("data", Context.MODE_PRIVATE)
    }

    fun readDevices(): List<Device> {
        val devicesJson = preferences.getString("devices", null)
        if (!devicesJson.isNullOrEmpty()) {
            return try {
                json.decodeFromString<List<Device>>(devicesJson)
            } catch (e: Exception) {
                emptyList()
            }
        }
        val oldMac = preferences.getString("mac", "") ?: ""
        val oldKey = preferences.getString("key", "") ?: ""
        if (oldMac.isNotEmpty() && oldKey.isNotEmpty()) {
            val migrated = listOf(
                Device(id = "1", name = "闂ㄧ1", mac = oldMac, key = oldKey)
            )
            saveDevices(migrated)
            preferences.edit { remove("mac").remove("key") }
            return migrated
        }
        return emptyList()
    }

    fun saveDevices(devices: List<Device>) {
        preferences.edit { putString("devices", json.encodeToString(devices)) }
    }

    fun addDevice(device: Device) {
        val devices = readDevices().toMutableList()
        devices.add(device)
        saveDevices(devices)
    }

    fun updateDevice(device: Device) {
        val devices = readDevices().toMutableList()
        val index = devices.indexOfFirst { it.id == device.id }
        if (index >= 0) devices[index] = device
        saveDevices(devices)
    }

    fun deleteDevice(deviceId: String) {
        val devices = readDevices().filter { it.id != deviceId }
        saveDevices(devices)
    }

    fun readDeviceById(id: String): Device? {
        return readDevices().find { it.id == id }
    }

    fun readData(): Pair<String, String> {
        val devices = readDevices()
        return if (devices.isNotEmpty()) devices.first().mac to devices.first().key
        else "" to ""
    }

    fun save(mac: String, key: String) {
        val devices = readDevices().toMutableList()
        if (devices.isNotEmpty()) {
            devices[0] = devices[0].copy(mac = mac, key = key)
        } else {
            devices.add(Device(id = "1", name = "闂ㄧ1", mac = mac, key = key))
        }
        saveDevices(devices)
    }

    fun exportDevices(deviceIds: List<String>? = null): String {
        val devices = if (deviceIds == null) readDevices()
        else readDevices().filter { it.id in deviceIds }
        val exportData = devices.map { DeviceExport(name = it.name, mac = it.mac, key = it.key) }
        return exportJson.encodeToString(exportData)
    }

    fun importDevices(jsonString: String): Int {
        return try {
            val jsonArray = json.parseToJsonElement(jsonString).jsonArray
            val existing = readDevices().toMutableList()
            var count = 0
            var anyParsed = false

            for (element in jsonArray) {
                try {
                    val device = json.decodeFromString<Device>(element.toString())
                    anyParsed = true
                    if (existing.none { it.mac == device.mac }) {
                        existing.add(device)
                        count++
                    }
                } catch (_: Exception) {
                    try {
                        val export = json.decodeFromString<DeviceExport>(element.toString())
                        anyParsed = true
                        if (existing.none { it.mac == export.mac }) {
                            existing.add(Device(
                                id = UUID.randomUUID().toString(),
                                name = export.name, mac = export.mac, key = export.key
                            ))
                            count++
                        }
                    } catch (_: Exception) {
                        // 灏濊瘯瀛楁鍚嶆槧灏勶紙鍏煎 mac1/processkey 绛夊彉浣擄級
                        try {
                            val obj = element.jsonObject
                            val mac = getField(obj, "mac", "MAC", "mac1", "MAC_NUM")
                            val key = getField(obj, "key", "KEY", "processkey", "PRODUCT_KEY")
                            if (mac != null && key != null) {
                                anyParsed = true
                                val name = getField(obj, "name", "NAME") ?: "闂ㄧ"
                                if (existing.none { it.mac == mac }) {
                                    existing.add(Device(
                                        id = UUID.randomUUID().toString(),
                                        name = name, mac = mac, key = key
                                    ))
                                    count++
                                }
                            }
                        } catch (_: Exception) { }
                    }
                }
            }

            if (count > 0) saveDevices(existing)
            if (anyParsed) count else -1
        } catch (e: Exception) { -1 }
    }

    private fun getField(obj: JsonObject, vararg names: String): String? {
        for (name in names) {
            try {
                val value = obj[name]?.jsonPrimitive?.content ?: continue
                if (value.isNotEmpty()) return value
            } catch (_: Exception) { continue }
        }
        return null
    }

    fun moveDeviceUp(id: String): Int {
        val devices = readDevices().toMutableList()
        val index = devices.indexOfFirst { it.id == id }
        if (index <= 0) return -1
        val temp = devices[index]
        devices[index] = devices[index - 1]
        devices[index - 1] = temp
        saveDevices(devices)
        return index - 1
    }

    fun moveDeviceDown(id: String): Int {
        val devices = readDevices().toMutableList()
        val index = devices.indexOfFirst { it.id == id }
        if (index < 0 || index >= devices.size - 1) return -1
        val temp = devices[index]
        devices[index] = devices[index + 1]
        devices[index + 1] = temp
        saveDevices(devices)
        return index + 1
    }
}
