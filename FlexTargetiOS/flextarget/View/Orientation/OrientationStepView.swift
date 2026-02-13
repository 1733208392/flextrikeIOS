import SwiftUI
import AVKit

struct OrientationStepView: View {
    @Binding var step: OrientationStep
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var timeObserverToken: Any?
    var onNext: (() -> Void)? = nil
    var onStepCompleted: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video Player (top 2/3)
                VideoPlayer(player: player)
                .background(Color.black)
                .onAppear {
                    loadVideo()
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                        step.isCompleted = true
                        onStepCompleted?()
                    }
                }
                .onDisappear {
                    player.pause()
                    // Remove time observer
                    if let token = timeObserverToken {
                        player.removeTimeObserver(token)
                        timeObserverToken = nil
                    }
                }
                .frame(height: geometry.size.height * 2 / 3)
                .ignoresSafeArea(edges: .top)
                
                // Video Controls
                VStack(spacing: 16) {
                    // Progress Bar
                    VStack(spacing: 4) {
                        ProgressView(value: max(0, min(1, duration > 0 ? currentTime / duration : 0)))
                            .progressViewStyle(.linear)
                            .accentColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .frame(height: 4)
                            .padding(.horizontal, 8)
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption2)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
                    .background(Color.black.opacity(0.5))
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            let newTime = max(currentTime - 10, 0)
                            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                            currentTime = newTime
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 20))
                        }
                        
                        Button(action: {
                            isPlaying.toggle()
                            if isPlaying {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        }
                        
                        Button(action: {
                            let newTime = min(currentTime + 10, duration)
                            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                            currentTime = newTime
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 20))
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                
                // Title, Subtitle, and Red Circle Arrow
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.step)
                            .font(.largeTitle)
                            .bold()
                        Text(step.title)
                            .font(.largeTitle)
                            .bold()
                        Text(step.subTitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    // Only show Next button if onNext is not nil
                    if let onNext = onNext {
                        Button(action: {
                            onNext()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                                    .font(.title2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
            }//Top Level VStack\
            .background(Color.black).ignoresSafeArea()
            .foregroundColor(.white)
            
        } //Top Level Geo Reader
    }//View Body
    
    // Helper to format time as mm:ss
    func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadVideo() {
        // Remove existing time observer
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Reset player state
        player.replaceCurrentItem(with: AVPlayerItem(url: step.videoURL))
        player.play()
        isPlaying = true
        currentTime = 0
        duration = 1
        
        // Load duration properly
        if let asset = player.currentItem?.asset {
            Task {
                do {
                    let durationValue = try await asset.load(.duration).seconds
                    await MainActor.run {
                        duration = durationValue.isFinite ? durationValue : 1
                    }
                } catch {
                    await MainActor.run {
                        duration = 1
                    }
                }
            }
        }
        
        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let timeSeconds = time.seconds
            if timeSeconds.isFinite {
                currentTime = timeSeconds
            }
            if let durationSeconds = player.currentItem?.duration.seconds, durationSeconds.isFinite {
                duration = durationSeconds
            }
        }
    }
}

// View extension for conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
