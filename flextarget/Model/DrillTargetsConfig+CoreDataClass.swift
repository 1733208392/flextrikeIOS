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
            countedShots: Int(countedShots)
        )
    }
}