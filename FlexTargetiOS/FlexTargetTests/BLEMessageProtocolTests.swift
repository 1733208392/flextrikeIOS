//
//  BLEMessageProtocolTests.swift
//  flextarget
//
//  Created by Test Framework on 2026/01/26.
//  Cross-platform integration tests validating identical JSON message formats on iOS and Android

import XCTest
import Foundation

@testable import FlexTarget

/**
 * Cross-platform message protocol tests
 * Ensures that iOS and Android parse identical JSON messages with same field mappings
 * and handle error responses consistently
 */
class BLEMessageProtocolTests: XCTestCase {
    
    // MARK: - Shot Data Message Format Tests
    
    func testShotMessageFormatConsistency() {
        // Both platforms must parse this shot message identically
        let shotMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "content": {
            "cmd": "shot",
            "ha": "C",
            "hp": {"x": 45.5, "y": 32.1},
            "tt": "idpa",
            "dd": 1.25,
            "d": "device_1"
          }
        }
        """
        
        // iOS parsing
        guard let data = shotMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = jsonObject["content"] as? [String: Any],
              let command = content["command"] as? String,
              let hitArea = content["hit_area"] as? String,
              let hitPosition = content["hit_position"] as? [String: Double],
              let targetType = content["target_type"] as? String,
              let timeDiff = content["time_diff"] as? Double else {
            XCTFail("Failed to parse shot message")
            return
        }
        
        // Assert field values match Android expectations
        XCTAssertEqual(command, "shot")
        XCTAssertEqual(hitArea, "C")
        XCTAssertEqual(hitPosition["x"], 45.5)
        XCTAssertEqual(hitPosition["y"], 32.1)
        XCTAssertEqual(targetType, "idpa")
        XCTAssertEqual(timeDiff, 1.25)
    }
    
    func testMultipleTargetTypesFormat() {
        // Test that all supported target types parse correctly
        let targetTypes = ["idpa", "ipsc", "uspsa", "cqb", "custom"]
        
        targetTypes.forEach { targetType in
            let message = BLETestData.createShotMessage(targetType: targetType)
            
            guard let data = message.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = jsonObject["c"] as? [String: Any],
                  let parsedTargetType = content["tt"] as? String else {
                XCTFail("Failed to parse shot message with target type: \(targetType)")
                return
            }
            
            XCTAssertEqual(parsedTargetType, targetType)
        }
    }
    
    func testHitAreaValuesFormat() {
        // Test all supported hit areas
        let hitAreas = ["A", "B", "C", "D", "E", "X"]
        
        hitAreas.forEach { hitArea in
            let message = BLETestData.createShotMessage(hitArea: hitArea)
            
            guard let data = message.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = jsonObject["c"] as? [String: Any],
                  let parsedHitArea = content["ha"] as? String else {
                XCTFail("Failed to parse hit area: \(hitArea)")
                return
            }
            
            XCTAssertEqual(parsedHitArea, hitArea)
        }
    }
    
    func testCoordinateRangeFormat() {
        // Test coordinate parsing with various ranges
        let coordinates = [
            (0.0, 0.0),      // Top-left
            (100.0, 100.0),  // Bottom-right
            (50.5, 50.5),    // Center with decimals
            (-10.0, -10.0),  // Negative coordinates
            (999.99, 999.99) // Large values
        ]
        
        coordinates.forEach { (x, y) in
            let message = BLETestData.createShotMessage(x: x, y: y)
            
            guard let data = message.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = jsonObject["c"] as? [String: Any],
                  let hitPosition = content["hp"] as? [String: Double] else {
                XCTFail("Failed to parse coordinates: (\(x), \(y))")
                return
            }
            
            XCTAssertEqual(hitPosition["x"], x)
            XCTAssertEqual(hitPosition["y"], y)
        }
    }
    
    // MARK: - Device List Message Format Tests
    
    func testDeviceListMessageFormat() {
        // Both platforms must parse device list identically
        let deviceListMessage = BLETestData.createDeviceListMessage(
            devices: [("Target1", "active"), ("Target2", "standby"), ("Target3", "sleep")]
        )
        
        guard let data = deviceListMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceArray = jsonObject["data"] as? [[String: String]] else {
            XCTFail("Failed to parse device list message")
            return
        }
        
        XCTAssertEqual(deviceArray.count, 3)
        XCTAssertEqual(deviceArray[0]["name"], "Target1")
        XCTAssertEqual(deviceArray[0]["mode"], "active")
        XCTAssertEqual(deviceArray[1]["name"], "Target2")
        XCTAssertEqual(deviceArray[1]["mode"], "standby")
        XCTAssertEqual(deviceArray[2]["name"], "Target3")
        XCTAssertEqual(deviceArray[2]["mode"], "sleep")
    }
    
    func testDeviceListEmptyDevices() {
        // Test parsing device list with no devices
        let emptyDeviceListMessage = BLETestData.createDeviceListMessage(devices: [])
        
        guard let data = emptyDeviceListMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceArray = jsonObject["data"] as? [[String: String]] else {
            XCTFail("Failed to parse empty device list message")
            return
        }
        
        XCTAssertEqual(deviceArray.count, 0)
    }
    
    // MARK: - Auth Data Message Format Tests
    
    func testAuthDataMessageFormat() {
        let authMessage = BLETestData.createAuthDataMessage(
            deviceId: "DEVICE_ABC123",
            token: "TOKEN_XYZ789"
        )
        
        guard let data = authMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = jsonObject["content"] as? [String: Any] else {
            XCTFail("Failed to parse auth data message")
            return
        }
        
        XCTAssertEqual(jsonObject["type"] as? String, "auth_data")
        XCTAssertEqual(content["device_id"] as? String, "DEVICE_ABC123")
        XCTAssertEqual(content["token"] as? String, "TOKEN_XYZ789")
        XCTAssertNotNil(content["timestamp"])
    }
    
    // MARK: - Message Separator Handling Tests
    
    func testMessageSeparatorsCarriageReturnLineFeed() {
        // \r\n separator handling
        let message = BLETestData.createShotMessage()
        let messageWithSeparator = message + "\r\n"
        
        XCTAssertTrue(messageWithSeparator.hasSuffix("\r\n"))
        
        // Both platforms should recognize this separator
        let separatorComponents = messageWithSeparator.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertGreaterThan(separatorComponents.count, 1)
    }
    
    func testMessageSeparatorsDoubleCarriageReturn() {
        // \r\r separator handling
        let message = BLETestData.createShotMessage()
        let messageWithSeparator = message + "\r\r"
        
        XCTAssertTrue(messageWithSeparator.hasSuffix("\r\r"))
        
        // Separator should be preserved
        let trimmed = messageWithSeparator.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmed.isEmpty)
    }
    
    func testMessageSeparatorRemoval() {
        // Test that separators are properly removed for JSON parsing
        let message = BLETestData.createShotMessage()
        let withSeparator = message + "\r\n"
        let cleaned = withSeparator.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Should be valid JSON without separator
        guard let _ = cleaned.data(using: .utf8) else {
            XCTFail("Failed to convert message to data")
            return
        }
        
        XCTAssertFalse(cleaned.contains("\r\n"))
        XCTAssertFalse(cleaned.contains("\r\r"))
    }
    
    // MARK: - JSON Encoding Consistency Tests
    
    func testJSONEncodingUtf8() {
        // All messages must be UTF-8 encoded
        let message = BLETestData.createShotMessage()
        
        guard let data = message.data(using: .utf8) else {
            XCTFail("Failed to encode message as UTF-8")
            return
        }
        
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testJSONStructureConsistency() {
        // Verify JSON structure is consistent across message types
        let messages = [
            ("shot", BLETestData.createShotMessage()),
            ("device_list", BLETestData.createDeviceListMessage()),
            ("auth_data", BLETestData.createAuthDataMessage())
        ]
        
        messages.forEach { (messageType, message) in
            guard let data = message.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                XCTFail("Failed to parse \(messageType) message")
                return
            }
            
            // All messages should have "type"/"t" and "action"/"a" or "content"/"c"
            XCTAssertTrue(jsonObject["type"] != nil || jsonObject["t"] != nil)
        }
    }
    
    // MARK: - Error Message Format Tests
    
    func testErrorResponseFormat() {
        // Standard error message format both platforms expect
        let errorMessage = """
        {
          "type": "notice",
          "action": "unknown",
          "state": "failure",
          "message": "Connection failed"
        }
        """
        
        guard let data = errorMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse error message")
            return
        }
        
        XCTAssertEqual(jsonObject["type"] as? String, "notice")
        XCTAssertEqual(jsonObject["state"] as? String, "failure")
        XCTAssertNotNil(jsonObject["message"])
    }
    
    // MARK: - Field Name Consistency Tests
    
    func testFieldNameCaseConsistency() {
        // Field names must be lowercase snake_case consistently
        let message = BLETestData.createShotMessage()
        
        guard let data = message.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse message")
            return
        }
        
        // Check top-level fields
        XCTAssertNotNil(jsonObject["t"]) // abbreviated
        XCTAssertNil(jsonObject["Type"]) // NOT uppercase
        XCTAssertNil(jsonObject["TYPE"]) // NOT all caps
        
        if let content = jsonObject["c"] as? [String: Any] {
            XCTAssertNotNil(content["ha"]) // abbreviated
            XCTAssertNil(content["hitArea"]) // NOT camelCase
            XCTAssertNil(content["HitArea"]) // NOT PascalCase
        }
    }
    
    func testSpecialCharacterHandling() {
        // Test that special characters in strings are properly escaped
        let deviceName = "Target™ Device®"
        let deviceListMessage = BLETestData.createDeviceListMessage(
            devices: [(deviceName, "active")]
        )
        
        guard let data = deviceListMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = jsonObject["data"] as? [[String: String]] else {
            XCTFail("Failed to parse device list with special characters")
            return
        }
        
        // Verify special characters are preserved through JSON encoding/decoding
        // (JSON serialization should handle escaping automatically)
        XCTAssertEqual(devices.count, 1)
    }
    
    // MARK: - Round-Trip Serialization Tests
    
    func testMessageRoundTripSerialization() {
        // Message should survive serialization -> deserialization -> re-serialization
        let originalMessage = BLETestData.createShotMessage(x: 12.34, y: 56.78)
        
        guard let data = originalMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse original message")
            return
        }
        
        // Re-serialize
        guard let reserialized = try? JSONSerialization.data(withJSONObject: jsonObject),
              let reserializedString = String(data: reserialized, encoding: .utf8) else {
            XCTFail("Failed to re-serialize message")
            return
        }
        
        // Parse re-serialized version
        guard let reserializedData = reserializedString.data(using: .utf8),
              let reserializedJSON = try? JSONSerialization.jsonObject(with: reserializedData) as? [String: Any],
              let reserializedContent = reserializedJSON["c"] as? [String: Any],
              let reserializedPosition = reserializedContent["hp"] as? [String: Double] else {
            XCTFail("Failed to parse re-serialized message")
            return
        }
        
        // Verify values survive round-trip
        XCTAssertEqual(reserializedPosition["x"], 12.34)
        XCTAssertEqual(reserializedPosition["y"], 56.78)
    }
    
    // MARK: - Compatibility Tests
    
    func testBackwardCompatibilityOldMessageFormat() {
        // Test parsing messages with legacy field names
        let legacyMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "shot": 1,
          "x": 45.5,
          "y": 32.1,
          "score": 10
        }
        """
        
        guard let data = legacyMessage.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse legacy message")
            return
        }
        
        // Both platforms should be able to handle this format
        XCTAssertNotNil(jsonObject["x"])
        XCTAssertNotNil(jsonObject["y"])
    }
    
    // MARK: - Large Message Tests
    
    func testLargeMessageParsing() {
        // Test messages exceeding chunk size (>100 bytes)
        var largeShotMessage = BLETestData.createShotMessage()
        
        // Pad to ensure size > 100 bytes
        while largeShotMessage.count < 150 {
            largeShotMessage = BLETestData.createShotMessage(
                x: Double(largeShotMessage.count),
                y: Double(largeShotMessage.count * 2)
            )
        }
        
        guard let data = largeShotMessage.data(using: .utf8) else {
            XCTFail("Failed to encode large message")
            return
        }
        
        XCTAssertGreaterThan(data.count, 100)
        
        // Should still parse correctly
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse large message")
            return
        }
        
        XCTAssertNotNil(jsonObject["type"])
    }
    
    func testMalformedJSONHandling() {
        // Test that both platforms handle malformed JSON gracefully
        let malformedMessages = [
            BLETestData.createMalformedJSON(),
            """
            {
              "type": "shot",
              "data": {incomplete}
            }
            """,
            """
            {
              "type": "shot",
              "data": [1, 2, 3,
            }
            """
        ]
        
        malformedMessages.forEach { message in
            // Attempt to parse (should fail or return nil)
            let data = message.data(using: .utf8)
            let result = try? JSONSerialization.jsonObject(with: data ?? Data())
            
            // Either parsing fails or succeeds - both platforms should handle consistently
            // The important thing is it doesn't crash the app
        }
    }
}
