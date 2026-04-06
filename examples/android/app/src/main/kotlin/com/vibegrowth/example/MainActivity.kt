package com.vibegrowth.example

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.vibegrowth.sdk.VibeGrowthSDK
import java.time.Instant
import java.time.LocalTime

class MainActivity : Activity() {
    private lateinit var logView: TextView
    private lateinit var logScrollView: ScrollView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 48, 32, 32)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        root.addView(TextView(this).apply {
            text = "Vibe Growth SDK Example"
            textSize = 22f
            setTextColor(Color.BLACK)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 8)
        })

        // Subtitle with version info
        root.addView(TextView(this).apply {
            text = "SDK v2.1.0 | Base URL: http://10.0.2.2:8000"
            textSize = 12f
            setTextColor(Color.GRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        })

        // Buttons for each SDK feature
        addButton(root, "Set User ID") {
            val userId = "user-${System.currentTimeMillis()}"
            VibeGrowthSDK.setUserId(userId)
            log("setUserId(\"$userId\")")
            val retrieved = VibeGrowthSDK.getUserId()
            log("getUserId() = $retrieved")
        }

        addButton(root, "Get User ID") {
            val userId = VibeGrowthSDK.getUserId()
            log("getUserId() = $userId")
        }

        addButton(root, "Track Purchase") {
            VibeGrowthSDK.trackPurchase(
                pricePaid = 4.99,
                currency = "USD",
                productId = "gem_pack_100"
            )
            log("trackPurchase(4.99, USD, gem_pack_100)")
        }

        addButton(root, "Track Ad Revenue") {
            VibeGrowthSDK.trackAdRevenue(
                source = "admob",
                revenue = 0.02,
                currency = "USD"
            )
            log("trackAdRevenue(admob, 0.02, USD)")
        }

        addButton(root, "Track Session Start") {
            val now = Instant.now().toString()
            VibeGrowthSDK.trackSessionStart(now)
            log("trackSessionStart($now)")
        }

        addButton(root, "Get Config") {
            log("getConfig() - requesting...")
            VibeGrowthSDK.getConfig(object : VibeGrowthSDK.ConfigCallback {
                override fun onSuccess(configJson: String) {
                    runOnUiThread { log("getConfig() = $configJson") }
                }
                override fun onError(error: String) {
                    runOnUiThread { log("getConfig() error: $error") }
                }
            })
        }

        addButton(root, "Clear Log") {
            logView.text = "--- Log Output ---\n"
        }

        // Separator
        root.addView(TextView(this).apply {
            text = "--- Log Output ---"
            textSize = 12f
            setTextColor(Color.DKGRAY)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 16, 0, 8)
        })

        // Log output area in a scroll view that fills remaining space
        logView = TextView(this).apply {
            text = ""
            textSize = 11f
            typeface = Typeface.MONOSPACE
            setTextColor(Color.DKGRAY)
            setTextIsSelectable(true)
            setPadding(8, 8, 8, 8)
        }

        logScrollView = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#F5F5F5"))
            addView(logView)
        }

        root.addView(logScrollView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f
        ))

        setContentView(root)
        log("Activity created, SDK initializing from Application class")
    }

    private fun addButton(parent: LinearLayout, label: String, onClick: () -> Unit) {
        parent.addView(Button(this).apply {
            text = label
            isAllCaps = false
            setOnClickListener {
                try {
                    onClick()
                } catch (e: Exception) {
                    log("ERROR: ${e.message}")
                }
            }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 8
        })
    }

    private fun log(message: String) {
        val timestamp = LocalTime.now().toString().take(12)
        val line = "[$timestamp] $message\n"
        logView.append(line)
        Log.d("VGExample", message)
        // Auto-scroll to bottom
        logScrollView.post { logScrollView.fullScroll(ScrollView.FOCUS_DOWN) }
    }
}
