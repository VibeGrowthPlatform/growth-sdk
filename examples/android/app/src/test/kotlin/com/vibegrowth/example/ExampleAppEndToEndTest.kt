package com.vibegrowth.example

import android.content.Context
import android.content.SharedPreferences
import com.vibegrowth.sdk.VibeGrowthSDK
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * End-to-end test that exercises the example app's SDK integration
 * against the real local backend.
 *
 * Enable via /tmp/vibegrowth-sdk-e2e.json or VIBEGROWTH_SDK_E2E=1.
 */
class ExampleAppEndToEndTest {

    private val enabled: Boolean
        get() {
            val f = File("/tmp/vibegrowth-sdk-e2e.json")
            if (f.isFile) {
                return Regex("\"enabled\"\\s*:\\s*(true|false)").find(f.readText())
                    ?.groupValues?.get(1)?.toBooleanStrictOrNull() ?: false
            }
            return System.getenv("VIBEGROWTH_SDK_E2E") == "1"
        }

    private val baseUrl get() = jsonField("baseUrl") ?: "http://[::1]:8000"
    private val appId get() = jsonField("appId") ?: "sm_app_sdk_e2e"
    private val apiKey get() = jsonField("apiKey") ?: "sk_live_sdk_e2e_local_only"
    private val chUrl get() = jsonField("clickHouseUrl") ?: "http://[::1]:8123"
    private val chDb get() = jsonField("clickHouseDatabase") ?: "scalemonk"

    @Test
    fun exampleAppFlowWorksEndToEnd() {
        assumeTrue("SDK e2e disabled", enabled)

        val userId = "example-user-${UUID.randomUUID()}"
        val productId = "example-product-${UUID.randomUUID()}"

        val context = createMockContext()

        // 1. Initialize
        val initLatch = CountDownLatch(1)
        var initError: String? = null
        VibeGrowthSDK.initialize(
            context = context,
            appId = appId,
            apiKey = apiKey,
            baseUrl = baseUrl,
            callback = object : VibeGrowthSDK.InitCallback {
                override fun onSuccess() { initLatch.countDown() }
                override fun onError(error: String) {
                    initError = error
                    initLatch.countDown()
                }
            },
        )
        check(initLatch.await(20, TimeUnit.SECONDS)) { "Init timed out" }
        assertNull("Init failed: $initError", initError)

        // 2. Set User ID
        VibeGrowthSDK.setUserId(userId)
        assertEquals(userId, VibeGrowthSDK.getUserId())

        // Find device_id from ClickHouse via user_id
        eventuallyEquals(userId, """
            SELECT ifNull(user_id, '') FROM devices FINAL
            WHERE user_id = ${q(userId)}
            ORDER BY updated_at DESC LIMIT 1 FORMAT TSVRaw
        """.trimIndent())

        val deviceId = chQuery("""
            SELECT device_id FROM devices FINAL
            WHERE user_id = ${q(userId)}
            ORDER BY updated_at DESC LIMIT 1 FORMAT TSVRaw
        """.trimIndent())
        check(deviceId.isNotEmpty()) { "Could not resolve device_id" }

        // 3. Track Purchase
        VibeGrowthSDK.trackPurchase(pricePaid = 4.99, currency = "USD", productId = productId)

        eventuallyEquals(productId, """
            SELECT ifNull(product_id, '') FROM revenue_events
            WHERE device_id = ${q(deviceId)} AND product_id = ${q(productId)}
            ORDER BY received_at DESC LIMIT 1 FORMAT TSVRaw
        """.trimIndent())

        // 4. Track Ad Revenue
        VibeGrowthSDK.trackAdRevenue(source = "admob", revenue = 0.02, currency = "USD")

        eventuallyEquals("ad_revenue", """
            SELECT revenue_type FROM revenue_events
            WHERE device_id = ${q(deviceId)} AND revenue_type = 'ad_revenue'
            ORDER BY received_at DESC LIMIT 1 FORMAT TSVRaw
        """.trimIndent())

        // 5. Track Session
        VibeGrowthSDK.trackSessionStart("2026-04-06T10:00:00+00:00")

        eventuallyEquals("1", """
            SELECT toString(count()) FROM session_events
            WHERE device_id = ${q(deviceId)}
            FORMAT TSVRaw
        """.trimIndent())

        // 6. Get Config
        val configLatch = CountDownLatch(1)
        var configJson: String? = null
        var configError: String? = null
        VibeGrowthSDK.getConfig(object : VibeGrowthSDK.ConfigCallback {
            override fun onSuccess(configJsonValue: String) {
                configJson = configJsonValue
                configLatch.countDown()
            }
            override fun onError(error: String) {
                configError = error
                configLatch.countDown()
            }
        })
        check(configLatch.await(20, TimeUnit.SECONDS)) { "Config timed out" }
        assertNull("Config error: $configError", configError)
        assertEquals("{}", configJson)
    }

    // --- Helpers ---

    private fun createMockContext(): Context {
        val prefsMap = mutableMapOf<String, SharedPreferences>()
        val context = mockk<Context>(relaxed = true)
        every { context.applicationContext } returns context
        every { context.getSharedPreferences(any(), any()) } answers {
            val name = firstArg<String>()
            prefsMap.getOrPut(name) { InMemoryPrefs() }
        }
        return context
    }

    private fun eventuallyEquals(expected: String, query: String) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(20)
        var lastValue = ""
        var lastError: String? = null
        while (System.nanoTime() < deadline) {
            try {
                lastValue = chQuery(query)
                if (lastValue == expected) return
            } catch (e: Exception) { lastError = e.message }
            Thread.sleep(500)
        }
        error("Timed out. expected=$expected, lastValue=$lastValue, lastError=$lastError")
    }

    private fun chQuery(query: String): String {
        val conn = URL("$chUrl/?database=$chDb&wait_end_of_query=1")
            .openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.doOutput = true
            OutputStreamWriter(conn.outputStream).use { it.write(query); it.flush() }
            if (conn.responseCode !in 200..299) {
                val body = conn.errorStream?.bufferedReader()?.use { it.readText() }
                error("CH HTTP ${conn.responseCode}: ${body.orEmpty()}")
            }
            return conn.inputStream.bufferedReader().use { it.readText().trim() }
        } finally { conn.disconnect() }
    }

    private fun q(v: String) = "'${v.replace("'", "''")}'"

    private fun jsonField(field: String): String? {
        val f = File("/tmp/vibegrowth-sdk-e2e.json")
        if (!f.isFile) return null
        return Regex("\"${Regex.escape(field)}\"\\s*:\\s*\"([^\"]*)\"").find(f.readText())
            ?.groupValues?.get(1)
    }

    private class InMemoryPrefs : SharedPreferences {
        private val values = linkedMapOf<String, Any?>()
        override fun getAll(): MutableMap<String, *> = LinkedHashMap(values)
        override fun getString(key: String?, defValue: String?) = values[key] as? String ?: defValue
        override fun getStringSet(key: String?, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String?, defValue: Int) = values[key] as? Int ?: defValue
        override fun getLong(key: String?, defValue: Long) = values[key] as? Long ?: defValue
        override fun getFloat(key: String?, defValue: Float) = values[key] as? Float ?: defValue
        override fun getBoolean(key: String?, defValue: Boolean) = values[key] as? Boolean ?: defValue
        override fun contains(key: String?) = values.containsKey(key)
        override fun edit(): SharedPreferences.Editor = Ed()
        override fun registerOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}
        override fun unregisterOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}
        private inner class Ed : SharedPreferences.Editor {
            private val updates = linkedMapOf<String, Any?>()
            private val removals = mutableSetOf<String>()
            override fun putString(k: String?, v: String?) = apply { updates[k ?: return@apply] = v }
            override fun putStringSet(k: String?, v: MutableSet<String>?) = apply { updates[k ?: return@apply] = v }
            override fun putInt(k: String?, v: Int) = apply { updates[k ?: return@apply] = v }
            override fun putLong(k: String?, v: Long) = apply { updates[k ?: return@apply] = v }
            override fun putFloat(k: String?, v: Float) = apply { updates[k ?: return@apply] = v }
            override fun putBoolean(k: String?, v: Boolean) = apply { updates[k ?: return@apply] = v }
            override fun remove(k: String?) = apply { k?.let { removals += it; updates.remove(it) } }
            override fun clear() = apply { values.clear() }
            override fun commit(): Boolean { removals.forEach(values::remove); values.putAll(updates); return true }
            override fun apply() { commit() }
        }
    }
}
