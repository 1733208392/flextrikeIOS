package com.flextarget.android.data.remote.interceptor

import android.util.Log
import com.flextarget.android.di.AppContainer
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * AuthInterceptor: on 401 or expired-400 responses, attempt an immediate token refresh
 * and retry the failed request once with updated Authorization header. If refresh
 * fails or retry still returns 401/expired, call logout.
 */
@Singleton
class AuthInterceptor @Inject constructor() : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        val response = chain.proceed(request)

        // If server explicitly indicates device token invalid/expired, clear device auth and return.
        if (response.code == 400) {
            try {
                val body = response.peekBody(Long.MAX_VALUE).string()
                if (isDeviceTokenError(body)) {
                    Log.w(TAG, "Server indicates device token error - clearing device auth")
                    try {
                        Thread {
                            runBlocking { AppContainer.deviceAuthManager.clearDeviceAuth() }
                        }.start()
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to clear device auth", t)
                    }
                    return response
                }
            } catch (e: Exception) {
                // ignore parsing errors and continue with normal handling
            }
        }

        if (!shouldAttemptRefresh(response)) {
            return response
        }

        Log.w(TAG, "AuthInterceptor detected auth-expired response (code=${response.code}) - attempting immediate refresh")

        // Attempt immediate refresh synchronously
        val refreshed = try {
            val mgr = AppContainer.authManager
            runBlocking {
                mgr.requestImmediateTokenRefresh()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Immediate refresh failed", e)
            false
        }

        if (!refreshed) {
            // Refresh failed - trigger logout asynchronously and return original response
            Log.w(TAG, "Immediate refresh failed - logging out user")
            try {
                // best-effort logout in background
                Thread {
                    runBlocking { AppContainer.authManager.logout() }
                }.start()
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to logout after refresh failure", t)
            }
            return response
        }

        // Build Authorization header for retry. Preserve device token if present in original header.
        val newToken = AppContainer.authManager.currentAccessToken
        val origAuth = request.header("Authorization")
        val newAuthHeader = buildAuthHeaderForRetry(origAuth, newToken)

        val newRequest = request.newBuilder()
            .header("Authorization", newAuthHeader)
            .build()

        val retryResponse = chain.proceed(newRequest)

        if (shouldAttemptRefresh(retryResponse)) {
            // Retry still indicates auth failure - logout and return retry response
            Log.w(TAG, "Retry after refresh still failed - logging out user")
            try { runBlocking { AppContainer.authManager.logout() } } catch (_: Exception) {}
        }

        return retryResponse
    }

    private fun shouldAttemptRefresh(response: Response): Boolean {
        if (response.code == 401) return true
        // Inspect body for expired/expired-auth messages when 400
        if (response.code == 400) {
            return try {
                val peek = response.peekBody(Long.MAX_VALUE).string()
                // If the body indicates a device-token problem, do NOT attempt user-token refresh here.
                if (isDeviceTokenError(peek)) return false
                peek.contains("expire", ignoreCase = true) ||
                    peek.contains("expired", ignoreCase = true) ||
                    peek.contains("authentication data", ignoreCase = true)
            } catch (e: Exception) {
                false
            }
        }
        return false
    }

    private fun isDeviceTokenError(body: String?): Boolean {
        if (body == null || body.isBlank()) return false
        val b = body.lowercase()
        // common server messages indicating device token problems
        val deviceIndicators = listOf("device token", "device_token", "device not", "invalid device", "device expired", "device revoked", "not related", "not related to user", "device not found")
        return deviceIndicators.any { b.contains(it) }
    }

    private fun buildAuthHeaderForRetry(origAuth: String?, newUserToken: String?): String {
        val user = newUserToken ?: ""
        if (origAuth == null) return "Bearer $user"

        val trimmed = origAuth.removePrefix("Bearer ").trim()
        return if (trimmed.contains("|")) {
            val parts = trimmed.split("|", limit = 2)
            val devicePart = parts.getOrNull(1) ?: ""
            "Bearer $user|$devicePart"
        } else {
            "Bearer $user"
        }
    }

    companion object {
        private const val TAG = "AuthInterceptor"
    }
}
