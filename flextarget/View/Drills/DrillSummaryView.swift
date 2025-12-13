import SwiftUI
import CoreData

struct DrillSummaryView: View {
    let drillSetup: DrillSetup
    @State var summaries: [DrillRepeatSummary]
    @State private var originalScores: [UUID: Int] = [:]

    @Environment(\.dismiss) private var dismiss

    private var drillName: String {
        drillSetup.name ?? "Untitled Drill"
    }

    private func metrics(for summary: DrillRepeatSummary) -> [SummaryMetric] {
        [
            SummaryMetric(iconName: "clock.arrow.circlepath", label: NSLocalizedString("total_time_label", comment: "Total time metric label"), value: format(time: summary.totalTime)),
            SummaryMetric(iconName: "scope", label: NSLocalizedString("shots_metric_label", comment: "Shots metric label"), value: "\(summary.numShots)"),
            SummaryMetric(iconName: "bolt.circle", label: NSLocalizedString("fastest_label", comment: "Fastest shot label"), value: format(time: summary.fastest)),
            SummaryMetric(iconName: "timer", label: NSLocalizedString("first_shot_label", comment: "First shot label"), value: format(time: summary.firstShot)),
            SummaryMetric(iconName: "flame.fill", label: NSLocalizedString("score_label", comment: "Score label"), value: "\(summary.score)")
        ]
    }

    private func format(time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--" }
        return String(format: "%.2f s", time)
    }

    private func calculateFactor(score: Int, time: TimeInterval) -> Double {
        guard time > 0 else { return 0.0 }
        return Double(score) / time
    }

    private func deductScore(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        let deductionAmount = 10
        withAnimation(.easeInOut(duration: 0.3)) {
            summaries[index].score -= deductionAmount
        }
    }

    private func restoreScore(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        if let originalScore = originalScores[summaries[index].id] {
            withAnimation(.easeInOut(duration: 0.3)) {
                summaries[index].score = originalScore
            }
        }
    }

    private func initializeOriginalScores() {
        for summary in summaries {
            if originalScores[summary.id] == nil {
                originalScores[summary.id] = summary.score
            }
        }
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
                        VStack(spacing: 20) {
                            ForEach(summaries.indices, id: \.self) { index in
                                NavigationLink(destination: DrillResultView(drillSetup: drillSetup, repeatSummary: summaries[index])) {
                                    summaryCard(
                                        title: String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex),
                                        subtitle: "\(NSLocalizedString("factor_label", comment: "Factor label")): \(String(format: "%.2f", calculateFactor(score: summaries[index].score, time: summaries[index].totalTime)))",
                                        iconName: "scope",
                                        metrics: metrics(for: summaries[index]),
                                        summaryIndex: index
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            initializeOriginalScores()
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                        )

                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                }
                .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            Text(NSLocalizedString("drill_result_summary_title", comment: "Drill result summary title"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.95))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.red)
                .padding()

            Text(NSLocalizedString("no_summary_data_title", comment: "No summary data title"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            Text(NSLocalizedString("no_summary_data_subtitle", comment: "No summary data subtitle"))
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func summaryCard(title: String, subtitle: String, iconName: String, metrics: [SummaryMetric], summaryIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                        )

                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }

                Spacer()
                
                // PE Button for penalty deduction
                PenaltyButton(action: {
                    deductScore(at: summaryIndex)
                })
                
                // Restore Button
                RestoreButton(action: {
                    restoreScore(at: summaryIndex)
                })
            }

            Divider()
                .overlay(Color.white.opacity(0.2))

            HStack(spacing: 12) {
                ForEach(metrics) { metric in
                    metricView(metric)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: Color.red.opacity(0.15), radius: 12, x: 0, y: 8)
    }

    private func metricView(_ metric: SummaryMetric) -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: metric.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)

                Text(metric.label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(metric.value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .id(metric.value) // This helps SwiftUI track changes and animate them
                .transition(.scale.combined(with: .opacity))

            if let footnote = metric.footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        // .padding(.horizontal, 16)
        .background(metricGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.red.opacity(0.12), radius: 8, x: 0, y: 6)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.12, blue: 0.12),
                Color(red: 0.25, green: 0.05, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var metricGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.18, blue: 0.18),
                Color(red: 0.35, green: 0.07, blue: 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SummaryMetric: Identifiable {
    let id = UUID()
    let iconName: String
    let label: String
    let value: String
    let footnote: String?

    init(iconName: String, label: String, value: String, footnote: String? = nil) {
        self.iconName = iconName
        self.label = label
        self.value = value
        self.footnote = footnote
    }
}

// MARK: - Penalty Button
struct PenaltyButton: View {
    @State private var isPressed = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                    )

                Text("PE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            .shadow(color: Color.orange.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .onLongPressGesture(minimumDuration: 0.05, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        })
    }
}

// MARK: - Restore Button
struct RestoreButton: View {
    @State private var isPressed = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                    )

                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
            }
            .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .onLongPressGesture(minimumDuration: 0.05, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        })
    }
}