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
class DrillSetupDaoTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private lateinit var database: FlexTargetDatabase
    private lateinit var drillSetupDao: DrillSetupDao
    private lateinit var targetConfigDao: DrillTargetsConfigDao
    
    @Before
    fun setup() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FlexTargetDatabase::class.java
        )
            .allowMainThreadQueries()
            .build()
        
        drillSetupDao = database.drillSetupDao()
        targetConfigDao = database.drillTargetsConfigDao()
    }
    
    @After
    fun tearDown() {
        database.close()
    }
    
    @Test
    fun insertDrillSetup_andGetById_returnsCorrectDrill() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(
            id = UUID.randomUUID(),
            name = "Test Drill",
            desc = "Test Description",
            delay = 3.0,
            drillDuration = 30.0,
            repeats = 3,
            pause = 10
        )
        
        // When
        drillSetupDao.insertDrillSetup(drillSetup)
        val retrieved = drillSetupDao.getDrillSetupById(drillSetup.id)
        
        // Then
        assertThat(retrieved).isNotNull()
        assertThat(retrieved?.name).isEqualTo("Test Drill")
        assertThat(retrieved?.desc).isEqualTo("Test Description")
        assertThat(retrieved?.delay).isEqualTo(3.0)
        assertThat(retrieved?.drillDuration).isEqualTo(30.0)
        assertThat(retrieved?.repeats).isEqualTo(3)
        assertThat(retrieved?.pause).isEqualTo(10)
    }
    
    @Test
    fun getAllDrillSetups_returnsAllDrills() = runTest {
        // Given
        val drill1 = DrillSetupEntity(name = "Drill A", delay = 1.0)
        val drill2 = DrillSetupEntity(name = "Drill B", delay = 2.0)
        val drill3 = DrillSetupEntity(name = "Drill C", delay = 3.0)
        
        // When
        drillSetupDao.insertDrillSetup(drill1)
        drillSetupDao.insertDrillSetup(drill2)
        drillSetupDao.insertDrillSetup(drill3)
        
        val allDrills = drillSetupDao.getAllDrillSetups().first()
        
        // Then
        assertThat(allDrills).hasSize(3)
        assertThat(allDrills.map { it.name }).containsExactly("Drill A", "Drill B", "Drill C")
    }
    
    @Test
    fun updateDrillSetup_updatesCorrectly() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Original Name", desc = "Original Desc")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        // When
        val updated = drillSetup.copy(name = "Updated Name", desc = "Updated Desc")
        drillSetupDao.updateDrillSetup(updated)
        
        val retrieved = drillSetupDao.getDrillSetupById(drillSetup.id)
        
        // Then
        assertThat(retrieved?.name).isEqualTo("Updated Name")
        assertThat(retrieved?.desc).isEqualTo("Updated Desc")
    }
    
    @Test
    fun deleteDrillSetup_removesFromDatabase() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "To Delete")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        // When
        drillSetupDao.deleteDrillSetup(drillSetup)
        
        val retrieved = drillSetupDao.getDrillSetupById(drillSetup.id)
        
        // Then
        assertThat(retrieved).isNull()
    }
    
    @Test
    fun searchDrillSetups_findsMatchingDrills() = runTest {
        // Given
        drillSetupDao.insertDrillSetup(DrillSetupEntity(name = "Accuracy Drill"))
        drillSetupDao.insertDrillSetup(DrillSetupEntity(name = "Speed Drill"))
        drillSetupDao.insertDrillSetup(DrillSetupEntity(name = "Accuracy Training"))
        
        // When
        val results = drillSetupDao.searchDrillSetups("Accuracy").first()
        
        // Then
        assertThat(results).hasSize(2)
        assertThat(results.map { it.name }).containsExactly("Accuracy Drill", "Accuracy Training")
    }
    
    @Test
    fun getDrillSetupWithTargets_returnsCorrectData() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Drill with Targets")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        val target1 = DrillTargetsConfigEntity(
            drillSetupId = drillSetup.id,
            seqNo = 1,
            targetName = "Target 1",
            targetType = "IPSC"
        )
        val target2 = DrillTargetsConfigEntity(
            drillSetupId = drillSetup.id,
            seqNo = 2,
            targetName = "Target 2",
            targetType = "Popper"
        )
        targetConfigDao.insertTargetConfig(target1)
        targetConfigDao.insertTargetConfig(target2)
        
        // When
        val setupWithTargets = drillSetupDao.getDrillSetupWithTargets(drillSetup.id)
        
        // Then
        assertThat(setupWithTargets).isNotNull()
        assertThat(setupWithTargets?.drillSetup?.name).isEqualTo("Drill with Targets")
        assertThat(setupWithTargets?.targets).hasSize(2)
        assertThat(setupWithTargets?.targets?.map { it.targetName })
            .containsExactly("Target 1", "Target 2")
    }
    
    @Test
    fun getDrillSetupCount_returnsCorrectCount() = runTest {
        // Given
        drillSetupDao.insertDrillSetup(DrillSetupEntity(name = "Drill 1"))
        drillSetupDao.insertDrillSetup(DrillSetupEntity(name = "Drill 2"))
        
        // When
        val count = drillSetupDao.getDrillSetupCount()
        
        // Then
        assertThat(count).isEqualTo(2)
    }
}
