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
    private let gracePeriodDuration: TimeInterval = 5.0
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
        // Send home command first to reset device UI to main menu
        sendHomeCommand()
        // Delay readiness check to allow device to process home command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendReadyCommands()
            self?.beginWaitingForAcks()
        }
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
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: self.gracePeriodDuration, repeats: false) { [weak self] _ in
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
    
    private func sendHomeCommand() {
        guard bleManager.isConnected else {
            print("BLE home command failed - not connected")
            return // Best-effort approach: proceed even if home command fails
        }

        do {
            // Send homepage directive
            let homeMessage: [String: Any] = [
                "action": "remote_control",
                "directive": "homepage"
            ]
            let homeData = try JSONSerialization.data(withJSONObject: homeMessage, options: [])
            if let homeString = String(data: homeData, encoding: .utf8) {
                print("Sending home command to reset device to main menu")
                bleManager.writeJSON(homeString)
            }
            
            // Send back directive after 0.5s delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                do {
                    let backMessage: [String: Any] = [
                        "action": "remote_control",
                        "directive": "back"
                    ]
                    let backData = try JSONSerialization.data(withJSONObject: backMessage, options: [])
                    if let backString = String(data: backData, encoding: .utf8) {
                        print("Sending back command to ensure menu state")
                        self?.bleManager.writeJSON(backString)
                    }
                } catch {
                    print("Failed to send back command: \(error)")
                }
            }
        } catch {
            print("Failed to send home command: \(error)")
            // Best-effort: don't fail the drill, proceed with readiness check
        }
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
                let content: [String: Any]
                let allTargetTypes = target.parseTargetTypes()
                let primaryTargetType = allTargetTypes.first ?? "ipsc"
                print("[DrillExecutionManager] sendReadyCommands() - target: \(target.targetName ?? ""), targetTypes: \(allTargetTypes), primary: \(primaryTargetType)")
                
                // For backward compatibility: send single type as string, multiple types as array
                let targetTypeValue: Any = allTargetTypes.count == 1 ? primaryTargetType : allTargetTypes
                
                if primaryTargetType == "disguised_enemy" {
                    content = [
                        "command": "ready",
                        "mode": "cqb",
                        "targetType": targetTypeValue  // String if single type, array if multiple
                    ]
                } else {
                    let delayValue = randomDelay > 0 ? randomDelay : drillSetup.delay
                    let roundedDelay = Double(String(format: "%.2f", delayValue)) ?? delayValue
                    content = [
                        "command": "ready",
                        "delay": roundedDelay,
                        "targetType": targetTypeValue,  // String if single type, array if multiple
                        "timeout": 1200,
                        "countedShots": target.countedShots,
                        "repeat": currentRepeat,
                        "isFirst": index == 0,
                        "isLast": index == sortedTargets.count - 1,
                        "mode": drillSetup.mode ?? "ipsc"
                    ]
                }
                let message: [String: Any] = [
                    "action": "netlink_forward",
                    "dest": target.targetName ?? "",
                    "content": content
                ]
                let messageData = try JSONSerialization.data(withJSONObject: message, options: [])
                let messageString = String(data: messageData, encoding: .utf8)!
                print("Sending ready message for target \(target.targetName ?? ""), targetType: \(targetTypeValue), length: \(messageData.count)")
                bleManager.writeJSON(messageString)
                
                // Send animation_config if CQB mode and action is set
                if drillSetup.mode == "cqb", let action = target.action, !action.isEmpty {
                    let animationContent: [String: Any] = [
                        "command": "animation_config",
                        "action": action,
                        "duration": target.duration
                    ]
                    let animationMessage: [String: Any] = [
                        "action": "netlink_forward",
                        "dest": target.targetName ?? "",
                        "content": animationContent
                    ]
                    let animationData = try JSONSerialization.data(withJSONObject: animationMessage, options: [])
                    let animationString = String(data: animationData, encoding: .utf8)!
                    print("Sending animation_config for target \(target.targetName ?? "")")
                    bleManager.writeJSON(animationString)
                }
                
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
                            "target_type": primaryTargetType,
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
                                "target_type": primaryTargetType,
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

        // Handle 'disguised_enemy' targets separately
        let targets = drillSetup.targets as? Set<DrillTargetsConfig> ?? []
        for target in targets where target.primaryTargetType() == "disguised_enemy" {
            let content: [String: Any] = [
                "command": "start",
                "mode": "cqb",
                "targetType": "disguised_enemy",
                "timeout": target.timeout,
                "delay": drillSetup.delay,
                "repeat": currentRepeat
            ]
            let message: [String: Any] = [
                "action": "netlink_forward",
                "dest": target.targetName ?? "",
                "content": content
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: message, options: [])
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Sending start command to disguised_enemy \(target.targetName ?? ""): \(jsonString)")
                    bleManager.writeJSON(jsonString)
                }
            } catch {
                print("Failed to serialize start command for disguised_enemy: \(error)")
            }
        }

        var content: [String: Any] = ["command": "start", "repeat": currentRepeat]
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
            print("[DrillExecutionManager] beginWaitingForEnd() - BLE not connected")
            onFailure()
            return
        }

        print("[DrillExecutionManager] beginWaitingForEnd() - starting to listen for shots in repeat \(currentRepeat)")

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
            print("[DrillExecutionManager] No expected devices, completing repeat immediately")
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
        
        print("[DrillExecutionManager] prepareForRepeatStart() - ready for repeat \(currentRepeat)")
        
        // Set first target name for later use in finalizeRepeat
        if let targetsSet = drillSetup.targets as? Set<DrillTargetsConfig> {
            let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
            firstTargetName = sortedTargets.first?.targetName
        }
    }

    private func finalizeRepeat(repeatIndex: Int) {
        guard currentRepeatStartTime != nil else {
            print("[DrillExecutionManager] No start time for repeat \(repeatIndex), skipping summary")
            return
        }

        // Sort shots by time_diff from the shot data message (not by receivedAt timestamp)
        // time_diff = timing of shot on target device - timing when repeat starts
        let sortedShots = currentRepeatShots.sorted { $0.shot.content.timeDiff < $1.shot.content.timeDiff }
        
        print("[DrillExecutionManager] finalizeRepeat(\(repeatIndex)) - currentRepeatShots count: \(currentRepeatShots.count), sorted: \(sortedShots.count)")
        
        // Validate: if no shots received at all, invalidate this repeat
        if sortedShots.isEmpty {
            print("[DrillExecutionManager] ⚠️ No shots received from any target for repeat \(repeatIndex), invalidating repeat")
            print("[DrillExecutionManager] - currentRepeat: \(currentRepeat)")
            print("[DrillExecutionManager] - isWaitingForEnd: \(isWaitingForEnd)")
            print("[DrillExecutionManager] - BeepTime: \(beepTime?.description ?? "nil")")
            // DO NOT clear currentRepeatStartTime here - let grace period shots be collected
            // It will be cleared in sendReadyCommands() when next repeat starts
            currentRepeatShots.removeAll()
            return
        }
        
        print("[DrillExecutionManager] ✅ finalizeRepeat(\(repeatIndex)) - found \(sortedShots.count) shots")

        // Calculate total time: use time_diff of last shot (original value from shot data)
        var totalTime: TimeInterval = 0.0
        
        if let lastShotTimeDiff = sortedShots.last?.shot.content.timeDiff {
            totalTime = lastShotTimeDiff
            print("Total time calculation - using last shot time_diff: \(totalTime)")
        } else {
            print("Warning: No shots with time_diff for repeat \(repeatIndex), using fallback calculation")
            // Fallback to old method if drill_duration available
            if let duration = drillDuration {
                let timerDelay: TimeInterval = self.randomDelay > 0 ? self.randomDelay : TimeInterval(drillSetup.delay)
                totalTime = max(0.0, duration - timerDelay)
                print("Fallback total time - drill_duration: \(duration), delay_time: \(timerDelay), total: \(totalTime)")
            } else {
                totalTime = 0.0
                print("No valid time calculation available for repeat \(repeatIndex), setting total time to 0.0")
            }
        }

        // Use original time_diff from shot data message
        // time_diff is already: timing of shot on target device - timing when repeat starts
        // 1st shot keeps original time_diff, subsequent shots show difference from previous shot
        let adjustedShots = sortedShots.enumerated().map { (index, event) -> ShotData in
            let newTimeDiff: TimeInterval
            if index == 0 {
                // First shot keeps original time_diff
                newTimeDiff = event.shot.content.timeDiff
            } else {
                // Subsequent shots: current shot's time_diff - previous shot's time_diff
                newTimeDiff = event.shot.content.timeDiff - sortedShots[index - 1].shot.content.timeDiff
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
        
        // Calculate total score using centralized ScoringUtility
        let totalScore = Int(ScoringUtility.calculateTotalScore(shots: adjustedShots, drillSetup: drillSetup))
        
        // Calculate CQB validation if this is a CQB drill
        var cqbResults: [CQBShotResult]? = nil
        var cqbPassed: Bool? = nil
        
        if drillSetup.mode?.lowercased() == "cqb" {
            // Get all target devices from the drill setup
            let targetDevices = (drillSetup.targets?.allObjects as? [DrillTargetsConfig])?.compactMap { config -> String? in
                guard let targetName = config.targetName, !targetName.isEmpty else { return nil }
                return targetName
            } ?? ([] as [String])
            
            let cqbDrillResult = CQBScoringUtility.generateCQBDrillResult(
                shots: adjustedShots,
                drillDuration: totalTime,
                targetDevices: targetDevices
            )
            
            cqbResults = cqbDrillResult.shotResults
            cqbPassed = cqbDrillResult.drilPassed
        }
        
        let summary = DrillRepeatSummary(
            repeatIndex: repeatIndex,
            totalTime: totalTime,
            numShots: numShots,
            firstShot: firstShot,
            fastest: fastest,
            score: totalScore,
            shots: adjustedShots,
            drillResultId: nil,
            adjustedHitZones: nil,
            cqbResults: cqbResults,
            cqbPassed: cqbPassed
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
        print("[DrillExecutionManager] startObservingShots() - registering .bleShotReceived observer")
        shotObserver = NotificationCenter.default.addObserver(
            forName: .bleShotReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleShotNotification(notification)
        }
        print("[DrillExecutionManager] Shot observer registered")
    }

    private func stopObservingShots() {
        if let observer = shotObserver {
            NotificationCenter.default.removeObserver(observer)
            shotObserver = nil
        }
    }

    private func handleShotNotification(_ notification: Notification) {
        guard currentRepeatStartTime != nil else {
            print("[DrillExecutionManager] Shot received but no currentRepeatStartTime set")
            return
        }
        
        guard let shotDict = notification.userInfo?["shot_data"] as? [String: Any] else {
            let keyList = notification.userInfo?.keys.map { String(describing: $0) }.joined(separator: ", ") ?? "none"
            print("[DrillExecutionManager] No shot_data in notification userInfo. Available keys: \(keyList)")
            return
        }

        print("[DrillExecutionManager] Received shot data: \(shotDict)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: shotDict, options: [])
            print("[DrillExecutionManager] JSON serialized successfully")
            
            let shot = try JSONDecoder().decode(ShotData.self, from: jsonData)
            print("[DrillExecutionManager] Shot decoded successfully - cmd: \(shot.content.command), ha: \(shot.content.hitArea), device: \(shot.device ?? "unknown")")
            
            // Filter shots by repeat number: only accept shots for the current repeat
            if let shotRepeatNumber = shot.content.`repeat` {
                if shotRepeatNumber != currentRepeat {
                    print("[DrillExecutionManager] Ignoring shot from repeat \(shotRepeatNumber), currently in repeat \(currentRepeat)")
                    return
                }
                print("[DrillExecutionManager] Shot repeat \(shotRepeatNumber) matches current repeat \(currentRepeat)")
            } else {
                print("[DrillExecutionManager] Shot has no repeat number, accepting for current repeat \(currentRepeat)")
            }
            
            // Check for duplicate shots (same device, same content)
            let isDuplicate = currentRepeatShots.contains { $0.shot == shot }
            if isDuplicate {
                print("[DrillExecutionManager] Ignoring duplicate shot from device \(shot.device ?? "unknown") at time \(shot.content.timeDiff)")
                return
            }
            
            let event = ShotEvent(shot: shot, receivedAt: Date())
            currentRepeatShots.append(event)
            
            print("[DrillExecutionManager] Shot accepted! Total shots in repeat \(currentRepeat): \(currentRepeatShots.count)")
        } catch {
            print("[DrillExecutionManager] Failed to decode shot: \(error)")
            print("[DrillExecutionManager] Error details: \(String(describing: error))")
        }
    }


    
    /// Calculate the number of missed targets in a drill repeat
    /// A target is considered missed if no shots were received from it
    private func calculateMissedTargets(shots: [ShotData]) -> Int {
        return ScoringUtility.calculateMissedTargets(shots: shots, drillSetup: drillSetup)
    }

    private struct ShotEvent {
        let shot: ShotData
        let receivedAt: Date
    }
}
