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
    private var startCommandTime: Date?
    private var endCommandTime: Date?
    private var shotObserver: NSObjectProtocol?
    private let firstShotMockValue: TimeInterval = 1.0
    private var deviceDelayTimes: [String: String] = [:]
    private var globalDelayTime: String?
    private var firstTargetName: String?
    private var lastTargetName: String?
    private var isWaitingForEnd = false
    private var pauseTimer: Timer?
    private var isStopped = false
    private var drillDuration: TimeInterval?
    
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
        ackTimeoutTimer?.invalidate()
        pauseTimer?.invalidate()
    }

    var summaries: [DrillRepeatSummary] {
        repeatSummaries
    }

    func startExecution() {
        isStopped = false
        repeatSummaries.removeAll()
        currentRepeatShots.removeAll()
        currentRepeatStartTime = nil
        executeNextRepeat()
    }
    
    func stopExecution() {
        isStopped = true
        ackTimeoutTimer?.invalidate()
        pauseTimer?.invalidate()
        stopObservingShots()
    }
    
    private func executeNextRepeat() {
        guard !isStopped else { return }
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
                    "timeout": 300,
                    "countedShots": target.countedShots,
                    "repeat": currentRepeat,
                    "isFirst": index == 0,
                    "isLast": index == sortedTargets.count - 1
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
        deviceDelayTimes.removeAll()
        globalDelayTime = nil
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
        guard let userInfo = notification.userInfo, let json = userInfo["json"] as? [String: Any] else { return }
        
        if let device = json["device"] as? String {
            // Content may be a string or object; normalize and detect "ready"
            var didAck = false
            var didEnd = false
            
            if let contentObj = json["content"] as? [String: Any] {
                // Content is already a dictionary
                if let ack = contentObj["ack"] as? String, ack == "ready" {
                    didAck = true
                }
                if let ack = contentObj["ack"] as? String, ack == "end" {
                    didEnd = true
                }
                
                // Extract delay_time if present and we have an ack
                if didAck, let delayTime = contentObj["delay_time"] {
                    let delayTimeStr = delayTime as? String ?? "\(delayTime)"
                    deviceDelayTimes[device] = delayTimeStr
                    if globalDelayTime == nil && delayTimeStr != "0" {
                        globalDelayTime = delayTimeStr
                    }
                }
                
                if didAck {
                    guard waitingForAcks else { return }
                    ackedDevices.insert(device)
                    print("Device ack received: \(device)")
                    
                    // Check if all expected devices have acked
                    if ackedDevices.count >= expectedDevices.count {
                        finishWaitingForAcks(success: true)
                    }
                }
                
                if didEnd {
                    guard isWaitingForEnd else { return }
                    // Extract drill_duration if present
                    if let duration = contentObj["drill_duration"] as? TimeInterval {
                        drillDuration = duration
                        print("Drill duration received: \(duration)")
                    }
                    // Only process end message from the last target
                    if device == lastTargetName {
                        print("Last device end received: \(device)")
                        endCommandTime = Date()  // Record when end command is received
                        sendEndCommand()
                        completeRepeat()
                    }
                }
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

            // Begin waiting for end messages
            beginWaitingForEnd()
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
        startCommandTime = Date()  // Record when start command is sent

        var content: [String: Any] = ["command": "start"]
        if let delayTime = globalDelayTime {
            content["delay_time"] = delayTime
        }
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": "all",
            "content": content
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Sending start command to all devices: \(jsonString)")
                bleManager.writeJSON(jsonString)
            }
        } catch {
            print("Failed to serialize start command: \(error)")
        }
    }

    private func sendEndCommand() {
        guard bleManager.isConnected else {
            print("BLE not connected - cannot send end command")
            return
        }

        let content: [String: Any] = ["command": "end"]
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": "all",
            "content": content
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Sending end command to all devices: \(jsonString)")
                bleManager.writeJSON(jsonString)
            }
        } catch {
            print("Failed to serialize end command: \(error)")
        }
    }

    private func beginWaitingForEnd() {
        guard bleManager.isConnected else {
            onFailure()
            return
        }

        // Get the last target name
        if let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> {
            let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
            lastTargetName = sortedTargets.last?.targetName
        }
        
        isWaitingForEnd = true

        // Start 30s guard timer in case end message doesn't arrive
        ackTimeoutTimer?.invalidate()
        ackTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.handleEndTimeout()
        }

        // If no expected devices, proceed immediately
        if expectedDevices.isEmpty {
            completeRepeat()
        }
    }

    private func handleEndTimeout() {
        print("End timeout for repeat \(currentRepeat)")
        completeRepeat()
    }

    private func completeRepeat() {
        isWaitingForEnd = false
        ackTimeoutTimer?.invalidate()
        ackTimeoutTimer = nil

        let repeatIndex = currentRepeat
        finalizeRepeat(repeatIndex: repeatIndex)

        if repeatIndex < drillSetup.repeats {
            // Apply pause time before starting next repeat
            let pauseSeconds = TimeInterval(drillSetup.pause)
            print("Completed repeat \(repeatIndex), waiting \(pauseSeconds) seconds before next repeat...")
            
            pauseTimer?.invalidate()
            pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseSeconds, repeats: false) { [weak self] _ in
                self?.executeNextRepeat()
            }
        } else {
            stopObservingShots()
            onComplete(repeatSummaries)
        }
    }

    private func prepareForRepeatStart() {
        currentRepeatShots.removeAll()
        currentRepeatStartTime = Date()
        startCommandTime = nil
        endCommandTime = nil
        drillDuration = nil
        
        // Set first target name for later use in finalizeRepeat
        if let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> {
            let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
            firstTargetName = sortedTargets.first?.targetName
        }
    }

    private func finalizeRepeat(repeatIndex: Int) {
        guard let startTime = currentRepeatStartTime else {
            print("No start time for repeat \(repeatIndex), skipping summary")
            return
        }

        let sortedShots = currentRepeatShots.sorted { $0.receivedAt < $1.receivedAt }
        
        // Validate: if no shots received at all, invalidate this repeat
        if sortedShots.isEmpty {
            print("No shots received from any target for repeat \(repeatIndex), invalidating repeat")
            currentRepeatShots.removeAll()
            currentRepeatStartTime = nil
            return
        }

        // Calculate total time: drill_duration - delay_time from ready ACK
        var totalTime: TimeInterval = 0.0
        let timerDelay: TimeInterval
        if let delayTimeStr = globalDelayTime, let delayValue = Double(delayTimeStr) {
            timerDelay = delayValue
        } else {
            timerDelay = 0.0
        }
        
        if let duration = drillDuration {
            totalTime = max(0.0, duration - timerDelay)
            print("Total time calculation - drill_duration: \(duration), delay_time: \(timerDelay), total: \(totalTime)")
        } else {
            print("Warning: No drill_duration received for repeat \(repeatIndex), using fallback calculation")
            // Fallback to shot-based calculation if drill_duration missing
            var timeSumPerTarget: [String: TimeInterval] = [:]
            for shot in sortedShots {
                let device = shot.shot.device ?? shot.shot.target ?? "unknown"
                let currentSum = timeSumPerTarget[device] ?? 0.0
                timeSumPerTarget[device] = currentSum + shot.shot.content.timeDiff
            }
            totalTime = timeSumPerTarget.values.max() ?? 0.0
        }

        // Adjust timeDiff for shots from non-first targets by subtracting the delay
        let adjustedShots = sortedShots.map { event -> ShotData in
            if event.shot.device != firstTargetName {
                let adjustedTimeDiff = max(0, event.shot.content.timeDiff - timerDelay)
                let adjustedContent = Content(
                    command: event.shot.content.command,
                    hitArea: event.shot.content.hitArea,
                    hitPosition: event.shot.content.hitPosition,
                    rotationAngle: event.shot.content.rotationAngle,
                    targetType: event.shot.content.targetType,
                    timeDiff: adjustedTimeDiff,
                    device: event.shot.content.device
                )
                return ShotData(
                    target: event.shot.target,
                    content: adjustedContent,
                    type: event.shot.type,
                    action: event.shot.action,
                    device: event.shot.device
                )
            } else {
                return event.shot
            }
        }

        let numShots = adjustedShots.count
        let fastest = adjustedShots.map { $0.content.timeDiff }.min() ?? 0.0
        let firstShot = adjustedShots.first?.content.timeDiff ?? 0.0
        let totalScore = adjustedShots.reduce(0) { $0 + scoreForHitArea($1.content.hitArea) }
        let summary = DrillRepeatSummary(
            repeatIndex: repeatIndex,
            totalTime: totalTime,
            numShots: numShots,
            firstShot: firstShot,
            fastest: fastest,
            score: totalScore,
            shots: adjustedShots
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
        case "CircleArea": return 5 //Paddle
        case "PopperZone": return 5 //Popper
        default: return 0
        }
    }

    private struct ShotEvent {
        let shot: ShotData
        let receivedAt: Date
    }
}
