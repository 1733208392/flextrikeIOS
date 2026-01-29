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
    @Binding var showDrillList: Bool
    var onDrillSelected: ((DrillSetup) -> Void)? = nil
    @State private var searchText: String = ""
    @State private var showConnectionAlert = false
    @State private var alertMessage = ""
    @State private var showAddDrillView = false

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
        let all = Array(drills).sorted { (drill1, drill2) -> Bool in
            let count1 = (drill1.results as? Set<DrillResult>)?.count ?? 0
            let count2 = (drill2.results as? Set<DrillResult>)?.count ?? 0
            return count1 > count2 // Descending order
        }
        
        if searchText.isEmpty { return all }
        return all.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
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
        .navigationTitle(NSLocalizedString("drill_setup", comment: "Navigation title for drill list"))
        .navigationBarTitleDisplayMode(.inline)
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
        drillRowContent(for: drill)
            .listRowBackground(Color.clear)
            .onTapGesture {
                onDrillSelected?(drill)
            }
            .contextMenu {
                Button(action: { copyDrill(drill) }) {
                    Label(NSLocalizedString("copy", comment: "Copy drill action"), systemImage: "doc.on.doc")
                }
                
                Button(role: .destructive, action: {
                    drillToDelete = drill
                    showDeleteAlert = true
                }) {
                    Label(NSLocalizedString("delete", comment: "Delete drill action"), systemImage: "trash")
                }
            }
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
                .foregroundColor(.red)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func drillInfo(for drill: DrillSetup) -> some View {
        HStack(spacing: 8) {
            let targetCount = (drill.targets as? Set<DrillTargetsConfig>)?.count ?? 0
            Text(String(format: NSLocalizedString("targets_count", comment: "Number of targets"), targetCount))
                .foregroundColor(.gray)
                .font(.caption)
            
            let performanceCount = (drill.results as? Set<DrillResult>)?.count ?? 0
            Text("\(NSLocalizedString("performed", comment: "Label for number of times drill was performed")): \(performanceCount)")
                .foregroundColor(.gray)
                .font(.caption)

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
        DrillListView(bleManager: BLEManager.shared, showDrillList: .constant(true))
            .environment(\.managedObjectContext, context)
            .environmentObject(BLEManager.shared)
            .preferredColorScheme(.dark)
    }
}
