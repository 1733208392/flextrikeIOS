import Foundation

/// Represents the result of CQB target validation
struct CQBShotResult: Identifiable, Codable {
    let id: UUID
    let targetName: String
    let isThreat: Bool
    let expectedShots: Int
    let actualValidShots: Int
    let cardStatus: CardStatus
    let failureReason: String?
    
    enum CardStatus: String, Codable {
        case green
        case red
    }
    
    /// Initialize CQBShotResult for a target
    /// - Parameters:
    ///   - targetName: Name of the target
    ///   - isThreat: Whether the target is a threat (must be destroyed) or non-threat (must not be shot)
    ///   - expectedShots: Number of shots expected (2 for threats, 0 for non-threats)
    ///   - actualValidShots: Number of valid head/body shots on this target
    ///   - cardStatus: Green (passed) or red (failed)
    ///   - failureReason: Description of why the target failed validation (nil if green card)
    init(targetName: String, isThreat: Bool, expectedShots: Int, actualValidShots: Int, cardStatus: CardStatus, failureReason: String? = nil) {
        self.id = UUID()
        self.targetName = targetName
        self.isThreat = isThreat
        self.expectedShots = expectedShots
        self.actualValidShots = actualValidShots
        self.cardStatus = cardStatus
        self.failureReason = failureReason
    }
}

/// Represents the overall CQB drill result
struct CQBDrillResult {
    let shotResults: [CQBShotResult]
    let drilPassed: Bool
    let totalShots: Int
    let drillDuration: Double // in seconds
    
    /// All targets in the drill (threat and non-threat)
    var allTargets: [CQBShotResult] {
        return shotResults
    }
    
    /// Only threat targets
    var threatTargets: [CQBShotResult] {
        return shotResults.filter { $0.isThreat }
    }
    
    /// Only non-threat targets
    var nonThreatTargets: [CQBShotResult] {
        return shotResults.filter { !$0.isThreat }
    }
    
    /// All green cards (passed targets)
    var greenCards: [CQBShotResult] {
        return shotResults.filter { $0.cardStatus == .green }
    }
    
    /// All red cards (failed targets)
    var redCards: [CQBShotResult] {
        return shotResults.filter { $0.cardStatus == .red }
    }
}
