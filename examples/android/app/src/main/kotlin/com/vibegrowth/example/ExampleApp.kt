package com.vibegrowth.example

import android.app.Application
import android.util.Log
import com.vibegrowth.sdk.VibeGrowthSDK

class ExampleApp : Application() {
    override fun onCreate() {
        super.onCreate()
        VibeGrowthSDK.initialize(
            context = this,
            appId = "sm_app_example",
            apiKey = "sk_live_example_key",
            baseUrl = "http://10.0.2.2:8000",
            callback = object : VibeGrowthSDK.InitCallback {
                override fun onSuccess() {
                    Log.d("VGExample", "SDK initialized successfully")
                }
                override fun onError(error: String) {
                    Log.e("VGExample", "SDK init failed: $error")
                }
            }
        )
    }
}
