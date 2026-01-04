import SwiftUI
import CoreData

struct HistoryTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var selectedDrillType: String? = nil
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
    
    var groupedResults: [String: [(DrillSetup, [DrillResult])]] {
        var grouped: [String: [(DrillSetup, [DrillResult])]] = [:]
        
        let filtered = drillResults.filter { result in
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
            
            return true
        }
        
        // Group by drill setup
        var setupGroups: [DrillSetup: [DrillResult]] = [:]
        for result in filtered {
            if let setup = result.drillSetup {
                if setupGroups[setup] == nil {
                    setupGroups[setup] = []
                }
                setupGroups[setup]?.append(result)
            }
        }
        
        // Group by date for each setup
        for (setup, results) in setupGroups {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            for result in results {
                let dateKey = result.date.map { dateFormatter.string(from: $0) } ?? NSLocalizedString("unknown_date", comment: "Unknown date")
                
                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                
                if !grouped[dateKey]!.contains(where: { $0.0 == setup }) {
                    grouped[dateKey]!.append((setup, []))
                }
                
                if var setupGroup = grouped[dateKey]?.first(where: { $0.0 == setup }) {
                    setupGroup.1.append(result)
                    if let index = grouped[dateKey]?.firstIndex(where: { $0.0 == setup }) {
                        grouped[dateKey]?[index] = setupGroup
                    }
                }
            }
        }
        
        return grouped
    }
    
    var uniqueDrillTypes: [String] {
        let types = Set(drillResults.compactMap { $0.drillSetup?.mode })
        return Array(types).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Controls
                VStack(spacing: 12) {
                    // Drill Type Filter
                    Menu {
                        Button(NSLocalizedString("all_drills", comment: "All drills filter")) {
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
                            Image(systemName: "funnel")
                            Text(selectedDrillType?.uppercased() ?? NSLocalizedString("all_drills", comment: "All drills filter"))
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
                            ForEach(groupedResults.sorted(by: { $0.key > $1.key }), id: \.key) { dateKey, setupGroups in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(dateKey)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                    
                                    ForEach(setupGroups, id: \.0.id) { setup, results in
                                        VStack(spacing: 8) {
                                            ForEach(results, id: \.objectID) { result in
                                                NavigationLink(destination: DrillSummaryView(drillSetup: setup, summaries: createSummaries(from: result) ?? [])
                                                    .environment(\.managedObjectContext, persistenceController.container.viewContext)) {
                                                    if let summaries = createSummaries(from: result) {
                                                        DrillSummaryCard(drillSetup: setup, summaries: summaries)
                                                    }
                                                }
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
        
        let summary = DrillRepeatSummary(
            repeatIndex: 1,
            totalTime: result.totalTime,
            numShots: numShots,
            firstShot: firstShotTime,
            fastest: fastestTime,
            score: 0,
            shots: shotDataArray,
            drillResultId: result.id,
            adjustedHitZones: adjustedHitZones
        )
        
        return [summary]
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
