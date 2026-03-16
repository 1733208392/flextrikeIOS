import SwiftUI

/**
 Wrapper view that uses the unified DrillFormView in add mode
 */
struct AddDrillView: View {
    let bleManager: BLEManager
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var defaultDrill: DrillSetup?
    @State private var isLoading = true
    
    var body: some View {
        if isLoading {
            ProgressView()
                .onAppear {
                    createAndNavigateToDefaultDrill()
                }
        } else if let drill = defaultDrill {
            DrillFormView(bleManager: bleManager, mode: .edit(drill), isFromNewDrill: true)
                .environment(\.managedObjectContext, viewContext)
        } else {
            DrillFormView(bleManager: bleManager, mode: .add)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func createAndNavigateToDefaultDrill() {
        do {
            let newDrill = DrillSetup(context: viewContext)
            newDrill.id = UUID()
            newDrill.name = "QUICK DRILL"
            newDrill.desc = nil
            newDrill.repeats = 1
            newDrill.pause = 5
            newDrill.drillDuration = 5.0
            newDrill.mode = "ipsc"
            
            try viewContext.save()
            print("Default drill created successfully with ID: \(newDrill.id?.uuidString ?? "unknown")")
            
            DispatchQueue.main.async {
                defaultDrill = newDrill
                isLoading = false
            }
        } catch {
            print("Failed to create default drill: \(error)")
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
}

struct AddDrillView_Previews: PreviewProvider {
    static var previews: some View {
        AddDrillView(bleManager: BLEManager.shared)
            .environmentObject(BLEManager.shared)
    }
}

import SwiftUI

struct AddDrillEntryView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var drillSetups: [DrillSetupData] = []
    
    var body: some View {
        VStack {
            if drillSetups.isEmpty {
                AddDrillView(bleManager: bleManager)
            } else {
                // TODO: Handle the case when there are existing DrillSetups
                Text(NSLocalizedString("drill_setups_exist", comment: "Drill setups exist message"))
            }
        }
        .onAppear {
            loadDrills()
        }
    }
    
    private func loadDrills() {
        do {
            drillSetups = try DrillRepository.shared.fetchAllDrillSetups()
        } catch {
            print("Failed to load drills: \(error)")
            drillSetups = []
        }
    }
}
