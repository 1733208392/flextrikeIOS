package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Data Access Object for DrillTargetsConfig operations.
 * Provides CRUD operations and queries for drill target configurations.
 */
@Dao
interface DrillTargetsConfigDao {
    
    @Query("SELECT * FROM drill_targets_config ORDER BY seqNo ASC")
    fun getAllTargetConfigs(): Flow<List<DrillTargetsConfigEntity>>
    
    @Query("SELECT * FROM drill_targets_config WHERE id = :id")
    suspend fun getTargetConfigById(id: UUID): DrillTargetsConfigEntity?
    
    @Query("SELECT * FROM drill_targets_config WHERE id = :id")
    fun getTargetConfigByIdFlow(id: UUID): Flow<DrillTargetsConfigEntity?>
    
    @Query("SELECT * FROM drill_targets_config WHERE drillSetupId = :drillSetupId ORDER BY seqNo ASC")
    fun getTargetConfigsByDrillSetupId(drillSetupId: UUID): Flow<List<DrillTargetsConfigEntity>>
    
    @Query("SELECT * FROM drill_targets_config WHERE drillSetupId = :drillSetupId ORDER BY seqNo ASC")
    suspend fun getTargetConfigsByDrillSetupIdSync(drillSetupId: UUID): List<DrillTargetsConfigEntity>
    
    @Query("SELECT * FROM drill_targets_config WHERE targetName = :targetName")
    fun getTargetConfigsByName(targetName: String): Flow<List<DrillTargetsConfigEntity>>
    
    @Query("SELECT * FROM drill_targets_config WHERE targetType = :targetType")
    fun getTargetConfigsByType(targetType: String): Flow<List<DrillTargetsConfigEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTargetConfig(targetConfig: DrillTargetsConfigEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTargetConfigs(targetConfigs: List<DrillTargetsConfigEntity>)
    
    @Update
    suspend fun updateTargetConfig(targetConfig: DrillTargetsConfigEntity)
    
    @Delete
    suspend fun deleteTargetConfig(targetConfig: DrillTargetsConfigEntity)
    
    @Query("DELETE FROM drill_targets_config WHERE id = :id")
    suspend fun deleteTargetConfigById(id: UUID)
    
    @Query("DELETE FROM drill_targets_config WHERE drillSetupId = :drillSetupId")
    suspend fun deleteTargetConfigsByDrillSetupId(drillSetupId: UUID)
    
    @Query("DELETE FROM drill_targets_config")
    suspend fun deleteAllTargetConfigs()
    
    @Query("SELECT COUNT(*) FROM drill_targets_config")
    suspend fun getTargetConfigCount(): Int
    
    @Query("SELECT COUNT(*) FROM drill_targets_config WHERE drillSetupId = :drillSetupId")
    suspend fun getTargetConfigCountByDrillSetupId(drillSetupId: UUID): Int
}
