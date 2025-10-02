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
                
                // Copy the actual video and thumbnail files to new locations
                let copiedVideoURL = drillData.demoVideoURL.flatMap { copyFile(from: $0) }
                let copiedThumbnailURL = drillData.thumbnailURL.flatMap { copyFile(from: $0) }
                
                let newDrillData = DrillSetupData(
                    id: UUID(),
                    name: drillData.name + " Copy",
                    description: drillData.description,
                    demoVideoURL: copiedVideoURL,
                    thumbnailURL: copiedThumbnailURL,
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
    
    private func copyFile(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        
        // Check if source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            print("Source file does not exist at: \(sourceURL.path)")
            return nil
        }
        
        // Create destination URL with new UUID
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
        let dest = docs.appendingPathComponent(UUID().uuidString + "." + ext)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: dest)
            print("Successfully copied file to: \(dest.lastPathComponent)")
            return dest
        } catch {
            print("Failed to copy file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func deleteButton(for drill: DrillSetup) -> some View {
        Button(role: .destructive) {
            drillToDelete = drill
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
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
                    listView
                }
            }
            .navigationTitle("Drill List")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search drills")
            .toolbar {
                // Removed Cancel button per design - rely on system back button
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
        .tint(.red)
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
    
    var totalTargets: Int {
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
                            Text("\(totalTargets)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Targets")
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

struct DrillListView_Previews: PreviewProvider {
    static var previews: some View {
        // Use shared BLEManager instance for preview
        PreviewDrillListView(bleManager: BLEManager.shared)
            .preferredColorScheme(.dark)
    }
}

struct PreviewDrillListView: View {
    let bleManager: BLEManager
    @State private var searchText: String = ""
    @State private var drills: [DrillSetup] = []
    
    var filteredDrills: [DrillSetup] {
        if searchText.isEmpty {
            return drills
        } else {
            return drills.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
    
    private func drillRow(for drill: DrillSetup, at index: Int) -> some View {
        ZStack {
            NavigationLink(destination: Text("Edit Drill")) { // Mock destination
                EmptyView()
            }
            .opacity(0)
            
            let itemView = DrillListItemView(drill: drill, index: index + 1)
                .listRowInsets(EdgeInsets())
            
            itemView
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        // Mock copy action
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .tint(Color.gray)
                    
                    Button(role: .destructive) {
                        // Mock delete action
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listRowBackground(Color.clear)
        .background(Color.clear)
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
                    listView
                }
            }
            .navigationTitle("Drill List")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .tint(.red)
        .onAppear {
            drills = createMockDrills()
        }
    }
    
    private func createMockDrills() -> [DrillSetup] {
        let context = PersistenceController.preview.container.viewContext
        
        let drill1 = DrillSetup(context: context)
        drill1.id = UUID()
        drill1.name = "Basic Pistol Drill"
        drill1.desc = "A fundamental drill for pistol marksmanship"
        drill1.delay = 2.0
        
        let target1 = DrillTargetsConfig(context: context)
        target1.id = UUID()
        target1.seqNo = 1
        target1.targetName = "Target A"
        target1.targetType = "Standard"
        target1.timeout = 5.0
        target1.countedShots = 5
        target1.drillSetup = drill1
        
        let drill2 = DrillSetup(context: context)
        drill2.id = UUID()
        drill2.name = "Advanced Rifle Course"
        drill2.desc = "Complex rifle drill with multiple targets"
        drill2.delay = 3.0
        
        let target2 = DrillTargetsConfig(context: context)
        target2.id = UUID()
        target2.seqNo = 1
        target2.targetName = "Target B"
        target2.targetType = "Popper"
        target2.timeout = 8.0
        target2.countedShots = 3
        target2.drillSetup = drill2
        
        let target3 = DrillTargetsConfig(context: context)
        target3.id = UUID()
        target3.seqNo = 2
        target3.targetName = "Target C"
        target3.targetType = "Steel"
        target3.timeout = 6.0
        target3.countedShots = 2
        target3.drillSetup = drill2
        
        let drill3 = DrillSetup(context: context)
        drill3.id = UUID()
        drill3.name = "Speed Shooting"
        drill3.desc = "Fast-paced drill for reaction time"
        drill3.delay = 1.0
        
        let target4 = DrillTargetsConfig(context: context)
        target4.id = UUID()
        target4.seqNo = 1
        target4.targetName = "Target D"
        target4.targetType = "Hostage"
        target4.timeout = 3.0
        target4.countedShots = 1
        target4.drillSetup = drill3
        
        return [drill1, drill2, drill3]
    }
}
