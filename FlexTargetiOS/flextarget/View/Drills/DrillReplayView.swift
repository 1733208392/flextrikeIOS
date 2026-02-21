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

                    let imageName = "\(display.icon).live.target"
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: frameWidth, height: frameHeight)
                        .onAppear {
                            // Log when image is loaded
                            print("[ReplayTargetDisplayView] Loading image: \(imageName)")
                        }
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
            let baseId = target.id?.uuidString ?? UUID().uuidString
            let variants = target.toStruct().parseVariants()
            
            print("[DrillReplayView] Target: \(target.targetName ?? "unknown"), iconName: '\(iconName)', variants count: \(variants.count)")
            
            // Check if targetType is a JSON array string (multi-target-type feature)
            let multiTargetTypes = parseMultiTargetTypes(iconName)
            
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
                    print("[DrillReplayView] Variant \(index): targetType='\(variant.targetType)', icon='\(variantIcon)', timeWindow: \(variant.startTime)-\(variant.endTime)")
                    displays.append(display)
                }
            } else if !multiTargetTypes.isEmpty {
                // Create a display for each target type in the multi-target array
                for (index, targetType) in multiTargetTypes.enumerated() {
                    let id = "\(baseId)-multitarget-\(index)"
                    let display = ReplayTargetDisplay(
                        id: id,
                        config: target,
                        icon: targetType,
                        targetName: target.targetName,
                        variant: nil
                    )
                    print("[DrillReplayView] Multi-target \(index): icon='\(targetType)'")
                    displays.append(display)
                }
            } else {
                // No variants or multi-target types: create single display (legacy behavior)
                let resolvedIcon = iconName.isEmpty ? "hostage" : iconName
                let display = ReplayTargetDisplay(
                    id: baseId,
                    config: target,
                    icon: resolvedIcon,
                    targetName: target.targetName,
                    variant: nil
                )
                print("[DrillReplayView] Single target: icon='\(resolvedIcon)'")
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
    
    /// Parses a JSON array string of target types (e.g., '["hostage","ipsc","paddle"]')
    /// Returns array of target type strings, or empty array if not a valid JSON array
    private func parseMultiTargetTypes(_ jsonString: String) -> [String] {
        guard jsonString.hasPrefix("[") && jsonString.hasSuffix("]") else {
            return []
        }
        
        do {
            if let data = jsonString.data(using: .utf8),
               let jsonArray = try JSONSerialization.jsonObject(with: data) as? [String] {
                print("[DrillReplayView] Parsed multi-target types: \(jsonArray)")
                return jsonArray
            }
        } catch {
            print("[DrillReplayView] Failed to parse multi-target types from '\(jsonString)': \(error)")
        }
        
        return []
    }
    private var backgroundImageName: String {
        // Try to get the drill mode from drillSetup if available
        let drillMode = drillSetup.mode?.lowercased() ?? ""
        
        // Get the first target type from the drill setup
        guard let firstTarget = drillSetup.sortedTargets.first,
              let targetTypeStr = firstTarget.targetType, !targetTypeStr.isEmpty else {
            // Fallback based on drill mode
            switch drillMode {
            case "ipsc":
                return "ipsc"
            case "idpa":
                return "idpa"
            case "cqb":
                return "cqb_swing"
            default:
                return "ipsc"
            }
        }
        
        // Check if targetType is a JSON array (multi-target feature)
        let multiTargetTypes = parseMultiTargetTypes(targetTypeStr)
        let effectiveTargetType = multiTargetTypes.first ?? targetTypeStr
        
        // Map target type to background image name
        let imageMap: [String: String] = [
            "ipsc": "ipsc",
            "hostage": "ipsc",
            "paddle": "ipsc",
            "popper": "ipsc",
            "rotation": "ipsc",
            "special_1": "ipsc",
            "special_2": "ipsc",
            "idpa": "idpa",
            "idpa_ns": "idpa_ns",
            "idpa_black_1": "idpa_hard_cover_1",
            "idpa_black_2": "idpa_hard_cover_2",
            "idpa-back-1": "idpa_hard_cover_1",
            "idpa-back-2": "idpa_hard_cover_2",
            "cqb_swing": "cqb_swing",
            "cqb_front": "cqb_front",
            "cqb_move": "cqb_move",
            "cqb_hostage": "cqb_swing",
            "disguised_enemy": "cqb_swing",
            "disguised_enemy_surrender": "cqb_swing"
        ]
        
        // Try exact match first
        if let image = imageMap[effectiveTargetType] {
            print("[DrillReplayView] Background image: \(image) for target type: '\(effectiveTargetType)'")
            return image
        }
        
        // Fallback based on drill mode
        switch drillMode {
        case "ipsc":
            print("[DrillReplayView] Background image fallback to ipsc for drill mode: \(drillMode)")
            return "ipsc"
        case "idpa":
            print("[DrillReplayView] Background image fallback to idpa for drill mode: \(drillMode)")
            return "idpa"
        case "cqb":
            print("[DrillReplayView] Background image fallback to cqb_swing for drill mode: \(drillMode)")
            return "cqb_swing"
        default:
            print("[DrillReplayView] Background image fallback to ipsc (default)")
            return "ipsc"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let frameHeight = screenHeight * 0.6
            let frameWidth = frameHeight * 9 / 16
            
            ZStack {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
        .navigationTitle("Replay")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
        .onAppear {
            if let firstTarget = targetDisplays.first {
                print("[DrillReplayView] onAppear - Setting initial target: \(firstTarget.id), icon: '\(firstTarget.icon)'")
                selectedTargetKey = firstTarget.id
            } else {
                print("[DrillReplayView] onAppear - No targets available!")
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
                    print("[DrillReplayView] activeTargetId: time \(time) in range [\(variant.startTime), \(variant.endTime)) -> \(display.id)")
                    return display.id
                }
            }
        }
        
        // If we have variants but time is past all of them, return the last one
        let variantDisplays = targetDisplays.filter { $0.variant != nil }
        if !variantDisplays.isEmpty {
            // Return the last variant (highest endTime)
            if let lastVariant = variantDisplays.last {
                print("[DrillReplayView] activeTargetId: time \(time) past all variants, returning last: \(lastVariant.id)")
                return lastVariant.id
            }
        }
        
        // Fallback: return first target (no time window constraints)
        let fallbackId = targetDisplays.first?.id
        print("[DrillReplayView] activeTargetId: Using fallback display: \(fallbackId ?? "none")")
        return fallbackId
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
                let shotDevice = lastShot.device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
                print("[DrillReplayView] Shot received - targetType: '\(shotTargetType)', device: '\(shotDevice)'")
                print("[DrillReplayView] Available displays: \(targetDisplays.map { "\($0.id): icon='\($0.icon)', targetName='\($0.targetName ?? "nil")'" }.joined(separator: ", "))")
                
                if let matchingDisplay = targetDisplays.first(where: { display in
                    // If variant exists, match its targetType
                    if let variant = display.variant {
                        let matches = variant.targetType == shotTargetType
                        print("[DrillReplayView] Checking variant: '\(variant.targetType)' vs '\(shotTargetType)' = \(matches)")
                        return matches
                    }
                    // Fallback: match by icon for non-variant targets
                    let matches = display.icon == shotTargetType
                    if let targetName = display.targetName {
                        // If display has targetName, also check device match
                        let deviceMatches = shotDevice == targetName
                        let finalMatch = matches && deviceMatches
                        print("[DrillReplayView] Checking icon+device: icon '\(display.icon)' vs '\(shotTargetType)' = \(matches), device '\(shotDevice)' vs '\(targetName)' = \(deviceMatches), final=\(finalMatch)")
                        return finalMatch
                    } else {
                        // No targetName constraint, just match icon
                        print("[DrillReplayView] Checking icon: '\(display.icon)' vs '\(shotTargetType)' = \(matches)")
                        return matches
                    }
                }) {
                    if selectedTargetKey != matchingDisplay.id {
                        print("[DrillReplayView] Switching to target: \(matchingDisplay.id), icon: '\(matchingDisplay.icon)'")
                        selectedTargetKey = matchingDisplay.id
                    }
                } else if let activeId = activeTargetId(forTime: time) {
                    // Fallback to time-based selection if no type match
                    print("[DrillReplayView] No type match, using time-based selection: \(activeId)")
                    if selectedTargetKey != activeId {
                        selectedTargetKey = activeId
                    }
                } else {
                    print("[DrillReplayView] No matching display found for shot")
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
