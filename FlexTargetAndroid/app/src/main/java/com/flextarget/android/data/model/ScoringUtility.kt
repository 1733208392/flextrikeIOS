package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillSetupEntity

/**
 * Utility class for drill scoring calculations
 * Ported from iOS ScoringUtility
 */
object ScoringUtility {

    /**
     * Calculate score for a specific hit area
     */
    fun scoreForHitArea(hitArea: String): Int {
        val trimmed = hitArea.trim().lowercase()
        return when (trimmed) {
            "azone" -> 5
            "czone" -> 3
            "dzone" -> 2
            "miss" -> 0
            "whitezone" -> -10
            "blackzone" -> -10
            "circlearea" -> 5 // Paddle
            "popperzone" -> 5 // Popper
            else -> 0
        }
    }

    /**
     * Calculate the number of missed targets
     */
    fun calculateMissedTargets(shots: List<ShotData>, drillSetup: DrillSetupEntity?): Int {
        val targetsSet = drillSetup?.targets ?: return 0
        val expectedTargets = targetsSet.mapNotNull { it.targetName }.filter { it.isNotEmpty() }.toSet()
        val shotsDevices = shots.mapNotNull { it.device ?: it.target }.toSet()
        val missedTargets = expectedTargets.subtract(shotsDevices)
        return missedTargets.size
    }

    /**
     * Calculate total score with drill rules applied
     */
    fun calculateTotalScore(shots: List<ShotData>, drillSetup: DrillSetupEntity?): Double {
        // Group shots by target/device
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val device = shot.device ?: shot.target ?: "unknown"
            shotsByTarget.getOrPut(device) { mutableListOf() }.add(shot)
        }

        // Keep best 2 shots per target, but always include no-shoot zone hits
        // Exception: for paddle and popper targets, keep all shots (no best 2 limit)
        val bestShotsPerTarget = mutableListOf<ShotData>()
        for ((_, targetShots) in shotsByTarget) {
            // Detect target type from shots
            val targetType = targetShots.firstOrNull()?.content?.actualTargetType?.lowercase() ?: ""
            val isPaddleOrPopper = targetType == "paddle" || targetType == "popper"

            val noShootZoneShots = targetShots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed == "whitezone" || trimmed == "blackzone"
            }

            val otherShots = targetShots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed != "whitezone" && trimmed != "blackzone"
            }

            // For paddle and popper: keep all shots; for others: keep best 2
            val selectedOtherShots = if (isPaddleOrPopper) {
                otherShots
            } else {
                val sortedOtherShots = otherShots.sortedByDescending { scoreForHitArea(it.content.actualHitArea) }
                sortedOtherShots.take(2)
            }

            // Always include no-shoot zone shots
            bestShotsPerTarget.addAll(noShootZoneShots)
            bestShotsPerTarget.addAll(selectedOtherShots)
        }

        var totalScore = bestShotsPerTarget.sumOf { scoreForHitArea(it.content.actualHitArea).toDouble() }

        // Auto re-evaluate score: deduct 10 points for each missed target
        val missedTargetCount = calculateMissedTargets(shots, drillSetup)
        val missedTargetPenalty = missedTargetCount * 10
        totalScore -= missedTargetPenalty.toDouble()

        // Ensure score never goes below 0
        return maxOf(0.0, totalScore)
    }
}