package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.DrillResultDao
import com.flextarget.android.data.local.dao.DrillSetupDao
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class DrillRepositoryTest {

    private lateinit var drillRepository: DrillRepository
    private val mockDrillSetupDao: DrillSetupDao = mockk()
    private val mockDrillResultDao: DrillResultDao = mockk()
    private val mockBleRepository: BLERepository = mockk()
    private val mockBleMessageQueue: BLEMessageQueue = mockk()

    @Before
    fun setup() {
        drillRepository = DrillRepository(
            mockDrillSetupDao,
            mockDrillResultDao,
            mockBleRepository,
            mockBleMessageQueue
        )
    }

    @Test
    fun `initializeDrill returns failure when drill not found`() = runTest {
        // Given
        val drillId = UUID.randomUUID()
        coEvery { mockDrillSetupDao.getDrillSetupById(drillId) } returns null

        // When
        val result = drillRepository.initializeDrill(drillId)

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Drill not found")
    }

    @Test
    fun `initializeDrill successfully initializes drill and sends ready signal`() = runTest {
        // Given
        val drillId = UUID.randomUUID()
        val drillSetup = DrillSetupEntity(
            id = drillId,
            name = "Test Drill",
            drillDuration = 60.0
        )
        coEvery { mockDrillSetupDao.getDrillSetupById(drillId) } returns drillSetup
        coEvery { mockBleRepository.sendReady() } returns Result.success(Unit)

        // When
        val result = drillRepository.initializeDrill(drillId)

        // Then
        assertThat(result.isSuccess).isTrue()
        val context = result.getOrNull()
        assertThat(context).isNotNull()
        assertThat(context?.drillId).isEqualTo(drillId)
        assertThat(context?.drillSetup).isEqualTo(drillSetup)
        assertThat(context?.state).isEqualTo(DrillExecutionState.INITIALIZED)

        coVerify { mockBleRepository.sendReady() }
    }

    @Test
    fun `startExecuting returns failure when no active drill`() = runTest {
        // When
        val result = drillRepository.startExecuting()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("No active drill")
    }

    @Test
    fun `startExecuting returns failure when not in WAITING_ACK state`() = runTest {
        // Given - set context in wrong state
        val context = DrillExecutionContext(
            drillId = UUID.randomUUID(),
            drillSetup = DrillSetupEntity(id = UUID.randomUUID(), name = "Test"),
            state = DrillExecutionState.INITIALIZED
        )
        drillRepository.javaClass.getDeclaredField("_executionContext").apply {
            isAccessible = true
            val mutableStateFlow = this.get(drillRepository)
            mutableStateFlow.javaClass.getDeclaredMethod("setValue", Any::class.java).apply {
                isAccessible = true
                invoke(mutableStateFlow, context)
            }
        }

        // When
        val result = drillRepository.startExecuting()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Invalid state: INITIALIZED")
    }

    @Test
    fun `startExecuting successfully starts shooting when in correct state`() = runTest {
        // Given - set context in WAITING_ACK state
        val context = DrillExecutionContext(
            drillId = UUID.randomUUID(),
            drillSetup = DrillSetupEntity(id = UUID.randomUUID(), name = "Test"),
            state = DrillExecutionState.WAITING_ACK
        )
        drillRepository.javaClass.getDeclaredField("_executionContext").apply {
            isAccessible = true
            val mutableStateFlow = this.get(drillRepository)
            mutableStateFlow.javaClass.getDeclaredMethod("setValue", Any::class.java).apply {
                isAccessible = true
                invoke(mutableStateFlow, context)
            }
        }
        coEvery { mockBleRepository.startShooting() } returns Result.success(Unit)

        // When
        val result = drillRepository.startExecuting()

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockBleRepository.startShooting() }
    }

    @Test
    fun `finalizeDrill successfully stops shooting and updates state`() = runTest {
        // Given - set context in EXECUTING state
        val context = DrillExecutionContext(
            drillId = UUID.randomUUID(),
            drillSetup = DrillSetupEntity(id = UUID.randomUUID(), name = "Test"),
            state = DrillExecutionState.EXECUTING
        )
        drillRepository.javaClass.getDeclaredField("_executionContext").apply {
            isAccessible = true
            val mutableStateFlow = this.get(drillRepository)
            mutableStateFlow.javaClass.getDeclaredMethod("setValue", Any::class.java).apply {
                isAccessible = true
                invoke(mutableStateFlow, context)
            }
        }
        coEvery { mockBleRepository.stopShooting() } returns Result.success(Unit)

        // When
        val result = drillRepository.finalizeDrill()

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockBleRepository.stopShooting() }
    }

    @Test
    fun `completeDrill successfully saves results and completes execution`() = runTest {
        // Given - set context in EXECUTING state
        val drillId = UUID.randomUUID()
        val drillSetupId = UUID.randomUUID()
        val context = DrillExecutionContext(
            drillId = drillId,
            drillSetup = DrillSetupEntity(id = drillSetupId, name = "Test"),
            state = DrillExecutionState.EXECUTING,
            startTime = System.currentTimeMillis() - 10000 // 10 seconds ago
        )
        drillRepository.javaClass.getDeclaredField("_executionContext").apply {
            isAccessible = true
            val mutableStateFlow = this.get(drillRepository)
            mutableStateFlow.javaClass.getDeclaredMethod("setValue", Any::class.java).apply {
                isAccessible = true
                invoke(mutableStateFlow, context)
            }
        }

        // Mock BLE repository
        val mockShots = listOf(
            ShotEvent(1, 10.0, 20.0, 10),
            ShotEvent(2, 15.0, 25.0, 8)
        )
        every { mockBleRepository.getCurrentSessionShots() } returns mockShots
        coEvery { mockBleRepository.saveSessionShots(any()) } returns Result.success(2)

        // Mock DAO
        coEvery { mockDrillResultDao.insertDrillResult(any()) } returns 1L

        // When
        val result = drillRepository.completeDrill()

        // Then
        assertThat(result.isSuccess).isTrue()
        val completedContext = result.getOrNull()
        assertThat(completedContext).isNotNull()
        assertThat(completedContext?.state).isEqualTo(DrillExecutionState.COMPLETE)
        assertThat(completedContext?.shotsReceived).isEqualTo(2)
        assertThat(completedContext?.totalScore).isEqualTo(18) // 10 + 8

        coVerify { mockDrillResultDao.insertDrillResult(any()) }
        coVerify { mockBleRepository.saveSessionShots(any()) }
    }

    @Test
    fun `abortDrill stops shooting and clears context`() = runTest {
        // Given
        coEvery { mockBleRepository.stopShooting() } returns Result.success(Unit)

        // When
        val result = drillRepository.abortDrill()

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockBleRepository.stopShooting() }
    }

    @Test
    fun `getAllDrills returns flow from dao`() = runTest {
        // Given
        val drills = listOf(
            DrillSetupEntity(id = UUID.randomUUID(), name = "Drill 1"),
            DrillSetupEntity(id = UUID.randomUUID(), name = "Drill 2")
        )
        every { mockDrillSetupDao.getAllDrillSetups() } returns flowOf(drills)

        // When
        val result = drillRepository.getAllDrills()

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getDrillById returns drill from dao`() = runTest {
        // Given
        val drillId = UUID.randomUUID()
        val drill = DrillSetupEntity(id = drillId, name = "Test Drill")
        coEvery { mockDrillSetupDao.getDrillSetupById(drillId) } returns drill

        // When
        val result = drillRepository.getDrillById(drillId)

        // Then
        assertThat(result).isEqualTo(drill)
    }

    @Test
    fun `createDrill inserts drill and returns id`() = runTest {
        // Given
        val name = "New Drill"
        val description = "Test drill description"
        val timeLimit = 120

        coEvery { mockDrillSetupDao.insertDrillSetup(any()) } returns 1L

        // When
        val result = drillRepository.createDrill(name, description, timeLimit)

        // Then
        assertThat(result.isSuccess).isTrue()
        val drillId = result.getOrNull()
        assertThat(drillId).isNotNull()

        coVerify { mockDrillSetupDao.insertDrillSetup(any()) }
    }

    @Test
    fun `updateDrill calls dao update method`() = runTest {
        // Given
        val drill = DrillSetupEntity(id = UUID.randomUUID(), name = "Updated Drill")
        coEvery { mockDrillSetupDao.updateDrillSetup(drill) } returns Unit

        // When
        val result = drillRepository.updateDrill(drill)

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockDrillSetupDao.updateDrillSetup(drill) }
    }

    @Test
    fun `deleteDrill calls dao delete method`() = runTest {
        // Given
        val drillId = UUID.randomUUID()
        coEvery { mockDrillSetupDao.deleteDrillSetupById(drillId) } returns Unit

        // When
        val result = drillRepository.deleteDrill(drillId)

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockDrillSetupDao.deleteDrillSetupById(drillId) }
    }

    @Test
    fun `getExecutionStats returns empty map when no active drill`() = runTest {
        // When
        val stats = drillRepository.getExecutionStats()

        // Then
        assertThat(stats).isEmpty()
    }

    @Test
    fun `getExecutionStats returns stats for active drill`() = runTest {
        // Given - set active context
        val startTime = System.currentTimeMillis() - 5000 // 5 seconds ago
        val context = DrillExecutionContext(
            drillId = UUID.randomUUID(),
            drillSetup = DrillSetupEntity(id = UUID.randomUUID(), name = "Test"),
            state = DrillExecutionState.EXECUTING,
            shotsReceived = 3,
            totalScore = 27,
            startTime = startTime
        )
        drillRepository.javaClass.getDeclaredField("_executionContext").apply {
            isAccessible = true
            val mutableStateFlow = this.get(drillRepository)
            mutableStateFlow.javaClass.getDeclaredMethod("setValue", Any::class.java).apply {
                isAccessible = true
                invoke(mutableStateFlow, context)
            }
        }

        // When
        val stats = drillRepository.getExecutionStats()

        // Then
        assertThat(stats).isNotEmpty()
        assertThat(stats["state"]).isEqualTo(DrillExecutionState.EXECUTING)
        assertThat(stats["shotsReceived"]).isEqualTo(3)
        assertThat(stats["totalScore"]).isEqualTo(27)
        assertThat(stats["averageScore"]).isEqualTo(9) // 27 / 3
    }
}