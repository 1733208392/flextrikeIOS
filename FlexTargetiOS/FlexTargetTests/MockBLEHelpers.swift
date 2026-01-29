import Foundation
import CoreBluetooth

// MARK: - BLE Protocols for Mocking

protocol BLECharacteristic {
    var uuid: CBUUID { get }
    var value: Data? { get }
    var properties: CBCharacteristicProperties { get }
    var permissions: CBAttributePermissions { get }
    var isNotifying: Bool { get }
}

protocol BLEDescriptor {
    var uuid: CBUUID { get }
    var value: Any? { get }
}

protocol BLEService {
    var uuid: CBUUID { get }
    var characteristics: [BLECharacteristic]? { get }
}

protocol BLEPeripheral {
    var identifier: UUID { get }
    var name: String? { get }
    var state: CBPeripheralState { get }
    var services: [BLEService]? { get }
    var rssi: NSNumber { get }
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: BLEService)
    func setNotifyValue(_ enabled: Bool, for characteristic: BLECharacteristic)
    func writeValue(_ data: Data, for characteristic: BLECharacteristic, type: CBCharacteristicWriteType)
}

protocol BLECentralManager {
    var state: CBManagerState { get }
    var authorization: CBManagerAuthorization { get }
    var delegate: Any? { get set }
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func connect(_ peripheral: BLEPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: BLEPeripheral)
}

// MARK: - Extensions to make real CoreBluetooth classes conform to protocols

// Removed extensions for real classes to avoid conflicts

// MARK: - Mock CBCharacteristic

class MockCBCharacteristic: BLECharacteristic {
    let mockUUID: CBUUID
    var mockValue: Data?
    var mockProperties: CBCharacteristicProperties
    var mockPermissions: CBAttributePermissions
    var mockIsNotifying: Bool = false
    
    init(uuid: CBUUID, value: Data? = nil, properties: CBCharacteristicProperties = .notify, permissions: CBAttributePermissions = .readable) {
        self.mockUUID = uuid
        self.mockValue = value
        self.mockProperties = properties
        self.mockPermissions = permissions
    }
    
    var uuid: CBUUID {
        return mockUUID
    }
    
    var value: Data? {
        return mockValue
    }
    
    var properties: CBCharacteristicProperties {
        return mockProperties
    }
    
    var permissions: CBAttributePermissions {
        return mockPermissions
    }
    
    var isNotifying: Bool {
        return mockIsNotifying
    }
}

// MARK: - Mock CBDescriptor

class MockCBDescriptor: BLEDescriptor {
    let mockUUID: CBUUID
    var mockValue: Any?
    
    init(uuid: CBUUID, value: Any? = nil) {
        self.mockUUID = uuid
        self.mockValue = value
    }
    
    var uuid: CBUUID {
        return mockUUID
    }
    
    var value: Any? {
        return mockValue
    }
}

// MARK: - Mock CBService

class MockCBService: BLEService {
    let mockUUID: CBUUID
    var mockCharacteristics: [BLECharacteristic]?
    
    init(uuid: CBUUID, characteristics: [BLECharacteristic]? = nil) {
        self.mockUUID = uuid
        self.mockCharacteristics = characteristics
    }
    
    var uuid: CBUUID {
        return mockUUID
    }
    
    var characteristics: [BLECharacteristic]? {
        return mockCharacteristics
    }
}

// MARK: - Mock CBPeripheral

class MockCBPeripheral: NSObject, BLEPeripheral {
    let mockUUID: UUID
    let mockName: String?
    var mockState: CBPeripheralState = .disconnected
    var mockServices: [BLEService]? = nil
    var mockRSSI: NSNumber = NSNumber(value: -50)
    
    var didWriteValueForCharacteristic: ((BLECharacteristic) -> Void)?
    var didUpdateValueForCharacteristic: ((BLECharacteristic) -> Void)?
    var didSetNotifyValueForCharacteristic: ((BLECharacteristic) -> Void)?
    var didDiscoverServices: ((Error?) -> Void)?
    var didDiscoverCharacteristics: ((BLEService, Error?) -> Void)?
    var didUpdateNotificationStateForCharacteristic: ((BLECharacteristic, Error?) -> Void)?
    
    init(uuid: UUID, name: String?) {
        self.mockUUID = uuid
        self.mockName = name
    }
    
    var identifier: UUID {
        return mockUUID
    }
    
    var name: String? {
        return mockName
    }
    
    var state: CBPeripheralState {
        return mockState
    }
    
    var services: [BLEService]? {
        return mockServices
    }
    
    var rssi: NSNumber {
        return mockRSSI
    }
    
    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        // Simulate service discovery
        let writeChar = MockCBCharacteristic(
            uuid: CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB"),
            properties: .write
        )
        let notifyChar = MockCBCharacteristic(
            uuid: CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB"),
            properties: .notify
        )
        
        let service = MockCBService(
            uuid: CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB"),
            characteristics: [writeChar, notifyChar]
        )
        mockServices = [service]
        
        // Call the delegate callback after a short delay to simulate async behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.didDiscoverServices?(nil)
        }
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: BLEService) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.didDiscoverCharacteristics?(service, nil)
        }
    }
    
    func setNotifyValue(_ enabled: Bool, for characteristic: BLECharacteristic) {
        if let mockChar = characteristic as? MockCBCharacteristic {
            mockChar.mockIsNotifying = enabled
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.didSetNotifyValueForCharacteristic?(characteristic)
        }
    }
    
    func writeValue(_ data: Data, for characteristic: BLECharacteristic, type: CBCharacteristicWriteType) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.didWriteValueForCharacteristic?(characteristic)
        }
    }
    
    /// Simulate receiving a notification from the device
    func simulateNotificationReceived(data: Data) {
        guard let service = mockServices?.first,
              let notifyChar = service.characteristics?.first(where: { $0.uuid.uuidString == "0000FFE1-0000-1000-8000-00805F9B34FB" }) as? MockCBCharacteristic else {
            return
        }
        notifyChar.mockValue = data
        didUpdateValueForCharacteristic?(notifyChar)
    }
    
    /// Simulate state change
    func simulateStateChange(_ newState: CBPeripheralState) {
        mockState = newState
    }
}

// MARK: - Mock CBCentralManagerDelegate Wrapper

class MockCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    var didUpdateState: (() -> Void)?
    var didDiscoverPeripheral: ((MockCBPeripheral, [String: Any], NSNumber) -> Void)?
    var didConnectPeripheral: ((MockCBPeripheral) -> Void)?
    var didFailToConnectPeripheral: ((MockCBPeripheral, Error?) -> Void)?
    var didDisconnectPeripheral: ((MockCBPeripheral, Error?) -> Void)?
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        didUpdateState?()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let mockPeripheral = peripheral as? MockCBPeripheral {
            didDiscoverPeripheral?(mockPeripheral, advertisementData, RSSI)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let mockPeripheral = peripheral as? MockCBPeripheral {
            didConnectPeripheral?(mockPeripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let mockPeripheral = peripheral as? MockCBPeripheral {
            didFailToConnectPeripheral?(mockPeripheral, error)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let mockPeripheral = peripheral as? MockCBPeripheral {
            didDisconnectPeripheral?(mockPeripheral, error)
        }
    }
}

// MARK: - Mock CBCentralManager

class MockCBCentralManager: BLECentralManager {
    var mockState: CBManagerState = .unknown
    var mockAuthorization: CBManagerAuthorization = .allowedAlways
    var isScanning: Bool = false
    var connectedPeripherals: [CBPeripheral] = []
    var discoveredPeripherals: [MockCBPeripheral] = []
    
    var scanStartedWithUUIDs: [CBUUID]? = nil
    var scanStartedWithOptions: [String: Any]? = nil
    var connectCalls: [(peripheral: BLEPeripheral, options: [String: Any]?)] = []
    var disconnectCalls: [BLEPeripheral] = []
    
    var delegate: Any?
    
    var state: CBManagerState {
        return mockState
    }
    
    var authorization: CBManagerAuthorization {
        return mockAuthorization
    }
    
    init(delegate: Any? = nil, queue: DispatchQueue? = nil, options: [String: Any]? = nil) {
        self.delegate = delegate
    }
    
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        isScanning = true
        scanStartedWithUUIDs = serviceUUIDs
        scanStartedWithOptions = options
        
        // Simulate peripheral discovery after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.discoveredPeripherals.forEach { peripheral in
                let advertisementData: [String: Any] = [
                    CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")]
                ]
                (self.delegate as? MockCentralManagerDelegate)?.didDiscoverPeripheral?(peripheral, advertisementData, NSNumber(value: -50))
            }
        }
    }
    
    func stopScan() {
        isScanning = false
    }
    
    func connect(_ peripheral: BLEPeripheral, options: [String: Any]?) {
        connectCalls.append((peripheral: peripheral, options: options))
        
        // Simulate successful connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let mockPeripheral = peripheral as? MockCBPeripheral {
                mockPeripheral.simulateStateChange(.connected)
            }
            (self.delegate as? MockCentralManagerDelegate)?.didConnectPeripheral?(peripheral as! MockCBPeripheral)
        }
    }
    
    func cancelPeripheralConnection(_ peripheral: BLEPeripheral) {
        disconnectCalls.append(peripheral)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let mockPeripheral = peripheral as? MockCBPeripheral {
                mockPeripheral.simulateStateChange(.disconnected)
            }
            (self.delegate as? MockCentralManagerDelegate)?.didDisconnectPeripheral?(peripheral as! MockCBPeripheral, nil)
        }
    }
    
    /// Add a simulated discovered peripheral
    func addDiscoveredPeripheral(_ peripheral: MockCBPeripheral) {
        discoveredPeripherals.append(peripheral)
    }
    
    /// Simulate Bluetooth being turned on
    func simulatePoweredOn() {
        mockState = .poweredOn
        (delegate as? MockCentralManagerDelegate)?.didUpdateState?()
    }
    
    /// Simulate Bluetooth being turned off
    func simulatePoweredOff() {
        mockState = .poweredOff
        (delegate as? MockCentralManagerDelegate)?.didUpdateState?()
    }
    
    /// Simulate unauthorized BLE access
    func simulateUnauthorized() {
        mockState = .unauthorized
        mockAuthorization = .denied
        (delegate as? MockCentralManagerDelegate)?.didUpdateState?()
    }
}

// MARK: - Test Helper Extensions

extension MockCBPeripheral {
    /// Simulate receiving multiple notification chunks for a large message
    func simulateChunkedNotification(_ chunks: [String], withDelay delay: TimeInterval = 0.05) {
        var currentDelay = delay
        for (index, chunk) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                if let data = chunk.data(using: .utf8) {
                    self.simulateNotificationReceived(data: data)
                }
            }
            currentDelay += delay
        }
    }
}

// MARK: - Test Data Helper

struct BLETestData {
    /// Create a mock shot data message
    static func createShotMessage(
        hitArea: String = "AZone",
        x: Double = 370.7,
        y: Double = 468.6,
        targetType: String = "special_1",
        timeDiff: Double = 1.41,
        repeatCount: Int = 1,
        rotationAngle: Double = 0.0,
        shotTimerDelay: Double = 4.18
    ) -> String {
        let innerJson = """
        {"cmd":"shot","ha":"\(hitArea)","hp":{"x":\(x),"y":\(y)},"r":\(repeatCount),"ra":\(rotationAngle),"std":\(shotTimerDelay),"tt":"\(targetType)","td":\(timeDiff)}
        """
        let json = """
        {"t":"netlink","a":"forward","d":"01","c":\(innerJson)}
        """
        return json
    }
    
    /// Create a mock device list response
    static func createDeviceListMessage(devices: [(name: String, mode: String)] = [("Target1", "active"), ("Target2", "standby")]) -> String {
        let deviceArray = devices.map { (name, mode) in
            """
            {
              "name": "\(name)",
              "mode": "\(mode)"
            }
            """
        }.joined(separator: ",")
        
        let json = """
        {
          "type": "netlink",
          "action": "device_list",
          "data": [\(deviceArray)]
        }
        """
        return json
    }
    
    /// Create a mock auth data response
    static func createAuthDataMessage(deviceId: String = "DEVICE_123", token: String = "AUTH_TOKEN_ABC") -> String {
        let json = """
        {
          "type": "auth_data",
          "content": {
            "device_id": "\(deviceId)",
            "token": "\(token)",
            "timestamp": 1234567890
          }
        }
        """
        return json
    }
    
    /// Create malformed JSON for error testing
    static func createMalformedJSON() -> String {
        return """
        {
          "type": "invalid",
          "data": [incomplete json
        """
    }
}
