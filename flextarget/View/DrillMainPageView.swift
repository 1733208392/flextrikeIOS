import SwiftUI

struct MainPageView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showDrillList = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                //system icon "bluetooth" (blue) when bleManager.isConnected == true
                                Image(systemName: bleManager.isConnected ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
                                    .foregroundColor(bleManager.isConnected ? .blue : .gray)
                                Text(bleManager.connectedPeripheral?.name ?? (bleManager.isConnected ? "CONNECTED" : "Device Disconnected"))
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(16)
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 28))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    // Recent Training
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest Drills")
                            .font(.headline)
                            .foregroundColor(.white)
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.3))
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 8) {
                                    Image(systemName: "scope")
                                        .foregroundColor(.orange)
                                    Text("#3 Bill Drill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.top, 12)
                                .padding(.horizontal, 16)
                                // Demo Image
                                Image("test")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 160)
                                    .clipped()
                                    .cornerRadius(12)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)
                                // Info Row
                                HStack {
                                    VStack {
                                        Text("2")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                        Text("Set")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    VStack {
                                        Text("10.000s")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                        Text("Duration")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    VStack {
                                        Text("5")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                        Text("Shots")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                // Page Indicator
                                HStack(spacing: 8) {
                                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                                    Circle().fill(Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                                    Circle().fill(Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                                }
                                .padding(.bottom, 12)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 260)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    // Menu Buttons
                    VStack(spacing: 20) {
                        MainMenuButton(icon: "target", text: "Drills", color: .orange)
                            .onTapGesture {
                                showDrillList = true
                            }
                        MainMenuButton(icon: "scope", text: "IPSC Questionaries", color: .orange)
                        MainMenuButton(icon: "shield", text: "IDPA Questionaries", color: .orange)
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
//                DrillListView()
                DrillSetupEntryView()
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

#Preview {
    MainPageView()
        .environmentObject(BLEManager.shared)
}
