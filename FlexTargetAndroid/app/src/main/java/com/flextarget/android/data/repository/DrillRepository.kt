package com.flextarget.android.data.repository

import android.util.Log
import com.flextarget.android.data.local.dao.DrillResultDao
import com.flextarget.android.data.local.dao.DrillSetupDao
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import java.util.UUID

/**
 * Drill execution state
 */
enum class DrillExecutionState {
    IDLE,           // Not executing
    INITIALIZED,    // Ready to start
    WAITING_ACK,    // Sent ready, waiting for device ACK (10s timeout)
    EXECUTING,      // Actively receiving shots
    FINALIZING,     // Waiting for final shots
    COMPLETE,       // Drill finished
    ERROR           // Error state
}

/**
 * Drill execution context - holds state during active drill
 */
data class DrillExecutionContext(
    val drillId: UUID,
    val drillSetup: DrillSetupEntity,
    val state: DrillExecutionState = DrillExecutionState.IDLE,
    val shotsReceived: Int = 0,
    val totalScore: Int = 0,
    val startTime: Long = 0,
    val endTime: Long = 0
)

/**
 * DrillRepository: Orchestrates drill execution lifecycle
 * 
 * Responsibilities:
 * - Manage drill setup (fetch, create, update, delete)
 * - Orchestrate drill execution (ready → ACK → execute → finalize → complete)
 * - Track execution state and progress
 * - Coordinate between BLE and database layers
 * - Handle timeouts (10s for ACK, drill timeout from setup)
 * - Calculate scores and results
 * - Store drill results
 */
@Singleton
class DrillRepository @Inject constructor(
    private val drillSetupDao: DrillSetupDao,
    private val drillResultDao: DrillResultDao,
    private val bleRepository: BLERepository,
    private val bleMessageQueue: BLEMessageQueue
) {
    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    
    // Current execution context
    private val _executionContext = MutableStateFlow<DrillExecutionContext?>(null)
    val executionContext: Flow<DrillExecutionContext?> = _executionContext.asStateFlow()
    
    /**
     * Initialize drill execution
     * Sends READY signal to device and waits for ACK
     */
    suspend fun initializeDrill(drillId: UUID): Result<DrillExecutionContext> =
        withContext(Dispatchers.IO) {
            try {
                // Fetch drill setup
                val drill = drillSetupDao.getDrillSetupById(drillId)
                    ?: return@withContext Result.failure(IllegalArgumentException("Drill not found"))
                
                val context = DrillExecutionContext(
                    drillId = drillId,
                    drillSetup = drill,
                    state = DrillExecutionState.INITIALIZED,
                    startTime = System.currentTimeMillis()
                )
                
                _executionContext.value = context
                
                // Send READY signal to device
                bleRepository.sendReady()
                    .onFailure { return@withContext Result.failure(it) }
                
                // Update state: waiting for ACK
                _executionContext.value = context.copy(state = DrillExecutionState.WAITING_ACK)
                
                Log.d(TAG, "Drill initialized: $drillId, waiting for device ACK")
                Result.success(context)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize drill", e)
                _executionContext.value = _executionContext.value?.copy(state = DrillExecutionState.ERROR)
                Result.failure(e)
            }
        }
    
    /**
     * Confirm device ACK and start shooting
     * Called after receiving ACK from device (within 10s timeout)
     */
    suspend fun startExecuting(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val context = _executionContext.value
                ?: return@withContext Result.failure(IllegalStateException("No active drill"))
            
            if (context.state != DrillExecutionState.WAITING_ACK) {
                return@withContext Result.failure(
                    IllegalStateException("Invalid state: ${context.state}")
                )
            }
            
            // Send START_SHOOTING signal
            bleRepository.startShooting()
                .onFailure { return@withContext Result.failure(it) }
            
            // Update state
            _executionContext.value = context.copy(state = DrillExecutionState.EXECUTING)
            
            Log.d(TAG, "Drill execution started")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start drill execution", e)
            _executionContext.value = _executionContext.value?.copy(state = DrillExecutionState.ERROR)
            Result.failure(e)
        }
    }
    
    /**
     * Finalize drill execution
     * Sends STOP_SHOOTING signal and waits for remaining shots
     */
    suspend fun finalizeDrill(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val context = _executionContext.value
                ?: return@withContext Result.failure(IllegalStateException("No active drill"))
            
            if (context.state != DrillExecutionState.EXECUTING) {
                return@withContext Result.failure(
                    IllegalStateException("Invalid state: ${context.state}")
                )
            }
            
            // Send STOP_SHOOTING signal
            bleRepository.stopShooting()
                .onFailure { return@withContext Result.failure(it) }
            
            // Update state: finalizing (waiting for last shots)
            _executionContext.value = context.copy(state = DrillExecutionState.FINALIZING)
            
            Log.d(TAG, "Drill finalization started")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to finalize drill", e)
            _executionContext.value = _executionContext.value?.copy(state = DrillExecutionState.ERROR)
            Result.failure(e)
        }
    }
    
    /**
     * Complete drill execution and save results
     */
    suspend fun completeDrill(): Result<DrillExecutionContext> = withContext(Dispatchers.IO) {
        try {
            val context = _executionContext.value
                ?: return@withContext Result.failure(IllegalStateException("No active drill"))
            
            if (context.state !in listOf(DrillExecutionState.EXECUTING, DrillExecutionState.FINALIZING)) {
                return@withContext Result.failure(
                    IllegalStateException("Invalid state: ${context.state}")
                )
            }
            
            // Collect shots from current session
            val shots = bleRepository.getCurrentSessionShots()
            val totalScore = shots.sumOf { it.score }
            val endTime = System.currentTimeMillis()
            
            // Calculate average
            val averageScore = if (shots.isNotEmpty()) totalScore / shots.size else 0
            
            // Create drill result entity
            val drillResult = DrillResultEntity(
                date = java.util.Date(),
                drillId = context.drillId,
                sessionId = UUID.randomUUID(), // Generate unique session ID
                totalTime = (endTime - context.startTime) / 1000.0, // Convert to seconds
                drillSetupId = context.drillSetup.id
            )
            
            // Insert drill result and get its ID
            drillResultDao.insertDrillResult(drillResult)
            
            // Save shots to database with drill result ID
            bleRepository.saveSessionShots(drillResult.id)
                .onFailure { return@withContext Result.failure(it) }
            
            // Update context
            val completedContext = context.copy(
                state = DrillExecutionState.COMPLETE,
                shotsReceived = shots.size,
                totalScore = totalScore,
                endTime = endTime
            )
            
            _executionContext.value = completedContext
            
            Log.d(
                TAG,
                "Drill completed: ${shots.size} shots, total score: $totalScore, avg: $averageScore"
            )
            Result.success(completedContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to complete drill", e)
            _executionContext.value = _executionContext.value?.copy(state = DrillExecutionState.ERROR)
            Result.failure(e)
        }
    }
    
    /**
     * Abort drill execution
     */
    suspend fun abortDrill(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            bleRepository.stopShooting()
            _executionContext.value = null
            Log.d(TAG, "Drill aborted")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to abort drill", e)
            Result.failure(e)
        }
    }
    
    /**
     * Get all drills
     */
    fun getAllDrills(): Flow<List<DrillSetupEntity>> {
        return drillSetupDao.getAllDrillSetups()
    }
    
    /**
     * Get drill by ID
     */
    suspend fun getDrillById(id: UUID): DrillSetupEntity? = withContext(Dispatchers.IO) {
        try {
            drillSetupDao.getDrillSetupById(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get drill", e)
            null
        }
    }
    
    /**
     * Create new drill
     */
    suspend fun createDrill(
        name: String,
        description: String? = null,
        timeLimit: Int = 60  // seconds
    ): Result<UUID> = withContext(Dispatchers.IO) {
        try {
            val drill = DrillSetupEntity(
                name = name,
                desc = description,
                drillDuration = timeLimit.toDouble()
            )
            drillSetupDao.insertDrillSetup(drill)
            Log.d(TAG, "Drill created: ${drill.id}")
            Result.success(drill.id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create drill", e)
            Result.failure(e)
        }
    }
    
    /**
     * Update drill
     */
    suspend fun updateDrill(drill: DrillSetupEntity): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            drillSetupDao.updateDrillSetup(drill)
            Log.d(TAG, "Drill updated: ${drill.id}")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update drill", e)
            Result.failure(e)
        }
    }
    
    /**
     * Delete drill
     */
    suspend fun deleteDrill(id: UUID): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            drillSetupDao.deleteDrillSetupById(id)
            Log.d(TAG, "Drill deleted: $id")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete drill", e)
            Result.failure(e)
        }
    }
    
    /**
     * Get execution statistics
     */
    fun getExecutionStats(): Map<String, Any> {
        val context = _executionContext.value ?: return emptyMap()
        return mapOf(
            "state" to context.state,
            "shotsReceived" to context.shotsReceived,
            "totalScore" to context.totalScore,
            "elapsedTime" to (if (context.endTime > 0) context.endTime - context.startTime else System.currentTimeMillis() - context.startTime),
            "averageScore" to if (context.shotsReceived > 0) context.totalScore / context.shotsReceived else 0
        )
    }
    
    companion object {
        private const val TAG = "DrillRepository"
    }
}
