import Foundation
import CoreData

class DrillExecutionManager {
    private let bleManager: BLEManager
    private let drillSetup: DrillSetup
    private let expectedDevices: [String]
    private let onComplete: () -> Void
    private let onFailure: () -> Void
    
    private var currentRepeat = 0
    private var ackedDevices = Set<String>()
    private var ackTimeoutTimer: Timer?
    private var waitingForAcks = false
    
    init(bleManager: BLEManager, drillSetup: DrillSetup, expectedDevices: [String], onComplete: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.bleManager = bleManager
        self.drillSetup = drillSetup
        self.expectedDevices = expectedDevices
        self.onComplete = onComplete
        self.onFailure = onFailure
    }
    
    func startExecution() {
        executeNextRepeat()
    }
    
    private func executeNextRepeat() {
        currentRepeat += 1
        print("Starting repeat \(currentRepeat) of \(drillSetup.repeats)")
        
        // Send ready commands
        sendReadyCommands()
        
        // Begin waiting for acks
        beginWaitingForAcks()
    }
    
    private func sendReadyCommands() {
        guard bleManager.isConnected else {
            print("BLE not connected")
            onFailure()
            return
        }
        
        guard let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> else {
            onFailure()
            return
        }
        let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
        
        for (index, target) in sortedTargets.enumerated() {
            do {
                let content: [String: Any] = [
                    "command": "ready",
                    "delay": drillSetup.delay,
                    "targetType": target.targetType ?? "",
                    "timeout": drillSetup.drillDuration,
                    "countedShots": target.countedShots
                ]
                let message: [String: Any] = [
                    "type": "netlink",
                    "action": "forward",
                    "dest": target.targetName ?? "",
                    "content": content
                ]
                let messageData = try JSONSerialization.data(withJSONObject: message, options: [])
                let messageString = String(data: messageData, encoding: .utf8)!
                print("Sending ready message for target \(target.targetName ?? ""), length: \(messageData.count)")
                bleManager.writeJSON(messageString)
                
                #if targetEnvironment(simulator)
                // In simulator, mock some shot received notifications after sending ready command
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1) * 2.0) {
                    // Mock shot data for this target
                    let mockShotData: [String: Any] = [
                        "target": target.targetName ?? "",
                        "device": target.targetName ?? "",
                        "type": "netlink",
                        "action": "forward",
                        "content": [
                            "command": "shot",
                            "hit_area": "center",
                            "hit_position": ["x": 200, "y": 400],
                            "rotation_angle": 0,
                            "target_type": target.targetType ?? "ipsc",
                            "time_diff": Double(index + 1) * 1.5
                        ]
                    ]
                    
                    NotificationCenter.default.post(
                        name: .bleShotReceived,
                        object: nil,
                        userInfo: ["shot_data": mockShotData]
                    )
                    
                    // Send a second shot after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let secondMockShotData: [String: Any] = [
                            "target": target.targetName ?? "",
                            "device": target.targetName ?? "",
                            "type": "netlink",
                            "action": "forward",
                            "content": [
                                "command": "shot",
                                "hit_area": "edge",
                                "hit_position": ["x": 220, "y": 430],
                                "rotation_angle": 15,
                                "target_type": target.targetType ?? "ipsc",
                                "time_diff": Double(index + 1) * 1.5 + 1.0
                            ]
                        ]
                        
                        NotificationCenter.default.post(
                            name: .bleShotReceived,
                            object: nil,
                            userInfo: ["shot_data": secondMockShotData]
                        )
                    }
                }
                #endif
            } catch {
                print("Failed to send ready message for target \(target.targetName ?? ""): \(error)")
                onFailure()
                return
            }
        }
    }
    
    private func beginWaitingForAcks() {
        guard bleManager.isConnected else {
            onFailure()
            return
        }

        // Reset tracking
        ackedDevices.removeAll()
        waitingForAcks = true

        // Start 10s guard timer
        ackTimeoutTimer?.invalidate()
        ackTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.handleAckTimeout()
        }

        // If no expected devices, proceed immediately
        if expectedDevices.isEmpty {
            finishWaitingForAcks(success: true)
        }
    }
    
    private func handleAckTimeout() {
        print("Ack timeout for repeat \(currentRepeat)")
        finishWaitingForAcks(success: false)
    }
    
    func handleNetlinkForward(_ notification: Notification) {
        guard waitingForAcks else { return }
        guard let userInfo = notification.userInfo, let json = userInfo["json"] as? [String: Any] else { return }

        if let device = json["device"] as? String {
            // Content may be a string or object; we only care about "ready"
            if let content = json["content"] as? String, content == "ready" {
                ackedDevices.insert(device)
                print("Device ack received: \(device) (string content)")
            } else if let content = json["content"] as? [String: Any], let command = content["command"] as? String, command == "ready" {
                ackedDevices.insert(device)
                print("Device ack received: \(device) (object content)")
            }

            // Check if all expected devices have acked
            if ackedDevices.count >= expectedDevices.count {
                finishWaitingForAcks(success: true)
            }
        }
    }
    
    private func finishWaitingForAcks(success: Bool) {
        waitingForAcks = false
        ackTimeoutTimer?.invalidate()
        ackTimeoutTimer = nil

        if success {
            // Send start commands
            sendStartCommands()
            
            // Check if we need to do more repeats
            if currentRepeat < drillSetup.repeats {
                // Schedule next repeat after drill duration + pause + delay + 1s latency compensation
                let delay = Double(drillSetup.drillDuration) + Double(drillSetup.pause) + Double(drillSetup.delay) + 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.executeNextRepeat()
                }
            } else {
                // All repeats completed
                onComplete()
            }
        } else {
            // Ack timeout - stop execution
            onFailure()
        }
    }
    
    private func sendStartCommands() {
        guard bleManager.isConnected else {
            print("BLE not connected - cannot send start commands")
            onFailure()
            return
        }

        for targetName in expectedDevices {
            let message: [String: Any] = [
                "type": "netlink",
                "action": "forward",
                "dest": targetName,
                "content": ["command": "start"]
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: message, options: [])
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Sending start command to \(targetName): \(jsonString)")
                    bleManager.writeJSON(jsonString)
                }
            } catch {
                print("Failed to serialize start command for \(targetName): \(error)")
            }
        }
    }
}