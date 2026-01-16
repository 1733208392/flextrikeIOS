package com.flextarget.android.di

import android.content.Context
import androidx.work.WorkManager
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.local.dao.CompetitionDao
import com.flextarget.android.data.local.dao.DrillResultDao
import com.flextarget.android.data.local.dao.DrillSetupDao
import com.flextarget.android.data.local.dao.GamePlayDao
import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.repository.BLEMessageQueue
import com.flextarget.android.data.repository.BLERepository
import com.flextarget.android.data.repository.CompetitionRepository
import com.flextarget.android.data.repository.DrillRepository
import com.flextarget.android.data.repository.OTARepository
import com.flextarget.android.data.remote.api.FlexTargetAPI
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt Module for Repository injection
 * 
 * Provides singleton instances of all repositories:
 * - BLERepository: Bluetooth communication
 * - CompetitionRepository: Competition and game play management
 * - DrillRepository: Drill execution orchestration
 * - OTARepository: Over-the-air update management
 */
@Module
@InstallIn(SingletonComponent::class)
object RepositoryModule {
    
    /**
     * Provide BLERepository singleton
     */
    @Singleton
    @Provides
    fun provideBLERepository(
        shotDao: ShotDao
    ): BLERepository {
        return BLERepository(shotDao)
    }
    
    /**
     * Provide BLEMessageQueue singleton
     */
    @Singleton
    @Provides
    fun provideBLEMessageQueue(
        bleRepository: BLERepository
    ): BLEMessageQueue {
        return BLEMessageQueue(bleRepository)
    }
    
    /**
     * Provide CompetitionRepository singleton
     */
    @Singleton
    @Provides
    fun provideCompetitionRepository(
        api: FlexTargetAPI,
        competitionDao: CompetitionDao,
        gamePlayDao: GamePlayDao,
        authManager: AuthManager,
        deviceAuthManager: DeviceAuthManager
    ): CompetitionRepository {
        return CompetitionRepository(api, competitionDao, gamePlayDao, authManager, deviceAuthManager)
    }
    
    fun provideDrillRepository(
        drillSetupDao: DrillSetupDao,
        drillResultDao: DrillResultDao,
        bleRepository: BLERepository,
        bleMessageQueue: BLEMessageQueue
    ): DrillRepository {
        return DrillRepository(drillSetupDao, drillResultDao, bleRepository, bleMessageQueue)
    }
    
    /**
     * Provide OTARepository singleton
     */
    @Singleton
    @Provides
    fun provideOTARepository(
        api: FlexTargetAPI,
        authManager: AuthManager,
        @ApplicationContext context: Context
    ): OTARepository {
        return OTARepository(api, authManager, WorkManager.getInstance(context))
    }
}
