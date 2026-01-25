package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ShotData
import com.flextarget.android.data.model.ScoringUtility
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.drills.DrillSession
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class HistoryTabViewModel(
    private val drillResultRepository: DrillResultRepository,
    private val drillSetupRepository: DrillSetupRepository
) : ViewModel() {

    private val _groupedResults = MutableStateFlow<Map<String, List<DrillSession>>>(emptyMap())
    val groupedResults: StateFlow<Map<String, List<DrillSession>>> = _groupedResults

    private val _uniqueDrillTypes = MutableStateFlow<List<String>>(emptyList())
    val uniqueDrillTypes: StateFlow<List<String>> = _uniqueDrillTypes

    private val _uniqueDrillNames = MutableStateFlow<List<String>>(emptyList())
    val uniqueDrillNames: StateFlow<List<String>> = _uniqueDrillNames

    private val gson = Gson()
    private val dateFormatter = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            try {
                // Load all drill results with shots
                val allResults = drillResultRepository.allDrillResultsWithShots.first()

                // Group by session ID and create sessions
                val sessionGroups = mutableMapOf<String, MutableList<com.flextarget.android.data.local.entity.DrillResultWithShots>>()

                for (result in allResults) {
                    val sessionId = result.drillResult.sessionId?.toString() ?: UUID.randomUUID().toString()
                    if (sessionGroups[sessionId] == null) {
                        sessionGroups[sessionId] = mutableListOf()
                    }
                    sessionGroups[sessionId]?.add(result)
                }

                // Create DrillSession objects
                val sessions = sessionGroups.mapNotNull { (sessionId, results) ->
                    val firstResult = results.firstOrNull() ?: return@mapNotNull null
                    val setup = drillSetupRepository.getDrillSetupById(firstResult.drillResult.drillSetupId ?: return@mapNotNull null)
                        ?: return@mapNotNull null
                    
                    // Load drill setup with targets for score calculation
                    val setupWithTargets = drillSetupRepository.getDrillSetupWithTargets(setup.id)
                    val targets = setupWithTargets?.targets ?: emptyList()

                    val summaries = results.mapNotNull { result ->
                        convertToSummary(result, targets)
                    }.sortedBy { it.repeatIndex }

                    if (summaries.isEmpty()) return@mapNotNull null

                    DrillSession(
                        sessionId = sessionId,
                        setup = setup,
                        date = firstResult.drillResult.date,
                        results = summaries
                    )
                }.sortedByDescending { it.date ?: Date(0) }

                // Group by date
                val grouped = mutableMapOf<String, MutableList<DrillSession>>()
                for (session in sessions) {
                    val dateKey = session.date?.let { dateFormatter.format(it) } ?: "Unknown Date"
                    if (grouped[dateKey] == null) {
                        grouped[dateKey] = mutableListOf()
                    }
                    grouped[dateKey]?.add(session)
                }

                _groupedResults.value = grouped

                // Extract unique drill types and names
                val drillTypes = sessions.map { it.setup.mode }.filterNotNull().distinct().sorted()
                val drillNames = sessions.map { it.setup.name }.filterNotNull().distinct().sorted()

                _uniqueDrillTypes.value = drillTypes
                _uniqueDrillNames.value = drillNames

            } catch (e: Exception) {
                e.printStackTrace()
                _groupedResults.value = emptyMap()
                _uniqueDrillTypes.value = emptyList()
                _uniqueDrillNames.value = emptyList()
            }
        }
    }

    private fun convertToSummary(
        result: com.flextarget.android.data.local.entity.DrillResultWithShots,
        targets: List<com.flextarget.android.data.local.entity.DrillTargetsConfigEntity> = emptyList()
    ): DrillRepeatSummary? {
        try {
            val shots = result.shots.mapNotNull { shot ->
                shot.data?.let { data ->
                    try {
                        gson.fromJson(data, ShotData::class.java)
                    } catch (e: Exception) {
                        null
                    }
                }
            }

            if (shots.isEmpty()) return null

            val totalTime = if (result.drillResult.totalTime > 0) {
                result.drillResult.totalTime
            } else {
                shots.sumOf { it.content.actualTimeDiff }
            }

            val fastestShot = shots.minOfOrNull { it.content.actualTimeDiff } ?: 0.0
            val firstShot = shots.firstOrNull()?.content?.actualTimeDiff ?: 0.0
            
            // Calculate score using ScoringUtility
            val totalScore = ScoringUtility.calculateTotalScore(shots, targets).toInt()

            return DrillRepeatSummary(
                repeatIndex = 1, // Will be set by caller
                totalTime = totalTime,
                numShots = shots.size,
                firstShot = firstShot,
                fastest = fastestShot,
                score = totalScore,
                shots = shots
            )
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    class Factory(
        private val drillResultRepository: DrillResultRepository,
        private val drillSetupRepository: DrillSetupRepository
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(HistoryTabViewModel::class.java)) {
                return HistoryTabViewModel(drillResultRepository, drillSetupRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}