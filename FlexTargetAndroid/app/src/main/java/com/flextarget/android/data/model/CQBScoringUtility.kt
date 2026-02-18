package com.flextarget.android.data.model

/**
 * Utility class for CQB drill validation and scoring.
 * Ported from iOS CQBScoringUtility.
 */
object CQBScoringUtility {

    /**
     * Threat targets that must be destroyed with 2 valid shots (head or body)
     */
    private val threatTargets = setOf(
        "cqb_moving",
        "cqb_front",
        "cqb_swing",
        "disguised_enemy"
    )

    /**
     * Non-threat targets that must not be shot at all
     */
    private val nonThreatTargets = setOf(
        "disguised_enemy_surrender",
        "cqb_hostage"
    )

    /**
     * Check if a target is a threat that needs to be destroyed
     */
    fun isThreatTarget(targetName: String): Boolean {
        return threatTargets.contains(targetName.lowercase())
    }

    /**
     * Check if a target is a non-threat that should not be shot
     */
    fun isNonThreatTarget(targetName: String): Boolean {
        return nonThreatTargets.contains(targetName.lowercase())
    }

    /**
     * Check if a shot is valid for CQB (head or body zone)
     */
    fun isValidCQBHit(hitArea: String): Boolean {
        val trimmed = hitArea.trim().lowercase()
        return trimmed == "head" || trimmed == "body"
    }

    /**
     * Validate a single threat target (must have at least 2 valid shots)
     */
    fun validateThreatTarget(targetName: String, validShotCount: Int): CQBShotResult {
        return if (validShotCount >= 2) {
            CQBShotResult(
                targetName = targetName,
                isThreat = true,
                expectedShots = 2,
                actualValidShots = validShotCount,
                cardStatus = CQBShotResult.CardStatus.green
            )
        } else {
            val reason = "Missed ${2 - validShotCount} shot${if (2 - validShotCount == 1) "" else "s"}"
            CQBShotResult(
                targetName = targetName,
                isThreat = true,
                expectedShots = 2,
                actualValidShots = validShotCount,
                cardStatus = CQBShotResult.CardStatus.red,
                failureReason = reason
            )
        }
    }

    /**
     * Validate a single non-threat target (must have 0 shots)
     */
    fun validateNonThreatTarget(targetName: String, totalShotCount: Int): CQBShotResult {
        return if (totalShotCount == 0) {
            CQBShotResult(
                targetName = targetName,
                isThreat = false,
                expectedShots = 0,
                actualValidShots = 0,
                cardStatus = CQBShotResult.CardStatus.green
            )
        } else {
            val reason = "Shot non-threat target ($totalShotCount shot${if (totalShotCount == 1) "" else "s"})"
            CQBShotResult(
                targetName = targetName,
                isThreat = false,
                expectedShots = 0,
                actualValidShots = totalShotCount,
                cardStatus = CQBShotResult.CardStatus.red,
                failureReason = reason
            )
        }
    }

    /**
     * Generate complete CQB drill result by validating all targets
     */
    fun generateCQBDrillResult(
        shots: List<ShotData>,
        drillDuration: Double,
        targetDevices: List<String>
    ): CQBDrillResult {
        val shotResults = mutableListOf<CQBShotResult>()
        
        println("[CQBScoringUtility] generateCQBDrillResult called: targetDevices=$targetDevices (count=${targetDevices.size}), shots=${shots.size}")
        
        // Group shots by device
        val shotsByDevice = shots.groupBy { it.device ?: it.target ?: "unknown" }
        println("[CQBScoringUtility] Shots grouped by device: $shotsByDevice")
        
        for (targetName in targetDevices) {
            val targetShots = shotsByDevice[targetName] ?: emptyList()
            println("[CQBScoringUtility] Processing target='$targetName': isThreat=${isThreatTarget(targetName)}, isNonThreat=${isNonThreatTarget(targetName)}, shotCount=${targetShots.size}")
            
            if (isThreatTarget(targetName)) {
                val validHits = targetShots.count { isValidCQBHit(it.content.actualHitArea) }
                println("[CQBScoringUtility]   -> Threat target: validHits=$validHits")
                shotResults.add(validateThreatTarget(targetName, validHits))
            } else if (isNonThreatTarget(targetName)) {
                println("[CQBScoringUtility]   -> Non-threat target: totalShots=${targetShots.size}")
                shotResults.add(validateNonThreatTarget(targetName, targetShots.size))
            } else {
                println("[CQBScoringUtility]   -> Unknown target type, skipping")
            }
        }
        
        println("[CQBScoringUtility] Total shotResults: ${shotResults.size}")
        shotResults.forEach { result ->
            println("[CQBScoringUtility]   - ${result.targetName}: cardStatus=${result.cardStatus}, validShots=${result.actualValidShots}/${result.expectedShots}")
        }
        
        // Drill passes only if all targets have green card
        val drillPassed = shotResults.all { it.cardStatus == CQBShotResult.CardStatus.green }
        println("[CQBScoringUtility] drillPassed=$drillPassed (all green: ${shotResults.all { it.cardStatus == CQBShotResult.CardStatus.green }})")
        
        return CQBDrillResult(shotResults, drillPassed)
    }
}
