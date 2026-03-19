package com.vibegrowth.sdk.network

import com.vibegrowth.sdk.VibeGrowthConfig
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class ApiClient(private val config: VibeGrowthConfig) {

    fun post(path: String, body: JSONObject): String {
        val url = URL("${config.baseUrl}$path")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer ${config.apiKey}")
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body.toString())
                writer.flush()
            }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw RuntimeException("HTTP $responseCode: ${connection.responseMessage}")
            }

            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    fun postInit(deviceId: String, platform: String, attribution: JSONObject?, sdkVersion: String): String {
        val body = JSONObject().apply {
            put("app_id", config.appId)
            put("device_id", deviceId)
            put("platform", platform)
            put("sdk_version", sdkVersion)
            if (attribution != null) {
                put("attribution", attribution)
            }
        }
        return post(ApiEndpoints.INIT, body)
    }

    fun postIdentify(deviceId: String, userId: String): String {
        val body = JSONObject().apply {
            put("app_id", config.appId)
            put("device_id", deviceId)
            put("user_id", userId)
        }
        return post(ApiEndpoints.IDENTIFY, body)
    }

    fun postRevenue(deviceId: String, userId: String?, event: JSONObject): String {
        event.put("app_id", config.appId)
        event.put("device_id", deviceId)
        if (userId != null) {
            event.put("user_id", userId)
        }
        return post(ApiEndpoints.REVENUE, event)
    }

    fun postSession(deviceId: String, sessionStart: String, sessionDurationMs: Int): String {
        val body = JSONObject().apply {
            put("app_id", config.appId)
            put("device_id", deviceId)
            put("session_start", sessionStart)
            put("session_duration_ms", sessionDurationMs)
        }
        return post(ApiEndpoints.SESSION, body)
    }
}
