package cn.huacheng.safebaiyun.util

import android.content.Context

object AppSettings {
    private val prefs by lazy {
        ContextHolder.get().getSharedPreferences("app_settings", Context.MODE_PRIVATE)
    }

    var autoCheckUpdate: Boolean
        get() = prefs.getBoolean("auto_check_update", true)
        set(value) = prefs.edit().putBoolean("auto_check_update", value).apply()
}