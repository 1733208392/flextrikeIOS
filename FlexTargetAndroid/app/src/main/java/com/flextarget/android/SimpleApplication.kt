package com.flextarget.android

import android.app.Application

/**
 * Simple Application class without Hilt dependency injection
 * Used temporarily to get the app running while Hilt issues are resolved
 */
class SimpleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize any non-Hilt dependencies here if needed
    }
}