package com.flextarget.android.data.model

import java.util.UUID

/**
 * Data model for drill target configuration.
 * Equivalent to iOS DrillTargetsConfigData.
 */
data class DrillTargetsConfigData(
    val id: UUID = UUID.randomUUID(),
    val seqNo: Int = 0,
    val targetName: String = "",
    val targetType: String = "ipsc",
    val timeout: Double = 30.0,
    val countedShots: Int = 5
) {
    companion object {
        val DEFAULT_TARGET_TYPES = listOf(
            "hostage",
            "ipsc",
            "paddle",
            "popper",
            "rotation",
            "special_1",
            "special_2",
            "testTarget"
        )
    }
}