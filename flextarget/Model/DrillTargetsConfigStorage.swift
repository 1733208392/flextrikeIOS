import Foundation

class DrillTargetsConfigStorage: ObservableObject {
    @Published var drillTargetsConfigs: [DrillTargetsConfig] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "DrillTargetsConfigs"
    
    init() {
        loadDrillTargetsConfigs()
    }
    
    // MARK: - Storage Operations
    
    func saveDrillTargetsConfigs() {
        do {
            let data = try JSONEncoder().encode(drillTargetsConfigs)
            userDefaults.set(data, forKey: storageKey)
            print("DrillTargetsConfigs saved successfully")
        } catch {
            print("Failed to save DrillTargetsConfigs: \(error)")
        }
    }
    
    func loadDrillTargetsConfigs() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            print("No DrillTargetsConfigs found in storage")
            return
        }
        
        do {
            drillTargetsConfigs = try JSONDecoder().decode([DrillTargetsConfig].self, from: data)
            print("DrillTargetsConfigs loaded successfully: \(drillTargetsConfigs.count) items")
        } catch {
            print("Failed to load DrillTargetsConfigs: \(error)")
            drillTargetsConfigs = []
        }
    }
    
    // MARK: - CRUD Operations
    
    func addDrillTargetsConfig(_ config: DrillTargetsConfig) {
        drillTargetsConfigs.append(config)
        saveDrillTargetsConfigs()
    }
    
    func updateDrillTargetsConfig(_ config: DrillTargetsConfig) {
        if let index = drillTargetsConfigs.firstIndex(where: { $0.id == config.id }) {
            drillTargetsConfigs[index] = config
            saveDrillTargetsConfigs()
        }
    }
    
    func deleteDrillTargetsConfig(withId id: UUID) {
        drillTargetsConfigs.removeAll { $0.id == id }
        saveDrillTargetsConfigs()
    }
    
    func deleteDrillTargetsConfig(at offsets: IndexSet) {
        drillTargetsConfigs.remove(atOffsets: offsets)
        saveDrillTargetsConfigs()
    }
    
    func getDrillTargetsConfig(withId id: UUID) -> DrillTargetsConfig? {
        return drillTargetsConfigs.first { $0.id == id }
    }
    
    func getDrillTargetsConfigsSorted() -> [DrillTargetsConfig] {
        return drillTargetsConfigs.sorted { $0.seqNo < $1.seqNo }
    }
    
    func getNextSequenceNumber() -> Int {
        return (drillTargetsConfigs.map { $0.seqNo }.max() ?? 0) + 1
    }
    
    func clearAllDrillTargetsConfigs() {
        drillTargetsConfigs.removeAll()
        saveDrillTargetsConfigs()
    }
}