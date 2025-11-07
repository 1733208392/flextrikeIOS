import SwiftUI
import CoreData

struct DrillRecordView: View {
    let drillSetup: DrillSetup
    
    @FetchRequest private var drillResults: FetchedResults<DrillResult>
    
    @Environment(\.managedObjectContext) private var viewContext
    
    init(drillSetup: DrillSetup) {
        self.drillSetup = drillSetup
        _drillResults = FetchRequest(
            entity: DrillResult.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)],
            predicate: NSPredicate(format: "drillSetup == %@", drillSetup),
            animation: .default
        )
    }

    private func convertShots(_ shots: NSSet?) -> [ShotData] {
        guard let shots = shots as? Set<Shot> else { return [] }
        return shots.compactMap { shot in
            guard let data = shot.data, let jsonData = data.data(using: .utf8) else { return nil }
            do {
                return try JSONDecoder().decode(ShotData.self, from: jsonData)
            } catch {
                print("Failed to decode shot: \(error)")
                return nil
            }
        }
    }

    private var groupedResults: [(key: String, results: [DrillResult])] {
        let grouped = Dictionary(grouping: drillResults) { result in
            let date = result.date ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
        
        return grouped.map { (key: $0.key, results: $0.value.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }) }
            .sorted { ($0.results.first?.date ?? Date()) > ($1.results.first?.date ?? Date()) }
    }
    
    /// Group results by execution session using sessionId
    /// All results from the same drill execution share the same sessionId
    private var sessionGroupedResults: [(key: String, sessions: [(firstResult: DrillResult, allResults: [DrillResult])])] {
        let monthGrouped = Dictionary(grouping: drillResults) { result in
            let date = result.date ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
        
        var result: [(key: String, sessions: [(firstResult: DrillResult, allResults: [DrillResult])])] = []
        
        for (monthKey, monthResults) in monthGrouped {
            let sortedByDate = monthResults.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
            
            // Group by sessionId - all results with same sessionId belong to same execution
            let sessionGrouped: [UUID: [DrillResult]] = Dictionary(grouping: sortedByDate) { result in
                result.sessionId ?? UUID()
            }
            
            let sessions = sessionGrouped.map { (sessionId: UUID, results: [DrillResult]) in
                let sorted = results.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
                return (firstResult: sorted[0], allResults: sorted)
            }
            .sorted { (a: (firstResult: DrillResult, allResults: [DrillResult]), b: (firstResult: DrillResult, allResults: [DrillResult])) in
                (a.firstResult.date ?? Date()) > (b.firstResult.date ?? Date())
            }
            
            if !sessions.isEmpty {
                result.append((key: monthKey, sessions: sessions))
            }
        }
        
        return result.sorted { ($0.sessions.first?.firstResult.date ?? Date()) > ($1.sessions.first?.firstResult.date ?? Date()) }
    }

    private func createDrillRepeatSummary(from result: DrillResult) -> DrillRepeatSummary {
        let shots = convertShots(result.shots)
        return DrillRepeatSummary(
            repeatIndex: 1,
            totalTime: result.totalTime,
            numShots: shots.count,
            firstShot: shots.first?.content.timeDiff ?? 0,
            fastest: result.fastestShot,
            score: Int(result.totalScore),
            shots: shots
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            List {
                ForEach(sessionGroupedResults, id: \.key) { group in
                    Section(header: Text(group.key.uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)) {
                        ForEach(group.sessions, id: \.firstResult.objectID) { session in
                            NavigationLink(destination: DrillSummaryView(
                                drillSetup: session.firstResult.drillSetup!,
                                summaries: session.allResults.map { createDrillRepeatSummary(from: $0) }
                            )) {
                                DrillRecordRowView(
                                    model: DrillRecordRowView.Model(
                                        id: session.firstResult.objectID,
                                        date: session.firstResult.date ?? Date(),
                                        repeats: session.allResults.count,
                                        totalShots: aggregateTotalShots(from: session.allResults),
                                        fastestShot: aggregateFastestShot(from: session.allResults)
                                    )
                                )
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    // Delete all results in this session
                                    for result in session.allResults {
                                        viewContext.delete(result)
                                    }
                                    do {
                                        try viewContext.save()
                                    } catch {
                                        print("Failed to delete: \(error)")
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .scrollContentBackgroundHidden()
        }
        .navigationTitle(NSLocalizedString("drill_history", comment: "Drill History navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Aggregate total shots from all results in a session
    private func aggregateTotalShots(from results: [DrillResult]) -> Int {
        results.reduce(0) { $0 + $1.shotStatistics.totalShots }
    }
    
    /// Aggregate fastest shot from all results in a session
    private func aggregateFastestShot(from results: [DrillResult]) -> TimeInterval {
        results.compactMap { $0.fastestShot }
            .filter { $0 > 0 }
            .min() ?? 0
    }

}

// MARK: - Row View
struct DrillRecordRowView: View {
    struct Model: Identifiable, Hashable {
        let id: AnyHashable
        let date: Date
        let repeats: Int
        let totalShots: Int
        let fastestShot: TimeInterval

        init(id: AnyHashable = UUID(), date: Date, repeats: Int, totalShots: Int, fastestShot: TimeInterval) {
            self.id = id
            self.date = date
            self.repeats = repeats
            self.totalShots = totalShots
            self.fastestShot = fastestShot
        }

        var dayText: String {
            Self.dayFormatter.string(from: date)
        }

        var repeatsText: String {
            "\(repeats)"
        }

        var totalShotsText: String {
            "\(totalShots)"
        }

        var fastestShotText: String {
            guard fastestShot > 0 else { return "--" }
            return Self.fastestShotFormatter.string(from: NSNumber(value: fastestShot)) ?? "--"
        }

        private static let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter
        }()

        private static let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 2
            return formatter
        }()

        private static let fastestShotFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.positiveSuffix = "s"
            formatter.negativeSuffix = "s"
            formatter.zeroSymbol = "--"
            return formatter
        }()
    }

    let model: Model

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 40, height: 40)
                    
                    Text(model.dayText.uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(minWidth: 68)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.2))

                HStack(spacing: 12) {
                    DrillMetricColumn(value: model.repeatsText, label: "#repeats")

                    Divider()
                        .frame(height: 44)
                        .background(Color.red)

                    DrillMetricColumn(value: model.totalShotsText, label: "#Shots")

                    Divider()
                        .frame(height: 44)
                        .background(Color.red)

                    DrillMetricColumn(value: model.fastestShotText, label: "Fastest")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)}
                        
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
//        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct DrillMetricColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview Support
private extension DrillRecordRowView.Model {
    static let previewSamples: [Self] = [
        .init(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
              repeats: 5,
              totalShots: 14,
              fastestShot: 0.23),
        .init(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
              repeats: 4,
              totalShots: 11,
              fastestShot: 0.31),
        .init(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
              repeats: 6,
              totalShots: 16,
              fastestShot: 0.19)
    ]
    
    static var groupedPreviewSamples: [(key: String, models: [Self])] {
        let grouped = Dictionary(grouping: previewSamples) { model in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: model.date)
        }
        
        return grouped.map { (key: $0.key, models: $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.models.first?.date ?? Date()) > ($1.models.first?.date ?? Date()) }
    }
}

struct DrillRecordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    ForEach(DrillRecordRowView.Model.groupedPreviewSamples, id: \.key) { group in
                        Section(header: Text(group.key.uppercased())
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.vertical, 8)) {
                            ForEach(group.models) { model in
                                DrillRecordRowView(model: model)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .padding(.top, 8)
                .background(Color.clear)
                .navigationTitle(NSLocalizedString("drill_history", comment: "Drill History navigation title"))
            }
        }
        .previewDisplayName("Drill Record List")
    }
}



