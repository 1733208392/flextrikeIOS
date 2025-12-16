package com.flextarget.android.data.local.dao

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.ShotEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Date
import java.util.UUID
import com.google.common.truth.Truth.assertThat

@RunWith(AndroidJUnit4::class)
class DrillResultDaoTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private lateinit var database: FlexTargetDatabase
    private lateinit var drillResultDao: DrillResultDao
    private lateinit var drillSetupDao: DrillSetupDao
    private lateinit var shotDao: ShotDao
    
    @Before
    fun setup() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FlexTargetDatabase::class.java
        )
            .allowMainThreadQueries()
            .build()
        
        drillResultDao = database.drillResultDao()
        drillSetupDao = database.drillSetupDao()
        shotDao = database.shotDao()
    }
    
    @After
    fun tearDown() {
        database.close()
    }
    
    @Test
    fun insertDrillResult_andGetById_returnsCorrectResult() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Test Drill")
        drillSetupDao.insertDrillSetup(drillSetup)
        
        val drillResult = DrillResultEntity(
            id = UUID.randomUUID(),
            date = Date(),
            drillId = UUID.randomUUID(),
            sessionId = UUID.randomUUID(),
            totalTime = 45.5,
            drillSetupId = drillSetup.id
        )
        
        // When
        drillResultDao.insertDrillResult(drillResult)
        val retrieved = drillResultDao.getDrillResultById(drillResult.id)
        
        // Then
        assertThat(retrieved).isNotNull()
        assertThat(retrieved?.totalTime).isEqualTo(45.5)
        assertThat(retrieved?.drillSetupId).isEqualTo(drillSetup.id)
    }
    
    @Test
    fun getAllDrillResults_returnsAllResults() = runTest {
        // Given
        val result1 = DrillResultEntity(totalTime = 30.0)
        val result2 = DrillResultEntity(totalTime = 40.0)
        val result3 = DrillResultEntity(totalTime = 50.0)
        
        // When
        drillResultDao.insertDrillResult(result1)
        drillResultDao.insertDrillResult(result2)
        drillResultDao.insertDrillResult(result3)
        
        val allResults = drillResultDao.getAllDrillResults().first()
        
        // Then
        assertThat(allResults).hasSize(3)
    }
    
    @Test
    fun getDrillResultWithShots_returnsCorrectData() = runTest {
        // Given
        val drillResult = DrillResultEntity(totalTime = 60.0)
        drillResultDao.insertDrillResult(drillResult)
        
        val shot1 = ShotEntity(
            drillResultId = drillResult.id,
            data = """{"x": 100, "y": 200}""",
            timestamp = Date()
        )
        val shot2 = ShotEntity(
            drillResultId = drillResult.id,
            data = """{"x": 150, "y": 250}""",
            timestamp = Date()
        )
        shotDao.insertShot(shot1)
        shotDao.insertShot(shot2)
        
        // When
        val resultWithShots = drillResultDao.getDrillResultWithShots(drillResult.id)
        
        // Then
        assertThat(resultWithShots).isNotNull()
        assertThat(resultWithShots?.drillResult?.totalTime).isEqualTo(60.0)
        assertThat(resultWithShots?.shots).hasSize(2)
    }
    
    @Test
    fun getDrillResultsBySetupId_returnsFilteredResults() = runTest {
        // Given
        val drillSetup1 = DrillSetupEntity(name = "Drill 1")
        val drillSetup2 = DrillSetupEntity(name = "Drill 2")
        drillSetupDao.insertDrillSetup(drillSetup1)
        drillSetupDao.insertDrillSetup(drillSetup2)
        
        drillResultDao.insertDrillResult(DrillResultEntity(drillSetupId = drillSetup1.id))
        drillResultDao.insertDrillResult(DrillResultEntity(drillSetupId = drillSetup1.id))
        drillResultDao.insertDrillResult(DrillResultEntity(drillSetupId = drillSetup2.id))
        
        // When
        val results = drillResultDao.getDrillResultsBySetupId(drillSetup1.id).first()
        
        // Then
        assertThat(results).hasSize(2)
    }
    
    @Test
    fun deleteDrillResult_removesFromDatabase() = runTest {
        // Given
        val drillResult = DrillResultEntity(totalTime = 30.0)
        drillResultDao.insertDrillResult(drillResult)
        
        // When
        drillResultDao.deleteDrillResult(drillResult)
        
        val retrieved = drillResultDao.getDrillResultById(drillResult.id)
        
        // Then
        assertThat(retrieved).isNull()
    }
    
    @Test
    fun getDrillResultCount_returnsCorrectCount() = runTest {
        // Given
        drillResultDao.insertDrillResult(DrillResultEntity())
        drillResultDao.insertDrillResult(DrillResultEntity())
        drillResultDao.insertDrillResult(DrillResultEntity())
        
        // When
        val count = drillResultDao.getDrillResultCount()
        
        // Then
        assertThat(count).isEqualTo(3)
    }
}
