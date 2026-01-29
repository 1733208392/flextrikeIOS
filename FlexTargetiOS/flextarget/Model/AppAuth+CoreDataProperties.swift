//
//  AppAuth+CoreDataProperties.swift
//  FlexTarget
//
//  Created by Kai Yang on 2026/1/7.
//
//

public import Foundation
public import CoreData


public typealias AppAuthCoreDataPropertiesSet = NSSet

extension AppAuth {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppAuth> {
        return NSFetchRequest<AppAuth>(entityName: "AppAuth")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var token: String?

}

extension AppAuth : Identifiable {

}
