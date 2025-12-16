package com.flextarget.android.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.sqlite.db.SupportSQLiteDatabase
import com.flextarget.android.data.local.converter.Converters
import com.flextarget.android.data.local.dao.*
import com.flextarget.android.data.local.entity.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Room database for FlexTarget application.
 * Migrated from iOS CoreData DrillDataModel.
 * 
 * This database contains:
 * - DrillSetup: Drill configurations
 * - DrillResult: Execution results
 * - Shot: Individual shots within a result
 * - DrillTargetsConfig: Target configurations for drills
 */
@Database(
    entities = [
        DrillSetupEntity::class,
        DrillResultEntity::class,
        ShotEntity::class,
        DrillTargetsConfigEntity::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class FlexTargetDatabase : RoomDatabase() {
    
    abstract fun drillSetupDao(): DrillSetupDao
    abstract fun drillResultDao(): DrillResultDao
    abstract fun shotDao(): ShotDao
    abstract fun drillTargetsConfigDao(): DrillTargetsConfigDao
    
    companion object {
        @Volatile
        private var INSTANCE: FlexTargetDatabase? = null
        
        private const val DATABASE_NAME = "flex_target_database"
        
        fun getDatabase(
            context: Context,
            scope: CoroutineScope = CoroutineScope(Dispatchers.IO)
        ): FlexTargetDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    FlexTargetDatabase::class.java,
                    DATABASE_NAME
                )
                    .addCallback(DatabaseCallback(scope))
                    .fallbackToDestructiveMigration() // For development; remove in production
                    .build()
                INSTANCE = instance
                instance
            }
        }
        
        /**
         * Callback to initialize database with seed data if needed.
         */
        private class DatabaseCallback(
            private val scope: CoroutineScope
        ) : RoomDatabase.Callback() {
            
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                INSTANCE?.let { database ->
                    scope.launch {
                        // Populate database with initial data if needed
                        // This mirrors the iOS PersistenceController initialization
                        populateDatabase(database)
                    }
                }
            }
        }
        
        /**
         * Populate database with initial data.
         * Can be used for seed data similar to iOS UITestDataSeeder.
         */
        private suspend fun populateDatabase(database: FlexTargetDatabase) {
            // Add initial data if needed
            // This is where you would add seed data similar to the iOS version
            val drillSetupDao = database.drillSetupDao()
            val targetConfigDao = database.drillTargetsConfigDao()
            
            // Example: Add a sample drill setup (can be removed in production)
            // Uncomment to add seed data:
            /*
            val sampleDrill = DrillSetupEntity(
                name = "Sample Drill",
                desc = "A sample drill for testing",
                delay = 3.0,
                drillDuration = 30.0,
                repeats = 3,
                pause = 10
            )
            drillSetupDao.insertDrillSetup(sampleDrill)
            */
        }
        
        /**
         * Close database instance. Useful for testing.
         */
        fun closeDatabase() {
            INSTANCE?.close()
            INSTANCE = null
        }
    }
}
