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
import java.time.Instant
import java.time.LocalTime
import kotlin.concurrent.thread

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
            text = "SDK v0.0.1 | Control: http://127.0.0.1:${ExampleController.CONTROL_PORT}"
            textSize = 12f
            setTextColor(Color.GRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        })

        addButton(root, "Initialize SDK") {
            runCommand(
                "initialize",
                mapOf(
                    "app_id" to ExampleController.DEFAULT_APP_ID,
                    "api_key" to ExampleController.DEFAULT_API_KEY,
                    "base_url" to ExampleController.DEFAULT_BASE_URL,
                ),
            )
        }

        // Buttons for each SDK feature
        addButton(root, "Set User ID") {
            val userId = "user-${System.currentTimeMillis()}"
            runCommand("set-user-id", mapOf("user_id" to userId))
        }

        addButton(root, "Get User ID") {
            log("status = ${ExampleController.statusJson()}")
        }

        addButton(root, "Track Purchase") {
            runCommand(
                "track-purchase",
                mapOf("amount" to "4.99", "currency" to "USD", "product_id" to "gem_pack_100"),
            )
        }

        addButton(root, "Track Ad Revenue") {
            runCommand(
                "track-ad-revenue",
                mapOf("source" to "admob", "revenue" to "0.02", "currency" to "USD"),
            )
        }

        addButton(root, "Track Session Start") {
            runCommand("track-session-start", mapOf("session_start" to Instant.now().toString()))
        }

        addButton(root, "Get Config") {
            runCommand("get-config", emptyMap())
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
        log("Activity created; initialize with the button or host control script")
        log("For emulator control, run: adb forward tcp:${ExampleController.CONTROL_PORT} tcp:${ExampleController.CONTROL_PORT}")
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

    private fun runCommand(name: String, params: Map<String, String>) {
        thread(name = "VGExampleButtonCommand") {
            val query = params.entries.joinToString("&") { "${it.key}=${it.value}" }
            val rawUrl = if (query.isBlank()) "/$name" else "/$name?$query"
            val result = ExampleController.executeCommand(name, params, rawUrl)
            runOnUiThread {
                log("$name -> ${result.optString("status")} ${result.optString("detail")}")
            }
        }
    }
}
