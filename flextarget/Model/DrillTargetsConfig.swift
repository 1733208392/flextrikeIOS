import Foundation

struct DrillTargetsConfig: Identifiable, Codable {
    let id: UUID
    var seqNo: Int
    var targetName: String
    var targetType: String
    var timeout: TimeInterval // seconds
    var countedShots: Int
    
    init(id: UUID = UUID(), seqNo: Int, targetName: String, targetType: String, timeout: TimeInterval, countedShots: Int) {
        self.id = id
        self.seqNo = seqNo
        self.targetName = targetName
        self.targetType = targetType
        self.timeout = timeout
        self.countedShots = countedShots
    }
}