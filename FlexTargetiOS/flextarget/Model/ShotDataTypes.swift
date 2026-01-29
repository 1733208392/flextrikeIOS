import Foundation

// Codable structs for JSON decoding
struct ShotData: Codable, Equatable {
    let target: String?
    let content: Content
    let type: String?
    let action: String?
    let device: String?

    static func == (lhs: ShotData, rhs: ShotData) -> Bool {
        return lhs.target == rhs.target &&
               lhs.content == rhs.content &&
               lhs.type == rhs.type &&
               lhs.action == rhs.action &&
               lhs.device == rhs.device
    }

    enum CodingKeys: String, CodingKey {
        case target
        case content
        case type
        case action
        case device
    }
}

struct Content: Codable, Equatable {
    let command: String
    let hitArea: String
    let hitPosition: Position
    let rotationAngle: Double?
    let targetType: String
    let timeDiff: Double
    let device: String?
    let targetPos: Position?
    let `repeat`: Int?

    static func == (lhs: Content, rhs: Content) -> Bool {
        return lhs.command == rhs.command &&
               lhs.hitArea == rhs.hitArea &&
               lhs.hitPosition == rhs.hitPosition &&
               lhs.rotationAngle == rhs.rotationAngle &&
               lhs.targetType == rhs.targetType &&
               lhs.timeDiff == rhs.timeDiff &&
               lhs.device == rhs.device &&
               lhs.targetPos == rhs.targetPos &&
               lhs.`repeat` == rhs.`repeat`
    }

    enum CodingKeys: String, CodingKey {
        // Old format keys
        case command
        case hitArea = "hit_area"
        case hitPosition = "hit_position"
        case rotationAngle = "rotation_angle"
        case targetType = "target_type"
        case timeDiff = "time_diff"
        case device
        case targetPos = "targetPos"
        case `repeat` = "repeat"
        // New abbreviated format keys
        case cmd = "cmd"
        case ha = "ha"
        case hp = "hp"
        case rot = "rot"
        case tt = "tt"
        case td = "td"
        case std = "std"
        case tgt_pos = "tgt_pos"
        case rep = "rep"
    }

    init(command: String, hitArea: String, hitPosition: Position, rotationAngle: Double? = nil, targetType: String, timeDiff: Double, device: String? = nil, targetPos: Position? = nil, `repeat`: Int? = nil) {
        self.command = command
        self.hitArea = hitArea
        self.hitPosition = hitPosition
        self.rotationAngle = rotationAngle
        self.targetType = targetType
        self.timeDiff = timeDiff
        self.device = device
        self.targetPos = targetPos
        self.`repeat` = `repeat`
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode command: try new key first, then old key
        if let cmd = try? container.decode(String.self, forKey: .cmd) {
            self.command = cmd
        } else {
            self.command = try container.decode(String.self, forKey: .command)
        }
        
        // Decode hitArea: try new key first, then old key
        if let ha = try? container.decode(String.self, forKey: .ha) {
            self.hitArea = ha
        } else {
            self.hitArea = try container.decode(String.self, forKey: .hitArea)
        }
        
        // Decode hitPosition: try new key first, then old key
        if let hp = try? container.decode(Position.self, forKey: .hp) {
            self.hitPosition = hp
        } else {
            self.hitPosition = try container.decode(Position.self, forKey: .hitPosition)
        }
        
        // Decode rotationAngle: try a variety of key names and types (Double, Int, String)
        var rotAngle: Double? = nil

        // First, try the explicit keys we know about
        if let val = try? container.decodeIfPresent(Double.self, forKey: .rot) {
            rotAngle = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .rot) {
            rotAngle = Double(val)
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .rot), let d = Double(val) {
            rotAngle = d
        } else if let val = try? container.decodeIfPresent(Double.self, forKey: .rotationAngle) {
            rotAngle = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .rotationAngle) {
            rotAngle = Double(val)
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .rotationAngle), let d = Double(val) {
            rotAngle = d
        }

        // If not found yet, scan all keys for anything that looks like a rotation key
        if rotAngle == nil {
            for key in container.allKeys {
                let name = key.stringValue.lowercased()
                if name.contains("rot") || name.contains("rotation") {
                    if let d = try? container.decodeIfPresent(Double.self, forKey: key) {
                        rotAngle = d
                        break
                    }
                    if let i = try? container.decodeIfPresent(Int.self, forKey: key) {
                        rotAngle = Double(i)
                        break
                    }
                    if let s = try? container.decodeIfPresent(String.self, forKey: key), let d = Double(s) {
                        rotAngle = d
                        break
                    }
                }
            }
        }

        self.rotationAngle = rotAngle
        
        // Decode targetType: try new key first, then old key
        if let tt = try? container.decode(String.self, forKey: .tt) {
            self.targetType = tt
        } else {
            self.targetType = try container.decode(String.self, forKey: .targetType)
        }
        
        // Decode timeDiff: try new key first, then old key, handle multiple types
        if let td = try? container.decode(Double.self, forKey: .td) {
            self.timeDiff = td
        } else if let td = try? container.decode(Int.self, forKey: .td) {
            self.timeDiff = Double(td)
        } else if let tdStr = try? container.decode(String.self, forKey: .td), let tdDouble = Double(tdStr) {
            self.timeDiff = tdDouble
        } else if let timeDiffDouble = try? container.decode(Double.self, forKey: .timeDiff) {
            self.timeDiff = timeDiffDouble
        } else if let timeDiffStr = try? container.decode(String.self, forKey: .timeDiff), let timeDiffDouble = Double(timeDiffStr) {
            self.timeDiff = timeDiffDouble
        } else {
            self.timeDiff = 0.0
        }
        
        self.device = try container.decodeIfPresent(String.self, forKey: .device)
        
        // Decode targetPos: try new key first, then old key (both optional for rotation targets)
        var targetPosition: Position? = nil
        if let tgt_pos = try? container.decodeIfPresent(Position.self, forKey: .tgt_pos), tgt_pos != nil {
            targetPosition = tgt_pos
        } else if let targetPosValue = try? container.decodeIfPresent(Position.self, forKey: .targetPos), targetPosValue != nil {
            targetPosition = targetPosValue
        }
        self.targetPos = targetPosition
        
        // Decode repeat: try new key first, then old key
        if let rep = try? container.decodeIfPresent(Int.self, forKey: .rep) {
            self.`repeat` = rep
        } else {
            self.`repeat` = try container.decodeIfPresent(Int.self, forKey: .`repeat`)
        }
    }
    
    // Encode using old format keys for backward compatibility
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(command, forKey: .command)
        try container.encode(hitArea, forKey: .hitArea)
        try container.encode(hitPosition, forKey: .hitPosition)
        try container.encodeIfPresent(rotationAngle, forKey: .rotationAngle)
        try container.encode(targetType, forKey: .targetType)
        try container.encode(timeDiff, forKey: .timeDiff)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(targetPos, forKey: .targetPos)
        try container.encodeIfPresent(`repeat`, forKey: .`repeat`)
    }
}

struct Position: Codable, Equatable {
    let x: Double
    let y: Double

    static func == (lhs: Position, rhs: Position) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let xStr = try? container.decode(String.self, forKey: .x), let xVal = Double(xStr) {
            self.x = xVal
        } else {
            self.x = try container.decode(Double.self, forKey: .x)
        }
        if let yStr = try? container.decode(String.self, forKey: .y), let yVal = Double(yStr) {
            self.y = yVal
        } else {
            self.y = try container.decode(Double.self, forKey: .y)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}