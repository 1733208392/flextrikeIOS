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
    @Environment(\.dismiss) var dismiss

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
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header with Back Button
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text(NSLocalizedString("back", comment: "Back button label"))
                                .font(.system(size: 16, weight: .regular))
                        }
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(NSLocalizedString("my_drills", comment: "Navigation title for drill list"))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if bleManager.isConnected {
                        NavigationLink(destination: AddDrillView(bleManager: bleManager)) {
                            Image(systemName: "plus")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            alertMessage = NSLocalizedString("connection_required_message", comment: "Message when connection is required")
                            showConnectionAlert = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                List {
                    ForEach(filteredDrills, id: \.objectID) { drill in
                        drillRow(for: drill)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: NSLocalizedString("search_drills", comment: "Search prompt for drills"))
            }
        }
        .tint(.red)
        .alert(NSLocalizedString("delete_drill_title", comment: "Alert title for deleting drill"), isPresented: $showDeleteAlert, presenting: drillToDelete) { drill in
            Button(NSLocalizedString("delete", comment: "Delete button"), role: .destructive) {
                deleteDrill(drill)
            }
            Button(NSLocalizedString("cancel", comment: "Cancel button"), role: .cancel) {}
        } message: { drill in
            Text(String(format: NSLocalizedString("delete_drill_message", comment: "Alert message for deleting drill"), drill.name ?? NSLocalizedString("untitled", comment: "Default name for untitled drill")))
        }
        .alert(NSLocalizedString("connection_required", comment: "Alert title for connection required"), isPresented: $showConnectionAlert) {
            Button(NSLocalizedString("ok", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
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
                Text(drill.name ?? NSLocalizedString("untitled", comment: "Default name for untitled drill"))
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
                Label(NSLocalizedString("copy", comment: "Copy drill action"), systemImage: "doc.on.doc")
            }
            .tint(.gray)

            Button(role: .destructive) {
                drillToDelete = drill
                showDeleteAlert = true
            } label: {
                Label(NSLocalizedString("delete", comment: "Delete drill action"), systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func drillInfo(for drill: DrillSetup) -> some View {
        HStack(spacing: 8) {
            let targetCount = (drill.targets as? Set<DrillTargetsConfig>)?.count ?? 0
            Text(String(format: NSLocalizedString("targets_count", comment: "Number of targets"), targetCount))
                .foregroundColor(.gray)
                .font(.caption)
            
            if drill.repeats > 1 {
                Text("Repeats: \(drill.repeats)")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            if drill.pause > 0 {
                Text("Pause: \(drill.pause)s")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            if drill.delay > 0 {
                Text(String(format: NSLocalizedString("delay_seconds", comment: "Delay in seconds"), Int(drill.delay)))
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func copyDrill(_ drill: DrillSetup) {
        let new = DrillSetup(context: viewContext)
        new.id = UUID()
        new.name = (drill.name ?? "") + NSLocalizedString("copy_suffix", comment: "Suffix added to copied drill name")
        new.desc = drill.desc
        new.delay = drill.delay
        new.repeats = drill.repeats
        new.pause = drill.pause
        new.drillDuration = drill.drillDuration

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
