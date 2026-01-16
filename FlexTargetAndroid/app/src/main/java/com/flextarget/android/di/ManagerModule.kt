package com.flextarget.android.di

import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.auth.TokenRefreshQueue
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.remote.api.FlexTargetAPI
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt Module for Manager injection
 * 
 * Provides singleton instances of core manager classes:
 * - AuthManager: User authentication and token lifecycle
 * - TokenRefreshQueue: Serialized token refresh with debouncing
 * - DeviceAuthManager: Device-level 2-step authentication
 */
@Module
@InstallIn(SingletonComponent::class)
object ManagerModule {
    
    /**
     * Provide TokenRefreshQueue singleton
     */
    @Singleton
    @Provides
    fun provideTokenRefreshQueue(
        authManager: AuthManager,
        api: FlexTargetAPI
    ): TokenRefreshQueue {
        return TokenRefreshQueue(authManager, api)
    }
    
    /**
     * Provide DeviceAuthManager singleton
     */
    @Singleton
    @Provides
    fun provideDeviceAuthManager(
        preferences: AppPreferences,
        api: FlexTargetAPI,
        authManager: AuthManager
    ): DeviceAuthManager {
        return DeviceAuthManager(preferences, api, authManager)
    }
}
