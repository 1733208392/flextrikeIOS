package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import java.util.UUID

/**
 * Extension functions for target transformations.
 * Centralizes all conversion logic in one place to prevent duplication.
 */

/**
 * Convert and expand target entities to display-ready data objects.
 * This is the ONLY place where expansion should happen.
 */
fun List<DrillTargetsConfigData>.toDisplayTargets(): List<DrillTargetState> {
    return this.map { data ->
        if (data.targetType.startsWith("[")) {
            // Not expanded - this shouldn't happen after DrillExecutionManager
            // but handle it gracefully
            DrillTargetState.SingleTarget(
                targetName = data.targetName ?: "unknown",
                targetType = TargetType(data.parseTargetTypes().firstOrNull() ?: "ipsc")
            )
        } else {
            // Already expanded - single type
            DrillTargetState.ExpandedMultiTarget(
                deviceId = DeviceId(data.targetName ?: "unknown"),
                targetType = TargetType(data.targetType),
                seqNo = data.seqNo
            )
        }
    }
}

/**
 * Convert entities to expanded data objects (called at data boundary).
 * This expands multi-targets and returns ready-to-use data objects.
 */
fun List<DrillTargetsConfigEntity>.toExpandedDataObjects(): List<DrillTargetsConfigData> {
    return DrillTargetsConfigData.expandMultiTargetEntities(this)
}

/**
 * Determine if this is a multi-target drill.
 */
fun List<DrillTargetsConfigData>.isMultiTarget(): Boolean {
    if (isEmpty()) return false
    // If any target has an unexpanded type (JSON array), it's multi-target
    return any { it.targetType.startsWith("[") }
}

/**
 * Get all unique device IDs.
 */
fun List<DrillTargetsConfigData>.deviceIds(): List<DeviceId> {
    return mapNotNull { it.targetName }.distinct().map { DeviceId(it) }
}

/**
 * Group targets by device ID.
 */
fun List<DrillTargetState>.groupByDevice(): Map<DeviceId, List<DrillTargetState>> {
    return groupBy { 
        when (it) {
            is DrillTargetState.SingleTarget -> DeviceId(it.targetName)
            is DrillTargetState.ExpandedMultiTarget -> it.deviceId
        }
    }
}
