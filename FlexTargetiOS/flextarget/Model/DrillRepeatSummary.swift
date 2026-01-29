import Foundation
import CoreData

/// Summary metrics for a single drill repeat.
struct DrillRepeatSummary: Identifiable, Codable {
    let id: UUID
    let repeatIndex: Int
    let totalTime: TimeInterval
    let numShots: Int
    let firstShot: TimeInterval
    let fastest: TimeInterval
    var score: Int
    let shots: [ShotData]
    var drillResultId: UUID?
    var adjustedHitZones: [String: Int]?
    var cqbResults: [CQBShotResult]?
    var cqbPassed: Bool?

    init(
        id: UUID = UUID(),
        repeatIndex: Int,
        totalTime: TimeInterval,
        numShots: Int,
        firstShot: TimeInterval,
        fastest: TimeInterval,
        score: Int,
        shots: [ShotData],
        drillResultId: UUID? = nil,
        adjustedHitZones: [String: Int]? = nil,
        cqbResults: [CQBShotResult]? = nil,
        cqbPassed: Bool? = nil
    ) {
        self.id = id
        self.repeatIndex = repeatIndex
        self.totalTime = totalTime
        self.numShots = numShots
        self.firstShot = firstShot
        self.fastest = fastest
        self.score = score
        self.shots = shots
        self.drillResultId = drillResultId
        self.adjustedHitZones = adjustedHitZones
        self.cqbResults = cqbResults
        self.cqbPassed = cqbPassed
    }
    
    /// Returns the effective score, using adjusted hit zones if available
    var effectiveScore: Int {
        if let adjustedHitZones = adjustedHitZones {
            // We need drill setup to calculate properly, but for now use a simplified calculation
            // This is a placeholder - in a real implementation, we'd pass drillSetup
            return ScoringUtility.calculateScoreFromAdjustedHitZones(adjustedHitZones, drillSetup: nil)
        }
        return score
    }
}
