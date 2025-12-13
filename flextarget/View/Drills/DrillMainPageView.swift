import SwiftUI
import CoreData

struct DrillMainPageView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showDrillList = false
    @State private var showConnectView = false
    @State private var showInfo = false
    @State private var selectedDrillSetup: DrillSetup? = nil
    @State private var selectedDrillShots: [ShotData]? = nil
    @State private var selectedDrillSummaries: [DrillRepeatSummary]? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    let persistenceController = PersistenceController.shared
    @State private var errorObserver: NSObjectProtocol?
    
    // (Image transfer moved to Connect view)
    
    // Image Crop Navigation
    @State private var showImageCrop = false
    
    // QR Scanner Navigation
    @State private var showQRScanner = false
    @State private var scannedPeripheralName: String? = nil
    
    
    var body: some View {
        if showDrillList {
            DrillListView(bleManager: bleManager, showDrillList: $showDrillList)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        } else {
            mainContent
                .sheet(isPresented: $showConnectView) {
                    ConnectSmartTargetWrapper(onDismiss: { showConnectView = false }, targetName: scannedPeripheralName, isConnected: bleManager.isConnected)
                        .id(scannedPeripheralName) // Force re-creation when targetName changes
                }
                .sheet(isPresented: $showInfo) {
                    InformationPage()
                }
                .sheet(isPresented: $showQRScanner) {
                    QRScannerView { scannedText in
                        // Save scanned peripheral name and present connect view
                        scannedPeripheralName = scannedText
                        showQRScanner = false
                        // Small delay to ensure state settles before presenting sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showConnectView = true
                        }
                    }
                }
                .onAppear {
                    // Do not automatically start connection or show Connect view.
                    // User will tap the BLE toolbar button to scan and connect.
                    errorObserver = NotificationCenter.default.addObserver(forName: .bleErrorOccurred, object: nil, queue: .main) { notification in
                        if let error = notification.userInfo?["error"] as? BLEError {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    }
                }
                .onChange(of: bleManager.isConnected) { newValue in
                    // no automatic presentation of connect view
                }
                .onChange(of: selectedDrillSetup) { newValue in
                    if newValue == nil {
                        selectedDrillShots = nil
                        selectedDrillSummaries = nil
                    }
                }
                .onDisappear {
                    if let observer = errorObserver {
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
                .alert(isPresented: $showError) {
                    Alert(title: Text(NSLocalizedString("ble_error", comment: "BLE Error alert title")), message: Text(errorMessage), dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button"))))
                }
                .alert(isPresented: $bleManager.showErrorAlert) {
                    Alert(title: Text("Error"), message: Text(bleManager.errorMessage ?? "Unknown error occurred"), dismissButton: .default(Text("OK")))
                }     
                .navigationViewStyle(.stack)
        }
    }
    
    var mainContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Recent Training (moved to subview)
                RecentTrainingView(selectedDrillSetup: $selectedDrillSetup, selectedDrillShots: $selectedDrillShots, selectedDrillSummaries: $selectedDrillSummaries)
                    .padding(.horizontal)
                    .padding(.top, 16)
                // Menu Buttons
                VStack(spacing: 20) {
                    MainMenuButton(icon: "target", text: NSLocalizedString("drills", comment: "Drills menu button"), color: .red)
                        .onTapGesture {
                            showDrillList = true
                        }
//                     // Disabled IPSC button (non-interactive, visually muted)
//                     MainMenuButton(icon: "scope", text: NSLocalizedString("ipsc_questionaries", comment: "IPSC Questionaries menu button"), color: .gray)
//                         .allowsHitTesting(false)
//                         .opacity(0.6)
//                     // Disabled IDPA button (non-interactive, visually muted)
//                     MainMenuButton(icon: "shield", text: NSLocalizedString("idpa_questionaries", comment: "IDPA Questionaries menu button"), color: .gray)
//                         .allowsHitTesting(false)
//                         .opacity(0.6)
                }
                .padding(.top, 24)
                Spacer()
                // Home Indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 120, height: 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            NavigationLink(isActive: Binding<Bool>(
                get: { selectedDrillSetup != nil },
                set: { newValue in
                    // When navigation is dismissed (newValue == false), clear the selected setup
                    if !newValue {
                        selectedDrillSetup = nil
                    }
                }
            )) {
                if let drillSetup = selectedDrillSetup {
                    if let summaries = selectedDrillSummaries {
                        // Navigate to summary view for recent drills (showing all repeats from session)
                        DrillSummaryView(drillSetup: drillSetup, summaries: summaries)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    } else if let shots = selectedDrillShots {
                        // Navigate to result view for manual drilling
                        DrillResultView(drillSetup: drillSetup, shots: shots)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    } else {
                        // Default to result view
                        DrillResultView(drillSetup: drillSetup)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    }
                }
            } label: {
                EmptyView()
            }
        }
        .toolbar {
            // Leading: BLE Connection Status
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if bleManager.isConnected {
                        showConnectView = true
                    } else {
                        showQRScanner = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(bleManager.isConnected ? "BleConnect": "BleDisconnect")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                        
                        Text(bleManager.connectedPeripheral?.name ?? (bleManager.isConnected ? NSLocalizedString("target_connected", comment: "Status when target is connected") : NSLocalizedString("target_disconnected", comment: "Status when target is disconnected")))
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
            }
            
            // Trailing: Info Button - Hidden for now
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            // ToolbarItem(placement: .navigationBarTrailing) {
            //     Button(action: { showInfo = true }) {
            //         Image(systemName: "info.circle")
            //             .foregroundColor(.white)
            //             .font(.title2)
            //     }
            // }
        }
    }
    
    struct MainMenuButton: View {
        let icon: String
        let text: String
        let color: Color
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 28))
                Text(text)
                    .foregroundColor(.white)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(color)
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(24)
            .padding(.horizontal)
        }
    }
    
    struct ConnectSmartTargetWrapper: View {
        @EnvironmentObject var bleManager: BLEManager
        let onDismiss: () -> Void
        var targetName: String? = nil
        var isConnected: Bool = false
        var body: some View {
            ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), targetPeripheralName: targetName, isAlreadyConnected: isConnected, onConnected: onDismiss)
        }
    }
    
    // MARK: - Image Transfer Methods
    // Image transfer handled from ConnectSmartTargetView now.
}

#Preview {
    DrillMainPageView()
        .environmentObject(BLEManager.shared)
}
