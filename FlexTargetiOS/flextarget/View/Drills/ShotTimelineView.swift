import SwiftUI

struct ShotTimelineView: View {
    let shots: [(index: Int, time: Double, diff: Double)]
    let totalDuration: Double
    let currentProgress: Double
    let isEnabled: Bool
    let onProgressChange: (Double) -> Void
    let onShotFocus: (Int) -> Void

    @State private var lastFocusedClusterID: UUID?
    @State private var activeCluster: ShotCluster?
    @State private var tooltipX: CGFloat = 0
    @State private var tooltipToken: UUID?

    private var clusterMergeWindow: Double {
        max(0.12, totalDuration * 0.02)
    }

    private var highlightThreshold: Double {
        max(clusterMergeWindow * 1.2, totalDuration * 0.03)
    }

    private var clusters: [ShotCluster] {
        guard !shots.isEmpty else { return [] }
        var result: [ShotCluster] = []
        var currentMembers: [(index: Int, time: Double, diff: Double)] = [shots[0]]
        for shot in shots.dropFirst() {
            if let lastTime = currentMembers.last?.time, shot.time - lastTime <= clusterMergeWindow {
                currentMembers.append(shot)
            } else {
                result.append(ShotCluster(members: currentMembers))
                currentMembers = [shot]
            }
        }
        result.append(ShotCluster(members: currentMembers))
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let clampedRatio = totalDuration > 0 ? min(max(currentProgress / totalDuration, 0), 1) : 0
            let progressWidth = width * clampedRatio

            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: progressWidth, height: 4)
                }
                .frame(height: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .overlay(
                    ZStack {
                        ForEach(clusters) { cluster in
                            let ratio = totalDuration > 0 ? min(max(cluster.representativeTime / totalDuration, 0), 1) : 0
                            let xPosition = width * ratio
                            let isPastCluster = cluster.latestTime <= currentProgress + 0.0001
                            let tickWidth: CGFloat = cluster.count > 1 ? 4 : 2
                            let baseColor: Color = cluster.count > 1 ? Color.orange : Color.white.opacity(0.7)
                            let fillColor: Color = isPastCluster ? (cluster.count > 1 ? Color.orange : Color.yellow) : baseColor
                            Rectangle()
                                .fill(fillColor)
                                .frame(width: tickWidth, height: cluster.count > 1 ? 18 : 12)
                                .frame(width: 28, height: height)
                                .position(x: xPosition, y: height / 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard isEnabled else { return }
                                    onProgressChange(cluster.representativeTime)
                                    onShotFocus(cluster.firstIndex)
                                    updateActiveCluster(cluster, xPosition: xPosition, autoHide: true)
                                }
                        }
                    }
                )

                if let cluster = activeCluster {
                    let clampedX = min(max(tooltipX, 70), width - 70)
                    ClusterTooltip(cluster: cluster)
                        .fixedSize()
                        .position(x: clampedX, y: 0)
                        .offset(y: -height * 0.5 - 30)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(isEnabled ? dragGesture(width: width) : nil)
        }
        .allowsHitTesting(isEnabled)
        .animation(.easeInOut(duration: 0.12), value: activeCluster?.id)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                let newTime = ratio * totalDuration
                onProgressChange(newTime)
                if let nearest = nearestCluster(to: newTime) {
                    if nearest.id != lastFocusedClusterID {
                        lastFocusedClusterID = nearest.id
                        onShotFocus(nearest.firstIndex)
                    }
                    let xPosition = xPosition(for: nearest, width: width)
                    updateActiveCluster(nearest, xPosition: xPosition, autoHide: false)
                } else {
                    lastFocusedClusterID = nil
                    updateActiveCluster(nil, xPosition: 0, autoHide: false)
                }
            }
            .onEnded { value in
                let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                let newTime = ratio * totalDuration
                if let nearest = nearestCluster(to: newTime) {
                    onProgressChange(nearest.representativeTime)
                    onShotFocus(nearest.firstIndex)
                    let xPosition = xPosition(for: nearest, width: width)
                    updateActiveCluster(nearest, xPosition: xPosition, autoHide: true)
                } else {
                    onProgressChange(newTime)
                    updateActiveCluster(nil, xPosition: 0, autoHide: false)
                }
                lastFocusedClusterID = nil
            }
    }

    private func nearestCluster(to time: Double) -> ShotCluster? {
        guard !clusters.isEmpty else { return nil }
        if let direct = clusters.first(where: { time >= $0.earliestTime - highlightThreshold && time <= $0.latestTime + highlightThreshold }) {
            return direct
        }
        return clusters.min(by: { abs($0.representativeTime - time) < abs($1.representativeTime - time) })
    }

    private func xPosition(for cluster: ShotCluster, width: CGFloat) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        let ratio = min(max(cluster.representativeTime / totalDuration, 0), 1)
        return width * ratio
    }

    private func updateActiveCluster(_ cluster: ShotCluster?, xPosition: CGFloat, autoHide: Bool) {
        tooltipToken = nil
        if let cluster = cluster {
            activeCluster = cluster
            tooltipX = xPosition
            if autoHide {
                let token = UUID()
                tooltipToken = token
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if tooltipToken == token {
                        activeCluster = nil
                    }
                }
            }
        } else {
            activeCluster = nil
        }
    }
}

struct ShotCluster: Identifiable, Equatable {
    let id = UUID()
    let members: [(index: Int, time: Double, diff: Double)]

    init(members: [(index: Int, time: Double, diff: Double)]) {
        self.members = members.sorted { $0.time < $1.time }
    }

    static func == (lhs: ShotCluster, rhs: ShotCluster) -> Bool {
        guard lhs.members.count == rhs.members.count else { return false }
        for (left, right) in zip(lhs.members, rhs.members) {
            if left.index != right.index { return false }
            if abs(left.time - right.time) > 0.0001 { return false }
            if abs(left.diff - right.diff) > 0.0001 { return false }
        }
        return true
    }

    var count: Int { members.count }
    var representativeTime: Double {
        guard !members.isEmpty else { return 0 }
        let total = members.reduce(0) { $0 + $1.time }
        return total / Double(members.count)
    }
    var firstIndex: Int { members.first?.index ?? 0 }
    var earliestTime: Double { members.first?.time ?? 0 }
    var latestTime: Double { members.last?.time ?? earliestTime }
}

struct ClusterTooltip: View {
    let cluster: ShotCluster

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if cluster.count > 1 {
                Text(String(format: NSLocalizedString("shots_count", comment: "Number of shots"), cluster.count))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else if let member = cluster.members.first {
                Text(String(format: NSLocalizedString("shot_number", comment: "Shot number"), member.index + 1))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            ForEach(Array(cluster.members.enumerated()), id: \.element.index) { _, member in
                Text(String(format: NSLocalizedString("shot_with_time", comment: "Shot with time"), member.index + 1, member.diff))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
