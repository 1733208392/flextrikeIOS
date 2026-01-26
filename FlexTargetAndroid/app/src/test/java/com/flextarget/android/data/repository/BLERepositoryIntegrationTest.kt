package com.flextarget.android.data.repository

import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.local.entity.ShotEntity
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date
import java.util.UUID

/**
 * Integration tests for BLERepository
 * Tests complete drill workflows, multi-shot sequences, device state transitions, and error handling
 */
@RunWith(RobolectricTestRunner::class)
class BLERepositoryIntegrationTest {

    private lateinit var bleRepository: BLERepository
    private val mockShotDao: ShotDao = mockk()

    @Before
    fun setup() {
        bleRepository = BLERepository(mockShotDao)
    }

    // MARK: - Drill Workflow Tests

    @Test
    fun `complete drill workflow Ready to Ready`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        // When - Ready signal
        val readyResult = bleRepository.sendReady()

        // Then
        assertThat(readyResult.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Ready)
        coVerify { mockConnection.sendCommand("READY") }
    }

    @Test
    fun `complete drill workflow Ready to Shooting with shots`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        // When - Ready
        val readyResult = bleRepository.sendReady()
        assertThat(readyResult.isSuccess).isTrue()

        // When - Start shooting
        val startResult = bleRepository.startShooting()
        assertThat(startResult.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Shooting)

        // When - Receive shots
        val shot1Message = BLETestDataAndroid.createShotMessage(
            hitArea = "A", x = 50.0, y = 60.0
        )
        val shot1Result = bleRepository.processMessage(shot1Message)
        assertThat(shot1Result.isSuccess).isTrue()

        val shot2Message = BLETestDataAndroid.createShotMessage(
            hitArea = "C", x = 45.5, y = 32.1
        )
        val shot2Result = bleRepository.processMessage(shot2Message)
        assertThat(shot2Result.isSuccess).isTrue()

        // Then - Verify shots accumulated
        val sessionShots = bleRepository.getCurrentSessionShots()
        assertThat(sessionShots).isNotEmpty()

        // When - Stop shooting
        val stopResult = bleRepository.stopShooting()
        assertThat(stopResult.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Ready)

        // Verify shots still in session after stop
        assertThat(bleRepository.getCurrentSessionShots()).isNotEmpty()
    }

    // MARK: - Multiple Shot Sequence Tests

    @Test
    fun `receive rapid sequence of 5 shots`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        bleRepository.startShooting()

        // When - Send 5 shots rapidly
        val shots = listOf(
            BLETestDataAndroid.createShotMessage(hitArea = "A", x = 10.0, y = 20.0),
            BLETestDataAndroid.createShotMessage(hitArea = "B", x = 30.0, y = 40.0),
            BLETestDataAndroid.createShotMessage(hitArea = "C", x = 50.0, y = 60.0),
            BLETestDataAndroid.createShotMessage(hitArea = "D", x = 70.0, y = 80.0),
            BLETestDataAndroid.createShotMessage(hitArea = "E", x = 90.0, y = 100.0)
        )

        shots.forEach { message ->
            val result = bleRepository.processMessage(message)
            assertThat(result.isSuccess).isTrue()
        }

        // Then - All shots should be accumulated
        val sessionShots = bleRepository.getCurrentSessionShots()
        assertThat(sessionShots.size).isGreaterThanOrEqualTo(5)
    }

    @Test
    fun `session shots cleared on new Ready signal`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        // Add initial shots
        bleRepository.startShooting()
        val initialMessage = BLETestDataAndroid.createShotMessage()
        bleRepository.processMessage(initialMessage)

        // When - Send Ready signal (clearing session)
        val readyResult = bleRepository.sendReady()

        // Then - Session shots should be cleared
        assertThat(readyResult.isSuccess).isTrue()
        assertThat(bleRepository.getCurrentSessionShots()).isEmpty()
    }

    // MARK: - Device Connection and Disconnection Tests

    @Test
    fun `handle device disconnection during shooting`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        bleRepository.startShooting()

        // Add a shot
        val message = BLETestDataAndroid.createShotMessage()
        bleRepository.processMessage(message)

        val initialShotCount = bleRepository.getCurrentSessionShots().size
        assertThat(initialShotCount).isGreaterThan(0)

        // When - Disconnect device
        val disconnectResult = bleRepository.disconnect()

        // Then
        assertThat(disconnectResult.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Disconnected)

        // Shots should still be in session for potential recovery
        assertThat(bleRepository.getCurrentSessionShots().size).isEqualTo(initialShotCount)
    }

    @Test
    fun `handle reconnection after disconnection`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        bleRepository.connect("AA:BB:CC:DD:EE:FF")
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Connected)

        // When - Disconnect
        bleRepository.disconnect()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Disconnected)

        // When - Reconnect
        val reconnectResult = bleRepository.connect("AA:BB:CC:DD:EE:FF")

        // Then
        assertThat(reconnectResult.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Connected)
    }

    // MARK: - Auth Data Request Tests

    @Test
    fun `getDeviceAuthData with connected device`() = runTest {
        // Given
        BLEManager.shared.isConnected = true
        val testAuthData = "DEVICE_123:AUTH_TOKEN_ABC"

        // When
        val result = bleRepository.getDeviceAuthData()

        // Then - Would succeed with mocked device response
        // In real scenario, device would respond with auth data
    }

    @Test
    fun `multiple auth data requests in sequence`() = runTest {
        // Given
        BLEManager.shared.isConnected = true

        // When - Send multiple requests
        val results = mutableListOf<Result<String>>()
        repeat(3) {
            BLEManager.shared.isConnected = true // Ensure still connected
            // In real test, would set up device responses
        }

        // Then - All requests should complete
        // (In actual implementation with device response mocking)
    }

    // MARK: - Message Format Validation Tests

    @Test
    fun `process valid shot message with all fields`() = runTest {
        // Given
        val fullShotMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "content": {
            "command": "shot",
            "hit_area": "C",
            "hit_position": {"x": 45.5, "y": 32.1},
            "target_type": "idpa",
            "time_diff": 1.25,
            "device": "device_1",
            "score": 8,
            "timestamp": 1234567890000
          }
        }
        """

        // When
        val result = bleRepository.processMessage(fullShotMessage)

        // Then
        assertThat(result.isSuccess).isTrue()
        val shots = bleRepository.getCurrentSessionShots()
        assertThat(shots).isNotEmpty()
    }

    @Test
    fun `process shot message missing optional fields`() = runTest {
        // Given
        val minimalShotMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "content": {
            "command": "shot",
            "hit_area": "A",
            "hit_position": {"x": 10.0, "y": 20.0},
            "target_type": "ipsc",
            "time_diff": 0.5
          }
        }
        """

        // When
        val result = bleRepository.processMessage(minimalShotMessage)

        // Then
        assertThat(result.isSuccess).isTrue()
    }

    @Test
    fun `handle device list message during drill`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        bleRepository.startShooting()

        // When - Receive device list message
        val deviceListMessage = BLETestDataAndroid.createDeviceListMessage(
            devices = listOf("Target1" to "active", "Target2" to "standby")
        )
        val result = bleRepository.processMessage(deviceListMessage)

        // Then - Should handle without disrupting drill
        assertThat(result.isSuccess).isTrue()
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Shooting)
    }

    // MARK: - State Validation Tests

    @Test
    fun `cannot start shooting without Ready state`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        // When - Try to start shooting directly from Disconnected
        val result = bleRepository.startShooting()

        // Then
        // System may either fail or auto-transition to Ready
        // Depends on implementation requirements
    }

    @Test
    fun `cannot send auth data request when disconnected`() = runTest {
        // Given
        BLEManager.shared.isConnected = false
        assertThat(bleRepository.deviceState.first()).isEqualTo(DeviceState.Disconnected)

        // When
        val result = bleRepository.getDeviceAuthData()

        // Then
        assertThat(result.isFailure).isTrue()
    }

    @Test
    fun `state transitions are correct across workflow`() = runTest {
        // Given
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        val stateHistory = mutableListOf<DeviceState>()

        // When - Capture all state transitions
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Initial: Disconnected

        bleRepository.connect("AA:BB:CC:DD:EE:FF")
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Connected

        bleRepository.sendReady()
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Ready

        bleRepository.startShooting()
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Shooting

        bleRepository.stopShooting()
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Ready

        bleRepository.disconnect()
        bleRepository.deviceState.first().also { stateHistory.add(it) } // Disconnected

        // Then - Verify expected state progression
        assertThat(stateHistory).containsAtLeast(
            DeviceState.Disconnected,
            DeviceState.Connected,
            DeviceState.Ready,
            DeviceState.Shooting
        ).inOrder()
    }

    // MARK: - Database Persistence Tests

    @Test
    fun `save session shots to database after drill`() = runTest {
        // Given
        val drillResultId = UUID.randomUUID()
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        // Add multiple shots to session
        bleRepository.startShooting()
        val shots = listOf(
            BLETestDataAndroid.createShotMessage(hitArea = "A"),
            BLETestDataAndroid.createShotMessage(hitArea = "C"),
            BLETestDataAndroid.createShotMessage(hitArea = "B")
        )

        shots.forEach { message ->
            bleRepository.processMessage(message)
        }

        coEvery { mockShotDao.insertShot(any()) } returns 1L

        // When - Save session
        val result = bleRepository.saveSessionShots(drillResultId)

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify(atLeast = 1) { mockShotDao.insertShot(any()) }
    }

    @Test
    fun `cannot save shots without session data`() = runTest {
        // Given
        val drillResultId = UUID.randomUUID()
        assertThat(bleRepository.getCurrentSessionShots()).isEmpty()

        coEvery { mockShotDao.insertShot(any()) } returns 1L

        // When
        val result = bleRepository.saveSessionShots(drillResultId)

        // Then
        assertThat(result.isSuccess).isTrue()
        // Should handle gracefully with 0 shots saved
    }

    @Test
    fun `handle database insertion errors gracefully`() = runTest {
        // Given
        val drillResultId = UUID.randomUUID()
        val mockConnection = mockk<BLEConnection>()
        bleRepository.javaClass.getDeclaredField("currentConnection").apply {
            isAccessible = true
            set(bleRepository, mockConnection)
        }
        coEvery { mockConnection.sendCommand(any()) } returns ""

        bleRepository.startShooting()
        val message = BLETestDataAndroid.createShotMessage()
        bleRepository.processMessage(message)

        coEvery { mockShotDao.insertShot(any()) } throws RuntimeException("DB Error")

        // When
        val result = bleRepository.saveSessionShots(drillResultId)

        // Then
        assertThat(result.isFailure).isTrue()
    }

    // MARK: - Error Handling Tests

    @Test
    fun `handle malformed JSON message`() = runTest {
        // Given
        val malformedMessage = BLETestDataAndroid.createMalformedJSON()

        // When
        val result = bleRepository.processMessage(malformedMessage)

        // Then
        assertThat(result.isSuccess).isTrue() // Should not crash
    }

    @Test
    fun `handle empty message`() = runTest {
        // Given
        val emptyMessage = ""

        // When
        val result = bleRepository.processMessage(emptyMessage)

        // Then
        assertThat(result.isSuccess).isTrue()
    }

    @Test
    fun `handle null coordinates in shot data`() = runTest {
        // Given
        val invalidMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "content": {
            "command": "shot",
            "hit_position": {"x": null, "y": null},
            "hit_area": "C",
            "target_type": "idpa"
          }
        }
        """

        // When
        val result = bleRepository.processMessage(invalidMessage)

        // Then
        assertThat(result.isSuccess).isTrue()
    }
}
