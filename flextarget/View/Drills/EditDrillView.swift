import PhotosUI
import SwiftUI
import UIKit
import PhotosUI

/**
 */

struct EditDrillView: View {
    let drillSetup: DrillSetup
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
    @State private var navigateToDrillResult: Bool = false
    
    init(drillSetup: DrillSetup, bleManager: BLEManager) {
        self.drillSetup = drillSetup
        self.bleManager = bleManager
        _drillName = State(initialValue: drillSetup.name ?? "")
        _description = State(initialValue: drillSetup.desc ?? "")
        _demoVideoURL = State(initialValue: drillSetup.demoVideoURL)
        _thumbnailFileURL = State(initialValue: drillSetup.thumbnailURL)
        _delayValue = State(initialValue: drillSetup.delay)
        
        // Convert NSSet to Array and transform to Data structs
        let coreDataTargets = (drillSetup.targets as? Set<DrillTargetsConfig>) ?? []
        let targetsArray = coreDataTargets.sorted(by: { $0.seqNo < $1.seqNo }).map { $0.toStruct() }
        _targets = State(initialValue: targetsArray)
        _targetConfigs = State(initialValue: targetsArray)
    }
    
    private func loadThumbnail() {
        if let url = thumbnailFileURL {
            do {
                let data = try Data(contentsOf: url)
                demoVideoThumbnail = UIImage(data: data)
            } catch {
                print("Failed to load thumbnail: \(error)")
            }
        }
    }
    
    private func buildDrillSetup() -> DrillSetup {
        // Update the existing drill setup with new values
        drillSetup.name = drillName
        drillSetup.desc = description
        drillSetup.demoVideoURL = demoVideoURL
        drillSetup.thumbnailURL = thumbnailFileURL
        drillSetup.delay = delayValue
        
        // Clear existing targets and add updated ones
        if let existingTargets = drillSetup.targets {
            drillSetup.removeFromTargets(existingTargets)
        }
        
        // Convert targetConfigs back to CoreData objects and add them
        for targetData in targetConfigs {
            let target = DrillTargetsConfig(context: drillSetup.managedObjectContext!)
            target.id = targetData.id
            target.seqNo = Int32(targetData.seqNo)
            target.targetName = targetData.targetName
            target.targetType = targetData.targetType
            target.timeout = targetData.timeout
            target.countedShots = Int32(targetData.countedShots)
            target.drillSetup = drillSetup
        }
        
        return drillSetup
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
                                bleManager: BLEManager.shared,
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
                                        do {
                                            try DrillRepository.shared.saveDrillSetup(setup.toStruct())
                                            presentationMode.wrappedValue.dismiss()
                                        } catch {
                                            print("Failed to save drill setup: \(error)")
                                        }
                                    }
                                }) {
                                    Text("Save Changes")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                                Button(action: {
                                    sendStartDrillMessages()
                                }) {
                                    Text("Start Drill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                            .onAppear {
                                queryDeviceList()
                                loadThumbnail()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .bleDeviceListUpdated)) { notification in
                                handleDeviceListUpdate(notification)
                            }
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToDrillResult) {
            DrillResultView(drillSetup: buildDrillSetup())
        }
    }
    
    private func sendStartDrillMessages() {
        guard bleManager.isConnected else {
            print("BLE not connected")
            return
        }
        let setup = buildDrillSetup()
        targets = targetConfigs
        
        // Convert NSSet to Array and enumerate
        guard let targetsSet = setup.targets as? Set<DrillTargetsConfig> else { return }
        let sortedTargets = targetsSet.sorted { $0.seqNo < $1.seqNo }
        
        for (index, target) in sortedTargets.enumerated() {
            do {
                let delay = index == 0 ? setup.delay : 0
                let content: [String: Any] = [
                    "command": "ready",
                    "delay": delay,
                    "targetType": target.targetType,
                    "timeout": target.timeout,
                    "countedShots": target.countedShots
                ]
                let message: [String: Any] = ["type": "netlink", "action": "forward", "dest": target.targetName, "content": content]
                let messageData = try JSONSerialization.data(withJSONObject: message, options: [])
                let messageString = String(data: messageData, encoding: .utf8)!
                print("Sending forward message for target \(target.targetName), length: \(messageData.count)")
                bleManager.writeJSON(messageString)
            } catch {
                print("Failed to send start drill message for target \(target.targetName): \(error)")
            }
        }
        // Navigate to DrillResultView after starting the drill
        navigateToDrillResult = true
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
                print("Query message length: \(jsonData.count)")
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
