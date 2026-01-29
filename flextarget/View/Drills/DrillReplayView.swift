import SwiftUI
import AVFoundation

/// A version of TargetDisplay specifically for the replay view to avoid conflicts with private definitions in DrillResultView.
struct ReplayTargetDisplay: Identifiable, Hashable {
    let id: String
    let config: DrillTargetsConfig
    let icon: String
    let targetName: String?
    let variant: TargetVariant?  // Optional variant from targetVariant JSON

    func matches(_ shot: ShotData) -> Bool {
        if let targetName = targetName {
            let shotTargetName = shot.device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shotIcon = shot.content.targetType.isEmpty ? "hostage" : shot.content.targetType
            // Use variant's targetType if present, otherwise use config's targetType
            let expectedIcon = variant?.targetType ?? icon
            return shotTargetName == targetName && shotIcon == expectedIcon
        } else {
            let shotIcon = shot.content.targetType.isEmpty ? "hostage" : shot.content.targetType
            let expectedIcon = variant?.targetType ?? icon
            return shotIcon == expectedIcon
        }
    }

    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(icon)
        hasher.combine(targetName)
        hasher.combine(variant)
    }

    static func == (lhs: ReplayTargetDisplay, rhs: ReplayTargetDisplay) -> Bool {
        return lhs.id == rhs.id &&
               lhs.icon == rhs.icon &&
               lhs.targetName == rhs.targetName &&
               lhs.variant == rhs.variant
    }
}

private func isScoringZone(_ hitArea: String) -> Bool {
    let trimmed = hitArea.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return trimmed == "azone" || trimmed == "czone" || trimmed == "dzone" || trimmed == "head" || trimmed == "body"
}

/// A version of TargetDisplayView that supports filtering shots by current playback time.
struct ReplayTargetDisplayView: View {
    let targetDisplays: [ReplayTargetDisplay]
    @Binding var selectedTargetKey: String
    let shots: [ShotData]
    let selectedShotIndex: Int?
    let pulsingShotIndex: Int?
    let pulseScale: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    
    /// The current playback time in seconds. Only shots fired before or at this time will be shown.
    let currentTime: Double

    private struct RotationOverlayView: View {
        let display: ReplayTargetDisplay
        let shots: [ShotData]
        let selectedShotIndex: Int?
        let pulsingShotIndex: Int?
        let pulseScale: CGFloat
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        let currentTime: Double

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
                    if let shotWithPos = chosenShot, let targetPos: Position = shotWithPos.content.targetPos {
                        let transformedX = (targetPos.x / 720.0) * frameWidth
                        let transformedY = (targetPos.y / 1280.0) * frameHeight
                        let rotationRad = shotWithPos.content.rotationAngle ?? 0.0

                        let scaleX = frameWidth / 720.0
                        let scaleY = frameHeight / 1280.0
                        let overlayBaseWidth: CGFloat = 396.0
                        let overlayBaseHeight: CGFloat = 489.5

                        ZStack(alignment: .center) {
                            ZStack(alignment: .center) {
                                Image("ipsc")
                                    .resizable()
                                    .frame(width: overlayBaseWidth * scaleX, height: overlayBaseHeight * scaleY)
                                    .aspectRatio(contentMode: .fill)

                                ForEach(shots.indices, id: \.self) { index in
                                    let shot = shots[index]
                                    
                                    // Calculate absolute time for this shot
                                    let shotTime = shots.prefix(index + 1).reduce(0.0) { $0 + $1.content.timeDiff }
                                    
                                    if shotTime <= currentTime && display.matches(shot), let shotTargetPos = shot.content.targetPos, isScoringZone(shot.content.hitArea) {
                                        let dx = shot.content.hitPosition.x - shotTargetPos.x
                                        let dy = shot.content.hitPosition.y - shotTargetPos.y
                                        let cosTheta = cos(-rotationRad)
                                        let sinTheta = sin(-rotationRad)
                                        let localDx = dx * cosTheta - dy * sinTheta
                                        let localDy = dx * sinTheta + dy * cosTheta
                                        let scaledDx = localDx * scaleX
                                        let scaledDy = localDy * scaleY

                                        ZStack {
                                            Image("bullet_hole2")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)

                                            if selectedShotIndex == index {
                                                Circle()
                                                    .stroke(Color.yellow, lineWidth: 2.5)
                                                    .frame(width: 21, height: 21)
                                                    .scaleEffect(pulsingShotIndex == index ? pulseScale : 1.0)
                                            }
                                        }
                                        .offset(x: scaledDx, y: scaledDy)
                                    }
                                }
                            }
                            .frame(width: overlayBaseWidth * scaleX, height: overlayBaseHeight * scaleY)
                            .rotationEffect(Angle(radians: rotationRad))
                        }
                        .frame(width: overlayBaseWidth * scaleX, height: overlayBaseHeight * scaleY)
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
                        .frame(width: frameWidth, height: frameHeight)
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

                    RotationOverlayView(display: display, shots: shots, selectedShotIndex: selectedShotIndex, pulsingShotIndex: pulsingShotIndex, pulseScale: pulseScale, frameWidth: frameWidth, frameHeight: frameHeight, currentTime: currentTime)

                    if display.icon.lowercased() == "rotation" {
                        let scaleX = frameWidth / 720.0
                        let scaleY = frameHeight / 1280.0
                        let barrelWidth: CGFloat = 420.0
                        let barrelHeight: CGFloat = 641.0
                        let barrelOffsetX: CGFloat = -200.0
                        let barrelOffsetY: CGFloat = 230.0
                        
                        let barrelCenterX = (frameWidth / 2.0) + (barrelOffsetX * scaleX)
                        let barrelCenterY = (frameHeight / 2.0) + (barrelOffsetY * scaleY)

                        Image("barrel")
                            .resizable()
                            .frame(width: barrelWidth * scaleX, height: barrelHeight * scaleY)
                            .position(x: barrelCenterX, y: barrelCenterY)
                    }

                    ForEach(shots.indices, id: \.self) { index in
                        let shot = shots[index]
                        let shotTime = shots.prefix(index + 1).reduce(0.0) { $0 + $1.content.timeDiff }
                        
                        if shotTime <= currentTime && display.matches(shot) && display.icon.lowercased() != "rotation" && isScoringZone(shot.content.hitArea) {
                            let x = shot.content.hitPosition.x
                            let y = shot.content.hitPosition.y
                            let transformedX = (x / 720.0) * frameWidth
                            let transformedY = (y / 1280.0) * frameHeight

                            ZStack {
                                Image("bullet_hole2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)

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

                    ForEach(shots.indices, id: \.self) { index in
                        let shot = shots[index]
                        let shotTime = shots.prefix(index + 1).reduce(0.0) { $0 + $1.content.timeDiff }

                        if shotTime <= currentTime && display.matches(shot) && !isScoringZone(shot.content.hitArea) {
                            let x = shot.content.hitPosition.x
                            let y = shot.content.hitPosition.y
                            let transformedX = (x / 720.0) * frameWidth
                            let transformedY = (y / 1280.0) * frameHeight

                            ZStack {
                                Image("bullet_hole2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)

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
    }
}

struct DrillReplayView: View {
    let drillSetup: DrillSetup
    let shots: [ShotData]
    
    @State private var currentProgress: Double = 0
    @State private var isPlaying: Bool = false
    @State private var selectedTargetKey: String = ""
    @State private var selectedShotIndex: Int? = nil
    @State private var pulsingShotIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var audioPlayer: AVAudioPlayer?
    
    @State private var timer: Timer?
    
    private var totalDuration: Double {
        shots.reduce(0.0) { $0 + $1.content.timeDiff }
    }
    
    private var playingDuration: Double {
        totalDuration + 1.0
    }
    
    private var shotTimelineData: [(index: Int, time: Double, diff: Double)] {
        var cumulativeTime = 0.0
        return shots.enumerated().map { (index, shot) in
            let interval = shot.content.timeDiff
            cumulativeTime += interval
            return (index, cumulativeTime, interval)
        }
    }
    
    private var targetDisplays: [ReplayTargetDisplay] {
        let sortedTargets = drillSetup.sortedTargets
        var displays: [ReplayTargetDisplay] = []
        
        for target in sortedTargets {
            let iconName = target.targetType ?? ""
            let resolvedIcon = iconName.isEmpty ? "hostage" : iconName
            let baseId = target.id?.uuidString ?? UUID().uuidString
            let variants = target.toStruct().parseVariants()
            
            if !variants.isEmpty {
                // Create a display for each variant
                for (index, variant) in variants.enumerated() {
                    let id = "\(baseId)-variant-\(index)"
                    let variantIcon = variant.targetType.isEmpty ? "hostage" : variant.targetType
                    let display = ReplayTargetDisplay(
                        id: id,
                        config: target,
                        icon: variantIcon,
                        targetName: target.targetName,
                        variant: variant
                    )
                    displays.append(display)
                }
            } else {
                // No variants: create single display (legacy behavior)
                let display = ReplayTargetDisplay(
                    id: baseId,
                    config: target,
                    icon: resolvedIcon,
                    targetName: target.targetName,
                    variant: nil
                )
                displays.append(display)
            }
        }
        
        // Sort by seqNo first, then by startTime (from variant if present)
        return displays.sorted { d1, d2 in
            if d1.config.seqNo != d2.config.seqNo {
                return d1.config.seqNo < d2.config.seqNo
            }
            let t1 = d1.variant?.startTime ?? 0
            let t2 = d2.variant?.startTime ?? 0
            return t1 < t2
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let frameHeight = screenHeight * 0.6
            let frameWidth = frameHeight * 9 / 16
            
            VStack(spacing: 20) {
                // Target Display
                ReplayTargetDisplayView(
                    targetDisplays: targetDisplays,
                    selectedTargetKey: $selectedTargetKey,
                    shots: shots,
                    selectedShotIndex: selectedShotIndex,
                    pulsingShotIndex: pulsingShotIndex,
                    pulseScale: pulseScale,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    currentTime: currentProgress
                )
                .frame(width: frameWidth, height: frameHeight)
                
                // Timeline and Controls
                VStack(spacing: 15) {
                    HStack {
                        Text(String(format: "%.2f", min(currentProgress, totalDuration)))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(String(format: "%.2f", totalDuration))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal)
                    
                    ShotTimelineView(
                        shots: shotTimelineData,
                        totalDuration: totalDuration,
                        currentProgress: currentProgress,
                        isEnabled: true,
                        onProgressChange: { newProgress in
                            currentProgress = newProgress
                            updateSelectionForTime(newProgress)
                        },
                        onShotFocus: { index in
                            selectedShotIndex = index
                            pulsingShotIndex = index
                            triggerPulse()
                            playShotSound()
                        }
                    )
                    .frame(height: 40)
                    .padding(.horizontal)
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        Button(action: {
                            currentProgress = 0
                            updateSelectionForTime(0)
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            currentProgress = playingDuration
                            updateSelectionForTime(playingDuration)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
        .navigationTitle("Replay")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let firstTarget = targetDisplays.first {
                selectedTargetKey = firstTarget.id
            }
            // Configure audio session
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Helper Methods for Time Window Handling
    
    private func activeTargetId(forTime time: Double) -> String? {
        // Find target whose time window contains the given time
        for display in targetDisplays {
            // Check variant time window if variant exists
            if let variant = display.variant {
                if time >= variant.startTime && time < variant.endTime {
                    return display.id
                }
            }
        }
        
        // Fallback: return first target (no time window constraints)
        return targetDisplays.first?.id
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopTimer()
        } else {
            if currentProgress >= playingDuration {
                currentProgress = 0
            }
            startTimer()
        }
        isPlaying.toggle()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            currentProgress += 0.05
            if currentProgress >= playingDuration {
                currentProgress = playingDuration
                stopTimer()
                isPlaying = false
            }
            updateSelectionForTime(currentProgress)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSelectionForTime(_ time: Double) {
        // Find the most recent shot before or at this time
        let pastShots = shotTimelineData.filter { $0.time <= time }
        if let lastShotTuple = pastShots.last, shots.indices.contains(lastShotTuple.index) {
            let lastShot = shots[lastShotTuple.index]
            if selectedShotIndex != lastShotTuple.index {
                selectedShotIndex = lastShotTuple.index
                pulsingShotIndex = lastShotTuple.index
                triggerPulse()
                
                if isPlaying {
                    playShotSound()
                }
                
                // Enhancement: Match shot targetType to variant targetType
                // This auto-switches the variant tab when a different type of shot is fired
                let shotTargetType = lastShot.content.targetType.isEmpty ? "hostage" : lastShot.content.targetType
                if let matchingDisplay = targetDisplays.first(where: { display in
                    // If variant exists, match its targetType
                    if let variant = display.variant {
                        return variant.targetType == shotTargetType
                    }
                    // Fallback: match by icon for non-variant targets
                    return display.icon == shotTargetType
                }) {
                    if selectedTargetKey != matchingDisplay.id {
                        selectedTargetKey = matchingDisplay.id
                    }
                } else if let activeId = activeTargetId(forTime: time) {
                    // Fallback to time-based selection if no type match
                    if selectedTargetKey != activeId {
                        selectedTargetKey = activeId
                    }
                }
            }
        } else {
            selectedShotIndex = nil
            pulsingShotIndex = nil
            
            // Enhancement: Switch on endTime via activeTargetId
            // When no shots are being fired, automatically switch variants when endTime is reached
            if let activeId = activeTargetId(forTime: time) {
                if selectedTargetKey != activeId {
                    selectedTargetKey = activeId
                }
            }
        }
    }
    
    private func playShotSound() {
        guard let url = Bundle.main.url(forResource: "paper_hit", withExtension: "mp3") else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play shot sound: \(error)")
        }
    }
    
    private func triggerPulse() {
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
