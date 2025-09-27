import SwiftUI

struct DrillListView: View {
    @State private var searchText: String = ""
    @State private var drills: [DrillConfig] = []
    @Environment(\.dismiss) private var dismiss
    // For showing alerts
    @State private var showDeleteAlert = false
    @State private var drillToDelete: DrillConfig?

    var filteredDrills: [DrillConfig] {
        if searchText.isEmpty {
            return drills
        } else {
            return drills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                // Search Field (unchanged)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    Text("Search")
                        .foregroundColor(.gray)
                    TextField("", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(24)
                .padding([.top, .horizontal])

                // Drill List using List
                List {
                    ForEach(Array(filteredDrills.enumerated()), id: \.element.id) { (index, drill) in
                        ZStack {
                            DrillListItemView(drill: drill, index: index + 1)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            NavigationLink(destination: EditDrillConfigView(drill: drill)) {
                                EmptyView()
                            }
                            .opacity(0) // Make the link invisible but still tappable
                        }
                        .listRowBackground(Color.clear) // Clear the default row background
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                // Copy logic: duplicate drill, assign new UUID, add to storage and refresh
                                var newDrill = drill
                                newDrill = DrillConfig(
                                    id: UUID(),
                                    name: drill.name + " Copy",
                                    description: drill.description,
                                    demoVideoURL: drill.demoVideoURL,
                                    thumbnailURL: drill.thumbnailURL,
                                    numberOfSets: drill.numberOfSets,
                                    startDelay: drill.startDelay,
                                    pauseBetweenSets: drill.pauseBetweenSets,
                                    sets: drill.sets,
                                    targetType: drill.targetType,
                                    gunType: drill.gunType
                                )
                                DrillConfigStorage.shared.add(newDrill)
                                drills = DrillConfigStorage.shared.getAll()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .tint(Color.gray)
                            Button(role: .destructive) {
                                // Show delete alert
                                drillToDelete = drill
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                Spacer()
                // Add New Drill Button (unchanged)
                NavigationLink(destination: AddDrillConfigView()) {
                    Text("Add New Drill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Drill List")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                drills = DrillConfigStorage.shared.getAll()
            }
        }
        .alert("Delete Drill?", isPresented: $showDeleteAlert, presenting: drillToDelete) { drill in
            Button("Delete", role: .destructive) {
                DrillConfigStorage.shared.delete(drill)
                drills = DrillConfigStorage.shared.getAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: { drill in
            Text("Are you sure you want to delete \(drill.name)? This cannot be undone.")
        }
    }
}
    
    
struct DrillListItemView: View {
    let drill: DrillConfig
    let index: Int
    
    var totalSets: Int {
        drill.sets.count
    }
    var totalDuration: Int {
        Int(drill.sets.reduce(0) { $0 + $1.duration })
    }
    var totalShots: Int? {
        // Fix: check if numberOfShots is optional, otherwise just sum
        let shots = drill.sets.map { $0.numberOfShots }
        // If numberOfShots is optional Int?
        if let firstNil = shots.first(where: { ($0 as Any?) == nil }) {
            return nil // Infinite
        }
        return shots.compactMap { $0 }.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top 1/3: Row 1 with light gray background
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundColor(.red)
                    Text("#\(index)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(drill.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: geometry.size.height / 3)
                .padding(.horizontal)
                .background(.gray.opacity(0.2))
                // Bottom 2/3:
                HStack(alignment: .center) {
                    HStack(spacing: 0) {
                        Spacer()
                        VStack {
                            Text("\(totalSets)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Sets")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("|")
                            .foregroundColor(.gray)
                        Spacer()
                        VStack {
                            Text("\(totalDuration)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Duration")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("|")
                            .foregroundColor(.gray)
                        Spacer()
                        VStack {
                            if let shots = totalShots {
                                Text("\(shots)")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "infinity")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                            Text("Shots")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.red)
                        .padding(.leading, 8)
                }
                .padding(8)
                .frame(height: geometry.size.height * 2 / 3)
                .background(.gray.opacity(0.6))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.vertical, 4)
        }
        .frame(height: 100) // Adjust height as needed
    }
}