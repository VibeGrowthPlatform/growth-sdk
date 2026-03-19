package com.vibegrowth.sdk.flutter

import android.content.Context
import com.vibegrowth.sdk.VibeGrowthSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class VibeGrowthSdkPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.vibegrowth.sdk/channel")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val appId = call.argument<String>("appId")
                val apiKey = call.argument<String>("apiKey")
                if (appId == null || apiKey == null) {
                    result.error("INVALID_ARGS", "appId and apiKey are required", null)
                    return
                }
                VibeGrowthSDK.initialize(context, appId, apiKey, object : VibeGrowthSDK.InitCallback {
                    override fun onSuccess() {
                        result.success(null)
                    }

                    override fun onError(error: String) {
                        result.error("INIT_ERROR", error, null)
                    }
                })
            }
            "setUserId" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGS", "userId is required", null)
                    return
                }
                try {
                    VibeGrowthSDK.setUserId(userId)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_INITIALIZED", e.message, null)
                }
            }
            "getUserId" -> {
                try {
                    val userId = VibeGrowthSDK.getUserId()
                    result.success(userId)
                } catch (e: IllegalStateException) {
                    result.error("NOT_INITIALIZED", e.message, null)
                }
            }
            "trackPurchase" -> {
                val amount = call.argument<Double>("amount")
                val currency = call.argument<String>("currency")
                val productId = call.argument<String>("productId")
                if (amount == null || currency == null || productId == null) {
                    result.error("INVALID_ARGS", "amount, currency, and productId are required", null)
                    return
                }
                try {
                    VibeGrowthSDK.trackPurchase(amount, currency, productId)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_INITIALIZED", e.message, null)
                }
            }
            "trackAdRevenue" -> {
                val source = call.argument<String>("source")
                val revenue = call.argument<Double>("revenue")
                val currency = call.argument<String>("currency")
                if (source == null || revenue == null || currency == null) {
                    result.error("INVALID_ARGS", "source, revenue, and currency are required", null)
                    return
                }
                try {
                    VibeGrowthSDK.trackAdRevenue(source, revenue, currency)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_INITIALIZED", e.message, null)
                }
            }
            "trackSession" -> {
                val sessionStart = call.argument<String>("sessionStart")
                val sessionDurationMs = call.argument<Int>("sessionDurationMs")
                if (sessionStart == null || sessionDurationMs == null) {
                    result.error("INVALID_ARGS", "sessionStart and sessionDurationMs are required", null)
                    return
                }
                try {
                    VibeGrowthSDK.trackSession(sessionStart, sessionDurationMs)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_INITIALIZED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
