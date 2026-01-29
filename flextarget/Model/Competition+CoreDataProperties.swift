import Foundation
import CoreData

extension Competition {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Competition> {
        return NSFetchRequest<Competition>(entityName: "Competition")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var venue: String?
    @NSManaged public var date: Date?
    @NSManaged public var drillSetup: DrillSetup?
    @NSManaged public var results: NSSet?

}

// MARK: Generated accessors for results
extension Competition {

    @objc(addResultsObject:)
    @NSManaged public func addToResults(_ value: DrillResult)

    @objc(removeResultsObject:)
    @NSManaged public func removeFromResults(_ value: DrillResult)

    @objc(addResults:)
    @NSManaged public func addToResults(_ values: NSSet)

    @objc(removeResults:)
    @NSManaged public func removeFromResults(_ values: NSSet)

}

extension Competition: Identifiable {

}
