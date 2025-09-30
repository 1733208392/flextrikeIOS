import SwiftUI

struct ConnectSmartTargetView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var navigateToMain: Bool
    @Environment(\.dismiss) var dismiss
    @State private var statusText: String = "CONNECTING"
    @State private var showReconnect: Bool = false
    @State private var isShaking: Bool = true
    @State private var showProgress: Bool = false
    @State private var showInfo = false
    @State private var hasTriedReconnect: Bool = false
    @State private var showOkay: Bool = false
    @State private var showPeripheralPicker: Bool = false
    @State private var selectedPeripheral: DiscoveredPeripheral?
    var onConnected: (() -> Void)?

    private func goToMain() {
        if let onConnected = onConnected {
            onConnected()
        } else {
            dismiss()
        }
        navigateToMain = true
    }

    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width * 0.4
            let frameHeight = geometry.size.height * 0.35
            let dotPadding: CGFloat = 100
            let dotRadius: CGFloat = 6

            VStack(spacing: 0) {
                //Information Button
                HStack {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.white)
//                                .background(Circle().fill(Color.red))
                    }
                }
                .frame(width: geometry.size.width, alignment: .trailing)
                .padding(.top, 16)
                .padding(.trailing, 24)
                // Main Target Frame
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 10)
                        .frame(width: frameWidth, height: frameHeight)
                    Circle()
                        .fill(Color.red)
                        .frame(width: dotRadius * 2, height: dotRadius * 2)
                        .offset(x: dotPadding, y: dotPadding)
                }
                //.frame(width: .infinity, height: frameHeight, alignment: .top)
                .padding(.top, geometry.size.height * 0.15)
//                    .border(.red, width: 1)
                
                // Status and Reconnect Button
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.custom("SFPro-Medium", size: 16))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        if showProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                    if showReconnect {
                        Button(action: handleReconnect) {
                            Text("RECONNECT")
                                .font(.custom("SFPro-Medium", size: 20))
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width * 0.75, height: 44)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    if showOkay {
                        Button(action: { goToMain() }) {
                            Text("OKAY")
                                .font(.custom("SFPro-Medium", size: 20))
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width * 0.75, height: 44)
                                .background(Color(red: 223/255, green: 13/255, blue: 13/255))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }//Status and Reconnect Button
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
            }//Top Level VStack
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
//                .border(Color.white, width: 1)
        }//Top Level Geometry Reader
        .sheet(isPresented: $showPeripheralPicker) {
            // Peripheral Picker Sheet
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("SELECT TARGET")
                        .font(.custom("SFPro-Medium", size: 20))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        ForEach(bleManager.discoveredPeripherals) { peripheral in
                            Button(action: {
                                selectedPeripheral = peripheral
                                connectToSelectedPeripheral()
                            }) {
                                Text(peripheral.name)
                                    .font(.custom("SFPro-Medium", size: 18))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .padding(.horizontal, 40)
            }
        }
        .sheet(isPresented: $showInfo) { InformationPage() }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if bleManager.isConnected {
                statusText = "Target Connected"
                showOkay = true
            } else {
                startScanAndTimer()
            }
        }
        .onChange(of: bleManager.isConnected) { oldValue, newValue in
            if newValue {
                statusText = "CONNECTED"
                isShaking = false
                showReconnect = false
                showProgress = false
                showPeripheralPicker = false
                goToMain()
            }
        }
        .onChange(of: bleManager.discoveredPeripherals) { oldValue, newValue in
            if !newValue.isEmpty && bleManager.isScanning && !showPeripheralPicker {
                // Peripherals found during scan, show picker immediately
                bleManager.completeScan()
                // Pre-select the first peripheral
                selectedPeripheral = newValue.first
                showPeripheralPicker = true
                showProgress = false
            }
        }
    }

    private func startScanAndTimer() {
        statusText = "CONNECTING"
        isShaking = true
        showReconnect = false
        showPeripheralPicker = false
        selectedPeripheral = nil
        bleManager.startScan()
        showProgress = true
        
        // Start 20s scan timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            if self.bleManager.isScanning && self.bleManager.discoveredPeripherals.isEmpty {
                // Scan timeout with no peripherals found
                self.bleManager.completeScan()
                self.statusText = "TARGET NOT FOUND"
                self.isShaking = false
                self.showReconnect = true
                self.showProgress = false
            }
        }
    }

    private func handleReconnect() {
        hasTriedReconnect = true
        startScanAndTimer()
    }
    
    private func connectToSelectedPeripheral() {
        print("connectToSelectedPeripheral called")
        guard let peripheral = selectedPeripheral else {
            print("selectedPeripheral is nil")
            return
        }
        print("Selected peripheral: \(peripheral.name)")
        showPeripheralPicker = false
        statusText = "CONNECTING"
        showProgress = true
        bleManager.connectToSelectedPeripheral(peripheral)
        
        // Start 10s connection timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !self.bleManager.isConnected {
                // Connection timeout
                self.bleManager.disconnect()
                self.statusText = "BLUETOOTH SERVICE NOT FOUND"
                self.isShaking = false
                self.showReconnect = true
                self.showProgress = false
            }
        }
    }
}
