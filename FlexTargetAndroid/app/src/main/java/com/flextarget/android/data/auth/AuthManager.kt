package com.flextarget.android.data.auth

import android.util.Log
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.local.preferences.UserTokenData
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.LoginRequest
import com.flextarget.android.data.remote.api.LoginWithEmailRequest
import com.flextarget.android.data.remote.api.LoginWithMobileRequest
import com.flextarget.android.data.remote.api.ChangePasswordRequest
import com.flextarget.android.data.remote.api.RegisterRequest
import com.flextarget.android.data.remote.api.SendVerifyCodeRequest
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * AuthManager: Singleton managing user authentication state and token lifecycle.
 * 
 * Responsibilities:
 * - Maintain current user state (UUID, tokens, mobile, username)
 * - Persist tokens to encrypted storage
 * - Implement 55-minute token refresh timer
 * - Handle login/logout lifecycle
 * - Auto-logout on refresh failure
 * 
 * On app launch with existing token:
 * - Loads user from encrypted storage
 * - Immediately attempts refresh if expired
 * - Starts 55-minute refresh timer if refresh succeeds
 */
@Singleton
class AuthManager @Inject constructor(
    private val preferences: AppPreferences,
    private val userApiService: FlexTargetAPI,
    private var tokenRefreshQueue: TokenRefreshQueue?
) {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    
    // Current user state
    private val _currentUser = MutableStateFlow<UserData?>(null)
    val currentUser: StateFlow<UserData?> = _currentUser.asStateFlow()
    
    val isAuthenticated: Boolean
        get() = _currentUser.value != null
    
    val currentAccessToken: String?
        get() = _currentUser.value?.accessToken
    
    val currentRefreshToken: String?
        get() = _currentUser.value?.refreshToken
    
    // Token refresh timer
    private var tokenRefreshJob: Job? = null
    private val TOKEN_REFRESH_INTERVAL = 55 * 60 * 1000L // 55 minutes in milliseconds
    
    init {
        scope.launch {
            loadUser()
            // If user exists and token might be expired, attempt immediate refresh
            if (_currentUser.value != null) {
                // Launch token refresh in background (don't block initialization)
                refreshToken()
                // Start the periodic refresh timer
                startTokenRefreshTimer()
            }
        }
    }
    
    /**
     * Set the token refresh queue (for dependency injection)
     */
    fun setTokenRefreshQueue(queue: TokenRefreshQueue) {
        this.tokenRefreshQueue = queue
    }
    
    /**
     * Load user from encrypted storage on app startup
     */
    private suspend fun loadUser() = withContext(Dispatchers.IO) {
        try {
            val tokenData = preferences.getUserToken()
            if (tokenData != null) {
                _currentUser.value = UserData(
                    userUUID = tokenData.userUUID,
                    accessToken = tokenData.accessToken,
                    refreshToken = tokenData.refreshToken,
                    mobile = tokenData.mobile,
                    username = tokenData.username
                )
                Log.d(TAG, "User loaded from storage: ${tokenData.userUUID}")
            } else {
                Log.d(TAG, "No user found in storage")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load user from storage", e)
        }
    }
    
    /**
     * User login: authenticate with mobile/email and password
     * Auto-detects if input is email or mobile number and calls appropriate endpoint
     * 
     * @param input User's mobile number or email
     * @param password User's password (will be Base64 encoded here)
     * @return Success with user data or failure with exception
     */
    suspend fun login(input: String, password: String): Result<UserData> = 
        withContext(Dispatchers.IO) {
            try {
                // Auto-detect email vs mobile
                val isEmail = input.contains("@")
                
                val encodedPassword = base64EncodePassword(password)
                val response = if (isEmail) {
                    userApiService.loginWithEmail(
                        LoginWithEmailRequest(
                            email = input,
                            password = encodedPassword
                        )
                    )
                } else {
                    userApiService.loginWithMobile(
                        LoginWithMobileRequest(
                            mobile = input,
                            password = encodedPassword
                        )
                    )
                }

                if (response.code != 0) {
                    return@withContext Result.failure(Exception(response.msg))
                }

                val data = response.data ?: return@withContext Result.failure(Exception("Invalid login response"))
                val user = UserData(
                    userUUID = response.data.userUUID,
                    accessToken = data.accessToken,
                    refreshToken = data.refreshToken,
                    mobile = input,
                    username = null // Loaded from editProfile call later if needed
                )
                
                // Save to encrypted storage
                preferences.saveUserToken(
                    userUUID = user.userUUID,
                    accessToken = user.accessToken,
                    refreshToken = user.refreshToken,
                    mobile = user.mobile,
                    username = user.username
                )
                
                // Update in-memory state
                _currentUser.value = user
                
                // Start refresh timer
                startTokenRefreshTimer()
                
                // Fetch user info to get username
                try {
                    val userGetResponse = userApiService.getUser("Bearer ${data.accessToken}")
                    if (userGetResponse.code == 0 && userGetResponse.data != null) {
                        val updatedUser = user.copy(username = userGetResponse.data.username)
                        _currentUser.value = updatedUser
                        preferences.saveUserToken(
                            userUUID = updatedUser.userUUID,
                            accessToken = updatedUser.accessToken,
                            refreshToken = updatedUser.refreshToken,
                            mobile = updatedUser.mobile,
                            username = userGetResponse.data.username
                        )
                        Log.d(TAG, "User info fetched and updated: ${userGetResponse.data.username}")
                    } else {
                        Log.w(TAG, "Failed to fetch user info: ${userGetResponse.msg}")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Exception while fetching user info: ${e.message}")
                    // Continue with login even if user info fetch fails
                }
                
                Log.d(TAG, "Login successful for ${if (isEmail) "email" else "mobile"}: $input")
                Result.success(user)
            } catch (e: Exception) {
                Log.e(TAG, "Login failed", e)
                Result.failure(e)
            }
        }
    
    /**
     * User logout: clear tokens and state
     */
    suspend fun logout(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val token = _currentUser.value?.accessToken
            if (token != null) {
                try {
                    userApiService.logout("Bearer $token")
                } catch (e: Exception) {
                    // Even if logout API fails, clear local state
                    Log.w(TAG, "Logout API call failed, but clearing local state", e)
                }
            }
            
            // Clear state
            stopTokenRefreshTimer()
            preferences.clearUserToken()
            _currentUser.value = null
            
            Log.d(TAG, "Logout completed")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Logout failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * Register new user with email
     * After successful registration, automatically logs in the user
     */
    suspend fun registerWithEmail(email: String, password: String, verifyCode: String): Result<UserData> = 
        withContext(Dispatchers.IO) {
            try {
                val encodedPassword = base64EncodePassword(password)
                
                // Step 1: Register with email
                val registerResponse = userApiService.registerWithEmail(
                    RegisterRequest(
                        email = email,
                        password = encodedPassword,
                        verify_code = verifyCode
                    )
                )

                if (registerResponse.code != 0) {
                    return@withContext Result.failure(Exception(registerResponse.msg))
                }

                Log.d(TAG, "Registration successful for email: $email, now logging in...")
                
                // Step 2: Login with email and password to get tokens
                // Note: The login endpoint accepts email or mobile, so we use email
                val loginResponse = userApiService.login(
                    LoginRequest(
                        mobile = email, // Server accepts email as mobile parameter
                        password = encodedPassword
                    )
                )

                if (loginResponse.code != 0) {
                    return@withContext Result.failure(Exception("Login after registration failed: ${loginResponse.msg}"))
                }

                val loginData = loginResponse.data ?: return@withContext Result.failure(Exception("Invalid login response after registration"))
                val user = UserData(
                    userUUID = loginData.userUUID,
                    accessToken = loginData.accessToken,
                    refreshToken = loginData.refreshToken,
                    mobile = email,
                    username = null // Will be loaded if needed
                )
                
                // Save to encrypted storage
                preferences.saveUserToken(
                    userUUID = user.userUUID,
                    accessToken = user.accessToken,
                    refreshToken = user.refreshToken,
                    mobile = user.mobile,
                    username = user.username
                )
                
                // Update in-memory state
                _currentUser.value = user
                
                // Start refresh timer
                startTokenRefreshTimer()
                
                // Fetch user info to get username
                try {
                    val userGetResponse = userApiService.getUser("Bearer ${loginData.accessToken}")
                    if (userGetResponse.code == 0 && userGetResponse.data != null) {
                        val updatedUser = user.copy(username = userGetResponse.data.username)
                        _currentUser.value = updatedUser
                        preferences.saveUserToken(
                            userUUID = updatedUser.userUUID,
                            accessToken = updatedUser.accessToken,
                            refreshToken = updatedUser.refreshToken,
                            mobile = updatedUser.mobile,
                            username = userGetResponse.data.username
                        )
                        Log.d(TAG, "User info fetched after registration: ${userGetResponse.data.username}")
                    } else {
                        Log.w(TAG, "Failed to fetch user info after registration: ${userGetResponse.msg}")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Exception while fetching user info after registration: ${e.message}")
                    // Continue with registration even if user info fetch fails
                }
                
                Log.d(TAG, "Registration and login successful for email: $email")
                Result.success(user)
            } catch (e: Exception) {
                Log.e(TAG, "Registration failed", e)
                Result.failure(e)
            }
        }
    
    /**
     * Send verification code to email
     */
    suspend fun sendVerifyCode(email: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val response = userApiService.sendVerifyCode(
                SendVerifyCodeRequest(email = email)
            )

            if (response.code != 0) {
                return@withContext Result.failure(Exception(response.msg))
            }

            Log.d(TAG, "Verification code sent to email: $email")
            Result.success("Code sent successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send verification code", e)
            Result.failure(e)
        }
    }
    
    /**
     * Update tokens (called by TokenRefreshQueue after successful refresh)
     */
    fun updateTokens(accessToken: String, refreshToken: String) {
        scope.launch {
            try {
                _currentUser.value?.let { currentUser ->
                    val updatedUser = currentUser.copy(
                        accessToken = accessToken,
                        refreshToken = refreshToken
                    )
                    _currentUser.value = updatedUser
                    preferences.updateTokens(accessToken, refreshToken)
                    Log.d(TAG, "Tokens updated")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update tokens", e)
            }
        }
    }
    
    /**
     * Start 55-minute token refresh timer
     */
    private fun startTokenRefreshTimer() {
        stopTokenRefreshTimer()
        tokenRefreshJob = scope.launch {
            while (isActive) {
                delay(TOKEN_REFRESH_INTERVAL)
                if (isActive) {
                    refreshToken()
                }
            }
        }
        Log.d(TAG, "Token refresh timer started (55 minute interval)")
    }
    
    /**
     * Stop refresh timer
     */
    private fun stopTokenRefreshTimer() {
        tokenRefreshJob?.cancel()
        tokenRefreshJob = null
    }
    
    /**
     * Refresh access token using refresh token
     * Called periodically by timer or on demand
     */
    private suspend fun refreshToken() {
        val refreshToken = _currentUser.value?.refreshToken ?: return
        
        try {
            Log.d(TAG, "Attempting token refresh")
            tokenRefreshQueue?.queueRefresh(refreshToken)
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh failed, logging out", e)
            // On refresh failure, logout user
            logout()
        }
    }
    
    /**
     * Edit user profile (username)
     */
    suspend fun editProfile(username: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val token = _currentUser.value?.accessToken ?: return@withContext Result.failure(
                IllegalStateException("Not authenticated")
            )
            
            // Call remote API
            val response = userApiService.editUser(
                com.flextarget.android.data.remote.api.EditUserRequest(username = username),
                "Bearer $token"
            )

            if (response.code != 0) {
                // Check for token expiration (code 401)
                if (response.code == 401) {
                    Log.w(TAG, "Token expired during profile update: ${response.msg}")
                    // Trigger auto-logout
                    logout()
                    return@withContext Result.failure(Exception(response.msg))
                }
                return@withContext Result.failure(Exception(response.msg))
            }

            // Update local state
            _currentUser.value?.let { currentUser ->
                val updatedUser = currentUser.copy(username = username)
                _currentUser.value = updatedUser
                preferences.updateUserProfile(username)
            }
            
            Log.d(TAG, "Profile updated: username=$username")
            Result.success(Unit)
        } catch (e: retrofit2.HttpException) {
            // Handle HTTP exceptions (e.g., 401 Unauthorized)
            Log.e(TAG, "HTTP exception during profile update: ${e.code()} ${e.message}", e)
            if (e.code() == 401) {
                Log.w(TAG, "Token expired during profile update (HTTP 401)")
                logout()
                return@withContext Result.failure(Exception("401"))
            }
            Result.failure(e)
        } catch (e: Exception) {
            Log.e(TAG, "Profile update failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * Change password
     */
    suspend fun changePassword(oldPassword: String, newPassword: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val token = _currentUser.value?.accessToken ?: return@withContext Result.failure(
                    IllegalStateException("Not authenticated")
                )
                
                val oldEncoded = base64EncodePassword(oldPassword)
                val newEncoded = base64EncodePassword(newPassword)
                
                val response = userApiService.changePassword(
                    ChangePasswordRequest(
                        old_password = oldEncoded,
                        new_password = newEncoded
                    ),
                    "Bearer $token"
                )

                if (response.code != 0) {
                    // Check for token expiration (code 401)
                    if (response.code == 401) {
                        Log.w(TAG, "Token expired during password change: ${response.msg}")
                        // Trigger auto-logout
                        logout()
                        return@withContext Result.failure(Exception(response.msg))
                    }
                    return@withContext Result.failure(Exception(response.msg))
                }
                
                Log.d(TAG, "Password changed successfully")
                Result.success(Unit)
            } catch (e: retrofit2.HttpException) {
                // Handle HTTP exceptions (e.g., 401 Unauthorized)
                Log.e(TAG, "HTTP exception during password change: ${e.code()} ${e.message}", e)
                if (e.code() == 401) {
                    Log.w(TAG, "Token expired during password change (HTTP 401)")
                    logout()
                    return@withContext Result.failure(Exception("401"))
                }
                Result.failure(e)
            } catch (e: Exception) {
                Log.e(TAG, "Password change failed", e)
                Result.failure(e)
            }
        }
    
    /**
     * Set user directly with tokens (for password reset auto-login)
     * Updates both in-memory state and persistent storage
     */
    suspend fun setUserDirectly(
        userUUID: String,
        accessToken: String,
        refreshToken: String,
        mobile: String,
        username: String?
    ) {
        try {
            val user = UserData(
                userUUID = userUUID,
                accessToken = accessToken,
                refreshToken = refreshToken,
                mobile = mobile,
                username = username
            )
            
            // Save to encrypted storage
            withContext(Dispatchers.IO) {
                preferences.saveUserToken(
                    userUUID = user.userUUID,
                    accessToken = user.accessToken,
                    refreshToken = user.refreshToken,
                    mobile = user.mobile,
                    username = user.username
                )
            }
            
            // Update in-memory state
            _currentUser.value = user
            
            // Start refresh timer
            startTokenRefreshTimer()
            
            Log.d(TAG, "User set directly for: $userUUID")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set user directly", e)
        }
    }
    
    /**
     * Handle invalid refresh token (401 on token refresh endpoint)
     * This means the refresh token is expired or revoked by server
     * Clears auth state and forces re-login
     * 
     * Called synchronously from TokenRefreshQueue when 401 is received
     */
    fun handleInvalidRefreshToken() {
        scope.launch {
            try {
                // Clear state without calling logout API (token is invalid)
                stopTokenRefreshTimer()
                preferences.clearUserToken()
                _currentUser.value = null
                
                Log.w(TAG, "Invalid refresh token cleared - user must re-authenticate")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to handle invalid refresh token", e)
            }
        }
    }
    
    /**
     * Base64 encode password (matching iOS implementation)
     * Encodes UTF-8 string to Base64 and removes padding (=) characters
     */
    private fun base64EncodePassword(password: String): String {
        val bytes = password.toByteArray(Charsets.UTF_8)
        var encoded = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
        // Remove padding
        encoded = encoded.trimEnd('=')
        return encoded
    }
    
    companion object {
        private const val TAG = "AuthManager"
    }
}

/**
 * User data class
 */
data class UserData(
    val userUUID: String,
    val accessToken: String,
    val refreshToken: String,
    val mobile: String? = null,
    val username: String? = null
)
