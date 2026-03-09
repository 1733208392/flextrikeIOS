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
     * Validate disguised_enemy target (requires 2+ valid shots on disguised_enemy AND 0 shots on disguised_enemy_surrender)
     */
    fun validateDisguisedEnemy(
        validShotsOnDisguisedEnemy: Int,
        totalShotsOnSurrender: Int
    ): CQBShotResult {
        return if (validShotsOnDisguisedEnemy >= 2 && totalShotsOnSurrender == 0) {
            CQBShotResult(
                targetName = "disguised_enemy",
                isThreat = true,
                expectedShots = 2,
                actualValidShots = validShotsOnDisguisedEnemy,
                cardStatus = CQBShotResult.CardStatus.green
            )
        } else if (totalShotsOnSurrender > 0) {
            val reason = "Shot surrendering variant ($totalShotsOnSurrender shot${if (totalShotsOnSurrender == 1) "" else "s"})"
            CQBShotResult(
                targetName = "disguised_enemy",
                isThreat = true,
                expectedShots = 2,
                actualValidShots = validShotsOnDisguisedEnemy,
                cardStatus = CQBShotResult.CardStatus.red,
                failureReason = reason
            )
        } else {
            val reason = "Missed ${2 - validShotsOnDisguisedEnemy} shot${if (2 - validShotsOnDisguisedEnemy == 1) "" else "s"}"
            CQBShotResult(
                targetName = "disguised_enemy",
                isThreat = true,
                expectedShots = 2,
                actualValidShots = validShotsOnDisguisedEnemy,
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
        
        // Group shots by BOTH device ID and actualTargetType to support:
        // 1. One device reporting multiple target types (e.g., Netlink/Simulator)
        // 2. Multiple devices, each having one target type assigned
        val shotsByTargetIdentifier = mutableMapOf<String, MutableList<ShotData>>()
        
        shots.forEach { shot ->
            // Add to device-based group
            val deviceId = (shot.device ?: shot.target ?: "unknown").lowercase()
            shotsByTargetIdentifier.getOrPut(deviceId) { mutableListOf() }.add(shot)
            
            // Add to targetType-based group
            val targetType = shot.content.actualTargetType.lowercase()
            if (targetType.isNotEmpty() && targetType != deviceId) {
                shotsByTargetIdentifier.getOrPut(targetType) { mutableListOf() }.add(shot)
            }
        }
        
        println("[CQBScoringUtility] Shots grouped by identifier keys: ${shotsByTargetIdentifier.keys}")
        
        for (targetName in targetDevices) {
            val normalizedTargetName = targetName.lowercase()
            val targetShots = shotsByTargetIdentifier[normalizedTargetName] ?: emptyList()
            println("[CQBScoringUtility] Processing target='$normalizedTargetName': isThreat=${isThreatTarget(normalizedTargetName)}, isNonThreat=${isNonThreatTarget(normalizedTargetName)}, shotCount=${targetShots.size}")
            
            when {
                normalizedTargetName == "disguised_enemy" -> {
                    // Special validation for disguised_enemy: must have 2+ valid shots AND no shots on disguised_enemy_surrender
                    val validShotsOnDisguisedEnemy = targetShots.count { isValidCQBHit(it.content.actualHitArea) }
                    val surrenderShots = shotsByTargetIdentifier["disguised_enemy_surrender"] ?: emptyList()
                    val totalShotsOnSurrender = surrenderShots.distinctBy { it.content }.size // ensure unique shots
                    println("[CQBScoringUtility]   -> Disguised enemy: validShots=$validShotsOnDisguisedEnemy, surrenderShots=$totalShotsOnSurrender")
                    shotResults.add(validateDisguisedEnemy(validShotsOnDisguisedEnemy, totalShotsOnSurrender))
                }
                isThreatTarget(normalizedTargetName) -> {
                    val validHits = targetShots.count { isValidCQBHit(it.content.actualHitArea) }
                    println("[CQBScoringUtility]   -> Threat target: validHits=$validHits")
                    shotResults.add(validateThreatTarget(normalizedTargetName, validHits))
                }
                isNonThreatTarget(normalizedTargetName) -> {
                    println("[CQBScoringUtility]   -> Non-threat target: totalShots=${targetShots.size}")
                    shotResults.add(validateNonThreatTarget(normalizedTargetName, targetShots.size))
                }
                else -> {
                    println("[CQBScoringUtility]   -> Unknown target type, skipping")
                }
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
