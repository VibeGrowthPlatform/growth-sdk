package com.vibegrowth.sdk

import org.junit.Assert.assertEquals
import org.junit.Test

class VibeGrowthConfigTest {

    @Test
    fun `uses default base url`() {
        val config = VibeGrowthConfig(appId = "app", apiKey = "key")

        assertEquals("https://api.vibegrowin.ai", config.baseUrl)
    }

    @Test
    fun `preserves explicit base url overrides`() {
        val config = VibeGrowthConfig(
            appId = "app",
            apiKey = "key",
            baseUrl = "http://localhost:8000"
        )

        assertEquals("http://localhost:8000", config.baseUrl)
    }
}
