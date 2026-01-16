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
 * Hilt module providing authentication dependencies
 */
@Module
@InstallIn(SingletonComponent::class)
object AuthModule {
    
    /**
     * Provide TokenRefreshQueue
     */
    @Singleton
    @Provides
    fun provideTokenRefreshQueue(
        authManager: AuthManager,
        userApiService: FlexTargetAPI
    ): TokenRefreshQueue {
        return TokenRefreshQueue(authManager, userApiService)
    }
    
    /**
     * Provide AuthManager
     */
    @Singleton
    @Provides
    fun provideAuthManager(
        preferences: AppPreferences,
        userApiService: FlexTargetAPI,
        tokenRefreshQueue: TokenRefreshQueue
    ): AuthManager {
        return AuthManager(preferences, userApiService, tokenRefreshQueue)
    }
    
    /**
     * Provide DeviceAuthManager
     */
    @Singleton
    @Provides
    fun provideDeviceAuthManager(
        preferences: AppPreferences,
        userApiService: FlexTargetAPI,
        authManager: AuthManager
    ): DeviceAuthManager {
        return DeviceAuthManager(preferences, userApiService, authManager)
    }
}
