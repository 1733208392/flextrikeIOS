package com.flextarget.android

import android.app.Application
import android.util.Log
import com.flextarget.android.di.AppContainer

/**
 * FlexTarget Application class
 */
class FlexTargetApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Log.d("FlexTargetApplication", "Application onCreate called")
        AppContainer.initialize(this)
        Log.d("FlexTargetApplication", "AppContainer initialized")
    }
}
