package com.flextarget.android.data.auth

import android.util.Log
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.RefreshTokenRequest
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import retrofit2.HttpException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * TokenRefreshQueue: Prevents concurrent token refresh calls using 30-second debounce.
 * 
 * When multiple API calls detect 401 simultaneously:
 * 1. First caller acquires Mutex lock
 * 2. Performs refresh call to server
 * 3. Updates tokens in AuthManager
 * 4. Releases lock
 * 5. Other callers waiting on Mutex proceed with new token
 * 
 * Debounce delay (30 seconds) prevents rapid refresh spam if multiple 401s arrive in quick succession.
 */
@Singleton
class TokenRefreshQueue @Inject constructor(
    private var authManager: AuthManager?,
    private val userApiService: FlexTargetAPI
) {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val refreshMutex = Mutex()
    private var debounceJob: Job? = null
    
    private val debounceDelay = 30_000L // 30 seconds
    
    /**
     * Queue a token refresh request with debouncing
     * 
     * @param refreshToken The refresh token to use for exchange
     */
    suspend fun queueRefresh(refreshToken: String) {
        // Cancel pending debounce job
        debounceJob?.cancel()
        
        // Start new debounce delay
        debounceJob = scope.launch {
            delay(debounceDelay)
            if (isActive) {
                performRefresh(refreshToken)
            }
        }
        
        Log.d(TAG, "Token refresh queued with 30s debounce")
    }
    
    /**
     * Perform actual token refresh (serialized by Mutex)
     */
    private suspend fun performRefresh(refreshToken: String) = refreshMutex.withLock {
        try {
            Log.d(TAG, "Performing token refresh")
            val response = userApiService.refreshToken(
                RefreshTokenRequest(refresh_token = refreshToken)
            )
            
            // Update tokens in AuthManager
            val mgr = authManager ?: throw Exception("AuthManager not set on TokenRefreshQueue")
            mgr.updateTokens(
                accessToken = response.data?.accessToken ?: throw Exception("No access token in response"),
                refreshToken = response.data.refreshToken ?: refreshToken
            )
            
            Log.d(TAG, "Token refresh successful")
        } catch (e: HttpException) {
            when (e.code()) {
                401 -> {
                    // 401 on token refresh = refresh token is invalid
                    // User's session is expired or token revoked
                    Log.e(TAG, "Token refresh returned 401 - refresh token invalid. Clearing auth.")
                    authManager?.handleInvalidRefreshToken()
                }
                else -> {
                    Log.e(TAG, "Token refresh failed with HTTP ${e.code()}: ${e.message()}", e)
                    throw e
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh failed: ${e.message}", e)
            // Refresh failed - let caller handle error
            throw e
        }
    }

    /**
     * Immediately perform token refresh and wait for result.
     * Cancels any pending debounce job and performs the refresh synchronously.
     */
    suspend fun refreshNow(refreshToken: String) {
        // Cancel pending debounce job
        debounceJob?.cancel()

        // performRefresh already serializes via refreshMutex
        performRefresh(refreshToken)
    }

    /**
     * Set the AuthManager reference after construction to avoid circular DI issues.
     */
    fun setAuthManager(mgr: AuthManager) {
        this.authManager = mgr
    }
    
    companion object {
        private const val TAG = "TokenRefreshQueue"
    }
}
