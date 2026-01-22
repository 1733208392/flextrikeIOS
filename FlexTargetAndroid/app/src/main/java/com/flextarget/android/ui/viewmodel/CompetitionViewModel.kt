package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.AthleteEntity
import com.flextarget.android.data.repository.CompetitionRepository
import com.flextarget.android.data.repository.AthleteRepository
import com.flextarget.android.data.repository.RankingData
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.Date
import java.util.UUID

/**
 * UI state for competitions
 */
data class CompetitionUiState(
    val isLoading: Boolean = false,
    val competitions: List<CompetitionEntity> = emptyList(),
    val athletes: List<AthleteEntity> = emptyList(),
    val selectedCompetition: CompetitionEntity? = null,
    val selectedAthlete: AthleteEntity? = null,
    val rankings: List<RankingData> = emptyList(),
    val error: String? = null
)

/**
 * CompetitionViewModel: Manages competition data and leaderboards
 * 
 * Responsibilities:
 * - Fetch and display competitions
 * - Manage athletes
 * - Handle competition selection
 * - Fetch and display leaderboards
 * - Submit drill results as game plays
 */
class CompetitionViewModel(
    private val competitionRepository: CompetitionRepository,
    private val athleteRepository: AthleteRepository
) : ViewModel() {
    
    private val _selectedCompetition = MutableStateFlow<CompetitionEntity?>(null)
    private val _selectedAthlete = MutableStateFlow<AthleteEntity?>(null)
    private val _isLoading = MutableStateFlow(false)
    private val _error = MutableStateFlow<String?>(null)
    private val _rankings = MutableStateFlow<List<RankingData>>(emptyList())

    /**
     * Current competitions UI state
     */
    val competitionUiState: StateFlow<CompetitionUiState> = combine(
        competitionRepository.getAllCompetitions(),
        athleteRepository.getAllAthletes(),
        _selectedCompetition,
        _selectedAthlete,
        _isLoading,
        _error,
        _rankings
    ) { flows ->
        val competitions = flows[0] as List<CompetitionEntity>
        val athletes = flows[1] as List<AthleteEntity>
        val selectedComp = flows[2] as CompetitionEntity?
        val selectedAth = flows[3] as AthleteEntity?
        val isLoading = flows[4] as Boolean
        val error = flows[5] as String?
        val rankings = flows[6] as List<RankingData>

        CompetitionUiState(
            competitions = competitions,
            athletes = athletes,
            selectedCompetition = selectedComp,
            selectedAthlete = selectedAth,
            isLoading = isLoading,
            error = error,
            rankings = rankings
        )
    }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = CompetitionUiState(isLoading = true)
        )

    // --- Competition Actions ---

    fun selectCompetition(competition: CompetitionEntity?) {
        _selectedCompetition.value = competition
    }

    fun createCompetition(name: String, venue: String?, date: Date, drillSetupId: UUID? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            competitionRepository.createCompetition(name, venue, date, drillSetupId = drillSetupId)
                .onFailure { _error.value = "Failed to create competition: ${it.message}" }
            _isLoading.value = false
        }
    }

    fun deleteCompetition(id: UUID) {
        viewModelScope.launch {
            competitionRepository.deleteCompetition(id)
        }
    }

    // --- Athlete Actions ---

    fun selectAthlete(athlete: AthleteEntity?) {
        _selectedAthlete.value = athlete
    }

    fun addAthlete(name: String, club: String?, avatarData: ByteArray? = null) {
        viewModelScope.launch {
            val athlete = AthleteEntity(
                name = name,
                club = club,
                avatarData = avatarData
            )
            athleteRepository.insertAthlete(athlete)
        }
    }

    fun updateAthlete(athlete: AthleteEntity) {
        viewModelScope.launch {
            athleteRepository.updateAthlete(athlete)
        }
    }

    fun deleteAthlete(athlete: AthleteEntity) {
        viewModelScope.launch {
            athleteRepository.deleteAthlete(athlete)
        }
    }
    
    /**
     * Submit game play result (drill execution result)
     */
    fun submitGamePlay(
        score: Int,
        detail: String,
        isPublic: Boolean = true,
        onSuccess: () -> Unit = {},
        onFailure: (String) -> Unit = {}
    ) {
        val competition = _selectedCompetition.value
            ?: return onFailure("No competition selected")
        
        val athlete = _selectedAthlete.value
            ?: return onFailure("No athlete selected")

        viewModelScope.launch {
            _isLoading.value = true
            competitionRepository.submitGamePlay(
                competitionId = competition.id,
                drillSetupId = competition.drillSetupId ?: UUID.randomUUID(),
                score = score,
                detail = detail,
                playerNickname = athlete.name,
                isPublic = isPublic
            ).onSuccess {
                _isLoading.value = false
                onSuccess()
            }.onFailure {
                _isLoading.value = false
                _error.value = "Failed to submit results: ${it.message}"
                onFailure(it.message ?: "Unknown error")
            }
        }
    }
    
    /**
     * Load rankings for the current competition
     */
    fun loadRankings(competitionId: UUID) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            competitionRepository.getCompetitionRanking(competitionId)
                .onSuccess { rankings ->
                    _rankings.value = rankings
                    _isLoading.value = false
                }
                .onFailure { error ->
                    _error.value = "Failed to load rankings: ${error.message}"
                    _rankings.value = emptyList()
                    _isLoading.value = false
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
