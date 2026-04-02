package com.vibegrowth.sdk

import android.content.Context
import com.vibegrowth.sdk.attribution.InstallReferrerHelper
import com.vibegrowth.sdk.identity.UserIdentityManager
import com.vibegrowth.sdk.network.ApiClient
import com.vibegrowth.sdk.persistence.PreferencesStore
import com.vibegrowth.sdk.revenue.RevenueTracker
import org.json.JSONObject
import kotlin.concurrent.thread

object VibeGrowthSDK {
    private const val KEY_HAS_TRACKED_FIRST_SESSION = "has_tracked_first_session"

    interface InitCallback {
        fun onSuccess()
        fun onError(error: String)
    }

    interface ConfigCallback {
        fun onSuccess(configJson: String)
        fun onError(error: String)
    }

    private const val PLATFORM = "android"
    private const val SDK_VERSION = "2.1.0"

    private var isInitialized = false
    private lateinit var config: VibeGrowthConfig
    private lateinit var apiClient: ApiClient
    private lateinit var prefsStore: PreferencesStore
    private lateinit var identityManager: UserIdentityManager
    private lateinit var revenueTracker: RevenueTracker
    private lateinit var referrerHelper: InstallReferrerHelper

    fun initialize(context: Context, appId: String, apiKey: String, callback: InitCallback? = null) {
        initialize(context, appId, apiKey, null, callback)
    }

    fun initialize(
        context: Context,
        appId: String,
        apiKey: String,
        baseUrl: String?,
        callback: InitCallback? = null
    ) {
        if (isInitialized) {
            callback?.onSuccess()
            return
        }

        val appContext = context.applicationContext
        config = if (baseUrl.isNullOrBlank()) {
            VibeGrowthConfig(appId = appId, apiKey = apiKey)
        } else {
            VibeGrowthConfig(appId = appId, apiKey = apiKey, baseUrl = baseUrl)
        }
        apiClient = ApiClient(config)
        prefsStore = PreferencesStore(appContext)
        identityManager = UserIdentityManager(prefsStore, appContext)
        revenueTracker = RevenueTracker(apiClient, identityManager)
        referrerHelper = InstallReferrerHelper(appContext)

        thread {
            try {
                val deviceId = identityManager.getOrCreateDeviceId()
                val referrerData = referrerHelper.getInstallReferrer()
                val attribution = JSONObject(referrerData.mapValues { it.value ?: "" })

                apiClient.postInit(
                    deviceId = deviceId,
                    platform = PLATFORM,
                    attribution = attribution,
                    sdkVersion = SDK_VERSION
                )

                isInitialized = true
                callback?.onSuccess()
            } catch (e: Exception) {
                callback?.onError(e.message ?: "Unknown error")
            }
        }
    }

    fun setUserId(userId: String) {
        checkInitialized()
        identityManager.setUserId(userId)
        thread {
            try {
                val deviceId = identityManager.getOrCreateDeviceId()
                apiClient.postIdentify(deviceId, userId)
            } catch (_: Exception) {
                // Silently handle network errors
            }
        }
    }

    fun getUserId(): String? {
        checkInitialized()
        return identityManager.getUserId()
    }

    @JvmOverloads
    fun trackPurchase(pricePaid: Double, currency: String, productId: String? = null) {
        checkInitialized()
        revenueTracker.trackPurchase(pricePaid, currency, productId)
    }

    fun trackAdRevenue(source: String, revenue: Double, currency: String) {
        checkInitialized()
        revenueTracker.trackAdRevenue(source, revenue, currency)
    }

    fun trackSessionStart(sessionStart: String) {
        checkInitialized()
        thread {
            try {
                val deviceId = identityManager.getOrCreateDeviceId()
                val userId = identityManager.getUserId()
                val isFirstSession = !prefsStore.getBoolean(KEY_HAS_TRACKED_FIRST_SESSION)
                apiClient.postSession(deviceId, userId, sessionStart, isFirstSession)
                if (isFirstSession) {
                    prefsStore.putBoolean(KEY_HAS_TRACKED_FIRST_SESSION, true)
                }
            } catch (_: Exception) {
                // Silently handle network errors for session tracking
            }
        }
    }

    fun trackSession(sessionStart: String, @Suppress("UNUSED_PARAMETER") sessionDurationMs: Int) {
        trackSessionStart(sessionStart)
    }

    fun getConfig(callback: ConfigCallback) {
        checkInitialized()
        thread {
            try {
                val configJson = apiClient.getConfig().toString()
                callback.onSuccess(configJson)
            } catch (e: Exception) {
                callback.onError(e.message ?: "Unknown error")
            }
        }
    }

    private fun checkInitialized() {
        if (!isInitialized) {
            throw IllegalStateException("VibeGrowthSDK is not initialized. Call initialize() first.")
        }
    }
}
