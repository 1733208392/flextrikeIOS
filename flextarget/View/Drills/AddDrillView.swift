import SwiftUI

/**
 Wrapper view that uses the unified DrillFormView in add mode
 */
struct AddDrillView: View {
    let bleManager: BLEManager
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        DrillFormView(bleManager: bleManager, mode: .add)
            .environment(\.managedObjectContext, viewContext)
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
