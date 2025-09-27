//
//  BLEManager.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/27.
//

import Foundation
import CoreBluetooth
import Combine
import UIKit

// Device data structures for netlink device_list
struct NetworkDevice: Codable, Identifiable {
    let id = UUID()
    let name: String
    let mode: String
    
    // Custom coding keys to match JSON structure
    enum CodingKeys: String, CodingKey {
        case name, mode
    }
    
    init(name: String, mode: String) {
        self.name = name
        self.mode = mode
    }
}

struct DeviceListResponse: Codable {
    let type: String
    let action: String
    let data: [NetworkDevice]
}

struct DiscoveredPeripheral: Identifiable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
}

enum BLEError: Error, LocalizedError {
    case bluetoothOff
    case unauthorized
    case connectionFailed(String)
    case disconnected(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .bluetoothOff: return "Bluetooth is turned off."
        case .unauthorized: return "Bluetooth access is unauthorized."
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .disconnected(let msg): return "Disconnected: \(msg)"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }
}

protocol BLEManagerProtocol {
    var isConnected: Bool { get }
    func write(data: Data, completion: @escaping (Bool) -> Void)
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Shared singleton instance for app-wide use
    static let shared = BLEManager()

    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var isConnected: Bool = false
    @Published var isReady: Bool = false
    @Published var isScanning: Bool = false
    @Published var error: BLEError?
    @Published var connectedPeripheral: DiscoveredPeripheral?

    // Global device list data for sharing across views
    @Published var networkDevices: [NetworkDevice] = []
    @Published var lastDeviceListUpdate: Date?

    private var centralManager: CBCentralManager!
    private var connectingPeripheral: CBPeripheral?
    private var disposables = Set<AnyCancellable>()
    // Pending start flag and fallback timer for scanning
    private var pendingStartScan: Bool = false
    private var fallbackScanTimer: Timer?
    private let targetedScanDuration: TimeInterval = 5.0

    // 1. Store the target service UUID
    private let advServiceUUID = CBUUID(string: "002A7982-6A23-1A71-A5C2-6C4B54310C9C")
    private let targetServiceUUID = CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")

    
    private var serviceDiscoveryRetries: [UUID: Int] = [:]
    private let maxServiceDiscoveryRetries = 5
    
//    private let notifyCharacteristicUUID = CBUUID(string: "0C8E3F1E-5654-4C41-B93B-CEA35001ED01")
    private let notifyCharacteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

//    private let writeCharacteristicUUID = CBUUID(string: "0C8E3F1E-5654-4C41-B93B-CEA35001ED02")
    private let writeCharacteristicUUID = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // Add this property to BLEManager to store the completion handler
    private var writeCompletion: ((Bool) -> Void)?
    
    // Make initializer private to enforce singleton usage
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    // MARK: - Scanning
    func startScan() {
        discoveredPeripherals.removeAll()
        // Reset readiness when starting a new scan
        DispatchQueue.main.async {
            self.isReady = false
        }
        DispatchQueue.main.async {
            self.error = nil
        }
        guard centralManager.state == .poweredOn else {
            // Bluetooth not yet powered — remember to start when it becomes ready
            pendingStartScan = true
            DispatchQueue.main.async {
                self.error = .bluetoothOff
            }
            return
        }
        DispatchQueue.main.async {
            self.isScanning = true
        }
        // Start with a targeted scan for the service UUID
        centralManager.scanForPeripherals(withServices: [advServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        // Schedule fallback to broad scan if nothing found within targetedScanDuration
        fallbackScanTimer?.invalidate()
        fallbackScanTimer = Timer.scheduledTimer(withTimeInterval: targetedScanDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.isScanning && self.discoveredPeripherals.isEmpty {
                print("No targeted devices found within \(self.targetedScanDuration)s — falling back to broad scan")
                self.centralManager.stopScan()
                self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            }
        }
    }
    
    func stopScan() {
        isScanning = false
        centralManager.stopScan()
        fallbackScanTimer?.invalidate()
        fallbackScanTimer = nil
        pendingStartScan = false
    }
    
    // MARK: - Connect
    
    func connect(to peripheral: CBPeripheral) {
        error = nil
        stopScan()
        connectingPeripheral = peripheral
        peripheral.delegate = self
        // Actively disconnect immediately after attempting to connect
//        centralManager.cancelPeripheralConnection(peripheral)
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectingPeripheral {
            //print device is disconnected
            print("Device is disconnected")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Auto-start pending scan if requested earlier
            if pendingStartScan {
                pendingStartScan = false
                startScan()
            }
            break
        case .unauthorized:
            error = .unauthorized
        case .poweredOff:
            error = .bluetoothOff
        default:
            error = .unknown("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        print("Discovered peripheral: \(name), RSSI: \(RSSI)")
        var matchesTargetService = false
        if let advServiceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            matchesTargetService = advServiceUUIDs.contains(where: { $0 == advServiceUUID })
        }

        let lowerName = name.lowercased()
        let matchesName = lowerName.contains("macbook")

        if matchesTargetService || matchesName {
            print("Adding peripheral: \(name)")
            // Cancel fallback broad-scan timer because we found a candidate
            fallbackScanTimer?.invalidate()
            fallbackScanTimer = nil

            if !discoveredPeripherals.contains(where: { $0.id == peripheral.identifier }) {
                let discovered = DiscoveredPeripheral(id: peripheral.identifier, name: name, peripheral: peripheral)
                discoveredPeripherals.append(discovered)
            }
            // Connect if not already connecting/connected
            if connectingPeripheral == nil && connectedPeripheral?.id != peripheral.identifier {
                connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        error = nil
        if let found = discoveredPeripherals.first(where: { $0.id == peripheral.identifier }) {
            connectedPeripheral = found
        }
        peripheral.delegate = self
        serviceDiscoveryRetries[peripheral.identifier] = 0
        // Discover only the target service
        peripheral.discoverServices([targetServiceUUID])    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        self.error = .connectionFailed(error?.localizedDescription ?? "Unknown")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isReady = false
        connectedPeripheral = nil
        if let err = error {
            self.error = .disconnected(err.localizedDescription)
        }
        // Retry service discovery if disconnected
        self.startScan()
    }
    
    // MARK: - CBPeripheralDelegate (implement as needed)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Service discovery failed: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        if let targetService = services.first(where: { $0.uuid == targetServiceUUID }) {
            print("Found target service: \(targetService.uuid)")
            serviceDiscoveryRetries[peripheral.identifier] = nil
             peripheral.discoverCharacteristics(nil, for: targetService)
        } else {
            let retries = (serviceDiscoveryRetries[peripheral.identifier] ?? 0) + 1
            if retries <= maxServiceDiscoveryRetries {
                print("Target service not found, retrying (\(retries))...")
                serviceDiscoveryRetries[peripheral.identifier] = retries
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    peripheral.discoverServices([self.targetServiceUUID])
                }
            } else {
                print("Target service not found after \(maxServiceDiscoveryRetries) retries.")
                serviceDiscoveryRetries[peripheral.identifier] = nil
                //Send disconnect to peripheral
                centralManager.cancelPeripheralConnection(peripheral)
            }
            
            isConnected = false
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == writeCharacteristicUUID {
                writeCharacteristic = characteristic
                print("Found write characteristic: \(characteristic.uuid)")
            } else if characteristic.uuid == notifyCharacteristicUUID {
                notifyCharacteristic = characteristic
                print("Found notify characteristic: \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
                isConnected = true
            }
        }
        
        // Update readiness: true only when both write and notify characteristics are found
        let ready = (writeCharacteristic != nil) && (notifyCharacteristic != nil)
        DispatchQueue.main.async {
            self.isReady = ready
        }
    }
    
    func writeJSON(_ jsonString: String) {
        guard let peripheral = connectingPeripheral,
              let writeCharacteristic = writeCharacteristic else {
            print("Peripheral or write characteristic not available")
            return
        }
        guard let data = jsonString.data(using: .utf8) else {
            print("Failed to encode JSON string")
            return
        }
        
        //Add debug to print the JSON string
        print("Writing JSON data to BLE: \(jsonString)")
        peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        _ = characteristic.value
        //        print("Received notification from peripheral \(peripheral.identifier) on characteristic \(characteristic.uuid), data: \(data as! NSData)")
        
        if let error = error {
            print("Failed to receive notification: \(error.localizedDescription)")
            return
        }
        
        guard error == nil, let data = characteristic.value else {
            guard characteristic.value != nil else {
                print("No data received from notify characteristic")
                return
            }
            return
        }
        
        // Parse JSON only
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            // Debug print for parsed JSON
            print("Parsed JSON: \(json)")
        }
        
        // Handle the state notification
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let type = json["type"] as? String, type == "state",
           let stateCode = json["state_code"] as? Int {
            // Handle the state notification as needed
            print("Received state notification with code: \(stateCode)")
            NotificationCenter.default.post(
                name: .bleStateNotificationReceived,
                object: nil,
                userInfo: ["state_code": stateCode]
            )
        }

        // Handle incoming netlink device_list response and save globally
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = json["type"] as? String, type == "netlink",
           let action = json["action"] as? String, action == "device_list",
           let dataArray = json["data"] {
            do {
                let normalized = try JSONSerialization.data(withJSONObject: dataArray, options: [])
                let decoder = JSONDecoder()
                let devices = try decoder.decode([NetworkDevice].self, from: normalized)
                print("Received netlink device_list: \(devices)")
                DispatchQueue.main.async {
                    self.networkDevices = devices
                    self.lastDeviceListUpdate = Date()
                }
                NotificationCenter.default.post(name: .bleDeviceListUpdated, object: nil, userInfo: ["device_list": devices])
            } catch {
                print("Failed to decode netlink device_list: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleAppWillTerminate() {
        disconnect()
    }
    
    // In BLEManager, implement the delegate to handle write response
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let completion = writeCompletion {
            writeCompletion = nil
            if let error = error {
                print("BLE write error: \(error.localizedDescription)")
                completion(false)
            } else {
//                print("BLE write to characteristic \(characteristic.uuid) succeeded")
                completion(true)
            }
        }
    }
}

// BLEManager conforms to BLEManagerProtocol
extension BLEManager: BLEManagerProtocol {
    func write(data: Data, completion: @escaping (Bool) -> Void) {
        guard let peripheral = connectingPeripheral,
              let writeCharacteristic = writeCharacteristic,
              isConnected else {
            completion(false)
            return
        }
        // Store the completion to call after write response
        writeCompletion = completion
//        print("Writing data to BLE: \(data as NSData)")
        peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
    }
}

// Add a notification name for BLE state updates
extension Notification.Name {
    static let bleStateNotificationReceived = Notification.Name("bleStateNotificationReceived")
    static let bleDeviceListUpdated = Notification.Name("bleDeviceListUpdated")
}
