import Foundation
import CoreData

class DrillExecutionManager {
    private let bleManager: BLEManager
    private let drillSetup: DrillSetup
    private let expectedDevices: [String]
    private let onComplete: ([DrillRepeatSummary]) -> Void
    private let onFailure: () -> Void
    private let onReadinessUpdate: (Int, Int) -> Void
    private let onReadinessTimeout: ([String]) -> Void
    private let onRepeatComplete: ((Int, Int) -> Void)?  // Callback when a repeat completes
    private var randomDelay: TimeInterval
    private var totalRepeats: Int
    
    private var currentRepeat = 0
    private var ackedDevices = Set<String>()
    private var ackTimeoutTimer: Timer?
    private var waitingForAcks = false
    private var repeatSummaries: [DrillRepeatSummary] = []
    private var currentRepeatShots: [ShotEvent] = []
    private var currentRepeatStartTime: Date?
    private var startCommandTime: Date?
    private var beepTime: Date?
    private var endCommandTime: Date?
    private var shotObserver: NSObjectProtocol?
    private let firstShotMockValue: TimeInterval = 1.0
    private var deviceDelayTimes: [String: String] = [:]
    private var globalDelayTime: String?
    private var firstTargetName: String?
    private var lastTargetName: String?
    private var isWaitingForEnd = false
    private var pauseTimer: Timer?
    private var gracePeriodTimer: Timer?
    private var isStopped = false
    private var drillDuration: TimeInterval?
    private var isReadinessCheckOnly = false
    
    init(bleManager: BLEManager, drillSetup: DrillSetup, expectedDevices: [String], randomDelay: TimeInterval = 0, totalRepeats: Int = 1, onComplete: @escaping ([DrillRepeatSummary]) -> Void, onFailure: @escaping () -> Void, onReadinessUpdate: @escaping (Int, Int) -> Void = { _, _ in }, onReadinessTimeout: @escaping ([String]) -> Void = { _ in }, onRepeatComplete: ((Int, Int) -> Void)? = nil) {
        self.bleManager = bleManager
        self.drillSetup = drillSetup
        self.expectedDevices = expectedDevices
        self.randomDelay = randomDelay
        self.totalRepeats = totalRepeats
        self.onComplete = onComplete
        self.onFailure = onFailure
        self.onReadinessUpdate = onReadinessUpdate
        self.onReadinessTimeout = onReadinessTimeout
        self.onRepeatComplete = onRepeatComplete

        startObservingShots()
    }
    
    deinit {
        stopObservingShots()
        ackTimeoutTimer?.invalidate()
        pauseTimer?.invalidate()
        gracePeriodTimer?.invalidate()
    }

    var summaries: [DrillRepeatSummary] {
        repeatSummaries
    }
    
    /// Call this when all repeats are completed to finalize the drill
    func completeDrill() {
        stopObservingShots()
        onComplete(repeatSummaries)
    }

    func performReadinessCheck() {
        isReadinessCheckOnly = true
        sendReadyCommands()
        beginWaitingForAcks()
    }
    
    func startExecution() {
        isStopped = false
        // Assumes currentRepeat is already set by UI before calling
        // Ready command was already sent in performReadinessCheck()
        // Send start command and begin waiting for shots
        sendStartCommands()
        beginWaitingForEnd()
    }
    
    func setCurrentRepeat(_ repeat: Int) {
        self.currentRepeat = `repeat`
    }
    
    func setRandomDelay(_ delay: TimeInterval) {
        self.randomDelay = delay
    }
    
    func setBeepTime(_ time: Date) {
        self.beepTime = time
    }
    
    func stopExecution() {
        isStopped = true
        ackTimeoutTimer?.invalidate()
        pauseTimer?.invalidate()
        gracePeriodTimer?.invalidate()
        stopObservingShots()
    }
    
    func manualStopRepeat() {
        isStopped = true
        ackTimeoutTimer?.invalidate()
        pauseTimer?.invalidate()
        isWaitingForEnd = false
        endCommandTime = Date()
        sendEndCommand()
        
        // Start grace period to collect in-flight shots before finalizing
        // Keep shot observer active during this period
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.completeManualStopRepeat()
        }
    }
    
    private func completeManualStopRepeat() {
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
        // DO NOT stop observing shots here - let them continue arriving during grace period
        // stopObservingShots() will be called when stopping execution or leaving the view
        let repeatIndex = currentRepeat
        finalizeRepeat(repeatIndex: repeatIndex)
        // NOTE: Do NOT call onComplete here - UI manages the next repeat or drill completion
    }
    
    private func sendReadyCommands() {
        guard bleManager.isConnected else {
            print("BLE not connected")
            onFailure()
            return
        }
        
        // Clear state from previous repeat before starting new readiness check
        currentRepeatStartTime = nil
        beepTime = nil
        
        guard let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> else {
            onFailure()
            return
        }
        let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
        
        for (index, target) in sortedTargets.enumerated() {
            do {
                let delayValue = randomDelay > 0 ? randomDelay : drillSetup.delay
                let roundedDelay = Double(String(format: "%.2f", delayValue)) ?? delayValue
                let content: [String: Any] = [
                    "command": "ready",
                    "delay": roundedDelay,
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
        let nonResponsiveTargets = expectedDevices.filter { !ackedDevices.contains($0) }
        print("Non-responsive targets: \(nonResponsiveTargets)")
        DispatchQueue.main.async {
            self.onReadinessTimeout(nonResponsiveTargets)
        }
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
                    
                    // Update readiness status
                    DispatchQueue.main.async {
                        self.onReadinessUpdate(self.ackedDevices.count, self.expectedDevices.count)
                    }
                    
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
            if isReadinessCheckOnly {
                // Just completed readiness check, don't proceed to execution
                isReadinessCheckOnly = false
                return
            }
            
            // Readiness check passed, UI will call startExecution() when ready
            print("Ready check completed, waiting for UI to start execution")
        } else {
            // Ack timeout - for readiness check, this is handled by the timeout callback
            if !isReadinessCheckOnly {
                stopObservingShots()
                onFailure()
            }
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
        
        // Notify UI that repeat is complete, UI will handle next repeat logic
        print("Completed repeat \(repeatIndex)")
        // NOTE: onComplete is NOT called here - UI will call completeDrill() when all repeats are done
    }

    private func prepareForRepeatStart() {
        // DO NOT clear currentRepeatShots here - it's cleared in sendReadyCommands() at the start of readiness check
        // This ensures grace period shots from previous repeat are not lost
        currentRepeatStartTime = Date()
        startCommandTime = nil
        // DO NOT reset beepTime here - it's set by UI via setBeepTime() before startExecution()
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
            // DO NOT clear currentRepeatStartTime here - let grace period shots be collected
            // It will be cleared in sendReadyCommands() when next repeat starts
            currentRepeatShots.removeAll()
            return
        }

        // Calculate total time: from BEEP to last shot
        var totalTime: TimeInterval = 0.0
        let timerDelay: TimeInterval = self.randomDelay > 0 ? self.randomDelay : TimeInterval(drillSetup.delay)
        
        if let startTime = beepTime, let lastShotTime = sortedShots.last?.receivedAt {
            totalTime = max(0.0, lastShotTime.timeIntervalSince(startTime))
            print("Total time calculation - beep: \(startTime), last shot: \(lastShotTime), total: \(totalTime)")
        } else {
            print("Warning: No beepTime or shots received for repeat \(repeatIndex), using fallback calculation")
            // Fallback to old method if drill_duration available
            if let duration = drillDuration {
                totalTime = max(0.0, duration - timerDelay)
                print("Fallback total time - drill_duration: \(duration), delay_time: \(timerDelay), total: \(totalTime)")
            } else {
                // Last resort: use shot-based calculation
                var timeSumPerTarget: [String: TimeInterval] = [:]
                for shot in sortedShots {
                    let device = shot.shot.device ?? shot.shot.target ?? "unknown"
                    let currentSum = timeSumPerTarget[device] ?? 0.0
                    timeSumPerTarget[device] = currentSum + shot.shot.content.timeDiff
                }
                totalTime = timeSumPerTarget.values.max() ?? 0.0
            }
        }

        // Recalculate timeDiff: first shot relative to beepTime, rest relative to previous shot's timestamp
        let adjustedShots = sortedShots.enumerated().map { (index, event) -> ShotData in
            let newTimeDiff: TimeInterval
            if let beepTime = beepTime {
                if index == 0 {
                    newTimeDiff = event.receivedAt.timeIntervalSince(beepTime)
                } else {
                    let previousReceivedAt = sortedShots[index - 1].receivedAt
                    newTimeDiff = event.receivedAt.timeIntervalSince(previousReceivedAt)
                }
            } else {
                // Fallback to old adjustment
                if event.shot.device != firstTargetName {
                    newTimeDiff = max(0, event.shot.content.timeDiff - timerDelay)
                } else {
                    newTimeDiff = event.shot.content.timeDiff
                }
            }
            let adjustedContent = Content(
                command: event.shot.content.command,
                hitArea: event.shot.content.hitArea,
                hitPosition: event.shot.content.hitPosition,
                rotationAngle: event.shot.content.rotationAngle,
                targetType: event.shot.content.targetType,
                timeDiff: newTimeDiff,
                device: event.shot.content.device,
                targetPos: event.shot.content.targetPos
            )
            return ShotData(
                target: event.shot.target,
                content: adjustedContent,
                type: event.shot.type,
                action: event.shot.action,
                device: event.shot.device
            )
        }

        let numShots = adjustedShots.count
        let fastest = adjustedShots.map { $0.content.timeDiff }.min() ?? 0.0
        let firstShot = adjustedShots.first?.content.timeDiff ?? 0.0
        
        // Group shots by target/device and keep only the best 2 per target
        // Exception: shots in no-shoot zones (whitezone, blackzone) always count as they deduct score
        var shotsByTarget: [String: [ShotData]] = [:]
        for shot in adjustedShots {
            let device = shot.device ?? shot.target ?? "unknown"
            if shotsByTarget[device] == nil {
                shotsByTarget[device] = []
            }
            shotsByTarget[device]?.append(shot)
        }
        
        // Keep best 2 shots per target, but always include no-shoot zone hits
        var bestShotsPerTarget: [ShotData] = []
        for (_, shots) in shotsByTarget {
            let noShootZoneShots = shots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespaces).lowercased()
                return trimmed == "whitezone" || trimmed == "blackzone"
            }
            
            let otherShots = shots.filter { shot in
                let trimmed = shot.content.hitArea.trimmingCharacters(in: .whitespaces).lowercased()
                return trimmed != "whitezone" && trimmed != "blackzone"
            }
            
            // Sort other shots by score (descending) and keep best 2
            let sortedOtherShots = otherShots.sorted {
                scoreForHitArea($0.content.hitArea) > scoreForHitArea($1.content.hitArea)
            }
            let bestOtherShots = Array(sortedOtherShots.prefix(2))
            
            // Always include no-shoot zone shots plus best 2 other shots
            bestShotsPerTarget.append(contentsOf: noShootZoneShots)
            bestShotsPerTarget.append(contentsOf: bestOtherShots)
        }
        
        var totalScore = bestShotsPerTarget.reduce(0) { $0 + scoreForHitArea($1.content.hitArea) }
        
        // Auto re-evaluate score: deduct 10 points for each missed target
        let missedTargetCount = calculateMissedTargets(shots: adjustedShots)
        let missedTargetPenalty = missedTargetCount * 10
        totalScore -= missedTargetPenalty
        
        if missedTargetCount > 0 {
            print("Repeat \(repeatIndex): \(missedTargetCount) target(s) missed, penalty: -\(missedTargetPenalty) points")
        }
        
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

        // Clear shots after processing, but DO NOT clear currentRepeatStartTime yet
        // Grace period is still active and may have more shots arriving
        // currentRepeatStartTime will be cleared in sendReadyCommands() when next repeat starts
        currentRepeatShots.removeAll()
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
            
            // Filter shots by repeat number: only accept shots for the current repeat
            if let shotRepeatNumber = shot.content.`repeat`, shotRepeatNumber != currentRepeat {
                print("Ignoring shot from repeat \(shotRepeatNumber), currently in repeat \(currentRepeat)")
                return
            }
            
            let event = ShotEvent(shot: shot, receivedAt: Date())
            currentRepeatShots.append(event)
            
            print("Shot notification count: \(currentRepeatShots.count)")
        } catch {
            print("Failed to process shot notification: \(error)")
        }
    }

    private func scoreForHitArea(_ hitArea: String) -> Int {
        let trimmed = hitArea.trimmingCharacters(in: .whitespaces).lowercased()
        
        switch trimmed {
        case "azone":
            return 5
        case "czone":
            return 3
        case "dzone":
            return 2
        case "miss":
            return 0
        case "whitezone":
            return -10
        case "blackzone":
            return -10
        case "circlearea": // Paddle
            return 5
        case "popperzone": // Popper
            return 5
        default:
            return 0
        }
    }
    
    /// Calculate the number of missed targets in a drill repeat
    /// A target is considered missed if no shots were received from it
    private func calculateMissedTargets(shots: [ShotData]) -> Int {
        guard let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> else {
            return 0
        }
        
        let expectedTargets = Set(targetsSet.map { $0.targetName ?? "" }.filter { !$0.isEmpty })
        let shotsDevices = Set(shots.compactMap { $0.device ?? $0.target })
        
        let missedTargets = expectedTargets.subtracting(shotsDevices)
        return missedTargets.count
    }

    private struct ShotEvent {
        let shot: ShotData
        let receivedAt: Date
    }
}
