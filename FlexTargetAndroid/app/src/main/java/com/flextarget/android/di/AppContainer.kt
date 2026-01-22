package com.flextarget.android.di

import android.content.Context
import androidx.room.Room
import androidx.work.WorkManager
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.auth.TokenRefreshQueue
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.repository.*
import com.flextarget.android.ui.viewmodel.AuthViewModel
import com.flextarget.android.ui.viewmodel.BLEViewModel
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel
import com.flextarget.android.ui.viewmodel.OTAViewModel
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

/**
 * Simple dependency injection container to replace Hilt
 */
object AppContainer {

    private lateinit var applicationContext: Context

    // Network
    private val loggingInterceptor by lazy {
        HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
    }

    private val okHttpClient by lazy {
        OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    private val retrofit by lazy {
        Retrofit.Builder()
            .baseUrl("https://etarget.topoint-archery.cn/") // Replace with actual base URL
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    private val flexTargetAPI by lazy {
        retrofit.create(FlexTargetAPI::class.java)
    }

    // Database
    private val database by lazy {
        Room.databaseBuilder(
            applicationContext,
            FlexTargetDatabase::class.java,
            "flex_target_database_v3"
        )
            .fallbackToDestructiveMigration()
            .build()
    }

    // DAOs
    private val drillSetupDao by lazy { database.drillSetupDao() }
    private val drillResultDao by lazy { database.drillResultDao() }
    private val competitionDao by lazy { database.competitionDao() }
    private val gamePlayDao by lazy { database.gamePlayDao() }
    private val shotDao by lazy { database.shotDao() }
    private val athleteDao by lazy { database.athleteDao() }

    // Preferences
    private val appPreferences by lazy { AppPreferences(applicationContext) }

    // Auth
    private val authManager by lazy {
        AuthManager(
            preferences = appPreferences,
            userApiService = flexTargetAPI,
            tokenRefreshQueue = null
        )
    }
    private val tokenRefreshQueue by lazy {
        TokenRefreshQueue(
            authManager = authManager,
            userApiService = flexTargetAPI
        )
    }
    private val deviceAuthManager by lazy { 
        DeviceAuthManager(
            preferences = appPreferences,
            userApiService = flexTargetAPI,
            authManager = authManager
        )
    }

    // WorkManager
    private val workManager by lazy { WorkManager.getInstance(applicationContext) }

    // Repositories
    private val bleRepository by lazy { BLERepository(shotDao) }
    private val bleMessageQueue by lazy { BLEMessageQueue(bleRepository) }
    private val drillRepository by lazy {
        DrillRepository(drillSetupDao, drillResultDao, bleRepository, bleMessageQueue)
    }
    private val competitionRepository by lazy {
        CompetitionRepository(
            api = flexTargetAPI,
            competitionDao = competitionDao,
            gamePlayDao = gamePlayDao,
            authManager = authManager,
            deviceAuthManager = deviceAuthManager
        )
    }
    private val otaRepository by lazy {
        OTARepository(
            api = flexTargetAPI,
            authManager = authManager,
            workManager = workManager
        )
    }
    private val athleteRepository by lazy { AthleteRepository(athleteDao) }

    // ViewModels
    val authViewModel by lazy {
        authManager.setTokenRefreshQueue(tokenRefreshQueue)
        AuthViewModel(authManager, deviceAuthManager)
    }

    val drillViewModel by lazy {
        DrillViewModel(drillRepository)
    }

    val bleViewModel by lazy {
        BLEViewModel(bleRepository)
    }

    val competitionViewModel by lazy {
        CompetitionViewModel(competitionRepository, athleteRepository)
    }

    val otaViewModel by lazy {
        OTAViewModel(otaRepository)
    }

    fun initialize(context: Context) {
        applicationContext = context.applicationContext
    }
}