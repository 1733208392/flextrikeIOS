import Foundation
import CoreData

struct CSVExporter {
    
    /// Generates a CSV string for a complete drill session.
    static func generateDrillSessionCSV(drillSetup: DrillSetup, summaries: [DrillRepeatSummary]) -> String {
        var csv = "Prompt: Please analyze the following shooting drill data and provide suggestions to improve my split times, accuracy, and overall score based on the target type and hit zones.\n\n"
        
        // Metadata Section
        csv += "--- SESSION METADATA ---\n"
        csv += "Drill Name,Mode,Total Repeats,Total Shots\n"
        let drillName = drillSetup.name ?? "Unknown Drill"
        let mode = drillSetup.mode ?? "Standard"
        let totalShots = summaries.reduce(0) { $0 + $1.numShots }
        csv += "\(drillName),\(mode),\(summaries.count),\(totalShots)\n\n"
        
        // Data Section Header
        csv += "--- SHOT DATA ---\n"
        csv += "Repeat,Shot Index,Hit Area,Split Time (s),Cumulative Time (s),Target Type,Device\n"
        
        for summary in summaries {
            var cumulativeTime: Double = 0
            for (index, shot) in summary.shots.enumerated() {
                cumulativeTime += shot.content.timeDiff
                let repeatNum = summary.repeatIndex + 1
                let shotNum = index + 1
                let hitArea = shot.content.hitArea
                let split = String(format: "%.3f", shot.content.timeDiff)
                let total = String(format: "%.3f", cumulativeTime)
                let tt = shot.content.targetType
                let device = shot.content.device ?? "N/A"
                
                csv += "\(repeatNum),\(shotNum),\(hitArea),\(split),\(total),\(tt),\(device)\n"
            }
        }
        
        return csv
    }
    
    /// Generates a CSV string for a single repeat.
    static func generateSingleRepeatCSV(drillName: String, summary: DrillRepeatSummary) -> String {
        var csv = "Prompt: Please analyze the following shooting drill data for this specific repeat. Suggest improvements for my splits and accuracy.\n\n"
        
        csv += "--- REPEAT METADATA ---\n"
        csv += "Drill Name,Repeat Index,Total Time,Num Shots,Score\n"
        let totalTime = String(format: "%.3f", summary.totalTime)
        csv += "\(drillName),\(summary.repeatIndex + 1),\(totalTime),\(summary.numShots),\(summary.score)\n\n"
        
        csv += "--- SHOT DATA ---\n"
        csv += "Shot Index,Hit Area,Split Time (s),Cumulative Time (s),Target Type,Device\n"
        
        var cumulativeTime: Double = 0
        for (index, shot) in summary.shots.enumerated() {
            cumulativeTime += shot.content.timeDiff
            let shotNum = index + 1
            let hitArea = shot.content.hitArea
            let split = String(format: "%.3f", shot.content.timeDiff)
            let total = String(format: "%.3f", cumulativeTime)
            let tt = shot.content.targetType
            let device = shot.content.device ?? "N/A"
            
            csv += "\(shotNum),\(hitArea),\(split),\(total),\(tt),\(device)\n"
        }
        
        return csv
    }
}
