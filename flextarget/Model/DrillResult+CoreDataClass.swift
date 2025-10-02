import Foundation
import CoreData

@objc(DrillResult)
public class DrillResult: NSManagedObject {

}

extension DrillResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillResult> {
        return NSFetchRequest<DrillResult>(entityName: "DrillResult")
    }

    @NSManaged public var date: Date?
    @NSManaged public var drillId: UUID?
    @NSManaged public var shots: NSSet?
    @NSManaged public var drillSetup: DrillSetup?

}

// MARK: Generated accessors for shots
extension DrillResult {

    @objc(addShotsObject:)
    @NSManaged public func addToShots(_ value: Shot)

    @objc(removeShotsObject:)
    @NSManaged public func removeFromShots(_ value: Shot)

    @objc(addShots:)
    @NSManaged public func addToShots(_ values: NSSet)

    @objc(removeShots:)
    @NSManaged public func removeFromShots(_ values: NSSet)

}

extension DrillResult : Identifiable {

}