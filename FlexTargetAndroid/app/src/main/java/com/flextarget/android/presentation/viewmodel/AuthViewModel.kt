package com.flextarget.android.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.auth.DeviceAuthManager
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
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
    val error: String? = null
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
    private val authManager: AuthManager,
    private val deviceAuthManager: DeviceAuthManager
) : ViewModel() {
    
    /**
     * Current authentication UI state
     */
    val authUiState: StateFlow<AuthUiState> = combine(
        authManager.currentUser,
        deviceAuthManager.isDeviceAuthenticated
    ) { user, isDeviceAuth ->
        AuthUiState(
            isAuthenticated = user != null,
            userName = user?.username,
            userMobile = user?.mobile,
            isDeviceAuthenticated = isDeviceAuth
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
            val result = authManager.login(mobile, password)
            result.onFailure {
                // Error would be emitted via error flow
            }
        }
    }
    
    /**
     * Logout current user
     */
    fun logout() {
        viewModelScope.launch {
            authManager.logout()
        }
    }
    
    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean = authManager.isAuthenticated
    
    /**
     * Get current access token
     */
    fun getAccessToken(): String? = authManager.currentAccessToken
}
