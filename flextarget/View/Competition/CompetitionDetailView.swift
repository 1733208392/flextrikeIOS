import SwiftUI
import CoreData

struct CompetitionDetailView: View {
    @ObservedObject var competition: Competition
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var bleManager: BLEManager
    
    @State private var showAthletePicker = false
    @State private var selectedAthlete: Athlete?
    @State private var navigateToTimerSession = false
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    @State private var navigateToDrillSummary = false
    @State private var showAckTimeoutAlert = false
    @State private var selectedResult: DrillResult?
    @State private var isLoadingSyncResults = false
    @State private var lastSyncError: String?
    @State private var showSyncError = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Competition Info Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(competition.name ?? "")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(competition.venue ?? "")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(competition.date ?? Date(), style: .date)
                            .foregroundColor(.red)
                    }
                    
                    if let drill = competition.drillSetup {
                        HStack {
                            Image(systemName: "target")
                            Text(drill.name ?? "")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                // Sync Button
                HStack(spacing: 12) {
                    if isLoadingSyncResults {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        Task {
                            await syncCompetitionResults()
                        }
                    }) {
                        Text(NSLocalizedString("sync_results", comment: "Sync results from server"))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .disabled(isLoadingSyncResults)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Results List
                List {
                    Section(header: Text(NSLocalizedString("results", comment: "")).foregroundColor(.white)) {
                        if let results = competition.results?.allObjects as? [DrillResult], !results.isEmpty {
                            ForEach(results.sorted(by: { ($0.date ?? Date()) > ($1.date ?? Date()) })) { result in
                                NavigationLink(destination: 
                                    ZStack {
                                        Color.black.ignoresSafeArea()
                                        if let drillSetup = result.drillSetup {
                                            DrillSummaryView(drillSetup: drillSetup, summaries: reconstructSummaries(from: result), competition: competition)
                                        }
                                    }
                                ) {
                                    CompetitionResultRow(result: result)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                        } else {
                            Text(NSLocalizedString("no_results_yet", comment: ""))
                                .foregroundColor(.gray)
                                .listRowBackground(Color.white.opacity(0.1))
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                
                // Start Button
                Button(action: {
                    showAthletePicker = true
                }) {
                    Text(NSLocalizedString("start_competition_drill", comment: ""))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bleManager.isConnected ? Color.red : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!bleManager.isConnected)
                .padding()
            }
            
            // Navigation Links
            NavigationLink(isActive: $navigateToTimerSession) {
                if let drillSetup = competition.drillSetup {
                    TimerSessionView(
                        drillSetup: drillSetup,
                        bleManager: bleManager,
                        competition: competition,
                        athlete: selectedAthlete,
                        onDrillComplete: { summaries in
                            DispatchQueue.main.async {
                                drillRepeatSummaries = summaries
                                saveCompetitionResults(summaries)
                                navigateToDrillSummary = true
                                navigateToTimerSession = false
                            }
                        },
                        onDrillFailed: {
                            DispatchQueue.main.async {
                                showAckTimeoutAlert = true
                                navigateToTimerSession = false
                            }
                        }
                    )
                }
            } label: {
                EmptyView()
            }
            
            NavigationLink(isActive: $navigateToDrillSummary) {
                if let drillSetup = competition.drillSetup {
                    DrillSummaryView(drillSetup: drillSetup, summaries: drillRepeatSummaries, competition: competition)
                }
            } label: {
                EmptyView()
            }
        }
        .navigationTitle(NSLocalizedString("competition_details", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAthletePicker) {
            AthletePickerSheet { athlete in
                selectedAthlete = athlete
                navigateToTimerSession = true
            }
        }
        .alert(isPresented: $showAckTimeoutAlert) {
            Alert(title: Text(NSLocalizedString("error_title", comment: "")), message: Text(NSLocalizedString("ack_timeout_message", comment: "")), dismissButton: .default(Text(NSLocalizedString("ok", comment: ""))))
        }
        .alert(isPresented: $showSyncError) {
            Alert(title: Text(NSLocalizedString("sync_error_title", comment: "Sync Error")), message: Text(lastSyncError ?? ""), dismissButton: .default(Text(NSLocalizedString("ok_button", comment: "OK"))))
        }
        .onAppear {
            // Load competition results from server on view appear
            Task {
                await syncCompetitionResults()
            }
        }
    }
    
    private func syncCompetitionResults() async {
        isLoadingSyncResults = true
        
        do {
            // Get required parameters
            guard let gameType = competition.id?.uuidString else {
                throw NSError(domain: "CompetitionDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Competition ID missing"])
            }
            
            let gameVer = "1.0"
            
            // Fetch results from server using device UUID from DeviceAuthManager
            let listResponse = try await CompetitionResultAPIService.shared.getGamePlayList(
                gameType: gameType,
                gameVer: gameVer
            )
            
            // Sync remote results with local results
            await DispatchQueue.main.async {
                self.syncRemoteResultsWithLocal(remoteResults: listResponse.rows)
            }
        } catch {
            // Set user-friendly error message for sync failures
            lastSyncError = NSLocalizedString("device_reauth_message", comment: "Device re-authorization message")
            showSyncError = true
        }
        
        isLoadingSyncResults = false
    }
    
    private func syncRemoteResultsWithLocal(remoteResults: [CompetitionResultAPIService.GamePlayRow]) {
        // Get all local results for this competition
        let localResults = (competition.results?.allObjects as? [DrillResult]) ?? []
        
        // Process remote results - find matches with local results
        for remoteResult in remoteResults {
            // Check if this remote result matches an existing local result
            if let matchingLocalResult = localResults.first(where: { $0.serverPlayId == remoteResult.play_uuid }) {
                // Already linked, update submission status if needed
                if matchingLocalResult.submittedAt == nil {
                    matchingLocalResult.submittedAt = Date()
                }
            } else {
                // New remote result that doesn't have a local match
                // Try to fetch detail and reconstruct local result
                Task {
                    do {
                        let detailResponse = try await CompetitionResultAPIService.shared.getGamePlayDetail(playUuid: remoteResult.play_uuid)
                        
                        // Reconstruct local DrillResult from remote data
                        await DispatchQueue.main.async {
                            self.reconstructDrillResultFromRemote(remoteResult: remoteResult, detailResponse: detailResponse)
                        }
                    } catch {
                        // Silently skip this result if detail fetch fails
                        print("Failed to fetch detail for remote result \(remoteResult.play_uuid): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Mark local results that haven't been submitted
        for localResult in localResults {
            if localResult.serverPlayId == nil {
                // This is a local-only result (not submitted yet)
                // The UI can show this as "local/unsubmitted" status
            }
        }
        
        // Save changes
        do {
            try viewContext.save()
        } catch {
            print("Failed to save sync changes: \(error)")
        }
    }
    
    private func reconstructDrillResultFromRemote(
        remoteResult: CompetitionResultAPIService.GamePlayRow,
        detailResponse: CompetitionResultAPIService.GamePlayDetailResponse
    ) {
        guard let drillSetup = competition.drillSetup else { return }
        
        // Parse play_time string to Date (format: "yyyy-MM-dd HH:mm:ss")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let playDate = dateFormatter.date(from: detailResponse.play_time) ?? Date()
        
        // Extract shot data and calculate total time
        let shotData = detailResponse.detail?.shotData ?? []
        let totalTime = detailResponse.detail?.totalTime ?? 0
        
        // Find or create athlete using athlete information from detail
        var athlete: Athlete?
        if let athleteName = detailResponse.detail?.athleteName {
            let fetchRequest = NSFetchRequest<Athlete>(entityName: "Athlete")
            let athleteClub = detailResponse.detail?.athleteClub ?? ""
            fetchRequest.predicate = NSPredicate(format: "name == %@ AND club == %@", athleteName, athleteClub)
            
            if let existingAthlete = try? viewContext.fetch(fetchRequest).first {
                athlete = existingAthlete
            } else {
                // Create new athlete
                athlete = Athlete(context: viewContext)
                athlete?.id = UUID()
                athlete?.name = athleteName
                athlete?.club = athleteClub
            }
        }
        
        // Create DrillResult
        let drillResult = DrillResult(context: viewContext)
        drillResult.id = UUID()
        drillResult.drillId = drillSetup.id
        drillResult.sessionId = UUID()
        drillResult.date = playDate
        drillResult.totalTime = totalTime
        drillResult.serverPlayId = remoteResult.play_uuid
        drillResult.serverDeviceId = remoteResult.device_uuid
        drillResult.submittedAt = Date()
        drillResult.drillSetup = drillSetup
        drillResult.competition = competition
        
        // Create Shot records from shot data
        var cumulativeTime: Double = 0
        for shotData in shotData {
            cumulativeTime += shotData.content.timeDiff
            let shot = Shot(context: viewContext)
            do {
                let jsonData = try JSONEncoder().encode(shotData)
                shot.data = String(data: jsonData, encoding: .utf8)
            } catch {
                print("Failed to encode shot data: \(error)")
                shot.data = nil
            }
            shot.timestamp = Int64(cumulativeTime * 1000)
            shot.drillResult = drillResult
        }
        
        // Create LeaderboardEntry if athlete exists
        if let athlete = athlete {
            let scoreFactor = totalTime > 0 ? Double(remoteResult.score) / totalTime : 0
            
            let entry = LeaderboardEntry(context: viewContext)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.baseFactor = scoreFactor
            entry.adjustment = 0
            entry.scoreFactor = scoreFactor
            entry.athlete = athlete
            entry.drillResult = drillResult
        }
        
        // Save all changes
        do {
            try viewContext.save()
        } catch {
            print("Failed to save reconstructed result: \(error)")
        }
    }
    
    private func saveCompetitionResults(_ summaries: [DrillRepeatSummary]) {
        guard let drillSetup = competition.drillSetup, let drillId = drillSetup.id else { return }
        
        let sessionId = UUID()
        for (index, summary) in summaries.enumerated() {
            let drillResult = DrillResult(context: viewContext)
            drillResult.id = UUID()
            drillResult.drillId = drillId
            drillResult.sessionId = sessionId
            drillResult.date = Date()
            drillResult.totalTime = summary.totalTime
            drillResult.drillSetup = drillSetup
            drillResult.competition = competition
            
            // Create LeaderboardEntry for the athlete
            if let athlete = selectedAthlete {
                let entry = LeaderboardEntry(context: viewContext)
                entry.id = UUID()
                entry.createdAt = Date()
                entry.athlete = athlete
                entry.drillResult = drillResult
                
                let factor: Double = summary.totalTime > 0 ? (Double(summary.score) / summary.totalTime) : 0
                entry.baseFactor = factor
                entry.adjustment = 0
                entry.scoreFactor = factor
            }
            
            var cumulativeTime: Double = 0
            for shotData in summary.shots {
                cumulativeTime += shotData.content.timeDiff
                let shot = Shot(context: viewContext)
                do {
                    let jsonData = try JSONEncoder().encode(shotData)
                    shot.data = String(data: jsonData, encoding: .utf8)
                } catch {
                    print("Failed to encode shot data: \(error)")
                    shot.data = nil
                }
                shot.timestamp = Int64(cumulativeTime * 1000)
                shot.drillResult = drillResult
            }
            
            // Update the summary with the drillResultId so it can be used in submission
            if index < drillRepeatSummaries.count {
                drillRepeatSummaries[index].drillResultId = drillResult.id
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save competition results: \(error)")
        }
    }
    
    private func reconstructSummaries(from result: DrillResult) -> [DrillRepeatSummary] {
        guard let shots = result.shots?.allObjects as? [Shot] else { return [] }
        
        let sortedShots = shots.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
        var shotDataArray: [ShotData] = []
        
        for shot in sortedShots {
            if let jsonString = shot.data,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    let shotData = try JSONDecoder().decode(ShotData.self, from: jsonData)
                    shotDataArray.append(shotData)
                } catch {
                    print("Failed to decode shot data: \(error)")
                }
            }
        }
        
        // Try to load adjusted hit zones from the result if available
        var adjustedHitZones: [String: Int]? = nil
        if let adjustedZonesJSON = result.adjustedHitZones,
           let jsonData = adjustedZonesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: jsonData) {
            adjustedHitZones = decoded
        }
        
        // Create a single DrillRepeatSummary from the DrillResult
        let summary = DrillRepeatSummary(
            id: UUID(),
            repeatIndex: 0,
            totalTime: result.totalTime,
            numShots: shotDataArray.count,
            firstShot: shotDataArray.first?.content.timeDiff ?? 0,
            fastest: shotDataArray.map { $0.content.timeDiff }.min() ?? 0,
            score: 0,  // Will be recalculated from adjusted hit zones in metrics function
            shots: shotDataArray,
            drillResultId: result.id,
            adjustedHitZones: adjustedHitZones
        )
        
        return [summary]
    }
}

struct CompetitionResultRow: View {
    let result: DrillResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let athlete = (result.leaderboardEntries?.allObjects as? [LeaderboardEntry])?.first?.athlete {
                    Text(athlete.name ?? "")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text(NSLocalizedString("unknown_athlete", comment: ""))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 8) {
                    Text(result.date ?? Date(), style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Show sync status badge
                    if result.serverPlayId != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text(NSLocalizedString("submitted", comment: "Submitted"))
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.dotted")
                                .font(.caption2)
                            Text(NSLocalizedString("local_unsubmitted", comment: "Local/Unsubmitted"))
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2fs", result.totalTime))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let leaderboardEntry = (result.leaderboardEntries?.allObjects as? [LeaderboardEntry])?.first {
                    Text(String(format: "%.3f", leaderboardEntry.scoreFactor))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
