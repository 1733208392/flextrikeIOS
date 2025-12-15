import SwiftUI
import CoreData

// Codable structs for JSON decoding
struct ShotData: Codable {
    let target: String?
    let content: Content
    let type: String?
    let action: String?
    let device: String?

    enum CodingKeys: String, CodingKey {
        case target
        case content
        case type
        case action
        case device
    }
}

struct Content: Codable {
    let command: String
    let hitArea: String
    let hitPosition: Position
    let rotationAngle: Double
    let targetType: String
    let timeDiff: Double
    let device: String?
    let targetPos: Position?
    let `repeat`: Int?

    enum CodingKeys: String, CodingKey {
        case command
        case hitArea = "hit_area"
        case hitPosition = "hit_position"
        case rotationAngle = "rotation_angle"
        case targetType = "target_type"
        case timeDiff = "time_diff"
        case device
        case targetPos = "targetPos"
        case `repeat` = "repeat"
    }

    init(command: String, hitArea: String, hitPosition: Position, rotationAngle: Double, targetType: String, timeDiff: Double, device: String? = nil, targetPos: Position? = nil, `repeat`: Int? = nil) {
        self.command = command
        self.hitArea = hitArea
        self.hitPosition = hitPosition
        self.rotationAngle = rotationAngle
        self.targetType = targetType
        self.timeDiff = timeDiff
        self.device = device
        self.targetPos = targetPos
        self.`repeat` = `repeat`
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.command = try container.decode(String.self, forKey: .command)
        self.hitArea = try container.decode(String.self, forKey: .hitArea)
        self.hitPosition = try container.decode(Position.self, forKey: .hitPosition)
        
        // Handle rotationAngle as either Double, Int, or String
        if let rotAngleDouble = try? container.decode(Double.self, forKey: .rotationAngle) {
            self.rotationAngle = rotAngleDouble
        } else if let rotAngleInt = try? container.decode(Int.self, forKey: .rotationAngle) {
            self.rotationAngle = Double(rotAngleInt)
        } else if let rotAngleStr = try? container.decode(String.self, forKey: .rotationAngle), let rotAngleDouble = Double(rotAngleStr) {
            self.rotationAngle = rotAngleDouble
        } else {
            self.rotationAngle = 0.0
        }
        
        self.targetType = try container.decode(String.self, forKey: .targetType)
        
        // Handle timeDiff as either Double or String
        if let timeDiffDouble = try? container.decode(Double.self, forKey: .timeDiff) {
            self.timeDiff = timeDiffDouble
        } else if let timeDiffStr = try? container.decode(String.self, forKey: .timeDiff), let timeDiffDouble = Double(timeDiffStr) {
            self.timeDiff = timeDiffDouble
        } else {
            self.timeDiff = 0.0
        }
        
        self.device = try container.decodeIfPresent(String.self, forKey: .device)
        self.targetPos = try container.decodeIfPresent(Position.self, forKey: .targetPos)
        self.`repeat` = try container.decodeIfPresent(Int.self, forKey: .`repeat`)
    }
}

struct Position: Codable {
    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let xStr = try? container.decode(String.self, forKey: .x), let xVal = Double(xStr) {
            self.x = xVal
        } else {
            self.x = try container.decode(Double.self, forKey: .x)
        }
        if let yStr = try? container.decode(String.self, forKey: .y), let yVal = Double(yStr) {
            self.y = yVal
        } else {
            self.y = try container.decode(Double.self, forKey: .y)
        }
    }
}

private struct TargetDisplay: Identifiable, Hashable {
    let id: String
    let config: DrillTargetsConfig
    let icon: String
    let targetName: String?

    func matches(_ shot: ShotData) -> Bool {
        if let targetName = targetName {
            let shotTargetName = shot.device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return shotTargetName == targetName
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
    let selectedShotIndex: Int?
    let pulsingShotIndex: Int?
    let pulseScale: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat

    // Extract the rotation overlay into a small subview to keep the main
    // view builder expression simpler and easier for the compiler to type-check.
    private struct RotationOverlayView: View {
        let display: TargetDisplay
        let shots: [ShotData]
        let selectedShotIndex: Int?
        let frameWidth: CGFloat
        let frameHeight: CGFloat

        var chosenShot: ShotData? {
            if let sel = selectedShotIndex, shots.indices.contains(sel) {
                let s = shots[sel]
                if display.matches(s), s.content.targetPos != nil {
                    return s
                }
            }
            return nil
        }

        var body: some View {
            Group {
                if display.icon.lowercased() == "rotation" {
                    if chosenShot == nil {
                        Color.clear.onAppear {
                            print("[DrillResultView] rotation overlay: no selected shot with targetPos for display \(display.id)")
                        }
                    }

                    if let shotWithPos = chosenShot, let targetPos: Position = shotWithPos.content.targetPos {
                        let transformedX = (targetPos.x / 720.0) * frameWidth
                        let transformedY = (targetPos.y / 1280.0) * frameHeight
                        let rotationRad = shotWithPos.content.rotationAngle

                        // Scale the overlay from the design coordinate space (720x1280)
                        // into the current frame so the image size matches the target
                        // coordinate transform. We use the previously applied 1.1× (360×445)
                        // base size (396×489.5) and scale it by the same factors used
                        // for position transformation.
                        let scaleX = frameWidth / 720.0
                        let scaleY = frameHeight / 1280.0
                        let overlayBaseWidth: CGFloat = 396.0
                        let overlayBaseHeight: CGFloat = 489.5

                        Image("ipsc")
                            // .resizable()
                            // .scaledToFit()
                            .frame(width: overlayBaseWidth * scaleX, height: overlayBaseHeight * scaleY)
                            .rotationEffect(Angle(radians: rotationRad))
                            .position(x: transformedX, y: transformedY)
                    }
                }
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTargetKey) {
            ForEach(targetDisplays, id: \.id) { display in
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: frameWidth, height: frameHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 12)
                        )

                    Image("\(display.icon).live.target")
                        .resizable()
                        .scaledToFit()
                        .frame(width: frameWidth - 20, height: frameHeight - 20)
                        .overlay(alignment: .topTrailing) {
                            if let targetName = display.targetName {
                                Text(targetName)
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(8)
                                    .padding(10)
                            }
                        }

                    RotationOverlayView(display: display, shots: shots, selectedShotIndex: selectedShotIndex, frameWidth: frameWidth, frameHeight: frameHeight)

                    ForEach(shots.indices, id: \.self) { index in
                        let shot = shots[index]
                        if display.matches(shot) {
                            let x = shot.content.hitPosition.x
                            let y = shot.content.hitPosition.y
                            let transformedX = (x / 720.0) * frameWidth
                            let transformedY = (y / 1280.0) * frameHeight

                            ZStack {
                                Image("bullet_hole2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 21, height: 21)

                                if selectedShotIndex == index {
                                    Circle()
                                        .stroke(Color.yellow, lineWidth: 2.5)
                                        .frame(width: 21, height: 21)
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
    let repeatSummary: DrillRepeatSummary?
    
    // Array to store received shots
    @State private var shots: [ShotData] = []
    
    // Timer for drill duration
    @State private var drillTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    
    // Drill status for title
    @State private var drillStatus: String = NSLocalizedString("drill_in_progress", comment: "Drill in progress status")
    @State private var isLiveDrill: Bool
    
    @State private var selectedTargetKey: String = ""
    @State private var selectedShotIndex: Int? = nil
    @State private var dots: String = ""
    @State private var dotsTimer: Timer?
    // visibleShotIndices removed: show all matching shots by default
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
            return TargetDisplay(id: id, config: target, icon: resolvedIcon, targetName: target.targetName)
        }
    }
    
    var totalDuration: Double {
        if let repeatSummary = repeatSummary {
            return repeatSummary.totalTime
        }
        return drillSetup.drillDuration
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
        self.repeatSummary = nil
        _isLiveDrill = State(initialValue: true)
        if let firstTarget = drillSetup.sortedTargets.first {
            _selectedTargetKey = State(initialValue: firstTarget.id?.uuidString ?? UUID().uuidString)
        } else {
            _selectedTargetKey = State(initialValue: UUID().uuidString)
        }
    }
    
    init(drillSetup: DrillSetup, shots: [ShotData]) {
        self.drillSetup = drillSetup
        self.repeatSummary = nil
        _isLiveDrill = State(initialValue: false)
        _shots = State(initialValue: shots)
        _drillStatus = State(initialValue: NSLocalizedString("drill_status_completed", comment: "Drill completed status"))
        if let firstTarget = drillSetup.sortedTargets.first {
            _selectedTargetKey = State(initialValue: firstTarget.id?.uuidString ?? UUID().uuidString)
        } else {
            _selectedTargetKey = State(initialValue: UUID().uuidString)
        }
    }
    
    init(drillSetup: DrillSetup, repeatSummary: DrillRepeatSummary) {
        self.drillSetup = drillSetup
        self.repeatSummary = repeatSummary
        _isLiveDrill = State(initialValue: false)
        _shots = State(initialValue: repeatSummary.shots)
        _drillStatus = State(initialValue: NSLocalizedString("drill_status_completed", comment: "Drill completed status"))
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
                    TargetDisplayView(
                        targetDisplays: targetDisplays,
                        selectedTargetKey: $selectedTargetKey,
                        shots: shots,
                        selectedShotIndex: selectedShotIndex,
                        pulsingShotIndex: pulsingShotIndex,
                        pulseScale: pulseScale,
                        frameWidth: frameWidth,
                        frameHeight: frameHeight
                    )
                    .onChange(of: shots.count) { _ in
                        ensureSelectedTargetIsValid()
                    }
                    .onChange(of: selectedShotIndex) { newIndex in
                        guard let idx = newIndex, shots.indices.contains(idx) else { return }
                        let shot = shots[idx]
                        if let matching = targetDisplays.first(where: { $0.matches(shot) }) {
                            selectedTargetKey = matching.id
                        }
                    }
                    .onChange(of: selectedTargetKey) { newKey in
                        // When the displayed target changes, update the list selection
                        // to focus the first shot for that target (if any).
                        let filtered = currentTargetTimelineData
                        if let first = filtered.first {
                            selectedShotIndex = first.index
                            pulsingShotIndex = first.index
                        } else {
                            selectedShotIndex = nil
                            pulsingShotIndex = nil
                        }
                    }

                    // Shot list below the target display
                    Divider()
                    ScrollView {
                        // Only show shots for the currently selected target.
                        // Use the precomputed `currentTargetTimelineData` which contains
                        // tuples with the original shot index.
                        LazyVStack(alignment: .center, spacing: 6) {
                            ForEach(Array(currentTargetTimelineData.enumerated()), id: \.element.index) { enumeratedEntry in
                                let pos = enumeratedEntry.offset
                                let idx = enumeratedEntry.element.index
                                let shot = shots[idx]

                                HStack(spacing: 12) {
                                    // Centered columns: seq, zone, time
                                    Text("#\(idx + 1)")
                                        .frame(width: 64, alignment: .center)
                                        .foregroundColor(.white)
                                    Text(shot.content.hitArea)
                                        .frame(width: 80, alignment: .center)
                                        .foregroundColor(.white)
                                    Text(String(format: "%.2f", shot.content.timeDiff))
                                        .frame(width: 80, alignment: .center)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: 640)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill((pos % 2) == 0 ? Color(white: 0.03) : Color(white: 0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedShotIndex == idx ? Color.red.opacity(0.95) : Color.clear, lineWidth: 2)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // highlight the selected shot marker in the display
                                    selectedShotIndex = idx
                                    pulsingShotIndex = idx
                                    // selectedTargetKey already matches this group; no change needed
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        pulseScale = 1.3
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeIn(duration: 0.15)) {
                                            pulseScale = 1.0
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 200)

                    // Simple status row
                    HStack(spacing: 12) {
                        Text(drillStatus)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(shots.count) shots")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.edgesIgnoringSafeArea(.all))
            }
            .navigationTitle(NSLocalizedString("drill_replay", comment: "Drill Replay navigation title"))
                .onAppear {
                    ensureSelectedTargetIsValid()

                    // If there are shots and no selection yet, focus the first shot
                    if selectedShotIndex == nil && !shots.isEmpty {
                        selectedShotIndex = 0
                        pulsingShotIndex = 0
                        if let firstShot = shots.first, let matching = targetDisplays.first(where: { $0.matches(firstShot) }) {
                            selectedTargetKey = matching.id
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            pulseScale = 1.3
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeIn(duration: 0.15)) {
                                pulseScale = 1.0
                            }
                        }
                    }

                    if isLiveDrill {
                        // NOTE: Live BLE handling has been moved out of `DrillResultView`.
                        // Live preview / live-shot streaming will be implemented in a
                        // dedicated `LivePreview` view in a future change.
                        startDrillTimer()
                        startDotsTimer()
                    }
                }
            .onDisappear {
                stopDrillTimer()
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

    

    private func ensureSelectedTargetIsValid() {
        guard !targetDisplays.contains(where: { $0.id == selectedTargetKey }) else { return }
        if let fallback = targetDisplays.first {
            selectedTargetKey = fallback.id
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
        // replay functionality removed; nothing more to stop here
    }
    
    // Live BLE notification handling previously lived here. It has been
    // intentionally removed so that `DrillResultView` only handles replay
    // and completed-results display. A dedicated `LivePreview` view should
    // implement streaming BLE shot handling and duplicate detection.
    
    private func onDrillTimerExpired() {
        drillStatus = NSLocalizedString("drill_ended", comment: "Drill ended status")
        stopDotsTimer()
        
        print(NSLocalizedString("drill_timer_expired", comment: "Drill timer expired message") + ". " + NSLocalizedString("shots_received", comment: "Shots received label") + ":")
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
        
        // Set totalTime from repeatSummary if available
        if let repeatSummary = repeatSummary {
            drillResult.totalTime = repeatSummary.totalTime
        }
        
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
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "B", hitPosition: Position(x: 395.0, y: 495.0), rotationAngle: 0, targetType: "hostage", timeDiff: 0.18, device: "device1", targetPos: nil), type: "shot", action: "hit", device: "device1"),
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "B", hitPosition: Position(x: 400.0, y: 500.0), rotationAngle: 0, targetType: "hostage", timeDiff: 0.21, device: "device1", targetPos: nil), type: "shot", action: "hit", device: "device1"),
            ShotData(target: "target1", content: Content(command: "shot", hitArea: "A", hitPosition: Position(x: 205.0, y: 295.0), rotationAngle: 0, targetType: "hostage", timeDiff: 1.35, device: "device2", targetPos: nil), type: "shot", action: "hit", device: "device2"),
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
