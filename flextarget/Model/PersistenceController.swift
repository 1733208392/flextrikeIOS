import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    let container: NSPersistentContainer
    private var hasRetried = false

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DrillDataModel")
        if let description = container.persistentStoreDescriptions.first {
            // Lightweight migration for additive model changes (like adding a new entity).
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        loadStores()
        
        // Configure viewContext
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Explicitly ensure viewContext uses main queue (should be default, but be explicit)
        if container.viewContext.concurrencyType != .mainQueueConcurrencyType {
            print("WARNING: ViewContext is not using main queue concurrency type!")
        }
    }

    private func loadStores() {
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
                if !self.hasRetried, let url = storeDescription.url {
                    self.hasRetried = true
                    do {
                        try FileManager.default.removeItem(at: url)
                        print("Deleted corrupted store, retrying...")
                        self.loadStores()
                    } catch {
                        print("Failed to delete store: \(error)")
                    }
                } else {
                    print("Failed to load stores after retry")
                }
            }
        })
    }
}

extension Notification.Name {
    static let drillRepositoryDidChange = Notification.Name("drillRepositoryDidChange")
}