import SwiftUI

struct OTAUpdateView: View {
    @ObservedObject var otaManager = OTAManager.shared
    @ObservedObject var bleManager = BLEManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingConfirmation = false
    @State private var selectedVersion: OTAVersion?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Device not connected card
                        if !bleManager.isConnected {
                            deviceNotConnectedCard
                        } else {
                            // Current version card
                            currentVersionCard
                            
                            // State-based content
                            stateBasedContent
                            
                            // Unified button
                            unifiedButton
                            
                            // Info card
                            infoCard
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(NSLocalizedString("ota_update_title", comment: "OTA Update"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            otaManager.fetchHistory()
            otaManager.queryCurrentDeviceVersion()
            if otaManager.currentState == .idle {
                checkForUpdates()
            }
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
            Text(otaManager.otaFailureReason.isEmpty ? NSLocalizedString("ota_game_disk_not_found", comment: "Game disk not found on device") : otaManager.otaFailureReason)
        }
    }
    
    // MARK: - UI Components
    
    private var deviceNotConnectedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
            
            Text(NSLocalizedString("connection_required", comment: "CONNECTION REQUIRED"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Text(NSLocalizedString("connect_device_prompt", comment: "Connect device"))
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var currentVersionCard: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("ota_current_version", comment: "Current Version"))
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Text(otaManager.currentDeviceVersion ?? "---")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var stateBasedContent: some View {
        Group {
            switch otaManager.currentState {
            case .idle:
                idleStateView
            case .preparing, .waitingForReadyToDownload:
                preparingStateView
            case .downloading:
                downloadingStateView
            case .reloading:
                reloadingStateView
            case .verifying:
                verifyingStateView
            case .completed:
                completedStateView
            case .failed:
                failedStateView
            }
        }
    }
    
    private var idleStateView: some View {
        Group {
            if otaManager.availableVersion == nil {
                loadingCard(message: NSLocalizedString("ota_checking", comment: "Checking for updates..."))
            } else if let available = otaManager.availableVersion, let current = otaManager.currentDeviceVersion, available != current {
                updateAvailableCard
            } else {
                upToDateCard
            }
        }
    }
    
    private var updateAvailableCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("ota_available", comment: "UPDATE AVAILABLE"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Version \(otaManager.availableVersion ?? "---")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Text(NSLocalizedString("ota_available_description", comment: "New version available"))
                .font(.system(size: 12))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var upToDateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("ota_up_to_date", comment: "UP TO DATE"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                if let lastCheck = otaManager.lastCheckTime {
                    Text("Last checked: \(lastCheck.prefix(10))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var preparingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.87, green: 0.22, blue: 0.14)))
            
            Text(otaManager.progressMessage.isEmpty ? NSLocalizedString("ota_msg_preparing", comment: "Preparing...") : otaManager.progressMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var downloadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.87, green: 0.22, blue: 0.14)))
            
            Text(NSLocalizedString("ota_msg_downloading", comment: "Downloading..."))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var reloadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.87, green: 0.22, blue: 0.14)))
            
            Text(NSLocalizedString("ota_msg_reloading", comment: "Reloading..."))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var verifyingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.87, green: 0.22, blue: 0.14)))
            
            Text(NSLocalizedString("ota_msg_verifying", comment: "Verifying..."))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var completedStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text(NSLocalizedString("ota_msg_success", comment: "Update Successful"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.green.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var failedStateView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("ota_failed", comment: "FAILED"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let error = otaManager.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { otaManager.retryVerification() }) {
                    Text(NSLocalizedString("ota_retry_verification", comment: "Retry"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                
                Button(action: { otaManager.recovery() }) {
                    Text(NSLocalizedString("ota_recovery_backup", comment: "Recovery"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var unifiedButton: some View {
        Button(action: buttonAction) {
            Text(buttonTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(buttonForeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(buttonBgColor)
                .cornerRadius(8)
        }
        .disabled(!buttonEnabled)
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(NSLocalizedString("ota_about_title", comment: "About OTA Updates"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(NSLocalizedString("ota_about_description", comment: "Make sure device remains connected during update"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func loadingCard(message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.87, green: 0.22, blue: 0.14)))
            
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    
    private var buttonTitle: String {
        switch otaManager.currentState {
        case .idle:
            if otaManager.availableVersion == nil {
                return NSLocalizedString("ota_checking", comment: "Checking...")
            } else if otaManager.availableVersion != nil && otaManager.availableVersion != otaManager.currentDeviceVersion {
                return NSLocalizedString("ota_update_now", comment: "Update Now")
            } else {
                return NSLocalizedString("check_now", comment: "Check Now")
            }
        case .preparing, .waitingForReadyToDownload, .downloading, .reloading, .verifying:
            return NSLocalizedString("ota_updating", comment: "Updating...")
        case .completed:
            return NSLocalizedString("ota_done_button", comment: "Done")
        case .failed:
            return NSLocalizedString("ota_retry_verification", comment: "Retry")
        }
    }
    
    private var buttonEnabled: Bool {
        switch otaManager.currentState {
        case .idle:
            return otaManager.availableVersion != nil && bleManager.isConnected
        case .completed:
            return true
        case .failed:
            return true
        default:
            return false
        }
    }
    
    private var buttonForeColor: Color {
        .white
    }
    
    private var buttonBgColor: Color {
        switch otaManager.currentState {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return Color(red: 0.87, green: 0.22, blue: 0.14)
        }
    }
    
    private func buttonAction() {
        switch otaManager.currentState {
        case .idle:
            if otaManager.availableVersion != nil && otaManager.availableVersion != otaManager.currentDeviceVersion {
                // Try from already loaded history
                if let version = otaManager.history.first(where: { $0.version == otaManager.availableVersion }) {
                    selectedVersion = version
                    showingConfirmation = true
                } else {
                    // If not found in history, try to fetch it again or start with latest known info
                    bleManager.getAuthData { result in
                        switch result {
                        case .success(let authData):
                            Task {
                                do {
                                    let latest = try await OTAService.shared.getLatestOTAVersion(authData: authData)
                                    if latest.version == otaManager.availableVersion {
                                        DispatchQueue.main.async {
                                            selectedVersion = latest
                                            showingConfirmation = true
                                        }
                                    }
                                } catch {
                                    print("OTAUpdateView: Failed to refetch version for buttonAction: \(error)")
                                }
                            }
                        case .failure(let error):
                            print("OTAUpdateView: Auth failed for buttonAction: \(error)")
                        }
                    }
                }
            } else {
                checkForUpdates()
            }
        case .completed:
            otaManager.reset()
            dismiss()
        case .failed:
            otaManager.retryVerification()
        default:
            break
        }
    }
    
    private func checkForUpdates() {
        otaManager.checkForUpdates()
    }
}

#Preview {
    OTAUpdateView()
}

