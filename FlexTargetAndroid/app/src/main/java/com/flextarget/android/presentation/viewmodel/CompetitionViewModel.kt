package com.flextarget.android.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.repository.CompetitionRepository
import com.flextarget.android.data.repository.RankingData
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * UI state for competitions
 */
data class CompetitionUiState(
    val isLoading: Boolean = false,
    val competitions: List<CompetitionEntity> = emptyList(),
    val selectedCompetition: CompetitionEntity? = null,
    val rankings: List<RankingData> = emptyList(),
    val error: String? = null
)

/**
 * CompetitionViewModel: Manages competition data and leaderboards
 * 
 * Responsibilities:
 * - Fetch and display competitions
 * - Handle competition selection
 * - Fetch and display leaderboards
 * - Submit drill results as game plays
 */
class CompetitionViewModel(
    private val competitionRepository: CompetitionRepository
) : ViewModel() {
    
    /**
     * Current competitions UI state
     */
    val competitionUiState: StateFlow<CompetitionUiState> = competitionRepository.getAllCompetitions()
        .map { competitions ->
            CompetitionUiState(competitions = competitions)
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = CompetitionUiState(isLoading = true)
        )
    
    /**
     * Select a competition and load its leaderboard
     */
    fun selectCompetition(competitionId: UUID) {
        viewModelScope.launch {
            competitionRepository.getCompetitionById(competitionId)
                ?.let { competition ->
                    // In real implementation, would update selected competition state
                }
            
            // Load rankings for this competition
            val result = competitionRepository.getCompetitionRanking(competitionId)
            result.onSuccess { rankings ->
                // Update UI state with rankings
            }
        }
    }
    
    /**
     * Search competitions by name
     */
    val searchResults: StateFlow<List<CompetitionEntity>> = competitionRepository.searchCompetitions("")
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
    
    /**
     * Get upcoming competitions
     */
    val upcomingCompetitions: StateFlow<List<CompetitionEntity>> = 
        competitionRepository.getUpcomingCompetitions()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )
    
    /**
     * Submit game play result
     */
    fun submitGamePlayResult(
        competitionId: UUID,
        drillSetupId: UUID,
        score: Int,
        detail: String,
        playerNickname: String? = null,
        isPublic: Boolean = false
    ) {
        viewModelScope.launch {
            val result = competitionRepository.submitGamePlay(
                competitionId = competitionId,
                drillSetupId = drillSetupId,
                score = score,
                detail = detail,
                playerNickname = playerNickname,
                isPublic = isPublic
            )
            result.onSuccess {
                // Result submitted successfully
            }.onFailure {
                // Handle error
            }
        }
    }
}
