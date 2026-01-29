package com.flextarget.android.data.remote.interceptor

import android.util.Log
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.TokenRefreshQueue
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * OkHttp Interceptor for automatic token management and 401 handling.
 * 
 * Responsibilities:
 * 1. Add Authorization header with current token to all requests
 * 2. Intercept 401 responses (invalid/expired token)
 * 3. Trigger token refresh via TokenRefreshQueue
 * 4. Retry request with new token (max 2 attempts)
 * 5. If refresh fails, return 401 to caller for logout handling
 */
@Singleton
class AuthInterceptor @Inject constructor(
    private val authManager: AuthManager,
    private val tokenRefreshQueue: TokenRefreshQueue
) : Interceptor {
    
    private var refreshAttempts = 0
    private val maxRefreshAttempts = 2
    
    override fun intercept(chain: Interceptor.Chain): Response {
        var request = chain.request()
        
        // Add authorization header if token available
        val token = authManager.currentAccessToken
        if (token != null) {
            request = request.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        }
        
        var response = chain.proceed(request)
        
        // Handle 401 Unauthorized - attempt token refresh
        if (response.code == 401 && refreshAttempts < maxRefreshAttempts) {
            refreshAttempts++
            
            val newToken = try {
                // Attempt to refresh token
                val refreshToken = authManager.currentRefreshToken
                if (refreshToken != null) {
                    runBlocking {
                        tokenRefreshQueue.queueRefresh(refreshToken)
                    }
                    // Wait a bit for refresh to complete
                    Thread.sleep(100)
                    authManager.currentAccessToken
                } else {
                    null
                }
            } catch (e: Exception) {
                Log.w(TAG, "Token refresh failed", e)
                null
            }
            
            // If refresh succeeded and token changed, retry original request
            if (newToken != null && newToken != token) {
                val retryRequest = request.newBuilder()
                    .header("Authorization", "Bearer $newToken")
                    .build()
                
                response.close()
                response = chain.proceed(retryRequest)
                refreshAttempts = 0
            } else {
                // Refresh failed or no new token, return original 401
                refreshAttempts = 0
            }
        } else {
            refreshAttempts = 0
        }
        
        return response
    }
    
    companion object {
        private const val TAG = "AuthInterceptor"
    }
}
