import Foundation

struct DrillRecord: Identifiable, Codable {
    let id: UUID
    let drillConfigID: UUID
    let performedAt: Date
    var setRecords: [DrillSetRecord]
    
    init(id: UUID = UUID(), drillConfigID: UUID, performedAt: Date = Date(), setRecords: [DrillSetRecord]) {
        self.id = id
        self.drillConfigID = drillConfigID
        self.performedAt = performedAt
        self.setRecords = setRecords
    }
}

struct DrillSetRecord: Identifiable, Codable {
    let id: UUID
    var shotRecords: [DrillShotRecord]
    
    init(id: UUID = UUID(), shotRecords: [DrillShotRecord]) {
        self.id = id
        self.shotRecords = shotRecords
    }
}

struct DrillShotRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let position: ShotPosition
    
    init(id: UUID = UUID(), timestamp: Date, position: ShotPosition) {
        self.id = id
        self.timestamp = timestamp
        self.position = position
    }
}

struct ShotPosition: Codable {
    var x: Double // normalized or pixel coordinate
    var y: Double // normalized or pixel coordinate
    var area: String? // optional, e.g. "bullseye", "outer ring", etc.
}
