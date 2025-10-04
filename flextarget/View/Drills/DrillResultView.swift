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
    
    @State private var selectedIcon: String = "hostage"
    @State private var selectedShotIndex: Int? = nil
    @State private var currentProgress: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var dots: String = ""
    @State private var replayTimer: Timer?
    @State private var visibleShotIndices: Set<Int> = []
    
    var totalDuration: Double {
        guard let targets = drillSetup.targets as? Set<DrillTargetsConfig> else { return 10.0 }
        return targets.map { $0.timeout }.max() ?? 10.0
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
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
                                            .frame(width: 40, height: 40)
                                    }
                                }
                                .position(x: transformedX, y: transformedY)
                            }
                        }
                    }
                    .frame(width: frameWidth, height: frameHeight)
                    
                    // Progress bar
                    HStack {
                        ProgressView(value: currentProgress, total: totalDuration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(height: 4)
                        Spacer()
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
                startDrillTimer()
                setupNotificationObserver()
                // Start dots animation
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    dots = dots == "..." ? "" : dots + "."
                }
            }
            .onDisappear {
                stopDrillTimer()
                removeNotificationObserver()
            }
            
            if drillStatus == "In Progress" {
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

    private func startReplay() {
        // Reset to beginning
        currentProgress = 0.0
        visibleShotIndices.removeAll()
        selectedShotIndex = nil
        
        // Start replay timer
        replayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentProgress += 0.1
            
            // Check if any shots should be visible at current progress
            for (index, shot) in shots.enumerated() {
                if shot.content.timeDiff <= currentProgress && !visibleShotIndices.contains(index) {
                    visibleShotIndices.insert(index)
                }
            }
            
            // Update selected shot to the current one
            let currentShotIndex = shots.enumerated()
                .filter { $0.element.content.timeDiff <= currentProgress }
                .max(by: { $0.element.content.timeDiff < $1.element.content.timeDiff })?
                .offset
            selectedShotIndex = currentShotIndex
            
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
            currentProgress = previousShot.element.content.timeDiff
            // Update visible shots
            visibleShotIndices = Set(shots.enumerated().filter { $0.element.content.timeDiff <= currentProgress }.map { $0.offset })
            selectedShotIndex = previousShot.offset
        } else {
            // Go to beginning
            currentProgress = 0.0
            visibleShotIndices.removeAll()
            selectedShotIndex = nil
        }
    }
    
    private func nextShot() {
        // Find the next shot after current progress
        let nextShots = shots.enumerated().filter { $0.element.content.timeDiff > currentProgress }.sorted { $0.element.content.timeDiff < $1.element.content.timeDiff }
        
        if let nextShot = nextShots.first {
            currentProgress = nextShot.element.content.timeDiff
            // Update visible shots
            visibleShotIndices = Set(shots.enumerated().filter { $0.element.content.timeDiff <= currentProgress }.map { $0.offset })
            selectedShotIndex = nextShot.offset
        } else {
            // Go to end
            currentProgress = totalDuration
            visibleShotIndices = Set(shots.indices)
            selectedShotIndex = shots.enumerated().max(by: { $0.element.content.timeDiff < $1.element.content.timeDiff })?.offset
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
                    "hit_area": "A",
                    "hit_position": ["x": 200.0, "y": 300.0],
                    "rotation_angle": 0,
                    "target_type": "hostage",
                    "time_diff": 1.5
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
                    "time_diff": 0.2
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
