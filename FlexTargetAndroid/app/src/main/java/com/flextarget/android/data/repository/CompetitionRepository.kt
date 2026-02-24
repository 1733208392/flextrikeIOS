package com.flextarget.android.data.repository

import android.util.Log
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.local.dao.CompetitionDao
import com.flextarget.android.data.local.dao.GamePlayDao
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.GamePlayEntity
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.AddGamePlayRequest
import com.flextarget.android.data.remote.api.GamePlayRankingRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import retrofit2.HttpException
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * CompetitionRepository: Manages competition data and game play submissions
 * 
 * Responsibilities:
 * - Fetch competitions from API and cache locally
 * - Manage competition CRUD operations
 * - Submit drill results as game play entries
 * - Track synced vs pending results
 * - Fetch leaderboards and rankings
 */
@Singleton
class CompetitionRepository @Inject constructor(
    private val api: FlexTargetAPI,
    private val competitionDao: CompetitionDao,
    private val gamePlayDao: GamePlayDao,
    private val authManager: AuthManager,
    private val deviceAuthManager: DeviceAuthManager,
    private val workManager: androidx.work.WorkManager? = null
) {
    
    /**
     * Get all competitions
     */
    fun getAllCompetitions(): Flow<List<CompetitionEntity>> {
        return competitionDao.getAllCompetitions()
    }
    
    /**
     * Search competitions by name
     */
    fun searchCompetitions(query: String): Flow<List<CompetitionEntity>> {
        return competitionDao.searchCompetitions(query)
    }
    
    /**
     * Get upcoming competitions (future dates)
     */
    fun getUpcomingCompetitions(): Flow<List<CompetitionEntity>> {
        return competitionDao.getUpcomingCompetitions()
    }
    
    /**
     * Get competition by ID
     */
    suspend fun getCompetitionById(id: UUID): CompetitionEntity? = withContext(Dispatchers.IO) {
        try {
            competitionDao.getCompetitionById(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get competition by ID", e)
            null
        }
    }
    
    /**
     * Create new competition locally
     */
    suspend fun createCompetition(
        name: String,
        venue: String? = null,
        date: Date = Date(),
        description: String? = null,
        drillSetupId: UUID? = null
    ): Result<UUID> = withContext(Dispatchers.IO) {
        try {
            val competition = CompetitionEntity(
                name = name,
                venue = venue,
                date = date,
                description = description,
                drillSetupId = drillSetupId
            )
            competitionDao.insertCompetition(competition)
            Log.d(TAG, "Competition created: ${competition.id}")
            Result.success(competition.id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create competition", e)
            Result.failure(e)
        }
    }
    
    /**
     * Update competition
     */
    suspend fun updateCompetition(competition: CompetitionEntity): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                competitionDao.updateCompetition(competition)
                Log.d(TAG, "Competition updated: ${competition.id}")
                Result.success(Unit)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update competition", e)
                Result.failure(e)
            }
        }
    
    /**
     * Delete competition
     */
    suspend fun deleteCompetition(id: UUID): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            competitionDao.deleteCompetitionById(id)
            Log.d(TAG, "Competition deleted: $id")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete competition", e)
            Result.failure(e)
        }
    }
    
    /**
     * Submit game play result (drill execution result)
     * Requires both user and device authentication.
     * 
     * @param competitionId Competition UUID (game_type)
     * @param drillSetupId Drill setup ID
     * @param score Player's score
     * @param detail JSON string of shot details
     * @param playerNickname Optional player nickname for public submissions
     * @param isPublic Whether result should be public (visible on leaderboard)
     */
    suspend fun submitGamePlay(
        competitionId: UUID,
        drillSetupId: UUID,
        score: Int,
        detail: String,
        playerNickname: String? = null,
        isPublic: Boolean = false
    ): Result<String> = withContext(Dispatchers.IO) {
        // Declare localGamePlay outside try so retry/catch branches can access it
        var localGamePlay: GamePlayEntity? = null
        try {
            val userToken = authManager.currentAccessToken
                ?: return@withContext Result.failure(IllegalStateException("Not authenticated"))

            // Always create and persist a local GamePlay record so results are not lost
            // if network submission fails. submittedAt == null indicates pending sync.
            localGamePlay = GamePlayEntity(
                competitionId = competitionId,
                drillSetupId = drillSetupId,
                score = score,
                detail = detail,
                playTime = Date(),
                isPublic = isPublic,
                playerNickname = playerNickname,
                playerMobile = authManager.currentUser.value?.mobile ?: "",
                playUuid = null,
                submittedAt = null
            )

            // Persist pending local copy immediately
            gamePlayDao.insertGamePlay(localGamePlay)

            // Format play time
            val playTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())

            // Build auth header: requires both user and device tokens
            val authHeader = try {
                deviceAuthManager.getAuthorizationHeader(userToken, requireDeviceToken = true)
            } catch (ise: IllegalStateException) {
                Log.e(TAG, "Device token required but not available: ${ise.message}")
                // Leave local record pending and schedule background sync
                try {
                    workManager?.let { wm ->
                        val request = androidx.work.OneTimeWorkRequestBuilder<SubmitPendingWorker>()
                            .setConstraints(
                                androidx.work.Constraints.Builder()
                                    .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                                    .build()
                            )
                            .build()

                        wm.enqueueUniqueWork(
                            "submit_pending_gameplays",
                            androidx.work.ExistingWorkPolicy.KEEP,
                            request
                        )
                    }
                } catch (we: Exception) {
                    Log.w(TAG, "Failed to enqueue SubmitPendingWorker when device token missing", we)
                }

                return@withContext Result.failure(ise)
            }

            // Call API to submit result
            val response = api.addGamePlay(
                AddGamePlayRequest(
                    game_type = competitionId.toString(),
                    game_ver = "1.0.0",
                    player_mobile = authManager.currentUser.value?.mobile ?: "",
                    player_nickname = playerNickname,
                    score = score,
                    detail = detail,
                    play_time = playTime,
                    is_public = isPublic,
                    namespace = "default"
                ),
                authHeader = authHeader
            )

            // Update local record with server-assigned play UUID and submitted timestamp
            val updatedGamePlay = localGamePlay.copy(
                playUuid = response.data?.playUUID,
                submittedAt = Date(),
                updatedAt = Date()
            )
            gamePlayDao.updateGamePlay(updatedGamePlay)

            Log.d(TAG, "Game play submitted: ${response.data?.playUUID}")
            Result.success(response.data?.playUUID ?: updatedGamePlay.id.toString())
        } catch (e: retrofit2.HttpException) {
            // Handle HTTP exceptions (e.g., 401 Unauthorized)
            Log.e(TAG, "HTTP exception during game play submission: ${e.code()} ${e.message}", e)
            if (e.code() == 401) {
                Log.w(TAG, "Token expired during game play submission (HTTP 401) - attempting immediate refresh")
                val refreshed = try {
                    authManager.requestImmediateTokenRefresh()
                } catch (re: Exception) {
                    false
                }

                if (refreshed) {
                    // Retry the submission once with new token
                    try {
                        val newUserToken = authManager.currentAccessToken
                            ?: return@withContext Result.failure(IllegalStateException("Not authenticated after refresh"))

                        val authHeaderRetry = deviceAuthManager.getAuthorizationHeader(newUserToken, requireDeviceToken = true)

                        val retryResponse = api.addGamePlay(
                            AddGamePlayRequest(
                                game_type = competitionId.toString(),
                                game_ver = "1.0.0",
                                player_mobile = authManager.currentUser.value?.mobile ?: "",
                                player_nickname = playerNickname,
                                score = score,
                                detail = detail,
                                play_time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date()),
                                is_public = isPublic,
                                namespace = "default"
                            ),
                            authHeader = authHeaderRetry
                        )

                        val baseLocal = localGamePlay ?: return@withContext Result.failure(IllegalStateException("Local gameplay missing"))
                        val updatedGamePlay = baseLocal.copy(
                            playUuid = retryResponse.data?.playUUID,
                            submittedAt = Date(),
                            updatedAt = Date()
                        )
                        gamePlayDao.updateGamePlay(updatedGamePlay)
                        Log.d(TAG, "Game play submitted after refresh: ${retryResponse.data?.playUUID}")
                        return@withContext Result.success(retryResponse.data?.playUUID ?: updatedGamePlay.id.toString())
                    } catch (e2: Exception) {
                        Log.e(TAG, "Retry after refresh failed", e2)
                        authManager.logout()
                        return@withContext Result.failure(Exception("401"))
                    }
                }

                // Refresh failed - force logout
                authManager.logout()
                return@withContext Result.failure(Exception("401"))
            }
            Result.failure(e)
        } catch (e: IOException) {
            // Network issue — leave local record pending and schedule background sync via WorkManager
            Log.w(TAG, "Network unavailable during game play submission", e)

            try {
                workManager?.let { wm ->
                    val request = androidx.work.OneTimeWorkRequestBuilder<SubmitPendingWorker>()
                        .setConstraints(
                            androidx.work.Constraints.Builder()
                                .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                                .build()
                        )
                        .build()

                    wm.enqueueUniqueWork(
                        "submit_pending_gameplays",
                        androidx.work.ExistingWorkPolicy.KEEP,
                        request
                    )
                }
            } catch (we: Exception) {
                Log.w(TAG, "Failed to enqueue SubmitPendingWorker", we)
            }

            Result.failure(IllegalStateException("NetworkUnavailable"))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to submit game play", e)
            Result.failure(e)
        }
    }
    
    /**
     * Get game play results for a competition
     */
    fun getGamePlaysByCompetition(competitionId: UUID): Flow<List<GamePlayEntity>> {
        return gamePlayDao.getGamePlaysByCompetition(competitionId)
    }
    
    /**
     * Get submitted game plays (synced with server)
     */
    fun getSubmittedGamePlays(competitionId: UUID): Flow<List<GamePlayEntity>> {
        return gamePlayDao.getSubmittedGamePlays(competitionId)
    }
    
    /**
     * Get pending game plays (not yet synced)
     */
    fun getPendingGamePlays(): Flow<List<GamePlayEntity>> {
        return gamePlayDao.getPendingSyncGamePlays()
    }
    
    /**
     * Get game play by ID
     */
    suspend fun getGamePlayById(id: UUID): GamePlayEntity? = withContext(Dispatchers.IO) {
        try {
            gamePlayDao.getGamePlayById(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get game play", e)
            null
        }
    }
    
    /**
     * Get leaderboard/ranking for a competition
     */
    suspend fun getCompetitionRanking(
        competitionId: UUID,
        page: Int = 1,
        limit: Int = 20
    ): Result<List<RankingData>> = withContext(Dispatchers.IO) {
        try {
            val userToken = authManager.currentAccessToken
                ?: return@withContext Result.failure(IllegalStateException("Not authenticated"))
            
            val response = api.getGamePlayRanking(
                GamePlayRankingRequest(
                    game_type = competitionId.toString(),
                    game_ver = "1.0.0",
                    namespace = "default",
                    page = page,
                    limit = limit
                ),
                authHeader = "Bearer $userToken"
            )
            
            val rankings = response.data?.map { row ->
                RankingData(
                    rank = row.rank,
                    playerNickname = row.playerNickname,
                    score = row.score,
                    playTime = row.playTime
                )
            } ?: emptyList()
            
            Log.d(TAG, "Fetched rankings for competition: ${rankings.size} entries")
            Result.success(rankings)
        } catch (e: retrofit2.HttpException) {
            // Handle HTTP exceptions (e.g., 401 Unauthorized)
            Log.e(TAG, "HTTP exception during ranking fetch: ${e.code()} ${e.message}", e)
            if (e.code() == 401) {
                Log.w(TAG, "Token expired during ranking fetch (HTTP 401)")
                authManager.logout()
                return@withContext Result.failure(Exception("401"))
            }
            Result.failure(e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch competition ranking", e)
            Result.failure(e)
        }
    }
    
    /**
     * Sync pending game plays to server
     */
    suspend fun syncPendingGamePlays(): Result<Int> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Syncing pending game plays")
            val pending = try { gamePlayDao.getPendingSyncGamePlays().first() } catch (e: Exception) {
                Log.e(TAG, "Failed to load pending game plays from DB", e)
                return@withContext Result.failure(e)
            }

            var synced = 0

            for (play in pending) {
                try {
                    val userToken = authManager.currentAccessToken
                    if (userToken == null) {
                        Log.w(TAG, "No user token available while syncing pending plays")
                        continue
                    }

                    val authHeader: String
                    try {
                        authHeader = deviceAuthManager.getAuthorizationHeader(userToken, requireDeviceToken = true)
                    } catch (ise: IllegalStateException) {
                        Log.w(TAG, "Device token not available for pending play ${play.id}")
                        continue
                    }

                    val playTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(play.playTime)

                    val response = api.addGamePlay(
                        AddGamePlayRequest(
                            game_type = play.competitionId.toString(),
                            game_ver = "1.0.0",
                            player_mobile = play.playerMobile ?: "",
                            player_nickname = play.playerNickname,
                            score = play.score,
                            detail = play.detail,
                            play_time = playTime,
                            is_public = play.isPublic,
                            namespace = play.namespace
                        ),
                        authHeader = authHeader
                    )

                    val updated = play.copy(
                        playUuid = response.data?.playUUID,
                        submittedAt = Date(),
                        updatedAt = Date()
                    )
                    gamePlayDao.updateGamePlay(updated)
                    synced++
                } catch (e: retrofit2.HttpException) {
                    Log.e(TAG, "HTTP error syncing pending play ${play.id}: ${e.code()}", e)
                    if (e.code() == 401) {
                        Log.w(TAG, "Auth error while syncing pending plays (HTTP 401) - attempting immediate refresh")
                        val refreshed = try { authManager.requestImmediateTokenRefresh() } catch (re: Exception) { false }
                        if (refreshed) {
                            try {
                                val newUserToken = authManager.currentAccessToken ?: continue
                                val authHeader = try {
                                    deviceAuthManager.getAuthorizationHeader(newUserToken, requireDeviceToken = true)
                                } catch (ise: IllegalStateException) {
                                    Log.w(TAG, "Device token not available for pending play ${play.id} after refresh")
                                    continue
                                }

                                val playTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(play.playTime)

                                val retryResp = api.addGamePlay(
                                    AddGamePlayRequest(
                                        game_type = play.competitionId.toString(),
                                        game_ver = "1.0.0",
                                        player_mobile = play.playerMobile ?: "",
                                        player_nickname = play.playerNickname,
                                        score = play.score,
                                        detail = play.detail,
                                        play_time = playTime,
                                        is_public = play.isPublic,
                                        namespace = play.namespace
                                    ),
                                    authHeader = authHeader
                                )

                                val updated = play.copy(
                                    playUuid = retryResp.data?.playUUID,
                                    submittedAt = Date(),
                                    updatedAt = Date()
                                )
                                gamePlayDao.updateGamePlay(updated)
                                synced++
                                continue
                            } catch (e2: Exception) {
                                Log.e(TAG, "Retry after refresh failed for pending play ${play.id}", e2)
                                authManager.logout()
                                return@withContext Result.failure(Exception("401"))
                            }
                        }

                        // Refresh failed - logout and abort
                        authManager.logout()
                        return@withContext Result.failure(Exception("401"))
                    }
                    // For other HTTP errors, leave the item pending and continue
                } catch (e: IOException) {
                    Log.w(TAG, "Network error while syncing pending play ${play.id}", e)
                    // Network problem: abort sync attempt and retry later
                    return@withContext Result.failure(IllegalStateException("NetworkUnavailable"))
                } catch (e: Exception) {
                    Log.e(TAG, "Unexpected error while syncing pending play ${play.id}", e)
                    // Continue with other items
                }
            }

            Result.success(synced)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync pending game plays", e)
            Result.failure(e)
        }
    }
    
    companion object {
        private const val TAG = "CompetitionRepository"
    }
}

/**
 * Data class for leaderboard ranking data
 */
data class RankingData(
    val rank: Int,
    val playerNickname: String?,
    val score: Int,
    val playTime: String
)
