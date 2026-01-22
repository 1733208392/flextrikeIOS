//
//  Athlete+CoreDataProperties.swift
//  FlexTarget
//
//  Created by Kai Yang on 2026/1/7.
//
//

public import Foundation
public import CoreData


public typealias AthleteCoreDataPropertiesSet = NSSet

extension Athlete {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Athlete> {
        return NSFetchRequest<Athlete>(entityName: "Athlete")
    }

    @NSManaged public var avatarData: Data?
    @NSManaged public var club: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?

}

extension Athlete : Identifiable {

}
