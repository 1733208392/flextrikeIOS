import Foundation

struct DrillConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var demoVideoURL: URL?
    var thumbnailURL: URL? // New property for thumbnail image
    var numberOfSets: Int
    var startDelay: TimeInterval // seconds before each set starts
    var pauseBetweenSets: TimeInterval // seconds between sets
    var sets: [DrillSetConfig]
    var targetType: String // e.g. "paper", "electronic", etc.
    var gunType: String // e.g. "airsoft", "laser", etc.
    
    init(id: UUID = UUID(), name: String, description: String, demoVideoURL: URL? = nil, thumbnailURL: URL? = nil, numberOfSets: Int, startDelay: TimeInterval, pauseBetweenSets: TimeInterval, sets: [DrillSetConfig], targetType: String, gunType: String) {
        self.id = id
        self.name = name
        self.description = description
        self.demoVideoURL = demoVideoURL
        self.thumbnailURL = thumbnailURL
        self.numberOfSets = numberOfSets
        self.startDelay = startDelay
        self.pauseBetweenSets = pauseBetweenSets
        self.sets = sets
        self.targetType = targetType
        self.gunType = gunType
    }
}

struct DrillSetConfig: Identifiable, Codable {
    let id: UUID
    var duration: TimeInterval // seconds
    var numberOfShots: Int
    var distance: Double // meters
    
    init(id: UUID = UUID(), duration: TimeInterval, numberOfShots: Int, distance: Double) {
        self.id = id
        self.duration = duration
        self.numberOfShots = numberOfShots
        self.distance = distance
    }
}
