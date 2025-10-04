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
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            // Calculate frame dimensions (9:16 aspect ratio, 2/3 of page height)
            let frameHeight = screenHeight * 2 / 3
            let frameWidth = frameHeight * 9 / 16

            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // White rectangular frame representing target device with gray fill (moved to top)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: frameWidth, height: frameHeight)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 12)
                    )
                    .position(x: screenWidth / 2, y: frameHeight / 2 + 10)
                
                // Target icon inside the frame (90% of frame size)
                Image(selectedIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frameWidth, height: frameHeight )
                    .position(x: screenWidth / 2, y: frameHeight / 2 + 10)
        
                    // Horizontal scroller below the frame
                    VStack {
                        Spacer()
                            .frame(height: frameHeight + 40)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Only show target icons that are in drillSetup.targets
                                if let targets = drillSetup.targets as? Set<DrillTargetsConfig> {
                                    ForEach(Array(targets).sorted(by: { $0.seqNo < $1.seqNo }), id: \.self) { target in
                                        if let targetType = target.targetType {
                                            Button(action: {
                                                selectedIcon = targetType
                                            }) {
                                                Image(targetType)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(selectedIcon == targetType ? Color.blue : Color.gray, lineWidth: 1))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 100)
                        
                        // Shot timing list below the scroller
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Shot Timing:")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(shots.indices, id: \.self) { index in
                                    let shot = shots[index]
                                    Button(action: {
                                        selectedShotIndex = (selectedShotIndex == index) ? nil : index
                                    }) {
                                        HStack {
                                            Text("Shot \(index + 1): \(String(format: "%.2f", shot.content.timeDiff))s")
                                                .font(.subheadline)
                                                .foregroundColor(selectedShotIndex == index ? .blue : .primary)
                                            Spacer()
                                            if selectedShotIndex == index {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(selectedShotIndex == index ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .frame(height: 200) // Fixed height for the scrollable area
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                
                // Shot position markers
                ForEach(shots.indices, id: \.self) { index in
                    let shot = shots[index]
                    let x = shot.content.hitPosition.x
                    let y = shot.content.hitPosition.y
                    // Transform coordinates from 720×1280 source to frame dimensions
                    let frameCenterX = screenWidth / 2
                    let frameCenterY = frameHeight / 2 + 20
                    let transformedX = frameCenterX - (frameWidth / 2) + (x / 720.0) * frameWidth
                    let transformedY = frameCenterY - (frameHeight / 2) + (y / 1280.0) * frameHeight
                    
                    ZStack {
                        Image(randomBulletHoleImage())
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
        .navigationTitle(drillStatus)
        .onAppear {
            startDrillTimer()
            setupNotificationObserver()
        }
        .onDisappear {
            stopDrillTimer()
            removeNotificationObserver()
        }
    }
    
    private func randomBulletHoleImage() -> String {
        let bulletHoleImages = ["bullet_hole2", "bullet_hole3", "bullet_hole4", "bullet_hole5", "bullet_hole6"]
        return bulletHoleImages.randomElement() ?? "bullet_hole2"
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
    
    return DrillResultView(drillSetup: mockDrillSetup)
        .environment(\.managedObjectContext, context)
}
