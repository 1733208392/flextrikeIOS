package com.flextarget.android

import android.app.Application
import com.flextarget.android.di.AppContainer

/**
 * FlexTarget Application class
 */
class FlexTargetApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppContainer.initialize(this)
    }
}
