package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillSetupWithResults
import com.flextarget.android.data.local.entity.DrillSetupWithTargets
import com.flextarget.android.data.local.entity.CompleteDrillSetup
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Data Access Object for DrillSetup operations.
 * Provides CRUD operations and queries for drill setups.
 */
@Dao
interface DrillSetupDao {
    
    @Query("SELECT * FROM drill_setup ORDER BY name ASC")
    fun getAllDrillSetups(): Flow<List<DrillSetupEntity>>
    
    @Query("SELECT * FROM drill_setup WHERE id = :id")
    suspend fun getDrillSetupById(id: UUID): DrillSetupEntity?
    
    @Query("SELECT * FROM drill_setup WHERE id = :id")
    fun getDrillSetupByIdFlow(id: UUID): Flow<DrillSetupEntity?>
    
    @Transaction
    @Query("SELECT * FROM drill_setup WHERE id = :id")
    suspend fun getDrillSetupWithTargets(id: UUID): DrillSetupWithTargets?
    
    @Transaction
    @Query("SELECT * FROM drill_setup WHERE id = :id")
    suspend fun getDrillSetupWithResults(id: UUID): DrillSetupWithResults?
    
    @Transaction
    @Query("SELECT * FROM drill_setup WHERE id = :id")
    suspend fun getCompleteDrillSetup(id: UUID): CompleteDrillSetup?
    
    @Transaction
    @Query("SELECT * FROM drill_setup ORDER BY name ASC")
    fun getAllDrillSetupsWithTargets(): Flow<List<DrillSetupWithTargets>>
    
    @Query("SELECT * FROM drill_setup WHERE name LIKE '%' || :searchQuery || '%'")
    fun searchDrillSetups(searchQuery: String): Flow<List<DrillSetupEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDrillSetup(drillSetup: DrillSetupEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDrillSetups(drillSetups: List<DrillSetupEntity>)
    
    @Update
    suspend fun updateDrillSetup(drillSetup: DrillSetupEntity)
    
    @Delete
    suspend fun deleteDrillSetup(drillSetup: DrillSetupEntity)
    
    @Query("DELETE FROM drill_setup WHERE id = :id")
    suspend fun deleteDrillSetupById(id: UUID)
    
    @Query("DELETE FROM drill_setup")
    suspend fun deleteAllDrillSetups()
    
    @Query("SELECT COUNT(*) FROM drill_setup")
    suspend fun getDrillSetupCount(): Int
}
