package com.flextarget.android.ui.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.auth.DeviceAuthManager
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.repository.BLERepository
import com.flextarget.android.data.repository.DeviceState
import com.flextarget.android.data.repository.ShotEvent
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * UI state for BLE device
 */
data class BLEUiState(
    val isConnected: Boolean = false,
    val deviceState: DeviceState = DeviceState.Disconnected,
    val shotsReceived: List<ShotEvent> = emptyList(),
    val currentShot: ShotEvent? = null,
    val lastShotTime: Long = 0L,
    val error: String? = null
)

/**
 * BLEViewModel: Manages Bluetooth device communication
 * 
 * Responsibilities:
 * - Connect/disconnect from BLE device
 * - Display device connection status
 * - Show real-time shot feedback
 * - Handle device errors
 * - Manage device state transitions
 */
class BLEViewModel(
    private val bleRepository: BLERepository,
    private val deviceAuthManager: DeviceAuthManager
) : ViewModel() {
    
    init {
        Log.d("BLEViewModel", "BLEViewModel initialized")
        
        // Monitor BLE connection state and auto-authenticate when connected
        viewModelScope.launch {
            Log.d("BLEViewModel", "Starting BLE ready monitoring loop")
            var wasReady = false
            // Check initial state
            val initialReady = BLEManager.shared.isReady
            Log.d("BLEViewModel", "Initial BLE ready state: $initialReady")
            if (initialReady) {
                Log.d("BLEViewModel", "BLE device already ready, attempting authentication")
                delay(1000) // Wait 1 additional second for stability
                authenticateDevice()
                wasReady = true
            }
            
            while (true) {
                val isReady = BLEManager.shared.isReady
                if (isReady != wasReady) {
                    Log.d("BLEViewModel", "BLE ready state changed: $wasReady -> $isReady")
                }
                if (isReady && !wasReady) {
                    Log.d("BLEViewModel", "BLE device ready, attempting authentication")
                    delay(1000) // Wait 1 additional second for stability
                    authenticateDevice()
                }
                wasReady = isReady
                delay(100) // Check every 100ms
            }
        }
    }
    
    /**
     * Current BLE UI state
     */
    val bleUiState: StateFlow<BLEUiState> = bleRepository.deviceState
        .map { deviceState ->
            BLEUiState(
                isConnected = deviceState != DeviceState.Disconnected,
                deviceState = deviceState
            )
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = BLEUiState()
        )
    
    /**
     * Real-time shot events
     */
    val shotEvents: StateFlow<ShotEvent?> = bleRepository.shotEvents
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = null
        )
    
    /**
     * Connect to BLE device
     */
    fun connectToDevice(deviceAddress: String) {
        viewModelScope.launch {
            val result = bleRepository.connect(deviceAddress)
            result.onFailure {
                // Handle connection error
            }
        }
    }
    
    /**
     * Disconnect from BLE device
     */
    fun disconnectDevice() {
        viewModelScope.launch {
            bleRepository.disconnect()
        }
    }
    
    /**
     * Get device authentication data for device binding
     */
    suspend fun getDeviceAuthData(): Result<String> {
        return bleRepository.getDeviceAuthData()
    }
    
    /**
     * Authenticate device after BLE connection
     */
    private suspend fun authenticateDevice() {
        try {
            Log.d("BLEViewModel", "Requesting device auth data")
            val authDataResult = getDeviceAuthData()
            if (authDataResult.isSuccess) {
                val authData = authDataResult.getOrThrow()
                Log.d("BLEViewModel", "Received auth data, authenticating device")
                val authResult = deviceAuthManager.authenticateDevice(authData)
                if (authResult.isSuccess) {
                    Log.d("BLEViewModel", "Device authentication successful")
                } else {
                    Log.e("BLEViewModel", "Device authentication failed: ${authResult.exceptionOrNull()?.message}")
                }
            } else {
                Log.e("BLEViewModel", "Failed to get device auth data: ${authDataResult.exceptionOrNull()?.message}")
            }
        } catch (e: Exception) {
            Log.e("BLEViewModel", "Error during device authentication: ${e.message}")
        }
    }
    
    /**
     * Send ready signal to device
     */
    fun sendReady() {
        viewModelScope.launch {
            val result = bleRepository.sendReady()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Start receiving shots
     */
    fun startShooting() {
        viewModelScope.launch {
            val result = bleRepository.startShooting()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Stop receiving shots
     */
    fun stopShooting() {
        viewModelScope.launch {
            val result = bleRepository.stopShooting()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Check if device is connected
     */
    fun isConnected(): Boolean = bleUiState.value.isConnected
}
