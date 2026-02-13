import SwiftUI

struct ManualDeviceSelectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    @State private var hasStartedScan = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("device_select_title", comment: "Select Device"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(NSLocalizedString("device_select_description", comment: "Available devices with FlexTarget service"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Device List or Scanning State
                if bleManager.isScanning && bleManager.discoveredPeripherals.isEmpty {
                    // Scanning state
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        Text(NSLocalizedString("device_scanning", comment: "Scanning for devices..."))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else if bleManager.discoveredPeripherals.isEmpty {
                    // No devices found
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(NSLocalizedString("device_not_found", comment: "No Devices Found"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(NSLocalizedString("device_not_found_description", comment: "Make sure your device is powered on and nearby"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                } else {
                    // Device list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(bleManager.discoveredPeripherals) { peripheral in
                                deviceRow(peripheral)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // Scan/Rescan Button
                if !bleManager.isScanning {
                    Button(action: {
                        bleManager.discoveredPeripherals.removeAll()
                        bleManager.enableManualMode()
                        bleManager.startScan()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(bleManager.discoveredPeripherals.isEmpty ? NSLocalizedString("device_start_scan", comment: "Start Scan") : NSLocalizedString("device_scan_again", comment: "Scan Again"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            if !hasStartedScan {
                bleManager.enableManualMode()
                bleManager.startScan()
                hasStartedScan = true
            }
        }
        .onDisappear {
            bleManager.stopScan()
        }
        .navigationTitle(NSLocalizedString("device_select_title", comment: "Select Device"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 222/255, green: 56/255, blue: 35/255))
                }
            }
        }
    }
    
    private func deviceRow(_ peripheral: DiscoveredPeripheral) -> some View {
        Button(action: {
            bleManager.selectPeripheral(peripheral)
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(peripheral.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(peripheral.id.uuidString.prefix(12).uppercased())
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationView {
        ManualDeviceSelectionView(bleManager: BLEManager.shared)
    }
}
