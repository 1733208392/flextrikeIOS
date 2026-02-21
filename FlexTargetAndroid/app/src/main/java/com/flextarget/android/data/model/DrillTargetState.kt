package com.flextarget.android.data.model

/**
 * Sealed class representing the state of a drill target.
 * Makes the single vs multi-target distinction explicit at the type level.
 * 
 * This prevents bugs where code incorrectly assumes all targets from same device = single target.
 */
sealed class DrillTargetState {
    /**
     * Single target - matches by device name
     */
    data class SingleTarget(
        val targetName: String,
        val targetType: TargetType
    ) : DrillTargetState()

    /**
     * Expanded multi-target - matches ONLY by target type
     * Each type is a separate target object
     */
    data class ExpandedMultiTarget(
        val deviceId: DeviceId,
        val targetType: TargetType,
        val seqNo: Int
    ) : DrillTargetState() {
        val targetName = deviceId.value
    }
}
