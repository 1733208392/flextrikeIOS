package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ShotData
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.google.gson.Gson
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * ViewModel for drill record/history view.
 * Ported from iOS DrillRecordView.
 */
class DrillRecordViewModel(
    private val drillResultRepository: DrillResultRepository,
    private val drillSetupRepository: DrillSetupRepository
) : ViewModel() {

    private val gson = Gson()

    // Get all drill results with shots for a specific drill setup
    fun getDrillResultsWithShots(drillSetupId: UUID): Flow<List<DrillResultWithShots>> {
        return drillResultRepository.getDrillResultsWithShotsBySetupId(drillSetupId)
    }

    // Group results by month and session (ported from iOS sessionGroupedResults)
    fun getGroupedResults(drillSetupId: UUID): Flow<List<GroupedResults>> {
        return getDrillResultsWithShots(drillSetupId).map { results ->
            groupResultsByMonthAndSession(results)
        }
    }

    private fun groupResultsByMonthAndSession(results: List<DrillResultWithShots>): List<GroupedResults> {
        // Group by month
        val monthGrouped = results.groupBy { result ->
            val date = result.drillResult.date ?: Date()
            val formatter = SimpleDateFormat("MMM yyyy", Locale.getDefault())
            formatter.format(date)
        }

        return monthGrouped.map { (monthKey, monthResults) ->
            // Sort by date descending
            val sortedByDate = monthResults.sortedByDescending { it.drillResult.date ?: Date() }

            // Group by sessionId
            val sessionGrouped = sortedByDate.groupBy { it.drillResult.sessionId ?: UUID.randomUUID() }

            val sessions = sessionGrouped.map { (sessionId, sessionResults) ->
                val sortedSessionResults = sessionResults.sortedByDescending { it.drillResult.date ?: Date() }
                val firstResult = sortedSessionResults.first()
                val summaries = sortedSessionResults.map { createDrillRepeatSummary(it) }

                SessionData(
                    sessionId = sessionId,
                    firstResult = firstResult,
                    allResults = sortedSessionResults,
                    summaries = summaries
                )
            }.sortedByDescending { it.firstResult.drillResult.date ?: Date() }

            GroupedResults(
                monthKey = monthKey,
                sessions = sessions
            )
        }.sortedByDescending { it.sessions.firstOrNull()?.firstResult?.drillResult?.date ?: Date() }
    }

    private fun createDrillRepeatSummary(resultWithShots: DrillResultWithShots): DrillRepeatSummary {
        val shots = convertShots(resultWithShots.shots)
        return DrillRepeatSummary(
            id = resultWithShots.drillResult.id,
            repeatIndex = 1,
            totalTime = resultWithShots.drillResult.totalTime,
            numShots = shots.size,
            firstShot = shots.firstOrNull()?.content?.timeDiff ?: 0.0,
            fastest = calculateFastestShot(shots),
            score = calculateScore(shots),
            shots = shots
        )
    }

    private fun convertShots(shotEntities: List<com.flextarget.android.data.local.entity.ShotEntity>): List<ShotData> {
        return shotEntities.mapNotNull { shotEntity ->
            shotEntity.data?.let { jsonData ->
                try {
                    gson.fromJson(jsonData, ShotData::class.java)
                } catch (e: Exception) {
                    null
                }
            }
        }
    }

    private fun calculateFastestShot(shots: List<ShotData>): Double {
        return shots.mapNotNull { it.content.timeDiff }
            .filter { it > 0 }
            .minOrNull() ?: 0.0
    }

    private fun calculateScore(shots: List<ShotData>): Int {
        // Simple scoring: just count the shots for now
        return shots.size
    }

    fun deleteSession(sessionId: UUID) {
        viewModelScope.launch {
            // Delete all results in this session
            drillResultRepository.getDrillResultsBySessionId(sessionId).collect { results ->
                results.forEach { result ->
                    drillResultRepository.deleteDrillResult(result)
                }
            }
        }
    }

    // Data classes for grouped results
    data class GroupedResults(
        val monthKey: String,
        val sessions: List<SessionData>
    )

    data class SessionData(
        val sessionId: UUID,
        val firstResult: DrillResultWithShots,
        val allResults: List<DrillResultWithShots>,
        val summaries: List<DrillRepeatSummary>
    )

    suspend fun getTargetsForDrill(drillId: UUID): List<com.flextarget.android.data.model.DrillTargetsConfigData> {
        val drillWithTargets = drillSetupRepository.getDrillSetupWithTargets(drillId)
        return drillWithTargets?.targets?.map { entity ->
            com.flextarget.android.data.model.DrillTargetsConfigData(
                id = entity.id,
                seqNo = entity.seqNo,
                targetName = entity.targetName ?: "",
                targetType = entity.targetType ?: "ipsc",
                timeout = entity.timeout,
                countedShots = entity.countedShots
            )
        } ?: emptyList()
    }

    class Factory(
        private val drillResultRepository: DrillResultRepository,
        private val drillSetupRepository: DrillSetupRepository
    ) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(DrillRecordViewModel::class.java)) {
                @Suppress("UNCHECKED_CAST")
                return DrillRecordViewModel(drillResultRepository, drillSetupRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}