package com.vibegrowth.example

import android.content.Context
import android.util.Log
import com.vibegrowth.sdk.VibeGrowthSDK
import org.json.JSONObject
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URI
import java.net.URLDecoder
import java.time.Duration
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

object ExampleController {
    const val CONTROL_PORT = 8766
    const val DEFAULT_APP_ID = "sm_app_sdk_e2e"
    const val DEFAULT_API_KEY = "sk_live_sdk_e2e_local_only"
    const val DEFAULT_BASE_URL = "http://10.0.2.2:8000"

    private enum class InitStatus(val wireName: String) {
        NOT_STARTED("not_started"),
        INITIALIZING("initializing"),
        READY("ready"),
        FAILED("failed"),
    }

    private data class CommandRecord(
        val command: String,
        val status: String,
        val detail: String?,
        val timestamp: String,
    )

    private val stateLock = Any()
    private lateinit var appContext: Context
    private var initStatus = InitStatus.NOT_STARTED
    private var baseUrl = DEFAULT_BASE_URL
    private var appId = DEFAULT_APP_ID
    private var currentUserId: String? = null
    private var commandCount = 0
    private var lastCommand: CommandRecord? = null
    private var serverError: String? = null
    private var serverSocket: ServerSocket? = null

    fun start(context: Context) {
        appContext = context.applicationContext
        synchronized(stateLock) {
            if (serverSocket != null) return
        }

        thread(name = "VGExampleControlServer", isDaemon = true) {
            try {
                val socket = ServerSocket().apply {
                    reuseAddress = true
                    bind(InetSocketAddress("0.0.0.0", CONTROL_PORT))
                }
                synchronized(stateLock) {
                    serverSocket = socket
                    serverError = null
                }
                Log.d("VGExample", "Control server listening on $CONTROL_PORT")
                while (!socket.isClosed) {
                    val client = socket.accept()
                    thread(name = "VGExampleControlRequest", isDaemon = true) {
                        serveClient(client)
                    }
                }
            } catch (error: Exception) {
                synchronized(stateLock) {
                    serverError = error.message ?: error.toString()
                    serverSocket = null
                }
                Log.e("VGExample", "Control server failed", error)
            }
        }
    }

    fun executeCommand(name: String, params: Map<String, String>, rawUrl: String): JSONObject {
        val startedAt = Instant.now()
        recordCommand(name, "running", "Executing remote command")

        var status = "completed"
        var detail: String?
        var errorMessage: String? = null
        val data = JSONObject()

        try {
            when (name) {
                "initialize" -> {
                    val requestedAppId = params["app_id"]?.takeIf { it.isNotBlank() } ?: DEFAULT_APP_ID
                    val requestedApiKey = params["api_key"]?.takeIf { it.isNotBlank() } ?: DEFAULT_API_KEY
                    val requestedBaseUrl = params["base_url"]?.takeIf { it.isNotBlank() } ?: DEFAULT_BASE_URL
                    initializeSdk(requestedAppId, requestedApiKey, requestedBaseUrl)
                    detail = "initialized baseUrl=$requestedBaseUrl appId=$requestedAppId"
                    data.put("appId", requestedAppId)
                    data.put("baseUrl", requestedBaseUrl)
                }
                "set-user-id" -> {
                    val userId = params["user_id"]?.takeIf { it.isNotBlank() }
                        ?: "android-user-${System.currentTimeMillis()}"
                    VibeGrowthSDK.setUserId(userId)
                    currentUserId = VibeGrowthSDK.getUserId()
                    detail = "userId=$currentUserId"
                    data.put("userId", currentUserId)
                }
                "track-purchase" -> {
                    val amount = params["amount"]?.toDoubleOrNull() ?: 4.99
                    val currency = params["currency"]?.takeIf { it.isNotBlank() } ?: "USD"
                    val productId = params["product_id"]?.takeIf { it.isNotBlank() } ?: "gem_pack_100"
                    VibeGrowthSDK.trackPurchase(amount, currency, productId)
                    detail = "purchase=$amount $currency productId=$productId"
                    data.put("amount", amount)
                    data.put("currency", currency)
                    data.put("productId", productId)
                }
                "track-ad-revenue" -> {
                    val source = params["source"]?.takeIf { it.isNotBlank() } ?: "admob"
                    val revenue = params["revenue"]?.toDoubleOrNull() ?: 0.02
                    val currency = params["currency"]?.takeIf { it.isNotBlank() } ?: "USD"
                    VibeGrowthSDK.trackAdRevenue(source, revenue, currency)
                    detail = "adRevenue=$revenue $currency source=$source"
                    data.put("source", source)
                    data.put("revenue", revenue)
                    data.put("currency", currency)
                }
                "track-session-start" -> {
                    val sessionStart = params["session_start"]?.takeIf { it.isNotBlank() }
                        ?: Instant.now().toString()
                    VibeGrowthSDK.trackSessionStart(sessionStart)
                    detail = "sessionStart=$sessionStart"
                    data.put("sessionStart", sessionStart)
                }
                "get-config" -> {
                    val configJson = fetchConfig()
                    detail = "config=$configJson"
                    data.put("config", JSONObject(configJson))
                }
                "refresh" -> {
                    refreshRuntimeState()
                    detail = "runtime refreshed"
                }
                else -> {
                    status = "ignored"
                    detail = "unknown command: $name"
                }
            }
        } catch (error: Exception) {
            status = "failed"
            errorMessage = error.message ?: error.toString()
            detail = errorMessage
        }

        val finishedAt = Instant.now()
        recordCommand(name, status, detail)

        return JSONObject().apply {
            put("ok", status == "completed")
            put("command", name)
            put("status", status)
            put("detail", detail)
            if (errorMessage != null) put("error", errorMessage)
            put("data", data)
            put("rawUrl", rawUrl)
            put("startedAt", startedAt.toString())
            put("finishedAt", finishedAt.toString())
            put("elapsedMs", Duration.between(startedAt, finishedAt).toMillis().coerceAtLeast(0))
            put("state", statusJson())
        }
    }

    fun statusJson(): JSONObject {
        refreshRuntimeState()
        return synchronized(stateLock) {
            JSONObject().apply {
                put("ok", initStatus == InitStatus.READY)
                put("initStatus", initStatus.wireName)
                put("appId", appId)
                put("baseUrl", baseUrl)
                put("userId", currentUserId ?: JSONObject.NULL)
                put("commandCount", commandCount)
                put("controlPort", CONTROL_PORT)
                put("controlServerError", serverError ?: JSONObject.NULL)
                put("lastCommand", lastCommand?.let {
                    JSONObject().apply {
                        put("command", it.command)
                        put("status", it.status)
                        put("detail", it.detail ?: JSONObject.NULL)
                        put("timestamp", it.timestamp)
                    }
                } ?: JSONObject.NULL)
            }
        }
    }

    private fun initializeSdk(requestedAppId: String, requestedApiKey: String, requestedBaseUrl: String) {
        synchronized(stateLock) {
            if (initStatus == InitStatus.READY) return
            initStatus = InitStatus.INITIALIZING
            appId = requestedAppId
            baseUrl = requestedBaseUrl
        }

        val latch = CountDownLatch(1)
        var initError: String? = null
        VibeGrowthSDK.initialize(
            context = appContext,
            appId = requestedAppId,
            apiKey = requestedApiKey,
            baseUrl = requestedBaseUrl,
            callback = object : VibeGrowthSDK.InitCallback {
                override fun onSuccess() {
                    latch.countDown()
                }

                override fun onError(error: String) {
                    initError = error
                    latch.countDown()
                }
            },
        )

        check(latch.await(20, TimeUnit.SECONDS)) { "SDK initialization timed out" }
        if (initError != null) {
            synchronized(stateLock) { initStatus = InitStatus.FAILED }
            error("SDK initialization failed: $initError")
        }
        synchronized(stateLock) { initStatus = InitStatus.READY }
        refreshRuntimeState()
    }

    private fun fetchConfig(): String {
        val latch = CountDownLatch(1)
        var configPayload: String? = null
        var configError: String? = null
        VibeGrowthSDK.getConfig(
            object : VibeGrowthSDK.ConfigCallback {
                override fun onSuccess(configJson: String) {
                    configPayload = configJson
                    latch.countDown()
                }

                override fun onError(error: String) {
                    configError = error
                    latch.countDown()
                }
            },
        )
        check(latch.await(20, TimeUnit.SECONDS)) { "Config fetch timed out" }
        if (configError != null) error("Config fetch failed: $configError")
        return configPayload ?: "{}"
    }

    private fun refreshRuntimeState() {
        val ready = synchronized(stateLock) { initStatus == InitStatus.READY }
        if (!ready) return
        currentUserId = try {
            VibeGrowthSDK.getUserId()
        } catch (_: Exception) {
            null
        }
    }

    private fun recordCommand(command: String, status: String, detail: String?) {
        synchronized(stateLock) {
            if (status == "running") commandCount += 1
            lastCommand = CommandRecord(
                command = command,
                status = status,
                detail = detail,
                timestamp = Instant.now().toString(),
            )
        }
        Log.d("VGExample", "$command $status ${detail.orEmpty()}")
    }

    private fun serveClient(socket: Socket) {
        socket.use { client ->
            try {
                val reader = client.getInputStream().bufferedReader()
                val requestLine = reader.readLine()
                if (requestLine.isNullOrBlank()) {
                    writeResponse(client, 400, JSONObject(mapOf("ok" to false, "error" to "empty request")))
                    return
                }
                while (true) {
                    val line = reader.readLine() ?: break
                    if (line.isEmpty()) break
                }

                val parts = requestLine.split(" ")
                if (parts.size < 2) {
                    writeResponse(client, 400, JSONObject(mapOf("ok" to false, "error" to "bad request line")))
                    return
                }

                val target = parts[1]
                val uri = URI(target)
                val path = uri.path.trim('/').ifEmpty { "status" }
                val body = when (path) {
                    "health" -> JSONObject().put("ok", true).put("controlPort", CONTROL_PORT)
                    "status" -> statusJson()
                    else -> executeCommand(path, parseQuery(uri.rawQuery), target)
                }
                val statusCode = when (body.optString("status")) {
                    "failed" -> 500
                    "ignored" -> 400
                    else -> 200
                }
                writeResponse(client, statusCode, body)
            } catch (error: Exception) {
                writeResponse(
                    client,
                    500,
                    JSONObject()
                        .put("ok", false)
                        .put("status", "failed")
                        .put("error", error.message ?: error.toString()),
                )
            }
        }
    }

    private fun writeResponse(socket: Socket, statusCode: Int, body: JSONObject) {
        val statusText = when (statusCode) {
            200 -> "OK"
            400 -> "Bad Request"
            else -> "Internal Server Error"
        }
        val bytes = body.toString().toByteArray(Charsets.UTF_8)
        socket.getOutputStream().use { output ->
            output.write(
                buildString {
                    append("HTTP/1.1 $statusCode $statusText\r\n")
                    append("Content-Type: application/json; charset=utf-8\r\n")
                    append("Access-Control-Allow-Origin: *\r\n")
                    append("Connection: close\r\n")
                    append("Content-Length: ${bytes.size}\r\n")
                    append("\r\n")
                }.toByteArray(Charsets.UTF_8),
            )
            output.write(bytes)
            output.flush()
        }
    }

    private fun parseQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrBlank()) return emptyMap()
        return rawQuery
            .split("&")
            .filter { it.isNotBlank() }
            .associate { part ->
                val key = part.substringBefore("=")
                val value = part.substringAfter("=", "")
                decode(key) to decode(value)
            }
    }

    private fun decode(value: String): String {
        return URLDecoder.decode(value, "UTF-8")
    }
}
