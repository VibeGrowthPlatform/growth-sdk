package com.vibegrowth.sdk.attribution

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class InstallReferrerHelper(private val context: Context) {

    fun getInstallReferrer(): Map<String, String?> {
        val result = mutableMapOf<String, String?>()
        val latch = CountDownLatch(1)

        val client = InstallReferrerClient.newBuilder(context).build()
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                try {
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        val details = client.installReferrer
                        result["install_referrer"] = details.installReferrer
                        result["referrer_click_timestamp"] = details.referrerClickTimestampSeconds.toString()
                        result["install_begin_timestamp"] = details.installBeginTimestampSeconds.toString()
                        result["google_play_instant"] = details.googlePlayInstantParam.toString()
                    } else {
                        result["error"] = "Install referrer response code: $responseCode"
                    }
                } catch (e: Exception) {
                    result["error"] = e.message
                } finally {
                    try {
                        client.endConnection()
                    } catch (_: Exception) {
                    }
                    latch.countDown()
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                result["error"] = "Install referrer service disconnected"
                latch.countDown()
            }
        })

        latch.await(5, TimeUnit.SECONDS)

        if (result.isEmpty()) {
            result["error"] = "Install referrer timed out"
        }

        return result
    }
}
