import SwiftUI
import CoreData

/**
 Wrapper view that uses the unified DrillFormView in edit mode
 */
struct EditDrillView: View {
    let drillSetup: DrillSetup
    let bleManager: BLEManager
    var onCreateNewDrillSetup: (() -> Void)? = nil
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        DrillFormView(bleManager: bleManager, mode: .edit(drillSetup))
            .environment(\.managedObjectContext, viewContext)
    }
}

struct EditDrillView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleDrillSetup = DrillSetup(context: context)
        sampleDrillSetup.id = UUID()
        sampleDrillSetup.name = "Sample Drill"
        sampleDrillSetup.desc = "A sample drill for testing"
        sampleDrillSetup.delay = 5.0
        
        let sampleTarget = DrillTargetsConfig(context: context)
        sampleTarget.id = UUID()
        sampleTarget.seqNo = 1
        sampleTarget.targetName = "Target 1"
        sampleTarget.targetType = "Standard"
        sampleTarget.timeout = 30
        sampleTarget.countedShots = 5
        sampleTarget.drillSetup = sampleDrillSetup
        
        return EditDrillView(drillSetup: sampleDrillSetup, bleManager: BLEManager.shared)
            .environment(\.managedObjectContext, context)
            .environmentObject(BLEManager.shared)
    }
}
