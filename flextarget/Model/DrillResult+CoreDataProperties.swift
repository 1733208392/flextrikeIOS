//
//  DrillResult+CoreDataProperties.swift
//  FlexTarget
//
//  Created by Kai Yang on 2025/12/21.
//
//

public import Foundation
public import CoreData


public typealias DrillResultCoreDataPropertiesSet = NSSet

extension DrillResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillResult> {
        return NSFetchRequest<DrillResult>(entityName: "DrillResult")
    }

    @NSManaged public var date: Date?
    @NSManaged public var drillId: UUID?
    @NSManaged public var sessionId: UUID?
    @NSManaged public var totalTime: Double
    @NSManaged public var adjustedHitZones: String?
    @NSManaged public var id: UUID?
    @NSManaged public var serverPlayId: String?
    @NSManaged public var serverDeviceId: String?
    @NSManaged public var submittedAt: Date?
    @NSManaged public var drillSetup: DrillSetup?
    @NSManaged public var competition: Competition?
    @NSManaged public var leaderboardEntries: NSSet?
    @NSManaged public var shots: NSSet?

}

// MARK: Generated accessors for leaderboardEntries
extension DrillResult {

    @objc(addLeaderboardEntriesObject:)
    @NSManaged public func addToLeaderboardEntries(_ value: LeaderboardEntry)

    @objc(removeLeaderboardEntriesObject:)
    @NSManaged public func removeFromLeaderboardEntries(_ value: LeaderboardEntry)

    @objc(addLeaderboardEntries:)
    @NSManaged public func addToLeaderboardEntries(_ values: NSSet)

    @objc(removeLeaderboardEntries:)
    @NSManaged public func removeFromLeaderboardEntries(_ values: NSSet)

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
