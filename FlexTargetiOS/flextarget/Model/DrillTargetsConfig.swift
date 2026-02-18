import Foundation

/// Represents a single variant of a target, stored in the targetVariant JSON field
struct TargetVariant: Codable, Equatable, Hashable {
    let targetType: String
    let startTime: Double
    let endTime: Double
}

struct DrillTargetsConfigData: Identifiable, Codable, Equatable {
    let id: UUID
    var seqNo: Int
    var targetName: String
    var targetType: String
    var timeout: TimeInterval // seconds
    var countedShots: Int
    var action: String
    var duration: Double
    var targetVariant: String? // JSON array of TargetVariant objects
    
    init(id: UUID = UUID(), seqNo: Int, targetName: String, targetType: String, timeout: TimeInterval, countedShots: Int, action: String = "", duration: Double = 0.0, targetVariant: String? = nil) {
        self.id = id
        self.seqNo = seqNo
        self.targetName = targetName
        self.targetType = targetType
        self.timeout = timeout
        self.countedShots = countedShots
        self.action = action
        self.duration = duration
        self.targetVariant = targetVariant
    }
    
    /// Parses targetVariant JSON string into array of TargetVariant structs
    /// Returns empty array if JSON is nil or malformed
    func parseVariants() -> [TargetVariant] {
        guard let variantJSON = targetVariant else { return [] }
        guard let data = variantJSON.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([TargetVariant].self, from: data)
        } catch {
            print("Failed to parse targetVariant JSON: \(error)")
            return []
        }
    }
    
    /// Encodes array of TargetVariant into JSON string
    static func encodeVariants(_ variants: [TargetVariant]) -> String {
        do {
            let data = try JSONEncoder().encode(variants)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Failed to encode variants: \(error)")
            return ""
        }
    }

    /// Parses targetType which can be either a legacy single value ("ipsc")
    /// or a JSON array string ("[\"ipsc\",\"hostage\"]")
    func parseTargetTypes() -> [String] {
        let raw = targetType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }

        if raw.hasPrefix("[") {
            guard let data = raw.data(using: .utf8) else { return [] }
            do {
                let values = try JSONDecoder().decode([String].self, from: data)
                return values.filter { !$0.isEmpty }
            } catch {
                print("Failed to parse targetType JSON array: \(error)")
                return []
            }
        }

        return [raw]
    }

    func primaryTargetType(default fallback: String = "ipsc") -> String {
        parseTargetTypes().first ?? fallback
    }

    static func encodeTargetTypes(_ targetTypes: [String]) -> String {
        let filtered = targetTypes.filter { !$0.isEmpty }
        do {
            let data = try JSONEncoder().encode(filtered)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("Failed to encode targetTypes: \(error)")
            return "[]"
        }
    }

    mutating func setTargetTypes(_ targetTypes: [String]) {
        targetType = Self.encodeTargetTypes(targetTypes)
    }
}