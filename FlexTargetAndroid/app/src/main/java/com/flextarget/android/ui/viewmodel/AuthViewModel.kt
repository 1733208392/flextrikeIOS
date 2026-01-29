package com.flextarget.android.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.R
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

/**
 * UI state for authentication
 */
data class AuthUiState(
    val isLoading: Boolean = false,
    val isAuthenticated: Boolean = false,
    val userName: String? = null,
    val userMobile: String? = null,
    val isDeviceAuthenticated: Boolean = false,
    val error: String? = null,
    val message: String? = null
)

/**
 * AuthViewModel: Manages authentication state and user login/logout
 * 
 * Responsibilities:
 * - Expose authentication state to UI
 * - Handle user login and logout
 * - Track device authentication status
 * - Manage error states
 */
class AuthViewModel(
    application: Application,
    private val authManager: AuthManager,
    private val deviceAuthManager: DeviceAuthManager
) : AndroidViewModel(application) {
    
    private val _loading = MutableStateFlow(false)
    private val _error = MutableStateFlow<String?>(null)
    private val _message = MutableStateFlow<String?>(null)

    /**
     * Current authentication UI state
     */
    val authUiState: StateFlow<AuthUiState> = combine(
        authManager.currentUser,
        deviceAuthManager.isDeviceAuthenticated,
        _loading,
        _error,
        _message
    ) { user, isDeviceAuth, loading, error, message ->
        AuthUiState(
            isAuthenticated = user != null,
            userName = user?.username,
            userMobile = user?.mobile,
            isDeviceAuthenticated = isDeviceAuth,
            isLoading = loading,
            error = error,
            message = message
        )
    }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = AuthUiState()
        )
    
    /**
     * Login with mobile and password
     */
    fun login(mobile: String, password: String) {
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            val result = authManager.login(mobile, password)
            _loading.value = false
            result.onFailure {
                _error.value = it.message ?: "Login failed"
            }
        }
    }
    
    /**
     * Logout current user
     */
    fun logout() {
        viewModelScope.launch {
            _loading.value = true
            authManager.logout()
            _loading.value = false
        }
    }
    
    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean = authManager.isAuthenticated
    
    /**
     * Update user profile
     */
    fun updateProfile(username: String) {
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            _message.value = null
            val result = authManager.editProfile(username)
            _loading.value = false
            result.onSuccess {
                _message.value = "Profile updated successfully"
            }.onFailure { error ->
                val errorMsg = error.message ?: "Failed to update profile"
                // Check if it's a token expired error (401)
                if (errorMsg == "401") {
                    _error.value = getApplication<Application>().getString(R.string.session_expired_message)
                    // Auto-logout on token expiration
                    logout()
                } else {
                    _error.value = errorMsg
                }
            }
        }
    }
    
    /**
     * Change user password
     */
    fun changePassword(oldPassword: String, newPassword: String) {
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            _message.value = null
            val result = authManager.changePassword(oldPassword, newPassword)
            _loading.value = false
            result.onSuccess {
                _message.value = "Password changed successfully"
            }.onFailure { error ->
                val errorMsg = error.message ?: "Failed to change password"
                // Check if it's a token expired error (401)
                if (errorMsg == "401") {
                    _error.value = getApplication<Application>().getString(R.string.session_expired_message)
                    // Auto-logout on token expiration
                    logout()
                } else {
                    _error.value = errorMsg
                }
            }
        }
    }

    /**
     * Clear messages and errors
     */
    fun clearStatus() {
        _error.value = null
        _message.value = null
    }

    /**
     * Set a message to show to the user
     */
    fun setShowMessage(message: String) {
        _message.value = message
    }

    /**
     * Set an error to show to the user
     */
    fun setShowError(error: String) {
        _error.value = error
    }
    
    /**
     * Get current access token
     */
    fun getAccessToken(): String? = authManager.currentAccessToken
}
