package com.flextarget.android.di

import android.content.Context
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.TokenRefreshQueue
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.interceptor.AuthInterceptor
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import javax.inject.Singleton

/**
 * Hilt module providing network dependencies (Retrofit, OkHttp, etc.)
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    private const val BASE_URL = "https://etarget.topoint-archery.cn"
    
    /**
     * Provide OkHttpClient with interceptors
     */
    @Singleton
    @Provides
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor
    ): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
        
        // Add logging interceptor for debug builds
        try {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        } catch (e: Exception) {
            // HttpLoggingInterceptor might not be available in release builds
        }
        
        return builder.build()
    }
    
    /**
     * Provide Retrofit instance
     */
    @Singleton
    @Provides
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }
    
    /**
     * Provide FlexTargetAPI service
     */
    @Singleton
    @Provides
    fun provideFlexTargetAPI(retrofit: Retrofit): FlexTargetAPI {
        return retrofit.create(FlexTargetAPI::class.java)
    }
    
    /**
     * Provide AuthInterceptor
     */
    @Singleton
    @Provides
    fun provideAuthInterceptor(
        authManager: AuthManager,
        tokenRefreshQueue: TokenRefreshQueue
    ): AuthInterceptor {
        return AuthInterceptor(authManager, tokenRefreshQueue)
    }
}
