package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillSetupWithTargets
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.repository.DrillSetupRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import java.util.UUID

class DrillListViewModel(
    private val drillSetupRepository: DrillSetupRepository
) : ViewModel() {

    val drillSetups: Flow<List<DrillSetupWithTargets>> = drillSetupRepository.allDrillSetupsWithTargets

    fun copyDrill(drillSetup: DrillSetupEntity) {
        viewModelScope.launch {
            try {
                // Get the original drill with targets
                val originalWithTargets = drillSetupRepository.getDrillSetupWithTargets(drillSetup.id)
                    ?: return@launch

                // Create new drill setup
                val newDrillSetup = drillSetup.copy(
                    id = UUID.randomUUID(),
                    name = "${drillSetup.name ?: "Untitled"} Copy"
                )

                // Create new target configs
                val newTargets = originalWithTargets.targets.map { target ->
                    target.copy(
                        id = UUID.randomUUID(),
                        drillSetupId = newDrillSetup.id
                    )
                }

                // Insert the new drill with targets
                drillSetupRepository.insertDrillSetupWithTargets(newDrillSetup, newTargets)
            } catch (e: Exception) {
                // Handle error - could emit error state
                e.printStackTrace()
            }
        }
    }

    fun deleteDrill(drillSetup: DrillSetupEntity) {
        viewModelScope.launch {
            try {
                drillSetupRepository.deleteDrillSetup(drillSetup)
            } catch (e: Exception) {
                // Handle error - could emit error state
                e.printStackTrace()
            }
        }
    }

    class Factory(private val drillSetupRepository: DrillSetupRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(DrillListViewModel::class.java)) {
                return DrillListViewModel(drillSetupRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}