package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.preferences.AppPreferences
import com.flextarget.android.data.remote.api.IpscMatch
import com.flextarget.android.data.remote.api.IpscShooter
import com.flextarget.android.data.remote.api.IpscSquad
import com.flextarget.android.data.remote.api.IpscStage
import com.flextarget.android.data.repository.IpscRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CompetitionSessionSetupUiState(
    val matches: List<IpscMatch> = emptyList(),
    val stages: List<IpscStage> = emptyList(),
    val squads: List<IpscSquad> = emptyList(),
    val selectedMatchId: Int? = null,
    val selectedStageId: Int? = null,
    val selectedSquadId: Int? = null,
    val selectedShooterId: Int? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null
) {
    val selectedSquad: IpscSquad?
        get() = squads.firstOrNull { it.id == selectedSquadId }

    val availableShooters: List<IpscShooter>
        get() = selectedSquad?.shooters ?: emptyList()

    val selectedShooter: IpscShooter?
        get() = availableShooters.firstOrNull { it.id == selectedShooterId }
}

class CompetitionSessionSetupViewModel(
    private val repository: IpscRepository,
    private val preferences: AppPreferences
) : ViewModel() {

    private val _uiState = MutableStateFlow(CompetitionSessionSetupUiState())
    val uiState: StateFlow<CompetitionSessionSetupUiState> = _uiState.asStateFlow()

    private var hasAttemptedRestore = false

    fun loadMatchesIfNeeded() {
        if (_uiState.value.matches.isNotEmpty()) {
            return
        }
        loadMatches(forceRefresh = false)
    }

    fun refreshMatches() {
        loadMatches(forceRefresh = true)
    }

    fun refreshStages() {
        val matchId = _uiState.value.selectedMatchId ?: return
        loadStages(matchId = matchId, forceRefresh = true, preferredStageId = null)
    }

    fun refreshSquads() {
        val matchId = _uiState.value.selectedMatchId ?: return
        loadSquads(matchId = matchId, forceRefresh = true, preferredSquadId = null)
    }

    fun selectMatch(matchId: Int) {
        _uiState.value = _uiState.value.copy(
            selectedMatchId = matchId,
            selectedStageId = null,
            selectedSquadId = null,
            selectedShooterId = null,
            stages = emptyList(),
            squads = emptyList(),
            errorMessage = null
        )
        persistSelection(matchId = matchId, stageId = null, squadId = null)
        loadStages(matchId = matchId, forceRefresh = false, preferredStageId = null)
        loadSquads(matchId = matchId, forceRefresh = false, preferredSquadId = null)
    }

    fun selectStage(stageId: Int) {
        val current = _uiState.value
        _uiState.value = current.copy(selectedStageId = stageId)
        persistSelection(
            matchId = current.selectedMatchId,
            stageId = stageId,
            squadId = current.selectedSquadId
        )
    }

    fun selectSquad(squadId: Int) {
        val current = _uiState.value
        _uiState.value = current.copy(selectedSquadId = squadId, selectedShooterId = null)
        persistSelection(
            matchId = current.selectedMatchId,
            stageId = current.selectedStageId,
            squadId = squadId
        )
    }

    fun selectShooter(shooterId: Int) {
        _uiState.value = _uiState.value.copy(selectedShooterId = shooterId)
    }

    private fun loadMatches(forceRefresh: Boolean) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            repository.getMatches(forceRefresh = forceRefresh).fold(
                onSuccess = { matches ->
                    _uiState.value = _uiState.value.copy(matches = matches, isLoading = false)
                    restoreCachedSelectionIfNeeded(matches)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Failed to load matches"
                    )
                }
            )
        }
    }

    private fun loadStages(matchId: Int, forceRefresh: Boolean, preferredStageId: Int?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            repository.getStages(matchId = matchId, forceRefresh = forceRefresh).fold(
                onSuccess = { stages ->
                    val state = _uiState.value
                    val selectedStageId = when {
                        preferredStageId != null && stages.any { it.id == preferredStageId } -> preferredStageId
                        state.selectedStageId != null && stages.any { it.id == state.selectedStageId } -> state.selectedStageId
                        else -> stages.firstOrNull()?.id
                    }

                    _uiState.value = state.copy(
                        stages = stages,
                        selectedStageId = selectedStageId,
                        isLoading = false
                    )
                    val updated = _uiState.value
                    persistSelection(updated.selectedMatchId, updated.selectedStageId, updated.selectedSquadId)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Failed to load stages"
                    )
                }
            )
        }
    }

    private fun loadSquads(matchId: Int, forceRefresh: Boolean, preferredSquadId: Int?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            repository.getSquadQueue(matchId = matchId, forceRefresh = forceRefresh).fold(
                onSuccess = { squads ->
                    val state = _uiState.value
                    val selectedSquadId = when {
                        preferredSquadId != null && squads.any { it.id == preferredSquadId } -> preferredSquadId
                        state.selectedSquadId != null && squads.any { it.id == state.selectedSquadId } -> state.selectedSquadId
                        else -> squads.firstOrNull()?.id
                    }

                    _uiState.value = state.copy(
                        squads = squads,
                        selectedSquadId = selectedSquadId,
                        selectedShooterId = null,
                        isLoading = false
                    )
                    val updated = _uiState.value
                    persistSelection(updated.selectedMatchId, updated.selectedStageId, updated.selectedSquadId)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Failed to load squads"
                    )
                }
            )
        }
    }

    private fun restoreCachedSelectionIfNeeded(matches: List<IpscMatch>) {
        if (hasAttemptedRestore) {
            return
        }
        hasAttemptedRestore = true

        viewModelScope.launch {
            val cached = preferences.getCompetitionSessionSelection()
            val cachedMatchId = cached.matchId
            if (cachedMatchId == null || matches.none { it.id == cachedMatchId }) {
                return@launch
            }

            _uiState.value = _uiState.value.copy(
                selectedMatchId = cachedMatchId,
                selectedStageId = null,
                selectedSquadId = null,
                selectedShooterId = null,
                stages = emptyList(),
                squads = emptyList()
            )
            loadStages(matchId = cachedMatchId, forceRefresh = false, preferredStageId = cached.stageId)
            loadSquads(matchId = cachedMatchId, forceRefresh = false, preferredSquadId = cached.squadId)
        }
    }

    private fun persistSelection(matchId: Int?, stageId: Int?, squadId: Int?) {
        viewModelScope.launch {
            preferences.saveCompetitionSessionSelection(
                matchId = matchId,
                stageId = stageId,
                squadId = squadId,
                drillId = null
            )
        }
    }
}
