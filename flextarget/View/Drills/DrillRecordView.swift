import SwiftUI
import CoreData

struct DrillRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)],
        animation: .default)
    private var drillResults: FetchedResults<DrillResult>

    @State private var selectedResult: DrillResult?

    var body: some View {
        NavigationView {
            List {
                ForEach(drillResults) { result in
                    VStack(alignment: .leading) {
                        Text("Drill ID: \(result.drillId?.uuidString ?? "Unknown")")
                        Text("Date: \(result.date ?? Date(), formatter: dateFormatter)")
                        Text("Shots: \(result.shots?.count ?? 0)")
                    }
                    .onTapGesture {
                        selectedResult = result
                    }
                }
            }
            .navigationTitle("Drill History")
            .sheet(item: $selectedResult) { result in
                DrillResultDetailView(result: result)
            }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct DrillResultDetailView: View {
    let result: DrillResult

    var body: some View {
        List {
            ForEach(Array(result.shots as! Set<Shot>), id: \.self) { shot in
                VStack(alignment: .leading) {
                    if let dataString = shot.data {
                        Text(dataString)
                    } else {
                        Text("No data")
                    }
                }
            }
        }
        .navigationTitle("Shots for \(result.drillId?.uuidString ?? "Unknown")")
    }
}