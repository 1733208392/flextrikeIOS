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
    
    // Mock data for target icons (keeping for now)
    let targetIcons = ["hostage", "ipsc", "paddle", "popper", "rotation", "special_1", "special_2"]
    
    @State private var selectedIcon: String = "hostage"
    
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

            ZStack {
                    
                    // Horizontal scroller below the frame
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(targetIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(selectedIcon == icon ? Color.blue : Color.gray, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 100)
        
                    // Center display for shot count
                    VStack {
                        Spacer()
                        Text("Shots: \(shots.count)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        Spacer()
                    }
                
                // Shot position markers
                ForEach(shots.indices, id: \.self) { index in
                    let shot = shots[index]
                    let x = shot.content.hitPosition.x
                    let y = shot.content.hitPosition.y
                    // Transform coordinates from 720×1280 source to screen dimensions
                    let transformedX = x * (screenWidth / 720.0)
                    let transformedY = y * (screenHeight / 1280.0)
                    Text("⭐")
                        .font(.title)
                        .position(x: transformedX, y: transformedY)
                }
                
                // Bottom right overlay list
                VStack {
                    Spacer()
                        HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hit Positions:")
                                .font(.headline)
                            ForEach(shots.indices, id: \.self) { index in
                                let shot = shots[index]
                                let x = shot.content.hitPosition.x
                                let y = shot.content.hitPosition.y
                                // Transform coordinates from 720×1280 source to screen dimensions
                                let transformedX = x * (screenWidth / 720.0)
                                let transformedY = y * (screenHeight / 1280.0)
                                Text("Shot \(index + 1): (\(String(format: "%.1f", transformedX)), \(String(format: "%.1f", transformedY)))")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .frame(width: 200)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Drill Result")
        .onAppear {
            startDrillTimer()
            setupNotificationObserver()
        }
        .onDisappear {
            stopDrillTimer()
            removeNotificationObserver()
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
        print("Drill timer expired. Shots received:")
        for (index, shot) in shots.enumerated() {
            print("Shot \(index + 1): (\(shot.content.hitPosition.x), \(shot.content.hitPosition.y))")
        }
        
        // Save drill results to Core Data
        saveDrillResults()
    }
    
    private func saveDrillResults() {
        let drillResult = DrillResult(context: viewContext)
        drillResult.drillId = drillSetup.id
        drillResult.date = Date()
        
        for shotData in shots {
            let shot = Shot(context: viewContext)
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
            try viewContext.save()
            print("Drill results saved successfully")
        } catch {
            print("Failed to save drill results: \(error)")
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
