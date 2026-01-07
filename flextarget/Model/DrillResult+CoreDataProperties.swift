//
//  DrillResult+CoreDataProperties.swift
//  FlexTarget
//
//  Created by Kai Yang on 2026/1/7.
//
//

public import Foundation
public import CoreData


public typealias DrillResultCoreDataPropertiesSet = NSSet

extension DrillResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillResult> {
        return NSFetchRequest<DrillResult>(entityName: "DrillResult")
    }

    @NSManaged public var adjustedHitZones: String?
    @NSManaged public var date: Date?
    @NSManaged public var drillId: UUID?
    @NSManaged public var id: UUID?
    @NSManaged public var serverDeviceId: String?
    @NSManaged public var serverPlayId: String?
    @NSManaged public var sessionId: UUID?
    @NSManaged public var submittedAt: Date?
    @NSManaged public var totalTime: NSNumber?
    @NSManaged public var athlete: Athlete?
    @NSManaged public var competition: Competition?
    @NSManaged public var drillSetup: DrillSetup?
    @NSManaged public var shots: NSSet?

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
