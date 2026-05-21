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
    var ipscContext: IpscLockedSelectionContext? = nil
    @State private var originalScores: [UUID: Int] = [:]
    @State private var penaltyCounts: [UUID: Int] = [:]
    
    // Submission state
    @State private var isSubmitting = false
    @State private var submitSuccessMessage: String? = nil
    @State private var submitErrorMessage: String? = nil

    @StateObject private var ipscSubmitViewModel = IpscSubmitViewModel()

    @State private var targetRows: [IpscEditableTargetRow] = []
    @State private var dqApplied = false
    @State private var pendingIpscAction: IpscPendingAction?

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
    
    private var isCQBMode: Bool {
        drillSetup.mode?.lowercased() == "cqb"
    }
    
    private var isIDPAMode: Bool {
        drillSetup.mode?.lowercased() == "idpa"
    }

    private var isResultAlreadySubmitted: Bool {
        guard let drillResultId = summaries.first?.drillResultId else { return false }
        let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
        fetchRequest.predicate = NSPredicate(format: "id == %@", drillResultId as CVarArg)
        fetchRequest.fetchLimit = 1
        if let result = try? viewContext.fetch(fetchRequest).first {
            return result.submittedAt != nil
        }
        return false
    }

    private var isIpscContextFlow: Bool {
        ipscContext != nil
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// True when this summary is being viewed as part of a competition session
    /// (either a generic competition or the IPSC locked-shooter flow). In that
    /// context we hide the DrillResultView/DrillReplayView navigations and the
    /// hit-zone edit sheet because the official scoring grid is the source of truth.
    private var isCompetitionFlow: Bool {
        competition != nil || isIpscContextFlow
    }

    private var shooterDivisionLine: String {
        guard let shooter = ipscContext?.shooter else { return "" }
        var parts: [String] = []
        if !shooter.divisionName.isEmpty {
            parts.append(shooter.divisionName)
        }
        if let category = shooter.categoryName, !category.isEmpty {
            parts.append(category)
        }
        return parts.joined(separator: " • ")
    }

    private var shouldShowDqBadge: Bool {
        dqApplied || (ipscContext?.shooter.isDq ?? false)
    }

    private var ipscRowPeTotal: Int {
        targetRows.reduce(0) { $0 + $1.pe }
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
            SummaryMetric(iconName: "clock.arrow.circlepath", label: NSLocalizedString("time_acronym", comment: "Time acronym"), value: format(time: summary.totalTime)),
            SummaryMetric(iconName: "scope", label: NSLocalizedString("shots_acronym", comment: "Shots acronym"), value: "\(summary.numShots)"),
            SummaryMetric(iconName: "bolt.circle", label: NSLocalizedString("fastest_acronym", comment: "Fastest acronym"), value: format(time: summary.fastest)),
            SummaryMetric(iconName: "timer", label: NSLocalizedString("first_shot_acronym", comment: "First shot acronym"), value: format(time: summary.firstShot)),
            SummaryMetric(iconName: "flame.fill", label: NSLocalizedString("score_acronym", comment: "Score acronym"), value: "\(effectiveScore)"),
            SummaryMetric(iconName: "percent", label: NSLocalizedString("factor_acronym", comment: "Factor acronym"), value: String(format: "%.3f", factor))
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
        // Check if already submitted
        if isResultAlreadySubmitted {
            showSubmitError(title: NSLocalizedString("already_submitted_title", comment: "Already Submitted"), message: NSLocalizedString("result_already_submitted_message", comment: "This result has already been submitted"))
            return
        }
        
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

        // Validate player nickname length (minimum 4 characters required by server)
        guard let playerNickname = AuthManager.shared.currentUser?.username, playerNickname.count >= 4 else {
            let displayNickname = AuthManager.shared.currentUser?.username ?? ""
            showSubmitError(
                title: NSLocalizedString("invalid_nickname_title", comment: "Invalid Nickname"),
                message: "Shooter name must be at least 4 characters (current: \(displayNickname.count))"
            )
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
                    gameVer: "1.0.0",
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            submitErrorMessage = message
        }
    }
    
    private func showSubmitSuccess(title: String, message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            submitSuccessMessage = message
        }
    }

    var body: some View {
        if isCQBMode {
            CQBDrillSummaryView(drillSetup: drillSetup, summaries: summaries)
        } else if isIDPAMode {
            IDPADrillSummaryView(drillSetup: drillSetup, summaries: summaries)
        } else {
            ipscDrillSummaryViewWithAllModifiers
        }
    }
    
    // MARK: - IPSC Drill Summary View
    
    private var ipscDrillSummaryView: some View {
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
                                    if isCompetitionFlow {
                                        summaryCard(
                                            title: isIpscContextFlow ? (ipscContext?.shooter.name ?? String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex)) : String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex),
                                            subtitle: AnyView(
                                                Group {
                                                    if isIpscContextFlow && !shooterDivisionLine.isEmpty {
                                                        Text(shooterDivisionLine)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            ),
                                            iconName: "scope",
                                            metrics: metrics(for: summaries[index]),
                                            hitZoneMetrics: hitZoneMetrics(for: summaries[index]),
                                            summaryIndex: index
                                        )
                                        .padding(.horizontal, 20)
                                    } else {
                                        NavigationLink(destination: DrillResultView(drillSetup: drillSetup, repeatSummary: summaries[index])) {
                                            summaryCard(
                                                title: isIpscContextFlow ? (ipscContext?.shooter.name ?? String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex)) : String(format: NSLocalizedString("repeat_number", comment: "Repeat number format"), summaries[index].repeatIndex),
                                                subtitle: AnyView(
                                                    Group {
                                                        if isIpscContextFlow && !shooterDivisionLine.isEmpty {
                                                            Text(shooterDivisionLine)
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.gray)
                                                        }
                                                    }
                                                ),
                                                iconName: "scope",
                                                metrics: metrics(for: summaries[index]),
                                                hitZoneMetrics: hitZoneMetrics(for: summaries[index]),
                                                summaryIndex: index
                                            )
                                        }
                                        .padding(.horizontal, 20)
                                        .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                    }
                                }
                            }

                            if isIpscContextFlow || isRunningPreview {
                                ipscInlineSubmitPanel
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 24)
                    }

                    if let replaySummary = summaries.first, !isCompetitionFlow {
                        NavigationLink(destination: DrillReplayView(drillSetup: drillSetup, shots: replaySummary.shots)) {
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
                        .padding(.bottom, 16)
                        .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    }
                }
            }

            // Error toast
            if let errorMsg = submitErrorMessage {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.87, green: 0.22, blue: 0.14))
                        Text(errorMsg)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(3)
                        Spacer()
                        Button(action: { withAnimation { submitErrorMessage = nil } }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.14, green: 0.04, blue: 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.87, green: 0.22, blue: 0.14).opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }

            // Success overlay
            if submitSuccessMessage != nil {
                Color.black.opacity(0.94)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(19)

                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.08))
                            .frame(width: 130, height: 130)
                        Circle()
                            .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 130, height: 130)
                        Image(systemName: "checkmark")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.green)
                    }

                    Spacer().frame(height: 36)

                    Text("SUBMITTED")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)

                    Spacer().frame(height: 12)

                    if let msg = submitSuccessMessage {
                        Text(msg)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation { submitSuccessMessage = nil }
                        dismiss()
                    }) {
                        Text(NSLocalizedString("done_button", comment: "Done button"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(20)
            }
        }
    }
    
    // MARK: - IPSC Drill Summary with Modifiers
    
    private var isGamingMode: Bool {
        drillSetup.mode?.lowercased() == "gaming"
    }

    private var ipscDrillSummaryViewWithAllModifiers: some View {
        ipscDrillSummaryView
            .navigationBarHidden(true)
            .alert(item: $pendingIpscAction) { action in
                switch action {
                case .addPenalty:
                    return Alert(
                        title: Text("Add PE"),
                        message: Text("Increase PE by 1 on the first row?"),
                        primaryButton: .destructive(Text("Confirm")) {
                            guard targetRows.isEmpty == false else { return }
                            targetRows[0].pe += 1
                            dqApplied = false
                            applyIpscGridToSummary()
                        },
                        secondaryButton: .cancel()
                    )
                case .disqualify:
                    return Alert(
                        title: Text("Apply DQ"),
                        message: Text("This will set all hit counts to 0. Continue?"),
                        primaryButton: .destructive(Text("Confirm")) {
                            applyDq()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .onAppear {
                initializeOriginalScores()
                initializeIpscEditableRowsIfNeeded()
                ipscSubmitViewModel.lockedContext = ipscContext
            }
            .onChange(of: ipscSubmitViewModel.step) { step in
                switch step {
                case .success(let hitFactor, let totalPoints):
                    showSubmitSuccess(
                        title: NSLocalizedString("success_title", comment: "Success"),
                        message: "HF \(String(format: "%.3f", hitFactor)), TOTAL \(totalPoints)"
                    )
                    ipscSubmitViewModel.dismiss()
                case .error(let message):
                    showSubmitError(
                        title: NSLocalizedString("submit_failed_title", comment: "Submission Failed"),
                        message: message
                    )
                    ipscSubmitViewModel.dismiss()
                default:
                    break
                }
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
                                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 2)
                        )

                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
                .shadow(color: Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.3), radius: 8, x: 0, y: 4)
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
                    .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .cornerRadius(4)
            }

            Spacer()

            if !summaries.isEmpty && (isIpscContextFlow || competition != nil) {
                Button(action: {
                    if isIpscContextFlow {
                        submitIpscFromSummary()
                    } else if competition != nil {
                        submitCompetitionResult()
                    }
                }) {
                    if case .submitting = ipscSubmitViewModel.step {
                        ProgressView()
                            .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    } else if isSubmitting {
                        ProgressView()
                            .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    }
                }
                .disabled(summaries.isEmpty || isResultAlreadySubmitted)
                .opacity((summaries.isEmpty || isResultAlreadySubmitted) ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.95))
    }

    private var ipscInlineSubmitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ipscTargetGridHeader

            ForEach(Array(targetRows.enumerated()), id: \.element.id) { index, row in
                ipscTargetGridRow(row: row, rowIndex: index)
            }

            if dqApplied {
                Text("DQ applied: all hit counts set to 0")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(24)
    }

    private var ipscTargetGridHeader: some View {
        HStack(spacing: 6) {
            Text("NAME")
                .foregroundColor(.gray)
                .frame(width: 108, alignment: .leading)
            Text("A").frame(maxWidth: .infinity)
            Text("C").frame(maxWidth: .infinity)
            Text("D").frame(maxWidth: .infinity)
            Text("NS").frame(maxWidth: .infinity)
            Text("M").frame(maxWidth: .infinity)
            Text("PE").frame(maxWidth: .infinity)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.gray)
    }

    private func ipscTargetGridRow(row: IpscEditableTargetRow, rowIndex: Int) -> some View {
        HStack(spacing: 6) {
            Text(row.rowLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 108, alignment: .leading)

            ipscCell(value: row.a, rowIndex: rowIndex, zone: .a)
            ipscCell(value: row.c, rowIndex: rowIndex, zone: .c)
            ipscCell(value: row.d, rowIndex: rowIndex, zone: .d)
            ipscCell(value: row.ns, rowIndex: rowIndex, zone: .ns)
            ipscCell(value: row.m, rowIndex: rowIndex, zone: .m)
            ipscCell(value: row.pe, rowIndex: rowIndex, zone: .pe)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isIpscRowIncomplete(row) ? Color.red.opacity(0.28) : Color.clear)
        .cornerRadius(8)
    }

    private func ipscCell(value: Int, rowIndex: Int, zone: IpscEditableZone) -> some View {
        Text("\(value)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(ipscCellColor(value: value, zone: zone))
            .cornerRadius(6)
            .onTapGesture {
                updateIpscCell(rowIndex: rowIndex, zone: zone, reset: false)
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                updateIpscCell(rowIndex: rowIndex, zone: zone, reset: true)
            }
    }

    private func ipscCellColor(value: Int, zone: IpscEditableZone) -> Color {
        guard value > 0 else {
            return Color(red: 0.82, green: 0.82, blue: 0.82)
        }

        switch zone {
        case .a, .c, .d:
            return Color.green
        case .ns, .m, .pe:
            return Color.red.opacity(0.88)
        }
    }

    private func isIpscRowIncomplete(_ row: IpscEditableTargetRow) -> Bool {
        let requiredHits = requiredScoringHits(for: row)
        let actualHits = row.a + row.c + row.d + row.m
        return actualHits != requiredHits
    }

    private func requiredScoringHits(for row: IpscEditableTargetRow) -> Int {
        row.rowKind.requiredScoringHits
    }

    private func initializeIpscEditableRowsIfNeeded() {
        guard isIpscContextFlow || isRunningPreview else { return }
        guard !targetRows.isEmpty || summaries.isEmpty else {
            targetRows = buildIpscEditableRows(summary: summaries.first)
            applyIpscGridToSummary()
            return
        }
    }

    private func applyDq() {
        dqApplied = true
        zeroIpscRowsAndSummary()
    }

    private func zeroIpscRowsAndSummary() {
        targetRows = targetRows.map { row in
            var next = row
            next.a = 0
            next.c = 0
            next.d = 0
            next.ns = 0
            next.m = 0
            next.pe = 0
            return next
        }
        applyIpscGridToSummary(forceZeroPenalties: true)
    }

    private func resetIpscPenaltyAndFlags() {
        dqApplied = false
        targetRows = buildIpscEditableRows(summary: summaries.first)
        applyIpscGridToSummary()
    }

    private func submitIpscFromSummary() {
        guard let context = ipscContext else {
            showSubmitError(title: NSLocalizedString("error_title", comment: "Error"), message: "Competition context missing.")
            return
        }
        guard !summaries.isEmpty else {
            showSubmitError(title: NSLocalizedString("error_title", comment: "Error"), message: "No summary data available.")
            return
        }
        applyIpscGridToSummary()
        ipscSubmitViewModel.submit(context: context, summary: summaries[0], isDq: dqApplied)
    }

    private func updateIpscCell(rowIndex: Int, zone: IpscEditableZone, reset: Bool) {
        guard targetRows.indices.contains(rowIndex) else { return }

        switch zone {
        case .a:
            targetRows[rowIndex].a = reset ? 0 : targetRows[rowIndex].a + 1
        case .c:
            targetRows[rowIndex].c = reset ? 0 : targetRows[rowIndex].c + 1
        case .d:
            targetRows[rowIndex].d = reset ? 0 : targetRows[rowIndex].d + 1
        case .ns:
            targetRows[rowIndex].ns = reset ? 0 : targetRows[rowIndex].ns + 1
        case .m:
            targetRows[rowIndex].m = reset ? 0 : targetRows[rowIndex].m + 1
        case .pe:
            targetRows[rowIndex].pe = reset ? 0 : targetRows[rowIndex].pe + 1
        }

        dqApplied = false
        applyIpscGridToSummary()
    }

    private func applyIpscGridToSummary(forceZeroPenalties: Bool = false) {
        guard !summaries.isEmpty else { return }
        let totals = aggregateIpscZones()
        let zones: [String: Int] = [
            "A": totals.a,
            "C": totals.c,
            "D": totals.d,
            "N": totals.ns,
            "M": totals.m,
            "PE": forceZeroPenalties ? 0 : totals.pe
        ]
        summaries[0].adjustedHitZones = zones
        summaries[0].score = ScoringUtility.calculateScoreFromAdjustedHitZones(zones, drillSetup: drillSetup)
    }

    private func aggregateIpscZones() -> (a: Int, c: Int, d: Int, ns: Int, m: Int, pe: Int) {
        (
            a: targetRows.reduce(0) { $0 + $1.a },
            c: targetRows.reduce(0) { $0 + $1.c },
            d: targetRows.reduce(0) { $0 + $1.d },
            ns: targetRows.reduce(0) { $0 + $1.ns },
            m: targetRows.reduce(0) { $0 + $1.m },
            pe: targetRows.reduce(0) { $0 + $1.pe }
        )
    }

    private func buildIpscEditableRows(summary: DrillRepeatSummary?) -> [IpscEditableTargetRow] {
        let targets = ((drillSetup.targets as? Set<DrillTargetsConfig>) ?? []).sorted { lhs, rhs in
            if lhs.seqNo == rhs.seqNo {
                return (lhs.targetName ?? "") < (rhs.targetName ?? "")
            }
            return lhs.seqNo < rhs.seqNo
        }

        // For ipsc_mini_double, expand into 2 panel rows (P0 top, P1 bottom).
        // For hasPhysicalPopper, append one synthetic popper row per host target.
        struct ExpandedTarget {
            let key: String
            let rowLabel: String
            let rowKind: IpscRowKind
            let targetType: String
            let hostName: String
        }

        var expanded: [ExpandedTarget] = []
        var popperIndex = 1
        for target in targets {
            let rawName = target.targetName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hostName = rawName.isEmpty ? "target_\(max(Int(target.seqNo), 1))" : rawName
            let normalizedHostName = hostName.lowercased()
            let type = target.primaryTargetType().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if type == "ipsc_mini_double" {
                expanded.append(ExpandedTarget(
                    key: "\(normalizedHostName)+p0|\(type)",
                    rowLabel: "\(hostName)-0",
                    rowKind: .miniDoublePanel,
                    targetType: type,
                    hostName: normalizedHostName
                ))
                expanded.append(ExpandedTarget(
                    key: "\(normalizedHostName)+p1|\(type)",
                    rowLabel: "\(hostName)-1",
                    rowKind: .miniDoublePanel,
                    targetType: type,
                    hostName: normalizedHostName
                ))
            } else {
                let rowKind: IpscRowKind = (type.contains("paddle") || type.contains("popper")) ? .steel : .paper
                expanded.append(ExpandedTarget(
                    key: "\(normalizedHostName)|\(type)",
                    rowLabel: hostName,
                    rowKind: rowKind,
                    targetType: type,
                    hostName: normalizedHostName
                ))
            }

            if target.hasPhysicalPopper {
                expanded.append(ExpandedTarget(
                    key: "\(normalizedHostName)|apopper",
                    rowLabel: "Popper #\(popperIndex)",
                    rowKind: .apopper,
                    targetType: "apopper",
                    hostName: normalizedHostName
                ))
                popperIndex += 1
            }
        }

        expanded = expanded.sorted { lhs, rhs in
            if lhs.rowKind == .apopper && rhs.rowKind != .apopper {
                return true
            }
            if lhs.rowKind != .apopper && rhs.rowKind == .apopper {
                return false
            }
            return false
        }

        let popperRowKeyByHost: [String: String] = Dictionary(uniqueKeysWithValues: expanded.compactMap { row in
            row.rowKind == .apopper ? (row.hostName, row.key) : nil
        })

        let shots = summary?.shots ?? []
        var groupedShots: [String: [ShotData]] = [:]
        for shot in shots {
            let normalizedKey = ScoringUtility.normalizedTargetKey(for: shot)
            let hitArea = ScoringUtility.normalizeHitArea(shot.content.hitArea)

            let key: String
            if hitArea == "apopper" {
                let parts = normalizedKey.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                let baseName = parts.first.map { String($0) } ?? normalizedKey
                let hostBaseName = ScoringUtility.configBaseName(fromKeyBaseName: baseName)
                key = popperRowKeyByHost[hostBaseName] ?? normalizedKey
            } else {
                key = normalizedKey
            }
            groupedShots[key, default: []].append(shot)
        }

        return expanded.map { entry in
            let rowShots = groupedShots[entry.key] ?? []
            let counts = calculateIpscRowCounts(rowShots: rowShots, rowKind: entry.rowKind, targetType: entry.targetType)

            return IpscEditableTargetRow(
                id: entry.key,
                rowLabel: entry.rowLabel,
                rowKind: entry.rowKind,
                a: counts.a,
                c: counts.c,
                d: counts.d,
                ns: counts.ns,
                m: counts.m,
                pe: counts.pe
            )
        }
    }

    private func calculateIpscRowCounts(rowShots: [ShotData], rowKind: IpscRowKind, targetType: String) -> (a: Int, c: Int, d: Int, ns: Int, m: Int, pe: Int) {
        var a = 0
        var c = 0
        var d = 0
        var ns = 0
        var m = 0
        var pe = 0

        if rowShots.isEmpty {
            return (a: 0, c: 0, d: 0, ns: 0, m: rowKind.defaultNoShotMisses, pe: rowKind.defaultNoShotPe)
        }

        let isPaddleOrPopper = targetType.contains("paddle") || targetType.contains("popper")

        let normalizedShots = rowShots.map { shot -> (shot: ShotData, area: String) in
            (shot, ScoringUtility.normalizeHitArea(shot.content.hitArea))
        }

        let noShootShots = normalizedShots.filter { $0.area == "whitezone" }
        ns += noShootShots.count

        let nonNoShootShots = normalizedShots.filter { $0.area != "whitezone" }
        let apopperShots = nonNoShootShots.filter { $0.area == "apopper" }
        let regularShots = nonNoShootShots.filter { $0.area != "apopper" }

        let validApopperHits = apopperShots.filter { ScoringUtility.scoreForHitArea($0.area) > 0 }.count
        if rowKind == .apopper {
            a += validApopperHits
            m += max(0, rowKind.requiredScoringHits - validApopperHits)
            return (a: a, c: c, d: d, ns: ns, m: m, pe: pe)
        }

        let validRegularShots = regularShots.filter { ScoringUtility.scoreForHitArea($0.area) > 0 }

        if isPaddleOrPopper {
            let requiredHits = rowKind.requiredScoringHits
            let totalSteelHits = validRegularShots.count + validApopperHits
            m += max(0, requiredHits - totalSteelHits)
            a += validApopperHits

            for validShot in validRegularShots {
                switch validShot.area {
                case "azone", "a", "circlearea", "popperzone":
                    a += 1
                case "czone", "c":
                    c += 1
                case "dzone", "d":
                    d += 1
                default:
                    break
                }
            }
        } else {
            let requiredHits = rowKind.requiredScoringHits
            m += max(0, requiredHits - validRegularShots.count)

            let scoringShots = validRegularShots
                .sorted { ScoringUtility.scoreForHitArea($0.area) > ScoringUtility.scoreForHitArea($1.area) }
                .prefix(requiredHits)

            for scoringShot in scoringShots {
                switch scoringShot.area {
                case "azone", "a":
                    a += 1
                case "czone", "c":
                    c += 1
                case "dzone", "d":
                    d += 1
                default:
                    break
                }
            }
        }

        return (a: a, c: c, d: d, ns: ns, m: m, pe: pe)
    }

    private func generateCSVFile() -> URL {
        let csvString = CSVExporter.generateDrillSessionCSV(drillSetup: drillSetup, summaries: summaries)
        let fileName = "\(drillName.replacingOccurrences(of: " ", with: "_"))_Results.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
                                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 2)
                        )

                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if shouldShowDqBadge {
                            Text("DQ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    subtitle
                }

                Spacer()

                if (isIpscContextFlow || isRunningPreview) && summaryIndex == 0 {
                    HStack(spacing: 10) {
                        PenaltyButton(action: {
                            pendingIpscAction = .addPenalty
                        }, penaltyCount: ipscRowPeTotal)

                        CircularActionButton(title: "DQ", tint: .orange, action: {
                            pendingIpscAction = .disqualify
                        })

                        RestoreButton(action: resetIpscPenaltyAndFlags)
                    }
                }
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
                    metricView(hitZoneMetrics[metricIndex])
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.15), radius: 12, x: 0, y: 8)
    }

    private func metricView(_ metric: SummaryMetric) -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: metric.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))

                Text(metric.label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
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
                .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.12), radius: 8, x: 0, y: 6)
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

private enum IpscEditableZone {
    case a
    case c
    case d
    case ns
    case m
    case pe
}

private enum IpscRowKind {
    case paper
    case steel
    case apopper
    case miniDoublePanel

    var requiredScoringHits: Int {
        switch self {
        case .paper, .miniDoublePanel:
            return 2
        case .steel, .apopper:
            return 1
        }
    }

    var defaultNoShotMisses: Int {
        switch self {
        case .paper, .miniDoublePanel:
            return 2
        case .steel, .apopper:
            return 1
        }
    }

    var defaultNoShotPe: Int {
        switch self {
        case .miniDoublePanel:
            return 2
        case .paper, .steel, .apopper:
            return 1
        }
    }
}

private enum IpscPendingAction: Identifiable {
    case addPenalty
    case disqualify

    var id: Int {
        switch self {
        case .addPenalty:
            return 1
        case .disqualify:
            return 2
        }
    }
}

private struct IpscEditableTargetRow: Identifiable {
    let id: String
    let rowLabel: String
    let rowKind: IpscRowKind
    var a: Int
    var c: Int
    var d: Int
    var ns: Int
    var m: Int
    var pe: Int
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
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                    )

                VStack(spacing: 0) {
                    Text("PE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    
                    if penaltyCount > 0 {
                        Text("\(penaltyCount)")
                            .font(.system(size: 9, weight: .bold))
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
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                    )

                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
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

struct CircularActionButton: View {
    @State private var isPressed = false
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(tint, lineWidth: 2)
                    )

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
            }
            .shadow(color: tint.opacity(0.3), radius: 6, x: 0, y: 3)
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

// SummaryEditSheet removed – hit zone editing is no longer available from the summary card.

#Preview("IPSC Summary Grid") {
    let context = PersistenceController.preview.container.viewContext

    let drillSetup = DrillSetup(context: context)
    drillSetup.id = UUID()
    drillSetup.name = "IPSC Preview Drill"
    drillSetup.mode = "ipsc"

    let paperTarget = DrillTargetsConfig(context: context)
    paperTarget.id = UUID()
    paperTarget.seqNo = 1
    paperTarget.targetName = "T1"
    paperTarget.targetType = "ipsc"
    paperTarget.timeout = 3
    paperTarget.countedShots = 2
    paperTarget.drillSetup = drillSetup

    let popperTarget = DrillTargetsConfig(context: context)
    popperTarget.id = UUID()
    popperTarget.seqNo = 2
    popperTarget.targetName = "APopper-1"
    popperTarget.targetType = "paddle"
    popperTarget.timeout = 3
    popperTarget.countedShots = 1
    popperTarget.drillSetup = drillSetup

    let popperTargetTwo = DrillTargetsConfig(context: context)
    popperTargetTwo.id = UUID()
    popperTargetTwo.seqNo = 3
    popperTargetTwo.targetName = "APopper-2"
    popperTargetTwo.targetType = "paddle"
    popperTargetTwo.timeout = 3
    popperTargetTwo.countedShots = 1
    popperTargetTwo.drillSetup = drillSetup

    let popperTargetThree = DrillTargetsConfig(context: context)
    popperTargetThree.id = UUID()
    popperTargetThree.seqNo = 4
    popperTargetThree.targetName = "APopper-3"
    popperTargetThree.targetType = "popper"
    popperTargetThree.timeout = 3
    popperTargetThree.countedShots = 1
    popperTargetThree.drillSetup = drillSetup

    drillSetup.addToTargets(paperTarget)
    drillSetup.addToTargets(popperTarget)
    drillSetup.addToTargets(popperTargetTwo)
    drillSetup.addToTargets(popperTargetThree)

    let mockShots: [ShotData] = [
        ShotData(
            target: "T1",
            content: Content(
                command: "hit",
                hitArea: "azone",
                hitPosition: Position(x: 0.52, y: 0.41),
                targetType: "ipsc",
                timeDiff: 0.64
            ),
            type: "shot",
            action: nil,
            device: "preview-device"
        ),
        ShotData(
            target: "T1",
            content: Content(
                command: "hit",
                hitArea: "czone",
                hitPosition: Position(x: 0.48, y: 0.46),
                targetType: "ipsc",
                timeDiff: 1.08
            ),
            type: "shot",
            action: nil,
            device: "preview-device"
        ),
        ShotData(
            target: "APopper-1",
            content: Content(
                command: "hit",
                hitArea: "apopper",
                hitPosition: Position(x: 0.49, y: 0.43),
                targetType: "paddle",
                timeDiff: 1.37
            ),
            type: "shot",
            action: nil,
            device: "preview-device"
        ),
        ShotData(
            target: "APopper-2",
            content: Content(
                command: "hit",
                hitArea: "apopper",
                hitPosition: Position(x: 0.53, y: 0.42),
                targetType: "paddle",
                timeDiff: 1.62
            ),
            type: "shot",
            action: nil,
            device: "preview-device"
        ),
        ShotData(
            target: "APopper-3",
            content: Content(
                command: "hit",
                hitArea: "circlearea",
                hitPosition: Position(x: 0.44, y: 0.39),
                targetType: "popper",
                timeDiff: 1.84
            ),
            type: "shot",
            action: nil,
            device: "preview-device"
        )
    ]

    let mockShooter: IpscShooter = {
        let json = """
        {
          "id": 101,
          "name": "Kai Preview",
          "bib_number": "0007",
          "division_name": "OPTICS",
          "category_name": "Senior",
          "power_factor": "Minor",
          "stages_done": 0,
          "status": "shooting"
        }
        """
        let data = Data(json.utf8)
        return try! JSONDecoder().decode(IpscShooter.self, from: data)
    }()

    let previewContext = IpscLockedSelectionContext(
        matchId: 1,
        matchName: "Preview Match",
        stageId: 1,
        stageName: "Stage 1",
        squadId: 1,
        squadName: "Squad A",
        shooter: mockShooter
    )

    let mockSummary = DrillRepeatSummary(
        repeatIndex: 1,
        totalTime: 3.18,
        numShots: mockShots.count,
        firstShot: 0.64,
        fastest: 0.29,
        score: 0,
        shots: mockShots,
        adjustedHitZones: ["A": 2, "C": 1, "D": 0, "N": 0, "M": 0, "PE": 1]
    )

    return NavigationStack {
        DrillSummaryView(drillSetup: drillSetup, summaries: [mockSummary], ipscContext: previewContext)
            .environment(\.managedObjectContext, context)
            .environmentObject(BLEManager.shared)
    }
}

