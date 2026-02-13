import SwiftUI
import CoreData

struct CQBDrillSummaryView: View {
    let drillSetup: DrillSetup
    @State var summaries: [DrillRepeatSummary]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var environmentContext
    
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
                                cqbDrillCard(for: summaries[index], index: index)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
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
    
    // MARK: - CQB Drill Card
    
    private func cqbDrillCard(for summary: DrillRepeatSummary, index: Int) -> some View {
        VStack(spacing: 16) {
            // Header: Repeat number and basic stats
            VStack(spacing: 12) {
                HStack {
                    Text(String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summary.repeatIndex))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Stats row: Total shots and duration
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("cqb_total_shots", comment: "Total shots label"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(summary.numShots)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(minWidth: 60)
                    
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("cqb_duration", comment: "Duration label"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(format(time: summary.totalTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(minWidth: 60)

                    Spacer()
                    
                    if let cqbPassed = summary.cqbPassed {
                        HStack(spacing: 6) {
                            Image(systemName: cqbPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(cqbPassed ? NSLocalizedString("cqb_passed", comment: "Passed status") : NSLocalizedString("cqb_failed", comment: "Failed status"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(cqbPassed ? .green : Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
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
            
            // Card results: Target-by-target pass/fail
            if let cqbResults = summary.cqbResults, !cqbResults.isEmpty {
                VStack(spacing: 10) {
                    ForEach(cqbResults) { result in
                        targetCardRow(result)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Watch replay button
            NavigationLink(destination: DrillReplayView(drillSetup: drillSetup, shots: summary.shots)) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(NSLocalizedString("watch_replay_button", comment: "Watch replay button text"))
                        .font(.system(size: 14, weight: .bold))
                        .kerning(0.5)
                }
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Target Card Row
    
    private func targetCardRow(_ result: CQBShotResult) -> some View {
        HStack(spacing: 12) {
            // Card indicator (green or red circle)
            Image(systemName: result.cardStatus == .green ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(result.cardStatus == .green ? .green : Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            
            // Target info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(result.targetName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if result.isThreat {
                        Text(NSLocalizedString("cqb_threat", comment: "Threat label"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(4)
                    } else {
                        Text(NSLocalizedString("cqb_non_threat", comment: "Non-threat label"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                
                if let failureReason = result.failureReason {
                    Text(failureReason)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Shot count for threat targets
                if result.isThreat {
                    Text(String(format: NSLocalizedString("cqb_shots_format", comment: "Shots format"), result.actualValidShots, result.expectedShots))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.cardStatus == .green ? Color.green.opacity(0.08) : Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            result.cardStatus == .green ? Color.green.opacity(0.3) : Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
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

#Preview {
    let mockSummary = DrillRepeatSummary(
        repeatIndex: 1,
        totalTime: 45.5,
        numShots: 8,
        firstShot: 0.5,
        fastest: 0.8,
        score: 0,
        shots: [],
        cqbResults: [
            CQBShotResult(targetName: "cqb_front", isThreat: true, expectedShots: 2, actualValidShots: 2, cardStatus: .green),
            CQBShotResult(targetName: "cqb_swing", isThreat: true, expectedShots: 2, actualValidShots: 1, cardStatus: .red, failureReason: "Missed 1 shot"),
        ],
        cqbPassed: false
    )
    
    let mockDrillSetup = DrillSetup(context: PersistenceController.preview.container.viewContext)
    mockDrillSetup.name = "CQB Drill"
    mockDrillSetup.mode = "cqb"
    
    return NavigationStack {
        CQBDrillSummaryView(drillSetup: mockDrillSetup, summaries: [mockSummary])
    }
}
