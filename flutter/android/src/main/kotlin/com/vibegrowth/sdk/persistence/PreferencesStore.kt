package com.vibegrowth.sdk.persistence

import android.content.Context
import android.content.SharedPreferences

class PreferencesStore(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("vibegrowth_sdk", Context.MODE_PRIVATE)

    fun getString(key: String, defaultValue: String? = null): String? {
        return prefs.getString(key, defaultValue)
    }

    fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    fun getBoolean(key: String, defaultValue: Boolean = false): Boolean {
        return prefs.getBoolean(key, defaultValue)
    }

    fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }
}
