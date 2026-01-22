import SwiftUI

struct OTAUpdateView: View {
    @ObservedObject var otaManager = OTAManager.shared
    @ObservedObject var bleManager = BLEManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingConfirmation = false
    @State private var selectedVersion: OTAVersion?
    @State private var latestVersion: OTAVersion?
    @State private var isLoadingLatest = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if otaManager.currentState == .idle {
                    versionListView
                } else {
                    otaProgressView
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("ota_update_title", comment: "OTA Update"))
        .navigationBarTitleDisplayMode(.inline)
        
        .onAppear {
            otaManager.fetchHistory()
            fetchLatestVersion()
        }
        .alert(NSLocalizedString("ota_confirm_title", comment: "Start OTA?"), isPresented: $showingConfirmation, presenting: selectedVersion) { version in
            Button(NSLocalizedString("ota_cancel_button", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("ota_start_update_button", comment: "Start Update")) {
                otaManager.startOTA(version: version)
            }
        } message: { version in
            Text(String(format: NSLocalizedString("ota_confirm_message", comment: "Update target device message"), version.version))
        }
        .alert(NSLocalizedString("ota_failed_to_start_title", comment: "OTA Failed to Start"), isPresented: $otaManager.showOTAFailureAlert) {
            Button(NSLocalizedString("ota_cancel_button", comment: "Cancel"), role: .cancel) {
                otaManager.reset()
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("ota_game_disk_not_found", comment: "Game disk not found on device"))
        }
    }
    
    private func fetchLatestVersion() {
        bleManager.getAuthData { result in
            switch result {
            case .success(let authData):
                Task {
                    do {
                        let latest = try await OTAService.shared.getLatestOTAVersion(authData: authData)
                        DispatchQueue.main.async {
                            self.latestVersion = latest
                            self.isLoadingLatest = false
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isLoadingLatest = false
                        }
                        print("OTAUpdateView: Failed to fetch latest version: \(error)")
                    }
                }
            case .failure(let error):
                print("OTAUpdateView: Failed to get auth data: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingLatest = false
                }
            }
        }
    }
    
    private var versionListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("ota_version_history", comment: "Version History"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Show latest version first if available
                if let latest = latestVersion {
                    versionRow(latest, isLatest: true)
                }
                
                if otaManager.history.isEmpty {
                    if isLoadingLatest {
                        Text(NSLocalizedString("ota_fetching_history", comment: "Fetching history..."))
                            .foregroundColor(.gray)
                    } else if latestVersion == nil {
                        Text(NSLocalizedString("ota_fetching_history", comment: "Fetching history..."))
                            .foregroundColor(.gray)
                    }
                } else {
                    // Show history, excluding duplicate latest version
                    ForEach(otaManager.history) { version in
                        if latestVersion?.version != version.version {
                            versionRow(version, isLatest: false)
                        }
                    }
                }
            }
        }
    }
    
    private func versionRow(_ version: OTAVersion, isLatest: Bool) -> some View {
        Button(action: {
            selectedVersion = version
            showingConfirmation = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("v\(version.version)")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.white)
                        if isLatest {
                            Text(NSLocalizedString("ota_latest_version", comment: "Latest"))
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    Text("SHA1: \(version.checksum.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.red)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var otaProgressView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    .frame(width: 150, height: 150)
                
                if otaManager.currentState == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                } else if otaManager.currentState == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(2.0)
                }
            }
            
            VStack(spacing: 12) {
                Text(otaManager.currentState.rawValue.uppercased())
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(otaManager.progressMessage)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let target = otaManager.targetVersion {
                    Text(NSLocalizedString("ota_target_version", comment: "Target Version:") + " \(target)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if otaManager.currentState == .failed {
                VStack(spacing: 16) {
                    Button(action: {
                        otaManager.retryVerification()
                    }) {
                        Text(NSLocalizedString("ota_retry_verification", comment: "Retry Verification"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        otaManager.recovery()
                    }) {
                        Text(NSLocalizedString("ota_recovery_backup", comment: "Recovery (Restore Backup)"))
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1))
                    }
                }
                .padding(.top, 20)
            }
            
            if otaManager.currentState == .completed {
                Button(action: {
                    otaManager.reset()
                }) {
                    Text(NSLocalizedString("ota_done_button", comment: "Done"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            
            Spacer()
        }
    }
}
