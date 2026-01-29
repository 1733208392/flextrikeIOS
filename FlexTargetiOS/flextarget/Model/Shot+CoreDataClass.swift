import Foundation
import CoreData

@objc(Shot)
public class Shot: NSManagedObject {

}

extension Shot {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Shot> {
        return NSFetchRequest<Shot>(entityName: "Shot")
    }

    @NSManaged public var data: String?
    @NSManaged public var timestamp: Int64
    @NSManaged public var drillResult: DrillResult?

}

extension Shot : Identifiable {
    
    var shotData: [String: Any]? {
        guard let data = data,
              let jsonData = data.data(using: .utf8) else { return nil }
        do {
            return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        } catch {
            print("Failed to decode shot data: \(error)")
            return nil
        }
    }
}