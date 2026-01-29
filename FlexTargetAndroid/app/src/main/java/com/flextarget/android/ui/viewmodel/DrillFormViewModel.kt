package com.flextarget.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.model.DrillTargetsConfigData
import com.flextarget.android.data.repository.DrillSetupRepository
import kotlinx.coroutines.launch
import java.util.UUID

class DrillFormViewModel(
    private val drillSetupRepository: DrillSetupRepository
) : ViewModel() {

    suspend fun saveNewDrill(drillSetup: DrillSetupEntity): DrillSetupEntity {
        val id = drillSetupRepository.insertDrillSetup(drillSetup)
        return drillSetup.copy(id = UUID.randomUUID()) // Room will generate the ID
    }

    suspend fun saveNewDrillWithTargets(
        drillSetup: DrillSetupEntity,
        targets: List<DrillTargetsConfigData>
    ): DrillSetupEntity {
        val targetEntities = targets.map { target ->
            DrillTargetsConfigEntity(
                id = target.id,
                seqNo = target.seqNo,
                targetName = target.targetName,
                targetType = target.targetType,
                timeout = target.timeout,
                countedShots = target.countedShots,
                drillSetupId = drillSetup.id
            )
        }
        drillSetupRepository.insertDrillSetupWithTargets(drillSetup, targetEntities)
        return drillSetup
    }

    suspend fun updateDrill(drillSetup: DrillSetupEntity): DrillSetupEntity {
        drillSetupRepository.updateDrillSetup(drillSetup)
        return drillSetup
    }

    suspend fun updateDrillWithTargets(
        drillSetup: DrillSetupEntity,
        targets: List<DrillTargetsConfigData>
    ): DrillSetupEntity {
        // First update the drill setup
        drillSetupRepository.updateDrillSetup(drillSetup)
        
        // Delete existing targets and insert new ones
        drillSetupRepository.deleteTargetConfigsByDrillSetupId(drillSetup.id)
        
        val targetEntities = targets.map { target ->
            DrillTargetsConfigEntity(
                id = target.id,
                seqNo = target.seqNo,
                targetName = target.targetName,
                targetType = target.targetType,
                timeout = target.timeout,
                countedShots = target.countedShots,
                drillSetupId = drillSetup.id
            )
        }
        drillSetupRepository.insertTargetConfigs(targetEntities)
        
        return drillSetup
    }

    suspend fun getTargetsForDrill(drillId: UUID): List<DrillTargetsConfigData> {
        val drillWithTargets = drillSetupRepository.getDrillSetupWithTargets(drillId)
        return drillWithTargets?.targets?.map { entity ->
            DrillTargetsConfigData(
                id = entity.id,
                seqNo = entity.seqNo,
                targetName = entity.targetName ?: "",
                targetType = entity.targetType ?: "ipsc",
                timeout = entity.timeout,
                countedShots = entity.countedShots
            )
        } ?: emptyList()
    }

    suspend fun getDrillResultCount(drillSetupId: UUID): Int {
        return drillSetupRepository.getDrillResultCountBySetupId(drillSetupId)
    }

    class Factory(private val drillSetupRepository: DrillSetupRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(DrillFormViewModel::class.java)) {
                return DrillFormViewModel(drillSetupRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}