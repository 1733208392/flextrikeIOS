package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.*
import com.flextarget.android.data.local.entity.*
import kotlinx.coroutines.flow.Flow
import java.util.Date
import java.util.UUID

/**
 * Repository for drill setup operations.
 * Provides a clean API for accessing drill setup data.
 * Mirrors the functionality of iOS DrillRepository.
 */
class DrillSetupRepository(
    private val drillSetupDao: DrillSetupDao,
    private val targetConfigDao: DrillTargetsConfigDao
) {
    
    // Observe all drill setups
    val allDrillSetups: Flow<List<DrillSetupEntity>> = drillSetupDao.getAllDrillSetups()
    
    // Observe all drill setups with targets
    val allDrillSetupsWithTargets: Flow<List<DrillSetupWithTargets>> = 
        drillSetupDao.getAllDrillSetupsWithTargets()
    
    // Get single drill setup
    suspend fun getDrillSetupById(id: UUID): DrillSetupEntity? {
        return drillSetupDao.getDrillSetupById(id)
    }
    
    // Observe single drill setup
    fun observeDrillSetupById(id: UUID): Flow<DrillSetupEntity?> {
        return drillSetupDao.getDrillSetupByIdFlow(id)
    }
    
    // Get drill setup with targets
    suspend fun getDrillSetupWithTargets(id: UUID): DrillSetupWithTargets? {
        return drillSetupDao.getDrillSetupWithTargets(id)
    }
    
    // Get drill setup with results
    suspend fun getDrillSetupWithResults(id: UUID): DrillSetupWithResults? {
        return drillSetupDao.getDrillSetupWithResults(id)
    }
    
    // Get complete drill setup
    suspend fun getCompleteDrillSetup(id: UUID): CompleteDrillSetup? {
        return drillSetupDao.getCompleteDrillSetup(id)
    }
    
    // Search drill setups
    fun searchDrillSetups(query: String): Flow<List<DrillSetupEntity>> {
        return drillSetupDao.searchDrillSetups(query)
    }
    
    // Insert drill setup
    suspend fun insertDrillSetup(drillSetup: DrillSetupEntity): Long {
        return drillSetupDao.insertDrillSetup(drillSetup)
    }
    
    // Insert drill setup with targets (transaction)
    suspend fun insertDrillSetupWithTargets(
        drillSetup: DrillSetupEntity,
        targets: List<DrillTargetsConfigEntity>
    ) {
        drillSetupDao.insertDrillSetup(drillSetup)
        val targetsWithSetupId = targets.map { it.copy(drillSetupId = drillSetup.id) }
        targetConfigDao.insertTargetConfigs(targetsWithSetupId)
    }
    
    // Update drill setup
    suspend fun updateDrillSetup(drillSetup: DrillSetupEntity) {
        drillSetupDao.updateDrillSetup(drillSetup)
    }
    
    // Delete drill setup
    suspend fun deleteDrillSetup(drillSetup: DrillSetupEntity) {
        drillSetupDao.deleteDrillSetup(drillSetup)
    }
    
    // Delete drill setup by ID
    suspend fun deleteDrillSetupById(id: UUID) {
        drillSetupDao.deleteDrillSetupById(id)
    }
    
    // Get count
    suspend fun getDrillSetupCount(): Int {
        return drillSetupDao.getDrillSetupCount()
    }
}
