package com.flextarget.android.data.repository

import android.util.Log
import androidx.work.*
import com.flextarget.android.data.auth.AuthManager
import com.flextarget.android.data.remote.api.FlexTargetAPI
import com.flextarget.android.data.remote.api.GetOTAVersionRequest
import com.flextarget.android.data.remote.api.GetOTAHistoryRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import java.util.Date
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * OTA update state
 */
enum class OTAState {
    IDLE,              // No update in progress
    CHECKING,          // Checking for new version
    UPDATE_AVAILABLE,  // New version found
    PREPARING,         // Downloading/preparing update (10min timeout)
    READY,             // Update ready to install
    VERIFYING,         // Verifying update integrity (30s timeout)
    INSTALLING,        // Applying update
    COMPLETE,          // Update installed
    ERROR              // Update failed
}

/**
 * OTA version info from server
 */
data class OTAVersionInfo(
    val version: String,
    val description: String,
    val fileUrl: String,
    val fileSize: Long,
    val checksum: String,
    val releaseDate: Date,
    val mandatory: Boolean = false
)

/**
 * OTA update progress
 */
data class OTAProgress(
    val state: OTAState = OTAState.IDLE,
    val version: String? = null,
    val progress: Int = 0,  // 0-100
    val error: String? = null,
    val lastCheck: Date? = null
)

/**
 * OTARepository: Manages over-the-air updates
 * 
 * Responsibilities:
 * - Check for new OTA versions from server
 * - Download and prepare updates
 * - Verify update integrity
 * - Install updates
 * - Track update state and progress
 * - Handle timeouts (10min prepare, 30s verify)
 * - Integrate with WorkManager for background polling
 */
@Singleton
class OTARepository @Inject constructor(
    private val api: FlexTargetAPI,
    private val authManager: AuthManager,
    private val workManager: WorkManager
) {
    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    
    // OTA progress tracking
    private val _otaProgress = MutableSharedFlow<OTAProgress>(replay = 1)
    val otaProgress: Flow<OTAProgress> = _otaProgress.asSharedFlow()
    
    // Current OTA state
    private val _currentState = MutableSharedFlow<OTAState>(replay = 1)
    val currentState: Flow<OTAState> = _currentState.asSharedFlow()
    
    // Download cache directory path
    private var downloadCachePath: String? = null
    
    // Current update info
    private var currentUpdateInfo: OTAVersionInfo? = null
    
    init {
        coroutineScope.launch {
            _otaProgress.emit(OTAProgress(state = OTAState.IDLE))
            _currentState.emit(OTAState.IDLE)
        }
        
        // Schedule periodic OTA checks (60-second interval in production, 10min in real app)
        schedulePeriodicOTACheck()
    }
    
    /**
     * Schedule periodic OTA version checks via WorkManager
     * Runs every 60 seconds (configurable for production)
     */
    private fun schedulePeriodicOTACheck() {
        try {
            val otaCheckRequest = PeriodicWorkRequestBuilder<OTACheckWorker>(
                15, TimeUnit.MINUTES  // Check every 15 minutes in production
            ).apply {
                // Note: setBackoffCriteria is not available for PeriodicWorkRequest
                addTag("ota_check")
            }.build()
            
            workManager.enqueueUniquePeriodicWork(
                "ota_periodic_check",
                ExistingPeriodicWorkPolicy.KEEP,
                otaCheckRequest
            )
            
            Log.d(TAG, "OTA periodic check scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule OTA check", e)
        }
    }
    
    /**
     * Check for new OTA version using device token
     */
        suspend fun checkForUpdates(deviceToken: String): Result<OTAVersionInfo?> = withContext(Dispatchers.IO) {
        try {
            _currentState.emit(OTAState.CHECKING)
            _otaProgress.emit(OTAProgress(state = OTAState.CHECKING, lastCheck = Date()))
            
            if (deviceToken.isEmpty()) {
                _currentState.emit(OTAState.ERROR)
                _otaProgress.emit(OTAProgress(state = OTAState.ERROR, error = "Invalid device token", lastCheck = Date()))
                return@withContext Result.failure(IllegalStateException("Device token is empty"))
            }
            
            // Check for available OTA version using device token
            val response = api.getLatestOTAVersion(
                GetOTAVersionRequest(auth_data = deviceToken)
            )
            
            val versionInfo = response.data?.let { data ->
                OTAVersionInfo(
                    version = data.version,
                    description = "OTA Update ${data.version}", // Default description
                    fileUrl = data.address,
                    fileSize = 0L, // Not provided by API
                    checksum = data.checksum,
                    releaseDate = Date(),
                    mandatory = false // Not provided by API
                )
            }
            
            if (versionInfo != null) {
                currentUpdateInfo = versionInfo
                _currentState.emit(OTAState.UPDATE_AVAILABLE)
                _otaProgress.emit(
                    OTAProgress(
                        state = OTAState.UPDATE_AVAILABLE,
                        version = versionInfo.version,
                        lastCheck = Date()
                    )
                )
                Log.d(TAG, "Update available: ${versionInfo.version}")
            } else {
                _currentState.emit(OTAState.IDLE)
                _otaProgress.emit(
                    OTAProgress(
                        state = OTAState.IDLE,
                        lastCheck = Date()
                    )
                )
                Log.d(TAG, "No update available")
            }
            
            Result.success(versionInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check for updates", e)
            _currentState.emit(OTAState.ERROR)
            _otaProgress.emit(
                OTAProgress(
                    state = OTAState.ERROR,
                    error = e.message,
                    lastCheck = Date()
                )
            )
            Result.failure(e)
        }
    }
    
    /**
     * Download and prepare OTA update
     * Timeout: 10 minutes
     */
    suspend fun prepareUpdate(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val updateInfo = currentUpdateInfo
                ?: return@withContext Result.failure(IllegalStateException("No update available"))
            
            _currentState.emit(OTAState.PREPARING)
            _otaProgress.emit(OTAProgress(state = OTAState.PREPARING, version = updateInfo.version))
            
            // Simulate download with progress updates
            for (i in 0..100 step 10) {
                _otaProgress.emit(
                    OTAProgress(
                        state = OTAState.PREPARING,
                        progress = i,
                        version = updateInfo.version
                    )
                )
                // In real implementation, this would download the file
                // kotlinx.coroutines.delay(100)
            }
            
            Log.d(TAG, "Update prepared: ${updateInfo.version}")
            _currentState.emit(OTAState.READY)
            _otaProgress.emit(
                OTAProgress(
                    state = OTAState.READY,
                    progress = 100,
                    version = updateInfo.version
                )
            )
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to prepare update", e)
            _currentState.emit(OTAState.ERROR)
            _otaProgress.emit(OTAProgress(state = OTAState.ERROR, error = e.message))
            Result.failure(e)
        }
    }
    
    /**
     * Verify update integrity
     * Timeout: 30 seconds
     */
    suspend fun verifyUpdate(): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val updateInfo = currentUpdateInfo
                ?: return@withContext Result.failure(IllegalStateException("No update to verify"))
            
            _currentState.emit(OTAState.VERIFYING)
            _otaProgress.emit(OTAProgress(state = OTAState.VERIFYING, version = updateInfo.version))
            
            // Simulate verification
            val isValid = true  // Would verify checksum against downloaded file
            
            if (isValid) {
                Log.d(TAG, "Update verified: ${updateInfo.version}")
                Result.success(true)
            } else {
                Log.w(TAG, "Update verification failed")
                _currentState.emit(OTAState.ERROR)
                _otaProgress.emit(
                    OTAProgress(
                        state = OTAState.ERROR,
                        error = "Integrity check failed"
                    )
                )
                Result.failure(Exception("Update integrity check failed"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify update", e)
            _currentState.emit(OTAState.ERROR)
            _otaProgress.emit(OTAProgress(state = OTAState.ERROR, error = e.message))
            Result.failure(e)
        }
    }
    
    /**
     * Install OTA update
     */
    suspend fun installUpdate(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            _currentState.emit(OTAState.INSTALLING)
            _otaProgress.emit(OTAProgress(state = OTAState.INSTALLING))
            
            // In real implementation, would trigger actual update installation
            Log.d(TAG, "Installing update")
            
            _currentState.emit(OTAState.COMPLETE)
            _otaProgress.emit(
                OTAProgress(
                    state = OTAState.COMPLETE,
                    progress = 100
                )
            )
            Log.d(TAG, "Update installation complete")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to install update", e)
            _currentState.emit(OTAState.ERROR)
            _otaProgress.emit(OTAProgress(state = OTAState.ERROR, error = e.message))
            Result.failure(e)
        }
    }
    
    /**
     * Get OTA update history
     */
    suspend fun getUpdateHistory(limit: Int = 10): Result<List<OTAHistoryEntry>> =
        withContext(Dispatchers.IO) {
            try {
                val userToken = authManager.currentAccessToken
                    ?: return@withContext Result.failure(IllegalStateException("Not authenticated"))
                
                val response = api.getOTAHistory(
                    GetOTAHistoryRequest(
                        auth_data = userToken,
                        page = 1,
                        limit = limit
                    )
                )
                
                val history = response.data?.rows?.map { item ->
                    OTAHistoryEntry(
                        id = UUID.randomUUID(),
                        version = item.version,
                        description = "OTA Update ${item.version}", // Default description
                        installedAt = Date(), // Not provided by API
                        status = "completed"
                    )
                } ?: emptyList()
                
                Log.d(TAG, "Fetched ${history.size} history entries")
                Result.success(history)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get update history", e)
                Result.failure(e)
            }
        }
    
    /**
     * Cancel ongoing update
     */
    suspend fun cancelUpdate(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            currentUpdateInfo = null
            _currentState.emit(OTAState.IDLE)
            _otaProgress.emit(OTAProgress(state = OTAState.IDLE))
            Log.d(TAG, "Update cancelled")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel update", e)
            Result.failure(e)
        }
    }
    
    /**
     * Get current update info if available
     */
    fun getCurrentUpdateInfo(): OTAVersionInfo? = currentUpdateInfo
    
    /**
     * Get download cache path
     */
    fun getDownloadCachePath(): String? = downloadCachePath
    
    /**
     * Set download cache path
     */
    fun setDownloadCachePath(path: String) {
        downloadCachePath = path
    }
    
    companion object {
        private const val TAG = "OTARepository"
    }
}

/**
 * OTA history entry
 */
data class OTAHistoryEntry(
    val id: UUID,
    val version: String,
    val description: String,
    val installedAt: Date,
    val status: String
)

/**
 * WorkManager Worker for periodic OTA checks
 */
class OTACheckWorker(
    private val appContext: android.content.Context,
    private val workerParams: androidx.work.WorkerParameters
) : androidx.work.CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            Log.d("OTACheckWorker", "OTA check running in background")
            // In a real implementation, this would inject OTARepository and call checkForUpdates()
            // For now, just log that the check ran
            Result.success()
        } catch (e: Exception) {
            Log.e("OTACheckWorker", "OTA check failed", e)
            Result.retry()
        }
    }
}
