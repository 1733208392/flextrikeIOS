import Foundation

struct DrillSetupData: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var demoVideoURL: URL?
    var thumbnailURL: URL?
    var delay: TimeInterval // seconds
    var drillDuration: TimeInterval // seconds
    var targets: [DrillTargetsConfigData]
    
    init(id: UUID = UUID(), name: String, description: String, demoVideoURL: URL? = nil, thumbnailURL: URL? = nil, delay: TimeInterval, drillDuration: TimeInterval = 5.0, targets: [DrillTargetsConfigData] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.demoVideoURL = demoVideoURL
        self.thumbnailURL = thumbnailURL
        self.delay = delay
        self.drillDuration = drillDuration
        self.targets = targets
    }
}
