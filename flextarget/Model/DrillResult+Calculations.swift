import Foundation
import CoreData

// MARK: - DrillResult Calculations Extension
extension DrillResult {
    
    /// Decode all shots from the drill result
    var decodedShots: [ShotData] {
        guard let shotsSet = shots as? Set<Shot> else { return [] }
        
        return shotsSet.compactMap { shot in
            guard let data = shot.data,
                  let jsonData = data.data(using: .utf8) else { return nil }
            
            do {
                return try JSONDecoder().decode(ShotData.self, from: jsonData)
            } catch {
                print("Failed to decode shot data: \(error)")
                return nil
            }
        }.sorted { shot1, shot2 in
            // Sort by timestamp if available, otherwise by timeDiff
            if let timestamp1 = shot1.content.timeDiff as TimeInterval?,
               let timestamp2 = shot2.content.timeDiff as TimeInterval? {
                return timestamp1 < timestamp2
            }
            return false
        }
    }
    
    /// Calculate the fastest shot time in seconds
    var fastestShot: TimeInterval {
        let shotTimes = decodedShots.map { $0.content.timeDiff }
        return shotTimes.min() ?? 0.0
    }
    
    /// Calculate individual shot scores based on hit area
    var shotScores: [Double] {
        return decodedShots.map { shot in
            calculateScore(for: shot.content.hitArea, targetType: shot.content.targetType)
        }
    }
    
    /// Calculate total score for all shots
    var totalScore: Double {
        return ScoringUtility.calculateTotalScore(shots: decodedShots, drillSetup: drillSetup)
    }
    
    /// Calculate total time for all shots (fallback if not persisted)
    private var calculatedTotalTime: TimeInterval {
        return decodedShots.map { $0.content.timeDiff }.reduce(0, +)
    }
    
    /// Get effective total time (uses persisted value or calculated fallback)
    var effectiveTotalTime: TimeInterval {
        // Use persisted totalTime if available (non-zero)
        if totalTime > 0 {
            return TimeInterval(totalTime)
        }
        // Fallback to shot-based calculation for backward compatibility
        return calculatedTotalTime
    }
    
    /// Calculate hit factor (score per second)
    var hitFactor: Double {
        guard effectiveTotalTime > 0 else { return 0.0 }
        return totalScore / effectiveTotalTime
    }
    
    /// Get unique target types from all shots
    var targetTypes: [String] {
        let types = decodedShots.map { $0.content.targetType }
        return Array(Set(types)).sorted()
    }
    
    /// Calculate accuracy percentage (hits vs total shots)
    var accuracy: Double {
        guard !decodedShots.isEmpty else { return 0.0 }
        
        let hits = decodedShots.filter { shot in
            isValidHit(hitArea: shot.content.hitArea)
        }.count
        
        return Double(hits) / Double(decodedShots.count) * 100.0
    }
    
    /// Get shot statistics summary
    var shotStatistics: ShotStatistics {
        return ShotStatistics(
            totalShots: decodedShots.count,
            totalScore: totalScore,
            totalTime: effectiveTotalTime,
            fastestShot: fastestShot,
            hitFactor: hitFactor,
            accuracy: accuracy,
            targetTypes: targetTypes
        )
    }
    
    /// Convert to DrillSummary for UI display
    func toDrillSummary() -> DrillSummary? {
        guard let date = date,
              let drillSetup = drillSetup else { return nil }
        
        return DrillSummary(
            drillName: drillSetup.name ?? "Unknown Drill",
            targetType: targetTypes,
            drillDate: date,
            hitFactor: hitFactor,
            fastestShoot: fastestShot
        )
    }
}

// MARK: - Helper Structures
struct ShotStatistics {
    let totalShots: Int
    let totalScore: Double
    let totalTime: TimeInterval
    let fastestShot: TimeInterval
    let hitFactor: Double
    let accuracy: Double
    let targetTypes: [String]
}

// MARK: - Private Calculation Methods
private extension DrillResult {
    
    /// Calculate score for a specific hit area and target type
    func calculateScore(for hitArea: String, targetType: String) -> Double {
        return Double(ScoringUtility.scoreForHitArea(hitArea))
    }
    
    /// Calculate the number of missed targets
    func calculateMissedTargets() -> Int {
        return ScoringUtility.calculateMissedTargets(shots: decodedShots, drillSetup: drillSetup)
    }
    
    /// Check if a hit area represents a valid hit (not a miss)
    func isValidHit(hitArea: String) -> Bool {
        let missAreas = ["miss", "m", ""]
        return !missAreas.contains(hitArea.lowercased())
    }
}