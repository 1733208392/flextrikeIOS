package com.flextarget.android.data.auth

import android.util.Log
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.RefreshTokenRequest
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
    private val authManager: AuthManager,
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
            authManager.updateTokens(
                accessToken = response.data?.accessToken ?: throw Exception("No access token in response"),
                refreshToken = response.data.refreshToken ?: refreshToken
            )
            
            Log.d(TAG, "Token refresh successful")
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh failed: ${e.message}", e)
            // Refresh failed - let caller handle error (will be converted to 401 by interceptor)
            throw e
        }
    }
    
    companion object {
        private const val TAG = "TokenRefreshQueue"
    }
}
