import SwiftUI

/*
 */

struct TargetsSectionView: View {
    @Binding var isTargetListReceived: Bool
    let bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onTargetConfigDone: () -> Void
    var disabled: Bool = false
    var onDisabledTap: (() -> Void)? = nil
    @Binding var drillMode: String
    var hasResults: Bool = false
    var onSettings: (() -> Void)? = nil
    var onStartDrill: (() -> Void)? = nil

    var body: some View {
        Group {
            if disabled, let onDisabledTap = onDisabledTap {
                Button(action: onDisabledTap) {
                    HStack(spacing: 8) {
                        // Shield icon on the left
                        Image(systemName: "shield")
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                            .overlay(
                                Circle().stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 2)
                            )

                        // Text label
                        Text(String(format: NSLocalizedString("targets_screen", comment: "Targets label"), targetConfigs.count))
                            .foregroundColor(.white)
                            .font(.headline)
                            .onAppear {
                                print("TargetsSectionView: Displaying count \(targetConfigs.count)")
                            }

                        Spacer()

                        // Chevron right icon
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.gray.opacity(targetConfigs.count > 0 ? 0.2 : 0.1))
                    .cornerRadius(16)
                    .opacity(isTargetListReceived ? 1.0 : 0.6)
                }
            } else {
                // Conditional navigation: TargetLinkView for multiple devices, TargetConfigListViewV2 for single device
                if bleManager.networkDevices.count > 1 {
                    NavigationLink(destination: TargetLinkView(bleManager: bleManager, targetConfigs: $targetConfigs, onDone: onTargetConfigDone, drillMode: $drillMode, hasResults: hasResults, onSettings: onSettings, onStartDrill: onStartDrill)) {
                        targetButtonContent
                    }
                    .disabled(!isTargetListReceived)
                } else {
                    NavigationLink(destination: TargetConfigListViewV2(deviceList: bleManager.networkDevices, targetConfigs: $targetConfigs, onDone: onTargetConfigDone, drillMode: $drillMode, singleDeviceMode: true, isFromTargetLink: false, hasResults: hasResults, onSettings: onSettings, onStartDrill: onStartDrill)) {
                        targetButtonContent
                    }
                    .disabled(!isTargetListReceived)
                }
            }
        }
    }
    
    private var targetButtonContent: some View {
        HStack(spacing: 8) {
            // Shield icon on the left
            Image(systemName: "shield")
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(
                    Circle().stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 2)
                )

            // Text label
            Text(String(format: NSLocalizedString("targets_screen", comment: "Targets label"), targetConfigs.count))
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            // Chevron right icon
            Image(systemName: "chevron.right")
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .font(.headline)
        }
        .padding()
        .background(Color.gray.opacity(targetConfigs.count > 0 ? 0.2 : 0.1))
        .cornerRadius(16)
        .opacity(isTargetListReceived ? 1.0 : 0.6)
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
                        DrillTargetsConfigData(seqNo: 1, targetName: "Target A", targetType: "ipsc", timeout: 30, countedShots: 5),
                        DrillTargetsConfigData(seqNo: 2, targetName: "Target B", targetType: "ipsc", timeout: 25, countedShots: 3)
                    ]),
                    onTargetConfigDone: {},
                    drillMode: .constant("ipsc")
                )
            }
            .padding()
        }
    }
}
