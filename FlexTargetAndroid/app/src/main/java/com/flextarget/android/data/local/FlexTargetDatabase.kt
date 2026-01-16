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
import java.util.Date
import java.util.UUID

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
        DrillTargetsConfigEntity::class,
        UserEntity::class,
        CompetitionEntity::class,
        GamePlayEntity::class,
        DrillHistoryEntity::class
    ],
    version = 3,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class FlexTargetDatabase : RoomDatabase() {
    
    abstract fun drillSetupDao(): DrillSetupDao
    abstract fun drillResultDao(): DrillResultDao
    abstract fun shotDao(): ShotDao
    abstract fun drillTargetsConfigDao(): DrillTargetsConfigDao
    abstract fun userDao(): UserDao
    abstract fun competitionDao(): CompetitionDao
    abstract fun gamePlayDao(): GamePlayDao
    abstract fun drillHistoryDao(): DrillHistoryDao
    
    companion object {
        @Volatile
        private var INSTANCE: FlexTargetDatabase? = null
        
        private const val DATABASE_NAME = "flex_target_database_v3"
        
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
            val drillResultDao = database.drillResultDao()
            val shotDao = database.shotDao()
            
            // Example: Add a sample drill setup (can be removed in production)
            // Uncomment to add seed data:
            val sampleDrill = DrillSetupEntity(
                name = "Sample Drill",
                desc = "A sample drill for testing",
                delay = 3.0,
                drillDuration = 30.0,
                repeats = 3,
                pause = 10
            )
            val drillId = drillSetupDao.insertDrillSetup(sampleDrill)
            
            // Add some sample targets
            val target1 = DrillTargetsConfigEntity(
                seqNo = 1,
                targetName = "Target 1",
                targetType = "popper",
                timeout = 5.0,
                countedShots = 1,
                drillSetupId = sampleDrill.id
            )
            val target2 = DrillTargetsConfigEntity(
                seqNo = 2,
                targetName = "Target 2", 
                targetType = "popper",
                timeout = 5.0,
                countedShots = 1,
                drillSetupId = sampleDrill.id
            )
            targetConfigDao.insertTargetConfigs(listOf(target1, target2))
            
            // Add sample drill results with shots
            val drillResult = DrillResultEntity(
                drillSetupId = sampleDrill.id,
                date = Date(System.currentTimeMillis()),
                totalTime = 15.5,
                sessionId = UUID.randomUUID()
            )
            drillResultDao.insertDrillResult(drillResult)
            val resultId = drillResult.id // Use the entity's UUID, not the returned Long
            
            // Add some sample shots
            val shots = listOf(
                ShotEntity(
                    drillResultId = resultId,
                    timestamp = Date(System.currentTimeMillis()),
                    data = """{"target":"popper","content":{"command":"shot","hitArea":"C","hitPosition":{"x":360.0,"y":640.0},"rotationAngle":0.0,"targetType":"popper","timeDiff":0.4,"device":"device_popper"},"type":"shot","action":"hit","device":"device_popper"}"""
                ),
                ShotEntity(
                    drillResultId = resultId,
                    timestamp = Date(System.currentTimeMillis() + 1000),
                    data = """{"target":"popper","content":{"command":"shot","hitArea":"C","hitPosition":{"x":367.0,"y":649.0},"rotationAngle":0.0,"targetType":"popper","timeDiff":0.55,"device":"device_popper"},"type":"shot","action":"hit","device":"device_popper"}"""
                ),
                ShotEntity(
                    drillResultId = resultId,
                    timestamp = Date(System.currentTimeMillis() + 2000),
                    data = """{"target":"popper","content":{"command":"shot","hitArea":"B","hitPosition":{"x":374.0,"y":658.0},"rotationAngle":0.0,"targetType":"popper","timeDiff":0.7,"device":"device_popper"},"type":"shot","action":"hit","device":"device_popper"}"""
                )
            )
            shotDao.insertShots(shots)
            
            // Add another drill result for testing multiple sessions
            val drillResult2 = DrillResultEntity(
                drillSetupId = sampleDrill.id,
                date = Date(System.currentTimeMillis() - 86400000), // Yesterday
                totalTime = 12.3,
                sessionId = UUID.randomUUID()
            )
            drillResultDao.insertDrillResult(drillResult2)
            val resultId2 = drillResult2.id // Use the entity's UUID, not the returned Long
            
            val shots2 = listOf(
                ShotEntity(
                    drillResultId = resultId2,
                    timestamp = Date(System.currentTimeMillis() - 86400000),
                    data = """{"target":"popper","content":{"command":"shot","hitArea":"A","hitPosition":{"x":350.0,"y":630.0},"rotationAngle":0.0,"targetType":"popper","timeDiff":0.3,"device":"device_popper"},"type":"shot","action":"hit","device":"device_popper"}"""
                ),
                ShotEntity(
                    drillResultId = resultId2,
                    timestamp = Date(System.currentTimeMillis() - 86400000 + 800),
                    data = """{"target":"popper","content":{"command":"shot","hitArea":"C","hitPosition":{"x":365.0,"y":645.0},"rotationAngle":0.0,"targetType":"popper","timeDiff":0.5,"device":"device_popper"},"type":"shot","action":"hit","device":"device_popper"}"""
                )
            )
            shotDao.insertShots(shots2)
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
