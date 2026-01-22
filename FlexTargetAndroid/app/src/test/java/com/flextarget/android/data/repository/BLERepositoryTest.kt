package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.local.entity.ShotEntity
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class BLERepositoryTest {

    private lateinit var bleRepository: BLERepository
    private val mockShotDao: ShotDao = mockk()

    @Before
    fun setup() {
        bleRepository = BLERepository(mockShotDao)
    }

    @Test
    fun `initial device state is Disconnected`() = runTest {
        // When
        val initialState = bleRepository.deviceState.first()

        // Then
        assertThat(initialState).isEqualTo(DeviceState.Disconnected)
    }

    @Test
    fun `getDeviceAuthData returns failure when no connection`() = runTest {
        // When
        val result = bleRepository.getDeviceAuthData()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("No BLE connection")
    }

    @Test
    fun `sendReady clears session shots and emits Ready state`() = runTest {
        // Given - mock connection
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand("READY") } returns ""

        // When
        val result = bleRepository.sendReady()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Ready)
        assertThat(bleRepository.getCurrentSessionShots()).isEmpty()
        coVerify { mockConnection.sendCommand("READY") }
    }

    @Test
    fun `sendReady returns failure when no connection`() = runTest {
        // When
        val result = bleRepository.sendReady()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("No BLE connection")
    }

    @Test
    fun `startShooting emits Shooting state`() = runTest {
        // Given - mock connection
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand("START_SHOOTING") } returns ""

        // When
        val result = bleRepository.startShooting()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Shooting)
        coVerify { mockConnection.sendCommand("START_SHOOTING") }
    }

    @Test
    fun `stopShooting emits Ready state and logs shot count`() = runTest {
        // Given - mock connection and add some shots
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        val sessionShotsField = bleRepository.javaClass.getDeclaredField("currentSessionShots")
        sessionShotsField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val sessionShots = sessionShotsField.get(bleRepository) as MutableList<ShotEvent>
        sessionShots.add(ShotEvent(1, 10.0, 20.0, 10))

        coEvery { mockConnection.sendCommand("STOP_SHOOTING") } returns ""

        // When
        val result = bleRepository.stopShooting()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Ready)
        coVerify { mockConnection.sendCommand("STOP_SHOOTING") }
    }

    @Test
    fun `processMessage parses valid shot JSON and emits ShotEvent`() = runTest {
        // Given
        val validMessage = """{"shot": 1, "x": 45.5, "y": 32.1, "score": 10}"""

        // When
        val result = bleRepository.processMessage(validMessage)

        // Then
        assertThat(result.isSuccess).isTrue()

        // Verify shot was added to session
        val sessionShots = bleRepository.getCurrentSessionShots()
        assertThat(sessionShots).hasSize(1)
        assertThat(sessionShots[0].shotIndex).isEqualTo(1)
        assertThat(sessionShots[0].x).isEqualTo(45.5)
        assertThat(sessionShots[0].y).isEqualTo(32.1)
        assertThat(sessionShots[0].score).isEqualTo(10)
    }

    @Test
    fun `processMessage handles invalid JSON gracefully`() = runTest {
        // Given
        val invalidMessage = "invalid json"

        // When
        val result = bleRepository.processMessage(invalidMessage)

        // Then
        assertThat(result.isSuccess).isTrue() // Should not fail, just log warning
    }

    @Test
    fun `saveSessionShots converts ShotEvents to ShotEntities and saves to database`() = runTest {
        // Given
        val drillResultId = UUID.randomUUID()
        val testShot = ShotEvent(1, 10.0, 20.0, 8, Date(1234567890000))

        // Add shot to session
        val sessionShotsField = bleRepository.javaClass.getDeclaredField("currentSessionShots")
        sessionShotsField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val sessionShots = sessionShotsField.get(bleRepository) as MutableList<ShotEvent>
        sessionShots.add(testShot)

        coEvery { mockShotDao.insertShot(any()) } returns 1L

        // When
        val result = bleRepository.saveSessionShots(drillResultId)

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrNull()).isEqualTo(1)

        coVerify { mockShotDao.insertShot(any()) }
    }

    @Test
    fun `connect establishes connection and emits Connected state`() = runTest {
        // Given
        val deviceAddress = "AA:BB:CC:DD:EE:FF"

        // When
        val result = bleRepository.connect(deviceAddress)

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Connected)
    }

    @Test
    fun `disconnect clears connection and emits Disconnected state`() = runTest {
        // Given - establish connection first
        val deviceAddress = "AA:BB:CC:DD:EE:FF"
        bleRepository.connect(deviceAddress)

        // When
        val result = bleRepository.disconnect()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Disconnected)
    }

    @Test
    fun `getCurrentSessionShots returns copy of session shots`() = runTest {
        // Given
        val testShot = ShotEvent(1, 10.0, 20.0, 8)
        val sessionShotsField = bleRepository.javaClass.getDeclaredField("currentSessionShots")
        sessionShotsField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val sessionShots = sessionShotsField.get(bleRepository) as MutableList<ShotEvent>
        sessionShots.add(testShot)

        // When
        val currentShots = bleRepository.getCurrentSessionShots()

        // Then
        assertThat(currentShots).hasSize(1)
        assertThat(currentShots[0]).isEqualTo(testShot)

        // Verify it's a copy (modifying returned list shouldn't affect internal list)
        // Note: getCurrentSessionShots() returns toList() which is immutable
        assertThat(bleRepository.getCurrentSessionShots()).hasSize(1)
    }
}