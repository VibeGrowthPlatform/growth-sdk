package com.vibegrowth.sdk

data class VibeGrowthConfig(
    val appId: String,
    val apiKey: String,
    val baseUrl: String = "https://api.vibegrowth.com"
)
