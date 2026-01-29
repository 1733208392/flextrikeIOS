package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
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

        fun getTargetTypesForDrillMode(drillMode: String): List<String> {
            return when (drillMode.lowercase()) {
                "ipsc" -> listOf(
                    "ipsc",
                    "hostage",
                    "paddle",
                    "popper",
                    "rotation",
                    "special_1",
                    "special_2",
                    "testTarget"
                )
                "idpa" -> listOf(
                    "idpa",
                    "hostage",
                    "paddle",
                    "popper",
                    "rotation",
                    "special_1",
                    "special_2",
                    "testTarget"
                )
                "cqb" -> listOf(
                    "cqb_front",
                    "cqb_hostage",
                    "disguised_enemy",
                    "cqb_swing"
                )
                else -> DEFAULT_TARGET_TYPES
            }
        }

        fun getDefaultTargetTypeForDrillMode(drillMode: String): String {
            return when (drillMode.lowercase()) {
                "ipsc" -> "ipsc"
                "idpa" -> "idpa"
                "cqb" -> "cqb_front"
                else -> "ipsc"
            }
        }

        fun fromEntity(entity: DrillTargetsConfigEntity): DrillTargetsConfigData {
            return DrillTargetsConfigData(
                id = entity.id,
                seqNo = entity.seqNo,
                targetName = entity.targetName ?: "",
                targetType = entity.targetType ?: "ipsc",
                timeout = entity.timeout,
                countedShots = entity.countedShots
            )
        }
    }
}