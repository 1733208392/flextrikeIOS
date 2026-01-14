import Foundation

/// Utility class for CQB drill validation and scoring
class CQBScoringUtility {
    
    // MARK: - Target Classification
    
    /// Threat targets that must be destroyed with 2 valid shots (head or body)
    private static let threatTargets = Set([
        "cqb_moving",
        "cqb_front",
        "cqb_swing",
        "disguised_enemy"
    ])
    
    /// Non-threat targets that must not be shot at all
    private static let nonThreatTargets = Set([
        "disguised_enemy_surrender",
        "cqb_hostage"
    ])
    
    /// Check if a target is a threat that needs to be destroyed
    /// - Parameter targetName: Name of the target
    /// - Returns: true if target is a threat, false if non-threat
    static func isThreatTarget(_ targetName: String) -> Bool {
        return threatTargets.contains(targetName.lowercased())
    }
    
    /// Check if a target is a non-threat that should not be shot
    /// - Parameter targetName: Name of the target
    /// - Returns: true if target is a non-threat, false if threat or unknown
    static func isNonThreatTarget(_ targetName: String) -> Bool {
        return nonThreatTargets.contains(targetName.lowercased())
    }
    
    // MARK: - Validation Logic
    
    /// Check if a shot is valid for CQB (head or body zone)
    /// - Parameter hitArea: The hit area from shot data
    /// - Returns: true if shot is in head or body zone
    static func isValidCQBHit(_ hitArea: String) -> Bool {
        let trimmed = hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "head" || trimmed == "body"
    }
    
    /// Validate a single threat target (must have at least 2 valid shots)
    /// - Parameters:
    ///   - targetName: Name of the threat target
    ///   - validShotCount: Number of valid (head/body) shots on this target
    /// - Returns: CQBShotResult with green card if valid (2+), red card with reason if invalid
    static func validateThreatTarget(targetName: String, validShotCount: Int) -> CQBShotResult {
        if validShotCount >= 2 {
            return CQBShotResult(
                targetName: targetName,
                isThreat: true,
                expectedShots: 2,
                actualValidShots: validShotCount,
                cardStatus: .green,
                failureReason: nil
            )
        } else {
            // Less than 2 valid shots (missed shots)
            let reason = "Missed \(2 - validShotCount) shot\(2 - validShotCount == 1 ? "" : "s")"
            return CQBShotResult(
                targetName: targetName,
                isThreat: true,
                expectedShots: 2,
                actualValidShots: validShotCount,
                cardStatus: .red,
                failureReason: reason
            )
        }
    }
    
    /// Validate a single non-threat target (must have 0 shots)
    /// - Parameters:
    ///   - targetName: Name of the non-threat target
    ///   - totalShotCount: Any shots on this target (should be 0)
    /// - Returns: CQBShotResult with green card if 0 shots, red card if any shots
    static func validateNonThreatTarget(targetName: String, totalShotCount: Int) -> CQBShotResult {
        if totalShotCount == 0 {
            return CQBShotResult(
                targetName: targetName,
                isThreat: false,
                expectedShots: 0,
                actualValidShots: 0,
                cardStatus: .green,
                failureReason: nil
            )
        } else {
            let reason = "Shot non-threat target (\(totalShotCount) shot\(totalShotCount == 1 ? "" : "s"))"
            return CQBShotResult(
                targetName: targetName,
                isThreat: false,
                expectedShots: 0,
                actualValidShots: totalShotCount,
                cardStatus: .red,
                failureReason: reason
            )
        }
    }
    
    // MARK: - CQB Drill Result Generation
    
    /// Generate CQB drill result from shots data
    /// - Parameters:
    ///   - shots: Array of shots from the drill
    ///   - drillDuration: Total duration of the drill in seconds
    ///   - targetDevices: Set of all target devices/names that should be validated
    /// - Returns: CQBDrillResult with validation results for all targets
    static func generateCQBDrillResult(
        shots: [ShotData],
        drillDuration: Double,
        targetDevices: [String]
    ) -> CQBDrillResult {
        // Group shots by target device name
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in shots {
            let device = shot.device ?? "unknown"
            if shotsByTarget[device] == nil {
                shotsByTarget[device] = []
            }
            shotsByTarget[device]?.append(shot)
        }
        
        var results: [CQBShotResult] = []
        
        // Validate each target device
        for targetName in targetDevices {
            let targetShots = shotsByTarget[targetName] ?? []
            
            if isThreatTarget(targetName) {
                // Threat target: count valid (head/body) shots
                let validShotCount = targetShots.filter { isValidCQBHit($0.content.hitArea) }.count
                let result = validateThreatTarget(targetName: targetName, validShotCount: validShotCount)
                results.append(result)
            } else if isNonThreatTarget(targetName) {
                // Non-threat target: must have 0 shots
                let result = validateNonThreatTarget(targetName: targetName, totalShotCount: targetShots.count)
                results.append(result)
            }
            // Unknown targets are ignored
        }
        
        // Drill passes if all targets have green cards
        let drillPassed = results.allSatisfy { $0.cardStatus == .green }
        
        return CQBDrillResult(
            shotResults: results,
            drilPassed: drillPassed,
            totalShots: shots.count,
            drillDuration: drillDuration
        )
    }
}
