import AVFoundation
import SwiftUI

enum TimerState {
    case idle
    case standby
    case running
    case paused
}

struct TimerSessionView: View {
    @Environment(\.dismiss) private var dismiss

    let drillSetup: DrillSetup
    let bleManager: BLEManager
    let onDrillComplete: ([DrillRepeatSummary]) -> Void
    let onDrillFailed: () -> Void

    @State private var timerState: TimerState = .idle
    @State private var delayTarget: Date?
    @State private var delayRemaining: TimeInterval = 0
    @State private var randomDelay: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var elapsedDuration: TimeInterval = 0
    @State private var updateTimer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showEndDrillAlert: Bool = false
    @State private var gracePeriodActive: Bool = false
    @State private var gracePeriodRemaining: TimeInterval = 0
    private let gracePeriodDuration: TimeInterval = 3.0
    
    // Drill execution properties
    @State private var executionManager: DrillExecutionManager?
    @State private var expectedDevices: [String] = []

    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Text(elapsedTimeText)
                        .font(.custom("DIGITALDREAMFAT", size: 48))
                        .tracking(4)
                        .foregroundColor(.white)
                    
                    if timerState == .standby {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(width: geometry.size.width * (1 - (delayRemaining / randomDelay)))
                            }
                            .frame(height: 2)
                        }
                        .frame(height: 2)
                    }
                }

                Spacer()

                if gracePeriodActive {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: min(gracePeriodRemaining / gracePeriodDuration, 1.0))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear, value: gracePeriodRemaining)
                            VStack(spacing: 4) {
                                Text("\(Int(gracePeriodRemaining))")
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(NSLocalizedString("processing_shots", comment: "Processing shots"))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 200, height: 200)
                    }
                } else {
                    Button(action: buttonTapped) {
                        Text(buttonText)
                            .font(.largeTitle.weight(.bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 200, height: 200)
                    .foregroundColor(.white)
                    .background(buttonColor)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 10)
                    .disabled(timerState == .standby)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            
            VStack {
                HStack {
                    Button(action: handleBackButtonTap) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text(NSLocalizedString("back", comment: "Back button"))
                        }
                        .foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark)
        .tint(.red)
        .navigationBarBackButtonHidden(true)
        .alert(NSLocalizedString("end_drill", comment: "End drill alert title"), isPresented: $showEndDrillAlert) {
            Button(NSLocalizedString("cancel", comment: "Cancel button"), role: .cancel) { }
            Button(NSLocalizedString("confirm", comment: "Confirm button"), role: .destructive) {
                executionManager?.manualStopDrill()
                gracePeriodActive = true
                gracePeriodRemaining = gracePeriodDuration
                stopUpdateTimer()
                startUpdateTimer()
            }
        } message: {
            Text(NSLocalizedString("drill_in_progress", comment: "Drill in progress"))
        }
        .onDisappear {
            stopUpdateTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bleNetlinkForwardReceived)) { notification in
            executionManager?.handleNetlinkForward(notification)
        }
    }

    private var elapsedTimeText: String {
        let centiseconds = Int(elapsedDuration * 100)
        let minutes = (centiseconds / 100) / 60
        let seconds = (centiseconds / 100) % 60
        let hundredths = centiseconds % 100
        return String(format: "%02d:%02d:%02d", minutes, seconds, hundredths)
    }

    private var buttonText: String {
        switch timerState {
        case .idle, .paused:
            return "START"
        case .standby:
            return "STANDBY"
        case .running:
            return "STOP"
        }
    }

    private var buttonColor: Color {
        switch timerState {
        case .idle:
            return Color.red
        case .standby:
            return Color.red
        case .running:
            return Color.blue
        case .paused:
            return Color.red
        }
    }

    private func startSequence() {
        timerState = .standby
        playStandbySound()
        let randomDelayValue = Double.random(in: 2...5)
        randomDelay = randomDelayValue
        delayTarget = Date().addingTimeInterval(randomDelayValue)
        delayRemaining = randomDelayValue
        timerStartDate = nil
        startUpdateTimer()
        
        // Extract expected devices from drill targets
        let expectedDevicesList = (drillSetup.targets as? Set<DrillTargetsConfig>)
            .map { $0.compactMap { $0.targetName } } ?? []
        expectedDevices = expectedDevicesList
        
        // Create and start drill execution manager
        let manager = DrillExecutionManager(
            bleManager: bleManager,
            drillSetup: drillSetup,
            expectedDevices: expectedDevices,
            randomDelay: randomDelayValue,
            onComplete: { summaries in
                DispatchQueue.main.async {
                    onDrillComplete(summaries)
                }
            },
            onFailure: {
                DispatchQueue.main.async {
                    onDrillFailed()
                }
            }
        )
        
        executionManager = manager
        manager.startExecution()
    }

    private func startButtonAnimation() {
        // Animation removed
    }

    private func stopButtonAnimation() {
        // Animation removed
    }

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer(timeInterval: 0.05, repeats: true) { _ in
            let now = Date()
            
            if timerState == .standby, let target = delayTarget {
                if now >= target {
                    delayTarget = nil
                    delayRemaining = 0
                    transitionToRunning(at: now)
                } else {
                    delayRemaining = target.timeIntervalSince(now)
                }
            }

            if timerState == .running, let start = timerStartDate {
                elapsedDuration = now.timeIntervalSince(start)
            }
            
            if gracePeriodActive {
                gracePeriodRemaining = max(0, gracePeriodRemaining - 0.05)
                if gracePeriodRemaining <= 0 {
                    gracePeriodActive = false
                    stopUpdateTimer()
                    dismiss()
                }
            }
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func transitionToRunning(at timestamp: Date) {
        timerState = .running
        timerStartDate = timestamp
        playHighBeep()
    }

    private func buttonTapped() {
        switch timerState {
        case .idle:
            startSequence()
        case .standby:
            // Do nothing while delay is running
            return
        case .running:
            // End the drill by calling manualStopDrill and show grace period
            executionManager?.manualStopDrill()
            gracePeriodActive = true
            gracePeriodRemaining = gracePeriodDuration
            stopUpdateTimer()
            startUpdateTimer()
        case .paused:
            // Resume from paused state
            resumeTimer()
        }
    }

    private func handleBackButtonTap() {
        if timerState == .standby || timerState == .running {
            showEndDrillAlert = true
        } else {
            dismiss()
        }
    }

    private func pauseTimer() {
        stopUpdateTimer()
        timerState = .paused
    }

    private func resumeTimer() {
        let elapsedSoFar = elapsedDuration
        timerStartDate = Date().addingTimeInterval(-elapsedSoFar)
        timerState = .running
        startUpdateTimer()
    }

    private func resetTimer() {
        stopUpdateTimer()
        timerState = .idle
        delayTarget = nil
        delayRemaining = 0
        timerStartDate = nil
        elapsedDuration = 0
        gracePeriodActive = false
        gracePeriodRemaining = 0
    }

    private func playHighBeep() {
        guard let url = Bundle.main.url(forResource: "synthetic-shot-timer", withExtension: "wav") else {
            print("Audio file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func playStandbySound() {
        guard let url = Bundle.main.url(forResource: "standby", withExtension: "mp3") else {
            print("Standby audio file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play standby audio: \(error)")
        }
    }
}

struct TimerSessionView_Previews: PreviewProvider {
    static var previews: some View {
        TimerSessionView(
            drillSetup: DrillSetup(),
            bleManager: BLEManager.shared,
            onDrillComplete: { _ in },
            onDrillFailed: {}
        )
    }
}
