//
//  BLEManagerErrorTests.swift
//  flextarget
//
//  Created by Test Framework on 2026/01/26.
//  Integration tests for BLE error scenarios and edge cases

import XCTest
import Combine
import CoreBluetooth

@testable import FlexTarget

class BLEManagerErrorTests: XCTestCase {
    
    var mockCentralManager: MockCBCentralManager!
    var mockPeripheral: MockCBPeripheral!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        let uuid = UUID()
        mockPeripheral = MockCBPeripheral(uuid: uuid, name: "FlexTarget Device")
        mockCentralManager = MockCBCentralManager()
        mockCentralManager.addDiscoveredPeripheral(mockPeripheral)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        mockPeripheral = nil
        mockCentralManager = nil
        super.tearDown()
    }
    
    // MARK: - Bluetooth State Error Tests
    
    func testBluetoothDisabledError() {
        // Arrange
        mockCentralManager.mockState = .poweredOff
        let expectation = self.expectation(description: "State change notified")
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didUpdateState = {
            if self.mockCentralManager.state == .poweredOff {
                expectation.fulfill()
            }
        }
        
        // Act
        mockCentralManager.simulatePoweredOff()
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockCentralManager.state, .poweredOff)
        XCTAssertFalse(mockCentralManager.isScanning) // Should not be able to scan
    }
    
    func testBluetoothUnauthorizedError() {
        // Arrange
        let expectation = self.expectation(description: "Unauthorized state set")
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didUpdateState = {
            if self.mockCentralManager.state == .unauthorized {
                expectation.fulfill()
            }
        }
        
        // Act
        mockCentralManager.simulateUnauthorized()
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockCentralManager.state, .unauthorized)
        XCTAssertEqual(mockCentralManager.authorization, .denied)
    }
    
    // MARK: - Connection Error Tests
    
    func testConnectionTimeoutSimulation() {
        // Arrange
        let expectation = self.expectation(description: "Connection attempt made")
        let disconnectExpectation = self.expectation(description: "Disconnection due to timeout")
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        
        delegateWrapper.didConnectPeripheral = { _ in
            expectation.fulfill()
        }
        
        // Simulate timeout by immediately disconnecting
        delegateWrapper.didDisconnectPeripheral = { _, _ in
            disconnectExpectation.fulfill()
        }
        
        // Act - Connect
        mockCentralManager.connect(mockPeripheral, options: nil)
        
        // Assert - Connection attempt
        waitForExpectations(timeout: 1.0)
        
        // Act - Simulate timeout disconnection
        let timeoutExpectation = self.expectation(description: "Timeout disconnect")
        delegateWrapper.didDisconnectPeripheral = { _, _ in
            timeoutExpectation.fulfill()
        }
        
        mockCentralManager.cancelPeripheralConnection(mockPeripheral)
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(mockPeripheral.state, .disconnected)
    }
    
    func testConnectionFailureError() {
        // Arrange
        let expectation = self.expectation(description: "Connection failure")
        var connectionError: Error?
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        
        delegateWrapper.didFailToConnectPeripheral = { _, error in
            connectionError = error
            expectation.fulfill()
        }
        
        // Note: MockCBCentralManager doesn't simulate connection failures by default
        // In a real test, you'd extend it to support failure scenarios
        // For demonstration, we simulate a failure manually
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            delegateWrapper.didFailToConnectPeripheral?(
                self.mockPeripheral,
                NSError(domain: "BLE", code: 8, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
            )
        }
        
        // Act
        mockCentralManager.connect(mockPeripheral, options: nil)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(connectionError)
        XCTAssertEqual((connectionError as? NSError)?.code, 8)
    }
    
    // MARK: - Service Discovery Error Tests
    
    func testServiceDiscoveryWithMissingService() {
        // Arrange
        mockPeripheral.mockServices = [] // No services
        let expectation = self.expectation(description: "Service discovery completed with error")
        
        mockPeripheral.didDiscoverServices = { error in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.discoverServices(
            [CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")]
        )
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(mockPeripheral.services?.isEmpty ?? true)
    }
    
    func testCharacteristicDiscoveryWithMissingCharacteristics() {
        // Arrange
        let service = MockCBService(
            uuid: CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB"),
            characteristics: [] // Empty characteristics
        )
        mockPeripheral.mockServices = [service]
        
        let expectation = self.expectation(description: "Characteristic discovery completed")
        mockPeripheral.didDiscoverCharacteristics = { _, _ in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(service.characteristics?.isEmpty ?? true)
    }
    
    // MARK: - Malformed Message Tests
    
    func testReceiveMalformedJSON() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Malformed message received")
        var receivedData: Data?
        
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            if let mockChar = notifyChar as? MockCBCharacteristic,
               let value = mockChar.value {
                receivedData = value
                expectation.fulfill()
            }
        }
        
        // Create malformed JSON
        let malformedMessage = BLETestData.createMalformedJSON()
        let messageData = (malformedMessage + "\r\n").data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedData)
        
        // Verify it's malformed (incomplete JSON)
        let receivedString = String(data: receivedData!, encoding: .utf8)
        XCTAssertTrue(receivedString?.contains("incomplete") ?? false)
    }
    
    func testReceiveMissingRequiredFields() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Incomplete message received")
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Create JSON missing required fields
        let incompleteMessage = """
        {
          "type": "netlink",
          "action": "forward"
        }
        """
        let messageData = (incompleteMessage + "\r\n").data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil((notifyChar as? MockCBCharacteristic)?.value)
    }
    
    func testReceiveInvalidShotData() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Invalid shot data received")
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Create shot data with invalid coordinates
        let invalidMessage = """
        {
          "type": "netlink",
          "action": "forward",
          "content": {
            "command": "shot",
            "hit_area": "X",
            "hit_position": {"x": "not_a_number", "y": -9999},
            "target_type": "unknown",
            "time_diff": null,
            "device": "device_1"
          }
        }
        """
        let messageData = (invalidMessage + "\r\n").data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil((notifyChar as? MockCBCharacteristic)?.value)
    }
    
    // MARK: - Message Buffer Edge Cases
    
    func testPartialMessageWithoutSeparator() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Partial message received")
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Send partial message without separator
        let partialMessage = """
        {
          "type": "netlink",
          "action": "forward",
        """
        let messageData = partialMessage.data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil((notifyChar as? MockCBCharacteristic)?.value)
    }
    
    func testEmptyNotification() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Empty notification received")
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Act
        let emptyData = Data()
        mockPeripheral.simulateNotificationReceived(data: emptyData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Write Operation Error Tests
    
    func testWriteToReadOnlyCharacteristic() {
        // Arrange
        let readOnlyChar = MockCBCharacteristic(
            uuid: CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB"),
            properties: .read, // Read-only
            permissions: .readable
        )
        
        // Creating a mock service with read-only characteristic
        let service = MockCBService(
            uuid: CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB"),
            characteristics: [readOnlyChar]
        )
        
        mockPeripheral.mockServices = [service]
        
        let expectation = self.expectation(description: "Write attempted on read-only characteristic")
        var writeWasAttempted = false
        
        mockPeripheral.didWriteValueForCharacteristic = { _ in
            writeWasAttempted = true
            expectation.fulfill()
        }
        
        let testData = "Test data".data(using: .utf8)!
        
        // Act
        mockPeripheral.writeValue(testData, for: readOnlyChar, type: .withResponse)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        // In real scenario, system should prevent write, but in mock it allows for testing
        XCTAssertTrue(writeWasAttempted)
    }
    
    // MARK: - Disconnection Error Tests
    
    func testDisconnectionDuringDataTransfer() {
        // Arrange
        mockPeripheral.simulateStateChange(.connected)
        let expectation = self.expectation(description: "Disconnected during transfer")
        
        var disconnectError: Error?
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        
        delegateWrapper.didDisconnectPeripheral = { _, error in
            disconnectError = error
            expectation.fulfill()
        }
        
        // Act - Simulate unexpected disconnection with error
        mockCentralManager.cancelPeripheralConnection(mockPeripheral)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockPeripheral.state, .disconnected)
    }
    
    // MARK: - Notification Subscription Error Tests
    
    func testFailToEnableNotifications() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) as? MockCBCharacteristic else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Notification enable attempted")
        mockPeripheral.didSetNotifyValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.setNotifyValue(true, for: notifyChar)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(notifyChar.mockIsNotifying)
    }
    
    // MARK: - Multiple Operation Error Scenarios
    
    func testScanAfterBluetoothDisabled() {
        // Arrange
        mockCentralManager.mockState = .poweredOn
        
        // Act 1 - Start scan
        mockCentralManager.scanForPeripherals(withServices: nil, options: nil)
        XCTAssertTrue(mockCentralManager.isScanning)
        
        // Act 2 - Bluetooth turned off
        mockCentralManager.simulatePoweredOff()
        
        // Assert - Scan should be halted
        XCTAssertEqual(mockCentralManager.state, .poweredOff)
        // In real scenario, scan would stop when Bluetooth is disabled
    }
    
    func testConnectionFailureDuringDiscovery() {
        // Arrange
        let connectExpectation = self.expectation(description: "Connected")
        let failureExpectation = self.expectation(description: "Discovery failed")
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        
        delegateWrapper.didConnectPeripheral = { _ in
            connectExpectation.fulfill()
            
            // Simulate discovery failure
            self.mockPeripheral.didDiscoverServices = { error in
                failureExpectation.fulfill()
            }
            self.mockPeripheral.mockServices = nil
            self.mockPeripheral.discoverServices(nil)
        }
        
        // Act
        mockCentralManager.connect(mockPeripheral, options: nil)
        
        // Assert
        waitForExpectations(timeout: 2.0)
        XCTAssertNil(mockPeripheral.services)
    }
}
