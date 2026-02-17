import Foundation
import CoreData
import SwiftUI

/// Utility class for drill scoring calculations
class ScoringUtility {
    
    /// Calculate score for a specific hit area
    static func scoreForHitArea(_ hitArea: String) -> Int {
        let trimmed = hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch trimmed {
        case "azone", "a":
            return 5
        case "czone", "c":
            return 3
        case "dzone", "d":
            return 1
        case "miss", "m":
            return -15
        case "whitezone", "blackzone", "n":
            return -10
        case "circlearea", "popperzone": // Steel
            return 5
        default:
            return 0
        }
    }
    
    /// Calculate the number of missed targets (targets with no valid hits)
    static func calculateMissedTargets(shots: [ShotData], drillSetup: DrillSetup?) -> Int {
        guard let targetsSet = drillSetup?.targets as? Set<DrillTargetsConfig> else {
            return 0
        }
        
        let expectedTargets = Set(targetsSet.map { $0.targetName ?? "" }.filter { !$0.isEmpty })
        
        // Group shots by target/device
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in shots {
            let device = shot.device ?? shot.target ?? "unknown"
            if shotsByTarget[device] == nil {
                shotsByTarget[device] = []
            }
            shotsByTarget[device]?.append(shot)
        }
        
        var targetsWithValidHits = Set<String>()
        for (device, targetShots) in shotsByTarget {
            let hasValidHit = targetShots.contains { shot in
                let area = shot.content.hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // Check if it's a scoring zone (A, C, D, circlearea, popperzone)
                return ScoringUtility.scoreForHitArea(area) > 0
            }
            if hasValidHit {
                targetsWithValidHits.insert(device)
            }
        }
        
        let missedTargets = expectedTargets.subtracting(targetsWithValidHits)
        return missedTargets.count
    }
    
    /// Calculate total score with drill rules applied
    static func calculateTotalScore(shots: [ShotData], drillSetup: DrillSetup?) -> Double {
        let counts = ScoringUtility.calculateEffectiveCounts(shots: shots, drillSetup: drillSetup)
        
        let aScore = Double(counts["A"] ?? 0) * 5.0
        let cScore = Double(counts["C"] ?? 0) * 3.0
        let dScore = Double(counts["D"] ?? 0) * 1.0
        let mScore = Double(counts["M"] ?? 0) * -15.0
        let nScore = Double(counts["N"] ?? 0) * -10.0
        let peScore = Double(counts["PE"] ?? 0) * -10.0
        
        let totalScore = aScore + cScore + dScore + mScore + nScore + peScore
        
        // Ensure score never goes below 0
        return max(0, totalScore)
    }
    
    /// Calculate effective hit zone counts based on drill rules
    static func calculateEffectiveCounts(shots: [ShotData], drillSetup: DrillSetup? = nil) -> [String: Int] {
        var aCount = 0
        var cCount = 0
        var dCount = 0
        var nCount = 0
        var mCount = 0
        
        // Group shots by target/device
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in shots {
            let device = shot.device ?? shot.target ?? "unknown"
            if shotsByTarget[device] == nil {
                shotsByTarget[device] = []
            }
            shotsByTarget[device]?.append(shot)
        }
        
        // Get all expected targets from setup
        let expectedTargets = (drillSetup?.targets as? Set<DrillTargetsConfig>) ?? []
        let expectedTargetNames = Set(expectedTargets.compactMap { $0.targetName }.filter { !$0.isEmpty })
        
        // Combine expected targets and targets that actually fired shots
        let allTargetNames = expectedTargetNames.union(shotsByTarget.keys)
        
        for targetName in allTargetNames {
            let targetShots = shotsByTarget[targetName] ?? []
            
            // Find target config to determine type
            let config = expectedTargets.first { $0.targetName == targetName }
            let targetType = config?.targetType?.lowercased() ?? targetShots.first?.content.targetType.lowercased() ?? ""
            let isPaddleOrPopper = targetType == "paddle" || targetType == "popper"
            
            let noShootZoneShots = targetShots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return trimmed == "whitezone" || trimmed == "blackzone"
            }
            
            let otherShots = targetShots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return trimmed != "whitezone" && trimmed != "blackzone"
            }
            
            // Count no-shoot zones (always included)
            nCount += noShootZoneShots.count
            
            // Filter for valid hits
            let validHits = otherShots.filter { ScoringUtility.scoreForHitArea($0.content.hitArea) > 0 }
            
            if isPaddleOrPopper {
                // Paddles/Poppers: 1 valid hit required
                let requiredHits = 1
                let deficit = max(0, requiredHits - validHits.count)
                mCount += deficit
                
                // Count all valid hits for paddles/poppers
                for shot in validHits {
                    let area = shot.content.hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    switch area {
                    case "azone", "a", "circlearea", "popperzone": aCount += 1
                    case "czone", "c": cCount += 1
                    case "dzone", "d": dCount += 1
                    default: break
                    }
                }
            } else {
                // Paper target: 2 valid hits required
                let requiredHits = 2
                let deficit = max(0, requiredHits - validHits.count)
                mCount += deficit
                
                // Count best 2 valid hits
                let sortedValidHits = validHits.sorted {
                    ScoringUtility.scoreForHitArea($0.content.hitArea) > ScoringUtility.scoreForHitArea($1.content.hitArea)
                }
                let scoringHits = Array(sortedValidHits.prefix(requiredHits))
                for shot in scoringHits {
                    let area = shot.content.hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    switch area {
                    case "azone", "a": aCount += 1
                    case "czone", "c": cCount += 1
                    case "dzone", "d": dCount += 1
                    default: break
                    }
                }
            }
        }
        
        let peCount = ScoringUtility.calculateMissedTargets(shots: shots, drillSetup: drillSetup)
        return ["A": aCount, "C": cCount, "D": dCount, "N": nCount, "M": mCount, "PE": peCount]
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
        // A=5, C=3, D=1, N=-10, M=-15, PE=-10
        let totalScore = (aCount * 5) + (cCount * 3) + (dCount * 1) + (mCount * -15) + (nCount * -10) + (peCount * -10)
        
        // Ensure score never goes below 0
        return max(0, totalScore)
    }
    
    // MARK: - IDPA Scoring Methods
    
    /// Map IDPA hit areas to IDPA zones (Head=0, Body=-1, Other=-3, NS5=-5)
    static func mapToIDPAZone(_ hitArea: String) -> String? {
        let trimmed = hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: "-")
        
        // Map based on IDPA NS target definition
        if trimmed == "head-0" || trimmed == "heart-0" {
            return "Head"
        }
        if trimmed == "body-1" {
            return "Body"
        }
        if trimmed == "other-3" {
            return "Other"
        }
        if trimmed == "ns-5" || trimmed.contains("ns-5") || trimmed.contains("idpa-ns") {
            return "NS5"
        }
        return nil  // Miss is handled per-target, not per-shot
    }
    
    /// Get IDPA zone breakdown from shots
    /// Returns dictionary with counts: Head, Body, Other, NS5, Miss
    static func getIDPAZoneBreakdown(shots: [ShotData]) -> [String: Int] {
        var head = 0
        var body = 0
        var other = 0
        var ns5 = 0
        var miss = 0
        
        // Group shots by target
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in shots {
            let target = shot.target ?? "unknown"
            if shotsByTarget[target] == nil {
                shotsByTarget[target] = []
            }
            shotsByTarget[target]?.append(shot)
        }
        
        // For each target, count zone hits
        for (_, targetShots) in shotsByTarget {
            var hasHits = false
            
            for shot in targetShots {
                if let zone = mapToIDPAZone(shot.content.hitArea) {
                    hasHits = true
                    switch zone {
                    case "Head":
                        head += 1
                    case "Body":
                        body += 1
                    case "Other":
                        other += 1
                    case "NS5":
                        ns5 += 1
                    default:
                        break
                    }
                }
            }
            
            // If target received no valid hits, count as miss
            if !hasHits {
                miss += 1
            }
        }
        
        return ["Head": head, "Body": body, "Other": other, "NS5": ns5, "Miss": miss]
    }
    
    /// Calculate IDPA points down
    /// Returns negative value representing total points down (negative because it's a deduction)
    static func calculateIDPAPointsDown(shots: [ShotData]) -> Int {
        let breakdown = getIDPAZoneBreakdown(shots: shots)
        
        let head = breakdown["Head"] ?? 0
        let body = breakdown["Body"] ?? 0
        let other = breakdown["Other"] ?? 0
        let ns5 = breakdown["NS5"] ?? 0
        let miss = breakdown["Miss"] ?? 0
        
        // IDPA scoring: Head=0, Body=-1, Other=-3, NS5=-5, Miss=-5
        let pointsDown = (head * 0) + (body * -1) + (other * -3) + (ns5 * -5) + (miss * -5)
        
        return pointsDown
    }
    
    /// Calculate IDPA final time (score)
    /// Final Time = Raw Time + |Points Down| + Penalties
    static func calculateIDPAFinalTime(rawTime: TimeInterval, pointsDown: Int, penalties: TimeInterval = 0) -> TimeInterval {
        return rawTime + TimeInterval(abs(pointsDown)) + penalties
    }
    
}
