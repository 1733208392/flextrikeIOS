import PhotosUI
import SwiftUI
import UIKit
import PhotosUI

/**
 */

struct AddDrillView: View {
    @State private var drillName: String = ""
    @State private var description: String = ""
    @State private var demoVideoURL: URL? = nil
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var demoVideoThumbnail: UIImage? = nil
    @State private var thumbnailFileURL: URL? = nil
    @State private var showVideoPlayer: Bool = false
    @State private var delayType: DelayConfigurationView.DelayType = .fixed
    @State private var delayValue: Double = 0
    @State private var targets: [DrillTargetsConfig] = []
    @State private var isTargetListReceived: Bool = false
    @EnvironmentObject private var bleManager: BLEManager
    @Environment(\.presentationMode) var presentationMode
    @State private var targetConfigs: [DrillTargetsConfig] = []
    
    private func buildDrillSetup() -> DrillSetup {
        return DrillSetup(
            name: drillName,
            description: description,
            demoVideoURL: demoVideoURL,
            thumbnailURL: thumbnailFileURL,
            delay: delayValue,
            targets: targets
        )
    }
    
    private func validateFields() -> Bool {
        // Title and description must not be empty
        guard !drillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        // Number of targets must be > 0
        guard targets.count > 0 else {
            return false
        }
        // For each target, timeout and countedShots must be > 0
        for target in targets {
            if target.timeout <= 0 || target.countedShots <= 0 {
                return false
            }
        }
        
        return true
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.ignoresSafeArea()
                        .onTapGesture {
                            // Dismiss any active keyboard focus
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        VStack(spacing: 20) {
                            // History Record Button
                            HistoryRecordButtonView {
                                // TODO: Implement history record functionality
                                print("History Record button tapped")
                            }
                            ScrollView {
                            // Grouped Section: Drill Name, Description, Add Video
                            VStack(spacing: 20) {
                                // Drill Name
                                DrillNameSectionView(drillName: $drillName)
                                
                                // Description & Add Video Section
                                DescriptionVideoSectionView(
                                    description: $description,
                                    demoVideoURL: $demoVideoURL,
                                    selectedVideoItem: $selectedVideoItem,
                                    demoVideoThumbnail: $demoVideoThumbnail,
                                    thumbnailFileURL: $thumbnailFileURL,
                                    showVideoPlayer: $showVideoPlayer
                                )
                                .sheet(isPresented: $showVideoPlayer) {
                                    if let url = demoVideoURL {
                                        VideoPlayerView(url: url)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20)
                            .padding(.horizontal)
                            
                            // Delay of Set Starting
                            DelayConfigurationView(
                                delayType: $delayType,
                                delayValue: $delayValue
                            )
                            .padding(.horizontal)
                            
                            
                            // Drill Setup Field
                            TargetsSectionView(
                                isTargetListReceived: $isTargetListReceived,
                                targetConfigs: $targetConfigs,
                                onTargetConfigDone: { targets = targetConfigs }
                            )
                            .padding(.horizontal)
                            Spacer()
                            
                            // Bottom Buttons
                            HStack {
                                Button(action: {
                                    targets = targetConfigs
                                    if validateFields() {
                                        let setup = buildDrillSetup()
                                        DrillSetupStorage.shared.addDrillSetup(setup)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    Text("Save Drill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                            .onAppear {
                                queryDeviceList()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .bleDeviceListUpdated)) { notification in
                                handleDeviceListUpdate(notification)
                            }
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Device List Query Methods
    
    private func queryDeviceList() {
        guard bleManager.isConnected else {
            print("BLE not connected, cannot query device list")
            return
        }
        
        let command = ["type": "netlink", "action": "query_device_list"]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                bleManager.writeJSON(jsonString)
                print("Sent query_device_list command: \(jsonString)")
            }
        } catch {
            print("Failed to serialize query_device_list command: \(error)")
        }
    }
    
    private func handleDeviceListUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deviceList = userInfo["device_list"] as? [NetworkDevice] {
            print("Device list received with \(deviceList.count) devices")
            DispatchQueue.main.async {
                self.isTargetListReceived = true
            }
        }
    }
}

struct AddDrillView_Previews: PreviewProvider {
    static var previews: some View {
        AddDrillView()
    }
}

import SwiftUI

struct AddDrillEntryView: View {
    @ObservedObject private var storage = DrillSetupStorage.shared
    
    var body: some View {
        if storage.drillSetups.isEmpty {
            AddDrillView()
        } else {
            // TODO: Handle the case when there are existing DrillSetups
            Text("Drill setups exist. TODO: Show list or main view.")
        }
    }
}
