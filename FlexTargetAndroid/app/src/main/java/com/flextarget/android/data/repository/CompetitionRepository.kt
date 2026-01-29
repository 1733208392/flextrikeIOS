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
import kotlinx.coroutines.withContext
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
    private val deviceAuthManager: DeviceAuthManager
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
        try {
            val userToken = authManager.currentAccessToken
                ?: return@withContext Result.failure(IllegalStateException("Not authenticated"))
            
            // Device token is optional - allow submission with just user token
            val deviceToken = deviceAuthManager.deviceToken.value
            val deviceUuid = deviceAuthManager.deviceUUID.value
            
            // Format play time
            val playTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            
            // Build auth header: include device token if available, otherwise use just user token
            val authHeader = if (deviceToken != null && deviceUuid != null) {
                "Bearer $userToken|$deviceToken"
            } else {
                Log.w(TAG, "Device token not available, submitting with user token only")
                "Bearer $userToken"
            }
            
            // Call API to submit result
            val response = api.addGamePlay(
                AddGamePlayRequest(
                    game_type = competitionId.toString(),
                    game_ver = "1.0.0",
                    player_mobile = null,
                    player_nickname = playerNickname,
                    score = score,
                    detail = detail,
                    play_time = playTime,
                    is_public = isPublic,
                    namespace = "default"
                ),
                authHeader = authHeader
            )
            
            // Create local game play entity
            val gamePlay = GamePlayEntity(
                competitionId = competitionId,
                drillSetupId = drillSetupId,
                score = score,
                detail = detail,
                playTime = Date(),
                isPublic = isPublic,
                playerNickname = playerNickname,
                playUuid = response.data?.playUUID,
                submittedAt = Date()
            )
            
            // Save locally
            gamePlayDao.insertGamePlay(gamePlay)
            
            Log.d(TAG, "Game play submitted: ${response.data?.playUUID}")
            Result.success(response.data?.playUUID ?: gamePlay.id.toString())
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
            val pendingFlow = gamePlayDao.getPendingSyncGamePlays()
            var synced = 0
            
            // Note: In real implementation, collect from Flow and sync each
            Log.d(TAG, "Syncing pending game plays")
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
