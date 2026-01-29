package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.DrillResultDao
import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.local.entity.ShotEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.util.Date
import java.util.UUID
import com.google.common.truth.Truth.assertThat

@RunWith(MockitoJUnitRunner::class)
class DrillResultRepositoryTest {
    
    @Mock
    private lateinit var drillResultDao: DrillResultDao
    
    @Mock
    private lateinit var shotDao: ShotDao
    
    private lateinit var repository: DrillResultRepository
    
    @Before
    fun setup() {
        repository = DrillResultRepository(drillResultDao, shotDao)
    }
    
    @Test
    fun getDrillResultById_callsDaoAndReturnsResult() = runTest {
        // Given
        val id = UUID.randomUUID()
        val drillResult = DrillResultEntity(id = id, totalTime = 45.5)
        whenever(drillResultDao.getDrillResultById(id)).thenReturn(drillResult)
        
        // When
        val result = repository.getDrillResultById(id)
        
        // Then
        verify(drillResultDao).getDrillResultById(id)
        assertThat(result).isEqualTo(drillResult)
    }
    
    @Test
    fun insertDrillResult_callsDaoWithCorrectData() = runTest {
        // Given
        val drillResult = DrillResultEntity(totalTime = 30.0)
        whenever(drillResultDao.insertDrillResult(drillResult)).thenReturn(1L)
        
        // When
        val result = repository.insertDrillResult(drillResult)
        
        // Then
        verify(drillResultDao).insertDrillResult(drillResult)
        assertThat(result).isEqualTo(1L)
    }
    
    @Test
    fun insertDrillResultWithShots_insertsResultAndShots() = runTest {
        // Given
        val drillResult = DrillResultEntity(id = UUID.randomUUID(), totalTime = 60.0)
        val shots = listOf(
            ShotEntity(data = "shot1"),
            ShotEntity(data = "shot2")
        )
        
        whenever(drillResultDao.insertDrillResult(drillResult)).thenReturn(1L)
        
        // When
        repository.insertDrillResultWithShots(drillResult, shots)
        
        // Then
        verify(drillResultDao).insertDrillResult(drillResult)
        verify(shotDao).insertShots(
            shots.map { it.copy(drillResultId = drillResult.id) }
        )
    }
    
    @Test
    fun getDrillResultsBySetupId_returnsDaoResults() = runTest {
        // Given
        val setupId = UUID.randomUUID()
        val results = listOf(
            DrillResultEntity(drillSetupId = setupId, totalTime = 30.0),
            DrillResultEntity(drillSetupId = setupId, totalTime = 35.0)
        )
        whenever(drillResultDao.getDrillResultsBySetupId(setupId)).thenReturn(flowOf(results))
        
        // When
        val flow = repository.getDrillResultsBySetupId(setupId)
        val actualResults = flow.first()
        
        // Then
        verify(drillResultDao).getDrillResultsBySetupId(setupId)
        assertThat(actualResults).hasSize(2)
        assertThat(actualResults).isEqualTo(results)
    }
    
    @Test
    fun getDrillResultsByDateRange_returnsDaoResults() = runTest {
        // Given
        val startDate = Date()
        val endDate = Date()
        val results = listOf(DrillResultEntity())
        whenever(drillResultDao.getDrillResultsByDateRange(startDate, endDate))
            .thenReturn(flowOf(results))
        
        // When
        val flow = repository.getDrillResultsByDateRange(startDate, endDate)
        val actualResults = flow.first()
        
        // Then
        verify(drillResultDao).getDrillResultsByDateRange(startDate, endDate)
        assertThat(actualResults).isEqualTo(results)
    }
    
    @Test
    fun deleteDrillResult_callsDaoDelete() = runTest {
        // Given
        val drillResult = DrillResultEntity()
        
        // When
        repository.deleteDrillResult(drillResult)
        
        // Then
        verify(drillResultDao).deleteDrillResult(drillResult)
    }
    
    @Test
    fun getDrillResultCount_returnsDaoCount() = runTest {
        // Given
        whenever(drillResultDao.getDrillResultCount()).thenReturn(10)
        
        // When
        val count = repository.getDrillResultCount()
        
        // Then
        verify(drillResultDao).getDrillResultCount()
        assertThat(count).isEqualTo(10)
    }
    
    @Test
    fun getDrillResultCountBySetupId_returnsDaoCount() = runTest {
        // Given
        val setupId = UUID.randomUUID()
        whenever(drillResultDao.getDrillResultCountBySetupId(setupId)).thenReturn(3)
        
        // When
        val count = repository.getDrillResultCountBySetupId(setupId)
        
        // Then
        verify(drillResultDao).getDrillResultCountBySetupId(setupId)
        assertThat(count).isEqualTo(3)
    }
}
