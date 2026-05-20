package com.flextarget.android.ui.ipsc

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ScoringUtility
import com.flextarget.android.data.remote.api.IpscMatch
import com.flextarget.android.data.remote.api.IpscScoreHits
import com.flextarget.android.data.remote.api.IpscScoreTargetRow
import com.flextarget.android.data.remote.api.IpscScorePenalties
import com.flextarget.android.data.remote.api.IpscScoreSubmitRequest
import com.flextarget.android.data.remote.api.IpscShooter
import com.flextarget.android.data.remote.api.IpscSquad
import com.flextarget.android.data.repository.IpscRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Steps in the IPSC submit dialog flow:
 *
 * Idle → LoadingMatches → MatchPicker
 *                              ↓ selectMatch
 *                        LoadingSquads → ShooterPicker
 *                                             ↓ selectShooter
 *                                        Confirm → Submitting → Success
 *                                                             → Error
 */
sealed class IpscSubmitStep {
    object Idle : IpscSubmitStep()
    object LoadingMatches : IpscSubmitStep()
    data class MatchPicker(val matches: List<IpscMatch>) : IpscSubmitStep()
    data class LoadingSquads(val matchId: Int) : IpscSubmitStep()
    data class ShooterPicker(val matchId: Int, val squads: List<IpscSquad>) : IpscSubmitStep()
    data class Confirm(val matchId: Int, val shooter: IpscShooter) : IpscSubmitStep()
    object Submitting : IpscSubmitStep()
    data class Success(val hitFactor: Double, val totalPoints: Int) : IpscSubmitStep()
    data class Error(val message: String, val retryAction: (() -> Unit)? = null) : IpscSubmitStep()
}

class IpscSubmitViewModel(
    private val repository: IpscRepository
) : ViewModel() {

    private val _step = MutableStateFlow<IpscSubmitStep>(IpscSubmitStep.Idle)
    val step: StateFlow<IpscSubmitStep> = _step

    // ---- Lifecycle ----

    /** Start the flow: fetch matches and move to MatchPicker. */
    fun start() {
        loadMatches(forceRefresh = false)
    }

    /** Go back one step (Confirm → ShooterPicker, ShooterPicker → MatchPicker). */
    fun back() {
        when (val current = _step.value) {
            is IpscSubmitStep.Confirm -> {
                val matchId = current.matchId
                viewModelScope.launch {
                    _step.value = IpscSubmitStep.LoadingSquads(matchId)
                    repository.getSquadQueue(matchId).fold(
                        onSuccess = { squads -> _step.value = IpscSubmitStep.ShooterPicker(matchId, squads) },
                        onFailure = { e ->
                            _step.value = IpscSubmitStep.Error(e.message ?: "Error loading squads") { selectMatch(matchId) }
                        }
                    )
                }
            }
            is IpscSubmitStep.ShooterPicker -> loadMatches(forceRefresh = false)
            else -> { /* no-op */ }
        }
    }

    /** Reset to Idle (call when dialog is dismissed). */
    fun dismiss() {
        _step.value = IpscSubmitStep.Idle
    }

    // ---- Step transitions ----

    fun refreshMatches() = loadMatches(forceRefresh = true)

    fun selectMatch(matchId: Int) {
        viewModelScope.launch {
            _step.value = IpscSubmitStep.LoadingSquads(matchId)
            repository.getSquadQueue(matchId).fold(
                onSuccess = { squads -> _step.value = IpscSubmitStep.ShooterPicker(matchId, squads) },
                onFailure = { e ->
                    _step.value = IpscSubmitStep.Error(e.message ?: "Error loading squads") { selectMatch(matchId) }
                }
            )
        }
    }

    fun refreshSquads(matchId: Int) {
        viewModelScope.launch {
            _step.value = IpscSubmitStep.LoadingSquads(matchId)
            repository.getSquadQueue(matchId, forceRefresh = true).fold(
                onSuccess = { squads -> _step.value = IpscSubmitStep.ShooterPicker(matchId, squads) },
                onFailure = { e ->
                    _step.value = IpscSubmitStep.Error(e.message ?: "Error loading squads") { refreshSquads(matchId) }
                }
            )
        }
    }

    fun selectShooter(matchId: Int, shooter: IpscShooter) {
        _step.value = IpscSubmitStep.Confirm(matchId, shooter)
    }

    /**
     * Build and submit an [IpscScoreSubmitRequest] from [summary].
     * Uses [summary.adjustedHitZones] if available, otherwise falls back to
     * [ScoringUtility.calculateEffectiveCounts].
     */
    fun submit(
        matchId: Int,
        shooter: IpscShooter,
        stageId: String,
        summary: DrillRepeatSummary
    ) {
        val hitZones = summary.adjustedHitZones
            ?: ScoringUtility.calculateEffectiveCounts(summary.shots, null)

        val request = IpscScoreSubmitRequest(
            shooterBib = shooter.bibNumber,
            stageId = stageId,
            totalTime = summary.totalTime,
            hits = IpscScoreHits(
                a = hitZones["A"] ?: 0,
                c = hitZones["C"] ?: 0,
                d = hitZones["D"] ?: 0,
                m = hitZones["M"] ?: 0,
                n = hitZones["N"] ?: 0
            ),
            rows = buildRows(summary),
            penalties = IpscScorePenalties(pe = hitZones["PE"] ?: 0),
            firstShot = if (summary.firstShot > 0) summary.firstShot else null,
            fastestSplit = if (summary.fastest > 0) summary.fastest else null
        )

        viewModelScope.launch {
            _step.value = IpscSubmitStep.Submitting
            repository.submitScore(matchId, request).fold(
                onSuccess = { data ->
                    repository.invalidateCache(matchId)
                    _step.value = IpscSubmitStep.Success(data.hitFactor, data.totalPoints)
                },
                onFailure = { e ->
                    _step.value = IpscSubmitStep.Error(e.message ?: "Submission failed") {
                        submit(matchId, shooter, stageId, summary)
                    }
                }
            )
        }
    }

    private data class RowAccumulator(
        val rowType: String,
        val key: String,
        var a: Int = 0,
        var c: Int = 0,
        var d: Int = 0,
        var m: Int = 0,
        var n: Int = 0
    )

    private fun buildRows(summary: DrillRepeatSummary): List<IpscScoreTargetRow>? {
        val grouped = linkedMapOf<String, RowAccumulator>()

        summary.shots.forEach { shot ->
            val targetType = shot.content.actualTargetType.trim().lowercase()
            val rawHitArea = shot.content.actualHitArea
            val isAPopper = isAPopperHitArea(rawHitArea)
            val rowType = if (
                isAPopper ||
                targetType.contains("steel") ||
                targetType.contains("popper") ||
                targetType.contains("paddle")
            ) "steel" else "paper"

            val targetName = shot.target?.trim().takeUnless { it.isNullOrEmpty() }
                ?: shot.content.device?.trim().takeUnless { it.isNullOrEmpty() }
                ?: shot.device?.trim().takeUnless { it.isNullOrEmpty() }
                ?: "target"

            val keyTargetType = if (isAPopper) "apopper" else targetType
            val key = "$rowType|${targetName.lowercase()}|$keyTargetType"
            val row = grouped.getOrPut(key) { RowAccumulator(rowType = rowType, key = key) }

            when (normalizeHitArea(rawHitArea)) {
                "a" -> row.a += 1
                "c" -> row.c += 1
                "d" -> row.d += 1
                "m" -> row.m += 1
                "n" -> row.n += 1
            }
        }

        if (grouped.isEmpty()) return null

        val steelRows = grouped.values
            .filter { it.rowType == "steel" }
            .sortedBy { it.key }
            .mapIndexed { index, row ->
                IpscScoreTargetRow(
                    rowType = "steel",
                    rowNo = index + 1,
                    a = row.a,
                    c = row.c,
                    d = row.d,
                    m = row.m,
                    n = row.n
                )
            }

        val paperRows = grouped.values
            .filter { it.rowType == "paper" }
            .sortedBy { it.key }
            .mapIndexed { index, row ->
                IpscScoreTargetRow(
                    rowType = "paper",
                    rowNo = index + 1,
                    a = row.a,
                    c = row.c,
                    d = row.d,
                    m = row.m,
                    n = row.n
                )
            }

        return steelRows + paperRows
    }

    private fun isAPopperHitArea(raw: String?): Boolean {
        return when (raw?.trim()?.lowercase()) {
            "apopper", "a_popper", "a-popper" -> true
            else -> false
        }
    }

    private fun normalizeHitArea(raw: String?): String {
        return when (raw?.trim()?.lowercase()) {
            "a", "azone", "a_zone", "a-zone", "circlearea", "popperzone", "apopper" -> "a"
            "c", "czone", "c_zone", "c-zone" -> "c"
            "d", "dzone", "d_zone", "d-zone" -> "d"
            "m", "miss" -> "m"
            "n", "ns", "whitezone", "no_shoot", "no-shoot", "noshoot" -> "n"
            "blackzone", "blackzoneleft", "blackzoneright",
            "black_zone", "black-zone", "black_zone_left", "black-zone-left", "black_zone_right", "black-zone-right" -> "m"
            else -> "unknown"
        }
    }

    // ---- Private helpers ----

    private fun loadMatches(forceRefresh: Boolean) {
        viewModelScope.launch {
            _step.value = IpscSubmitStep.LoadingMatches
            repository.getMatches(forceRefresh).fold(
                onSuccess = { matches -> _step.value = IpscSubmitStep.MatchPicker(matches) },
                onFailure = { e ->
                    _step.value = IpscSubmitStep.Error(e.message ?: "Error loading matches") {
                        loadMatches(forceRefresh = true)
                    }
                }
            )
        }
    }
}
