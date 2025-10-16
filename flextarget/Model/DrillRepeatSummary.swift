import Foundation

/// Summary metrics for a single drill repeat.
struct DrillRepeatSummary: Identifiable, Codable {
    let id: UUID
    let repeatIndex: Int
    let totalTime: TimeInterval
    let numShots: Int
    let firstShot: TimeInterval
    let fastest: TimeInterval
    let score: Int
    let shots: [ShotData]

    init(
        id: UUID = UUID(),
        repeatIndex: Int,
        totalTime: TimeInterval,
        numShots: Int,
        firstShot: TimeInterval,
        fastest: TimeInterval,
        score: Int,
        shots: [ShotData]
    ) {
        self.id = id
        self.repeatIndex = repeatIndex
        self.totalTime = totalTime
        self.numShots = numShots
        self.firstShot = firstShot
        self.fastest = fastest
        self.score = score
        self.shots = shots
    }
}
