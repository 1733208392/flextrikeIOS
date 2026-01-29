import Foundation

class DrillRecordStorage {
    static let shared = DrillRecordStorage()
    private let fileName = "drill_records.json"
    private var records: [DrillRecord] = []
    
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
            records = try JSONDecoder().decode([DrillRecord].self, from: data)
        } catch {
            records = []
        }
    }
    
    func save() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: url)
        } catch {
            print("Failed to save drill records: \(error)")
        }
    }
    
    func getAll() -> [DrillRecord] {
        records
    }
    
    func add(_ record: DrillRecord) {
        records.append(record)
        save()
    }
    
    func update(_ record: DrillRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
            save()
        }
    }
    
    func delete(_ record: DrillRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }
    
    // Example calculation: average shot interval for a drill record
    func averageShotInterval(for record: DrillRecord) -> TimeInterval? {
        let allShots = record.setRecords.flatMap { $0.shotRecords }
        guard allShots.count > 1 else { return nil }
        let sortedShots = allShots.sorted { $0.timestamp < $1.timestamp }
        let intervals = zip(sortedShots.dropFirst(), sortedShots).map { $0.timestamp.timeIntervalSince($1.timestamp) }
        return intervals.reduce(0, +) / Double(intervals.count)
    }
    
    // Example calculation: shot accuracy by area
    func shotAccuracy(for record: DrillRecord, area: String) -> Double {
        let allShots = record.setRecords.flatMap { $0.shotRecords }
        guard !allShots.isEmpty else { return 0 }
        let hits = allShots.filter { $0.position.area == area }.count
        return Double(hits) / Double(allShots.count)
    }
}
