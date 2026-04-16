package com.vibegrowth.sdk

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class VibeGrowthSdkEndToEndTest {
    private lateinit var context: Context
    private lateinit var testConfig: SdkE2eConfig

    @Before
    fun setUp() {
        testConfig = loadSdkE2eConfig()
        assumeTrue(testConfig.enabled)
        context = TestContext()
        VibeGrowthSDK.resetForTests(context)
        VibeGrowthSDK.installReferrerProviderForTests = { emptyMap() }
    }

    @After
    fun tearDown() {
        if (::context.isInitialized) {
            VibeGrowthSDK.resetForTests(context)
        }
    }

    @Test
    fun fullSdkFlowPersistsThroughRealBackend() {
        val deviceId = "android-e2e-${UUID.randomUUID()}"
        val userId = "user-${UUID.randomUUID()}"
        val productId = "product-${UUID.randomUUID()}"
        val firstSessionStart = "2026-04-02T10:00:00+00:00"
        val secondSessionStart = "2026-04-02T10:05:00+00:00"

        context
            .getSharedPreferences("vibegrowth_sdk", Context.MODE_PRIVATE)
            .edit()
            .putString("device_id", deviceId)
            .commit()

        initializeSdk()

        eventuallyEquals(
            expected = "android",
            query = """
                SELECT platform
                FROM devices FINAL
                WHERE device_id = ${sqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """.trimIndent(),
        )
        eventuallyEquals(
            expected = "0.0.1",
            query = """
                SELECT sdk_version
                FROM devices FINAL
                WHERE device_id = ${sqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """.trimIndent(),
        )

        VibeGrowthSDK.setUserId(userId)
        assertEquals(userId, VibeGrowthSDK.getUserId())
        eventuallyEquals(
            expected = userId,
            query = """
                SELECT ifNull(user_id, '')
                FROM devices FINAL
                WHERE device_id = ${sqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """.trimIndent(),
        )

        VibeGrowthSDK.trackPurchase(
            pricePaid = 4.99,
            currency = "USD",
            productId = productId,
        )
        eventuallyEquals(
            expected = productId,
            query = """
                SELECT ifNull(product_id, '')
                FROM revenue_events
                WHERE device_id = ${sqlString(deviceId)}
                  AND product_id = ${sqlString(productId)}
                ORDER BY received_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """.trimIndent(),
        )

        VibeGrowthSDK.trackSessionStart(firstSessionStart)
        VibeGrowthSDK.trackSessionStart(secondSessionStart)
        eventuallyEquals(
            expected = "1",
            query = """
                SELECT count()
                FROM session_events
                WHERE device_id = ${sqlString(deviceId)}
                  AND is_first_session = 1
                FORMAT TSVRaw
            """.trimIndent(),
        )
        eventuallyEquals(
            expected = "1",
            query = """
                SELECT count()
                FROM session_events
                WHERE device_id = ${sqlString(deviceId)}
                  AND is_first_session = 0
                FORMAT TSVRaw
            """.trimIndent(),
        )

        val configResult = fetchConfig()
        assertNull(configResult.second)
        assertEquals("{}", configResult.first)
    }

    private fun initializeSdk() {
        val latch = CountDownLatch(1)
        var initError: String? = null

        VibeGrowthSDK.initialize(
            context = context,
            appId = testConfig.appId,
            apiKey = testConfig.apiKey,
            baseUrl = testConfig.baseUrl,
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
        assertNull(initError)
    }

    private fun fetchConfig(): Pair<String?, String?> {
        val latch = CountDownLatch(1)
        var configJson: String? = null
        var configError: String? = null

        VibeGrowthSDK.getConfig(
            object : VibeGrowthSDK.ConfigCallback {
                override fun onSuccess(configJsonValue: String) {
                    configJson = configJsonValue
                    latch.countDown()
                }

                override fun onError(error: String) {
                    configError = error
                    latch.countDown()
                }
            },
        )

        check(latch.await(20, TimeUnit.SECONDS)) { "Config fetch timed out" }
        return configJson to configError
    }

    private fun eventuallyEquals(
        expected: String,
        query: String,
        timeoutSeconds: Long = 20,
        pollIntervalMillis: Long = 500,
    ) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(timeoutSeconds)
        var lastValue = ""
        var lastError: String? = null

        while (System.nanoTime() < deadline) {
            try {
                lastValue = runClickHouseQuery(query)
                if (lastValue == expected) {
                    return
                }
            } catch (error: Exception) {
                lastError = error.message
            }
            Thread.sleep(pollIntervalMillis)
        }

        error(
            buildString {
                append("Timed out waiting for ClickHouse query result. expected=")
                append(expected)
                append(", lastValue=")
                append(lastValue)
                if (lastError != null) {
                    append(", lastError=")
                    append(lastError)
                }
            },
        )
    }

    private fun runClickHouseQuery(query: String): String {
        val connection = URL(
            "${testConfig.clickHouseUrl}/?database=${testConfig.clickHouseDatabase}&wait_end_of_query=1",
        ).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.doOutput = true

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(query)
                writer.flush()
            }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() }
                error("ClickHouse query failed: HTTP $responseCode ${connection.responseMessage} ${errorBody.orEmpty()}")
            }

            return connection.inputStream.bufferedReader().use { it.readText().trim() }
        } finally {
            connection.disconnect()
        }
    }

    private fun sqlString(value: String): String {
        return "'${value.replace("'", "''")}'"
    }

    private fun loadSdkE2eConfig(): SdkE2eConfig {
        val configFile = File(SDK_E2E_CONFIG_PATH)
        if (configFile.isFile) {
            val json = configFile.readText()
            return SdkE2eConfig(
                enabled = jsonBooleanField(json, "enabled") ?: false,
                appId = jsonStringField(json, "appId") ?: DEFAULT_APP_ID,
                apiKey = jsonStringField(json, "apiKey") ?: DEFAULT_API_KEY,
                baseUrl = jsonStringField(json, "baseUrl") ?: DEFAULT_BASE_URL,
                clickHouseUrl = jsonStringField(json, "clickHouseUrl") ?: DEFAULT_CLICKHOUSE_URL,
                clickHouseDatabase = jsonStringField(json, "clickHouseDatabase") ?: DEFAULT_CLICKHOUSE_DATABASE,
            )
        }

        return SdkE2eConfig(
            enabled = System.getenv("VIBEGROWTH_SDK_E2E") == "1",
            appId = System.getenv("VIBEGROWTH_SDK_E2E_APP_ID") ?: DEFAULT_APP_ID,
            apiKey = System.getenv("VIBEGROWTH_SDK_E2E_API_KEY") ?: DEFAULT_API_KEY,
            baseUrl = System.getenv("VIBEGROWTH_SDK_E2E_BASE_URL") ?: DEFAULT_BASE_URL,
            clickHouseUrl = System.getenv("VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL") ?: DEFAULT_CLICKHOUSE_URL,
            clickHouseDatabase = System.getenv("VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE") ?: DEFAULT_CLICKHOUSE_DATABASE,
        )
    }

    private fun jsonBooleanField(json: String, fieldName: String): Boolean? {
        val match = Regex("\"${Regex.escape(fieldName)}\"\\s*:\\s*(true|false)").find(json) ?: return null
        return match.groupValues[1].toBooleanStrictOrNull()
    }

    private fun jsonStringField(json: String, fieldName: String): String? {
        val match = Regex("\"${Regex.escape(fieldName)}\"\\s*:\\s*\"([^\"]*)\"").find(json) ?: return null
        return match.groupValues[1]
    }

    private data class SdkE2eConfig(
        val enabled: Boolean,
        val appId: String,
        val apiKey: String,
        val baseUrl: String,
        val clickHouseUrl: String,
        val clickHouseDatabase: String,
    )

    private class TestContext : ContextWrapper(null) {
        private val sharedPreferencesByName = mutableMapOf<String, InMemorySharedPreferences>()

        override fun getApplicationContext(): Context {
            return this
        }

        override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences {
            val key = name ?: "default"
            return sharedPreferencesByName.getOrPut(key) { InMemorySharedPreferences() }
        }
    }

    private class InMemorySharedPreferences : SharedPreferences {
        private val values = linkedMapOf<String, Any?>()
        private val listeners = linkedSetOf<SharedPreferences.OnSharedPreferenceChangeListener>()

        override fun getAll(): MutableMap<String, *> {
            return LinkedHashMap(values)
        }

        override fun getString(key: String?, defValue: String?): String? {
            return values[key] as? String ?: defValue
        }

        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? {
            @Suppress("UNCHECKED_CAST")
            return (values[key] as? Set<String>)?.toMutableSet() ?: defValues
        }

        override fun getInt(key: String?, defValue: Int): Int {
            return values[key] as? Int ?: defValue
        }

        override fun getLong(key: String?, defValue: Long): Long {
            return values[key] as? Long ?: defValue
        }

        override fun getFloat(key: String?, defValue: Float): Float {
            return values[key] as? Float ?: defValue
        }

        override fun getBoolean(key: String?, defValue: Boolean): Boolean {
            return values[key] as? Boolean ?: defValue
        }

        override fun contains(key: String?): Boolean {
            return values.containsKey(key)
        }

        override fun edit(): SharedPreferences.Editor {
            return Editor()
        }

        override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {
            if (listener != null) {
                listeners += listener
            }
        }

        override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {
            if (listener != null) {
                listeners -= listener
            }
        }

        private inner class Editor : SharedPreferences.Editor {
            private val updates = linkedMapOf<String, Any?>()
            private val removals = linkedSetOf<String>()
            private var shouldClear = false

            override fun putString(key: String?, value: String?): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = value
                removals -= key
            }

            override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = values?.toSet()
                removals -= key
            }

            override fun putInt(key: String?, value: Int): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = value
                removals -= key
            }

            override fun putLong(key: String?, value: Long): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = value
                removals -= key
            }

            override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = value
                removals -= key
            }

            override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = apply {
                updates[key ?: return@apply] = value
                removals -= key
            }

            override fun remove(key: String?): SharedPreferences.Editor = apply {
                key ?: return@apply
                removals += key
                updates.remove(key)
            }

            override fun clear(): SharedPreferences.Editor = apply {
                shouldClear = true
                updates.clear()
                removals.clear()
            }

            override fun commit(): Boolean {
                applyChanges()
                return true
            }

            override fun apply() {
                applyChanges()
            }

            private fun applyChanges() {
                if (shouldClear) {
                    values.clear()
                }
                removals.forEach(values::remove)
                updates.forEach { (key, value) ->
                    values[key] = value
                }
                val changedKeys = buildList {
                    if (shouldClear) {
                        addAll(values.keys)
                    }
                    addAll(removals)
                    addAll(updates.keys)
                }.distinct()
                changedKeys.forEach { key ->
                    listeners.forEach { listener ->
                        listener.onSharedPreferenceChanged(this@InMemorySharedPreferences, key)
                    }
                }
            }
        }
    }

    private companion object {
        private const val SDK_E2E_CONFIG_PATH = "/tmp/vibegrowth-sdk-e2e.json"
        private const val DEFAULT_APP_ID = "sm_app_sdk_e2e"
        private const val DEFAULT_API_KEY = "sk_live_sdk_e2e_local_only"
        private const val DEFAULT_BASE_URL = "http://127.0.0.1:8000"
        private const val DEFAULT_CLICKHOUSE_URL = "http://127.0.0.1:8123"
        private const val DEFAULT_CLICKHOUSE_DATABASE = "scalemonk"
    }
}
