package com.flextarget.android.data.model

/**
 * The matching logic for shots to targets.
 * Extracted as a pure function for easy testing and reusability.
 * 
 * This is the "single source of truth" for the matching domain.
 * 
 * Rules:
 * - For ExpandedMultiTarget: Match ONLY by type (strict type matching)
 * - For SingleTarget: Match by device name (accepts any type from the device)
 */
fun shotMatchesTarget(shot: ShotData, target: DrillTargetState): Boolean {
    val shotDevice = shot.device?.trim()?.lowercase()
    val shotTargetType = shot.content.actualTargetType.lowercase()

    return when (target) {
        is DrillTargetState.ExpandedMultiTarget -> {
            // For expanded targets, ONLY match by type
            // Never use device fallback (prevents all-shots-on-all-targets bug)
            shotTargetType == target.targetType.value.lowercase()
        }
        is DrillTargetState.SingleTarget -> {
            // For single targets, match by device name
            shotDevice == target.targetName.lowercase()
        }
    }
}
