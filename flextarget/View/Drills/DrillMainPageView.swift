import SwiftUI

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
    
    var body: some View {
        if showDrillList {
            DrillListView(bleManager: bleManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        } else {
            mainContent
                .sheet(isPresented: $showConnectView) {
                    ConnectSmartTargetWrapper(onDismiss: { showConnectView = false })
                }
                .sheet(isPresented: $showInfo) {
                    InformationPage()
                }
                .onAppear {
                    if !bleManager.isConnected {
                        showConnectView = true
                    }
                    errorObserver = NotificationCenter.default.addObserver(forName: .bleErrorOccurred, object: nil, queue: .main) { notification in
                        if let error = notification.userInfo?["error"] as? BLEError {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    }
                }
                .onChange(of: bleManager.isConnected) { newValue in
                    if !newValue {
                        showConnectView = true
                    }
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
                .navigationViewStyle(.stack)
        }
    }
    
    var mainContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Button(action: {
                                showConnectView = true
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
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                    }
                    Spacer()
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
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
                    // Disabled IPSC button (non-interactive, visually muted)
                    MainMenuButton(icon: "scope", text: NSLocalizedString("ipsc_questionaries", comment: "IPSC Questionaries menu button"), color: .gray)
                        .allowsHitTesting(false)
                        .opacity(0.6)
                    // Disabled IDPA button (non-interactive, visually muted)
                    MainMenuButton(icon: "shield", text: NSLocalizedString("idpa_questionaries", comment: "IDPA Questionaries menu button"), color: .gray)
                        .allowsHitTesting(false)
                        .opacity(0.6)
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
            
            NavigationLink(isActive: .constant(selectedDrillSetup != nil)) {
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
        var body: some View {
            ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), onConnected: onDismiss)
        }
    }
}

#Preview {
    DrillMainPageView()
        .environmentObject(BLEManager.shared)
}
