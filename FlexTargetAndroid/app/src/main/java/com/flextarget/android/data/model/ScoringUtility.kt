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

    /**
     * Calculate effective hit zone counts based on drill rules
     */
    fun calculateEffectiveCounts(shots: List<ShotData>, targets: List<DrillTargetsConfigEntity>?): Map<String, Int> {
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
        return mapOf("A" to aCount, "C" to cCount, "D" to dCount, "N" to nCount, "M" to mCount, "PE" to peCount)
    }

    /**
     * Calculate score based on adjusted hit zone metrics
     */
    fun calculateScoreFromAdjustedHitZones(adjustedHitZones: Map<String, Int>?, drillSetup: DrillSetupEntity?): Int {
        val adjustedHitZones = adjustedHitZones ?: return 0

        val aCount = adjustedHitZones["A"] ?: 0
        val cCount = adjustedHitZones["C"] ?: 0
        val dCount = adjustedHitZones["D"] ?: 0
        val nCount = adjustedHitZones["N"] ?: 0  // No-shoot zones
        val peCount = adjustedHitZones["PE"] ?: 0  // Penalty count
        val mCount = adjustedHitZones["M"] ?: 0

        // Calculate base score from adjusted counts
        // A=5, C=3, D=1, N=-10, M=-15, PE=-10
        val totalScore = (aCount * 5) + (cCount * 3) + (dCount * 1) + (mCount * -15) + (nCount * -10) + (peCount * -10)

        // Ensure score never goes below 0
        return maxOf(0, totalScore)
    }

    // MARK: IDPA Scoring Methods

    /**
     * Map IDPA hit areas to IDPA zones (Head=0, Body=-1, Other=-3, NS5=-5)
     */
    private fun mapToIDPAZone(hitArea: String): String? {
        val trimmed = hitArea.trim().lowercase().replace('_', '-')
        
        // Map based on IDPA NS target definition
        return when {
            trimmed == "head-0" || trimmed == "heart-0" -> "Head"
            trimmed == "body-1" -> "Body"
            trimmed == "other-3" -> "Other"
            trimmed == "ns-5" || trimmed.contains("ns-5") || trimmed.contains("idpa-ns") -> "NS5"
            else -> null  // Miss is handled per-target, not per-shot
        }
    }

    /**
     * Get IDPA zone breakdown from shots
     * Returns map with counts: Head, Body, Other, NS5, Miss
     * Miss is only counted for targets that received no hits
     */
    fun getIDPAZoneBreakdown(shots: List<ShotData>): Map<String, Int> {
        var head = 0
        var body = 0
        var other = 0
        var ns5 = 0
        var miss = 0

        // Group shots by target
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val target = shot.target ?: "unknown"
            shotsByTarget.getOrPut(target) { mutableListOf() }.add(shot)
        }

        // For each target, count zone hits
        for ((_, targetShots) in shotsByTarget) {
            var hasHits = false

            for (shot in targetShots) {
                val zone = mapToIDPAZone(shot.content.actualHitArea)
                if (zone != null) {
                    hasHits = true
                    when (zone) {
                        "Head" -> head += 1
                        "Body" -> body += 1
                        "Other" -> other += 1
                        "NS5" -> ns5 += 1
                    }
                }
            }

            // If target received no valid hits, count as miss
            if (!hasHits) {
                miss += 1
            }
        }

        return mapOf("Head" to head, "Body" to body, "Other" to other, "NS5" to ns5, "Miss" to miss)
    }

    /**
     * Calculate IDPA points down
     * Returns negative value representing total points down (negative because it's a deduction)
     */
    fun calculateIDPAPointsDown(shots: List<ShotData>): Int {
        val breakdown = getIDPAZoneBreakdown(shots)

        val head = breakdown["Head"] ?: 0
        val body = breakdown["Body"] ?: 0
        val other = breakdown["Other"] ?: 0
        val ns5 = breakdown["NS5"] ?: 0
        val miss = breakdown["Miss"] ?: 0

        // IDPA scoring: Head=0, Body=-1, Other=-3, NS5=-5, Miss=-5
        return (head * 0) + (body * -1) + (other * -3) + (ns5 * -5) + (miss * -5)
    }

    /**
     * Calculate IDPA final time (score)
     * Final Time = Raw Time + |Points Down| + Penalties
     */
    fun calculateIDPAFinalTime(rawTime: Double, pointsDown: Int, penalties: Double = 0.0): Double {
        return rawTime + kotlin.math.abs(pointsDown).toDouble() + penalties
    }
}