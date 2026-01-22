package com.flextarget.android.data.repository

import android.util.Log
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.dao.ShotDao
import com.flextarget.android.data.local.entity.ShotEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import java.util.Date
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.math.sqrt

/**
 * ShotEvent: Domain model for a single shot
 */
data class ShotEvent(
    val shotIndex: Int,
    val x: Double,
    val y: Double,
    val score: Int,
    val timestamp: Date = Date(),
    val confidence: Double = 1.0
)

/**
 * BLERepository: Manages Bluetooth Low Energy communication
 * 
 * Responsibilities:
 * - Handle BLE device connection/disconnection
 * - Receive and parse shot data from device
 * - Convert raw BLE messages to ShotEvent domain objects
 * - Provide real-time shot event streams
 * - Manage device state (connected, ready, shooting, etc.)
 */
@Singleton
class BLERepository @Inject constructor(
    private val shotDao: ShotDao
) {
    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    
    // State management
    private val _deviceState = MutableSharedFlow<DeviceState>(replay = 1)
    val deviceState: Flow<DeviceState> = _deviceState.asSharedFlow()
    
    // Real-time shot events
    private val _shotEvents = MutableSharedFlow<ShotEvent>()
    val shotEvents: Flow<ShotEvent> = _shotEvents.asSharedFlow()
    
    // Raw BLE messages (for debugging)
    private val _rawMessages = MutableSharedFlow<String>()
    val rawMessages: Flow<String> = _rawMessages.asSharedFlow()
    
    private var currentConnection: BLEConnection? = null
    private var currentSessionShots = mutableListOf<ShotEvent>()
    
    init {
        coroutineScope.launch {
            _deviceState.emit(DeviceState.Disconnected)
        }
    }
    
    /**
     * Get device authentication data for device binding
     * Called during 2-step device auth process
     */
    suspend fun getDeviceAuthData(): Result<String> = withContext(Dispatchers.IO) {
        if (!BLEManager.shared.isConnected) {
            return@withContext Result.failure(
                IllegalStateException("Device not connected")
            )
        }

        return@withContext suspendCancellableCoroutine { continuation ->
            var timeoutJob: Job? = null

            // Register callback to receive auth data response
            BLEManager.shared.onAuthDataReceived = { authData ->
                timeoutJob?.cancel()
                BLEManager.shared.onAuthDataReceived = null
                Log.d(TAG, "Retrieved device auth data")
                continuation.resume(Result.success(authData))
            }

            // Send BLE command to request auth data from device
            val timestamp = System.currentTimeMillis()
            val command = """{"action":"get_auth_data","timestamp":$timestamp}"""
            BLEManager.shared.writeJSON(command)
            Log.d(TAG, "Sent get_auth_data command to device")

            // Set 10-second timeout guard
            timeoutJob = CoroutineScope(Dispatchers.Main).launch {
                delay(10000)
                BLEManager.shared.onAuthDataReceived = null
                Log.e(TAG, "Device auth data request timed out")
                continuation.resume(Result.failure(
                    Exception("Device did not respond with auth_data within 10 seconds")
                ))
            }
        }
    }
    
    /**
     * Send ready signal to device (start of drill)
     */
    suspend fun sendReady(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            currentConnection?.sendCommand("READY")
                ?: return@withContext Result.failure(IllegalStateException("No BLE connection"))
            
            currentSessionShots.clear()
            _deviceState.emit(DeviceState.Ready)
            Log.d(TAG, "Ready signal sent to device")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send ready signal", e)
            Result.failure(e)
        }
    }
    
    /**
     * Start receiving shots (drill execution begins)
     */
    suspend fun startShooting(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            currentConnection?.sendCommand("START_SHOOTING")
                ?: return@withContext Result.failure(IllegalStateException("No BLE connection"))
            
            _deviceState.emit(DeviceState.Shooting)
            Log.d(TAG, "Shooting started")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start shooting", e)
            Result.failure(e)
        }
    }
    
    /**
     * Stop receiving shots and finalize drill
     */
    suspend fun stopShooting(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            currentConnection?.sendCommand("STOP_SHOOTING")
                ?: return@withContext Result.failure(IllegalStateException("No BLE connection"))
            
            _deviceState.emit(DeviceState.Ready)
            Log.d(TAG, "Shooting stopped, ${currentSessionShots.size} shots recorded")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop shooting", e)
            Result.failure(e)
        }
    }
    
    /**
     * Handle incoming BLE message from device
     * Parses JSON shot data and emits ShotEvent
     */
    suspend fun processMessage(message: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            _rawMessages.emit(message)
            
            // Parse shot data from device message
            val shot = parseShotMessage(message)
            if (shot != null) {
                currentSessionShots.add(shot)
                _shotEvents.emit(shot)
                Log.d(TAG, "Shot received: X=${shot.x}, Y=${shot.y}, Score=${shot.score}")
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process BLE message", e)
            Result.failure(e)
        }
    }
    
    /**
     * Get all shots from current session
     */
    fun getCurrentSessionShots(): List<ShotEvent> = currentSessionShots.toList()
    
    /**
     * Save shots from session to database
     */
    suspend fun saveSessionShots(drillResultId: UUID): Result<Int> = withContext(Dispatchers.IO) {
        try {
            val shots = currentSessionShots.map { event ->
                // Serialize shot data as JSON string to match ShotEntity structure
                val shotData = """
                    {
                        "shotIndex": ${event.shotIndex},
                        "x": ${event.x},
                        "y": ${event.y},
                        "score": ${event.score},
                        "timestamp": "${event.timestamp.time}"
                    }
                """.trimIndent()

                ShotEntity(
                    data = shotData,
                    timestamp = event.timestamp.time,
                    drillResultId = drillResultId
                )
            }

            shots.forEach { shotDao.insertShot(it) }
            Log.d(TAG, "Saved ${shots.size} shots to database")
            Result.success(shots.size)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save session shots", e)
            Result.failure(e)
        }
    }
    
    /**
     * Connect to BLE device
     */
    suspend fun connect(deviceAddress: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            _deviceState.emit(DeviceState.Connecting)
            
            // Initialize BLE connection (would use actual BLE manager)
            currentConnection = BLEConnection(deviceAddress)
            currentConnection?.connect()
            
            _deviceState.emit(DeviceState.Connected)
            Log.d(TAG, "Connected to device: $deviceAddress")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect to device", e)
            _deviceState.emit(DeviceState.Disconnected)
            Result.failure(e)
        }
    }
    
    /**
     * Disconnect from BLE device
     */
    suspend fun disconnect(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            currentConnection?.disconnect()
            currentConnection = null
            _deviceState.emit(DeviceState.Disconnected)
            Log.d(TAG, "Disconnected from device")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disconnect from device", e)
            Result.failure(e)
        }
    }
    
    /**
     * Parse shot data from device message
     * 
     * Expected message format (JSON):
     * {
     *   "shot": 1,
     *   "x": 45.5,
     *   "y": 32.1,
     *   "score": 10,
     *   "time": "2024-01-15 14:30:45"
     * }
     */
    private fun parseShotMessage(message: String): ShotEvent? {
        return try {
            // Simple JSON parsing (would use kotlinx.serialization or Gson in production)
            val shotIndex = message.extractIntValue("\"shot\"\\s*:\\s*(\\d+)".toRegex())
            val x = message.extractDoubleValue("\"x\"\\s*:\\s*([\\d.]+)".toRegex())
            val y = message.extractDoubleValue("\"y\"\\s*:\\s*([\\d.]+)".toRegex())
            val score = message.extractIntValue("\"score\"\\s*:\\s*(\\d+)".toRegex())
            
            if (shotIndex >= 0 && x >= 0 && y >= 0 && score >= 0) {
                ShotEvent(
                    shotIndex = shotIndex,
                    x = x,
                    y = y,
                    score = score
                )
            } else null
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse shot message: $message", e)
            null
        }
    }
    
    companion object {
        private const val TAG = "BLERepository"
    }
}

/**
 * Device connection state enum
 */
enum class DeviceState {
    Disconnected,
    Connecting,
    Connected,
    Ready,
    Shooting,
    Error
}

/**
 * BLE connection wrapper (placeholder for actual BLE manager)
 */
class BLEConnection(val deviceAddress: String) {
    suspend fun connect() {
        // Would implement actual BLE connection
    }
    
    suspend fun disconnect() {
        // Would implement actual BLE disconnection
    }
    
    suspend fun sendCommand(command: String): String {
        // Would send command via BLE and wait for response
        return ""
    }
}

// Extension functions for regex-based JSON parsing
private fun String.extractIntValue(pattern: Regex): Int {
    return pattern.find(this)?.groupValues?.get(1)?.toIntOrNull() ?: -1
}

private fun String.extractDoubleValue(pattern: Regex): Double {
    return pattern.find(this)?.groupValues?.get(1)?.toDoubleOrNull() ?: -1.0
}
