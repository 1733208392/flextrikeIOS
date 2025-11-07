import SwiftUI
import CoreData

// Codable structs for JSON decoding
struct ShotData: Codable {
    let target: String?
    let content: Content
    let type: String?
    let action: String?
    let device: String?
}

struct Content: Codable {
    let command: String
    let hitArea: String
    let hitPosition: HitPosition
    let rotationAngle: Int
    let targetType: String
    let timeDiff: Double
    let device: String?

    enum CodingKeys: String, CodingKey {
        case command
        case hitArea = "hit_area"
        case hitPosition = "hit_position"
        case rotationAngle = "rotation_angle"
        case targetType = "target_type"
        case timeDiff = "time_diff"
        case device
    }

    init(command: String, hitArea: String, hitPosition: HitPosition, rotationAngle: Int, targetType: String, timeDiff: Double, device: String? = nil) {
        self.command = command
        self.hitArea = hitArea
        self.hitPosition = hitPosition
        self.rotationAngle = rotationAngle
        self.targetType = targetType
        self.timeDiff = timeDiff
        self.device = device
    }
}

struct HitPosition: Codable {
    let x: Double
    let y: Double
}

private struct TargetDisplay: Identifiable, Hashable {
    let id: String
    let config: DrillTargetsConfig
    let icon: String
    let deviceName: String?

    func matches(_ shot: ShotData) -> Bool {
        if let deviceName = deviceName {
            let shotDevice = shot.device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return shotDevice == deviceName
        } else {
            let shotIcon = shot.content.targetType.isEmpty ? "hostage" : shot.content.targetType
            return shotIcon == icon
        }
    }
}

private struct TargetDisplayView: View {
    let targetDisplays: [TargetDisplay]
    @Binding var selectedTargetKey: String
    let shots: [ShotData]
    let visibleShotIndices: Set<Int>
    let selectedShotIndex: Int?
    let pulsingShotIndex: Int?
    let pulseScale: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    
    var body: some View {
        TabView(selection: $selectedTargetKey) {
            ForEach(targetDisplays) { display in
                ZStack {
                    // White rectangular frame representing target device with gray fill
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: frameWidth, height: frameHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 12)
                        )
                    
                    // Target icon inside the frame
                    Image("\(display.icon).live.target")
                        .resizable()
                        .scaledToFit()
                        .frame(width: frameWidth - 20, height: frameHeight - 20)
                        .overlay(alignment: .topTrailing) {
                            if let deviceName = display.deviceName {
                                Text(deviceName)
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(8)
                                    .padding(10)
                            }
                        }
                    
                    // Shot position markers (only show visible shots during replay)
                    ForEach(shots.indices, id: \.self) { index in
                        let shot = shots[index]
                        if display.matches(shot) && visibleShotIndices.contains(index) {
                            let x = shot.content.hitPosition.x
                            let y = shot.content.hitPosition.y
                            // Transform coordinates from 720×1280 source to frame dimensions
                            let transformedX = (x / 720.0) * frameWidth
                            let transformedY = (y / 1280.0) * frameHeight
                            
                            ZStack {
                                Image("bullet_hole2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                
                                // Highlight selected shot
                                if selectedShotIndex == index {
                                    Circle()
                                        .stroke(Color.yellow, lineWidth: 3)
                                        .frame(width: 30, height: 30)
                                        .scaleEffect(pulsingShotIndex == index ? pulseScale : 1.0)
                                }
                            }
                            .position(x: transformedX, y: transformedY)
                        }
                    }
                }
                .frame(width: frameWidth, height: frameHeight)
                .tag(display.id)
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: targetDisplays.count > 1 ? .automatic : .never))
                    .onChange(of: shots.count) { _ in
            // This would need to be passed as a closure or handled differently
            // For now, we'll handle this in the parent view
        }
    }
}

struct DrillResultView: View {
    let drillSetup: DrillSetup
    
    // Array to store received shots
    @State private var shots: [ShotData] = []
    
    // Timer for drill duration
    @State private var drillTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    
    // Drill status for title
    @State private var drillStatus: String = "In Progress"
    @State private var isLiveDrill: Bool
    
    @State private var selectedTargetKey: String = ""
    @State private var selectedShotIndex: Int? = nil
    @State private var currentProgress: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var dots: String = ""
    @State private var dotsTimer: Timer?
    @State private var replayTimer: Timer?
    @State private var visibleShotIndices: Set<Int> = []
    @State private var pulsingShotIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    
    private var shotTimelineData: [(index: Int, time: Double, diff: Double)] {
        var cumulativeTime = 0.0
        return shots.enumerated().map { (index, shot) in
            let interval = shot.content.timeDiff
            cumulativeTime += interval
            return (index, cumulativeTime, interval)
        }
    }

    private var currentTargetTimelineData: [(index: Int, time: Double, diff: Double)] {
        guard let display = targetDisplays.first(where: { $0.id == selectedTargetKey }) else { return [] }
        let filteredShots = shots.enumerated().filter { display.matches($0.element) }
        var cumulativeTime = 0.0
        return filteredShots.map { enumeratedShot in
            let interval = enumeratedShot.element.content.timeDiff
            cumulativeTime += interval
            return (enumeratedShot.offset, cumulativeTime, interval)
        }
    }

    private func absoluteTime(for shotIndex: Int) -> Double {
        guard shots.indices.contains(shotIndex) else { return 0.0 }
        let sortedShots = shots.prefix(shotIndex + 1)
        return sortedShots.reduce(0) { $0 + $1.content.timeDiff }
    }

    private var targetDisplays: [TargetDisplay] {
        let sortedTargets = drillSetup.sortedTargets
        
        return sortedTargets.map { target in
            let iconName = target.targetType ?? ""
            let resolvedIcon = iconName.isEmpty ? "hostage" : iconName
            let id = target.id?.uuidString ?? UUID().uuidString
            return TargetDisplay(id: id, config: target, icon: resolvedIcon, deviceName: target.targetName)
        }
    }
    
    var totalDuration: Double {
        guard let targets = drillSetup.targets as? Set<DrillTargetsConfig> else { return 10.0 }
        return targets.map { $0.timeout }.max() ?? 10.0
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
        _isLiveDrill = State(initialValue: true)
        if let firstTarget = drillSetup.sortedTargets.first {
            _selectedTargetKey = State(initialValue: firstTarget.id?.uuidString ?? UUID().uuidString)
        } else {
            _selectedTargetKey = State(initialValue: UUID().uuidString)
        }
    }
    
    init(drillSetup: DrillSetup, shots: [ShotData]) {
        self.drillSetup = drillSetup
        _isLiveDrill = State(initialValue: false)
        _shots = State(initialValue: shots)
        _drillStatus = State(initialValue: "Completed")
        if let firstTarget = drillSetup.sortedTargets.first {
            _selectedTargetKey = State(initialValue: firstTarget.id?.uuidString ?? UUID().uuidString)
        } else {
            _selectedTargetKey = State(initialValue: UUID().uuidString)
        }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let screenHeight = geometry.size.height
                
                // Calculate frame dimensions (9:16 aspect ratio, 2/3 of page height)
                let frameHeight = screenHeight * 2 / 3
                let frameWidth = frameHeight * 9 / 16
                
                VStack {
                    Spacer()
                    
                    TargetDisplayView(
                        targetDisplays: targetDisplays,
                        selectedTargetKey: $selectedTargetKey,
                        shots: shots,
                        visibleShotIndices: visibleShotIndices,
                        selectedShotIndex: selectedShotIndex,
                        pulsingShotIndex: pulsingShotIndex,
                        pulseScale: pulseScale,
                        frameWidth: frameWidth,
                        frameHeight: frameHeight
                    )
                    .onChange(of: shots.count) { _ in
                        ensureSelectedTargetIsValid()
                    }
                    
                    // Progress bar with shot tick marks
                    HStack(alignment: .center, spacing: 12) {
                        ShotTimelineView(
                            shots: currentTargetTimelineData,
                            totalDuration: totalDuration,
                            currentProgress: currentProgress,
                            isEnabled: drillStatus != "In Progress",
                            onProgressChange: { newTime in
                                seek(to: newTime, highlightIndex: nil, shouldPulse: false, restrictToSelectedTarget: true)
                            },
                            onShotFocus: { shotIndex in
                                focusOnShot(shotIndex)
                            }
                        )
                        .frame(height: 28)
                        
                        Text(String(format: NSLocalizedString("progress_time", comment: "Progress time display"), currentProgress, totalDuration))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    
                    // Video player controls
                    HStack(spacing: 40) {
                        Button(action: {
                            // Previous shot
                            previousShot()
                        }) {
                            Image(systemName: "backward.end")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                        .disabled(drillStatus == "In Progress")
                        
                        Button(action: {
                            // Play/Pause
                            if drillStatus == "In Progress" {
                                return // Don't allow replay during drill
                            }
                            isPlaying.toggle()
                            if isPlaying {
                                startReplay()
                            } else {
                                pauseReplay()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                        .disabled(drillStatus == "In Progress")
                        
                        Button(action: {
                            // Next shot
                            nextShot()
                        }) {
                            Image(systemName: "forward.end")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                        .disabled(drillStatus == "In Progress")
                    }
                    .padding(.vertical, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.edgesIgnoringSafeArea(.all))
            }
            .navigationTitle(NSLocalizedString("drill_replay", comment: "Drill Replay navigation title"))
            .onAppear {
                ensureSelectedTargetIsValid()
                if isLiveDrill {
                    startDrillTimer()
                    setupNotificationObserver()
                    startDotsTimer()
                }
            }
            .onDisappear {
                stopDrillTimer()
                removeNotificationObserver()
                stopDotsTimer()
            }
            
            if isLiveDrill && drillStatus == "In Progress" {
                VStack {
                    Spacer()
                    ZStack {
                        Color.red.opacity(0.7)
                        Text(NSLocalizedString("drill_in_progress", comment: "Drill in progress message") + dots)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .italic()
                    }
                    .frame(height: UIScreen.main.bounds.height / 8)
                    Spacer()
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func seek(to time: Double, highlightIndex: Int?, shouldPulse: Bool, restrictToSelectedTarget: Bool = false) {
        let clampedTime = max(0.0, min(time, totalDuration))
        pauseReplay()
        isPlaying = false
        currentProgress = clampedTime
        updateVisibleShots(upTo: clampedTime)
        
        if let highlightIndex = highlightIndex, shots.indices.contains(highlightIndex) {
            selectedShotIndex = highlightIndex
            updateSelectedTargetForCurrentShot()
            if shouldPulse {
                triggerPulse(on: highlightIndex)
            } else {
                pulsingShotIndex = highlightIndex
                pulseScale = 1.0
            }
        } else if restrictToSelectedTarget, let display = targetDisplays.first(where: { $0.id == selectedTargetKey }) {
            let currentShotIndex = shots.enumerated()
                .filter { display.matches($0.element) && absoluteTime(for: $0.offset) <= clampedTime }
                .max(by: { absoluteTime(for: $0.offset) < absoluteTime(for: $1.offset) })?
                .offset
            selectedShotIndex = currentShotIndex
            pulsingShotIndex = currentShotIndex
            pulseScale = 1.0
        } else {
            updateSelection(for: clampedTime)
            pulsingShotIndex = selectedShotIndex
            pulseScale = 1.0
        }
    }
    
    private func focusOnShot(_ shotIndex: Int) {
        guard shots.indices.contains(shotIndex) else { return }
        let shotTime = absoluteTime(for: shotIndex)
        seek(to: shotTime, highlightIndex: shotIndex, shouldPulse: true)
    }
    
    private func updateVisibleShots(upTo progress: Double) {
        let indices = shots.enumerated()
            .filter { absoluteTime(for: $0.offset) <= progress }
            .map { $0.offset }
        visibleShotIndices = Set(indices)
    }
    
    private func updateSelection(for progress: Double) {
        let currentShotIndex = shots.enumerated()
            .filter { absoluteTime(for: $0.offset) <= progress }
            .max(by: { absoluteTime(for: $0.offset) < absoluteTime(for: $1.offset) })?
            .offset
        selectedShotIndex = currentShotIndex
        updateSelectedTargetForCurrentShot()
    }
    
    private func triggerPulse(on index: Int) {
        guard shots.indices.contains(index) else { return }
        pulsingShotIndex = index
        withAnimation(.easeOut(duration: 0.15)) {
            pulseScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                pulseScale = 1.0
            }
        }
    }

    private func startDotsTimer() {
        dotsTimer?.invalidate()
        dots = ""
        dotsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dots = dots == "..." ? "" : dots + "."
        }
    }

    private func stopDotsTimer() {
        dotsTimer?.invalidate()
        dotsTimer = nil
        dots = ""
    }

    private func startReplay() {
        // Reset to beginning
        currentProgress = 0.0
        visibleShotIndices.removeAll()
        selectedShotIndex = nil
        pulsingShotIndex = nil
        pulseScale = 1.0
        
        // Start replay timer
        replayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentProgress += 0.1
            
            updateVisibleShots(upTo: currentProgress)
            
            // Update selected shot to the current one
            let currentShotIndex = shots.enumerated()
                .filter { absoluteTime(for: $0.offset) <= currentProgress }
                .max(by: { absoluteTime(for: $0.offset) < absoluteTime(for: $1.offset) })?
                .offset
            selectedShotIndex = currentShotIndex
            updateSelectedTargetForCurrentShot()
            pulsingShotIndex = currentShotIndex
            
            // Stop at end of drill
            if currentProgress >= totalDuration {
                pauseReplay()
                currentProgress = totalDuration
                isPlaying = false
            }
        }
    }
    
    private func updateSelectedTargetForCurrentShot() {
        guard let index = selectedShotIndex, shots.indices.contains(index) else { return }
        let shot = shots[index]
        
        // Find matching display for this shot
        if let matchingDisplay = targetDisplays.first(where: { $0.matches(shot) }) {
            selectedTargetKey = matchingDisplay.id
        }
    }

    private func ensureSelectedTargetIsValid() {
        guard !targetDisplays.contains(where: { $0.id == selectedTargetKey }) else { return }
        if let fallback = targetDisplays.first {
            selectedTargetKey = fallback.id
        }
    }
    private func pauseReplay() {
        replayTimer?.invalidate()
        replayTimer = nil
    }
    
    private func previousShot() {
        // Find the previous shot before current progress
        let previousShots = shots.enumerated().filter { absoluteTime(for: $0.offset) < currentProgress }.sorted { absoluteTime(for: $0.offset) > absoluteTime(for: $1.offset) }
        
        if let previousShot = previousShots.first {
            seek(to: absoluteTime(for: previousShot.offset), highlightIndex: previousShot.offset, shouldPulse: true)
        } else {
            // Go to beginning
            seek(to: 0.0, highlightIndex: nil, shouldPulse: false)
        }
    }
    
    private func nextShot() {
        // Find the next shot after current progress
        let nextShots = shots.enumerated().filter { absoluteTime(for: $0.offset) > currentProgress }.sorted { absoluteTime(for: $0.offset) < absoluteTime(for: $1.offset) }
        
        if let nextShot = nextShots.first {
            seek(to: absoluteTime(for: nextShot.offset), highlightIndex: nextShot.offset, shouldPulse: true)
        } else {
            // Go to end
            if let lastShot = shotTimelineData.last {
                seek(to: totalDuration, highlightIndex: lastShot.index, shouldPulse: true)
            } else {
                seek(to: totalDuration, highlightIndex: nil, shouldPulse: false)
            }
        }
    }
    
    private func startDrillTimer() {
        let duration = drillSetup.delay + drillSetup.drillDuration
        timeRemaining = duration
        
        drillTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                timer.invalidate()
                onDrillTimerExpired()
            }
        }
    }
    
    private func stopDrillTimer() {
        drillTimer?.invalidate()
        drillTimer = nil
        pauseReplay() // Also stop replay timer if running
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .bleShotReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let shotDict = notification.userInfo?["shot_data"] as? [String: Any] {
                do {
                    // Convert dict to JSON data for decoding
                    let jsonData = try JSONSerialization.data(withJSONObject: shotDict, options: [])
                    let shotData = try JSONDecoder().decode(ShotData.self, from: jsonData)
                    
                    // Check for duplicates based on hit position
                    let isDuplicate = shots.contains { existingShot in
                        existingShot.content.hitPosition.x == shotData.content.hitPosition.x &&
                        existingShot.content.hitPosition.y == shotData.content.hitPosition.y
                    }
                    
                    if !isDuplicate {
                        shots.append(shotData)
                        print("Added new shot at position: (\(shotData.content.hitPosition.x), \(shotData.content.hitPosition.y))")
                    } else {
                        print("Ignored duplicate shot")
                    }
                } catch {
                    print("Failed to decode shot data: \(error)")
                }
            }
        }
    }
    
    private func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self, name: .bleShotReceived, object: nil)
    }
    
    private func onDrillTimerExpired() {
        drillStatus = "Drill Ended"
        stopDotsTimer()
        
        print("Drill timer expired. Shots received:")
        for (index, shot) in shots.enumerated() {
            print("Shot \(index + 1): (\(shot.content.hitPosition.x), \(shot.content.hitPosition.y))")
        }
        
        // Save drill results to Core Data
        saveDrillResults()
    }
    
    private func saveDrillResults() {
        // Debug: Check if drillSetup.id exists
        guard let drillId = drillSetup.id else {
            print("Failed to save drill results: drillSetup.id is nil")
            return
        }
        
        print("Saving drill results for drill ID: \(drillId)")
        
        // Use the drillSetup's managed object context to ensure consistency
        guard let context = drillSetup.managedObjectContext else {
            print("Failed to save drill results: drillSetup has no managed object context")
            return
        }
        
        let drillResult = DrillResult(context: context)
        drillResult.drillId = drillId
        drillResult.date = Date()
        drillResult.drillSetup = drillSetup
        
        for shotData in shots {
            let shot = Shot(context: context)
            do {
                let jsonData = try JSONEncoder().encode(shotData)
                shot.data = String(data: jsonData, encoding: .utf8)
            } catch {
                print("Failed to encode shot data: \(error)")
                shot.data = nil
            }
            shot.timestamp = Date()
            shot.drillResult = drillResult
        }
        
        do {
            try context.save()
            print("Drill results saved successfully with \(shots.count) shots")
        } catch let error as NSError {
            print("Failed to save drill results: \(error)")
            print("Error domain: \(error.domain)")
            print("Error code: \(error.code)")
            print("Error userInfo: \(error.userInfo)")
            
            // Check for validation errors
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Detailed error: \(detailedError)")
                }
            }
        }
    }
}

#Preview {
    PreviewContent()
}

struct PreviewContent: View {
    var context: NSManagedObjectContext
    let mockDrillSetup: DrillSetup
    let mockShots: [ShotData]
    
    init() {
        let context = PersistenceController.preview.container.viewContext
        let mockDrillSetup = DrillSetup(context: context)
        mockDrillSetup.id = UUID()
        mockDrillSetup.name = "Test Drill"
        mockDrillSetup.desc = "Test drill description"
        mockDrillSetup.delay = 2.0
        
        // Add mock targets
        let mockTarget = DrillTargetsConfig(context: context)
        mockTarget.targetType = "hostage"
        mockTarget.seqNo = 1
        mockTarget.timeout = 10.0
        mockDrillSetup.addToTargets(mockTarget)
        
        // Create mock shots with device info
        let mockShots = [
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "B", hitPosition: HitPosition(x: 395.0, y: 495.0), rotationAngle: 0, targetType: "hostage", timeDiff: 0.18), type: "shot", action: "hit", device: "device1"),
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "B", hitPosition: HitPosition(x: 400.0, y: 500.0), rotationAngle: 0, targetType: "hostage", timeDiff: 0.21), type: "shot", action: "hit", device: "device1"),
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "A", hitPosition: HitPosition(x: 205.0, y: 295.0), rotationAngle: 0, targetType: "hostage", timeDiff: 1.35), type: "shot", action: "hit", device: "device2"),
        ]
        
        self.context = context
        self.mockDrillSetup = mockDrillSetup
        self.mockShots = mockShots
    }
    
    var body: some View {
        DrillResultView(drillSetup: mockDrillSetup, shots: mockShots)
            .environment(\.managedObjectContext, context)
    }
}
