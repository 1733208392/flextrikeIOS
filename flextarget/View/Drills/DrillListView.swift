//
//  DrillListView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/9/27.
//


import SwiftUI

struct DrillListView: View {
    let bleManager: BLEManager
    @State private var searchText: String = ""
    @State private var drills: [DrillSetup] = []
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = DrillRepository.shared
    // For showing alerts
    @State private var showDeleteAlert = false
    @State private var drillToDelete: DrillSetup?

    var filteredDrills: [DrillSetup] {
        if searchText.isEmpty {
            return drills
        } else {
            return drills.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    private func drillRow(for drill: DrillSetup, at index: Int) -> some View {
        ZStack {
            NavigationLink(destination: EditDrillView(drillSetup: drill, bleManager: bleManager)) {
                EmptyView()
            }
            .opacity(0)
            
            let itemView = DrillListItemView(drill: drill, index: index + 1)
                .listRowInsets(EdgeInsets())
            
            itemView
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    copyButton(for: drill)
                    deleteButton(for: drill)
                }
        }
        .listRowBackground(Color.clear)
        .background(Color.clear)
    }
    
    private func copyButton(for drill: DrillSetup) -> some View {
        Button {
            do {
                let drillData = drill.toStruct()
                let newDrillData = DrillSetupData(
                    id: UUID(),
                    name: drillData.name + " Copy",
                    description: drillData.description,
                    demoVideoURL: drillData.demoVideoURL,
                    thumbnailURL: drillData.thumbnailURL,
                    delay: drillData.delay,
                    targets: drillData.targets
                )
                try repository.saveDrillSetup(newDrillData)
                drills = try repository.fetchAllDrillSetupsAsCoreData()
            } catch {
                print("Failed to copy drill: \(error)")
            }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .tint(Color.gray)
    }
    
    private func deleteButton(for drill: DrillSetup) -> some View {
        Button(role: .destructive) {
            drillToDelete = drill
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var headerView: some View {
        Text("Select a Drill")
            .font(.title)
            .foregroundColor(.white)
            .padding()
    }
    
    private var listView: some View {
        List {
            ForEach(filteredDrills.indices, id: \.self) { index in
                drillRow(for: filteredDrills[index], at: index)
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    headerView
                    listView
                }
            }
            .navigationTitle("Drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddDrillView(bleManager: bleManager)) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Delete Drill", isPresented: $showDeleteAlert, presenting: drillToDelete) { drill in
                Button("Delete", role: .destructive) {
                    do {
                        try repository.deleteDrillSetup(withId: drill.id ?? UUID())
                        drills = try repository.fetchAllDrillSetupsAsCoreData()
                    } catch {
                        print("Failed to delete drill: \(error)")
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { drill in
                Text("Are you sure you want to delete \(drill.name ?? "this drill")? This cannot be undone.")
            }
        }
        .onAppear {
            do {
                drills = try repository.fetchAllDrillSetupsAsCoreData()
            } catch {
                print("Failed to load drills: \(error)")
            }
        }
    }
}
    
    
struct DrillListItemView: View {
    let drill: DrillSetup
    let index: Int
    
    var totalSets: Int {
        drill.targets?.count ?? 0
    }
    
    var totalDuration: Int {
        let targets = drill.targets?.allObjects as? [DrillTargetsConfig] ?? []
        return Int(targets.reduce(0) { $0 + $1.timeout })
    }
    
    var totalShots: Int {
        let targets = drill.targets?.allObjects as? [DrillTargetsConfig] ?? []
        return targets.reduce(0) { $0 + Int($1.countedShots) }
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
                    Text(drill.name ?? "Unnamed Drill")
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
                            Text("\(totalShots)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
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
