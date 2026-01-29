package com.flextarget.android.data.model

import java.util.UUID

/**
 * Summary metrics for a single drill repeat.
 * Ported from iOS DrillRepeatSummary struct.
 */
data class DrillRepeatSummary(
    val id: UUID = UUID.randomUUID(),
    val repeatIndex: Int,
    val totalTime: Double,
    val numShots: Int,
    val firstShot: Double,
    val fastest: Double,
    var score: Int,
    val shots: List<ShotData>,
    val cqbResults: List<CQBShotResult>? = null,
    val cqbPassed: Boolean? = null,
    var adjustedHitZones: Map<String, Int>? = null,
    val drillResultId: UUID? = null
)