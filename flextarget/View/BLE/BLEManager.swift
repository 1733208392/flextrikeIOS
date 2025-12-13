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

struct DiscoveredPeripheral: Identifiable, Hashable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
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
    func writeJSON(_ jsonString: String)
}

// Backwards-compatibility: some views reference an older protocol name `ConnectSmartTargetBLEProtocol`.
// Provide a typealias so both names refer to the same protocol and avoid compilation errors.
typealias ConnectSmartTargetBLEProtocol = BLEManagerProtocol

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Shared singleton instance for app-wide use
    static let shared = BLEManager()

    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var isConnected: Bool = false
    @Published var isReady: Bool = false
    @Published var isScanning: Bool = false
    @Published var error: BLEError?
    @Published var connectedPeripheral: DiscoveredPeripheral?
    // Optional name to auto-connect when a matching peripheral is discovered
    @Published var autoConnectTargetName: String? = nil

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
//    private let advServiceUUID = CBUUID(string: "002A7982-6A23-1A71-A5C2-6C4B54310C9C")
    private let advServiceUUID = CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")
    private let targetServiceUUID = CBUUID(string: "0000FFC9-0000-1000-8000-00805F9B34FB")

    
    private var connectionAttemptFailed = false
    private var connectionTimer: Timer?
    
    private func timeoutConnection() {
        print("Connection timeout after 30 seconds")
        stopScan()
        disconnect()
        connectionAttemptFailed = true
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
//    private let notifyCharacteristicUUID = CBUUID(string: "0C8E3F1E-5654-4C41-B93B-CEA35001ED01")
    private let notifyCharacteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

//    private let writeCharacteristicUUID = CBUUID(string: "0C8E3F1E-5654-4C41-B93B-CEA35001ED02")
    private let writeCharacteristicUUID = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // Add this property to BLEManager to store the completion handler
    private var writeCompletion: ((Bool) -> Void)?
    
    // Buffer to accumulate split messages until "\r\n" is received
    private var messageBuffer = Data()
    
    // Make initializer private to enforce singleton usage
    private override init() {
        super.init()
        #if targetEnvironment(simulator)
        // Simulator: Mock connected state and device list
        isConnected = true
        isReady = true
        networkDevices = [
            NetworkDevice(name: "Simulator Target 1", mode: "active"),
            NetworkDevice(name: "Simulator Target 2", mode: "standby"),
            NetworkDevice(name: "Simulator Target 3", mode: "active")
        ]
        lastDeviceListUpdate = Date()
        #else
        centralManager = CBCentralManager(delegate: self, queue: .main)
        #endif
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillTerminate() {
        disconnect()
    }
    
    // MARK: - Scanning
    func startScan() {
        #if targetEnvironment(simulator)
        // Simulator: No-op for scanning
        return
        #else
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

        // Start 60s scan timer to allow time to discover multiple peripherals
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.completeScan()
        }

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
        #endif
    }
    
    func stopScan() {
        isScanning = false
        centralManager.stopScan()
        fallbackScanTimer?.invalidate()
        fallbackScanTimer = nil
        pendingStartScan = false
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    func completeScan() {
        stopScan()
    }
    
    // MARK: - Connect
    
    func connect(to peripheral: CBPeripheral) {
        #if targetEnvironment(simulator)
        // Simulator: No-op for connection
        return
        #else
        error = nil
        stopScan()
        connectingPeripheral = peripheral
        peripheral.delegate = self
        // Actively disconnect immediately after attempting to connect
//        centralManager.cancelPeripheralConnection(peripheral)
        centralManager.connect(peripheral, options: nil)
        #endif
    }
    
    func connectToSelectedPeripheral(_ discoveredPeripheral: DiscoveredPeripheral) {
        #if targetEnvironment(simulator)
        // Simulator: No-op for connection
        return
        #else
        error = nil
        stopScan()
        connectingPeripheral = discoveredPeripheral.peripheral
        discoveredPeripheral.peripheral.delegate = self
        centralManager.connect(discoveredPeripheral.peripheral, options: nil)
        
        // Start 10s connection timer
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.timeoutConnection()
        }
        #endif
    }

    /// Find a discovered peripheral by name.
    /// - Parameters:
    ///   - name: The peripheral name to search for.
    ///   - caseInsensitive: If true, comparison is case-insensitive. Default is true.
    ///   - contains: If true, use substring matching (contains). If false, require exact match. Default is false.
    /// - Returns: The first matching `DiscoveredPeripheral` or nil if none found.
    public func findPeripheral(named name: String, caseInsensitive: Bool = true, contains: Bool = false) -> DiscoveredPeripheral? {
        // Normalize strings to avoid mismatches caused by different Unicode punctuation
        func normalize(_ s: String) -> String {
            // Trim whitespace
            var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
            // Replace common curly quotes/apostrophes with ASCII equivalents
            let replacements: [Character: Character] = [
                Character("\u{2019}"): Character("'"),
                Character("\u{2018}"): Character("'"),
                Character("\u{201C}"): Character("\"") ,
                Character("\u{201D}"): Character("\"")
            ]
            out = String(out.map { replacements[$0] ?? $0 })
            return out
        }

        let target = normalize(name)

        if caseInsensitive {
            let targetLower = target.lowercased()
            if contains {
                return discoveredPeripherals.first { normalize($0.name).lowercased().contains(targetLower) }
            } else {
                return discoveredPeripherals.first { normalize($0.name).lowercased() == targetLower }
            }
        } else {
            if contains {
                return discoveredPeripherals.first { normalize($0.name).contains(target) }
            } else {
                return discoveredPeripherals.first { normalize($0.name) == target }
            }
        }
    }

    /// Set or clear the auto-connect target name. When set, BLEManager will attempt
    /// to automatically connect to the first discovered peripheral that matches
    /// this name according to the `findPeripheral` rules.
    public func setAutoConnectTarget(_ name: String?) {
        DispatchQueue.main.async {
            self.autoConnectTargetName = name
            // If name cleared, ensure no pending auto-connect behavior remains
            if name == nil {
                // no-op for now
            }
        }
    }
    
    func disconnect() {
        #if targetEnvironment(simulator)
        // Simulator: Set disconnected state
        isConnected = false
        isReady = false
        connectedPeripheral = nil
        #else
        connectionAttemptFailed = true
        if let peripheral = connectingPeripheral {
            //print device is disconnected
            print("Device is disconnected")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        #endif
    }
    
    // MARK: - CBCentralManagerDelegate
    
    #if !targetEnvironment(simulator)
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
        
        // Previously we matched by a hardcoded name substring ("GR-WOLF").
        // Now rely only on advertised service UUID to identify candidate devices.
        if matchesTargetService {
            print("Adding peripheral: \(name)")
            // Cancel fallback broad-scan timer because we found a candidate
            fallbackScanTimer?.invalidate()
            fallbackScanTimer = nil

            if !discoveredPeripherals.contains(where: { $0.id == peripheral.identifier }) {
                let discovered = DiscoveredPeripheral(id: peripheral.identifier, name: name, peripheral: peripheral)
                discoveredPeripherals.append(discovered)
            }
            // If an auto-connect target name is set, and this discovered peripheral
            // matches, initiate an automatic connection and clear the target name.
            if let target = autoConnectTargetName {
                if let match = findPeripheral(named: target) {
                    // Clear the auto-connect target to avoid repeated attempts
                    autoConnectTargetName = nil
                    print("Auto-connecting to discovered target: \(match.name)")
                    connectToSelectedPeripheral(match)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        error = nil
        if let found = discoveredPeripherals.first(where: { $0.id == peripheral.identifier }) {
            connectedPeripheral = found
        }
        peripheral.delegate = self
        // Discover only the target service
        peripheral.discoverServices([targetServiceUUID])
    }
    
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
        // Do not auto-retry scan, let the view handle reconnection logic
    }
    #else
    // Simulator stubs for required protocol methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {}
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {}
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {}
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {}
    #endif
    
    #if !targetEnvironment(simulator)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Service discovery failed: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        if let targetService = services.first(where: { $0.uuid == targetServiceUUID }) {
            print("Found target service: \(targetService.uuid)")
            peripheral.discoverCharacteristics(nil, for: targetService)
        } else {
            print("Target service not found.")
            connectionAttemptFailed = true
            centralManager.cancelPeripheralConnection(peripheral)
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
                print("Found write characteristic: \(characteristic.uuid), properties: \(characteristic.properties)")
            } else if characteristic.uuid == notifyCharacteristicUUID {
                notifyCharacteristic = characteristic
                print("Found notify characteristic: \(characteristic.uuid), properties: \(characteristic.properties)")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Attempting to enable notifications for \(characteristic.uuid)")
                } else {
                    print("Notify characteristic does not support notifications: \(characteristic.properties)")
                }
                isConnected = true
            }
        }
        
        // Update readiness: true only when both write and notify characteristics are found
        let ready = (writeCharacteristic != nil) && (notifyCharacteristic != nil)
        DispatchQueue.main.async {
            self.isReady = ready
            if ready {
                self.connectionTimer?.invalidate()
                self.connectionTimer = nil
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        _ = characteristic.value
        
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
        
        // Accumulate data and process complete messages separated by \r\r or \r\n
        messageBuffer.append(data)
        let separator1 = "\r\r".data(using: .utf8)!
        let separator2 = "\r\n".data(using: .utf8)!
        let range1 = messageBuffer.range(of: separator1, options: .backwards)
        let range2 = messageBuffer.range(of: separator2, options: .backwards)
        guard let lastSeparatorRange = [range1, range2].compactMap({ $0 }).max(by: { $0.lowerBound < $1.lowerBound }) else {
            return
        }
        let completeData = messageBuffer.subdata(in: 0..<lastSeparatorRange.lowerBound)
        messageBuffer = messageBuffer.subdata(in: lastSeparatorRange.upperBound..<messageBuffer.count)
        
        if let string = String(data: completeData, encoding: .utf8) {
            let normalized = string.replacingOccurrences(of: "\r\r", with: "\r\n")
            let parts = normalized.split(separator: "\r\n", omittingEmptySubsequences: true)
            for part in parts {
                guard let partData = part.data(using: .utf8) else { continue }
                
                var notificationHandled = false
                
                // Try to parse as JSON
                if let json = try? JSONSerialization.jsonObject(with: partData, options: []) as? [String: Any] {
                    
                    // Handle the state notification
                    if let type = json["type"] as? String, type == "state",
                       let stateCode = json["state_code"] as? Int {
                        print("Received state notification with code: \(stateCode)")
                        NotificationCenter.default.post(
                            name: .bleStateNotificationReceived,
                            object: nil,
                            userInfo: ["state_code": stateCode]
                        )
                        notificationHandled = true
                    }
                    
                    // Handle incoming netlink device_list response and save globally
                    if let type = json["type"] as? String, type == "netlink",
                       let action = json["action"] as? String, action == "device_list",
                       let dataArray = json["data"] {
                        do {
                            let normalizedJson = try JSONSerialization.data(withJSONObject: dataArray, options: [])
                            let decoder = JSONDecoder()
                            let devices = try decoder.decode([NetworkDevice].self, from: normalizedJson)
                            print("Received netlink device_list: \(devices)")
                            DispatchQueue.main.async {
                                self.networkDevices = devices
                                self.lastDeviceListUpdate = Date()
                            }
                            NotificationCenter.default.post(name: .bleDeviceListUpdated, object: nil, userInfo: ["device_list": devices])
                            notificationHandled = true
                        } catch {
                            print("Failed to decode netlink device_list: \(error.localizedDescription)")
                        }
                    }
                    
                    // Handle incoming shot data
                    if let type = json["type"] as? String, type == "netlink",
                       let action = json["action"] as? String, action == "forward",
                       let content = json["content"] as? [String: Any],
                       let command = content["command"] as? String, command == "shot" {
                        print("Received shot data: \(json)")
                        NotificationCenter.default.post(name: .bleShotReceived, object: nil, userInfo: ["shot_data": json])
                        notificationHandled = true
                    }
                    
                    // Handle notice for non-master device connection failure
                    if let type = json["type"] as? String, type == "notice",
                       let state = json["state"] as? String, state == "failure",
                       let failureReason = json["failure_reason"] as? String, failureReason == "execution_error",
                       let message = json["message"] as? String, message.contains("working mode is not master") {
                        print("Received non-master device failure notice: \(json)")
                        DispatchQueue.main.async {
                            self.error = .unknown("Device is not in master mode: \(message)")
                        }
                        NotificationCenter.default.post(name: .bleErrorOccurred, object: nil, userInfo: ["error": BLEError.unknown("Device is not in master mode: \(message)")])
                        notificationHandled = true
                    }
                    
                    // Post general netlink forward messages (e.g. device ACKs with content "ready")
                    if let type = json["type"] as? String, type == "netlink",
                       let action = json["action"] as? String, action == "forward" {
                        // Avoid duplicating the shot notification which is already posted above
                        var isShot = false
                        if let content = json["content"] as? [String: Any], let command = content["command"] as? String, command == "shot" {
                            isShot = true
                        }
                        if let contentStr = json["content"] as? String, contentStr == "shot" {
                            isShot = true
                        }
                        
                        // Check if this is an image chunk
                        var isImageChunk = false
                        if let content = json["content"] as? [String: Any], let command = content["command"] as? String, command == "image_chunk" {
                            isImageChunk = true
                            print("Received image chunk: \(json)")
                            NotificationCenter.default.post(name: .bleImageChunkReceived, object: nil, userInfo: ["json": content])
                            notificationHandled = true
                        }
                        
                        if !isShot && !isImageChunk {
                            print("Received general netlink forward: \(json)")
                            NotificationCenter.default.post(name: .bleNetlinkForwardReceived, object: nil, userInfo: ["json": json])
                            notificationHandled = true
                        }
                    }
                    
                    if !notificationHandled {
                        print("Received unrecognized JSON notification: \(json)")
                        // Optionally post a general notification for unrecognized JSON
                        NotificationCenter.default.post(name: .bleNetlinkForwardReceived, object: nil, userInfo: ["json": json, "unrecognized": true])
                    }
                } else {
                    // Handle non-JSON data
                    if let stringData = String(data: partData, encoding: .utf8) {
                        print("Received non-JSON notification: \(stringData)")
                    } else {
                        print("Received binary notification: \(partData as NSData)")
                    }
                    // Optionally post a notification for non-JSON data
                    NotificationCenter.default.post(name: .bleNetlinkForwardReceived, object: nil, userInfo: ["raw_data": partData])
                    notificationHandled = true
                }
            }
        }
    }
    
    // In BLEManager, implement the delegate to handle write response
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let completion = writeCompletion {
            writeCompletion = nil
            if let error = error {
                print("BLE write error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("BLE write to characteristic \(characteristic.uuid) succeeded")
                completion(true)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to enable notifications for \(characteristic.uuid): \(error.localizedDescription)")
            // Optionally, set isConnected to false or handle reconnection
        } else {
            print("Notifications enabled for \(characteristic.uuid)")
        }
    }
    #else
    // Simulator stubs for required protocol methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {}
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {}
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {}
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {}
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {}
    #endif
}

// BLEManager conforms to BLEManagerProtocol
extension BLEManager: BLEManagerProtocol {
    func write(data: Data, completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        // Simulator: Mock successful write
        print("Simulator: Mock writing data")
        completion(true)
        #else
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
        #endif
    }
    
    func writeJSON(_ jsonString: String) {
        #if targetEnvironment(simulator)
        // Simulator: No-op for writing
        print("Simulator: Mock writing JSON: \(jsonString)")
        #else
        guard let peripheral = connectingPeripheral,
              let writeCharacteristic = writeCharacteristic else {
            print("Peripheral or write characteristic not available")
            return
        }
        let commandStr = jsonString + "\r\n"
        guard let data = commandStr.data(using: .utf8) else {
            print("Failed to encode JSON string")
            return
        }

        // peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
        
        //Add debug to print the JSON string
        print("Writing JSON data to BLE: \(commandStr)")
        print("BLE data length: \(data.count)")
        if data.count <= 100 {
            peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
        } else {
            // Split data into chunks of 100 bytes or less
            var startIndex = 0
            while startIndex < data.count {
                let endIndex = min(startIndex + 100, data.count)
                let chunk = data[startIndex..<endIndex]
                print("Writing chunk of size \(chunk.count)")
                peripheral.writeValue(chunk, for: writeCharacteristic, type: .withResponse)
                startIndex = endIndex
            }
        }
        #endif
    }
}

// Add a notification name for BLE state updates
extension Notification.Name {
    static let bleStateNotificationReceived = Notification.Name("bleStateNotificationReceived")
    static let bleDeviceListUpdated = Notification.Name("bleDeviceListUpdated")
    static let bleShotReceived = Notification.Name("bleShotReceived")
    static let bleNetlinkForwardReceived = Notification.Name("bleNetlinkForwardReceived")
    static let bleImageChunkReceived = Notification.Name("bleImageChunkReceived")
    static let bleErrorOccurred = Notification.Name("bleErrorOccurred")
    static let drillExecutionCompleted = Notification.Name("drillExecutionCompleted")
}
