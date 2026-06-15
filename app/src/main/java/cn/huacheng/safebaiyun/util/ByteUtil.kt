package cn.huacheng.safebaiyun.util

/**
 *
 *@description:
 *@author: guangzhou
 *@create: 2024-03-04
 */
object ByteUtil {

    private val hexChars = "0123456789abcdef".toCharArray()

    fun byteToHex(b: Byte): String {
        return "${hexChars[(b.toInt() shr 4) and 0x0F]}${hexChars[b.toInt() and 0x0F]}"
    }

    fun bytesToHex(bytes: ByteArray): String {
        val result = StringBuilder(bytes.size * 2)
        bytes.forEach {
            val octet = it.toInt()
            result.append(hexChars[(octet shr 4) and 0x0F])
            result.append(hexChars[octet and 0x0F])
        }
        return result.toString()
    }

    fun hexToBytes(hexString: String): ByteArray {
        if (hexString.isBlank()) return byteArrayOf()
        val result = ByteArray(hexString.length / 2)
        for (i in hexString.indices step 2) {
            val byteValue = hexString.substring(i, i + 2).toInt(16)
            result[i / 2] = byteValue.toByte()
        }
        return result
    }

    fun hexToBytesOrNull(hexString: String): ByteArray? {
        val normalized = hexString.trim().filter { it.isDigit() || it.uppercaseChar() in 'A'..'F' }
        if (normalized.isEmpty() || normalized.length % 2 != 0) return null
        return runCatching { hexToBytes(normalized) }.getOrNull()
    }

    fun macToBytes(mac: String): ByteArray {
        return hexToBytesOrNull(mac) ?: byteArrayOf()
    }

    fun normalizeMac(mac: String): String {
        val hex = mac.uppercase().filter { it.isDigit() || it in 'A'..'F' }
        if (hex.length != 12) return mac.trim().uppercase()
        return hex.chunked(2).joinToString(":")
    }

}

