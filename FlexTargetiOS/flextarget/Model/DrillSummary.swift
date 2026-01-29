import Foundation

/// Summary data for a completed drill
struct DrillSummary: Identifiable, Codable, Equatable {
    let id: UUID
    var drillName: String
    var targetType: [String]
    var drillDate: Date
    var hitFactor: Double
    var fastestShoot: TimeInterval

    init(id: UUID = UUID(), drillName: String, targetType: [String], drillDate: Date = Date(), hitFactor: Double, fastestShoot: TimeInterval) {
        self.id = id
        self.drillName = drillName
        self.targetType = targetType
        self.drillDate = drillDate
        self.hitFactor = hitFactor
        self.fastestShoot = fastestShoot
    }
}

// Mock data: 3 sample summaries
extension DrillSummary {
    static let mock: [DrillSummary] = [
        DrillSummary(drillName: "Bill Drill #3", targetType: ["IPSC", "Popper"], drillDate: Date().addingTimeInterval(-86400 * 2), hitFactor: 12.3, fastestShoot: 1.42),
        DrillSummary(drillName: "Hostage Drill A", targetType: ["Hostage"], drillDate: Date().addingTimeInterval(-86400 * 10), hitFactor: 9.8, fastestShoot: 2.10),
        DrillSummary(drillName: "Paddle Sprint", targetType: ["Paddle", "Special_1"], drillDate: Date().addingTimeInterval(-86400 * 30), hitFactor: 15.0, fastestShoot: 1.05)
    ]
}
