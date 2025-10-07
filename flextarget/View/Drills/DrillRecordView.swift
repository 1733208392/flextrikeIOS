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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            List {
                ForEach(groupedResults, id: \.key) { group in
                    Section(header: Text(group.key.uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)) {
                        ForEach(group.results) { result in
                            NavigationLink(destination: DrillResultView(drillSetup: result.drillSetup!, shots: convertShots(result.shots))) {
                                DrillRecordRowView(
                                    model: DrillRecordRowView.Model(
                                        id: result.objectID,
                                        date: result.date ?? Date(),
                                        hitFactor: result.hitFactor,
                                        totalShots: result.shotStatistics.totalShots,
                                        fastestShot: result.fastestShot
                                    )
                                )
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewContext.delete(result)
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Drill History")
        .navigationBarTitleDisplayMode(.inline)
    }

}

// MARK: - Row View
struct DrillRecordRowView: View {
    struct Model: Identifiable, Hashable {
        let id: AnyHashable
        let date: Date
        let hitFactor: Double
        let totalShots: Int
        let fastestShot: TimeInterval

        init(id: AnyHashable = UUID(), date: Date, hitFactor: Double, totalShots: Int, fastestShot: TimeInterval) {
            self.id = id
            self.date = date
            self.hitFactor = hitFactor
            self.totalShots = totalShots
            self.fastestShot = fastestShot
        }

        var dayText: String {
            Self.dayFormatter.string(from: date)
        }

        var hitFactorText: String {
            Self.numberFormatter.string(from: NSNumber(value: hitFactor)) ?? "0.0"
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
                    DrillMetricColumn(value: model.hitFactorText, label: "Hit Factor")

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
              hitFactor: 5.3,
              totalShots: 14,
              fastestShot: 0.23),
        .init(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
              hitFactor: 4.8,
              totalShots: 11,
              fastestShot: 0.31),
        .init(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
              hitFactor: 6.1,
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
                .navigationTitle("Drill History")
            }
        }
        .previewDisplayName("Drill Record List")
    }
}



