package com.flextarget.android.data.local.entity

import com.flextarget.android.data.model.ScoringUtility
import com.flextarget.android.data.model.ShotData
import com.google.gson.Gson
import kotlin.math.max

// MARK: - DrillResultWithShots Calculations Extension
val DrillResultWithShots.decodedShots: List<ShotData>
    get() {
        return shots.mapNotNull { shot ->
            shot.data?.let { data ->
                try {
                    Gson().fromJson(data, ShotData::class.java)
                } catch (e: Exception) {
                    null
                }
            }
        }.sortedBy { it.content.actualTimeDiff }
    }

val DrillResultWithShots.fastestShot: Double
    get() {
        return decodedShots.map { it.content.actualTimeDiff }.minOrNull() ?: 0.0
    }

val DrillResultWithShots.shotScores: List<Double>
    get() {
        return decodedShots.map { shot ->
            ScoringUtility.scoreForHitArea(shot.content.actualHitArea).toDouble()
        }
    }

val DrillResultWithShots.totalScore: Double
    get() {
        return ScoringUtility.calculateTotalScore(decodedShots, drillResult.drillSetupId?.let {
            // Note: We need drillSetup, but it's not directly available here
            // This might need adjustment based on how the data is accessed
            null // TODO: Pass drillSetup if available
        })
    }

private val DrillResultWithShots.calculatedTotalTime: Double
    get() {
        return decodedShots.sumOf { it.content.actualTimeDiff }
    }

val DrillResultWithShots.effectiveTotalTime: Double
    get() {
        return if (drillResult.totalTime > 0) drillResult.totalTime else calculatedTotalTime
    }

val DrillResultWithShots.hitFactor: Double
    get() {
        return if (effectiveTotalTime > 0) totalScore / effectiveTotalTime else 0.0
    }

val DrillResultWithShots.targetTypes: List<String>
    get() {
        return decodedShots.map { it.content.actualTargetType }.distinct().sorted()
    }

val DrillResultWithShots.accuracy: Double
    get() {
        if (decodedShots.isEmpty()) return 0.0
        val hits = decodedShots.count { isValidHit(it.content.actualHitArea) }
        return hits.toDouble() / decodedShots.size.toDouble() * 100.0
    }

data class ShotStatistics(
    val totalShots: Int,
    val totalScore: Double,
    val totalTime: Double,
    val fastestShot: Double,
    val hitFactor: Double,
    val accuracy: Double,
    val targetTypes: List<String>
)

val DrillResultWithShots.shotStatistics: ShotStatistics
    get() {
        return ShotStatistics(
            totalShots = decodedShots.size,
            totalScore = totalScore,
            totalTime = effectiveTotalTime,
            fastestShot = fastestShot,
            hitFactor = hitFactor,
            accuracy = accuracy,
            targetTypes = targetTypes
        )
    }

private fun isValidHit(hitArea: String): Boolean {
    val missAreas = listOf("miss", "m", "")
    return !missAreas.contains(hitArea.lowercase())
}