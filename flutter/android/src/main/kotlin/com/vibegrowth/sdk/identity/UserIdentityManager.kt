package com.vibegrowth.sdk.identity

import android.content.Context
import android.provider.Settings
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import com.vibegrowth.sdk.persistence.PreferencesStore
import java.util.UUID

class UserIdentityManager(
    private val preferencesStore: PreferencesStore,
    private val context: Context
) {

    companion object {
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_USER_ID = "user_id"
    }

    fun getOrCreateDeviceId(): String {
        val existing = preferencesStore.getString(KEY_DEVICE_ID)
        if (existing != null) {
            return existing
        }
        val deviceId = resolveDeviceId()
        preferencesStore.putString(KEY_DEVICE_ID, deviceId)
        return deviceId
    }

    private fun resolveDeviceId(): String {
        // 1. Try GAID (Google Advertising ID)
        try {
            val adInfo = AdvertisingIdClient.getAdvertisingIdInfo(context)
            if (!adInfo.isLimitAdTrackingEnabled) {
                val gaid = adInfo.id
                if (!gaid.isNullOrEmpty()) return gaid
            }
        } catch (_: Exception) { }

        // 2. Try ANDROID_ID
        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        if (!androidId.isNullOrEmpty()) return androidId

        // 3. Fallback: random UUID
        return UUID.randomUUID().toString()
    }

    fun setUserId(userId: String) {
        preferencesStore.putString(KEY_USER_ID, userId)
    }

    fun getUserId(): String? {
        return preferencesStore.getString(KEY_USER_ID)
    }
}
