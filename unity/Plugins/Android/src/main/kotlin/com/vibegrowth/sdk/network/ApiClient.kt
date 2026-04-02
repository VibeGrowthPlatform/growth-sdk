package com.vibegrowth.sdk.network

import com.vibegrowth.sdk.VibeGrowthConfig
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class ApiClient(private val config: VibeGrowthConfig) {

    private fun request(method: String, path: String, body: JSONObject? = null): String {
        val normalizedBaseUrl = config.baseUrl.trimEnd('/')
        val url = URL("$normalizedBaseUrl$path")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.setRequestProperty("Authorization", "Bearer ${config.apiKey}")
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            if (body != null) {
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(body.toString())
                    writer.flush()
                }
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

    fun post(path: String, body: JSONObject): String {
        return request("POST", path, body)
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

    fun postSession(
        deviceId: String,
        userId: String?,
        sessionStart: String,
        isFirstSession: Boolean
    ): String {
        val body = JSONObject().apply {
            put("app_id", config.appId)
            put("device_id", deviceId)
            if (userId != null) {
                put("user_id", userId)
            }
            put("session_start", sessionStart)
            put("is_first_session", isFirstSession)
        }
        return post(ApiEndpoints.SESSION, body)
    }

    fun getConfig(): JSONObject {
        val response = request("GET", ApiEndpoints.CONFIG)
        val payload = JSONObject(response)
        return payload.optJSONObject("config") ?: JSONObject()
    }
}
