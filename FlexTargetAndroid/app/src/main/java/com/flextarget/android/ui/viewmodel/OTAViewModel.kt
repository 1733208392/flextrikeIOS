package com.flextarget.android.ui.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.repository.OTAHistoryEntry
import com.flextarget.android.data.repository.OTARepository
import com.flextarget.android.data.repository.OTAState
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * UI state for OTA updates
 */
data class OTAUiState(
    val state: OTAState = OTAState.IDLE,
    val progress: Int = 0,
    val currentVersion: String? = null,
    val availableVersion: String? = null,
    val description: String = "",
    val mandatory: Boolean = false,
    val lastCheck: String? = null,
    val error: String? = null,
    val updateHistory: List<OTAHistoryEntry> = emptyList()
)

/**
 * OTAViewModel: Manages over-the-air updates
 * 
 * Responsibilities:
 * - Check for available updates
 * - Download and prepare updates
 * - Verify update integrity
 * - Initiate update installation
 * - Display update progress
 * - Show update history
 */
class OTAViewModel(
    private val otaRepository: OTARepository
) : ViewModel() {
    
    init {
        Log.d("OTAViewModel", "OTAViewModel initialized")
    }
    
    /**
     * Current OTA UI state
     */
    val otaUiState: StateFlow<OTAUiState> = combine(
        otaRepository.otaProgress,
        otaRepository.currentDeviceVersion
    ) { progress, currentVersion ->
        OTAUiState(
            state = progress.state,
            progress = progress.progress,
            currentVersion = currentVersion,
            availableVersion = progress.version,
            description = "", // Would need to be set from update info
            mandatory = false, // Would need to be set from update info
            lastCheck = progress.lastCheck?.toString(),
            error = progress.error,
            updateHistory = emptyList() // Would need to be fetched separately
        )
    }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = OTAUiState()
        )
    
    /**
     * Check for available updates
     */
    fun checkForUpdates(deviceToken: String) {
        Log.d("OTAViewModel", "checkForUpdates called with deviceToken: ${deviceToken.take(20)}...")
        viewModelScope.launch {
            Log.d("OTAViewModel", "Launching checkForUpdates coroutine")
            val result = otaRepository.checkForUpdates(deviceToken)
            result.onSuccess { versionInfo ->
                Log.d("OTAViewModel", "checkForUpdates success: versionInfo = $versionInfo")
                if (versionInfo != null) {
                    // Update available, show to user
                }
            }.onFailure { error ->
                Log.e("OTAViewModel", "checkForUpdates failed: ${error.message}", error)
                // Handle error
            }
        }
    }
    
    /**
     * Download and prepare update
     */
    fun prepareUpdate() {
        viewModelScope.launch {
            val result = otaRepository.prepareUpdate()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Verify downloaded update
     */
    fun verifyUpdate() {
        viewModelScope.launch {
            val result = otaRepository.verifyUpdate()
            result.onSuccess { isValid ->
                if (isValid) {
                    // Update verified, ready to install
                }
            }.onFailure {
                // Handle error
            }
        }
    }
    

    
    /**
     * Cancel ongoing update
     */
    fun cancelUpdate() {
        viewModelScope.launch {
            otaRepository.cancelUpdate()
        }
    }
    
    /**
     * Load update history
     */
    fun loadUpdateHistory() {
        viewModelScope.launch {
            val result = otaRepository.getUpdateHistory(limit = 20)
            result.onSuccess { history ->
                // Update UI with history
            }.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Get current OTA state
     */
    fun getCurrentState(): OTAState = otaRepository.getCurrentUpdateInfo()?.let { OTAState.UPDATE_AVAILABLE } ?: OTAState.IDLE
}
