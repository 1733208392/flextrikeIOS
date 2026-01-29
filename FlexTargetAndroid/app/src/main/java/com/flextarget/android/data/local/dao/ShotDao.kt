package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.ShotEntity
import kotlinx.coroutines.flow.Flow
import java.util.Date
import java.util.UUID

/**
 * Data Access Object for Shot operations.
 * Provides CRUD operations and queries for individual shots.
 */
@Dao
interface ShotDao {
    
    @Query("SELECT * FROM shot ORDER BY timestamp DESC")
    fun getAllShots(): Flow<List<ShotEntity>>
    
    @Query("SELECT * FROM shot WHERE id = :id")
    suspend fun getShotById(id: UUID): ShotEntity?
    
    @Query("SELECT * FROM shot WHERE id = :id")
    fun getShotByIdFlow(id: UUID): Flow<ShotEntity?>
    
    @Query("SELECT * FROM shot WHERE drillResultId = :drillResultId ORDER BY timestamp ASC")
    fun getShotsByDrillResultId(drillResultId: UUID): Flow<List<ShotEntity>>
    
    @Query("SELECT * FROM shot WHERE drillResultId = :drillResultId ORDER BY timestamp ASC")
    suspend fun getShotsByDrillResultIdSync(drillResultId: UUID): List<ShotEntity>
    
    @Query("SELECT * FROM shot WHERE timestamp >= :startDate AND timestamp <= :endDate ORDER BY timestamp DESC")
    fun getShotsByDateRange(startDate: Date, endDate: Date): Flow<List<ShotEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertShot(shot: ShotEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertShots(shots: List<ShotEntity>)
    
    @Update
    suspend fun updateShot(shot: ShotEntity)
    
    @Delete
    suspend fun deleteShot(shot: ShotEntity)
    
    @Query("DELETE FROM shot WHERE id = :id")
    suspend fun deleteShotById(id: UUID)
    
    @Query("DELETE FROM shot WHERE drillResultId = :drillResultId")
    suspend fun deleteShotsByDrillResultId(drillResultId: UUID)
    
    @Query("DELETE FROM shot")
    suspend fun deleteAllShots()
    
    @Query("SELECT COUNT(*) FROM shot")
    suspend fun getShotCount(): Int
    
    @Query("SELECT COUNT(*) FROM shot WHERE drillResultId = :drillResultId")
    suspend fun getShotCountByDrillResultId(drillResultId: UUID): Int
}
