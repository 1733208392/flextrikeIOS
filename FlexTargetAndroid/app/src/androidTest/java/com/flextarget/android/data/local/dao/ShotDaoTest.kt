package com.flextarget.android.data.local.dao

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillResultEntity
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
class ShotDaoTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private lateinit var database: FlexTargetDatabase
    private lateinit var shotDao: ShotDao
    private lateinit var drillResultDao: DrillResultDao
    
    @Before
    fun setup() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FlexTargetDatabase::class.java
        )
            .allowMainThreadQueries()
            .build()
        
        shotDao = database.shotDao()
        drillResultDao = database.drillResultDao()
    }
    
    @After
    fun tearDown() {
        database.close()
    }
    
    @Test
    fun insertShot_andGetById_returnsCorrectShot() = runTest {
        // Given
        val drillResult = DrillResultEntity()
        drillResultDao.insertDrillResult(drillResult)
        
        val shot = ShotEntity(
            id = UUID.randomUUID(),
            data = """{"x": 100, "y": 200, "score": 10}""",
            timestamp = Date(),
            drillResultId = drillResult.id
        )
        
        // When
        shotDao.insertShot(shot)
        val retrieved = shotDao.getShotById(shot.id)
        
        // Then
        assertThat(retrieved).isNotNull()
        assertThat(retrieved?.data).contains("\"x\": 100")
        assertThat(retrieved?.drillResultId).isEqualTo(drillResult.id)
    }
    
    @Test
    fun getShotsByDrillResultId_returnsCorrectShots() = runTest {
        // Given
        val drillResult1 = DrillResultEntity()
        val drillResult2 = DrillResultEntity()
        drillResultDao.insertDrillResult(drillResult1)
        drillResultDao.insertDrillResult(drillResult2)
        
        shotDao.insertShot(ShotEntity(drillResultId = drillResult1.id, data = "shot1"))
        shotDao.insertShot(ShotEntity(drillResultId = drillResult1.id, data = "shot2"))
        shotDao.insertShot(ShotEntity(drillResultId = drillResult2.id, data = "shot3"))
        
        // When
        val shots = shotDao.getShotsByDrillResultId(drillResult1.id).first()
        
        // Then
        assertThat(shots).hasSize(2)
    }
    
    @Test
    fun deleteShot_removesFromDatabase() = runTest {
        // Given
        val shot = ShotEntity(data = "test shot")
        shotDao.insertShot(shot)
        
        // When
        shotDao.deleteShot(shot)
        
        val retrieved = shotDao.getShotById(shot.id)
        
        // Then
        assertThat(retrieved).isNull()
    }
    
    @Test
    fun getShotCount_returnsCorrectCount() = runTest {
        // Given
        shotDao.insertShot(ShotEntity())
        shotDao.insertShot(ShotEntity())
        shotDao.insertShot(ShotEntity())
        
        // When
        val count = shotDao.getShotCount()
        
        // Then
        assertThat(count).isEqualTo(3)
    }
}
