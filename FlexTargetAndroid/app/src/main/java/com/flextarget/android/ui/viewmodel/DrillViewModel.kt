package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.repository.DrillExecutionContext
import com.flextarget.android.data.repository.DrillExecutionState
import com.flextarget.android.data.repository.DrillRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * UI state for drills
 */
data class DrillUiState(
    val isLoading: Boolean = false,
    val drills: List<DrillSetupEntity> = emptyList(),
    val selectedDrill: DrillSetupEntity? = null,
    val executionState: DrillExecutionState = DrillExecutionState.IDLE,
    val shotsReceived: Int = 0,
    val totalScore: Int = 0,
    val averageScore: Int = 0,
    val error: String? = null
)

/**
 * DrillViewModel: Manages drill selection and execution
 * 
 * Responsibilities:
 * - Display available drills
 * - Orchestrate drill execution lifecycle
 * - Track shot collection and scoring
 * - Display execution progress and results
 */
class DrillViewModel(
    private val drillRepository: DrillRepository
) : ViewModel() {
    
    /**
     * Current drills UI state
     */
    val drillUiState: StateFlow<DrillUiState> = drillRepository.getAllDrills()
        .map { drills ->
            DrillUiState(drills = drills)
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = DrillUiState(isLoading = true)
        )
    
    /**
     * Current execution context
     */
    val executionContext: StateFlow<DrillExecutionContext?> = drillRepository.executionContext
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = null
        )
    
    /**
     * Select a drill
     */
    fun selectDrill(drillId: UUID) {
        viewModelScope.launch {
            drillRepository.getDrillById(drillId)?.let { drill ->
                // Update selected drill in state
            }
        }
    }
    
    /**
     * Initialize drill execution
     */
    fun initializeDrill(drillId: UUID) {
        viewModelScope.launch {
            val result = drillRepository.initializeDrill(drillId)
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Start executing drill after ACK from device
     */
    fun startExecuting() {
        viewModelScope.launch {
            val result = drillRepository.startExecuting()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Finalize drill execution
     */
    fun finalizeDrill() {
        viewModelScope.launch {
            val result = drillRepository.finalizeDrill()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Complete drill and save results
     */
    fun completeDrill() {
        viewModelScope.launch {
            val result = drillRepository.completeDrill()
            result.onFailure {
                // Handle error
            }
        }
    }
    
    /**
     * Abort current drill execution
     */
    fun abortDrill() {
        viewModelScope.launch {
            drillRepository.abortDrill()
        }
    }
    
    /**
     * Get execution statistics
     */
    fun getExecutionStats(): Map<String, Any> = drillRepository.getExecutionStats()
    
    /**
     * Create new drill
     */
    fun createDrill(
        name: String,
        description: String? = null,
        timeLimit: Int = 60
    ) {
        viewModelScope.launch {
            drillRepository.createDrill(name, description, timeLimit)
                .onFailure {
                    // Handle error
                }
        }
    }
}
