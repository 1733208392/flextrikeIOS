package com.flextarget.android.data.repository

import android.content.Context
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.dao.DrillResultDao
import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.local.entity.ShotEntity
import kotlinx.coroutines.flow.Flow
import java.util.Date
import java.util.UUID

/**
 * Repository for drill result operations.
 * Provides a clean API for accessing drill execution results.
 * Mirrors the functionality of iOS DrillRecordStorage.
 */
class DrillResultRepository(
    private val drillResultDao: DrillResultDao,
    private val shotDao: ShotDao
) {
    
    companion object {
        @Volatile
        private var INSTANCE: DrillResultRepository? = null
        
        fun getInstance(context: Context): DrillResultRepository {
            return INSTANCE ?: synchronized(this) {
                val database = FlexTargetDatabase.getDatabase(context)
                val instance = DrillResultRepository(
                    database.drillResultDao(),
                    database.shotDao()
                )
                INSTANCE = instance
                instance
            }
        }
    }
    
    // Observe all drill results
    val allDrillResults: Flow<List<DrillResultEntity>> = drillResultDao.getAllDrillResults()
    
    // Observe all drill results with shots
    val allDrillResultsWithShots: Flow<List<DrillResultWithShots>> = 
        drillResultDao.getAllDrillResultsWithShots()
    
    // Get single drill result
    suspend fun getDrillResultById(id: UUID): DrillResultEntity? {
        return drillResultDao.getDrillResultById(id)
    }
    
    // Observe single drill result
    fun observeDrillResultById(id: UUID): Flow<DrillResultEntity?> {
        return drillResultDao.getDrillResultByIdFlow(id)
    }
    
    // Get drill result with shots
    suspend fun getDrillResultWithShots(id: UUID): DrillResultWithShots? {
        return drillResultDao.getDrillResultWithShots(id)
    }
    
    // Observe drill result with shots
    fun observeDrillResultWithShots(id: UUID): Flow<DrillResultWithShots?> {
        return drillResultDao.getDrillResultWithShotsFlow(id)
    }
    
    // Get results by drill setup ID
    fun getDrillResultsBySetupId(drillSetupId: UUID): Flow<List<DrillResultEntity>> {
        return drillResultDao.getDrillResultsBySetupId(drillSetupId)
    }
    
    // Get results with shots by drill setup ID
    fun getDrillResultsWithShotsBySetupId(drillSetupId: UUID): Flow<List<DrillResultWithShots>> {
        return drillResultDao.getDrillResultsWithShotsBySetupId(drillSetupId)
    }
    
    // Get results by session ID
    fun getDrillResultsBySessionId(sessionId: UUID): Flow<List<DrillResultEntity>> {
        return drillResultDao.getDrillResultsBySessionId(sessionId)
    }
    
    // Get results by date range
    fun getDrillResultsByDateRange(startDate: Date, endDate: Date): Flow<List<DrillResultEntity>> {
        return drillResultDao.getDrillResultsByDateRange(startDate, endDate)
    }
    
    // Insert drill result
    suspend fun insertDrillResult(drillResult: DrillResultEntity): Long {
        return drillResultDao.insertDrillResult(drillResult)
    }
    
    // Insert drill result with shots (transaction)
    suspend fun insertDrillResultWithShots(
        drillResult: DrillResultEntity,
        shots: List<ShotEntity>
    ) {
        drillResultDao.insertDrillResult(drillResult)
        val shotsWithResultId = shots.map { it.copy(drillResultId = drillResult.id) }
        shotDao.insertShots(shotsWithResultId)
    }
    
    // Update drill result
    suspend fun updateDrillResult(drillResult: DrillResultEntity) {
        drillResultDao.updateDrillResult(drillResult)
    }
    
    // Delete drill result
    suspend fun deleteDrillResult(drillResult: DrillResultEntity) {
        drillResultDao.deleteDrillResult(drillResult)
    }
    
    // Delete drill result by ID
    suspend fun deleteDrillResultById(id: UUID) {
        drillResultDao.deleteDrillResultById(id)
    }
    
    // Get count
    suspend fun getDrillResultCount(): Int {
        return drillResultDao.getDrillResultCount()
    }
    
    // Get count by setup ID
    suspend fun getDrillResultCountBySetupId(drillSetupId: UUID): Int {
        return drillResultDao.getDrillResultCountBySetupId(drillSetupId)
    }
}
