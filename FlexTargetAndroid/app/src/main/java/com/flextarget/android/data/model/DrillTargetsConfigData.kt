package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import org.json.JSONArray
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
    val countedShots: Int = 5,
    val action: String = "",
    val duration: Double = 3.0
) {
    fun parseTargetTypes(): List<String> {
        val raw = targetType.trim()
        if (raw.isEmpty()) return emptyList()

        return if (raw.startsWith("[")) {
            try {
                val json = JSONArray(raw)
                (0 until json.length())
                    .mapNotNull { index -> json.optString(index).takeIf { it.isNotBlank() } }
            } catch (e: Exception) {
                emptyList()
            }
        } else {
            listOf(raw)
        }
    }

    fun primaryTargetType(default: String = "ipsc"): String {
        return parseTargetTypes().firstOrNull() ?: default
    }

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
                    "idpa_ns",
                    "idpa_black_1",
                    "idpa_black_2"
                )
                "cqb" -> listOf(
                    "cqb_front",
                    "cqb_move",
                    "cqb_swing",
                    "cqb_hostage",
                    "disguised_enemy"
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

        /**
         * Get allowed actions for a given target type in CQB mode
         */
        fun allowedActions(targetType: String, drillMode: String = "cqb"): List<String> {
            if (drillMode.lowercase() != "cqb") return emptyList()
            return when (targetType.lowercase()) {
                "cqb_front" -> listOf("flash")
                "cqb_swing" -> listOf("swing_right")
                "cqb_move" -> listOf("run_through")
                "cqb_hostage" -> listOf("flash")
                "disguised_enemy" -> listOf("disguised_enemy_flash")
                else -> emptyList()
            }
        }

        /**
         * Get the default action for a given target type
         */
        fun getDefaultActionForTargetType(targetType: String, drillMode: String = "cqb"): String {
            val allowed = allowedActions(targetType, drillMode)
            return allowed.firstOrNull() ?: ""
        }

        fun encodeTargetTypes(types: List<String>): String {
            val arr = JSONArray()
            types.filter { it.isNotBlank() }.forEach { arr.put(it) }
            return arr.toString()
        }

        fun fromEntity(entity: DrillTargetsConfigEntity): DrillTargetsConfigData {
            return DrillTargetsConfigData(
                id = entity.id,
                seqNo = entity.seqNo,
                targetName = entity.targetName ?: "",
                targetType = entity.targetType ?: "ipsc",
                timeout = entity.timeout,
                countedShots = entity.countedShots,
                action = entity.action ?: "",
                duration = entity.duration
            )
        }
    }
}