package com.flextarget.android.data.auth

import android.util.Log
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.remote.api.FlexTargetAPI
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
                val response = userApiService.relateDevice(authDataFromDevice, userToken)

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
            } catch (e: Exception) {
                Log.e(TAG, "Device authentication failed", e)
                // Clear device auth on failure
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
        return if (_deviceToken.value != null) {
            "Bearer $userToken|${_deviceToken.value}"
        } else if (requireDeviceToken) {
            throw IllegalStateException("Device token required but not available. Connect BLE device first.")
        } else {
            "Bearer $userToken"
        }
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
