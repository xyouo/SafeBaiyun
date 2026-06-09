package cn.huacheng.safebaiyun.unlock

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import cn.huacheng.safebaiyun.util.ContextHolder
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class Device(
    val id: String,
    val name: String,
    val mac: String,
    val key: String
)

object DataRepo {

    private val json = Json { ignoreUnknownKeys = true }

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
                Device(id = "1", name = "门禁1", mac = oldMac, key = oldKey)
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
            devices.add(Device(id = "1", name = "门禁1", mac = mac, key = key))
        }
        saveDevices(devices)
    }

    fun generateUniqueName(baseName: String = "门禁"): String {
        val existing = readDevices()
        if (existing.none { it.name == baseName }) return baseName
        var i = 2
        while (existing.any { it.name == baseName + i }) i++
        return baseName + i
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