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
        return shotScores.reduce(0, +)
    }
    
    /// Calculate total time for all shots
    var totalTime: TimeInterval {
        return decodedShots.map { $0.content.timeDiff }.reduce(0, +)
    }
    
    /// Calculate hit factor (score per second)
    var hitFactor: Double {
        guard totalTime > 0 else { return 0.0 }
        return totalScore / totalTime
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
            totalTime: totalTime,
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
        switch targetType.lowercased() {
        case "ipsc":
            return calculateIPSCScore(for: hitArea)
        case "hostage":
            return calculateHostageScore(for: hitArea)
        case "paddle", "popper":
            return calculatePaddleScore(for: hitArea)
        case "special_1", "special_2":
            return calculateSpecialScore(for: hitArea)
        default:
            return calculateDefaultScore(for: hitArea)
        }
    }
    
    /// IPSC target scoring system
    func calculateIPSCScore(for hitArea: String) -> Double {
        switch hitArea.lowercased() {
        case "a":
            return 5.0
        case "c":
            return 4.0
        case "d":
            return 2.0
        case "miss", "m":
            return 0.0
        default:
            return 1.0 // Default for unknown areas
        }
    }
    
    /// Hostage target scoring (penalty for hostage hits)
    func calculateHostageScore(for hitArea: String) -> Double {
        switch hitArea.lowercased() {
        case "target":
            return 5.0
        case "hostage":
            return -10.0 // Penalty for hitting hostage
        case "miss", "m":
            return 0.0
        default:
            return 1.0
        }
    }
    
    /// Paddle/Popper scoring (binary hit/miss)
    func calculatePaddleScore(for hitArea: String) -> Double {
        switch hitArea.lowercased() {
        case "hit", "center", "edge":
            return 5.0
        case "miss", "m":
            return 0.0
        default:
            return 2.5 // Partial credit for edge hits
        }
    }
    
    /// Special target scoring
    func calculateSpecialScore(for hitArea: String) -> Double {
        switch hitArea.lowercased() {
        case "bullseye", "center":
            return 10.0
        case "ring1":
            return 8.0
        case "ring2":
            return 6.0
        case "ring3":
            return 4.0
        case "outer", "edge":
            return 2.0
        case "miss", "m":
            return 0.0
        default:
            return 1.0
        }
    }
    
    /// Default scoring system
    func calculateDefaultScore(for hitArea: String) -> Double {
        switch hitArea.lowercased() {
        case "center", "bullseye":
            return 5.0
        case "inner":
            return 4.0
        case "outer", "edge":
            return 2.0
        case "miss", "m":
            return 0.0
        default:
            return 1.0
        }
    }
    
    /// Check if a hit area represents a valid hit (not a miss)
    func isValidHit(hitArea: String) -> Bool {
        let missAreas = ["miss", "m", ""]
        return !missAreas.contains(hitArea.lowercased())
    }
}