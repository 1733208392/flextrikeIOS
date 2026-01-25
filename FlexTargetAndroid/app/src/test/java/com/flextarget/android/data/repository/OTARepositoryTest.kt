package com.flextarget.android.data.repository

import androidx.work.WorkManager
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.remote.api.ApiResponse
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.OTAVersionResponse
import com.flextarget.android.data.remote.api.OTAHistoryResponse
import com.flextarget.android.data.remote.api.OTAVersionRow
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date

@RunWith(RobolectricTestRunner::class)
class OTARepositoryTest {

    private lateinit var otaRepository: OTARepository
    private val mockApi: FlexTargetAPI = mockk()
    private val mockAuthManager: AuthManager = mockk()
    private val mockWorkManager: WorkManager = mockk()

    @Before
    fun setup() {
        otaRepository = OTARepository(mockApi, mockAuthManager, mockWorkManager)
    }

    @Test
    fun `initial OTA state is IDLE`() = runTest {
        // When
        val initialState = otaRepository.currentState.first()

        // Then
        assertThat(initialState).isEqualTo(OTAState.IDLE)
    }

    @Test
    fun `initial OTA progress is IDLE`() = runTest {
        // When
        val initialProgress = otaRepository.otaProgress.first()

        // Then
        assertThat(initialProgress.state).isEqualTo(OTAState.IDLE)
    }

    @Test
    fun `checkForUpdates returns failure when not authenticated`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns null

        // When
        val result = otaRepository.checkForUpdates("test-device-token")

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Not authenticated")
    }

    @Test
    fun `checkForUpdates successfully fetches and processes update info`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns "user_token"

        val mockData = mockk<OTAVersionResponse>()
        every { mockData.version } returns "2.1.0"
        every { mockData.address } returns "https://example.com/update.apk"
        every { mockData.checksum } returns "abc123"

        val mockResponse = mockk<ApiResponse<OTAVersionResponse>>()
        every { mockResponse.data } returns mockData
        coEvery { mockApi.getLatestOTAVersion(any()) } returns mockResponse

        // When
        val result = otaRepository.checkForUpdates("test-device-token")

        // Then
        assertThat(result.isSuccess).isTrue()
        val versionInfo = result.getOrNull()
        assertThat(versionInfo).isNotNull()
        assertThat(versionInfo?.version).isEqualTo("2.1.0")
        assertThat(versionInfo?.fileUrl).isEqualTo("https://example.com/update.apk")
        assertThat(versionInfo?.checksum).isEqualTo("abc123")

        // Verify state changes
        assertThat(otaRepository.currentState.first()).isEqualTo(OTAState.UPDATE_AVAILABLE)

        coVerify { mockApi.getLatestOTAVersion(any()) }
    }

    @Test
    fun `checkForUpdates handles no update available`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns "user_token"

        val mockResponse = mockk<ApiResponse<OTAVersionResponse>>()
        every { mockResponse.data } returns null
        coEvery { mockApi.getLatestOTAVersion(any()) } returns mockResponse

        // When
        val result = otaRepository.checkForUpdates("test-device-token")

        // Then
        assertThat(result.isSuccess).isTrue()
        val versionInfo = result.getOrNull()
        assertThat(versionInfo).isNull()

        // Verify state remains IDLE
        assertThat(otaRepository.currentState.first()).isEqualTo(OTAState.IDLE)
    }

    @Test
    fun `prepareUpdate returns failure when no update available`() = runTest {
        // When
        val result = otaRepository.prepareUpdate()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("No update available")
    }

    @Test
    fun `prepareUpdate successfully downloads and prepares update`() = runTest {
        // Given - set current update info
        val updateInfo = OTAVersionInfo(
            version = "2.1.0",
            description = "Test update",
            fileUrl = "https://example.com/update.apk",
            fileSize = 1024L,
            checksum = "abc123",
            releaseDate = Date()
        )
        otaRepository.javaClass.getDeclaredField("currentUpdateInfo").apply {
            isAccessible = true
            set(otaRepository, updateInfo)
        }

        // When
        val result = otaRepository.prepareUpdate()

        // Then
        assertThat(result.isSuccess).isTrue()

        // Verify final state
        assertThat(otaRepository.currentState.first()).isEqualTo(OTAState.READY)
    }

    @Test
    fun `verifyUpdate returns failure when no update to verify`() = runTest {
        // When
        val result = otaRepository.verifyUpdate()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("No update to verify")
    }

    @Test
    fun `verifyUpdate successfully verifies update integrity`() = runTest {
        // Given - set current update info
        val updateInfo = OTAVersionInfo(
            version = "2.1.0",
            description = "Test update",
            fileUrl = "https://example.com/update.apk",
            fileSize = 1024L,
            checksum = "abc123",
            releaseDate = Date()
        )
        otaRepository.javaClass.getDeclaredField("currentUpdateInfo").apply {
            isAccessible = true
            set(otaRepository, updateInfo)
        }

        // When
        val result = otaRepository.verifyUpdate()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrNull()).isTrue()
    }

    @Test
    fun `installUpdate successfully installs update`() = runTest {
        // When
        val result = otaRepository.installUpdate()

        // Then
        assertThat(result.isSuccess).isTrue()

        // Verify final state
        assertThat(otaRepository.currentState.first()).isEqualTo(OTAState.COMPLETE)
    }

    @Test
    fun `getUpdateHistory returns failure when not authenticated`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns null

        // When
        val result = otaRepository.getUpdateHistory()

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Not authenticated")
    }

    @Test
    fun `getUpdateHistory successfully fetches history`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns "user_token"

        val mockRow = mockk<OTAVersionRow>()
        every { mockRow.version } returns "2.0.0"

        val mockResponse = mockk<ApiResponse<OTAHistoryResponse>>()
        every { mockResponse.data?.rows } returns listOf(mockRow)
        coEvery { mockApi.getOTAHistory(any()) } returns mockResponse

        // When
        val result = otaRepository.getUpdateHistory()

        // Then
        assertThat(result.isSuccess).isTrue()
        val history = result.getOrNull()
        assertThat(history).hasSize(1)
        assertThat(history?.get(0)?.version).isEqualTo("2.0.0")

        coVerify { mockApi.getOTAHistory(any()) }
    }

    @Test
    fun `cancelUpdate clears update info and resets state`() = runTest {
        // Given - set current update info
        val updateInfo = OTAVersionInfo(
            version = "2.1.0",
            description = "Test update",
            fileUrl = "https://example.com/update.apk",
            fileSize = 1024L,
            checksum = "abc123",
            releaseDate = Date()
        )
        otaRepository.javaClass.getDeclaredField("currentUpdateInfo").apply {
            isAccessible = true
            set(otaRepository, updateInfo)
        }

        // When
        val result = otaRepository.cancelUpdate()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(otaRepository.getCurrentUpdateInfo()).isNull()
        assertThat(otaRepository.currentState.first()).isEqualTo(OTAState.IDLE)
    }

    @Test
    fun `getCurrentUpdateInfo returns stored update info`() = runTest {
        // Given - set current update info
        val updateInfo = OTAVersionInfo(
            version = "2.1.0",
            description = "Test update",
            fileUrl = "https://example.com/update.apk",
            fileSize = 1024L,
            checksum = "abc123",
            releaseDate = Date()
        )
        otaRepository.javaClass.getDeclaredField("currentUpdateInfo").apply {
            isAccessible = true
            set(otaRepository, updateInfo)
        }

        // When
        val result = otaRepository.getCurrentUpdateInfo()

        // Then
        assertThat(result).isEqualTo(updateInfo)
    }

    @Test
    fun `download cache path management works correctly`() = runTest {
        // Given
        val testPath = "/cache/ota"

        // When
        otaRepository.setDownloadCachePath(testPath)

        // Then
        assertThat(otaRepository.getDownloadCachePath()).isEqualTo(testPath)
    }
}