import SwiftUI

/**
 `DrillSetupSectionView` is a SwiftUI component for displaying and configuring drill setup parameters.
 
 This view provides:
 - A button to open drill setup modal
 - Visual display of current drill configuration (sets, duration, shots)
 - Conditional styling based on setup enabled state
 - Integration with drill setup sheet
 
 ## Features
 - Shows current drill parameters in a clean layout
 - Disabled state when setup is not enabled
 - Modal sheet presentation for detailed configuration
 - Consistent styling with app design system
 */

struct TargetsSectionView: View {
    @Binding var isTargetListReceived: Bool
    @EnvironmentObject private var bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfig]

    var body: some View {
        NavigationLink(destination: TargetConfigView(deviceList: bleManager.networkDevices, targetConfigs: $targetConfigs)) {
            HStack(spacing: 8) {
                Text("Add Target")
                    .foregroundColor(.white)
                    .font(.headline)
                Spacer()
                Text("\(targetConfigs.count)")
                    .foregroundColor(.white)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(targetConfigs.count > 0 ? 0.2 : 0.1))
            .cornerRadius(16)
            .opacity(isTargetListReceived ? 1.0 : 0.6)
        }
        .disabled(!isTargetListReceived)
    }
}

struct DrillSetupSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                TargetsSectionView(
                    isTargetListReceived: .constant(true),
                    targetConfigs: .constant([
                        DrillTargetsConfig(seqNo: 1, targetName: "Target A", targetType: "Standard", timeout: 30, countedShots: 5),
                        DrillTargetsConfig(seqNo: 2, targetName: "Target B", targetType: "Paper", timeout: 25, countedShots: 3),
                        DrillTargetsConfig(seqNo: 3, targetName: "Target C", targetType: "Electronic", timeout: 20, countedShots: 10)
                    ])
                )
            }
            .padding()
        }
    }
}
