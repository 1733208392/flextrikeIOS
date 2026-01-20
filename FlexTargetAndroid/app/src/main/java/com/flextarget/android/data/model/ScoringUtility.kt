package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity

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
            "azone", "a" -> 5
            "czone", "c" -> 3
            "dzone", "d" -> 1
            "miss", "m" -> -15
            "whitezone", "blackzone", "n" -> -10
            "circlearea" -> 5 // Paddle
            "popperzone" -> 5 // Popper
            else -> 0
        }
    }

    /**
     * Calculate the number of missed targets (targets with NO valid hits)
     */
    fun calculateMissedTargets(shots: List<ShotData>, targets: List<DrillTargetsConfigEntity>?): Int {
        val targetsSet = targets ?: return 0
        val expectedTargets = targetsSet.mapNotNull { it.targetName }.filter { it.isNotEmpty() }.toSet()
        
        // Group shots by target/device
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val device = shot.device ?: shot.target ?: "unknown"
            shotsByTarget.getOrPut(device) { mutableListOf() }.add(shot)
        }

        var targetsWithValidHits = mutableSetOf<String>()
        for ((device, targetShots) in shotsByTarget) {
            val hasValidHit = targetShots.any { shot ->
                scoreForHitArea(shot.content.actualHitArea) > 0
            }
            if (hasValidHit) {
                targetsWithValidHits.add(device)
            }
        }

        val missedTargets = expectedTargets.subtract(targetsWithValidHits)
        return missedTargets.size
    }

    /**
     * Calculate total score with drill rules applied
     */
    fun calculateTotalScore(shots: List<ShotData>, targets: List<DrillTargetsConfigEntity>?): Double {
        var aCount = 0
        var cCount = 0
        var dCount = 0
        var nCount = 0
        var mCount = 0

        val targetsConfigs = targets ?: emptyList()
        val expectedTargetNames = targetsConfigs.mapNotNull { it.targetName }.filter { it.isNotEmpty() }.toSet()

        // Group shots by target/device
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val device = shot.device ?: shot.target ?: "unknown"
            shotsByTarget.getOrPut(device) { mutableListOf() }.add(shot)
        }

        // Combine expected targets and targets that actually fired shots
        val allTargetNames = expectedTargetNames.union(shotsByTarget.keys)

        for (targetName in allTargetNames) {
            val targetShots = shotsByTarget[targetName] ?: mutableListOf()

            // Find target config to determine type
            val config = targetsConfigs.find { it.targetName == targetName }
            val targetType = config?.targetType?.lowercase() ?: targetShots.firstOrNull()?.content?.actualTargetType?.lowercase() ?: ""
            val isPaddleOrPopper = targetType == "paddle" || targetType == "popper"

            val noShootZoneShots = targetShots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed == "whitezone" || trimmed == "blackzone"
            }

            val otherShots = targetShots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed != "whitezone" && trimmed != "blackzone"
            }

            // Count no-shoot zones (always included)
            nCount += noShootZoneShots.size

            // Filter for valid hits
            val validHits = otherShots.filter { scoreForHitArea(it.content.actualHitArea) > 0 }

            if (isPaddleOrPopper) {
                // Paddles/Poppers: 1 valid hit required
                val requiredHits = 1
                val deficit = maxOf(0, requiredHits - validHits.size)
                mCount += deficit

                // Count all valid hits for paddles/poppers
                for (shot in validHits) {
                    when (shot.content.actualHitArea.trim().lowercase()) {
                        "azone", "a", "circlearea", "popperzone" -> aCount += 1
                        "czone", "c" -> cCount += 1
                        "dzone", "d" -> dCount += 1
                    }
                }
            } else {
                // Paper target: 2 valid hits required
                val requiredHits = 2
                val deficit = maxOf(0, requiredHits - validHits.size)
                mCount += deficit

                // Count best 2 valid hits
                val sortedValidHits = validHits.sortedByDescending { scoreForHitArea(it.content.actualHitArea) }
                val scoringHits = sortedValidHits.take(requiredHits)
                for (shot in scoringHits) {
                    when (shot.content.actualHitArea.trim().lowercase()) {
                        "azone", "a" -> aCount += 1
                        "czone", "c" -> cCount += 1
                        "dzone", "d" -> dCount += 1
                    }
                }
            }
        }

        val peCount = calculateMissedTargets(shots, targets)

        // Calculate base score from adjusted counts
        // A=5, C=3, D=1, N=-10, M=-15, PE=-10
        val totalScore = (aCount * 5.0) + (cCount * 3.0) + (dCount * 1.0) + (mCount * -15.0) + (nCount * -10.0) + (peCount * -10.0)

        // Ensure score never goes below 0
        return maxOf(0.0, totalScore)
    }
}