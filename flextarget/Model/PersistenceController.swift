import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    private var hasRetried = false

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DrillDataModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        loadStores()
        container.viewContext.automaticallyMergesChangesFromParent = true
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