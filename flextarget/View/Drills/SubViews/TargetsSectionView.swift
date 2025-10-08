import SwiftUI

/*
 */

struct TargetsSectionView: View {
    @Binding var isTargetListReceived: Bool
    let bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onTargetConfigDone: () -> Void

    var body: some View {
        NavigationLink(destination: TargetConfigListView(deviceList: bleManager.networkDevices, targetConfigs: $targetConfigs, onDone: onTargetConfigDone)) {
            HStack(spacing: 8) {
                // Shield icon on the left
                Image(systemName: "shield")
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .overlay(
                        Circle().stroke(Color.red, lineWidth: 2)
                    )

                // Text label
                Text(NSLocalizedString("targets", comment: "Targets label"))
                    .foregroundColor(.white)
                    .font(.headline)

                Spacer()

                // Count
                Text(String(format: NSLocalizedString("targets_count_label", comment: "Number of targets"), targetConfigs.count))
                    .foregroundColor(.white)
                    .font(.headline)

                Spacer()

                // > symbol
                Text(">")
                    .foregroundColor(.gray)
                    .font(.headline)
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
                    bleManager: BLEManager.shared,
                    targetConfigs: .constant([
                        DrillTargetsConfigData(seqNo: 1, targetName: "Target A", targetType: "Standard", timeout: 30, countedShots: 5),
                        DrillTargetsConfigData(seqNo: 2, targetName: "Target B", targetType: "Paper", timeout: 25, countedShots: 3),
                        DrillTargetsConfigData(seqNo: 3, targetName: "Target C", targetType: "Electronic", timeout: 20, countedShots: 10)
                    ]),
                    onTargetConfigDone: {}
                )
            }
            .padding()
        }
        .environmentObject(BLEManager.shared)
    }
}
