package com.flextarget.android.data.model

import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import android.util.Log

/**
 * Utility class for drill scoring calculations
 * Ported from iOS ScoringUtility
 * 
 * IMPORTANT: targetName + targetType uniquely identifies a target
 * Grouping key format: "targetname|targettype" (lowercase)
 */
object ScoringUtility {

    // Normalize incoming hit area strings to canonical values
    private fun normalizeHitArea(raw: String?): String {
        val trimmed = raw?.trim()?.lowercase() ?: ""
        if (trimmed.isEmpty()) return "miss"
        return when (trimmed) {
            "circle", "circlearea", "circle_area", "circle-area" -> "circlearea"
            "popper", "popperzone", "popper_zone", "popper-zone" -> "popperzone"
            "azone", "a", "a-zone", "a_zone" -> "azone"
            "czone", "c", "c-zone", "c_zone" -> "czone"
            "dzone", "d", "d-zone", "d_zone" -> "dzone"
            "whitezone", "white_zone", "white-zone" -> "whitezone"
            "blackzone", "black_zone", "black-zone" -> "blackzone"
            "miss", "m" -> "miss"
            else -> trimmed
        }
    }

    /**
     * Build a stable, unique key for grouping shots by (targetName + targetType).
     * Always uses combined key format: "name|type"
     * 
     * Priority:
     * 1. If shot.target (explicit targetName) exists: use "targetName|targetType"
     * 2. Otherwise (fallback when targetName not available): use "device|targetType"
     * 3. Last resort: "unknown|unknown"
     */
    private fun normalizedTargetKey(shot: ShotData): String {
        // Priority 1: Explicit target name from shot.target
        val name = shot.target?.trim()
        if (!name.isNullOrBlank()) {
            val ttype = shot.content.actualTargetType?.trim()?.lowercase() ?: "unknown"
            return "${name.lowercase()}|$ttype"
        }

        // Priority 2: Fall back to device|targetType 
        // (ensures shots to different types on same device are grouped separately)
        val device = shot.content.device ?: shot.device
        val ttype = shot.content.actualTargetType?.trim()?.lowercase() ?: "unknown"
        if (!device.isNullOrBlank()) {
            val key = "${device.trim().lowercase()}|$ttype"
            Log.d("ScoringUtility", "normalizedTargetKey: using fallback device|type: $key")
            return key
        }

        // Last resort
        Log.d("ScoringUtility", "normalizedTargetKey: could not determine key; using 'unknown|unknown'")
        return "unknown|unknown"
    }

    /**
     * Find target config by combined name|type key.
     */
    private fun findConfigByNameAndType(
        configs: List<DrillTargetsConfigData>,
        baseName: String,
        baseType: String
    ): DrillTargetsConfigData? {
        val normalizedType = baseType.trim().lowercase()
        return configs.find { cfg ->
            cfg.targetName?.trim()?.lowercase() == baseName.lowercase() &&
            (cfg.targetType?.trim()?.lowercase() == normalizedType || normalizedType == "unknown")
        } ?: configs.find { cfg ->
            cfg.targetName?.trim()?.lowercase() == baseName.lowercase()
        }
    }


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
     * Calculate the number of missed targets (targets with NO valid hits).
     * Miss is only counted if target received NO valid shots at all.
     */
    fun calculateMissedTargets(shots: List<ShotData>, targets: List<DrillTargetsConfigData>?): Int {
        val targetsSet = targets ?: return 0
        // Build expected targets as combined keys "name|type"
        val expectedTargets = targetsSet.mapNotNull { cfg ->
            val name = cfg.targetName?.trim()
            if (name.isNullOrEmpty()) return@mapNotNull null
            val type = cfg.targetType?.trim()?.lowercase() ?: "unknown"
            "${name.lowercase()}|$type"
        }.toSet()
        
        // Group shots by target/device using combined key
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val key = normalizedTargetKey(shot)
            shotsByTarget.getOrPut(key) { mutableListOf() }.add(shot)
        }

        // Find which targets have at least one valid hit
        var targetsWithValidHits = mutableSetOf<String>()
        for ((key, targetShots) in shotsByTarget) {
            val hasValidHit = targetShots.any { shot ->
                scoreForHitArea(normalizeHitArea(shot.content.actualHitArea)) > 0
            }
            if (hasValidHit) {
                targetsWithValidHits.add(key)
            }
        }

        // Targets without valid hits are missed
        val missedTargets = expectedTargets.subtract(targetsWithValidHits)
        return missedTargets.size
    }

    /**
     * Calculate total score with drill rules applied.
     * Score is based on effective counts from calculateEffectiveCounts.
     */
    fun calculateTotalScore(shots: List<ShotData>, targets: List<DrillTargetsConfigData>?): Double {
        var aCount = 0
        var cCount = 0
        var dCount = 0
        var nCount = 0
        var mCount = 0

        val targetsConfigs = targets ?: emptyList()
        // Build expected target combined keys "name|type"
        val expectedTargetNames = targetsConfigs.mapNotNull { cfg ->
            val name = cfg.targetName?.trim()
            if (name.isNullOrEmpty()) return@mapNotNull null
            val type = cfg.targetType?.trim()?.lowercase() ?: "unknown"
            "${name.lowercase()}|$type"
        }.toSet()

        // Group shots by target using combined key
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val key = normalizedTargetKey(shot)
            shotsByTarget.getOrPut(key) { mutableListOf() }.add(shot)
        }

        // Combine expected targets and targets that actually fired shots
        val allTargetNames = expectedTargetNames.union(shotsByTarget.keys)

        for (targetKey in allTargetNames) {
            val targetShots = shotsByTarget[targetKey] ?: mutableListOf()

            // targetKey is "name|type" format; split for config lookup and rule determination
            val parts = targetKey.split("|", limit = 2)
            val baseName = parts.getOrNull(0) ?: targetKey
            val baseType = parts.getOrNull(1) ?: "unknown"

            // Find config by name AND type
            val config = findConfigByNameAndType(targetsConfigs, baseName, baseType)
            val configType = config?.targetType?.trim()?.lowercase()
            val shotType = targetShots.firstOrNull()?.content?.actualTargetType?.trim()?.lowercase() ?: baseType
            val targetType = if (!configType.isNullOrBlank()) configType else shotType
            val isPaddleOrPopper = targetType.contains("paddle") || targetType.contains("popper")

            // Separate no-shoot zone hits from valid hits
            val noShootZoneShots = targetShots.filter { shot ->
                val trimmed = normalizeHitArea(shot.content.actualHitArea)
                trimmed == "whitezone" || trimmed == "blackzone"
            }

            val otherShots = targetShots.filter { shot ->
                val trimmed = normalizeHitArea(shot.content.actualHitArea)
                trimmed != "whitezone" && trimmed != "blackzone"
            }

            // Count no-shoot zones (always included, negative score)
            nCount += noShootZoneShots.size

            // Filter for valid hits (positive score)
            val validHits = otherShots.filter { scoreForHitArea(normalizeHitArea(it.content.actualHitArea)) > 0 }

            if (isPaddleOrPopper) {
                // Paddles/Poppers: 1 valid hit required, count all valid hits
                val requiredHits = 1
                val deficit = maxOf(0, requiredHits - validHits.size)
                mCount += deficit

                // Count all valid hits for paddles/poppers
                for (shot in validHits) {
                    when (normalizeHitArea(shot.content.actualHitArea)) {
                        "azone", "a", "circlearea", "popperzone" -> aCount += 1
                        "czone", "c" -> cCount += 1
                        "dzone", "d" -> dCount += 1
                    }
                }
            } else {
                // Paper target: 2 valid hits required, count best 2
                val requiredHits = 2
                val deficit = maxOf(0, requiredHits - validHits.size)
                mCount += deficit

                // Count best 2 valid hits
                val sortedValidHits = validHits.sortedByDescending { scoreForHitArea(normalizeHitArea(it.content.actualHitArea)) }
                val scoringHits = sortedValidHits.take(requiredHits)
                for (shot in scoringHits) {
                    when (normalizeHitArea(shot.content.actualHitArea)) {
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
     * Calculate effective hit zone counts based on drill rules.
     * Returns: Map of "A" -> count, "C" -> count, "D" -> count, "N" -> count, "M" -> count, "PE" -> count
     * 
     * Rules per user requirement:
     * - Miss (M) is only counted if target has NO valid shots
     * - For each unique target (name + type): best 2 valid shots are counted
     * - Paddle/Popper targets: 1 valid hit required, all valid hits counted as A
     * - Paper targets: 2 valid hits required, best 2 counted
     */
    fun calculateEffectiveCounts(shots: List<ShotData>, targets: List<DrillTargetsConfigData>?): Map<String, Int> {
        var aCount = 0
        var cCount = 0
        var dCount = 0
        var nCount = 0
        var mCount = 0

        val targetsConfigs = targets ?: emptyList()
        // Build expected target combined keys "name|type"
        val expectedTargetNames = targetsConfigs.mapNotNull { cfg ->
            val name = cfg.targetName?.trim()
            if (name.isNullOrEmpty()) return@mapNotNull null
            val type = cfg.targetType?.trim()?.lowercase() ?: "unknown"
            "${name.lowercase()}|$type"
        }.toSet()

        // Group shots by target using combined key (ensures different types are separate groups)
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val key = normalizedTargetKey(shot)
            shotsByTarget.getOrPut(key) { mutableListOf() }.add(shot)
        }

        // Combine expected targets and targets that actually fired shots
        val allTargetNames = expectedTargetNames.union(shotsByTarget.keys)

        for (targetKey in allTargetNames) {
            val targetShots = shotsByTarget[targetKey] ?: mutableListOf()

            // targetKey is "name|type" format; split for config lookup and rule determination
            val parts = targetKey.split("|", limit = 2)
            val baseName = parts.getOrNull(0) ?: targetKey
            val baseType = parts.getOrNull(1) ?: "unknown"

            // Find config by name AND type
            val config = findConfigByNameAndType(targetsConfigs, baseName, baseType)
            val configType = config?.targetType?.trim()?.lowercase()
            val shotType = targetShots.firstOrNull()?.content?.actualTargetType?.trim()?.lowercase() ?: baseType
            val targetType = if (!configType.isNullOrBlank()) configType else shotType
            val isPaddleOrPopper = targetType.contains("paddle") || targetType.contains("popper")

            // Separate no-shoot zone hits from valid hits
            val noShootZoneShots = targetShots.filter { shot ->
                val trimmed = normalizeHitArea(shot.content.actualHitArea)
                trimmed == "whitezone" || trimmed == "blackzone"
            }

            val otherShots = targetShots.filter { shot ->
                val trimmed = normalizeHitArea(shot.content.actualHitArea)
                trimmed != "whitezone" && trimmed != "blackzone"
            }

            // Count no-shoot zones (always included)
            nCount += noShootZoneShots.size

            // Filter for valid hits
            val validHits = otherShots.filter { scoreForHitArea(normalizeHitArea(it.content.actualHitArea)) > 0 }

            if (isPaddleOrPopper) {
                // Paddles/Poppers: 1 valid hit required
                val requiredHits = 1
                val deficit = maxOf(0, requiredHits - validHits.size)
                mCount += deficit

                // Count all valid hits for paddles/poppers as A zone
                for (shot in validHits) {
                    when (normalizeHitArea(shot.content.actualHitArea)) {
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
                val sortedValidHits = validHits.sortedByDescending { scoreForHitArea(normalizeHitArea(it.content.actualHitArea)) }
                val scoringHits = sortedValidHits.take(requiredHits)
                for (shot in scoringHits) {
                    when (normalizeHitArea(shot.content.actualHitArea)) {
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
     * Calculate score based on effective hit zone counts.
     * This method should be called AFTER calculateEffectiveCounts.
     */
    fun calculateScoreFromAdjustedHitZones(adjustedHitZones: Map<String, Int>?, drillSetup: DrillSetupEntity?): Int {
        val adjustedHitZones = adjustedHitZones ?: return 0

        val aCount = adjustedHitZones["A"] ?: 0
        val cCount = adjustedHitZones["C"] ?: 0
        val dCount = adjustedHitZones["D"] ?: 0
        val nCount = adjustedHitZones["N"] ?: 0  // No-shoot zones
        val peCount = adjustedHitZones["PE"] ?: 0  // Penalty count (missed targets)
        val mCount = adjustedHitZones["M"] ?: 0

        // Calculate base score from adjusted counts
        // A=5, C=3, D=1, N=-10, M=-10, PE=-10
        val totalScore = (aCount * 5) + (cCount * 3) + (dCount * 1) + (mCount * -10) + (nCount * -10) + (peCount * -10)

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

        // Group shots by target using combined key
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in shots) {
            val target = normalizedTargetKey(shot)
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