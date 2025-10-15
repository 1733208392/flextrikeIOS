import Foundation
import CoreData

@objc(DrillSetup)
public class DrillSetup: NSManagedObject {

}

extension DrillSetup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillSetup> {
        return NSFetchRequest<DrillSetup>(entityName: "DrillSetup")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var desc: String?
    @NSManaged public var demoVideoURL: URL?
    @NSManaged public var thumbnailURL: URL?
    @NSManaged public var delay: Double
    @NSManaged public var drillDuration: Double
    @NSManaged public var repeats: Int
    @NSManaged public var pause: Int
    @NSManaged public var targets: NSSet?
    @NSManaged public var results: NSSet?

}

// MARK: Generated accessors for targets
extension DrillSetup {

    @objc(addTargetsObject:)
    @NSManaged public func addToTargets(_ value: DrillTargetsConfig)

    @objc(removeTargetsObject:)
    @NSManaged public func removeFromTargets(_ value: DrillTargetsConfig)

    @objc(addTargets:)
    @NSManaged public func addToTargets(_ values: NSSet)

    @objc(removeTargets:)
    @NSManaged public func removeFromTargets(_ values: NSSet)

}

// MARK: Generated accessors for results
extension DrillSetup {

    @objc(addResultsObject:)
    @NSManaged public func addToResults(_ value: DrillResult)

    @objc(removeResultsObject:)
    @NSManaged public func removeFromResults(_ value: DrillResult)

    @objc(addResults:)
    @NSManaged public func addToResults(_ values: NSSet)

    @objc(removeResults:)
    @NSManaged public func removeFromResults(_ values: NSSet)

}

extension DrillSetup : Identifiable {

}

// MARK: - Convenience Methods
extension DrillSetup {
    
    /// Convenience initializer from DrillSetupData struct
    convenience init(context: NSManagedObjectContext, from setup: DrillSetupData) {
        self.init(context: context)
        self.id = setup.id
        self.name = setup.name
        self.desc = setup.description
        self.demoVideoURL = setup.demoVideoURL
        self.thumbnailURL = setup.thumbnailURL
        self.delay = setup.delay
        self.drillDuration = setup.drillDuration
        
        // Create target configs
        for targetConfig in setup.targets {
            let config = DrillTargetsConfig(context: context)
            config.id = targetConfig.id
            config.seqNo = Int32(targetConfig.seqNo)
            config.targetName = targetConfig.targetName
            config.targetType = targetConfig.targetType
            config.timeout = targetConfig.timeout
            config.countedShots = Int32(targetConfig.countedShots)
            config.drillSetup = self
        }
    }
    
    /// Convert to DrillSetupData struct
    func toStruct() -> DrillSetupData {
        let targetConfigs = (targets?.allObjects as? [DrillTargetsConfig])?.map { config in
            DrillTargetsConfigData(
                id: config.id ?? UUID(),
                seqNo: Int(config.seqNo),
                targetName: config.targetName ?? "",
                targetType: config.targetType ?? "",
                timeout: config.timeout,
                countedShots: Int(config.countedShots)
            )
        } ?? []
        
        return DrillSetupData(
            id: id ?? UUID(),
            name: name ?? "",
            description: desc ?? "",
            demoVideoURL: demoVideoURL,
            thumbnailURL: thumbnailURL,
            delay: delay,
            drillDuration: drillDuration,
            targets: targetConfigs
        )
    }
    
    /// Sorted targets by sequence number
    var sortedTargets: [DrillTargetsConfig] {
        let targetArray = targets?.allObjects as? [DrillTargetsConfig] ?? []
        return targetArray.sorted { $0.seqNo < $1.seqNo }
    }
}