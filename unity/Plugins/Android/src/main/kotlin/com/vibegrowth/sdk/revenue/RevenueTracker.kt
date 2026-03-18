package com.vibegrowth.sdk.revenue

import com.vibegrowth.sdk.identity.UserIdentityManager
import com.vibegrowth.sdk.network.ApiClient
import org.json.JSONObject
import kotlin.concurrent.thread

class RevenueTracker(
    private val apiClient: ApiClient,
    private val identityManager: UserIdentityManager
) {

    fun trackPurchase(amount: Double, currency: String, productId: String) {
        val event = JSONObject().apply {
            put("revenue_type", "purchase")
            put("amount", amount)
            put("currency", currency)
            put("product_id", productId)
        }
        postRevenue(event)
    }

    fun trackAdRevenue(source: String, revenue: Double, currency: String) {
        val event = JSONObject().apply {
            put("revenue_type", "ad_revenue")
            put("amount", revenue)
            put("currency", currency)
            put("ad_source", source)
        }
        postRevenue(event)
    }

    private fun postRevenue(event: JSONObject) {
        thread {
            try {
                val deviceId = identityManager.getOrCreateDeviceId()
                val userId = identityManager.getUserId()
                apiClient.postRevenue(deviceId, userId, event)
            } catch (e: Exception) {
                // Silently handle network errors for revenue tracking
            }
        }
    }
}
