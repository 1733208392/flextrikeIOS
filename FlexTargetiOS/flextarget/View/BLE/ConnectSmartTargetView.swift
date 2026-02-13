import SwiftUI

struct ConnectSmartTargetView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var navigateToMain: Bool
    // Optional peripheral name passed in (from QR scan or navigation)
    var targetPeripheralName: String? = nil
    // Flag indicating if BLE is already connected
    var isAlreadyConnected: Bool = false
    var hideCloseButton: Bool = false
    @Environment(\.dismiss) var dismiss
    @State private var statusText: String = "CONNECTING"
    @State private var showReconnect: Bool = false
    @State private var isShaking: Bool = true
    @State private var showProgress: Bool = false
    @State private var hasTriedReconnect: Bool = false
    @State private var selectedPeripheral: DiscoveredPeripheral?
    @State private var showImageCrop: Bool = false
    @State private var connectionStartTime: Date?
    @State private var timeoutTimer: Timer?
    @State private var remainingSeconds: Int = 15
    @State private var scanStartTime: Date?
    @State private var minScanDurationTimer: Timer?
    private let minScanDuration: TimeInterval = 5.0  // Minimum 3 seconds before showing picker
    var onConnected: (() -> Void)?
    @State private var activeTargetName: String? = nil
    
    func goToMain() {
        if let onConnected = onConnected {
            onConnected()
        } else {
            dismiss()
        }
        navigateToMain = true
    }
    
    private struct TargetFrameView: View {
        let geometry: GeometryProxy
        let bleManager: BLEManager
        
        var body: some View {
            let frameWidth = geometry.size.width * 0.4
            let frameHeight = geometry.size.height * 0.35
            let dotPadding: CGFloat = 100
            let dotRadius: CGFloat = 6
            // Corner sensor icon configuration
            let sensorIconSize: CGFloat = 24
            let sensorOffsetAdjustment: CGFloat = -4 // how far outside the rectangle the icons sit
            let baseAnimation = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
            let animation0 = baseAnimation
            let animation15 = baseAnimation.delay(0.15)
            let animation30 = baseAnimation.delay(0.30)
            let animation45 = baseAnimation.delay(0.45)
            
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Color.white, lineWidth: 10)
                    .frame(width: frameWidth, height: frameHeight)
                Circle()
                    .fill(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .frame(width: dotRadius * 2, height: dotRadius * 2)
                    .offset(x: dotPadding, y: dotPadding)
                
                // Bottom-left sensor icon (45° clockwise)
                Image(systemName: "dot.radiowaves.forward")
                    .font(.system(size: sensorIconSize))
                    .foregroundColor(.white)
                    .scaleEffect(!bleManager.isConnected ? 1.1 : 0.9)
                    .opacity(!bleManager.isConnected ? 1.0 : 0.6)
                    .animation(animation0, value: bleManager.isConnected)
                    .rotationEffect(.degrees(-45)) // clockwise
                    .offset(x: -sensorOffsetAdjustment, y: frameHeight - sensorIconSize + sensorOffsetAdjustment)
                
                // Bottom-right sensor icon (135° clockwise)
                Image(systemName: "dot.radiowaves.forward")
                    .font(.system(size: sensorIconSize))
                    .foregroundColor(.white)
                    .scaleEffect(!bleManager.isConnected ? 1.1 : 0.9)
                    .opacity(!bleManager.isConnected ? 1.0 : 0.6)
                    .animation(animation15, value: bleManager.isConnected)
                    .rotationEffect(.degrees(-135)) // clockwise
                    .offset(x: frameWidth - sensorIconSize + sensorOffsetAdjustment, y: frameHeight - sensorIconSize + sensorOffsetAdjustment)
                
                // Top-right sensor icon (135° counter-clockwise)
                Image(systemName: "dot.radiowaves.forward")
                    .font(.system(size: sensorIconSize))
                    .foregroundColor(.white)
                    .scaleEffect(!bleManager.isConnected ? 1.1 : 0.9)
                    .opacity(!bleManager.isConnected ? 1.0 : 0.6)
                    .animation(animation30, value: bleManager.isConnected)
                    .rotationEffect(.degrees(135)) // counter-clockwise
                    .offset(x: frameWidth - sensorIconSize + sensorOffsetAdjustment, y: -sensorOffsetAdjustment)
                
                // Top-left sensor icon (45° counter-clockwise)
                Image(systemName: "dot.radiowaves.forward")
                    .font(.system(size: sensorIconSize))
                    .foregroundColor(.white)
                    .scaleEffect(!bleManager.isConnected ? 1.1 : 0.9)
                    .opacity(!bleManager.isConnected ? 1.0 : 0.6)
                    .animation(animation45, value: bleManager.isConnected)
                    .rotationEffect(.degrees(45)) // counter-clockwise
                    .offset(x: -sensorOffsetAdjustment, y: -sensorOffsetAdjustment)
            }
            .padding(.top, geometry.size.height * 0.15)
        }
    }
    
    private struct StatusAndButtonsView: View {
        let geometry: GeometryProxy
        let statusText: String
        let showProgress: Bool
        let showReconnect: Bool
        let isAlreadyConnected: Bool
        let bleManager: BLEManager
        let handleReconnect: () -> Void
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
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
                        Text(NSLocalizedString("reconnect", comment: "Reconnect button"))
                            .font(.custom("SFPro-Medium", size: 20))
                            .foregroundColor(.white)
                            .frame(width: geometry.size.width * 0.75, height: 44)
                            .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                if isAlreadyConnected {
                    VStack(spacing: 12) {
                        Button(action: {
                            bleManager.disconnect()
                            dismiss()
                        }) {
                            Text(NSLocalizedString("disconnect", comment: "Disconnect button"))
                                .font(.custom("SFPro-Medium", size: 20))
                                .foregroundColor(.white)
                                .frame(height: 44)
                                .frame(maxWidth: .infinity)
                                .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TargetFrameView(geometry: geometry, bleManager: bleManager)
                
                StatusAndButtonsView(
                    geometry: geometry,
                    statusText: statusText,
                    showProgress: showProgress,
                    showReconnect: showReconnect,
                    isAlreadyConnected: isAlreadyConnected,
                    bleManager: bleManager,
                    handleReconnect: handleReconnect
                )
                .padding(.top, 120)
            }//Top Level VStack
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            //                .border(Color.white, width: 1)
        }//Top Level Geometry Reader
        .overlay(alignment: .topTrailing) {
            if !hideCloseButton {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                        .padding(12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
                .accessibilityLabel(Text("Close"))
            }
        }
        .sheet(isPresented: $showImageCrop) {
            ImageCropView()
        }
        .sheet(isPresented: $bleManager.showMultiDevicePicker) {
            MultiDevicePickerSheetView(bleManager: bleManager)
        }
        .background(Color.black.ignoresSafeArea())
        .alert(isPresented: $bleManager.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(bleManager.errorMessage ?? "Unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: bleManager.error) { error in
            if case .bluetoothOff = error {
                statusText = "Bluetooth has been turned off"
                isShaking = false
                showProgress = false
                showReconnect = true
                timeoutTimer?.invalidate()
                
                // Dismiss after 2 seconds if already connected
                if isAlreadyConnected {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: bleManager.isConnected) { isConnected in
            if !isConnected && hasTriedReconnect && activeTargetName == nil {
                // Unexpected disconnection during auto-detect
                statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
                showReconnect = true
                showProgress = false
                isShaking = false
                timeoutTimer?.invalidate()
            }
        }
        .onAppear {
            if isAlreadyConnected {
                let deviceName = bleManager.connectedPeripheral?.name ?? "Device"
                let connectedText = NSLocalizedString("target_connected", comment: "Status when target is connected")
                statusText = deviceName + " " + connectedText
            } else {
                connectionStartTime = Date()
                startConnectionTimeout()
                // If a target peripheral name was passed in (from QR scan), begin scanning
                if let target = targetPeripheralName {
                    activeTargetName = target
                    bleManager.setAutoConnectTarget(target)
                    startScanAndTimer()
                    statusText = String(format: NSLocalizedString("scanning_for_target", comment: "Scanning for specific target"), target)
                } else if bleManager.autoDetectMode {
                    // Auto-detect mode: check if peripherals are already discovered
                    if bleManager.discoveredPeripherals.count == 1 {
                        // Single device found - auto-connect
                        let peripheral = bleManager.discoveredPeripherals.first!
                        bleManager.completeScan()
                        selectedPeripheral = peripheral
                        showProgress = true
                        statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
                        connectToSelectedPeripheral()
                    } else if bleManager.discoveredPeripherals.count > 1 {
                        // Multiple devices found - show selection
                        bleManager.stopScan()
                        bleManager.showMultiDevicePicker = true
                        statusText = "Multiple devices found, select one"
                        showProgress = false
                    } else if bleManager.isScanning {
                        // Scanning in progress, wait for results
                        statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
                        showProgress = true
                        isShaking = true
                    } else {
                        // No devices found yet, start scanning if not already scanning
                        if !bleManager.isScanning {
                            bleManager.startScan()
                        }
                        statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
                        showProgress = true
                        isShaking = true
                    }
                } else {
                    // No target provided and not in auto-detect mode
                    statusText = NSLocalizedString("ready_to_scan", comment: "Ready to scan prompt")
                    showProgress = false
                    isShaking = false
                }
            }
        }
        .onDisappear {
            timeoutTimer?.invalidate()
            minScanDurationTimer?.invalidate()
            // Clear any auto-connect target on exit
            bleManager.setAutoConnectTarget(nil as String?)
        }
        .onChange(of: bleManager.isConnected) { newValue in
            if newValue {
                timeoutTimer?.invalidate()
                let deviceName = bleManager.connectedPeripheral?.name ?? "Device"
                let connectedText = NSLocalizedString("connected", comment: "Status when connection successful")
                statusText = deviceName + " " + connectedText
                isShaking = false
                showReconnect = false
                showProgress = false
                goToMain()
            }
        }
        .onChange(of: bleManager.discoveredPeripherals) { newValue in
            // If we are looking for a specific target name, try to match and auto-connect
            if let target = activeTargetName, bleManager.isScanning {
                if let match = bleManager.findPeripheral(named: target) {
                    // Found the target peripheral - connect to it
                    bleManager.completeScan()
                    selectedPeripheral = match
                    showProgress = true
                    connectToSelectedPeripheral()
                    return
                }
                // Otherwise wait for timers (min duration / overall timeout) to decide
                return
            }
            // Auto-detect mode
            if bleManager.autoDetectMode && activeTargetName == nil {
                if bleManager.discoveredPeripherals.count == 1 {
                    let peripheral = bleManager.discoveredPeripherals.first!
                    bleManager.completeScan()
                    selectedPeripheral = peripheral
                    showProgress = true
                    connectToSelectedPeripheral()
                } else if bleManager.discoveredPeripherals.count > 1 {
                    bleManager.stopScan()
                    bleManager.showMultiDevicePicker = true
                    statusText = "Multiple devices found, select one"
                    showProgress = false
                }
            }
        }
    }
    
    func startScanAndTimer() {
        statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
        isShaking = true
        showReconnect = false
        selectedPeripheral = nil
        scanStartTime = Date()  // Record scan start time
        bleManager.startScan()
        showProgress = true
        minScanDurationTimer?.invalidate()
        
        // Delay the scan timer start to allow BLE to power on
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.bleManager.isScanning {
                // If a target name was requested, check for it and auto-connect or dismiss
                if let target = self.activeTargetName {
                    if let match = self.bleManager.findPeripheral(named: target) {
                        self.bleManager.completeScan()
                        self.selectedPeripheral = match
                        self.connectToSelectedPeripheral()
                    } else {
                        // Target not found in scan results -> dismiss
                        self.bleManager.completeScan()
                        // Clear manager auto-connect target before dismissing
                        self.bleManager.setAutoConnectTarget(nil as String?)
                        self.dismiss()
                    }
                } else {
                    if self.bleManager.discoveredPeripherals.isEmpty {
                        // Scan timeout with no peripherals found
                        self.bleManager.completeScan()
                        self.statusText = NSLocalizedString("target_not_found", comment: "Status when no targets found after scan")
                        self.isShaking = false
                        self.showReconnect = true
                        self.showProgress = false
                    }
                }
            }
        }
    }
        
        func handleReconnect() {
            hasTriedReconnect = true
            startScanAndTimer()
        }
        
        func connectToSelectedPeripheral() {
            guard let peripheral = selectedPeripheral else {
                return
            }
            statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device")
            showProgress = true
            
            bleManager.connectToSelectedPeripheral(peripheral)
            // Clear manager auto-connect target since we are actively connecting
            bleManager.setAutoConnectTarget(nil as String?)
            
            // Start 30s connection timer (increased from 10s to match BLEManager timeout)
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if !self.bleManager.isConnected {
                    // Connection timeout
                    self.bleManager.disconnect()
                    self.statusText = NSLocalizedString("bluetooth_service_not_found", comment: "Status when bluetooth service not found during connection")
                    self.isShaking = false
                    self.showReconnect = true
                    self.showProgress = false
                }
            }
        }
        
        func startConnectionTimeout() {
            timeoutTimer?.invalidate()
            remainingSeconds = 45  // Increased from 15 to 45 seconds
            
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                guard let startTime = connectionStartTime else { return }
                let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
                remainingSeconds = max(0, 45 - elapsedSeconds)  // Updated to match new timeout
                
                // Update status text with countdown
                statusText = NSLocalizedString("trying_to_connect", comment: "Status when trying to connect to FlexTarget device") + " (\(remainingSeconds))"
                
                // If 45 seconds have passed and not connected, dismiss
                if elapsedSeconds >= 45 && !bleManager.isConnected {
                    timeoutTimer?.invalidate()
                    bleManager.disconnect()
                    bleManager.completeScan()
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Preview
#if DEBUG
    struct ConnectSmartTargetView_Previews: PreviewProvider {
        static var previews: some View {
            // Provide a constant binding for navigateToMain. Use shared BLEManager for preview.
            ConnectSmartTargetView(bleManager: BLEManager.shared, navigateToMain: .constant(false), isAlreadyConnected: false)
                .previewLayout(.fixed(width: 375, height: 700))
                .background(Color.black)
        }
    }
#endif

// MARK: - Multi-Device Picker Sheet
struct MultiDevicePickerSheetView: View {
    var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Select a Device")
                        .font(.custom("SFPro-Bold", size: 24))
                        .foregroundColor(.white)
                    
                    Text("Multiple targets found. Please select one to connect:")
                        .font(.custom("SFPro-Regular", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                
                // Device List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(bleManager.discoveredPeripherals) { peripheral in
                            DeviceSelectionButtonView(
                                peripheral: peripheral,
                                action: {
                                    bleManager.selectDeviceFromPicker(peripheral)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                // Cancel Button
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    Button(action: {
                        bleManager.dismissDevicePicker()
                    }) {
                        Text("Cancel")
                            .font(.custom("SFPro-Medium", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

struct DeviceSelectionButtonView: View {
    let peripheral: DiscoveredPeripheral
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Device Icon
                Image(systemName: "smartphone.badge.checkmark")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                
                // Device Information
                VStack(alignment: .leading, spacing: 4) {
                    Text(peripheral.name)
                        .font(.custom("SFPro-Medium", size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(peripheral.peripheral.identifier.uuidString.prefix(12).uppercased())
                        .font(.custom("SFPro-Regular", size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Arrow Icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    action()
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            }
        }
    }
}