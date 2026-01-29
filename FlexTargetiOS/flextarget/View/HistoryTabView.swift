import SwiftUI
import CoreData

struct DrillSession {
    let sessionId: UUID
    let setup: DrillSetup
    let date: Date?
    let results: [DrillResult]
    
    var repeatCount: Int { results.count }
    var totalShots: Int {
        results.reduce(0) { $0 + (($1.shots as? Set<Shot>)?.count ?? 0) }
    }
}

struct HistoryTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var selectedDrillType: String? = nil
    @State private var selectedDrillName: String? = nil
    @State private var selectedDateRange: DateRange = .all
    @State private var expandedDrillSetups: Set<UUID> = []
    @State private var selectedResult: DrillResult? = nil
    @State private var showDetailView = false
    
    @FetchRequest(
        entity: DrillResult.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)],
        animation: .default
    ) private var drillResults: FetchedResults<DrillResult>
    
    let persistenceController = PersistenceController.shared
    
    enum DateRange {
        case all
        case week
        case month
        case custom(Date, Date)
        
        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all:
                return nil
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .custom(let start, _):
                return start
            }
        }
        
        var endDate: Date {
            switch self {
            case .custom(_, let end):
                return end
            default:
                return Date()
            }
        }
    }
    
    var groupedResults: [String: [DrillSession]] {
        var grouped: [String: [DrillSession]] = [:]
        
        let filtered = drillResults.filter { result in
            // Exclude results from competitions that have associated athletes
            // These are competition/match records, not personal drill records
            if result.competition != nil && result.athlete != nil {
                return false // Exclude competition results with athletes
            }
            
            // Filter by date range
            if let startDate = selectedDateRange.startDate, let resultDate = result.date {
                if resultDate < startDate || resultDate > selectedDateRange.endDate {
                    return false
                }
            }
            
            // Filter by drill type
            if let selectedType = selectedDrillType {
                if result.drillSetup?.mode != selectedType {
                    return false
                }
            }
            
            // Filter by drill name
            if let selectedName = selectedDrillName {
                if result.drillSetup?.name != selectedName {
                    return false
                }
            }
            
            return true
        }
        
        // Group by sessionId
        var sessionGroups: [UUID: [DrillResult]] = [:]
        for result in filtered {
            let sid = result.sessionId ?? UUID()
            if sessionGroups[sid] == nil {
                sessionGroups[sid] = []
            }
            sessionGroups[sid]?.append(result)
        }
        
        // Create sessions
        var sessions: [DrillSession] = sessionGroups.compactMap { (sid: UUID, results: [DrillResult]) -> DrillSession? in
            guard let firstResult = results.first, let setup = firstResult.drillSetup else { return nil }
            return DrillSession(sessionId: sid, setup: setup, date: firstResult.date, results: results)
        }
        
        // Sort sessions by date descending to ensure stable order
        sessions.sort { (a, b) -> Bool in
            let dateA = a.date ?? Date.distantPast
            let dateB = b.date ?? Date.distantPast
            if dateA != dateB {
                return dateA > dateB
            }
            return a.sessionId.uuidString > b.sessionId.uuidString
        }
        
        // Group by date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        for session in sessions {
            let dateKey = session.date.map { dateFormatter.string(from: $0) } ?? NSLocalizedString("unknown_date", comment: "Unknown date")
            
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            
            grouped[dateKey]?.append(session)
        }
        
        return grouped
    }
    
    var uniqueDrillTypes: [String] {
        let types = Set(drillResults.compactMap { $0.drillSetup?.mode })
        return Array(types).sorted()
    }
    
    var uniqueDrillNames: [String] {
        let names = Set(drillResults.compactMap { $0.drillSetup?.name })
        return Array(names).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Controls
                VStack(spacing: 12) {
                    // Drill Type Filter
                    Menu {
                        Button(NSLocalizedString("all_modes", comment: "All drills filter")) {
                            selectedDrillType = nil
                        }
                        
                        Divider()
                        
                        ForEach(uniqueDrillTypes, id: \.self) { type in
                            Button(type.uppercased()) {
                                selectedDrillType = type
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text(selectedDrillType?.uppercased() ?? NSLocalizedString("all_modes", comment: "All drills filter"))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    // Date Range Filter
                    Menu {
                        Button(NSLocalizedString("all_time", comment: "All time filter")) {
                            selectedDateRange = .all
                        }
                        
                        Button(NSLocalizedString("past_week", comment: "Past week filter")) {
                            selectedDateRange = .week
                        }
                        
                        Button(NSLocalizedString("past_month", comment: "Past month filter")) {
                            selectedDateRange = .month
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text(dateRangeLabel)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    // Drill Name Filter
                    Menu {
                        Button(NSLocalizedString("all_drill_setup", comment: "All names filter")) {
                            selectedDrillName = nil
                        }
                        
                        Divider()
                        
                        ForEach(uniqueDrillNames, id: \.self) { name in
                            Button(name) {
                                selectedDrillName = name
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "target")
                            Text(selectedDrillName ?? NSLocalizedString("all_drill_setup", comment: "All names filter"))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                
                Divider()
                    .background(Color.red.opacity(0.3))
                
                // Results List
                if groupedResults.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text(NSLocalizedString("no_results", comment: "No results message"))
                                .font(.headline)
                            Text(NSLocalizedString("no_results_hint", comment: "No results hint"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(groupedResults.sorted(by: { $0.key > $1.key }), id: \.key) { dateKey, sessions in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(dateKey)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                    
                                    ForEach(sessions, id: \.sessionId) { session in
                                        let isExpanded = expandedDrillSetups.contains(session.sessionId)
                                        VStack(spacing: 0) {
                                            Button(action: {
                                                withAnimation {
                                                    if isExpanded {
                                                        expandedDrillSetups.remove(session.sessionId)
                                                    } else {
                                                        expandedDrillSetups.insert(session.sessionId)
                                                    }
                                                }
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(session.setup.name ?? NSLocalizedString("untitled", comment: "Untitled"))
                                                            .font(.headline)
                                                            .foregroundColor(.white)
                                                        Text("\(session.repeatCount) repeats")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                    Spacer()
                                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                        .foregroundColor(.red)
                                                }
                                                .padding(12)
                                                .background(Color.gray.opacity(0.15))
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            if isExpanded {
                                                VStack(spacing: 8) {
                                                    ForEach(session.results, id: \.objectID) { result in
                                                        NavigationLink(destination: DrillSummaryView(drillSetup: session.setup, summaries: createSummaries(from: result) ?? [])
                                                            .environment(\.managedObjectContext, persistenceController.container.viewContext)) {
                                                            if let summaries = createSummaries(from: result) {
                                                                DrillSummaryCard(drillSetup: session.setup, summaries: summaries, onDelete: { deleteResult(result) })
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.top, 8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("history", comment: "History tab title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteResult(_ result: DrillResult) {
        managedObjectContext.delete(result)
        try? managedObjectContext.save()
    }
    
    private func createSummaries(from result: DrillResult) -> [DrillRepeatSummary]? {
        // Convert DrillResult to DrillRepeatSummary format for display
        guard let shots = result.shots as? Set<Shot> else { return nil }
        
        var shotDataArray: [ShotData] = []
        let decoder = JSONDecoder()
        
        for shot in shots {
            guard let data = shot.data else { continue }
            if let shotData = try? decoder.decode(ShotData.self, from: data.data(using: .utf8) ?? Data()) {
                shotDataArray.append(shotData)
            }
        }
        
        shotDataArray.sort { (a: ShotData, b: ShotData) in a.content.timeDiff < b.content.timeDiff }
        
        guard !shotDataArray.isEmpty else { return nil }
        
        // Calculate derived values
        let numShots = shotDataArray.count
        let firstShotTime = shotDataArray.first?.content.timeDiff ?? 0
        let fastestTime = shotDataArray.min(by: { (a: ShotData, b: ShotData) in a.content.timeDiff < b.content.timeDiff })?.content.timeDiff ?? 0
        
        var adjustedHitZones: [String: Int]? = nil
        if let adjustedStr = result.adjustedHitZones {
            let decoder = JSONDecoder()
            adjustedHitZones = try? decoder.decode([String: Int].self, from: adjustedStr.data(using: .utf8) ?? Data())
        }
        
        // Decode CQB data
        var cqbResults: [CQBShotResult]? = nil
        if let cqbResultsStr = result.cqbResults, 
           let data = cqbResultsStr.data(using: .utf8) {
            cqbResults = try? decoder.decode([CQBShotResult].self, from: data)
        }
        
        let cqbPassed: Bool? = result.cqbPassed?.boolValue
        
        let summary = DrillRepeatSummary(
            repeatIndex: 1,
            totalTime: result.totalTime?.doubleValue ?? 0,
            numShots: numShots,
            firstShot: firstShotTime,
            fastest: fastestTime,
            score: 0,
            shots: shotDataArray,
            drillResultId: result.id,
            adjustedHitZones: adjustedHitZones,
            cqbResults: cqbResults,
            cqbPassed: cqbPassed
        )
        
        return [summary]
    }
    
    private func createSummaries(for session: DrillSession) -> [DrillRepeatSummary]? {
        var summaries: [DrillRepeatSummary] = []
        for (index, result) in session.results.enumerated() {
            if let summary = createSummaries(from: result)?.first {
                let updatedSummary = DrillRepeatSummary(
                    repeatIndex: index + 1,
                    totalTime: summary.totalTime,
                    numShots: summary.numShots,
                    firstShot: summary.firstShot,
                    fastest: summary.fastest,
                    score: summary.score,
                    shots: summary.shots,
                    drillResultId: summary.drillResultId,
                    adjustedHitZones: summary.adjustedHitZones,
                    cqbResults: summary.cqbResults,
                    cqbPassed: summary.cqbPassed
                )
                summaries.append(updatedSummary)
            }
        }
        return summaries.isEmpty ? nil : summaries
    }
    
    private var dateRangeLabel: String {
        switch selectedDateRange {
        case .all:
            return NSLocalizedString("all_time", comment: "All time filter")
        case .week:
            return NSLocalizedString("past_week", comment: "Past week filter")
        case .month:
            return NSLocalizedString("past_month", comment: "Past month filter")
        case .custom:
            return NSLocalizedString("custom_date", comment: "Custom date filter")
        }
    }
}

// Helper card view for displaying summary in history
struct DrillSummaryCard: View {
    let drillSetup: DrillSetup
    let summaries: [DrillRepeatSummary]
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drillSetup.name ?? NSLocalizedString("untitled", comment: "Untitled"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(drillSetup.mode?.uppercased() ?? "N/A")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2fs", summaries.first?.totalTime ?? 0))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(String(summaries.first?.shots.count ?? 0) + " shots")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding(.leading, 8)
            }
            .padding(12)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationView {
        HistoryTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
