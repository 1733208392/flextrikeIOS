import SwiftUI

struct DrillMainPageView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showDrillList = false
    @State private var showConnectView = false
    @State private var showInfo = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !bleManager.isConnected {
                                        showConnectView = true
                                    }
                                }) {
                                    Image(bleManager.isConnected ? "BleConnect": "BleDisconnect")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                }

                                Text(bleManager.connectedPeripheral?.name ?? (bleManager.isConnected ? "Target Connected" : "Target Disconnected"))
                                    .font(.footnote)
                                    .foregroundColor(.gray)
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
                    .padding(.top, 24)
                    // Recent Training (moved to subview)
                    RecentTrainingView()
                        .padding(.horizontal)
                        .padding(.top, 16)
                    // Menu Buttons
                    VStack(spacing: 20) {
                        MainMenuButton(icon: "target", text: "Drills", color: .red)
                            .onTapGesture {
                                showDrillList = true
                            }
                        MainMenuButton(icon: "scope", text: "IPSC Questionaries", color: .red)
                        MainMenuButton(icon: "shield", text: "IDPA Questionaries", color: .red)
                    }
                    .padding(.top, 24)
                    Spacer()
                    // Home Indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 120, height: 6)
                        .padding(.bottom, 12)
                }
            }
            .navigationDestination(isPresented: $showDrillList) {
                DrillListView(bleManager: bleManager)
                /*DrillSetupEntryView()*/
            }
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
            }
            .onChange(of: bleManager.isConnected) { oldValue, newValue in
                if !newValue {
                    showConnectView = true
                }
            }
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

#Preview {
    DrillMainPageView()
        .environmentObject(BLEManager.shared)
}
