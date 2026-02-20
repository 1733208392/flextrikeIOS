import Foundation
import CoreData

@objc(DrillTargetsConfig)
public class DrillTargetsConfig: NSManagedObject {

}

extension DrillTargetsConfig {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillTargetsConfig> {
        return NSFetchRequest<DrillTargetsConfig>(entityName: "DrillTargetsConfig")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var seqNo: Int32
    @NSManaged public var targetName: String?
    @NSManaged public var targetType: String?
    @NSManaged public var timeout: Double
    @NSManaged public var countedShots: Int32
    @NSManaged public var action: String?
    @NSManaged public var duration: Double
    @NSManaged public var targetVariant: String?
    @NSManaged public var drillSetup: DrillSetup?

}

extension DrillTargetsConfig : Identifiable {

}

// MARK: - Convenience Methods
extension DrillTargetsConfig {
    
    /// Convert to DrillTargetsConfigData struct
    func toStruct() -> DrillTargetsConfigData {
        return DrillTargetsConfigData(
            id: id ?? UUID(),
            seqNo: Int(seqNo),
            targetName: targetName ?? "", //Device Name
            targetType: targetType ?? "",
            timeout: timeout,
            countedShots: Int(countedShots),
            action: action ?? "",
            duration: duration,
            targetVariant: targetVariant
        )
    }

    func parsedTargetTypes() -> [String] {
        let raw = (targetType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }

        if raw.hasPrefix("[") {
            guard let data = raw.data(using: .utf8) else { return [] }
            do {
                let values = try JSONDecoder().decode([String].self, from: data)
                return values.filter { !$0.isEmpty }
            } catch {
                print("Failed to parse CoreData targetType JSON: \(error)")
                return []
            }
        }

        return [raw]
    }

    /// Alias for parsedTargetTypes() to match Android naming convention
    func parseTargetTypes() -> [String] {
        return parsedTargetTypes()
    }

    func primaryTargetType(default fallback: String = "ipsc") -> String {
        parseTargetTypes().first ?? fallback
    }
}