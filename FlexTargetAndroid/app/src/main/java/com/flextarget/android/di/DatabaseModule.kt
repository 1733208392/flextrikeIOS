package com.flextarget.android.di

import android.content.Context
import androidx.room.Room
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.dao.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module providing Room database dependencies
 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    private const val DATABASE_NAME = "flex_target_database_v3"
    
    /**
     * Provide FlexTargetDatabase instance
     */
    @Singleton
    @Provides
    fun provideDatabase(
        @ApplicationContext context: Context
    ): FlexTargetDatabase {
        return Room.databaseBuilder(
            context,
            FlexTargetDatabase::class.java,
            DATABASE_NAME
        )
            .fallbackToDestructiveMigration() // For development; use explicit migrations in production
            .build()
    }
    
    /**
     * Provide DrillSetupDao
     */
    @Singleton
    @Provides
    fun provideDrillSetupDao(database: FlexTargetDatabase): DrillSetupDao {
        return database.drillSetupDao()
    }
    
    /**
     * Provide DrillResultDao
     */
    @Singleton
    @Provides
    fun provideDrillResultDao(database: FlexTargetDatabase): DrillResultDao {
        return database.drillResultDao()
    }
    
    /**
     * Provide ShotDao
     */
    @Singleton
    @Provides
    fun provideShotDao(database: FlexTargetDatabase): ShotDao {
        return database.shotDao()
    }
    
    /**
     * Provide DrillTargetsConfigDao
     */
    @Singleton
    @Provides
    fun provideDrillTargetsConfigDao(database: FlexTargetDatabase): DrillTargetsConfigDao {
        return database.drillTargetsConfigDao()
    }
    
    /**
     * Provide UserDao
     */
    @Singleton
    @Provides
    fun provideUserDao(database: FlexTargetDatabase): UserDao {
        return database.userDao()
    }
    
    /**
     * Provide CompetitionDao
     */
    @Singleton
    @Provides
    fun provideCompetitionDao(database: FlexTargetDatabase): CompetitionDao {
        return database.competitionDao()
    }
    
    /**
     * Provide GamePlayDao
     */
    @Singleton
    @Provides
    fun provideGamePlayDao(database: FlexTargetDatabase): GamePlayDao {
        return database.gamePlayDao()
    }
    
    /**
     * Provide DrillHistoryDao
     */
    @Singleton
    @Provides
    fun provideDrillHistoryDao(database: FlexTargetDatabase): DrillHistoryDao {
        return database.drillHistoryDao()
    }
}
