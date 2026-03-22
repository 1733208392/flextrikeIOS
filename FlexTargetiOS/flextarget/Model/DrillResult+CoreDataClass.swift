import Foundation
import CoreData

@objc(DrillResult)
public class DrillResult: NSManagedObject {
    /// In-memory cache for decoded shots to avoid repeated JSON decoding during performance calculations
    internal var _cachedShots: [ShotData]?
}

extension DrillResult : Identifiable {

}
