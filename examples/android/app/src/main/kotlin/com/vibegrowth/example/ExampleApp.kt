package com.vibegrowth.example

import android.app.Application
import android.util.Log

class ExampleApp : Application() {
    override fun onCreate() {
        super.onCreate()
        ExampleController.start(this)
        Log.d("VGExample", "Control server requested on port ${ExampleController.CONTROL_PORT}")
    }
}
