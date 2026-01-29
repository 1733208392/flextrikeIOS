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
import com.google.gson.Gson
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
        DrillHistoryEntity::class,
        AthleteEntity::class,
        AppAuthEntity::class
    ],
    version = 4,
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
    abstract fun athleteDao(): AthleteDao
    abstract fun appAuthDao(): AppAuthDao
    
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
                    .addCallback(DatabaseCallback(context.applicationContext, scope))
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
            private val context: Context,
            private val scope: CoroutineScope
        ) : RoomDatabase.Callback() {
            
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                // Removed sample drill seeding for clean app installation
                // INSTANCE?.let { database ->
                //     scope.launch {
                //         // Populate database with initial data from JSON
                //         populateDatabase(database, context)
                //     }
                // }
            }
        }

        /**
         * Populate database with initial data from assets/drills_config.json
         */
        private suspend fun populateDatabase(database: FlexTargetDatabase, context: Context) {
            val drillSetupDao = database.drillSetupDao()
            val targetConfigDao = database.drillTargetsConfigDao()
            
            try {
                val jsonString = context.assets.open("drills_config.json").bufferedReader().use { it.readText() }
                val gson = Gson()
                val config = gson.fromJson(jsonString, DrillsConfig::class.java)

                for (drillJson in config.drills) {
                    val drillSetup = DrillSetupEntity(
                        name = drillJson.name,
                        desc = drillJson.desc,
                        delay = drillJson.delay,
                        drillDuration = drillJson.drillDuration,
                        repeats = drillJson.repeats,
                        pause = drillJson.pause,
                        mode = drillJson.mode
                    )
                    val drillId = drillSetupDao.insertDrillSetup(drillSetup)

                    val targets = drillJson.targets.map { targetJson ->
                        DrillTargetsConfigEntity(
                            seqNo = targetJson.seqNo,
                            targetName = targetJson.targetName,
                            targetType = targetJson.targetType,
                            timeout = targetJson.timeout,
                            countedShots = targetJson.countedShots,
                            drillSetupId = drillSetup.id
                        )
                    }
                    targetConfigDao.insertTargetConfigs(targets)
                }
                println("[FlexTargetDatabase] Successfully seeded ${config.drills.size} drills from JSON")
            } catch (e: Exception) {
                println("[FlexTargetDatabase] Error seeding database: ${e.message}")
                e.printStackTrace()
            }
        }

    private data class DrillsConfig(val drills: List<DrillJson>)
    private data class DrillJson(
        val name: String,
        val desc: String,
        val delay: Double,
        val drillDuration: Double,
        val repeats: Int,
        val pause: Int = 0,
        val mode: String? = null,
        val targets: List<TargetJson>
    )
    private data class TargetJson(
        val seqNo: Int,
        val targetName: String,
        val targetType: String,
        val timeout: Double,
        val countedShots: Int
    )
        
        /**
         * Close database instance. Useful for testing.
         */
        fun closeDatabase() {
            INSTANCE?.close()
            INSTANCE = null
        }
    }
}
