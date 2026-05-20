package com.flextarget.android.data.repository

import android.util.Log
import com.flextarget.android.data.remote.api.IpscApi
import com.flextarget.android.data.remote.api.IpscMatch
import com.flextarget.android.data.remote.api.IpscScoreSubmitData
import com.flextarget.android.data.remote.api.IpscScoreSubmitRequest
import com.flextarget.android.data.remote.api.IpscStage
import com.flextarget.android.data.remote.api.IpscSquad
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Repository for IPSC Match Management API calls.
 *
 * Wraps 接口 1 (squad queue), 接口 2 (submit score), and 接口 3 (matches list).
 * Results are cached in memory with a 5-minute TTL.
 * Pass forceRefresh = true to bypass the cache.
 */
class IpscRepository(private val api: IpscApi) {

    private companion object {
        const val TAG = "IpscRepository"
        const val CACHE_TTL_MS = 5 * 60 * 1000L  // 5 minutes
    }

    // ---- in-memory cache ----

    @Volatile private var cachedMatches: List<IpscMatch>? = null
    @Volatile private var matchesCachedAt: Long = 0L

    // matchId → (cachedAtMs, squads)
    private val squadCache = mutableMapOf<Int, Pair<Long, List<IpscSquad>>>()

    // matchId → (cachedAtMs, stages)
    private val stageCache = mutableMapOf<Int, Pair<Long, List<IpscStage>>>()

    // ---- public API ----

    /**
     * Fetch all matches (接口 3).
     * Cached for [CACHE_TTL_MS] ms; pass [forceRefresh] = true to bypass.
     */
    suspend fun getMatches(forceRefresh: Boolean = false): Result<List<IpscMatch>> =
        withContext(Dispatchers.IO) {
            val now = System.currentTimeMillis()
            if (!forceRefresh) {
                val cached = cachedMatches
                if (cached != null && now - matchesCachedAt < CACHE_TTL_MS) {
                    Log.d(TAG, "getMatches: cache hit (${cached.size} matches)")
                    return@withContext Result.success(cached)
                }
            }
            try {
                val response = api.getMatches()
                if (response.success && response.data != null) {
                    cachedMatches = response.data
                    matchesCachedAt = now
                    Log.d(TAG, "getMatches: fetched ${response.data.size} matches")
                    Result.success(response.data)
                } else {
                    Result.failure(Exception(response.error ?: "Failed to load matches"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "getMatches error", e)
                Result.failure(e)
            }
        }

    /**
     * Fetch squad queue for a match (接口 1).
     * Cached per [matchId] for [CACHE_TTL_MS] ms; pass [forceRefresh] = true to bypass.
     */
    suspend fun getSquadQueue(matchId: Int, forceRefresh: Boolean = false): Result<List<IpscSquad>> =
        withContext(Dispatchers.IO) {
            val now = System.currentTimeMillis()
            if (!forceRefresh) {
                val entry = synchronized(squadCache) { squadCache[matchId] }
                if (entry != null && now - entry.first < CACHE_TTL_MS) {
                    Log.d(TAG, "getSquadQueue($matchId): cache hit (${entry.second.size} squads)")
                    return@withContext Result.success(entry.second)
                }
            }
            try {
                val response = api.getSquadQueue(matchId)
                if (response.success && response.data != null) {
                    synchronized(squadCache) {
                        squadCache[matchId] = Pair(now, response.data)
                    }
                    Log.d(TAG, "getSquadQueue($matchId): fetched ${response.data.size} squads")
                    Result.success(response.data)
                } else {
                    Result.failure(Exception(response.error ?: "Failed to load squad queue"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "getSquadQueue($matchId) error", e)
                Result.failure(e)
            }
        }

    /**
     * Fetch stages for a match.
     * Cached per [matchId] for [CACHE_TTL_MS] ms; pass [forceRefresh] = true to bypass.
     */
    suspend fun getStages(matchId: Int, forceRefresh: Boolean = false): Result<List<IpscStage>> =
        withContext(Dispatchers.IO) {
            val now = System.currentTimeMillis()
            if (!forceRefresh) {
                val entry = synchronized(stageCache) { stageCache[matchId] }
                if (entry != null && now - entry.first < CACHE_TTL_MS) {
                    Log.d(TAG, "getStages($matchId): cache hit (${entry.second.size} stages)")
                    return@withContext Result.success(entry.second)
                }
            }
            try {
                val response = api.getStages(matchId)
                if (response.success && response.data != null) {
                    synchronized(stageCache) {
                        stageCache[matchId] = Pair(now, response.data)
                    }
                    Log.d(TAG, "getStages($matchId): fetched ${response.data.size} stages")
                    Result.success(response.data)
                } else {
                    Result.failure(Exception(response.error ?: "Failed to load stages"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "getStages($matchId) error", e)
                Result.failure(e)
            }
        }

    /**
     * Submit a FlexTarget score for a shooter/stage (接口 2).
     * Not cached — always performs a network call.
     */
    suspend fun submitScore(
        matchId: Int,
        request: IpscScoreSubmitRequest
    ): Result<IpscScoreSubmitData> = withContext(Dispatchers.IO) {
        try {
            val response = api.submitScore(matchId, request)
            if (response.success && response.data != null) {
                Log.d(TAG, "submitScore: hitFactor=${response.data.hitFactor}")
                Result.success(response.data)
            } else {
                Result.failure(Exception(response.error ?: "Score submission failed"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "submitScore error", e)
            Result.failure(e)
        }
    }

    /** Invalidate all caches (call after a successful submit if freshness matters). */
    fun invalidateCache(matchId: Int? = null) {
        if (matchId == null) {
            cachedMatches = null
            matchesCachedAt = 0L
            synchronized(squadCache) { squadCache.clear() }
            synchronized(stageCache) { stageCache.clear() }
        } else {
            synchronized(squadCache) { squadCache.remove(matchId) }
            synchronized(stageCache) { stageCache.remove(matchId) }
        }
    }
}
