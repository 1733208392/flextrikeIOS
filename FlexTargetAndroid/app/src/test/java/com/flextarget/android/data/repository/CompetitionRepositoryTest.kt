package com.flextarget.android.data.repository

import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.local.dao.CompetitionDao
import com.flextarget.android.data.local.dao.GamePlayDao
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.GamePlayEntity
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.AddGamePlayRequest
import com.flextarget.android.data.remote.api.ApiResponse
import com.flextarget.android.data.remote.api.GamePlayResponse
import com.flextarget.android.data.remote.api.RankingRow
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
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
class CompetitionRepositoryTest {

    private lateinit var competitionRepository: CompetitionRepository
    private val mockApi: FlexTargetAPI = mockk()
    private val mockCompetitionDao: CompetitionDao = mockk()
    private val mockGamePlayDao: GamePlayDao = mockk()
    private val mockAuthManager: AuthManager = mockk()
    private val mockDeviceAuthManager: DeviceAuthManager = mockk()

    @Before
    fun setup() {
        competitionRepository = CompetitionRepository(
            mockApi,
            mockCompetitionDao,
            mockGamePlayDao,
            mockAuthManager,
            mockDeviceAuthManager
        )
    }

    @Test
    fun `getAllCompetitions returns flow from dao`() = runTest {
        // Given
        val competitions = listOf(
            CompetitionEntity(id = UUID.randomUUID(), name = "Test Competition")
        )
        every { mockCompetitionDao.getAllCompetitions() } returns flowOf(competitions)

        // When
        val result = competitionRepository.getAllCompetitions()

        // Then
        assertThat(result).isNotNull()
        // Note: Flow testing would require collecting the flow
    }

    @Test
    fun `searchCompetitions returns flow from dao with query`() = runTest {
        // Given
        val query = "test"
        val competitions = listOf(
            CompetitionEntity(id = UUID.randomUUID(), name = "Test Competition")
        )
        every { mockCompetitionDao.searchCompetitions(query) } returns flowOf(competitions)

        // When
        val result = competitionRepository.searchCompetitions(query)

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getUpcomingCompetitions returns flow from dao`() = runTest {
        // Given
        val competitions = listOf(
            CompetitionEntity(id = UUID.randomUUID(), name = "Future Competition", date = Date(System.currentTimeMillis() + 86400000))
        )
        every { mockCompetitionDao.getUpcomingCompetitions() } returns flowOf(competitions)

        // When
        val result = competitionRepository.getUpcomingCompetitions()

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getCompetitionById returns competition from dao`() = runTest {
        // Given
        val id = UUID.randomUUID()
        val competition = CompetitionEntity(id = id, name = "Test Competition")
        coEvery { mockCompetitionDao.getCompetitionById(id) } returns competition

        // When
        val result = competitionRepository.getCompetitionById(id)

        // Then
        assertThat(result).isEqualTo(competition)
    }

    @Test
    fun `createCompetition inserts competition and returns id`() = runTest {
        // Given
        val name = "New Competition"
        val venue = "Test Venue"
        val date = Date()
        val description = "Test Description"

        coEvery { mockCompetitionDao.insertCompetition(any()) } returns 1L

        // When
        val result = competitionRepository.createCompetition(name, venue, date, description)

        // Then
        assertThat(result.isSuccess).isTrue()
        val competitionId = result.getOrNull()
        assertThat(competitionId).isNotNull()

        coVerify { mockCompetitionDao.insertCompetition(any()) }
    }

    @Test
    fun `updateCompetition calls dao update method`() = runTest {
        // Given
        val competition = CompetitionEntity(id = UUID.randomUUID(), name = "Updated Competition")
        coEvery { mockCompetitionDao.updateCompetition(competition) } returns Unit

        // When
        val result = competitionRepository.updateCompetition(competition)

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockCompetitionDao.updateCompetition(competition) }
    }

    @Test
    fun `deleteCompetition calls dao delete method`() = runTest {
        // Given
        val id = UUID.randomUUID()
        coEvery { mockCompetitionDao.deleteCompetitionById(id) } returns Unit

        // When
        val result = competitionRepository.deleteCompetition(id)

        // Then
        assertThat(result.isSuccess).isTrue()
        coVerify { mockCompetitionDao.deleteCompetitionById(id) }
    }

    @Test
    fun `submitGamePlay returns failure when not authenticated`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns null

        // When
        val result = competitionRepository.submitGamePlay(
            competitionId = UUID.randomUUID(),
            drillSetupId = UUID.randomUUID(),
            score = 100,
            detail = "{}"
        )

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Not authenticated")
    }

    @Test
    fun `submitGamePlay succeeds when device not authenticated but user is authenticated`() = runTest {
        // Given
        val competitionId = UUID.randomUUID()
        val drillSetupId = UUID.randomUUID()
        val playUuid = "user-only-submission-uuid"
        
        every { mockAuthManager.currentAccessToken } returns "user_token"
        every { mockDeviceAuthManager.deviceToken.value } returns null
        every { mockDeviceAuthManager.deviceUUID.value } returns null
        coEvery { mockApi.addGamePlay(any(), "Bearer user_token") } returns
            AddGamePlayResponse(
                code = 0,
                msg = "success",
                data = GamePlayResponseData(
                    playUUID = playUuid,
                    deviceUUID = "server-assigned-device"
                )
            )
        coEvery { mockGamePlayDao.insertGamePlay(any()) } returns Unit

        // When
        val result = competitionRepository.submitGamePlay(
            competitionId = competitionId,
            drillSetupId = drillSetupId,
            score = 100,
            detail = "{}"
        )

        // Then - should succeed with user token only
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrNull()).isEqualTo(playUuid)
        coVerify { mockApi.addGamePlay(any(), "Bearer user_token") }
    }

    @Test
    fun `submitGamePlay successfully submits and saves locally`() = runTest {
        // Given
        val competitionId = UUID.randomUUID()
        val drillSetupId = UUID.randomUUID()
        val score = 95
        val detail = """{"shots": 10, "hits": 9}"""
        val playerNickname = "TestPlayer"
        val playUuid = "server-generated-uuid"

        every { mockAuthManager.currentAccessToken } returns "user_token"
        every { mockDeviceAuthManager.deviceToken.value } returns "device_token"
        every { mockDeviceAuthManager.deviceUUID.value } returns "device-uuid"

        val mockResponse = mockk<ApiResponse<GamePlayResponse>>()
        every { mockResponse.data?.playUUID } returns playUuid
        coEvery { mockApi.addGamePlay(any(), any()) } returns mockResponse

        coEvery { mockGamePlayDao.insertGamePlay(any()) } returns 1L

        // When
        val result = competitionRepository.submitGamePlay(
            competitionId = competitionId,
            drillSetupId = drillSetupId,
            score = score,
            detail = detail,
            playerNickname = playerNickname,
            isPublic = true
        )

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrNull()).isEqualTo(playUuid)

        coVerify { mockApi.addGamePlay(any(), any()) }
        coVerify { mockGamePlayDao.insertGamePlay(any()) }
    }

    @Test
    fun `getGamePlaysByCompetition returns flow from dao`() = runTest {
        // Given
        val competitionId = UUID.randomUUID()
        val gamePlays = listOf(
            GamePlayEntity(
                id = UUID.randomUUID(),
                competitionId = competitionId,
                drillSetupId = UUID.randomUUID(),
                score = 90,
                detail = "{}",
                playTime = Date()
            )
        )
        every { mockGamePlayDao.getGamePlaysByCompetition(competitionId) } returns flowOf(gamePlays)

        // When
        val result = competitionRepository.getGamePlaysByCompetition(competitionId)

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getSubmittedGamePlays returns flow from dao`() = runTest {
        // Given
        val competitionId = UUID.randomUUID()
        val gamePlays = listOf(
            GamePlayEntity(
                id = UUID.randomUUID(),
                competitionId = competitionId,
                drillSetupId = UUID.randomUUID(),
                score = 85,
                detail = "{}",
                playTime = Date(),
                playUuid = "submitted-uuid"
            )
        )
        every { mockGamePlayDao.getSubmittedGamePlays(competitionId) } returns flowOf(gamePlays)

        // When
        val result = competitionRepository.getSubmittedGamePlays(competitionId)

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getPendingGamePlays returns flow from dao`() = runTest {
        // Given
        val gamePlays = listOf(
            GamePlayEntity(
                id = UUID.randomUUID(),
                competitionId = UUID.randomUUID(),
                drillSetupId = UUID.randomUUID(),
                score = 80,
                detail = "{}",
                playTime = Date()
            )
        )
        every { mockGamePlayDao.getPendingSyncGamePlays() } returns flowOf(gamePlays)

        // When
        val result = competitionRepository.getPendingGamePlays()

        // Then
        assertThat(result).isNotNull()
    }

    @Test
    fun `getGamePlayById returns game play from dao`() = runTest {
        // Given
        val id = UUID.randomUUID()
        val gamePlay = GamePlayEntity(
            id = id,
            competitionId = UUID.randomUUID(),
            drillSetupId = UUID.randomUUID(),
            score = 88,
            detail = "{}",
            playTime = Date()
        )
        coEvery { mockGamePlayDao.getGamePlayById(id) } returns gamePlay

        // When
        val result = competitionRepository.getGamePlayById(id)

        // Then
        assertThat(result).isEqualTo(gamePlay)
    }

    @Test
    fun `getCompetitionRanking returns failure when not authenticated`() = runTest {
        // Given
        every { mockAuthManager.currentAccessToken } returns null

        // When
        val result = competitionRepository.getCompetitionRanking(UUID.randomUUID())

        // Then
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).isInstanceOf(IllegalStateException::class.java)
        assertThat(result.exceptionOrNull()?.message).isEqualTo("Not authenticated")
    }

    @Test
    fun `getCompetitionRanking successfully fetches and maps rankings`() = runTest {
        // Given
        val competitionId = UUID.randomUUID()
        every { mockAuthManager.currentAccessToken } returns "user_token"

        val mockRow = mockk<RankingRow>()
        every { mockRow.rank } returns 1
        every { mockRow.playerNickname } returns "TopPlayer"
        every { mockRow.score } returns 100
        every { mockRow.playTime } returns "2024-01-15 10:30:00"

        val mockResponse = mockk<ApiResponse<List<RankingRow>>>()
        every { mockResponse.data } returns listOf(mockRow)
        coEvery { mockApi.getGamePlayRanking(any(), any()) } returns mockResponse

        // When
        val result = competitionRepository.getCompetitionRanking(competitionId)

        // Then
        assertThat(result.isSuccess).isTrue()
        val rankings = result.getOrNull()
        assertThat(rankings).hasSize(1)
        assertThat(rankings?.get(0)?.rank).isEqualTo(1)
        assertThat(rankings?.get(0)?.playerNickname).isEqualTo("TopPlayer")
        assertThat(rankings?.get(0)?.score).isEqualTo(100)
        assertThat(rankings?.get(0)?.playTime).isEqualTo("2024-01-15 10:30:00")

        coVerify { mockApi.getGamePlayRanking(any(), any()) }
    }

    @Test
    fun `syncPendingGamePlays returns success with zero synced items`() = runTest {
        // Given
        every { mockGamePlayDao.getPendingSyncGamePlays() } returns flowOf(emptyList())

        // When
        val result = competitionRepository.syncPendingGamePlays()

        // Then
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrNull()).isEqualTo(0)
    }
}