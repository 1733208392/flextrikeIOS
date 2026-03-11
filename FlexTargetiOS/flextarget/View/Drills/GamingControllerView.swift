import SwiftUI
import CoreData

struct GamingControllerView: View {
    let drillSetup: DrillSetup
    let bleManager: BLEManager
    var onGameEnd: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var score: String = "0"
    @State private var hitCount: String = "0"
    @State private var missCount: String = "0"
    @State private var isGameStarted: Bool = false
    @State private var showResult: Bool = false
    @State private var touchpadScale: CGFloat = 1.0
    @State private var isStopping: Bool = false
    
    // Swipe detection
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if showResult {
                GameDrillResultView(
                    gameName: "Clay Pigeon",
                    score: score,
                    hits: hitCount,
                    misses: missCount,
                    onReplay: {
                        withAnimation {
                            showResult = false
                            isGameStarted = true
                            isStopping = false
                        }
                        sendGameCommand(cmd: "start")
                    },
                    onDone: {
                        onGameEnd()
                        dismiss()
                    }
                )
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 30) {
                        // Game Name Title
                        Text("Clay Pigeon")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(ftRed)
                            .padding(.top, 40)
                        
                        Spacer()
                        
                        // Touchpad Area
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 280, height: 280)
                                .overlay(
                                    Circle()
                                        .stroke(ftRed.opacity(0.5), lineWidth: 4)
                                )
                            
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 80))
                                .foregroundColor(ftRed.opacity(0.2))
                            
                            // Indicators for directions
                            VStack {
                                Image(systemName: "chevron.up")
                                Spacer()
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                Spacer()
                            }
                            .padding(40)
                            .foregroundColor(ftRed.opacity(0.4))
                            .font(.system(size: 24, weight: .bold))
                        }
                        .scaleEffect(touchpadScale)
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    touchpadScale = 0.95
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    touchpadScale = 1.0
                                    handleSwipe(translation: value.translation)
                                    dragOffset = .zero
                                }
                        )
                        
                        Text(NSLocalizedString("swipe_to_launch", comment: "Swipe to launch"))
                            .foregroundColor(.white.opacity(0.6))
                            .font(.headline)
                        
                        Spacer()
                        
                        // Bottom Buttons
                        HStack(spacing: 20) {
                            if !isGameStarted {
                                Button(action: { startGame() }) {
                                    Text(NSLocalizedString("start_game", comment: "Start Game"))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.green)
                                        .cornerRadius(16)
                                }
                            } else {
                                Button(action: { stopGame() }) {
                                    Text(NSLocalizedString("stop_game", comment: "Stop Game"))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(isStopping ? Color.gray : ftRed)
                                        .cornerRadius(16)
                                }
                                .disabled(isStopping)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(ftRed)
                }
            }
        }
        .onAppear {
            setupResultListener()
        }
    }
    
    private let ftRed = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
    
    private func resultMetric(label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Game Logic
    
    private func handleSwipe(translation: CGSize) {
        guard isGameStarted && !showResult else { return }
        
        // Direction logic:
        // x positive is right, y negative is up
        let x = translation.width
        let y = translation.height
        
        var direction = "center"
        
        if y < -30 { // Upward swipe
            if x > 30 {
                direction = "right"
            } else if x < -30 {
                direction = "left"
            } else {
                direction = "center"
            }
        } else if x > 50 {
            direction = "right"
        } else if x < -50 {
            direction = "left"
        } else {
            return // Didn't swipe enough
        }
        
        sendGameCommand(cmd: "launch", direction: direction)
    }
    
    private func startGame() {
        isGameStarted = true
        showResult = false
        isStopping = false
        sendGameCommand(cmd: "start")
    }
    
    private func stopGame() {
        isStopping = true
        sendGameCommand(cmd: "stop")
        
        // Timeout to show result if no packet arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isStopping {
                withAnimation {
                    self.showResult = true
                    self.isStopping = false
                    self.isGameStarted = false
                }
            }
        }
    }
    
    private func restartGame() {
        showResult = false
        isStopping = false
        startGame()
    }
    
    private func sendGameCommand(cmd: String, direction: String? = nil) {
        // Find the single target device name
        guard let device = drillSetup.targets?.allObjects.first as? DrillTargetsConfig,
              let deviceName = device.targetName else {
            print("[Gaming] No device found to send command")
            return
        }
        
        var content: [String: Any] = [
            "game": "clay pigeon",
            "cmd": cmd
        ]
        
        if let dir = direction {
            content["direct"] = dir
        }
        
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": deviceName,
            "content": content
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            bleManager.writeJSON(jsonString)
            print("[Gaming] Sent: \(jsonString)")
        }
    }
    
    private func setupResultListener() {
        // Listen for netlink forward messages (Godot relay)
        NotificationCenter.default.addObserver(forName: Notification.Name("bleNetlinkForwardReceived"), object: nil, queue: .main) { notification in
            handleIncomingPacket(notification: notification)
        }
        
        // Listen for direct forward messages (Type: forward)
        NotificationCenter.default.addObserver(forName: Notification.Name("bleDirectForwardReceived"), object: nil, queue: .main) { notification in
            handleIncomingPacket(notification: notification)
        }
    }
    
    private func handleIncomingPacket(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let json = userInfo["json"] as? [String: Any] else {
            return
        }
        
        // Content might be top-level or nested under 'content' key
        let content: [String: Any]
        if let nestedContent = json["content"] as? [String: Any] {
            content = nestedContent
        } else {
            content = json
        }
        
        guard let game = content["game"] as? String, game == "clay pigeon" else {
            return
        }
        
        if let scoreVal = content["score"] { score = "\(scoreVal)" }
        if let hitVal = content["hit"] { hitCount = "\(hitVal)" }
        if let missVal = content["miss"] { missCount = "\(missVal)" }
        
        // If we represent a final state (score/hit/miss present) or were waiting for a stop
        if content["score"] != nil || isStopping {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showResult = true
                    isStopping = false
                    isGameStarted = false
                }
            }
        }
    }
}
