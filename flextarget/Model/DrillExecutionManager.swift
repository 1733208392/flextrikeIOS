import Foundation
import CoreData

class DrillExecutionManager {
    private let bleManager: BLEManager
    private let drillSetup: DrillSetup
    private let expectedDevices: [String]
    private let onComplete: ([DrillRepeatSummary]) -> Void
    private let onFailure: () -> Void
    
    private var currentRepeat = 0
    private var ackedDevices = Set<String>()
    private var ackTimeoutTimer: Timer?
    private var waitingForAcks = false
    private var repeatSummaries: [DrillRepeatSummary] = []
    private var currentRepeatShots: [ShotEvent] = []
    private var currentRepeatStartTime: Date?
    private var shotObserver: NSObjectProtocol?
    private let firstShotMockValue: TimeInterval = 1.0
    private var shotTimerDelay: TimeInterval?
    
    init(bleManager: BLEManager, drillSetup: DrillSetup, expectedDevices: [String], onComplete: @escaping ([DrillRepeatSummary]) -> Void, onFailure: @escaping () -> Void) {
        self.bleManager = bleManager
        self.drillSetup = drillSetup
        self.expectedDevices = expectedDevices
        self.onComplete = onComplete
        self.onFailure = onFailure

        startObservingShots()
    }
    
    deinit {
        stopObservingShots()
    }

    var summaries: [DrillRepeatSummary] {
        repeatSummaries
    }

    func startExecution() {
        repeatSummaries.removeAll()
        currentRepeatShots.removeAll()
        currentRepeatStartTime = nil
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
                    "countedShots": target.countedShots,
                    "repeat": currentRepeat,
                    "isFirst": index == 0
                ]
                let message: [String: Any] = [
                    "action": "netlink_forward",
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
            // Content may be a string or object; normalize and detect "ready"
            var didAck = false

            if let contentStr = json["content"] as? String {
                // Content is a string. It might be plain "ready" or a JSON string. Try to detect "ready" safely.
                if contentStr == "ready" {
                    didAck = true
                } else {
                    // Try to parse string as JSON and inspect
                    if let data = contentStr.data(using: .utf8) {
                        if let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if let cmd = parsed["command"] as? String, cmd == "ready" { didAck = true }
                            if let ack = parsed["ack"] as? String, ack == "ready" { didAck = true }
                        }
                    }
                }
            } else if let contentObj = json["content"] as? [String: Any] {
                // Content is already a dictionary
                if let command = contentObj["command"] as? String, command == "ready" {
                    didAck = true
                } else if let ack = contentObj["ack"] as? String, ack == "ready" {
                    didAck = true
                } else if let inner = contentObj["content"] as? [String: Any] {
                    if let innerCommand = inner["command"] as? String, innerCommand == "ready" { didAck = true }
                    if let innerAck = inner["ack"] as? String, innerAck == "ready" { didAck = true }
                } else if let innerStr = contentObj["content"] as? String {
                    // content.content might be a JSON string or plain string
                    if innerStr == "ready" { didAck = true }
                    else if let data = innerStr.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let cmd = parsed["command"] as? String, cmd == "ready" { didAck = true }
                        if let ack = parsed["ack"] as? String, ack == "ready" { didAck = true }
                    }
                }
            }

            if didAck {
                ackedDevices.insert(device)
                print("Device ack received: \(device)")
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

            // Schedule completion handling for this repeat
            let repeatIndex = currentRepeat
            let delay = Double(drillSetup.drillDuration) + Double(drillSetup.pause) + Double(drillSetup.delay) + 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.finalizeRepeat(repeatIndex: repeatIndex)

                if repeatIndex < self.drillSetup.repeats {
                    self.executeNextRepeat()
                } else {
                    self.stopObservingShots()
                    self.onComplete(self.repeatSummaries)
                }
            }
        } else {
            // Ack timeout - stop execution
            stopObservingShots()
            onFailure()
        }
    }
    
    private func sendStartCommands() {
        guard bleManager.isConnected else {
            print("BLE not connected - cannot send start commands")
            onFailure()
            return
        }

        prepareForRepeatStart()

        for targetName in expectedDevices {
            let message: [String: Any] = [
                "action": "netlink_forward",
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

    private func prepareForRepeatStart() {
        currentRepeatShots.removeAll()
        currentRepeatStartTime = Date()
        shotTimerDelay = nil
    }

    private func finalizeRepeat(repeatIndex: Int) {
        guard let startTime = currentRepeatStartTime else {
            print("No start time for repeat \(repeatIndex), skipping summary")
            return
        }

        let sortedShots = currentRepeatShots.sorted { $0.receivedAt < $1.receivedAt }
        let firstTargetName = (drillSetup.targets as? Set<DrillTargetsConfig>)?.sorted { $0.seqNo < $1.seqNo }.first?.targetName
        
        // Validate: if no shots from the first target, invalidate this repeat
        if let firstTarget = firstTargetName, !sortedShots.contains(where: { $0.shot.device == firstTarget }) {
            print("No shots received from first target \(firstTarget) for repeat \(repeatIndex), invalidating repeat")
            currentRepeatShots.removeAll()
            currentRepeatStartTime = nil
            return
        }

        let totalTime = sortedShots.reduce(0.0) { $0 + $1.shot.content.timeDiff }

        let numShots = sortedShots.count
        let fastest = sortedShots.map { $0.shot.content.timeDiff }.min() ?? 0.0
        let firstShotRaw = sortedShots.first?.shot.content.timeDiff ?? 0.0
        let firstShot = (sortedShots.first?.shot.device != firstTargetName) ? (firstShotRaw - (shotTimerDelay ?? 0.0)) : firstShotRaw
        let totalScore = sortedShots.reduce(0) { $0 + scoreForHitArea($1.shot.content.hitArea) }
        let summary = DrillRepeatSummary(
            repeatIndex: repeatIndex,
            totalTime: totalTime,
            numShots: numShots,
            firstShot: firstShot,
            fastest: fastest,
            score: totalScore,
            shots: sortedShots.map { $0.shot }
        )

        if repeatIndex - 1 < repeatSummaries.count {
            repeatSummaries[repeatIndex - 1] = summary
        } else {
            repeatSummaries.append(summary)
        }

        currentRepeatShots.removeAll()
        currentRepeatStartTime = nil
    }

    private func startObservingShots() {
        shotObserver = NotificationCenter.default.addObserver(
            forName: .bleShotReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleShotNotification(notification)
        }
    }

    private func stopObservingShots() {
        if let observer = shotObserver {
            NotificationCenter.default.removeObserver(observer)
            shotObserver = nil
        }
    }

    private func handleShotNotification(_ notification: Notification) {
        guard currentRepeatStartTime != nil else { return }
        guard let shotDict = notification.userInfo?["shot_data"] as? [String: Any] else { return }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: shotDict, options: [])
            let shot = try JSONDecoder().decode(ShotData.self, from: jsonData)
            let event = ShotEvent(shot: shot, receivedAt: Date())
            currentRepeatShots.append(event)
            
            // Store shot_timer_delay from the first target
            let firstTargetName = (drillSetup.targets as? Set<DrillTargetsConfig>)?.sorted { $0.seqNo < $1.seqNo }.first?.targetName
            if shot.device == firstTargetName {
                shotTimerDelay = shotDict["shot_timer_delay"] as? TimeInterval
            }
            
            print("Shot notification count: \(currentRepeatShots.count)")
        } catch {
            print("Failed to process shot notification: \(error)")
        }
    }

    private func scoreForHitArea(_ hitArea: String) -> Int {
        if hitArea.contains("BlackZone") {
            return -10
        }
        switch hitArea {
        case "AZone": return 5
        case "CZone": return 3
        case "DZone": return 2
        case "Miss": return 0
        case "WhiteZone": return -5
        case "Paddle": return 5
        case "Popper": return 5
        default: return 0
        }
    }

    private struct ShotEvent {
        let shot: ShotData
        let receivedAt: Date
    }
}
