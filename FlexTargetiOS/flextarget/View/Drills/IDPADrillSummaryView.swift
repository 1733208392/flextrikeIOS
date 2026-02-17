import SwiftUI
import CoreData

struct IDPADrillSummaryView: View {
    let drillSetup: DrillSetup
    @State var summaries: [DrillRepeatSummary]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var environmentContext
    
    @State private var showEditDialog = false
    @State private var editingSummary: DrillRepeatSummary?
    @State private var showDrillResult = false
    @State private var showDrillReplay = false
    @State private var selectedSummary: DrillRepeatSummary?
    
    private var viewContext: NSManagedObjectContext {
        if let coordinator = environmentContext.persistentStoreCoordinator,
           coordinator.persistentStores.isEmpty == false {
            return environmentContext
        }
        return PersistenceController.shared.container.viewContext
    }
    
    private var drillName: String {
        drillSetup.name ?? "Untitled Drill"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    navigationBar
                    
                    if summaries.isEmpty {
                        emptyState
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                ForEach(summaries.indices, id: \.self) { index in
                                    idpaDrillCard(for: summaries[index], index: index)
                                }
                            }
                            .padding(.vertical, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            
            // Edit Dialog
            if showEditDialog, let editingSummary = editingSummary {
                IDPAZoneEditDialog(
                    summary: editingSummary,
                    onSave: { updatedZones in
                        if let index = summaries.firstIndex(where: { $0.id == editingSummary.id }) {
                            summaries[index].idpaZones = updatedZones
                        }
                        showEditDialog = false
                        self.editingSummary = nil
                    },
                    onCancel: {
                        showEditDialog = false
                        self.editingSummary = nil
                    }
                )
            }
            
            // Navigation to DrillResultView
            if showDrillResult, let selectedSummary = selectedSummary {
                NavigationLink(
                    destination: DrillResultView(drillSetup: drillSetup, repeatSummary: selectedSummary),
                    isActive: $showDrillResult
                ) {
                    EmptyView()
                }
            }
            
            // Navigation to DrillReplayView
            if showDrillReplay, let selectedSummary = selectedSummary {
                NavigationLink(
                    destination: DrillReplayView(drillSetup: drillSetup, shots: selectedSummary.shots),
                    isActive: $showDrillReplay
                ) {
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            Text(drillName.capitalized)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            // Placeholder for alignment
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.6))
    }
    
    // MARK: - IDPA Drill Card
    
    private func idpaDrillCard(for summary: DrillRepeatSummary, index: Int) -> some View {
        let breakdown = ScoringUtility.getIDPAZoneBreakdown(shots: summary.shots)
        let pointsDown = ScoringUtility.calculateIDPAPointsDown(shots: summary.shots)
        let finalTime = ScoringUtility.calculateIDPAFinalTime(rawTime: summary.totalTime, pointsDown: pointsDown)
        
        return VStack(spacing: 16) {
            // Header: Repeat number and basic stats
            VStack(spacing: 12) {
                HStack {
                    Text(String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summary.repeatIndex))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Metrics grid: Raw Time, Final Time (Score) - CLICKABLE
                Button(action: {
                    selectedSummary = summary
                    showDrillResult = true
                }) {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(NSLocalizedString("idpa_raw_time", comment: "Raw time label"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Text(format(time: summary.totalTime))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 80)
                        
                        VStack(spacing: 4) {
                            Text(NSLocalizedString("idpa_points_down", comment: "Points down label"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(abs(pointsDown))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 80)

                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text(NSLocalizedString("idpa_final_time", comment: "Final time label"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Text(format(time: finalTime))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .frame(minWidth: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            
            // Zone breakdown
            IDPAZoneBreakdownView(breakdown: breakdown, pointsDown: pointsDown)
                .padding(.horizontal, 20)
            
            // Replay button
            Button(action: {
                selectedSummary = summary
                showDrillReplay = true
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(NSLocalizedString("drill_replay", comment: "Replay button"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.3))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            // Edit zones button
            Button(action: {
                editingSummary = summary
                showEditDialog = true
            }) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(NSLocalizedString("edit_zones", comment: "Edit zones button"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            Text(NSLocalizedString("no_results_title", comment: "No results title"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(NSLocalizedString("no_results_message", comment: "No results message"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func format(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%.3fs", time)
        }
    }
}

// MARK: - IDPA Zone Breakdown View

struct IDPAZoneBreakdownView: View {
    let breakdown: [String: Int]
    let pointsDown: Int
    
    private let zoneColors: [String: Color] = [
        "Head": Color(red: 0.5, green: 1.0, blue: 0.5),  // Light green
        "Body": Color(red: 1.0, green: 0.8, blue: 0.2),  // Yellow
        "Other": Color(red: 1.0, green: 0.5, blue: 0.2), // Orange
        "Miss": Color(red: 1.0, green: 0.3, blue: 0.3)   // Red
    ]
    
    private let zonePoints: [String: Int] = [
        "Head": 0,
        "Body": -1,
        "Other": -3,
        "Miss": -5
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("idpa_zones_breakdown", comment: "Zones breakdown title"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            HStack(spacing: 8) {
                ForEach(["Head", "Body", "Other", "Miss"], id: \.self) { zone in
                    let count = breakdown[zone] ?? 0
                    let points = zonePoints[zone] ?? 0
                    
                    VStack(spacing: 6) {
                        Circle()
                            .fill(zoneColors[zone] ?? .gray)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(zone.prefix(1))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            )
                        
                        Text("\(count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        if points != 0 {
                            Text("\(points)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(points < 0 ? Color.red : Color.green)
                        } else {
                            Text("0")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(zoneColors[zone]?.opacity(0.1) ?? Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Total points down summary
            HStack {
                Text(NSLocalizedString("idpa_total_points_down", comment: "Total points down label"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(String(format: "-%d", abs(pointsDown)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Edit Dialog

struct IDPAZoneEditDialog: View {
    let summary: DrillRepeatSummary
    let onSave: ([String: Int]) -> Void
    let onCancel: () -> Void
    
    @State private var headCount: Int
    @State private var bodyCount: Int
    @State private var otherCount: Int
    @State private var missCount: Int
    
    init(summary: DrillRepeatSummary, onSave: @escaping ([String: Int]) -> Void, onCancel: @escaping () -> Void) {
        self.summary = summary
        self.onSave = onSave
        self.onCancel = onCancel
        
        let breakdown = ScoringUtility.getIDPAZoneBreakdown(shots: summary.shots)
        _headCount = State(initialValue: breakdown["Head"] ?? 0)
        _bodyCount = State(initialValue: breakdown["Body"] ?? 0)
        _otherCount = State(initialValue: breakdown["Other"] ?? 0)
        _missCount = State(initialValue: breakdown["Miss"] ?? 0)
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(NSLocalizedString("edit_idpa_zones", comment: "Edit IDPA zones title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    zoneEditor(label: NSLocalizedString("idpa_zone_head", comment: "Head zone"), count: $headCount)
                    zoneEditor(label: NSLocalizedString("idpa_zone_body", comment: "Body zone"), count: $bodyCount)
                    zoneEditor(label: NSLocalizedString("idpa_zone_other", comment: "Other zone"), count: $otherCount)
                    zoneEditor(label: NSLocalizedString("idpa_zone_miss", comment: "Miss zone"), count: $missCount)
                }
                
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(NSLocalizedString("cancel", comment: "Cancel button"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        let updatedZones: [String: Int] = [
                            "Head": headCount,
                            "Body": bodyCount,
                            "Other": otherCount,
                            "Miss": missCount
                        ]
                        onSave(updatedZones)
                    }) {
                        Text(NSLocalizedString("save", comment: "Save button"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
            )
            .padding(20)
        }
    }
    
    private func zoneEditor(label: String, count: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { if count.wrappedValue > 0 { count.wrappedValue -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
                
                Text("\(count.wrappedValue)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                
                Button(action: { count.wrappedValue += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    let mockSummary = DrillRepeatSummary(
        repeatIndex: 1,
        totalTime: 25.5,
        numShots: 4,
        firstShot: 0.5,
        fastest: 0.8,
        score: 0,
        shots: []
    )
    
    let mockDrillSetup = DrillSetup(context: PersistenceController.preview.container.viewContext)
    mockDrillSetup.name = "IDPA Drill"
    mockDrillSetup.mode = "idpa"
    
    return NavigationStack {
        IDPADrillSummaryView(drillSetup: mockDrillSetup, summaries: [mockSummary])
    }
}
