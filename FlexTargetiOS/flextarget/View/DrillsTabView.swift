import SwiftUI
import CoreData

struct DrillsTabView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var selectedDrillSetup: DrillSetup? = nil
    @State private var selectedDrillShots: [ShotData]? = nil
    @State private var selectedDrillSummaries: [DrillRepeatSummary]? = nil
    @State private var showConnectView = false
    @State private var showQRScanner = false
    @State private var scannedPeripheralName: String? = nil
    @State private var showConnectionAlert = false
    @State private var quickDrillSetup: DrillSetup? = nil
    @State private var showQuickDrillConfig = false
    @State private var quickDrillTargetConfigs: [DrillTargetsConfigData] = []
    @State private var quickDrillMode: String = "ipsc"
    @State private var navigateToTimerSession = false
    @State private var drillSetupForTimer: DrillSetup? = nil
    @State private var showQuickDrillDetailsEditor = false
    @State private var isWaitingForQuickDrillSync = false
    
    // For navigation to results
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    @State private var navigateToDrillSummary = false
    
    // Track if the current quick drill was ever used to record data or has been customized
    private var isQuickDrillDataEmpty: Bool {
        guard let drill = quickDrillSetup else { return true }
        
        // Check if there are any recorded results for this drill
        let resultsCount = (drill.results as? Set<NSManagedObject>)?.count ?? 0
        if resultsCount > 0 { return false }
        
        // Check if the user has modified the name from default "QUICK DRILL"
        if let name = drill.name, name != "QUICK DRILL" { return false }
        
        // Check if the user has added a description
        if let desc = drill.desc, !desc.isEmpty { return false }
        
        // Check if the user has modified default configuration (e.g., repeats > 1 or pause != 5)
        if drill.repeats > 1 { return false }
        if drill.pause != 5 { return false }
        
        return true
    }
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            DrillListView(bleManager: bleManager, showDrillList: .constant(true), onDrillSelected: { drill in
                startEditFlow(for: drill)
            })
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .navigationTitle(NSLocalizedString("drills", comment: "Drills tab title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if bleManager.isConnected {
                            showConnectView = true
                        } else {
                            showQRScanner = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(bleManager.isConnected ? "BleConnect" : "BleDisconnect")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(bleManager.isConnected ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : .gray)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.isConnected {
                        Button(action: createQuickDrill) {
                            Image(systemName: "plus")
                                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        }
                    } else {
                        Button(action: {
                            showConnectionAlert = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        }
                    }
                }
            }
            
            // Quick Drill Navigation - Direct to Target Config
            NavigationLink(isActive: $showQuickDrillConfig) {
                if let drill = quickDrillSetup {
                    if bleManager.networkDevices.count > 1 {
                        TargetLinkView(
                            bleManager: bleManager,
                            targetConfigs: $quickDrillTargetConfigs,
                            onDone: { cancelQuickDrill() },
                            drillMode: $quickDrillMode,
                            onSettings: { showQuickDrillDetailsEditor = true },
                            onStartDrill: { saveAndStartQuickDrill() }
                        )
                    } else {
                        TargetConfigListViewV2(
                            deviceList: bleManager.networkDevices,
                            targetConfigs: $quickDrillTargetConfigs,
                            onDone: { cancelQuickDrill() },
                            drillMode: $quickDrillMode,
                            singleDeviceMode: true,
                            deviceNameFilter: bleManager.networkDevices.first?.name,
                            isFromTargetLink: false,
                            onSettings: { showQuickDrillDetailsEditor = true },
                            onStartDrill: { saveAndStartQuickDrill() }
                        )
                    }
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
            .environment(\.managedObjectContext, managedObjectContext)
            
            NavigationLink(isActive: $navigateToTimerSession) {
                if let drill = drillSetupForTimer {
                    TimerSessionView(
                        drillSetup: drill,
                        bleManager: bleManager,
                        onDrillComplete: { summaries in
                            print("[DrillsTabView] Drill completed with \(summaries.count) summaries")
                            
                            // Save results to Core Data
                            let viewContext = persistenceController.container.viewContext
                            let sessionId = UUID()
                            
                            for (index, summary) in summaries.enumerated() {
                                let result = DrillResult(context: viewContext)
                                result.id = summary.drillResultId ?? UUID()
                                result.sessionId = sessionId
                                result.drillId = drill.id
                                result.date = Date()
                                result.totalTime = NSNumber(value: summary.totalTime)
                                
                                // DrillSetup relationship
                                result.drillSetup = drill
                                
                                // Add shots
                                var cumulativeTime: Double = 0
                                for shotData in summary.shots {
                                    cumulativeTime += shotData.content.timeDiff
                                    let shot = Shot(context: viewContext)
                                    shot.timestamp = Int64(cumulativeTime * 1000)
                                    shot.drillResult = result
                                    
                                    if let jsonData = try? JSONEncoder().encode(shotData),
                                       let jsonString = String(data: jsonData, encoding: .utf8) {
                                        shot.data = jsonString
                                    }
                                }
                            }
                            
                            do {
                                try viewContext.save()
                                print("[DrillsTabView] Saved \(summaries.count) drill results to Core Data")
                                // Notify other views about the data change
                                NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
                            } catch {
                                print("[DrillsTabView] Failed to save drill results: \(error)")
                            }
                            
                            drillRepeatSummaries = summaries
                            
                            // 1. First trigger navigation to summary
                            navigateToDrillSummary = true
                            
                            // 2. Then dismiss the timer in the next run loop
                            DispatchQueue.main.async {
                                navigateToTimerSession = false
                            }
                        },
                        onDrillFailed: {
                            navigateToTimerSession = false
                        }
                    )
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }

            NavigationLink(isActive: $navigateToDrillSummary) {
                if let drill = drillSetupForTimer {
                    DrillSummaryView(drillSetup: drill, summaries: drillRepeatSummaries)
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
            .isDetailLink(false)

            if isWaitingForQuickDrillSync {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)))
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("syncing_devices", comment: "Loading message for device sync"))
                        .foregroundColor(.white)
                        .font(.custom("TTNorms-Medium", size: 16))
                }
                .padding(24)
                .background(Color(.systemGray6).opacity(0.9))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showQuickDrillDetailsEditor) {
            if let drill = quickDrillSetup {
                NavigationView {
                    DrillFormView(
                        bleManager: bleManager,
                        mode: .edit(drill),
                        isFromNewDrill: true,
                        showDetailsByDefault: true
                    )
                    .environment(\.managedObjectContext, managedObjectContext)
                }
            }
        }
        .alert(isPresented: $showConnectionAlert) {
            Alert(title: Text(NSLocalizedString("connection_required", comment: "Alert title for connection required")), message: Text(NSLocalizedString("connect_target_first", comment: "Alert message for connecting target first")), dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button"))))
        }
        .sheet(isPresented: $showConnectView) {
            ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), targetPeripheralName: scannedPeripheralName, isAlreadyConnected: bleManager.isConnected, onConnected: { showConnectView = false })
                .id(scannedPeripheralName)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedText in
                scannedPeripheralName = scannedText
                showQRScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showConnectView = true
                }
            }
        }
        .onAppear {
            if bleManager.isConnected {
                queryDeviceList()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bleDeviceListUpdated)) { _ in
            print("[DrillsTabView] Received bleDeviceListUpdated notification")
            if isWaitingForQuickDrillSync {
                isWaitingForQuickDrillSync = false
                proceedWithQuickDrillCreation()
            }
        }
        .onChange(of: showQuickDrillConfig) { isActive in
            if !isActive && !navigateToTimerSession && !navigateToDrillSummary {
                // Only cleanup if we're not navigating to the timer session or summary
                cancelQuickDrill()
            }
        }
    }
    
    private func cancelQuickDrill() {
        guard let drill = quickDrillSetup else {
            showQuickDrillConfig = false
            return
        }
        
        // Skip deletion if we are actively showing results for this drill
        if navigateToDrillSummary {
            print("[DrillsTabView] Skipping cancelQuickDrill: navigateToDrillSummary is true")
            return
        }
        
        let viewContext = persistenceController.container.viewContext
        
        // Only delete if it's truly empty (no shots/summaries)
        if isQuickDrillDataEmpty {
            print("[DrillsTabView] Deleting empty quick drill: \(drill.id?.uuidString ?? "unknown")")
            viewContext.delete(drill)
            try? viewContext.save()
        }
        
        quickDrillSetup = nil
        showQuickDrillConfig = false
    }

    private func createQuickDrill() {
        // Start waiting for the response
        isWaitingForQuickDrillSync = true
        
        // Refresh device list
        queryDeviceList()
        
        // Safety timeout in case notification is never received
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isWaitingForQuickDrillSync {
                print("[DrillsTabView] Sync timeout, proceeding with current device list")
                self.isWaitingForQuickDrillSync = false
                self.proceedWithQuickDrillCreation()
            }
        }
    }
    
    private func queryDeviceList() {
        guard bleManager.isConnected else { return }
        let queryMessage: [String: Any] = ["action": "netlink_query_device_list"]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: queryMessage, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            bleManager.writeJSON(jsonString)
            print("[DrillsTabView] Sent netlink_query_device_list: \(jsonString)")
        }
    }
    
    private func proceedWithQuickDrillCreation() {
        let viewContext = persistenceController.container.viewContext
        
        do {
            let newDrill = DrillSetup(context: viewContext)
            newDrill.id = UUID()
            newDrill.name = "QUICK DRILL"
            newDrill.desc = ""
            newDrill.repeats = 1
            newDrill.pause = 5
            newDrill.drillDuration = 5.0
            newDrill.mode = "ipsc"
            
            try viewContext.save()
            print("[DrillsTabView] Default quick drill created: \(newDrill.id?.uuidString ?? "unknown")")
            
            // Auto-initialize with current connected devices if possible
            let initialConfigs: [DrillTargetsConfigData] = bleManager.networkDevices.enumerated().map { index, device in
                DrillTargetsConfigData(
                    id: UUID(),
                    seqNo: index + 1,
                    targetName: device.name,
                    targetType: DrillTargetsConfigData.encodeTargetTypes(["ipsc"]),
                    timeout: 30.0,
                    countedShots: 2,
                    action: "none",
                    duration: 0.0,
                    targetVariant: "[]"
                )
            }
            
            DispatchQueue.main.async {
                quickDrillSetup = newDrill
                quickDrillMode = "ipsc"
                quickDrillTargetConfigs = initialConfigs
                showQuickDrillConfig = true
            }
        } catch {
            print("[DrillsTabView] Failed to create quick drill: \(error)")
        }
    }
    
    private func startEditFlow(for drill: DrillSetup) {
        // 1. Prepare Target Configs from the existing drill
        let coreDataTargets = (drill.targets as? Set<DrillTargetsConfig>) ?? []
        self.quickDrillTargetConfigs = coreDataTargets.sorted(by: { $0.seqNo < $1.seqNo }).map { $0.toStruct() }
        self.quickDrillMode = drill.mode ?? "ipsc"
        
        // 2. Set as the active quick drill to reuse the same flow
        self.quickDrillSetup = drill
        self.showQuickDrillConfig = true
    }
    
    private func saveAndStartQuickDrill() {
        guard let drill = quickDrillSetup else {
            print("[DrillsTabView] No quick drill setup available")
            return
        }
        
        do {
            let viewContext = persistenceController.container.viewContext
            
            // First, remove existing targets to avoid duplicates if user comes back and edits again
            if let existingTargets = drill.targets as? Set<NSManagedObject> {
                for target in existingTargets {
                    viewContext.delete(target)
                }
            }
            
            // Create new DrillTargetsConfig objects and add them to the relationship
            for targetData in quickDrillTargetConfigs {
                let target = DrillTargetsConfig(context: viewContext)
                target.id = targetData.id
                target.seqNo = Int32(targetData.seqNo)
                target.targetName = targetData.targetName
                target.targetType = targetData.targetType
                target.timeout = targetData.timeout
                target.countedShots = Int32(targetData.countedShots)
                target.action = targetData.action
                target.duration = targetData.duration
                target.targetVariant = targetData.targetVariant ?? "[]"
                
                drill.addToTargets(target)
            }
            
            // Save to CoreData
            if viewContext.hasChanges {
                try viewContext.save()
                print("[DrillsTabView] Quick drill saved with \(quickDrillTargetConfigs.count) target configs")
            }
            
            // Set up for timer session navigation
            drillSetupForTimer = drill
            navigateToTimerSession = true
            
        } catch {
            print("[DrillsTabView] Failed to save quick drill: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        DrillsTabView()
            .environmentObject(BLEManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
