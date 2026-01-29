//
//  BLEManagerIntegrationTests.swift
//  flextarget
//
//  Created by Test Framework on 2026/01/26.
//  Integration tests for BLE device scanning, connection, and communication

import XCTest
import Combine
import CoreBluetooth

@testable import FlexTarget

class BLEManagerIntegrationTests: XCTestCase {
    
    var mockCentralManager: MockCBCentralManager!
    var mockPeripheral: MockCBPeripheral!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Create fresh BLE manager instance for each test
        // Note: BLEManager is a singleton, so we'd need to inject or mock the centralManager
        // For now, we create the mock peripheral that would be discovered
        let uuid = UUID()
        mockPeripheral = MockCBPeripheral(uuid: uuid, name: "FlexTarget Device")
        
        mockCentralManager = MockCBCentralManager()
        mockCentralManager.mockState = .poweredOn
        
        // Add test peripheral to be discovered
        mockCentralManager.addDiscoveredPeripheral(mockPeripheral)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        mockPeripheral = nil
        mockCentralManager = nil
        super.tearDown()
    }
    
    // MARK: - Scanning Tests
    
    func testScanStartsWithServiceUUID() {
        // Arrange
        mockCentralManager.mockState = .poweredOn
        
        // Act
        mockCentralManager.scanForPeripherals(
            withServices: [CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Assert
        XCTAssertTrue(mockCentralManager.isScanning)
        XCTAssertNotNil(mockCentralManager.scanStartedWithUUIDs)
        XCTAssertEqual(
            mockCentralManager.scanStartedWithUUIDs?.first?.uuidString,
            "0000FFC9-0000-1000-8000-00805F9B34FB"
        )
    }
    
    func testScanDiscoveryCallsDelegate() {
        // Arrange
        let expectation = self.expectation(description: "Peripheral discovered")
        var discoveredPeripheral: MockCBPeripheral?
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didDiscoverPeripheral = { peripheral, _, _ in
            discoveredPeripheral = peripheral
            expectation.fulfill()
        }
        
        // Act
        mockCentralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(discoveredPeripheral)
        XCTAssertEqual(discoveredPeripheral?.name, "FlexTarget Device")
    }
    
    func testScanStops() {
        // Arrange
        mockCentralManager.scanForPeripherals(withServices: nil, options: nil)
        XCTAssertTrue(mockCentralManager.isScanning)
        
        // Act
        mockCentralManager.stopScan()
        
        // Assert
        XCTAssertFalse(mockCentralManager.isScanning)
    }
    
    // MARK: - Connection Tests
    
    func testConnectToPeripheral() {
        // Arrange
        let expectation = self.expectation(description: "Peripheral connected")
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didConnectPeripheral = { _ in
            expectation.fulfill()
        }
        
        // Act
        mockCentralManager.connect(mockPeripheral, options: nil)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockPeripheral.state, .connected)
        XCTAssertEqual(mockCentralManager.connectCalls.count, 1)
    }
    
    func testDisconnectFromPeripheral() {
        // Arrange
        mockPeripheral.simulateStateChange(.connected)
        let expectation = self.expectation(description: "Peripheral disconnected")
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didDisconnectPeripheral = { _, _ in
            expectation.fulfill()
        }
        
        // Act
        mockCentralManager.cancelPeripheralConnection(mockPeripheral)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockPeripheral.state, .disconnected)
    }
    
    // MARK: - Service and Characteristic Discovery Tests
    
    func testDiscoverServices() {
        // Arrange
        let expectation = self.expectation(description: "Services discovered")
        mockPeripheral.didDiscoverServices = { error in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.discoverServices([CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")])
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(mockPeripheral.services)
        XCTAssertEqual(mockPeripheral.services?.count, 1)
        XCTAssertEqual(
            mockPeripheral.services?.first?.uuid.uuidString,
            "0000FFC9-0000-1000-8000-00805F9B34FB"
        )
    }
    
    func testDiscoverCharacteristics() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let targetService = mockPeripheral.services?.first
        XCTAssertNotNil(targetService)
        
        let expectation = self.expectation(description: "Characteristics discovered")
        mockPeripheral.didDiscoverCharacteristics = { service, error in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.discoverCharacteristics(nil, for: targetService!)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        let characteristics = targetService?.characteristics ?? []
        XCTAssertEqual(characteristics.count, 2)
        
        let writeChar = characteristics.first { $0.uuid.uuidString == "0000FFE2-0000-1000-8000-00805F9B34FB" }
        let notifyChar = characteristics.first { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }
        
        XCTAssertNotNil(writeChar)
        XCTAssertNotNil(notifyChar)
    }
    
    // MARK: - Notification Tests
    
    func testEnableNotifications() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Notification enabled")
        mockPeripheral.didSetNotifyValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Act
        mockPeripheral.setNotifyValue(true, for: notifyChar)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue((notifyChar as? MockCBCharacteristic)?.mockIsNotifying ?? false)
    }
    
    func testReceiveNotification() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Notification received")
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        let testData = "Test notification data".data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: testData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual((notifyChar as? MockCBCharacteristic)?.value, testData)
    }
    
    // MARK: - Message Parsing Tests
    
    func testReceiveShotMessageNotification() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Shot message received")
        var receivedData: Data?
        
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            if let mockChar = notifyChar as? MockCBCharacteristic,
               let value = mockChar.value {
                receivedData = value
                expectation.fulfill()
            }
        }
        
        // Create valid shot message with newline separator
        let shotMessage = BLETestData.createShotMessage(hitArea: "A", x: 50.0, y: 60.0)
        let messageData = (shotMessage + "\r\n").data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedData)
        
        let receivedString = String(data: receivedData!, encoding: .utf8)
        XCTAssertTrue(receivedString?.contains("\"cmd\": \"shot\"") ?? false)
        XCTAssertTrue(receivedString?.contains("\"ha\": \"A\"") ?? false)
    }
    
    func testReceiveDeviceListMessage() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Device list received")
        var receivedString: String?
        
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            if let mockChar = notifyChar as? MockCBCharacteristic,
               let value = mockChar.value,
               let str = String(data: value, encoding: .utf8) {
                receivedString = str
                expectation.fulfill()
            }
        }
        
        let deviceListMessage = BLETestData.createDeviceListMessage(
            devices: [("Flex1", "active"), ("Flex2", "standby")]
        )
        let messageData = (deviceListMessage + "\r\r").data(using: .utf8)!
        
        // Act
        mockPeripheral.simulateNotificationReceived(data: messageData)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedString)
        XCTAssertTrue(receivedString?.contains("device_list") ?? false)
        XCTAssertTrue(receivedString?.contains("Flex1") ?? false)
    }
    
    // MARK: - Write Operation Tests
    
    func testWriteDataToCharacteristic() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let writeChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE2-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Write characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "Write completed")
        mockPeripheral.didWriteValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        let testData = "Test write data".data(using: .utf8)!
        
        // Act
        mockPeripheral.writeValue(testData, for: writeChar, type: .withResponse)
        
        // Assert
        waitForExpectations(timeout: 1.0)
        // Note: MockCBCharacteristic doesn't persist written data, but the callback confirms write was processed
    }
    
    func testWriteJSONCommandToCharacteristic() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let writeChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE2-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Write characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "JSON write completed")
        mockPeripheral.didWriteValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        let jsonCommand = """
        {"action":"get_auth_data","timestamp":1234567890}
        """
        let jsonData = jsonCommand.data(using: .utf8)!
        
        // Act
        mockPeripheral.writeValue(jsonData, for: writeChar, type: .withResponse)
        
        // Assert
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Message Chunking Tests
    
    func testReceiveChunkedMessage() {
        // Arrange
        mockPeripheral.discoverServices(nil)
        let service = mockPeripheral.services!.first!
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        guard let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) else {
            XCTFail("Notify characteristic not found")
            return
        }
        
        let expectation = self.expectation(description: "All chunks received")
        expectation.expectedFulfillmentCount = 3
        
        mockPeripheral.didUpdateValueForCharacteristic = { _ in
            expectation.fulfill()
        }
        
        // Create a long message and split it into chunks
        let longMessage = BLETestData.createShotMessage(
            hitArea: "C",
            x: 123.456,
            y: 789.012,
            targetType: "ipsc",
            timeDiff: 1.5
        )
        let chunks = stride(from: 0, to: longMessage.count, by: 100).map { start in
            let end = min(start + 100, longMessage.count)
            return String(longMessage[longMessage.index(longMessage.startIndex, offsetBy: start)..<longMessage.index(longMessage.startIndex, offsetBy: end)])
        }
        
        // Act
        mockPeripheral.simulateChunkedNotification(chunks, withDelay: 0.05)
        
        // Assert
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - State Transition Tests
    
    func testBluetoothStateTransitionPoweredOn() {
        // Arrange
        mockCentralManager.mockState = .unknown
        let expectation = self.expectation(description: "State updated to poweredOn")
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        delegateWrapper.didUpdateState = {
            if self.mockCentralManager.state == .poweredOn {
                expectation.fulfill()
            }
        }
        
        // Act
        mockCentralManager.simulatePoweredOn()
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockCentralManager.state, .poweredOn)
    }
    
    func testBluetoothStateTransitionPoweredOff() {
        // Arrange
        mockCentralManager.mockState = .poweredOn
        let expectation = self.expectation(description: "State updated to poweredOff")
        
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
    }
    
    // MARK: - Multiple Operations Tests
    
    func testScanThenConnectWorkflow() {
        // Arrange
        let scanExpectation = self.expectation(description: "Scan discovered peripheral")
        let connectExpectation = self.expectation(description: "Connected to peripheral")
        
        var discoveredPeriph: BLEPeripheral?
        
        let delegateWrapper = MockCentralManagerDelegate()
        mockCentralManager.delegate = delegateWrapper
        
        delegateWrapper.didDiscoverPeripheral = { peripheral, _, _ in
            discoveredPeriph = peripheral
            scanExpectation.fulfill()
        }
        
        delegateWrapper.didConnectPeripheral = { _ in
            connectExpectation.fulfill()
        }
        
        // Act - Scan
        mockCentralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Assert - Scan
        waitForExpectations(timeout: 1.0, handler: nil)
        XCTAssertNotNil(discoveredPeriph)
        
        // Act - Connect
        if let peripheral = discoveredPeriph {
            let newExpectation = self.expectation(description: "Final connection")
            delegateWrapper.didConnectPeripheral = { _ in
                newExpectation.fulfill()
            }
            mockCentralManager.connect(peripheral, options: nil)
            waitForExpectations(timeout: 1.0)
        }
    }
    
    func testFullDiscoveryWorkflow() {
        // Arrange
        let serviceExpectation = self.expectation(description: "Services discovered")
        let charExpectation = self.expectation(description: "Characteristics discovered")
        
        mockPeripheral.didDiscoverServices = { _ in
            serviceExpectation.fulfill()
        }
        
        // Act - Discover Services
        mockPeripheral.discoverServices(nil)
        waitForExpectations(timeout: 1.0)
        
        // Assert Services
        XCTAssertNotNil(mockPeripheral.services)
        let service = mockPeripheral.services!.first!
        
        // Act - Discover Characteristics
        mockPeripheral.didDiscoverCharacteristics = { _, _ in
            charExpectation.fulfill()
        }
        mockPeripheral.discoverCharacteristics(nil, for: service)
        
        // Assert - Wait for characteristics
        waitForExpectations(timeout: 1.0)
        
        // Assert Characteristics
        let characteristics = service.characteristics ?? []
        XCTAssertEqual(characteristics.count, 2)
        
        let hasWrite = characteristics.contains { $0.uuid.uuidString == "0000FFE2-0000-1000-8000-00805F9B34FB" }
        let hasNotify = characteristics.contains { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }
        
        XCTAssertTrue(hasWrite)
        XCTAssertTrue(hasNotify)
    }
}
