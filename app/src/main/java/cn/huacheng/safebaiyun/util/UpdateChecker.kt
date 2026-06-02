package cn.huacheng.safebaiyun.util

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL

@Serializable
data class GithubRelease(
    val tag_name: String,
    val assets: List<GithubAsset> = emptyList()
)

@Serializable
data class GithubAsset(
    val name: String,
    val browser_download_url: String
)

data class UpdateInfo(
    val hasUpdate: Boolean,
    val latestVersion: String = "",
    val downloadUrl: String = ""
)

object UpdateChecker {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun checkForUpdate(currentVersion: String): UpdateInfo {
        return try {
            val url = URL("https://api.github.com/repos/xyouo/SafeBaiyun/releases/latest")
            val response = url.readText()
            val release = json.decodeFromString<GithubRelease>(response)
            val latestTag = release.tag_name.removePrefix("v")

            if (latestTag > currentVersion) {
                val apkAsset = release.assets.firstOrNull { it.name.endsWith(".apk") }
                UpdateInfo(
                    hasUpdate = true,
                    latestVersion = latestTag,
                    downloadUrl = apkAsset?.browser_download_url ?: ""
                )
            } else {
                UpdateInfo(hasUpdate = false)
            }
        } catch (e: Exception) {
            UpdateInfo(hasUpdate = false)
        }
    }
}