import Foundation
import CoreData

#if DEBUG
enum UITestDataSeeder {
    static func seedSampleData(into context: NSManagedObjectContext) {
        context.perform {
            do {
                // marker name so tests/UX can find this drill
                let markerName = "__UITEST_DRILL__"

                // remove existing marker entries
                let fetchReq = NSFetchRequest<DrillSetup>(entityName: "DrillSetup")
                fetchReq.predicate = NSPredicate(format: "name == %@", markerName)
                let existing = try context.fetch(fetchReq)
                for obj in existing { context.delete(obj) }

                // create DrillSetup
                let drillSetup = DrillSetup(context: context)
                drillSetup.id = UUID()
                drillSetup.name = markerName
                drillSetup.desc = "UI seeded test drill"
                drillSetup.delay = 1.0
                drillSetup.drillDuration = 30.0
                drillSetup.repeats = 1

                // three target configs
                let types = ["hostage", "rotation", "paddle"]
                var seq: Int32 = 1
                var generatedShots: [ShotData] = []
                for t in types {
                    let tc = DrillTargetsConfig(context: context)
                    tc.id = UUID()
                    tc.seqNo = seq
                    // targetName should match the device identifier used in ShotData
                    // so matching logic (which compares shot.device to targetName) succeeds
                    tc.targetName = "device_\(t)"
                    tc.targetType = t
                    tc.timeout = 10.0
                    tc.countedShots = 5
                    tc.drillSetup = drillSetup
                    seq += 1

                    // create 5 shots per target
                    for i in 0..<5 {
                        let jitterX = Double((i % 3) - 1) * 6.0
                        let jitterY = Double((i % 2) - 1) * 8.0
                        let centerX = 360.0 + Double(i * 7) + jitterX
                        let centerY = 640.0 + Double(i * 9) + jitterY
                        let timeDelta = 0.4 + Double(i) * 0.15
                        // For rotation targets include a sample rotation angle (in radians)
                        // and a target position. `Content.rotationAngle` is an Int in
                        // the model; we'll store a small integer radian value (e.g. 1).
                        let rotAngle = t == "rotation" ? 1 : 0
                        // For rotation targets include a `target_pos` with the requested
                        // coordinates (-120, 200). For other targets leave nil.
                        let targetPosValue: Position? = t == "rotation" ? Position(x: 240.0, y: 840.0) : nil

                        let content = Content(command: "shot", hitArea: "C", hitPosition: Position(x: centerX, y: centerY), rotationAngle: rotAngle, targetType: t, timeDiff: timeDelta, device: "device_\(t)", targetPos: targetPosValue)

                        let sd = ShotData(target: "\(t)", content: content, type: "shot", action: "hit", device: "device_\(t)")
                        generatedShots.append(sd)
                    }
                }

                // Create DrillResult and shots
                let result = DrillResult(context: context)
                result.drillId = drillSetup.id
                result.date = Date()
                result.drillSetup = drillSetup
                result.totalTime = generatedShots.map { $0.content.timeDiff }.reduce(0, +)

                for sd in generatedShots {
                    let shotEntity = Shot(context: context)
                    let data = try JSONEncoder().encode(sd)
                    shotEntity.data = String(data: data, encoding: .utf8)
                    shotEntity.timestamp = Date()
                    shotEntity.drillResult = result
                }

                try context.save()
                print("[UITestDataSeeder] seeded sample drill '")
            } catch {
                print("[UITestDataSeeder] failed to seed: \(error)")
            }
        }
    }
}
#endif
