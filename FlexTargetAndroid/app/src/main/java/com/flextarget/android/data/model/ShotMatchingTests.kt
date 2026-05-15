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
    val shotDevice = (shot.target ?: shot.device)?.trim()?.lowercase()
    val shotTargetType = shot.content.actualTargetType.lowercase()

    return when (target) {
        is DrillTargetState.ExpandedMultiTarget -> {
            // Match by both target type AND device/name so that same-type targets on
            // different devices each only show their own shots.
            // shotDevice == null is a fallback for legacy data with no device field.
            val typeMatches = shotTargetType == target.targetType.value.lowercase()
            val deviceMatches = shotDevice == null || shotDevice == target.deviceId.value.lowercase()
            typeMatches && deviceMatches
        }
        is DrillTargetState.SingleTarget -> {
            // For single targets, match by device name
            shotDevice == target.targetName.lowercase()
        }
    }
}
