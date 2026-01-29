package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.DrillSetupDao
import com.flextarget.android.data.local.dao.DrillTargetsConfigDao
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillSetupWithTargets
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
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
import java.util.UUID
import com.google.common.truth.Truth.assertThat

@RunWith(MockitoJUnitRunner::class)
class DrillSetupRepositoryTest {
    
    @Mock
    private lateinit var drillSetupDao: DrillSetupDao
    
    @Mock
    private lateinit var targetConfigDao: DrillTargetsConfigDao
    
    private lateinit var repository: DrillSetupRepository
    
    @Before
    fun setup() {
        repository = DrillSetupRepository(drillSetupDao, targetConfigDao)
    }
    
    @Test
    fun getDrillSetupById_callsDaoAndReturnsResult() = runTest {
        // Given
        val id = UUID.randomUUID()
        val drillSetup = DrillSetupEntity(id = id, name = "Test Drill")
        whenever(drillSetupDao.getDrillSetupById(id)).thenReturn(drillSetup)
        
        // When
        val result = repository.getDrillSetupById(id)
        
        // Then
        verify(drillSetupDao).getDrillSetupById(id)
        assertThat(result).isEqualTo(drillSetup)
    }
    
    @Test
    fun insertDrillSetup_callsDaoWithCorrectData() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "New Drill")
        whenever(drillSetupDao.insertDrillSetup(drillSetup)).thenReturn(1L)
        
        // When
        val result = repository.insertDrillSetup(drillSetup)
        
        // Then
        verify(drillSetupDao).insertDrillSetup(drillSetup)
        assertThat(result).isEqualTo(1L)
    }
    
    @Test
    fun insertDrillSetupWithTargets_insertsSetupAndTargets() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(id = UUID.randomUUID(), name = "Drill with Targets")
        val targets = listOf(
            DrillTargetsConfigEntity(targetName = "Target 1"),
            DrillTargetsConfigEntity(targetName = "Target 2")
        )
        
        whenever(drillSetupDao.insertDrillSetup(drillSetup)).thenReturn(1L)
        
        // When
        repository.insertDrillSetupWithTargets(drillSetup, targets)
        
        // Then
        verify(drillSetupDao).insertDrillSetup(drillSetup)
        verify(targetConfigDao).insertTargetConfigs(
            targets.map { it.copy(drillSetupId = drillSetup.id) }
        )
    }
    
    @Test
    fun updateDrillSetup_callsDaoUpdate() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "Updated Drill")
        
        // When
        repository.updateDrillSetup(drillSetup)
        
        // Then
        verify(drillSetupDao).updateDrillSetup(drillSetup)
    }
    
    @Test
    fun deleteDrillSetup_callsDaoDelete() = runTest {
        // Given
        val drillSetup = DrillSetupEntity(name = "To Delete")
        
        // When
        repository.deleteDrillSetup(drillSetup)
        
        // Then
        verify(drillSetupDao).deleteDrillSetup(drillSetup)
    }
    
    @Test
    fun searchDrillSetups_returnsDaoResults() = runTest {
        // Given
        val query = "Accuracy"
        val results = listOf(
            DrillSetupEntity(name = "Accuracy Drill 1"),
            DrillSetupEntity(name = "Accuracy Drill 2")
        )
        whenever(drillSetupDao.searchDrillSetups(query)).thenReturn(flowOf(results))
        
        // When
        val flow = repository.searchDrillSetups(query)
        val actualResults = flow.first()
        
        // Then
        verify(drillSetupDao).searchDrillSetups(query)
        assertThat(actualResults).hasSize(2)
        assertThat(actualResults).isEqualTo(results)
    }
    
    @Test
    fun getDrillSetupCount_returnsDaoCount() = runTest {
        // Given
        whenever(drillSetupDao.getDrillSetupCount()).thenReturn(5)
        
        // When
        val count = repository.getDrillSetupCount()
        
        // Then
        verify(drillSetupDao).getDrillSetupCount()
        assertThat(count).isEqualTo(5)
    }
}
