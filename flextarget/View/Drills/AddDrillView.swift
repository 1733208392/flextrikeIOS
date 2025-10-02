import PhotosUI
import SwiftUI
import UIKit
import PhotosUI

/**
 */

struct AddDrillView: View {
    let bleManager: BLEManager
    @State private var drillName: String = ""
    @State private var description: String = ""
    @State private var demoVideoURL: URL? = nil
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var demoVideoThumbnail: UIImage? = nil
    @State private var thumbnailFileURL: URL? = nil
    @State private var showVideoPlayer: Bool = false
    @State private var delayType: DelayConfigurationView.DelayType = .fixed
    @State private var delayValue: Double = 0
    @State private var targets: [DrillTargetsConfigData] = []
    @State private var isTargetListReceived: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @State private var targetConfigs: [DrillTargetsConfigData] = []
    @State private var networkDevices: [NetworkDevice] = []
    
    private func buildDrillSetup() -> DrillSetupData {
        return DrillSetupData(
            name: drillName,
            description: description,
            demoVideoURL: demoVideoURL,
            thumbnailURL: thumbnailFileURL,
            delay: delayValue,
            targets: targetConfigs
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
                            NavigationLink(destination: DrillRecordView()) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.red, lineWidth: 1)
                                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.clear))
                                        .frame(height: 36)
                                        .overlay(
                                            HStack(spacing: 8) {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(.red)
                                                    .font(.title3)
                                                Text("History Record")
                                                    .foregroundColor(.white)
                                                    .font(.footnote)
                                            }
                                        )
                                        .padding(.horizontal)
                                        .padding(.top)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                bleManager: bleManager,
                                targetConfigs: $targetConfigs,
                                onTargetConfigDone: { targets = targetConfigs }
                            )
                            .padding(.horizontal)
                            Spacer()
                            
                            // Bottom Buttons
                            HStack {
                                Button(action: {
                                    guard bleManager.isConnected else { return }
                                    guard !networkDevices.isEmpty else { return }
                                    targets = targetConfigs
                                    if validateFields() {
                                        let setup = buildDrillSetup()
                                        do {
                                            try DrillRepository.shared.saveDrillSetup(setup)
                                            presentationMode.wrappedValue.dismiss()
                                        } catch {
                                            print("Failed to save drill setup: \(error)")
                                        }
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
                self.networkDevices = deviceList
                self.isTargetListReceived = true
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
                Text("Drill setups exist. TODO: Show list or main view.")
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
