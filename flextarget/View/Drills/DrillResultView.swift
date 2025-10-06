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

    enum CodingKeys: String, CodingKey {
        case command
        case hitArea = "hit_area"
        case hitPosition = "hit_position"
        case rotationAngle = "rotation_angle"
        case targetType = "target_type"
        case timeDiff = "time_diff"
    }
}

struct HitPosition: Codable {
    let x: Double
    let y: Double
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
    
    @State private var selectedIcon: String = "hostage"
    @State private var selectedShotIndex: Int? = nil
    @State private var currentProgress: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var dots: String = ""
    @State private var dotsTimer: Timer?
    @State private var replayTimer: Timer?
    @State private var visibleShotIndices: Set<Int> = []
    @State private var pulsingShotIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    
    private var shotTimelineData: [(index: Int, time: Double)] {
        shots.enumerated()
            .map { ($0.offset, $0.element.content.timeDiff) }
            .sorted { $0.1 < $1.1 }
    }
    
    var totalDuration: Double {
        guard let targets = drillSetup.targets as? Set<DrillTargetsConfig> else { return 10.0 }
        return targets.map { $0.timeout }.max() ?? 10.0
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
        _isLiveDrill = State(initialValue: true)
        // Set selected icon based on first target type if available
        if let targets = drillSetup.targets as? Set<DrillTargetsConfig>,
           let firstTarget = targets.first {
            _selectedIcon = State(initialValue: firstTarget.targetType ?? "")
        }
    }
    
    init(drillSetup: DrillSetup, shots: [ShotData]) {
        self.drillSetup = drillSetup
        _isLiveDrill = State(initialValue: false)
        _shots = State(initialValue: shots)
        _drillStatus = State(initialValue: "Completed")
        // Set selected icon based on first target type if available
        if let targets = drillSetup.targets as? Set<DrillTargetsConfig>,
           let firstTarget = targets.first {
            _selectedIcon = State(initialValue: firstTarget.targetType ?? "")
        }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Calculate frame dimensions (9:16 aspect ratio, 2/3 of page height)
                let frameHeight = screenHeight * 2 / 3
                let frameWidth = frameHeight * 9 / 16
                
                VStack {
                    Spacer()
                    
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
                        Image(selectedIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: frameWidth, height: frameHeight)
                        
                        // Shot position markers (only show visible shots during replay)
                        ForEach(shots.indices, id: \.self) { index in
                            if visibleShotIndices.contains(index) {
                                let shot = shots[index]
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
                    
                    // Progress bar with shot tick marks
                    HStack(alignment: .center, spacing: 12) {
                        ShotTimelineView(
                            shots: shotTimelineData,
                            totalDuration: totalDuration,
                            currentProgress: currentProgress,
                            isEnabled: drillStatus != "In Progress",
                            onProgressChange: { newTime in
                                seek(to: newTime, highlightIndex: nil, shouldPulse: false)
                            },
                            onShotFocus: { shotIndex in
                                focusOnShot(shotIndex)
                            }
                        )
                        .frame(height: 28)
                        
                        Text("\(String(format: "%.1f", currentProgress))/\(String(format: "%.1f", totalDuration))s")
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
            .navigationTitle("Drill Replay")
            .onAppear {
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
                        Text("Drill In Progress" + dots)
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

    private func seek(to time: Double, highlightIndex: Int?, shouldPulse: Bool) {
        let clampedTime = max(0.0, min(time, totalDuration))
        pauseReplay()
        isPlaying = false
        currentProgress = clampedTime
        updateVisibleShots(upTo: clampedTime)
        
        if let highlightIndex = highlightIndex, shots.indices.contains(highlightIndex) {
            selectedShotIndex = highlightIndex
            if shouldPulse {
                triggerPulse(on: highlightIndex)
            } else {
                pulsingShotIndex = highlightIndex
                pulseScale = 1.0
            }
        } else {
            updateSelection(for: clampedTime)
            pulsingShotIndex = selectedShotIndex
            pulseScale = 1.0
        }
    }
    
    private func focusOnShot(_ shotIndex: Int) {
        guard shots.indices.contains(shotIndex) else { return }
        let shotTime = shots[shotIndex].content.timeDiff
        seek(to: shotTime, highlightIndex: shotIndex, shouldPulse: true)
    }
    
    private func updateVisibleShots(upTo progress: Double) {
        let indices = shots.enumerated()
            .filter { $0.element.content.timeDiff <= progress }
            .map { $0.offset }
        visibleShotIndices = Set(indices)
    }
    
    private func updateSelection(for progress: Double) {
        let currentShotIndex = shots.enumerated()
            .filter { $0.element.content.timeDiff <= progress }
            .max(by: { $0.element.content.timeDiff < $1.element.content.timeDiff })?
            .offset
        selectedShotIndex = currentShotIndex
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
                .filter { $0.element.content.timeDiff <= currentProgress }
                .max(by: { $0.element.content.timeDiff < $1.element.content.timeDiff })?
                .offset
            selectedShotIndex = currentShotIndex
            pulsingShotIndex = currentShotIndex
            
            // Stop at end of drill
            if currentProgress >= totalDuration {
                pauseReplay()
                currentProgress = totalDuration
                isPlaying = false
            }
        }
    }
    
    private func pauseReplay() {
        replayTimer?.invalidate()
        replayTimer = nil
    }
    
    private func previousShot() {
        // Find the previous shot before current progress
        let previousShots = shots.enumerated().filter { $0.element.content.timeDiff < currentProgress }.sorted { $0.element.content.timeDiff > $1.element.content.timeDiff }
        
        if let previousShot = previousShots.first {
            seek(to: previousShot.element.content.timeDiff, highlightIndex: previousShot.offset, shouldPulse: true)
        } else {
            // Go to beginning
            seek(to: 0.0, highlightIndex: nil, shouldPulse: false)
        }
    }
    
    private func nextShot() {
        // Find the next shot after current progress
        let nextShots = shots.enumerated().filter { $0.element.content.timeDiff > currentProgress }.sorted { $0.element.content.timeDiff < $1.element.content.timeDiff }
        
        if let nextShot = nextShots.first {
            seek(to: nextShot.element.content.timeDiff, highlightIndex: nextShot.offset, shouldPulse: true)
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
        guard let targets = drillSetup.targets as? Set<DrillTargetsConfig>,
              let firstTarget = targets.first else { return }
        let duration = drillSetup.delay + firstTarget.timeout + 1
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

private struct ShotTimelineView: View {
    let shots: [(index: Int, time: Double)]
    let totalDuration: Double
    let currentProgress: Double
    let isEnabled: Bool
    let onProgressChange: (Double) -> Void
    let onShotFocus: (Int) -> Void
    
    @State private var lastFocusedClusterID: UUID?
    @State private var activeCluster: ShotCluster?
    @State private var tooltipX: CGFloat = 0
    @State private var tooltipToken: UUID?
    
    private var clusterMergeWindow: Double {
        max(0.12, totalDuration * 0.02)
    }
    
    private var highlightThreshold: Double {
        max(clusterMergeWindow * 1.2, totalDuration * 0.03)
    }
    
    private var clusters: [ShotCluster] {
        guard !shots.isEmpty else { return [] }
        var result: [ShotCluster] = []
        var currentMembers: [(index: Int, time: Double)] = [shots[0]]
        for shot in shots.dropFirst() {
            if let lastTime = currentMembers.last?.time, shot.time - lastTime <= clusterMergeWindow {
                currentMembers.append(shot)
            } else {
                result.append(ShotCluster(members: currentMembers))
                currentMembers = [shot]
            }
        }
        result.append(ShotCluster(members: currentMembers))
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let clampedRatio = totalDuration > 0 ? min(max(currentProgress / totalDuration, 0), 1) : 0
            let progressWidth = width * clampedRatio
            
            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: progressWidth, height: 4)
                }
                .frame(height: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .overlay(
                    ZStack {
                        ForEach(clusters) { cluster in
                            let ratio = totalDuration > 0 ? min(max(cluster.representativeTime / totalDuration, 0), 1) : 0
                            let xPosition = width * ratio
                            let isPastCluster = cluster.latestTime <= currentProgress + 0.0001
                            let tickWidth: CGFloat = cluster.count > 1 ? 4 : 2
                            let baseColor: Color = cluster.count > 1 ? Color.orange : Color.white.opacity(0.7)
                            let fillColor: Color = isPastCluster ? (cluster.count > 1 ? Color.orange : Color.yellow) : baseColor
                            Rectangle()
                                .fill(fillColor)
                                .frame(width: tickWidth, height: cluster.count > 1 ? 18 : 12)
                                .frame(width: 28, height: height)
                                .position(x: xPosition, y: height / 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard isEnabled else { return }
                                    onProgressChange(cluster.representativeTime)
                                    onShotFocus(cluster.firstIndex)
                                    updateActiveCluster(cluster, xPosition: xPosition, autoHide: true)
                                }
                        }
                    }
                )
                
                if let cluster = activeCluster {
                    let clampedX = min(max(tooltipX, 70), width - 70)
                    ClusterTooltip(cluster: cluster)
                        .fixedSize()
                        .position(x: clampedX, y: 0)
                        .offset(y: -height * 0.5 - 30)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(isEnabled ? dragGesture(width: width) : nil)
        }
        .allowsHitTesting(isEnabled)
        .animation(.easeInOut(duration: 0.12), value: activeCluster?.id)
    }
    
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                let newTime = ratio * totalDuration
                onProgressChange(newTime)
                if let nearest = nearestCluster(to: newTime) {
                    if nearest.id != lastFocusedClusterID {
                        lastFocusedClusterID = nearest.id
                        onShotFocus(nearest.firstIndex)
                    }
                    let xPosition = xPosition(for: nearest, width: width)
                    updateActiveCluster(nearest, xPosition: xPosition, autoHide: false)
                } else {
                    lastFocusedClusterID = nil
                    updateActiveCluster(nil, xPosition: 0, autoHide: false)
                }
            }
            .onEnded { value in
                let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                let newTime = ratio * totalDuration
                if let nearest = nearestCluster(to: newTime) {
                    onProgressChange(nearest.representativeTime)
                    onShotFocus(nearest.firstIndex)
                    let xPosition = xPosition(for: nearest, width: width)
                    updateActiveCluster(nearest, xPosition: xPosition, autoHide: true)
                } else {
                    onProgressChange(newTime)
                    updateActiveCluster(nil, xPosition: 0, autoHide: false)
                }
                lastFocusedClusterID = nil
            }
    }
    
    private func nearestCluster(to time: Double) -> ShotCluster? {
        guard !clusters.isEmpty else { return nil }
        if let direct = clusters.first(where: { time >= $0.earliestTime - highlightThreshold && time <= $0.latestTime + highlightThreshold }) {
            return direct
        }
        return clusters.min(by: { abs($0.representativeTime - time) < abs($1.representativeTime - time) })
    }
    
    private func xPosition(for cluster: ShotCluster, width: CGFloat) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        let ratio = min(max(cluster.representativeTime / totalDuration, 0), 1)
        return width * ratio
    }
    
    private func updateActiveCluster(_ cluster: ShotCluster?, xPosition: CGFloat, autoHide: Bool) {
        tooltipToken = nil
        if let cluster = cluster {
            activeCluster = cluster
            tooltipX = xPosition
            if autoHide {
                let token = UUID()
                tooltipToken = token
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if tooltipToken == token {
                        activeCluster = nil
                    }
                }
            }
        } else {
            activeCluster = nil
        }
    }
    
    private struct ShotCluster: Identifiable, Equatable {
        let id = UUID()
        let members: [(index: Int, time: Double)]
        
        init(members: [(index: Int, time: Double)]) {
            self.members = members.sorted { $0.time < $1.time }
        }
        
        static func == (lhs: ShotCluster, rhs: ShotCluster) -> Bool {
            guard lhs.members.count == rhs.members.count else { return false }
            for (left, right) in zip(lhs.members, rhs.members) {
                if left.index != right.index { return false }
                if abs(left.time - right.time) > 0.0001 { return false }
            }
            return true
        }
        
        var count: Int { members.count }
        var representativeTime: Double {
            guard !members.isEmpty else { return 0 }
            let total = members.reduce(0) { $0 + $1.time }
            return total / Double(members.count)
        }
        var firstIndex: Int { members.first?.index ?? 0 }
        var earliestTime: Double { members.first?.time ?? 0 }
        var latestTime: Double { members.last?.time ?? earliestTime }
    }
    
    private struct ClusterTooltip: View {
        let cluster: ShotCluster
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                if cluster.count > 1 {
                    Text("\(cluster.count) shots")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else if let member = cluster.members.first {
                    Text("Shot \(member.index + 1)")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                ForEach(Array(cluster.members.enumerated()), id: \.element.index) { _, member in
                    Text("Shot \(member.index + 1): \(String(format: "%.2fs", member.time))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
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
    
    // Create mock shots and simulate them being received
    let mockView = DrillResultView(drillSetup: mockDrillSetup)
    
    // Post mock shots to simulate drill completion
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let mockShotsData: [[String: Any]] = [
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "B",
                    "hit_position": ["x": 395.0, "y": 495.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 0.18
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "B",
                    "hit_position": ["x": 400.0, "y": 500.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 0.21
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "B",
                    "hit_position": ["x": 403.0, "y": 502.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 0.22
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "B",
                    "hit_position": ["x": 398.0, "y": 498.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 0.24
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "B",
                    "hit_position": ["x": 405.0, "y": 505.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 0.27
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "A",
                    "hit_position": ["x": 205.0, "y": 295.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 1.35
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "A",
                    "hit_position": ["x": 208.0, "y": 298.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 1.37
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "C",
                    "hit_position": ["x": 520.0, "y": 640.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 2.8
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ],
            [
                "target": "target1",
                "content": [
                    "command": "shot",
                    "hit_area": "C",
                    "hit_position": ["x": 523.0, "y": 643.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 2.83
                ],
                "type": "shot",
                "action": "hit",
                "device": "device1"
            ]
        ]
        
        // Simulate shot notifications for preview
        for shotData in mockShotsData {
            NotificationCenter.default.post(
                name: .bleShotReceived,
                object: nil,
                userInfo: ["shot_data": shotData]
            )
        }
    }
    
    return mockView
        .environment(\.managedObjectContext, context)
}
