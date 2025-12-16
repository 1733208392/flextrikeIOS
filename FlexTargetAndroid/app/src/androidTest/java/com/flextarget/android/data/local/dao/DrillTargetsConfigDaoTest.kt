package com.flextarget.android.data.local.dao

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import com.google.common.truth.Truth.assertThat

@RunWith(AndroidJUnit4::class)
class DrillTargetsConfigDaoTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private lateinit var database: FlexTargetDatabase
    private lateinit var targetConfigDao: DrillTargetsConfigDao
    private lateinit var drillSetupDao: DrillSetupDao
    
    @Before
    fun setup() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FlexTargetDatabase::class.java
        )
            .allowMainThreadQueries()
            .build()
        
        targetConfigDao = database.drillTargetsConfigDao()
        drillSetupDao = database.drillSetupDao()
    }
    
    @After
    fun tearDown() {
        database.close()
    }
    
    @Test
    fun insertTargetConfig_andGetById_returnsCorrectConfig() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Test Drill")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        val targetConfig = DrillTargetsConfigEntity(
            id = UUID.randomUUID(),
            seqNo = 1,
            targetName = "Target Alpha",
            targetType = "IPSC",
            timeout = 5.0,
            countedShots = 2,
            drillSetupId = drillSetup.id
        )
        
        // When
        targetConfigDao.insertTargetConfig(targetConfig)
        val retrieved = targetConfigDao.getTargetConfigById(targetConfig.id)
        
        // Then
        assertThat(retrieved).isNotNull()
        assertThat(retrieved?.targetName).isEqualTo("Target Alpha")
        assertThat(retrieved?.targetType).isEqualTo("IPSC")
        assertThat(retrieved?.seqNo).isEqualTo(1)
        assertThat(retrieved?.timeout).isEqualTo(5.0)
        assertThat(retrieved?.countedShots).isEqualTo(2)
    }
    
    @Test
    fun getTargetConfigsByDrillSetupId_returnsInSequenceOrder() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Multi-target Drill")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(
                drillSetupId = drillSetup.id,
                seqNo = 2,
                targetName = "Second Target"
            )
        )
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(
                drillSetupId = drillSetup.id,
                seqNo = 1,
                targetName = "First Target"
            )
        )
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(
                drillSetupId = drillSetup.id,
                seqNo = 3,
                targetName = "Third Target"
            )
        )
        
        // When
        val configs = targetConfigDao.getTargetConfigsByDrillSetupId(drillSetup.id).first()
        
        // Then
        assertThat(configs).hasSize(3)
        assertThat(configs[0].targetName).isEqualTo("First Target")
        assertThat(configs[1].targetName).isEqualTo("Second Target")
        assertThat(configs[2].targetName).isEqualTo("Third Target")
    }
    
    @Test
    fun getTargetConfigsByType_returnsFilteredResults() = runTest {
        // Given
        val drillSetup = DrillSetupEntity()
        drillSetupDao.insertDrillSetup(drillSetup)
        
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(targetType = "IPSC", drillSetupId = drillSetup.id)
        )
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(targetType = "Popper", drillSetupId = drillSetup.id)
        )
        targetConfigDao.insertTargetConfig(
            DrillTargetsConfigEntity(targetType = "IPSC", drillSetupId = drillSetup.id)
        )
        
        // When
        val ipscTargets = targetConfigDao.getTargetConfigsByType("IPSC").first()
        
        // Then
        assertThat(ipscTargets).hasSize(2)
    }
    
    @Test
    fun deleteTargetConfig_removesFromDatabase() = runTest {
        // Given
        val targetConfig = DrillTargetsConfigEntity(targetName = "To Delete")
        targetConfigDao.insertTargetConfig(targetConfig)
        
        // When
        targetConfigDao.deleteTargetConfig(targetConfig)
        
        val retrieved = targetConfigDao.getTargetConfigById(targetConfig.id)
        
        // Then
        assertThat(retrieved).isNull()
    }
    
    @Test
    fun getTargetConfigCount_returnsCorrectCount() = runTest {
        // Given
        targetConfigDao.insertTargetConfig(DrillTargetsConfigEntity())
        targetConfigDao.insertTargetConfig(DrillTargetsConfigEntity())
        
        // When
        val count = targetConfigDao.getTargetConfigCount()
        
        // Then
        assertThat(count).isEqualTo(2)
    }
}
