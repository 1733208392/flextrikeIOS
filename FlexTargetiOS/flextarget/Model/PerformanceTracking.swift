import Foundation

/// Represents a single data point in the performance tracking chart.
struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let reactionTime: Double // Time of first shot in seconds
    let fastestSplit: Double // Minimum time between consecutive shots in seconds
    let grouping: Double     // Average distance from center or spread in some unit (normalized)
}

/// Utility to calculate performance metrics from a collection of drill results.
struct PerformanceCalculator {
    
    /// Maps a list of CoreData DrillResult entities to PerformanceDataPoint objects.
    static func calculateTrends(from results: [DrillResult]) -> [PerformanceDataPoint] {
        return results.compactMap { result -> PerformanceDataPoint? in
            guard let date = result.date else { return nil }
            
            let shots = result.decodedShots
            guard !shots.isEmpty else { return nil }
            
            // 1. Reaction Time (First shot's timeDiff or timestamp from start)
            let firstShot = shots.sorted { $0.content.timeDiff < $1.content.timeDiff }.first
            let reactionTime = firstShot?.content.timeDiff ?? 0.0
            
            // 2. Fastest Split (Min time between shots)
            // Assuming timeDiff in ShotData is the time since the PREVIOUS shot 
            // OR we calculate it from absolute timestamps.
            // Based on DrillResult+Calculations.swift, we look at the minimum interval.
            let splits = shots.map { $0.content.timeDiff }.filter { $0 > 0 }
            let fastestSplit = splits.min() ?? 0.0
            
            // 3. Grouping (Average distance between shots - measure of precision/cluster)
            let averageGrouping: Double
            if shots.count <= 1 {
                averageGrouping = 0.0
            } else {
                // Optimized Centroid dispersion (O(n) calculation)
                let positions = shots.map { $0.content.hitPosition }
                let count = Double(positions.count)
                
                let avgX = positions.reduce(0.0) { $0 + $1.x } / count
                let avgY = positions.reduce(0.0) { $0 + $1.y } / count
                
                let totalDistFromCentroid = positions.reduce(0.0) { acc, pos in
                    return acc + sqrt(pow(pos.x - avgX, 2) + pow(pos.y - avgY, 2))
                }
                averageGrouping = totalDistFromCentroid / count
            }
            
            return PerformanceDataPoint(
                date: date,
                reactionTime: reactionTime,
                fastestSplit: fastestSplit,
                grouping: averageGrouping
            )
        }.sorted { $0.date < $1.date }
    }
}
