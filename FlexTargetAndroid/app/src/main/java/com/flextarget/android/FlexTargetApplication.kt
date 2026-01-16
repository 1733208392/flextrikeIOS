package com.flextarget.android

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * FlexTarget Application class with Hilt dependency injection setup
 */
@HiltAndroidApp
class FlexTargetApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
