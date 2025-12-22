import Foundation
import CoreData
import SwiftUI

/// Utility class for drill scoring calculations
class ScoringUtility {
    
    /// Calculate score for a specific hit area
    static func scoreForHitArea(_ hitArea: String) -> Int {
        let trimmed = hitArea.trimmingCharacters(in: .whitespaces).lowercased()
        
        switch trimmed {
        case "azone":
            return 5
        case "czone":
            return 3
        case "dzone":
            return 2
        case "miss":
            return -15
        case "whitezone":
            return -25
        case "blackzone":
            return -10
        case "circlearea": // Paddle
            return 5
        case "popperzone": // Popper
            return 5
        default:
            return 0
        }
    }
    
    /// Calculate the number of missed targets
    static func calculateMissedTargets(shots: [ShotData], drillSetup: DrillSetup?) -> Int {
        guard let targetsSet = drillSetup?.targets as? Set<DrillTargetsConfig> else {
            return 0
        }
        
        let expectedTargets = Set(targetsSet.map { $0.targetName ?? "" }.filter { !$0.isEmpty })
        let shotsDevices = Set(shots.compactMap { $0.device ?? $0.target })
        
        let missedTargets = expectedTargets.subtracting(shotsDevices)
        return missedTargets.count
    }
    
    /// Calculate total score with drill rules applied
    static func calculateTotalScore(shots: [ShotData], drillSetup: DrillSetup?) -> Double {
        // Group shots by target/device
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in shots {
            let device = shot.device ?? shot.target ?? "unknown"
            if shotsByTarget[device] == nil {
                shotsByTarget[device] = []
            }
            shotsByTarget[device]?.append(shot)
        }
        
        // Keep best 2 shots per target, but always include no-shoot zone hits
        // Exception: for paddle and popper targets, keep all shots (no best 2 limit)
        var bestShotsPerTarget: [ShotData] = []
        for (_, targetShots) in shotsByTarget {
            // Detect target type from shots
            let targetType = targetShots.first?.content.targetType.lowercased() ?? ""
            let isPaddleOrPopper = targetType == "paddle" || targetType == "popper"
            
            let noShootZoneShots = targetShots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespaces).lowercased()
                return trimmed == "whitezone" || trimmed == "blackzone"
            }
            
            let otherShots = targetShots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespaces).lowercased()
                return trimmed != "whitezone" && trimmed != "blackzone"
            }
            
            // For paddle and popper: keep all shots; for others: keep best 2
            let selectedOtherShots: [ShotData]
            if isPaddleOrPopper {
                selectedOtherShots = otherShots
            } else {
                let sortedOtherShots = otherShots.sorted {
                    Double(ScoringUtility.scoreForHitArea($0.content.hitArea)) > Double(ScoringUtility.scoreForHitArea($1.content.hitArea))
                }
                selectedOtherShots = Array(sortedOtherShots.prefix(2))
            }
            
            // Always include no-shoot zone shots
            bestShotsPerTarget.append(contentsOf: noShootZoneShots)
            bestShotsPerTarget.append(contentsOf: selectedOtherShots)
        }
        
        var totalScore = bestShotsPerTarget.reduce(0.0) { $0 + Double(ScoringUtility.scoreForHitArea($1.content.hitArea)) }
        
        // Auto re-evaluate score: deduct 10 points for each missed target
        let missedTargetCount = ScoringUtility.calculateMissedTargets(shots: shots, drillSetup: drillSetup)
        let missedTargetPenalty = missedTargetCount * 10
        totalScore -= Double(missedTargetPenalty)
        
        // Ensure score never goes below 0
        return max(0, totalScore)
    }
    
    /// Calculate score based on adjusted hit zone metrics
    static func calculateScoreFromAdjustedHitZones(_ adjustedHitZones: [String: Int]?, drillSetup: DrillSetup?) -> Int {
        guard let adjustedHitZones = adjustedHitZones else { return 0 }
        
        let aCount = adjustedHitZones["A"] ?? 0
        let cCount = adjustedHitZones["C"] ?? 0
        let dCount = adjustedHitZones["D"] ?? 0
        let nCount = adjustedHitZones["N"] ?? 0  // No-shoot zones
        let peCount = adjustedHitZones["PE"] ?? 0  // Penalty count
        let mCount = adjustedHitZones["M"] ?? 0
        
        // Calculate base score from adjusted counts
        // A=5, C=3, D=2, N=-10 (black zone) or -25 (white zone), M=-15
        var totalScore = (aCount * 5) + (cCount * 3) + (dCount * 2) + (mCount * -15)
        
        // Apply penalties for no-shoot zones
        // Assume half are black zone (-10) and half are white zone (-25) for average penalty
        let avgNoShootPenalty = nCount > 0 ? (nCount / 2 * (-10) + (nCount + 1) / 2 * (-25)) : 0
        totalScore += avgNoShootPenalty
        
        // Apply penalty deductions (10 points per PE)
        let penaltyDeduction = peCount * 10
        totalScore -= penaltyDeduction
        
        // Ensure score never goes below 0
        return max(0, totalScore)
    }
    
}
