package com.flextarget.android.data.auth

import android.util.Log
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.DeviceRelateRequest
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * DeviceAuthManager: Manages device-level authentication via 2-step process.
 * 
 * Flow:
 * 1. BLE device connection established
 * 2. Request auth_data from device via BLE
 * 3. Exchange auth_data with server via /device/relate endpoint (requires user token)
 * 4. Receive and cache device_uuid + device_token
 * 5. Use combined token for device-specific API calls
 * 
 * Token Expiration:
 * - Cached in encrypted storage with expiration timestamp
 * - Automatically cleared if expired
 * - Re-acquired on BLE reconnection
 */
@Singleton
class DeviceAuthManager @Inject constructor(
    private val preferences: AppPreferences,
    private val userApiService: FlexTargetAPI,
    private val authManager: AuthManager
) {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    
    // Device state
    private val _deviceUUID = MutableStateFlow<String?>(null)
    val deviceUUID: StateFlow<String?> = _deviceUUID.asStateFlow()
    
    private val _deviceToken = MutableStateFlow<String?>(null)
    val deviceToken: StateFlow<String?> = _deviceToken.asStateFlow()
    
    private val _isDeviceAuthenticated = MutableStateFlow(false)
    val isDeviceAuthenticated: StateFlow<Boolean> = _isDeviceAuthenticated.asStateFlow()
    
    init {
        scope.launch {
            loadCachedDeviceAuth()
        }
    }
    
    /**
     * Load device auth from encrypted storage on startup
     */
    private suspend fun loadCachedDeviceAuth() = withContext(Dispatchers.IO) {
        try {
            val (uuid, token) = preferences.getDeviceToken()
            _deviceUUID.value = uuid
            _deviceToken.value = token
            _isDeviceAuthenticated.value = uuid != null && token != null
            
            if (uuid != null && token != null) {
                Log.d(TAG, "Device auth loaded from cache: $uuid")
            } else {
                Log.d(TAG, "No cached device auth found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load cached device auth", e)
        }
    }
    
    /**
     * Perform device authentication after BLE connection
     * Must be called when:
     * - BLE device connects successfully
     * - auth_data is received from device
     * 
     * @param authDataFromDevice Base64-encoded auth_data from BLE device
     * @return Success with device UUID or failure
     */
    suspend fun authenticateDevice(authDataFromDevice: String): Result<String> =
        withContext(Dispatchers.IO) {
            try {
                // Verify user is authenticated first
                val userToken = authManager.currentAccessToken
                    ?: return@withContext Result.failure(
                        IllegalStateException("User not authenticated. Please login first.")
                    )
                
                Log.d(TAG, "Authenticating device with auth_data")
                
                // Exchange auth_data with server for device token

                // Attempt relateDevice; on 401 we will try immediate token refresh and retry once
                var response = userApiService.relateDevice(
                    DeviceRelateRequest(auth_data = authDataFromDevice),
                    "Bearer $userToken"
                )

                if (response.code == 401) {
                    // Try immediate refresh and retry once
                    val refreshed = try {
                        authManager.requestImmediateTokenRefresh()
                    } catch (e: Exception) {
                        false
                    }

                    if (refreshed) {
                        val newUserToken = authManager.currentAccessToken
                        if (newUserToken != null) {
                            response = userApiService.relateDevice(
                                DeviceRelateRequest(auth_data = authDataFromDevice),
                                "Bearer $newUserToken"
                            )
                        }
                    }
                }

                if (response.code != 0) {
                    return@withContext Result.failure(Exception(response.msg))
                }

                val data = response.data ?: return@withContext Result.failure(Exception("Invalid login response"))

                // Cache device auth
                preferences.saveDeviceToken(
                    deviceUUID = data.deviceUUID,
                    deviceToken = data.deviceToken,
                    expirationMillis = data.expiration
                )
                // Update in-memory state
                _deviceUUID.value = data.deviceUUID
                _deviceToken.value = data.deviceToken
                _isDeviceAuthenticated.value = true
                
                Log.d(TAG, "Device authenticated successfully: ${data.deviceUUID}")
                Result.success(data.deviceUUID)
            } catch (e: retrofit2.HttpException) {
                // Read error body (if available) to detect expired auth messages
                val errorBody = try {
                    e.response()?.errorBody()?.string() ?: ""
                } catch (readEx: Exception) {
                    ""
                }

                Log.e(TAG, "HTTP exception during device authentication: ${e.code()} ${e.message} body=$errorBody", e)

                // Treat 401 and some 400 responses that indicate expired authentication as token-expiration
                val indicatesExpired = when {
                    e.code() == 401 -> true
                    e.code() == 400 && errorBody.contains("expire", ignoreCase = true) -> true
                    e.code() == 400 && errorBody.contains("expired", ignoreCase = true) -> true
                    e.code() == 400 && errorBody.contains("authentication data", ignoreCase = true) -> true
                    else -> false
                }

                if (indicatesExpired) {
                    Log.w(TAG, "Device relate returned HTTP ${e.code()} indicating expired auth - attempting immediate user token refresh")
                    val refreshed = try { authManager.requestImmediateTokenRefresh() } catch (re: Exception) { false }
                    if (refreshed) {
                        // Retry relateDevice once with refreshed token
                        val newUserToken = authManager.currentAccessToken
                        if (newUserToken != null) {
                            try {
                                val retryResp = userApiService.relateDevice(
                                    DeviceRelateRequest(auth_data = authDataFromDevice),
                                    "Bearer $newUserToken"
                                )

                                if (retryResp.code != 0) {
                                    clearDeviceAuth()
                                    return@withContext Result.failure(Exception(retryResp.msg))
                                }

                                val data = retryResp.data ?: return@withContext Result.failure(Exception("Invalid response"))
                                // Cache device auth after successful retry
                                preferences.saveDeviceToken(
                                    deviceUUID = data.deviceUUID,
                                    deviceToken = data.deviceToken,
                                    expirationMillis = data.expiration
                                )
                                _deviceUUID.value = data.deviceUUID
                                _deviceToken.value = data.deviceToken
                                _isDeviceAuthenticated.value = true
                                Log.d(TAG, "Device authenticated successfully after refresh: ${data.deviceUUID}")
                                return@withContext Result.success(data.deviceUUID)
                            } catch (e2: Exception) {
                                Log.e(TAG, "Retry after refresh failed", e2)
                                // If retry throws IO, keep cached device auth; otherwise clear
                                if (e2 is java.io.IOException) {
                                    return@withContext Result.failure(e2)
                                }
                                clearDeviceAuth()
                                return@withContext Result.failure(e2)
                            }
                        }
                    }

                    // Refresh failed or no token - clear device auth and fail
                    clearDeviceAuth()
                    return@withContext Result.failure(e)
                }

                // For other HTTP errors, clear device auth
                clearDeviceAuth()
                return@withContext Result.failure(e)
            } catch (e: Exception) {
                Log.e(TAG, "Device authentication failed", e)
                // Do NOT clear cached device auth on transient network failures
                // (e.g., UnknownHostException, SocketTimeoutException, general IO issues).
                // Clearing device auth should only happen for explicit auth problems
                // (server responses indicating invalid/expired device token) or
                // when caller intentionally requests a clear.
                if (e is java.io.IOException) {
                    return@withContext Result.failure(e)
                }

                // For other errors (malformed response, explicit server-side failure),
                // clear cached device auth to force a clean re-auth flow.
                clearDeviceAuth()
                Result.failure(e)
            }
        }
    
    /**
     * Generate Authorization header for API calls
     * 
     * Format with device token: "Bearer {userToken}|{deviceToken}"
     * Format without device token: "Bearer {userToken}"
     * 
     * @param userToken User's access token
     * @param requireDeviceToken If true, throws exception if device token unavailable
     * @return Authorization header string
     */
    fun getAuthorizationHeader(userToken: String, requireDeviceToken: Boolean = false): String {
        // Fast-path: in-memory token
        val memToken = _deviceToken.value
        if (memToken != null) {
            return "Bearer $userToken|$memToken"
        }

        // Blocking fallback: attempt to read persisted token (this will also enforce expiration)
        try {
            val (uuid, token) = runBlocking(Dispatchers.IO) { preferences.getDeviceToken() }
            if (token != null) {
                // Populate in-memory state for subsequent calls
                _deviceUUID.value = uuid
                _deviceToken.value = token
                _isDeviceAuthenticated.value = uuid != null && token != null
                Log.d(TAG, "Loaded device token from prefs for header construction: uuid=$uuid")
                return "Bearer $userToken|$token"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read device token from prefs", e)
        }

        if (requireDeviceToken) {
            throw IllegalStateException("Device token required but not available. Connect BLE device first.")
        }

        return "Bearer $userToken"
    }
    
    /**
     * Check if device token is still valid (not expired)
     */
    suspend fun isDeviceTokenValid(): Boolean = withContext(Dispatchers.IO) {
        val (uuid, token) = preferences.getDeviceToken()
        uuid != null && token != null
    }
    
    /**
     * Clear device authentication (on BLE disconnect or logout)
     */
    suspend fun clearDeviceAuth() = withContext(Dispatchers.IO) {
        try {
            preferences.clearDeviceToken()
            _deviceUUID.value = null
            _deviceToken.value = null
            _isDeviceAuthenticated.value = false
            Log.d(TAG, "Device auth cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear device auth", e)
        }
    }
    
    /**
     * Force re-authentication of device (e.g., after token expiration)
     * Requires BLE connection with new auth_data from device
     */
    suspend fun reAuthenticateDevice(authDataFromDevice: String): Result<String> {
        // Clear existing tokens first
        clearDeviceAuth()
        // Then attempt new authentication
        return authenticateDevice(authDataFromDevice)
    }
    
    companion object {
        private const val TAG = "DeviceAuthManager"
    }
}
