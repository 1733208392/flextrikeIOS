import SwiftUI

// MARK: - Accent colour (matches the app's red)
private let accentRed = Color(red: 0.871, green: 0.220, blue: 0.137)
private let darkBg    = Color.black
private let cardBg    = Color(white: 0.10)
private let textPrimary   = Color.white
private let textSecondary = Color(white: 0.67)

// MARK: - Entry Point

/// Full-screen cover that drives the IPSC score-submission flow.
/// Present it with `.fullScreenCover(isPresented:)`.
struct IpscSubmitView: View {

    @ObservedObject var viewModel: IpscSubmitViewModel
    let summaries: [DrillRepeatSummary]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()
            stepContent
        }
        .onAppear {
            viewModel.summaries = summaries
            if case .idle = viewModel.step { viewModel.start() }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .idle:
            LoadingStepView(message: NSLocalizedString("ipsc_submit_loading_context", comment: "Loading locked competition context"))

        case .confirm(let context):
            ConfirmStep(
                context: context,
                summaries: summaries,
                onSubmit: { summary in
                    viewModel.submit(context: context, summary: summary, isDq: false)
                },
                onBack: { viewModel.back() },
                onDismiss: onDismiss
            )

        case .submitting:
            LoadingStepView(message: NSLocalizedString("ipsc_submit_submitting", comment: "Submitting score"))

        case .success(let hitFactor, let totalPoints):
            SuccessStep(hitFactor: hitFactor, totalPoints: totalPoints, onClose: onDismiss)

        case .error(let message):
            ErrorStep(
                message: message,
                onRetry: { viewModel.start() },
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Loading

private struct LoadingStepView: View {
    let message: String
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(accentRed)
                .scaleEffect(1.4)
            Text(message)
                .foregroundColor(textSecondary)
                .font(.system(size: 15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkBg.ignoresSafeArea())
    }
}

// MARK: - Confirm Step

private struct ConfirmStep: View {
    let context: IpscLockedSelectionContext
    let summaries: [DrillRepeatSummary]
    let onSubmit: (DrillRepeatSummary) -> Void
    let onBack: () -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0

    private var selectedSummary: DrillRepeatSummary {
        summaries.indices.contains(selectedIndex) ? summaries[selectedIndex] : summaries[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            StepNavBar(title: NSLocalizedString("ipsc_submit_confirm_title", comment: "Confirm and submit title"), onBack: onBack)
            ScrollView {
                VStack(spacing: 16) {
                    // Shooter card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("ipsc_submit_shooter", comment: "Shooter section title"))
                            .foregroundColor(textSecondary)
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.16))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(accentRed.opacity(0.6), lineWidth: 1))
                                Text(context.shooter.bibNumber)
                                    .foregroundColor(accentRed)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(context.shooter.name ?? NSLocalizedString("unknown_athlete", comment: ""))
                                    .foregroundColor(textPrimary)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(shooterMetadata(context.shooter))
                                    .foregroundColor(textSecondary)
                                    .font(.system(size: 12))
                            }
                        }

                        Divider().background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(context.matchName) · \(context.stageName)")
                                .foregroundColor(textPrimary)
                                .font(.system(size: 12, weight: .semibold))
                            Text(context.squadName)
                                .foregroundColor(textSecondary)
                                .font(.system(size: 11))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBg)
                    .cornerRadius(12)

                    // Repeat picker (only when >1 repeat)
                    if summaries.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("ipsc_submit_select_repeat", comment: "Select repeat title"))
                                .foregroundColor(textSecondary)
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(summaries.indices, id: \.self) { i in
                                        let isSelected = i == selectedIndex
                                        Button { selectedIndex = i } label: {
                                            Text("R\(summaries[i].repeatIndex)")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(isSelected ? .white : textSecondary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(isSelected ? accentRed : Color(white: 0.16))
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBg)
                        .cornerRadius(12)
                    }

                    // Score preview
                    ScorePreviewCard(summary: selectedSummary)

                    // Submit button
                    Button { onSubmit(selectedSummary) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(NSLocalizedString("ipsc_submit_submit_score", comment: "Submit score button"))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentRed)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
        }
        .background(darkBg.ignoresSafeArea())
    }
}

private func shooterMetadata(_ shooter: IpscShooter) -> String {
    var parts: [String] = []
    if !shooter.divisionName.isEmpty {
        parts.append(shooter.divisionName)
    }
    if let category = shooter.categoryName, !category.isEmpty {
        parts.append(category)
    } else if !shooter.powerFactor.isEmpty {
        parts.append(shooter.powerFactor.prefix(1).uppercased() + shooter.powerFactor.dropFirst())
    }
    return parts.joined(separator: " · ")
}

// MARK: - Score Preview Card

private struct ScorePreviewCard: View {
    let summary: DrillRepeatSummary

    private var hitZones: [String: Int] {
        if let zones = summary.adjustedHitZones, !zones.isEmpty { return zones }
        return ScoringUtility.calculateEffectiveCounts(shots: summary.shots, drillSetup: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: NSLocalizedString("ipsc_submit_score_preview_repeat", comment: "Score preview repeat format"), summary.repeatIndex))
                .foregroundColor(textSecondary)
                .font(.system(size: 11, weight: .bold))
                .kerning(1)

            HStack {
                ForEach(["A", "C", "D", "M", "N", "PE"], id: \.self) { zone in
                    Spacer(minLength: 0)
                    ZoneItem(zone: zone, value: hitZones[zone] ?? 0)
                    Spacer(minLength: 0)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                TimeItem(label: NSLocalizedString("ipsc_submit_time", comment: "Time label"), value: String(format: "%.2fs", summary.totalTime))
                Spacer()
                TimeItem(label: NSLocalizedString("ipsc_submit_first_shot", comment: "First shot label"), value: summary.firstShot > 0 ? String(format: "%.2fs", summary.firstShot) : "-")
                Spacer()
                TimeItem(label: NSLocalizedString("ipsc_submit_fastest", comment: "Fastest label"), value: summary.fastest > 0 ? String(format: "%.2fs", summary.fastest) : "-")
            }
        }
        .padding(16)
        .background(cardBg)
        .cornerRadius(12)
    }
}

private struct ZoneItem: View {
    let zone: String
    let value: Int
    var color: Color {
        switch zone {
        case "A":           return Color(red: 0.30, green: 0.69, blue: 0.31)
        case "C":           return Color(red: 1.00, green: 0.92, blue: 0.23)
        case "D":           return Color(red: 1.00, green: 0.60, blue: 0.00)
        default:            return accentRed
        }
    }
    var body: some View {
        VStack(spacing: 2) {
            Text(zone)
                .foregroundColor(textSecondary)
                .font(.system(size: 10, weight: .medium))
            Text("\(value)")
                .foregroundColor(color)
                .font(.system(size: 20, weight: .bold))
        }
    }
}

private struct TimeItem: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(textSecondary)
                .font(.system(size: 10))
            Text(value)
                .foregroundColor(textPrimary)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

// MARK: - Success Step

private struct SuccessStep: View {
    let hitFactor: Double
    let totalPoints: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            Text(NSLocalizedString("ipsc_submit_success_title", comment: "Score submitted title"))
                .foregroundColor(textPrimary)
                .font(.system(size: 22, weight: .bold))

            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("ipsc_submit_hit_factor", comment: "Hit factor label"))
                            .foregroundColor(textSecondary)
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1)
                        Text(String(format: "%.4f", hitFactor))
                            .foregroundColor(.green)
                            .font(.system(size: 28, weight: .black))
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 50)
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("ipsc_submit_total_points", comment: "Total points label"))
                            .foregroundColor(textSecondary)
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1)
                        Text("\(totalPoints)")
                            .foregroundColor(textPrimary)
                            .font(.system(size: 28, weight: .black))
                    }
                }
                .padding(20)
                .background(cardBg)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onClose) {
                Text(NSLocalizedString("done", comment: "Done button"))
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkBg.ignoresSafeArea())
    }
}

// MARK: - Error Step

private struct ErrorStep: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(accentRed)
            Text(NSLocalizedString("ipsc_submit_error_title", comment: "Error title"))
                .foregroundColor(textPrimary)
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .foregroundColor(textSecondary)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text(NSLocalizedString("retry", comment: "Retry button"))
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentRed)
                        .cornerRadius(12)
                }
                Button(action: onDismiss) {
                    Text(NSLocalizedString("cancel", comment: "Cancel button"))
                        .foregroundColor(textSecondary)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(white: 0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkBg.ignoresSafeArea())
    }
}

// MARK: - Shared Nav Bar

private struct StepNavBar: View {
    let title: String
    let onBack: () -> Void
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String = "arrow.clockwise"

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentRed)
            }
            Text(title)
                .foregroundColor(textPrimary)
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            if let action = trailingAction {
                Button(action: action) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 17))
                        .foregroundColor(accentRed)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(darkBg.opacity(0.95))
    }
}

