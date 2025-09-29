import SwiftUI
import CoreData

struct DrillResultView: View {
    let drillSetup: DrillSetup
    
    // Array to store received shots
    @State private var shots: [[String: Any]] = []
    
    // Timer for drill duration
    @State private var drillTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    
    // Mock data for target icons (keeping for now)
    let targetIcons = ["hostage", "ipsc", "paddle", "popper", "rotation", "special_1", "special_2"]
    
    // Mock data for time differences (in seconds) - will be replaced with real data
    let timeDiffs = [0.5, 1.2, 0.8, 2.1, 1.5, 0.9, 1.8]
    
    @State private var selectedIcon: String = "hostage"
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
        // Set selected icon based on first target type if available
        if let firstTarget = drillSetup.targets.first {
            _selectedIcon = State(initialValue: firstTarget.targetType)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let frameHeight = screenHeight * 2 / 3
            let frameWidth = frameHeight * (268 / 476.4)
            
            ZStack {
                VStack(spacing: 20) {
                    // Black rectangular frame in the center
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: frameWidth, height: frameHeight)
                        
                        Image(selectedIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: frameWidth * 0.8, height: frameHeight * 0.8)
                        
                        // Display shots as red circles
                        ForEach(shots.indices, id: \.self) { index in
                            let shot = shots[index]
                            if let content = shot["content"] as? [String: Any],
                               let hitPosition = content["hit_position"] as? [String: Any],
                               let xStr = hitPosition["x"] as? String,
                               let yStr = hitPosition["y"] as? String,
                               let x = Double(xStr),
                               let y = Double(yStr) {
                                let imageWidth = frameWidth * 0.8
                                let imageHeight = frameHeight * 0.8
                                let scaleX = imageWidth / 720.0
                                let scaleY = imageHeight / 1280.0
                                let offsetX = frameWidth * 0.1
                                let offsetY = frameHeight * 0.1
                                let posX = offsetX + x * scaleX
                                let posY = offsetY + y * scaleY
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .position(x: posX, y: posY)
                            }
                        }
                        
                        // Display shots as red circles
                        ForEach(shots.indices, id: \.self) { index in
                            let shot = shots[index]
                            if let x = shot["x"] as? Double, let y = shot["y"] as? Double {
                                let imageWidth = frameWidth * 0.8
                                let imageHeight = frameHeight * 0.8
                                let scaleX = imageWidth / 720.0
                                let scaleY = imageHeight / 1280.0
                                let offsetX = frameWidth * 0.1
                                let offsetY = frameHeight * 0.1
                                let posX = offsetX + x * scaleX
                                let posY = offsetY + y * scaleY
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .position(x: posX, y: posY)
                            }
                        }
                    }
                    
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
                }
                
                // Bottom right overlay list
                VStack {
                    Spacer()
                        HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Time Diffs:")
                                .font(.headline)
                            ForEach(timeDiffs.indices, id: \.self) { index in
                                Text("Shot \(index + 1): \(String(format: "%.1f", timeDiffs[index]))s")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .frame(width: 150)
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
        guard let firstTarget = drillSetup.targets.first else { return }
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
            if let shotData = notification.userInfo?["shot_data"] as? [String: Any] {
                shots.append(shotData)
            }
        }
    }
    
    private func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self, name: .bleShotReceived, object: nil)
    }
    
    private func onDrillTimerExpired() {
        print("Drill timer expired. Shots received:")
        for (index, shot) in shots.enumerated() {
            print("Shot \(index + 1): \(shot)")
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
            // Convert shot data to JSON string
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: shotData, options: [])
                shot.data = String(data: jsonData, encoding: .utf8)
            } catch {
                print("Failed to encode shot data: \(error)")
                shot.data = nil
            }
            shot.timestamp = Date() // You might want to extract timestamp from shotData if available
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
    let mockDrillSetup = DrillSetup(
        name: "Test Drill",
        description: "Test drill description",
        delay: 2.0,
        targets: [
            DrillTargetsConfig(seqNo: 1, targetName: "target1", targetType: "paddle", timeout: 5.0, countedShots: 3)
        ]
    )
    DrillResultView(drillSetup: mockDrillSetup)
}
