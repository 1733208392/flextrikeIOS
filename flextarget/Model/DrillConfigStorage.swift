import Foundation

class DrillConfigStorage {
    static let shared = DrillConfigStorage()
    private let fileName = "drill_configs.json"
    private var configs: [DrillConfig] = []
    
    private init() {
        load()
    }
    
    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
    
    func load() {
        guard let url = fileURL else { return }
        do {
            let data = try Data(contentsOf: url)
            configs = try JSONDecoder().decode([DrillConfig].self, from: data)
        } catch {
            configs = []
        }
    }
    
    func save() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(configs)
            try data.write(to: url)
        } catch {
            print("Failed to save drill configs: \(error)")
        }
    }
    
    func getAll() -> [DrillConfig] {
        configs
    }
    
    func add(_ config: DrillConfig) {
        configs.append(config)
        save()
    }
    
    func update(_ config: DrillConfig) {
        if let idx = configs.firstIndex(where: { $0.id == config.id }) {
            configs[idx] = config
            save()
        }
    }
    
    func delete(_ config: DrillConfig) {
        configs.removeAll { $0.id == config.id }
        save()
    }
    
    // Example calculation: count by gun type
    func countByGunType(_ gunType: String) -> Int {
        configs.filter { $0.gunType == gunType }.count
    }
    // Example calculation: count by target type
    func countByTargetType(_ targetType: String) -> Int {
        configs.filter { $0.targetType == targetType }.count
    }
    
    // MARK: - Editable Sets Storage
    private let editableSetsFileName = "drill_editable_sets.json"
    
    private var editableSetsFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(editableSetsFileName)
    }
    
    func loadEditableSets() -> [DrillSetConfigEditable] {
        guard let url = editableSetsFileURL else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let sets = try JSONDecoder().decode([DrillSetConfigEditable].self, from: data)
            return sets
        } catch {
            return []
        }
    }
    
    func saveEditableSets(_ sets: [DrillSetConfigEditable]) {
        guard let url = editableSetsFileURL else { return }
        do {
            let data = try JSONEncoder().encode(sets)
            try data.write(to: url)
        } catch {
            print("Failed to save editable sets: \(error)")
        }
    }
}
