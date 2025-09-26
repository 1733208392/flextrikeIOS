import Foundation

class DrillSetupStorage: ObservableObject {
    static let shared = DrillSetupStorage()
    @Published var drillSetups: [DrillSetup] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "DrillSetups"
    
    init() {
        loadDrillSetups()
    }
    
    // MARK: - Storage Operations
    
    func saveDrillSetups() {
        do {
            let data = try JSONEncoder().encode(drillSetups)
            userDefaults.set(data, forKey: storageKey)
            print("DrillSetups saved successfully")
        } catch {
            print("Failed to save DrillSetups: \(error)")
        }
    }
    
    func loadDrillSetups() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            print("No DrillSetups found in storage")
            return
        }
        
        do {
            drillSetups = try JSONDecoder().decode([DrillSetup].self, from: data)
            print("DrillSetups loaded successfully: \(drillSetups.count) items")
        } catch {
            print("Failed to load DrillSetups: \(error)")
            drillSetups = []
        }
    }
    
    // MARK: - CRUD Operations
    
    func addDrillSetup(_ setup: DrillSetup) {
        drillSetups.append(setup)
        saveDrillSetups()
    }
    
    func updateDrillSetup(_ setup: DrillSetup) {
        if let index = drillSetups.firstIndex(where: { $0.id == setup.id }) {
            drillSetups[index] = setup
            saveDrillSetups()
        }
    }
    
    func deleteDrillSetup(withId id: UUID) {
        drillSetups.removeAll { $0.id == id }
        saveDrillSetups()
    }
    
    func deleteDrillSetup(at offsets: IndexSet) {
        drillSetups.remove(atOffsets: offsets)
        saveDrillSetups()
    }
    
    func getDrillSetup(withId id: UUID) -> DrillSetup? {
        return drillSetups.first { $0.id == id }
    }
    
    func getDrillSetup(withName name: String) -> DrillSetup? {
        return drillSetups.first { $0.name == name }
    }
    
    func addTargetToDrillSetup(setupId: UUID, target: DrillTargetsConfig) {
        if let index = drillSetups.firstIndex(where: { $0.id == setupId }) {
            drillSetups[index].targets.append(target)
            saveDrillSetups()
        }
    }
    
    func removeTargetFromDrillSetup(setupId: UUID, targetId: UUID) {
        if let setupIndex = drillSetups.firstIndex(where: { $0.id == setupId }) {
            drillSetups[setupIndex].targets.removeAll { $0.id == targetId }
            saveDrillSetups()
        }
    }
    
    func updateTargetInDrillSetup(setupId: UUID, target: DrillTargetsConfig) {
        if let setupIndex = drillSetups.firstIndex(where: { $0.id == setupId }),
           let targetIndex = drillSetups[setupIndex].targets.firstIndex(where: { $0.id == target.id }) {
            drillSetups[setupIndex].targets[targetIndex] = target
            saveDrillSetups()
        }
    }
    
    func clearAllDrillSetups() {
        drillSetups.removeAll()
        saveDrillSetups()
    }
}