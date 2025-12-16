package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillResultWithShots
import kotlinx.coroutines.flow.Flow
import java.util.Date
import java.util.UUID

/**
 * Data Access Object for DrillResult operations.
 * Provides CRUD operations and queries for drill execution results.
 */
@Dao
interface DrillResultDao {
    
    @Query("SELECT * FROM drill_result ORDER BY date DESC")
    fun getAllDrillResults(): Flow<List<DrillResultEntity>>
    
    @Query("SELECT * FROM drill_result WHERE id = :id")
    suspend fun getDrillResultById(id: UUID): DrillResultEntity?
    
    @Query("SELECT * FROM drill_result WHERE id = :id")
    fun getDrillResultByIdFlow(id: UUID): Flow<DrillResultEntity?>
    
    @Transaction
    @Query("SELECT * FROM drill_result WHERE id = :id")
    suspend fun getDrillResultWithShots(id: UUID): DrillResultWithShots?
    
    @Transaction
    @Query("SELECT * FROM drill_result WHERE id = :id")
    fun getDrillResultWithShotsFlow(id: UUID): Flow<DrillResultWithShots?>
    
    @Transaction
    @Query("SELECT * FROM drill_result ORDER BY date DESC")
    fun getAllDrillResultsWithShots(): Flow<List<DrillResultWithShots>>
    
    @Query("SELECT * FROM drill_result WHERE drillSetupId = :drillSetupId ORDER BY date DESC")
    fun getDrillResultsBySetupId(drillSetupId: UUID): Flow<List<DrillResultEntity>>
    
    @Transaction
    @Query("SELECT * FROM drill_result WHERE drillSetupId = :drillSetupId ORDER BY date DESC")
    fun getDrillResultsWithShotsBySetupId(drillSetupId: UUID): Flow<List<DrillResultWithShots>>
    
    @Query("SELECT * FROM drill_result WHERE sessionId = :sessionId ORDER BY date DESC")
    fun getDrillResultsBySessionId(sessionId: UUID): Flow<List<DrillResultEntity>>
    
    @Query("SELECT * FROM drill_result WHERE date >= :startDate AND date <= :endDate ORDER BY date DESC")
    fun getDrillResultsByDateRange(startDate: Date, endDate: Date): Flow<List<DrillResultEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDrillResult(drillResult: DrillResultEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDrillResults(drillResults: List<DrillResultEntity>)
    
    @Update
    suspend fun updateDrillResult(drillResult: DrillResultEntity)
    
    @Delete
    suspend fun deleteDrillResult(drillResult: DrillResultEntity)
    
    @Query("DELETE FROM drill_result WHERE id = :id")
    suspend fun deleteDrillResultById(id: UUID)
    
    @Query("DELETE FROM drill_result WHERE drillSetupId = :drillSetupId")
    suspend fun deleteDrillResultsBySetupId(drillSetupId: UUID)
    
    @Query("DELETE FROM drill_result")
    suspend fun deleteAllDrillResults()
    
    @Query("SELECT COUNT(*) FROM drill_result")
    suspend fun getDrillResultCount(): Int
    
    @Query("SELECT COUNT(*) FROM drill_result WHERE drillSetupId = :drillSetupId")
    suspend fun getDrillResultCountBySetupId(drillSetupId: UUID): Int
}
