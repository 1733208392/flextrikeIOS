import Foundation
import CoreData
import Combine

/// Protocol for drill repository operations
protocol DrillRepositoryProtocol {
    // DrillSetup operations (using value types)
    func saveDrillSetup(_ setup: DrillSetupData) throws
    func fetchDrillSetup(by id: UUID) throws -> DrillSetupData?
    func fetchAllDrillSetups() throws -> [DrillSetupData]
    func fetchAllDrillSetupsAsCoreData() throws -> [DrillSetup]
    func deleteDrillSetup(withId id: UUID) throws
    
    // DrillResult operations
    func saveDrillResult(_ result: DrillResult) throws
    func fetchRecentResults(limit: Int) throws -> [DrillResult]
    func fetchResults(for setupId: UUID) throws -> [DrillResult]
    
    // Summary operations
    func fetchRecentSummaries(limit: Int) throws -> [DrillSummary]
    func fetchRecentDrills(limit: Int) throws -> [(DrillSummary, DrillResult)]
}

/// Repository for drill data operations using CoreData
class DrillRepository: ObservableObject, DrillRepositoryProtocol {
    
    static let shared = DrillRepository()
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.context = persistenceController.container.viewContext
    }
    
    // MARK: - DrillSetup Operations
    
    func saveDrillSetup(_ setup: DrillSetupData) throws {
        // Check if setup already exists in CoreData
        let fetchRequest: NSFetchRequest<DrillSetup> = DrillSetup.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", setup.id as CVarArg)
        
        let existingSetups = try context.fetch(fetchRequest)
        
        let coreDataSetup: DrillSetup
        if let existing = existingSetups.first {
            // Update existing
            coreDataSetup = existing
            coreDataSetup.name = setup.name
            coreDataSetup.desc = setup.description
            coreDataSetup.demoVideoURL = setup.demoVideoURL
            coreDataSetup.thumbnailURL = setup.thumbnailURL
            coreDataSetup.delay = setup.delay
            
            // Update targets: reuse existing ones by ID, create only new ones
            let existingTargets = (coreDataSetup.targets as? Set<DrillTargetsConfig>) ?? []
            
            // Build a map of existing targets by their ID (safely handle nil)
            var targetMap: [UUID: DrillTargetsConfig] = [:]
            for existingTarget in existingTargets {
                if let id = existingTarget.id {
                    targetMap[id] = existingTarget
                }
            }
            
            let targetIdsToKeep = Set(setup.targets.map { $0.id })
            
            // Update existing or create new targets
            for targetConfig in setup.targets {
                let config: DrillTargetsConfig
                
                if let existing = targetMap[targetConfig.id] {
                    // Reuse existing target
                    config = existing
                } else {
                    // Create new target only if it doesn't exist
                    config = DrillTargetsConfig(context: context)
                    config.id = targetConfig.id
                    coreDataSetup.addToTargets(config)
                }
                
                // Update target properties
                config.seqNo = Int32(targetConfig.seqNo)
                config.targetName = targetConfig.targetName
                config.targetType = targetConfig.targetType
                config.timeout = targetConfig.timeout
                config.countedShots = Int32(targetConfig.countedShots)
            }
            
            // Remove targets that are no longer needed
            let targetsToRemove = existingTargets.filter { !targetIdsToKeep.contains($0.id ?? UUID()) }
            for target in targetsToRemove {
                coreDataSetup.removeFromTargets(target)
                context.delete(target)
            }
        } else {
            // Create new
            coreDataSetup = DrillSetup(context: context, from: setup)
        }
        
        try context.save()
        print("DrillSetup saved to CoreData: \(setup.name)")
        // Notify listeners that the repository changed (so UI can refresh)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
        }
    }
    
    func fetchDrillSetup(by id: UUID) throws -> DrillSetupData? {
        let fetchRequest: NSFetchRequest<DrillSetup> = DrillSetup.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(fetchRequest)
        return results.first?.toStruct()
    }
    
    func fetchAllDrillSetups() throws -> [DrillSetupData] {
        let fetchRequest: NSFetchRequest<DrillSetup> = DrillSetup.fetchRequest()
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toStruct() }
    }
    
    func fetchAllDrillSetupsAsCoreData() throws -> [DrillSetup] {
        let fetchRequest: NSFetchRequest<DrillSetup> = DrillSetup.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    func deleteDrillSetup(withId id: UUID) throws {
        let fetchRequest: NSFetchRequest<DrillSetup> = DrillSetup.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(fetchRequest)
        for setup in results {
            // Attempt to remove any stored video/thumbnail files referenced by this setup
            if let videoURL = setup.demoVideoURL {
                do { try FileManager.default.removeItem(at: videoURL) } catch { /* ignore */ }
            }
            if let thumbURL = setup.thumbnailURL {
                do { try FileManager.default.removeItem(at: thumbURL) } catch { /* ignore */ }
            }
            context.delete(setup)
        }
        
        try context.save()
        // Notify listeners that the repository changed (so UI can refresh)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
        }
    }
    
    // MARK: - DrillResult Operations
    
    func saveDrillResult(_ result: DrillResult) throws {
        try context.save()
    }
    
    func fetchRecentResults(limit: Int = 10) throws -> [DrillResult] {
        let fetchRequest: NSFetchRequest<DrillResult> = DrillResult.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)]
        fetchRequest.fetchLimit = limit
        
        return try context.fetch(fetchRequest)
    }
    
    func fetchResults(for setupId: UUID) throws -> [DrillResult] {
        let fetchRequest: NSFetchRequest<DrillResult> = DrillResult.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "drillId == %@", setupId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)]
        
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Summary Operations
    
    func fetchRecentSummaries(limit: Int = 3) throws -> [DrillSummary] {
        let results = try fetchRecentResults(limit: limit)
        
        return results.compactMap { result in
            result.toDrillSummary()
        }
    }
    
    func fetchRecentDrills(limit: Int = 3) throws -> [(DrillSummary, DrillResult)] {
        let results = try fetchRecentResults(limit: limit)
        
        return results.compactMap { result in
            guard let summary = result.toDrillSummary() else {
                return nil
            }
            return (summary, result)
        }
    }
    
}

