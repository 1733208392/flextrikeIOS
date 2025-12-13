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
    let onDrillStart: (TimeInterval) -> Void

    @State private var timerState: TimerState = .idle
    @State private var delayTarget: Date?
    @State private var delayRemaining: TimeInterval = 0
    @State private var randomDelay: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var elapsedDuration: TimeInterval = 0
    @State private var updateTimer: Timer?
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Text("Elapsed Time")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(elapsedTimeText)
                        .font(.custom("DIGITALDREAMFAT", size: 54))
                        .tracking(4)

                    if timerState == .standby {
                        Text("Random delay: \(delayRemaining, format: .number.precision(.fractionLength(1)))s")
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: buttonTapped) {
                    Text(buttonText)
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 200, height: 200)
                .foregroundColor(.white)
                .background(buttonColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 10)
                .disabled(timerState == .standby)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear {
            stopUpdateTimer()
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
            return "Start"
        case .standby:
            return "Standby"
        case .running:
            return "Stop"
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
        let randomDelayValue = Double.random(in: 2...5)
        randomDelay = randomDelayValue
        delayTarget = Date().addingTimeInterval(randomDelayValue)
        delayRemaining = randomDelayValue
        timerStartDate = nil
        startUpdateTimer()
        // Trigger drill execution immediately when entering standby state
        // This gives target devices time to receive the command and get ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDrillStart(randomDelayValue)
        }
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
            pauseTimer()
        case .paused:
            // Resume from paused state
            resumeTimer()
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
}

struct TimerSessionView_Previews: PreviewProvider {
    static var previews: some View {
        TimerSessionView(drillSetup: DrillSetup(), onDrillStart: { _ in })
    }
}
