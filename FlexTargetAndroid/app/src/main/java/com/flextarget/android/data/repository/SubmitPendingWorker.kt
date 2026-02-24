package com.flextarget.android.data.repository

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.flextarget.android.di.AppContainer

/**
 * Worker that attempts to sync pending `game_plays` when network is available.
 */
class SubmitPendingWorker(
    private val appContext: Context,
    private val workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            Log.d(TAG, "SubmitPendingWorker started")
            // Use the shared container to access CompetitionRepository
            val result = AppContainer.competitionRepository.syncPendingGamePlays()

            if (result.isSuccess) {
                Log.d(TAG, "SubmitPendingWorker completed: synced ${result.getOrNull()} items")
                Result.success()
            } else {
                val err = result.exceptionOrNull()
                Log.w(TAG, "SubmitPendingWorker failed: ${err}")
                // Retry on network issues
                if (err is IllegalStateException && err.message == "NetworkUnavailable") {
                    Result.retry()
                } else {
                    Result.failure()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "SubmitPendingWorker unexpected failure", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "SubmitPendingWorker"
    }
}
