//
//  DrillListView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/9/27.
//


import SwiftUI
import CoreData

struct DrillListView: View {
    let bleManager: BLEManager
    @State private var searchText: String = ""
    @State private var showConnectionAlert = false
    @State private var alertMessage = ""

    @Environment(\.managedObjectContext) private var environmentContext

    // Use the shared persistence controller's viewContext as a fallback to
    // ensure we always point at a live store even if the environment is missing
    private var viewContext: NSManagedObjectContext {
        if let coordinator = environmentContext.persistentStoreCoordinator,
           coordinator.persistentStores.isEmpty == false {
            return environmentContext
        }
        return PersistenceController.shared.container.viewContext
    }
    
    @FetchRequest(
        entity: DrillSetup.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillSetup.name, ascending: true)],
        animation: .default
    ) private var drills: FetchedResults<DrillSetup>
    @State private var showDeleteAlert = false
    @State private var drillToDelete: DrillSetup?

    private var filteredDrills: [DrillSetup] {
        let all = Array(drills)
        if searchText.isEmpty { return all }
        return all.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    ForEach(filteredDrills, id: \.objectID) { drill in
                        drillRow(for: drill)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("My Drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.isConnected {
                        NavigationLink(destination: AddDrillView(bleManager: bleManager)) {
                            Image(systemName: "plus")
                        }
                    } else {
                        Button(action: {
                            alertMessage = "Please connect to the target device before adding drills."
                            showConnectionAlert = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .tint(.red)
            .alert("Delete Drill?", isPresented: $showDeleteAlert, presenting: drillToDelete) { drill in
                Button("Delete", role: .destructive) {
                    deleteDrill(drill)
                }
                Button("Cancel", role: .cancel) {}
            } message: { drill in
                Text("Are you sure you want to delete \(drill.name ?? "this drill")?")
            }
            .alert("Connection Required", isPresented: $showConnectionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .environment(\.managedObjectContext, viewContext)
    }

    // MARK: - Row View
    
    @ViewBuilder
    private func drillRow(for drill: DrillSetup) -> some View {
        ZStack {
            NavigationLink(destination: EditDrillView(drillSetup: drill, bleManager: bleManager)) {
                EmptyView()
            }
            .opacity(0)
            
            drillRowContent(for: drill)
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func drillRowContent(for drill: DrillSetup) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name ?? "Untitled")
                    .foregroundColor(.white)
                    .font(.headline)
                
                drillInfo(for: drill)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                copyDrill(drill)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.gray)

            Button(role: .destructive) {
                drillToDelete = drill
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func drillInfo(for drill: DrillSetup) -> some View {
        HStack(spacing: 8) {
            let targetCount = (drill.targets as? Set<DrillTargetsConfig>)?.count ?? 0
            Text("\(targetCount) targets")
                .foregroundColor(.gray)
                .font(.caption)
            
            if drill.delay > 0 {
                Text("delay: \(Int(drill.delay))s")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func copyDrill(_ drill: DrillSetup) {
        let new = DrillSetup(context: viewContext)
        new.id = UUID()
        new.name = (drill.name ?? "") + " Copy"
        new.desc = drill.desc
        new.delay = drill.delay

        if let targets = drill.targets as? Set<DrillTargetsConfig> {
            for t in targets.sorted(by: { $0.seqNo < $1.seqNo }) {
                let nt = DrillTargetsConfig(context: viewContext)
                nt.id = t.id ?? UUID()
                nt.seqNo = t.seqNo
                nt.targetName = t.targetName
                nt.targetType = t.targetType
                nt.timeout = t.timeout
                nt.countedShots = t.countedShots
                nt.drillSetup = new
            }
        }

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
        } catch {
            viewContext.rollback()
            print("Failed to copy drill: \(error)")
        }
    }

    private func deleteDrill(_ drill: DrillSetup) {
        viewContext.delete(drill)
        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
        } catch {
            viewContext.rollback()
            print("Failed to delete drill: \(error)")
        }
    }
}

struct DrillListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        DrillListView(bleManager: BLEManager.shared)
            .environment(\.managedObjectContext, context)
            .environmentObject(BLEManager.shared)
            .preferredColorScheme(.dark)
    }
}
