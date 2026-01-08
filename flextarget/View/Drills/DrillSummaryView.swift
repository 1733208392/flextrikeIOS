import SwiftUI
import CoreData
import Foundation

// MARK: - DetailData Codable Struct
struct DetailData: Codable {
    let drillName: String
    let score: Int
    let factor: Double
    let totalTime: TimeInterval
    let numShots: Int
    let fastest: TimeInterval
    let firstShot: TimeInterval
    let shotData: [ShotData]
    let hitZones: [String: Int]?
    let athleteName: String?
    let athleteClub: String?
    
    enum CodingKeys: String, CodingKey {
        case drillName
        case score
        case factor
        case totalTime
        case numShots
        case fastest
        case firstShot
        case shotData
        case hitZones
        case athleteName
        case athleteClub
    }
}

struct DrillSummaryView: View {
    let drillSetup: DrillSetup
    @State var summaries: [DrillRepeatSummary]
    var competition: Competition? = nil
    @State private var originalScores: [UUID: Int] = [:]
    @State private var penaltyCounts: [UUID: Int] = [:]
    @State private var editingSummary: DrillRepeatSummary? = nil
    
    // Submission state
    @State private var isSubmitting = false
    @State private var showSubmitAlert = false
    @State private var submitAlertTitle = ""
    @State private var submitAlertMessage = ""
    @State private var submitError: Error? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var environmentContext
    @EnvironmentObject private var bleManager: BLEManager

    // Use the shared persistence controller's viewContext as a fallback to
    // ensure we always point at a live store even if the environment is missing
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

    private func metrics(for summary: DrillRepeatSummary) -> [SummaryMetric] {
        // Calculate effective score using adjusted hit zones if available
        let effectiveScore: Int
        if let adjustedHitZones = summary.adjustedHitZones {
            effectiveScore = ScoringUtility.calculateScoreFromAdjustedHitZones(adjustedHitZones, drillSetup: drillSetup)
        } else if summary.score > 0 {
            effectiveScore = summary.score
        } else {
            // For fresh summaries, calculate score from shot data
            effectiveScore = Int(ScoringUtility.calculateTotalScore(shots: summary.shots, drillSetup: drillSetup))
        }
        
        let factor = calculateFactor(score: effectiveScore, time: summary.totalTime)
        
        return [
            SummaryMetric(iconName: "clock.arrow.circlepath", label: NSLocalizedString("total_time_label", comment: "Total time metric label"), value: format(time: summary.totalTime)),
            SummaryMetric(iconName: "scope", label: NSLocalizedString("shots_metric_label", comment: "Shots metric label"), value: "\(summary.numShots)"),
            SummaryMetric(iconName: "bolt.circle", label: NSLocalizedString("fastest_label", comment: "Fastest shot label"), value: format(time: summary.fastest)),
            SummaryMetric(iconName: "timer", label: NSLocalizedString("first_shot_label", comment: "First shot label"), value: format(time: summary.firstShot)),
            SummaryMetric(iconName: "flame.fill", label: NSLocalizedString("score_label", comment: "Score label"), value: "\(effectiveScore)"),
            SummaryMetric(iconName: "percent", label: NSLocalizedString("factor_label", comment: "Factor label"), value: String(format: "%.3f", factor))
        ]
    }

    private func hitZoneMetrics(for summary: DrillRepeatSummary) -> [SummaryMetric] {
        if let adjusted = summary.adjustedHitZones,
           adjusted.keys.contains(where: { ["A", "C", "D", "N", "M", "PE"].contains($0) }) {
            return [
                SummaryMetric(iconName: "a.circle.fill", label: "A", value: "\(adjusted["A"] ?? 0)"),
                SummaryMetric(iconName: "c.circle.fill", label: "C", value: "\(adjusted["C"] ?? 0)"),
                SummaryMetric(iconName: "d.circle.fill", label: "D", value: "\(adjusted["D"] ?? 0)"),
                SummaryMetric(iconName: "xmark.circle.fill", label: "N", value: "\(adjusted["N"] ?? 0)"),
                SummaryMetric(iconName: "slash.circle.fill", label: "M", value: "\(adjusted["M"] ?? 0)"),
                SummaryMetric(iconName: "exclamationmark.triangle.fill", label: "PE", value: "\(adjusted["PE"] ?? 0)")
            ]
        }
        
        // Use centralized ScoringUtility to get effective counts for fallback
        let effectiveCounts = ScoringUtility.calculateEffectiveCounts(shots: summary.shots, drillSetup: drillSetup)

        return [
            SummaryMetric(iconName: "a.circle.fill", label: "A", value: "\(effectiveCounts["A"] ?? 0)"),
            SummaryMetric(iconName: "c.circle.fill", label: "C", value: "\(effectiveCounts["C"] ?? 0)"),
            SummaryMetric(iconName: "d.circle.fill", label: "D", value: "\(effectiveCounts["D"] ?? 0)"),
            SummaryMetric(iconName: "xmark.circle.fill", label: "N", value: "\(effectiveCounts["N"] ?? 0)"),
            SummaryMetric(iconName: "slash.circle.fill", label: "M", value: "\(effectiveCounts["M"] ?? 0)"),
            SummaryMetric(iconName: "exclamationmark.triangle.fill", label: "PE", value: "\(effectiveCounts["PE"] ?? 0)")
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

    private func missedTargets(for summary: DrillRepeatSummary) -> Int {
        return ScoringUtility.calculateMissedTargets(shots: summary.shots, drillSetup: drillSetup)
    }

    private func deductScore(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        let summaryId = summaries[index].id
        
        withAnimation(.easeInOut(duration: 0.3)) {
            penaltyCounts[summaryId, default: 0] += 1
        }
        
        // Recalculate score using centralized ScoringUtility
        recalculateScore(at: index)
        
        // Save penalty count to Core Data
        savePenaltyCount(at: index)
    }

    private func restoreScore(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        let summaryId = summaries[index].id
        
        withAnimation(.easeInOut(duration: 0.3)) {
            penaltyCounts[summaryId] = 0
        }
        
        // Recalculate score using centralized ScoringUtility
        recalculateScore(at: index)
        
        // Save penalty count (reset to 0) to Core Data
        savePenaltyCount(at: index)
    }

    private func recalculateScore(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        let summaryId = summaries[index].id
        let penaltyCount = penaltyCounts[summaryId, default: 0]
        
        // Get current adjusted hit zones or create from shots
        var adjustedZones = summaries[index].adjustedHitZones ?? [:]
        
        // If this is the first time adjusting, initialize with adjusted hit zone counts (after applying scoring rules)
        if adjustedZones.isEmpty {
            // Use centralized ScoringUtility to get effective counts
            let effectiveCounts = ScoringUtility.calculateEffectiveCounts(shots: summaries[index].shots, drillSetup: drillSetup)
            
            adjustedZones["A"] = effectiveCounts["A"] ?? 0
            adjustedZones["C"] = effectiveCounts["C"] ?? 0
            adjustedZones["D"] = effectiveCounts["D"] ?? 0
            adjustedZones["N"] = effectiveCounts["N"] ?? 0
            adjustedZones["M"] = effectiveCounts["M"] ?? 0
            adjustedZones["PE"] = effectiveCounts["PE"] ?? 0
        }
        
        // Update the penalty count (manual + auto from missed targets)
        adjustedZones["PE"] = penaltyCount + missedTargets(for: summaries[index])
        
        // Update the summary
        summaries[index].adjustedHitZones = adjustedZones
        
        // Recalculate score using centralized ScoringUtility
        let recalculatedScore = ScoringUtility.calculateScoreFromAdjustedHitZones(adjustedZones, drillSetup: drillSetup)
        summaries[index].score = recalculatedScore
    }

    private func initializeOriginalScores() {
        for summary in summaries {
            if originalScores[summary.id] == nil {
                originalScores[summary.id] = summary.score
            }
            if penaltyCounts[summary.id] == nil {
                // Load penalty count from adjusted hit zones if available, subtracting auto-calculated missed targets
                let totalPE = summary.adjustedHitZones?["PE"] ?? 0
                let missed = missedTargets(for: summary)
                penaltyCounts[summary.id] = totalPE - missed
            }
        }
    }
    
    private func savePenaltyCount(at index: Int) {
        guard index >= 0 && index < summaries.count else { return }
        
        // The adjustedHitZones are already updated by recalculateScore()
        // Just save the current adjustedHitZones to Core Data
        if let drillResultId = summaries[index].drillResultId,
           let adjustedZones = summaries[index].adjustedHitZones {
            let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
            fetchRequest.predicate = NSPredicate(format: "id == %@", drillResultId as CVarArg)
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let result = results.first {
                    if let jsonData = try? JSONEncoder().encode(adjustedZones),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        result.adjustedHitZones = jsonString
                        try viewContext.save()
                    } else {
                        print("savePenaltyCount: Failed to encode JSON")
                    }
                } else {
                    print("savePenaltyCount: No DrillResult found with id \(drillResultId)")
                }
            } catch {
                print("Failed to save penalty count: \(error)")
            }
        } else {
            print("savePenaltyCount: drillResultId is nil or adjustedHitZones is nil")
        }
    }
    
    // MARK: - Submission Methods
    
    private func submitCompetitionResult() {
        // Validate prerequisites
        guard let competition = competition else {
            showSubmitError(title: NSLocalizedString("error_title", comment: "Error"), message: NSLocalizedString("no_competition_error", comment: "No competition associated with this result"))
            return
        }
        
        guard let competitionId = competition.id else {
            showSubmitError(title: NSLocalizedString("error_title", comment: "Error"), message: NSLocalizedString("invalid_competition_id_error", comment: "Invalid competition ID"))
            return
        }
        
        guard bleManager.isConnected else {
            showSubmitError(title: NSLocalizedString("device_disconnected_title", comment: "Device Disconnected"), message: NSLocalizedString("connect_device_before_submit", comment: "Please connect to the device before submitting"))
            return
        }
        
        guard let deviceToken = DeviceAuthManager.shared.deviceToken, !deviceToken.isEmpty else {
            showSubmitError(title: NSLocalizedString("device_auth_required_title", comment: "Device Auth Required"), message: NSLocalizedString("device_token_unavailable", comment: "Device authentication token is not available. Please ensure device is properly connected"))
            return
        }
        
        guard let userToken = AuthManager.shared.currentUser?.accessToken, !userToken.isEmpty else {
            showSubmitError(title: NSLocalizedString("not_authenticated_title", comment: "Not Authenticated"), message: NSLocalizedString("login_before_submit", comment: "Please log in before submitting results"))
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                // Prepare submission data from first summary (main result)
                guard let firstSummary = summaries.first else {
                    throw NSError(domain: "DrillSummaryView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No drill summary available"])
                }
                
                // Recalculate adjusted hit zones to ensure we submit the latest counts
                let submissionHitZones: [String: Int] = {
                    if let zones = firstSummary.adjustedHitZones, zones.isEmpty == false {
                        return zones
                    }
                    return ScoringUtility.calculateEffectiveCounts(shots: firstSummary.shots, drillSetup: drillSetup)
                }()

                let finalScore = ScoringUtility.calculateScoreFromAdjustedHitZones(submissionHitZones, drillSetup: drillSetup)
                
                // Calculate factor
                let factor = calculateFactor(score: finalScore, time: firstSummary.totalTime)
                // For IPSC, the ranking score is the hit factor (score/time); otherwise use total score
                let rankingScore: Double = (competition.drillSetup?.mode?.lowercased() == "ipsc") ? factor : Double(finalScore)
                
                // Format play time
                let playTime = formatPlayTime(Date())
                
                // Extract athlete information from the drill result if available
                var athleteName: String? = nil
                var athleteClub: String? = nil
                
                if let drillResultId = firstSummary.drillResultId {
                    let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", drillResultId as CVarArg)
                    fetchRequest.fetchLimit = 1
                    
                    if let result = try? viewContext.fetch(fetchRequest).first,
                       let athlete = result.athlete {
                        athleteName = athlete.name
                        athleteClub = athlete.club
                    }
                }
                
                // Create DetailData struct with shot data and athlete info
                let detailData = DetailData(
                    drillName: drillSetup.name ?? "Unknown",
                    score: finalScore,
                    factor: factor,
                    totalTime: firstSummary.totalTime,
                    numShots: firstSummary.numShots,
                    fastest: firstSummary.fastest,
                    firstShot: firstSummary.firstShot,
                    shotData: firstSummary.shots,
                    hitZones: submissionHitZones,
                    athleteName: athleteName,
                    athleteClub: athleteClub
                )
                
                // Encode DetailData to JSON and convert to dictionary
                let encodedData = try JSONEncoder().encode(detailData)
                let detail = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] ?? [:]
                
                // Submit to server
                let response = try await CompetitionResultAPIService.shared.addGamePlay(
                    gameType: competitionId.uuidString,  // Competition ID
                    gameVer: "1.0",
                    score: Float(rankingScore),
                    detail: detail,
                    playTime: playTime,
                    playerMobile: AuthManager.shared.currentUser?.mobile,
                    playerNickname: AuthManager.shared.currentUser?.username,
                    isPublic: true
                )
                
                // Save response data to Core Data (link play_uuid back to local result)
                if let drillResultId = firstSummary.drillResultId {
                    let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", drillResultId as CVarArg)
                    
                    let results = try viewContext.fetch(fetchRequest)
                    if let result = results.first {
                        // Store server response data
                        result.serverPlayId = response.play_uuid
                        result.serverDeviceId = response.device_uuid
                        result.submittedAt = Date()
                        try viewContext.save()
                    }
                }
                
                await MainActor.run {
                    isSubmitting = false
                    showSubmitSuccess(title: NSLocalizedString("success_title", comment: "Success"), message: NSLocalizedString("submit_success_message", comment: "Competition result submitted successfully"))
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showSubmitError(title: NSLocalizedString("submit_failed_title", comment: "Submission Failed"), message: error.localizedDescription)
                }
            }
        }
    }
    
    private func formatPlayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func showSubmitError(title: String, message: String) {
        submitAlertTitle = title
        submitAlertMessage = message
        submitError = NSError(domain: "Submit", code: -1)
        showSubmitAlert = true
    }
    
    private func showSubmitSuccess(title: String, message: String) {
        submitAlertTitle = title
        submitAlertMessage = message
        submitError = nil
        showSubmitAlert = true
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
                                VStack(spacing: 12) {
                                    NavigationLink(destination: DrillResultView(drillSetup: drillSetup, repeatSummary: summaries[index])) {
                                        summaryCard(
                                            title: String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex),
                                            subtitle: AnyView(EmptyView()),
                                            iconName: "scope",
                                            metrics: metrics(for: summaries[index]),
                                            hitZoneMetrics: hitZoneMetrics(for: summaries[index]),
                                            summaryIndex: index
                                        )
                                    }
                                    
                                    NavigationLink(destination: DrillReplayView(drillSetup: drillSetup, shots: summaries[index].shots)) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 16, weight: .bold))
                                            Text(NSLocalizedString("watch_replay_button", comment: "Watch replay button text"))
                                                .font(.system(size: 14, weight: .bold))
                                                .kerning(0.5)
                                        }
                                        .foregroundColor(.red)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.red.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .padding(.horizontal, 20)
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
        .sheet(item: $editingSummary) { summary in
            SummaryEditSheet(
                summary: summary,
                onSave: { updatedZones in
                    // Find the index of the summary being edited
                    if let index = summaries.firstIndex(where: { $0.id == summary.id }) {
                        // Use the PE count from the edit sheet
                        var finalZones = updatedZones
                        
                        summaries[index].adjustedHitZones = finalZones
                        
                        // Update penalty count state (subtract auto-calculated missed targets)
                        penaltyCounts[summary.id] = (finalZones["PE"] ?? 0) - missedTargets(for: summaries[index])
                        
                        // Persist to Core Data
                        if let drillResultId = summaries[index].drillResultId {
                            let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
                            fetchRequest.predicate = NSPredicate(format: "id == %@", drillResultId as CVarArg)
                            do {
                                let results = try viewContext.fetch(fetchRequest)
                                if let result = results.first {
                                    if let jsonData = try? JSONEncoder().encode(finalZones),
                                       let jsonString = String(data: jsonData, encoding: .utf8) {
                                        result.adjustedHitZones = jsonString
                                        try viewContext.save()
                                    }
                                }
                            } catch {
                                print("Failed to save adjusted hit zones: \(error)")
                            }
                        }
                    }
                    editingSummary = nil
                },
                onCancel: {
                    editingSummary = nil
                }
            )
        }
        .alert(NSLocalizedString("alert_title", comment: "Alert"), isPresented: $showSubmitAlert) {
            Button(NSLocalizedString("ok_button", comment: "OK button")) {
                if submitError == nil {
                    // Success - dismiss the view
                    dismiss()
                }
            }
        } message: {
            Text(submitAlertMessage)
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
            
            if competition != nil {
                Text(NSLocalizedString("competition", comment: "Competition badge"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(4)
            }

            Spacer()
            
            // Submit button - only for competition results
            if competition != nil {
                let isSubmittingNow = isSubmitting
                let isDeviceConnected = bleManager.isConnected
                let deviceTokenExists = DeviceAuthManager.shared.deviceToken != nil
                let isButtonDisabled = isSubmittingNow || !isDeviceConnected || !deviceTokenExists
                
                Button(action: {
                    print("=== Submit Button Tapped ===")
                    print("isSubmitting: \(isSubmittingNow)")
                    print("bleManager.isConnected: \(isDeviceConnected)")
                    print("deviceToken: \(DeviceAuthManager.shared.deviceToken ?? "nil")")
                    print("Button disabled: \(isButtonDisabled)")
                    print("============================")
                    if !isButtonDisabled {
                        submitCompetitionResult()
                    } else {
                        print("Button is disabled - action not triggered")
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        
                        if isSubmitting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isButtonDisabled)
                .opacity(isButtonDisabled ? 0.5 : 1.0)
                .onAppear {
                    print("=== NavigationBar onAppear ===")
                    print("competition: \(competition != nil)")
                    print("bleManager.isConnected: \(bleManager.isConnected)")
                    print("deviceToken: \(DeviceAuthManager.shared.deviceToken ?? "nil")")
                    print("================================")
                }
            }
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

    private func summaryCard(title: String, subtitle: some View, iconName: String, metrics: [SummaryMetric], hitZoneMetrics: [SummaryMetric], summaryIndex: Int) -> some View {
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

                    subtitle
                }

                Spacer()
                
                // PE Button for penalty deduction
                PenaltyButton(action: {
                    deductScore(at: summaryIndex)
                }, penaltyCount: penaltyCounts[summaries[summaryIndex].id, default: 0] + missedTargets(for: summaries[summaryIndex]))
                
                // Restore Button
                RestoreButton(action: {
                    restoreScore(at: summaryIndex)
                })
            }

            Divider()
                .overlay(Color.white.opacity(0.2))

            // First row: Current metrics
            HStack(spacing: 12) {
                ForEach(metrics) { metric in
                    metricView(metric)
                }
            }

            // Second row: Hit zone metrics
            HStack(spacing: 12) {
                ForEach(hitZoneMetrics.indices, id: \.self) { metricIndex in
                    let metric = hitZoneMetrics[metricIndex]
                    Button(action: {
                        editingSummary = summaries[summaryIndex]
                    }) {
                        metricView(metric)
                    }
                    .buttonStyle(PlainButtonStyle())
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
    let penaltyCount: Int
    
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

                VStack(spacing: 0) {
                    Text("PE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    
                    if penaltyCount > 0 {
                        Text("\(penaltyCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
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

// MARK: - Summary Edit Sheet
struct SummaryEditSheet: View {
    let summary: DrillRepeatSummary
    let onSave: ([String: Int]) -> Void
    let onCancel: () -> Void

    @Environment(\.managedObjectContext) private var environmentContext

    // Use the shared persistence controller's viewContext as a fallback to
    // ensure we always point at a live store even if the environment is missing
    private var viewContext: NSManagedObjectContext {
        if let coordinator = environmentContext.persistentStoreCoordinator,
           coordinator.persistentStores.isEmpty == false {
            return environmentContext
        }
        return PersistenceController.shared.container.viewContext
    }

    @State private var showAthletePicker: Bool = false
    @State private var showLeaderboard: Bool = false
    @State private var showError: Bool = false
    @State private var errorTitle: String = NSLocalizedString("error_title", comment: "Generic error title")
    @State private var errorMessage: String = ""
    
    @State private var aCount: Int
    @State private var cCount: Int
    @State private var dCount: Int
    @State private var nCount: Int
    @State private var mCount: Int
    @State private var peCount: Int
    
    init(summary: DrillRepeatSummary, onSave: @escaping ([String: Int]) -> Void, onCancel: @escaping () -> Void) {
        self.summary = summary
        self.onSave = onSave
        self.onCancel = onCancel
        
        let adjusted = summary.adjustedHitZones
        
        let aZoneCount = summary.shots.filter { $0.content.hitArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "azone" }.count
        let cZoneCount = summary.shots.filter { $0.content.hitArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "czone" }.count
        let dZoneCount = summary.shots.filter { $0.content.hitArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "dzone" }.count
        let noShootCount = summary.shots.filter {
            let area = $0.content.hitArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return area == "blackzone" || area == "whitezone"
        }.count
        let missCount = summary.shots.filter {
            let area = $0.content.hitArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return area == "miss" || area == "m" || area.isEmpty
        }.count
        
        _aCount = State(initialValue: adjusted?["A"] ?? aZoneCount)
        _cCount = State(initialValue: adjusted?["C"] ?? cZoneCount)
        _dCount = State(initialValue: adjusted?["D"] ?? dZoneCount)
        _nCount = State(initialValue: adjusted?["N"] ?? noShootCount)
        _mCount = State(initialValue: adjusted?["M"] ?? missCount)
        _peCount = State(initialValue: adjusted?["PE"] ?? 0)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header with title and close button
                HStack {
                    Text(NSLocalizedString("edit_hit_zone_counts_title", comment: "Title for editing hit zone counts"))
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        onCancel()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                VStack(spacing: 16) {
                    zoneStepper(label: NSLocalizedString("a_zone_label", comment: "A zone label"), icon: "a.circle.fill", count: $aCount)
                    zoneStepper(label: NSLocalizedString("c_zone_label", comment: "C zone label"), icon: "c.circle.fill", count: $cCount)
                    zoneStepper(label: NSLocalizedString("d_zone_label", comment: "D zone label"), icon: "d.circle.fill", count: $dCount)
                    zoneStepper(label: NSLocalizedString("no_shoot_label", comment: "No shoot zone label"), icon: "xmark.circle.fill", count: $nCount)
                    zoneStepper(label: NSLocalizedString("miss_label", comment: "Miss zone label"), icon: "slash.circle.fill", count: $mCount)
                    zoneStepper(label: NSLocalizedString("penalty_label", comment: "Penalty label"), icon: "minus.circle.fill", count: $peCount)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(NSLocalizedString("cancel_button", comment: "Cancel button text")) {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button(NSLocalizedString("save_button", comment: "Save button text")) {
                        let updated = [
                            "A": aCount,
                            "C": cCount,
                            "D": dCount,
                            "N": nCount,
                            "M": mCount,
                            "PE": peCount
                        ]
                        onSave(updated)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .sheet(isPresented: $showLeaderboard) {
            NavigationView {
                LeaderboardView()
                    .preferredColorScheme(.dark)
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text(errorTitle),
                message: Text(errorMessage),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button")))
            )
        }
    }
    
    private func zoneStepper(label: String, icon: String, count: Binding<Int>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.red)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack {
                Button(action: { if count.wrappedValue > 0 { count.wrappedValue -= 1 } }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
                
                Text("\(count.wrappedValue)")
                    .foregroundColor(.white)
                    .frame(width: 40)
                
                Button(action: { count.wrappedValue += 1 }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
    }
}
