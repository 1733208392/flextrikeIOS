package com.flextarget.android.di

import android.content.Context
import com.flextarget.android.data.local.preferences.AppPreferences
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module providing preferences/storage dependencies
 */
@Module
@InstallIn(SingletonComponent::class)
object PreferencesModule {
    
    /**
     * Provide AppPreferences (encrypted shared preferences)
     */
    @Singleton
    @Provides
    fun provideAppPreferences(
        @ApplicationContext context: Context
    ): AppPreferences {
        return AppPreferences(context)
    }
}
