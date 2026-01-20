package com.flextarget.android.data.model

import java.util.UUID

/**
 * Represents the result of CQB target validation.
 * Ported from iOS CQBShotResult.
 */
data class CQBShotResult(
    val id: UUID = UUID.randomUUID(),
    val targetName: String,
    val isThreat: Boolean,
    val expectedShots: Int,
    val actualValidShots: Int,
    val cardStatus: CardStatus,
    val failureReason: String? = null
) {
    enum class CardStatus {
        green,
        red
    }
}

/**
 * Summary of a complete CQB drill execution.
 */
data class CQBDrillResult(
    val shotResults: List<CQBShotResult>,
    val drilPassed: Boolean
)
