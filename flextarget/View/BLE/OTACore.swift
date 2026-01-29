import Foundation
import Combine
import SwiftUI
import CryptoKit

// MARK: - Localization Helper

private func localizedMessage(_ key: String, _ arguments: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    if arguments.isEmpty {
        return format
    }
    return String(format: format, arguments: arguments)
}

struct OTAVersion: Codable, Identifiable, Hashable {
    var id: String { version }
    let version: String
    let address: String
    let checksum: String
    
    enum CodingKeys: String, CodingKey {
        case version
        case address
        case checksum
    }
}

struct OTALatestResponse: Codable {
    let code: Int
    let msg: String
    let data: OTAVersion?
}

struct OTAHistoryData: Codable {
    let total_count: Int
    let limit: Int
    let page: Int
    let rows: [OTAVersion]
}

struct OTAHistoryResponse: Codable {
    let code: Int
    let msg: String
    let data: OTAHistoryData?
}

// MARK: - Service

class OTAService {
    static let shared = OTAService()
    
    private let baseURL = "https://etarget.topoint-archery.cn"
    private let session = URLSession.shared
    
    /// Fetches the latest OTA version metadata
    func getLatestOTAVersion(authData: String) async throws -> OTAVersion {
        let url = URL(string: "\(baseURL)/ota/game")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["auth_data": authData]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OTALatestResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "OTAService", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let otaVersion = response.data else {
            throw NSError(domain: "OTAService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No OTA version data received"])
        }
        
        return otaVersion
    }
    
    /// Fetches OTA history, limited to top 10 as per requirements
    func getOTAHistory(authData: String, page: Int = 1, limit: Int = 10) async throws -> [OTAVersion] {
        let url = URL(string: "\(baseURL)/ota/game/history")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "auth_data": authData,
            "page": page,
            "limit": limit
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OTAHistoryResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "OTAService", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        return response.data?.rows ?? []
    }
}

// MARK: - Manager

enum OTAState: String, Codable {
    case idle
    case preparing
    case waitingForReadyToDownload
    case downloading
    case reloading
    case verifying
    case completed
    case failed
}

class OTAManager: ObservableObject {
    static let shared = OTAManager()
    
    @Published var currentState: OTAState = .idle
    @Published var targetVersion: String?
    @Published var progressMessage: String = ""
    @Published var errorMessage: String?
    @Published var showOTAFailureAlert: Bool = false
    @Published var otaFailureReason: String = ""
    @Published var history: [OTAVersion] = []
    
    private var currentOTAVersion: OTAVersion?
    private var preparationStartTime: Date?
    
    private let userDefaults = UserDefaults.standard
    private let stateKey = "ota_current_state"
    private let targetVersionKey = "ota_target_version"
    
    private var verificationTimer: Timer?
    private var verificationStartTime: Date?
    private let verificationTimeout: TimeInterval = 60.0
    
    private var readyToDownloadTimer: Timer?
    private var readyToDownloadStartTime: Date?
    private let readyToDownloadTimeout: TimeInterval = 30.0
    
    private var prepareGameDiskOTACompleted: Bool = false
    private var prepareGameDiskOTATimer: Timer?
    private var prepareGameDiskOTAStartTime: Date?
    private let prepareGameDiskOTATimeout: TimeInterval = 600.0  // 10 minutes
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadState()
        setupNotificationObservers()
    }
    
    // MARK: - State Management
    
    private func saveState() {
        userDefaults.set(currentState.rawValue, forKey: stateKey)
        userDefaults.set(targetVersion, forKey: targetVersionKey)
    }
    
    private func loadState() {
        if let rawState = userDefaults.string(forKey: stateKey),
           let state = OTAState(rawValue: rawState) {
            self.currentState = state
        }
        self.targetVersion = userDefaults.string(forKey: targetVersionKey)
        
        // If app crashed/restarted during a critical phase, we might need to resume
        if currentState == .verifying {
            startVerificationLoop()
        }
    }
    
    private func transition(to state: OTAState, message: String = "") {
        let block = {
            self.currentState = state
            self.progressMessage = message
            self.saveState()
            
            if state == .preparing {
                // Already managed in startOTA
            } else {
                self.stopPrepareGameDiskOTATimeout()
            }
            
            if state == .waitingForReadyToDownload {
                self.startReadyToDownloadTimeout()
            } else {
                self.stopReadyToDownloadTimeout()
            }
            
            if state == .verifying {
                self.startVerificationLoop()
            } else {
                self.stopVerificationLoop()
            }
        }
        
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    // MARK: - Workflow Actions
    
    func startOTA(version: OTAVersion) {
        guard BLEManager.shared.isConnected else {
            self.errorMessage = "Device not connected"
            return
        }
        
        self.currentOTAVersion = version
        self.targetVersion = version.version
        self.errorMessage = nil
        self.prepareGameDiskOTACompleted = false
        transition(to: .preparing, message: localizedMessage("ota_msg_preparing"))
        
        // Step 1: Prepare OTA - wait for explicit success response
        self.preparationStartTime = Date()
        self.prepareGameDiskOTAStartTime = Date()
        BLEManager.shared.prepareGameDiskOTA()
        startPrepareGameDiskOTATimeout()
    }
    
    func proceedWithUpgrade() {
        guard let version = currentOTAVersion else {
            transition(to: .failed, message: localizedMessage("ota_msg_no_upgrade_info"))
            return
        }
        BLEManager.shared.startGameUpgrade(address: version.address, checksum: version.checksum, otaVersion: version.version)
    }
    
    func retryVerification() {
        transition(to: .verifying, message: localizedMessage("ota_msg_retrying_verification"))
    }
    
    func recovery() {
        transition(to: .idle, message: localizedMessage("ota_msg_restoring_backup"))
        BLEManager.shared.recoveryGameDiskOTA()
    }
    
    // MARK: - Prepare Game Disk OTA Timeout
    
    private func startPrepareGameDiskOTATimeout() {
        prepareGameDiskOTAStartTime = Date()
        prepareGameDiskOTATimer?.invalidate()
        prepareGameDiskOTATimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPrepareGameDiskOTATimeout()
        }
    }
    
    private func stopPrepareGameDiskOTATimeout() {
        prepareGameDiskOTATimer?.invalidate()
        prepareGameDiskOTATimer = nil
        prepareGameDiskOTAStartTime = nil
    }
    
    private func checkPrepareGameDiskOTATimeout() {
        guard let startTime = prepareGameDiskOTAStartTime else { return }
        
        if Date().timeIntervalSince(startTime) > prepareGameDiskOTATimeout {
            stopPrepareGameDiskOTATimeout()
            let errorMsg = localizedMessage("ota_msg_prep_timeout")
            self.errorMessage = errorMsg
            transition(to: .failed, message: errorMsg)
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .bleOTAPreparationFailed)
            .sink { [weak self] notification in
                guard let self = self, self.currentState == .preparing else { return }
                
                if let errorReason = notification.userInfo?["errorReason"] as? String {
                    print("OTAManager: Received OTA preparation failure - \(errorReason)")
                    self.otaFailureReason = errorReason
                    self.stopPrepareGameDiskOTATimeout()
                    
                    // Transition to failed state
                    self.transition(to: .failed, message: "")
                    
                    // Show alert to user
                    DispatchQueue.main.async {
                        self.showOTAFailureAlert = true
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .bleGameDiskOTAReady)
            .sink { [weak self] _ in
                guard let self = self, self.currentState == .preparing else { return }
                
                print("OTAManager: Received prepare_game_disk_ota success confirmation")
                self.prepareGameDiskOTACompleted = true
                self.stopPrepareGameDiskOTATimeout()
                
                // Transition to waiting for ready_to_download
                self.transition(to: .waitingForReadyToDownload, message: localizedMessage("ota_msg_ready_to_download"))
                self.startReadyToDownloadTimeout()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .bleReadyToDownload)
            .sink { [weak self] _ in
                guard let self = self, (self.currentState == .waitingForReadyToDownload || self.currentState == .preparing) else { return }
                
                // Only proceed if prepare_game_disk_ota has completed successfully
                guard self.prepareGameDiskOTACompleted else {
                    print("OTAManager: Received bleReadyToDownload but prepare_game_disk_ota not yet confirmed. Waiting...")
                    return
                }

                let elapsed = Date().timeIntervalSince(self.preparationStartTime ?? Date())
                let remainingDelay = max(0, 1.0 - (elapsed - 5.0))  // Adjusted for prepare confirmation time
                
                print("OTAManager: Received bleReadyToDownload notification. Device ready. Starting upgrade...")

                DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) { [weak self] in
                    guard let self = self, self.currentState == .waitingForReadyToDownload else { return }
                    
                    // Transition to downloading immediately to reflect device state and prevent multiple triggers
                    self.transition(to: .downloading, message: localizedMessage("ota_msg_downloading"))
                    self.stopReadyToDownloadTimeout()

                    // Prefer the detailed OTAVersion already stored on the manager
                    if let ota = self.currentOTAVersion {
                        BLEManager.shared.startGameUpgrade(address: ota.address, checksum: ota.checksum, otaVersion: ota.version)
                        return
                    }

                    // If we don't have the full metadata, try to find it in fetched history
                    if let target = self.targetVersion, let found = self.history.first(where: { $0.version == target }) {
                        self.currentOTAVersion = found
                        BLEManager.shared.startGameUpgrade(address: found.address, checksum: found.checksum, otaVersion: found.version)
                        return
                    }

                    // Otherwise, attempt to fetch metadata from OTAService using auth data from BLEManager
                    if let target = self.targetVersion {
                        BLEManager.shared.getAuthData { result in
                            switch result {
                            case .success(let authData):
                                Task {
                                    do {
                                        // Try latest first
                                        let latest = try await OTAService.shared.getLatestOTAVersion(authData: authData)
                                        if latest.version == target {
                                            DispatchQueue.main.async {
                                                self.currentOTAVersion = latest
                                                BLEManager.shared.startGameUpgrade(address: latest.address, checksum: latest.checksum, otaVersion: latest.version)
                                            }
                                            return
                                        }

                                        // If latest didn't match, try history list
                                        let rows = try await OTAService.shared.getOTAHistory(authData: authData)
                                        if let matched = rows.first(where: { $0.version == target }) {
                                            DispatchQueue.main.async {
                                                self.currentOTAVersion = matched
                                                BLEManager.shared.startGameUpgrade(address: matched.address, checksum: matched.checksum, otaVersion: matched.version)
                                            }
                                            return
                                        }

                                        DispatchQueue.main.async {
                                            let errorMsg = localizedMessage("ota_msg_no_metadata", self.targetVersion ?? "unknown")
                                            self.errorMessage = errorMsg
                                            self.transition(to: .failed, message: errorMsg)
                                        }
                                    } catch {
                                        DispatchQueue.main.async {
                                            let errorMsg = localizedMessage("ota_msg_fetch_metadata_failed")
                                            self.errorMessage = errorMsg
                                            self.transition(to: .failed, message: errorMsg)
                                        }
                                    }
                                }
                            case .failure:
                                DispatchQueue.main.async {
                                    let errorMsg = localizedMessage("ota_msg_auth_failed")
                                    self.errorMessage = errorMsg
                                    self.transition(to: .failed, message: errorMsg)
                                }
                            }
                        }
                        return
                    }

                    // No version information available
                    let errorMsg = localizedMessage("ota_msg_no_version_selected")
                    self.errorMessage = errorMsg
                    self.transition(to: .failed, message: errorMsg)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .bleDownloadComplete)
            .sink { [weak self] notification in
                guard let self = self, self.currentState == .downloading else { return }
                
                if let version = notification.userInfo?["version"] as? String, version == self.targetVersion {
                    self.transition(to: .reloading, message: localizedMessage("ota_msg_reloading"))
                    BLEManager.shared.reloadUI()
                    
                    // After reloading, we start verifying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.transition(to: .verifying, message: localizedMessage("ota_msg_verifying"))
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .bleVersionInfoReceived)
            .sink { [weak self] notification in
                guard let self = self, self.currentState == .verifying else { return }
                
                if let version = notification.userInfo?["version"] as? String {
                    print("OTAManager: Received version info: \(version), target: \(self.targetVersion ?? "nil")")
                    if version == self.targetVersion {
                        self.transition(to: .completed, message: localizedMessage("ota_msg_success"))
                        // Finalize
                        BLEManager.shared.finishGameDiskOTA()
                        
                        // Clear state after success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.reset()
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .bleErrorOccurred)
            .sink { [weak self] _ in
                // Handle potential BLE errors during OTA
                // self?.transition(to: .failed, message: "Communication error")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Ready to Download Timeout
    
    private func startReadyToDownloadTimeout() {
        readyToDownloadStartTime = Date()
        readyToDownloadTimer?.invalidate()
        readyToDownloadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkReadyToDownloadTimeout()
        }
    }
    
    private func stopReadyToDownloadTimeout() {
        readyToDownloadTimer?.invalidate()
        readyToDownloadTimer = nil
        readyToDownloadStartTime = nil
    }
    
    private func checkReadyToDownloadTimeout() {
        guard let startTime = readyToDownloadStartTime else { return }
        
        if Date().timeIntervalSince(startTime) > readyToDownloadTimeout {
            stopReadyToDownloadTimeout()
            let errorMsg = localizedMessage("ota_msg_ready_timeout")
            self.errorMessage = errorMsg
            transition(to: .failed, message: errorMsg)
        }
    }
    
    // MARK: - Verification Loop
    
    private func startVerificationLoop() {
        verificationStartTime = Date()
        verificationTimer?.invalidate()
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollVersion()
        }
    }
    
    private func stopVerificationLoop() {
        verificationTimer?.invalidate()
        verificationTimer = nil
    }
    
    private func pollVersion() {
        guard let startTime = verificationStartTime else { return }
        
        if Date().timeIntervalSince(startTime) > verificationTimeout {
            stopVerificationLoop()
            let errorMsg = localizedMessage("ota_msg_verification_timeout")
            self.errorMessage = errorMsg
            transition(to: .failed, message: errorMsg)
            return
        }
        
        print("OTAManager: Polling version...")
        BLEManager.shared.queryVersion()
    }
    
    func reset() {
        currentState = .idle
        targetVersion = nil
        currentOTAVersion = nil
        progressMessage = ""
        errorMessage = nil
        preparationStartTime = nil
        prepareGameDiskOTACompleted = false
        stopPrepareGameDiskOTATimeout()
        saveState()
    }
    
    // MARK: - History
    
    func fetchHistory() {
        Task {
            do {
                // We need auth_data which is usually handled via DeviceAuthManager or BLEManager directly
                // For now, let's try to get it from BLEManager if connected
                BLEManager.shared.getAuthData { result in
                    switch result {
                    case .success(let authData):
                        Task {
                            do {
                                let history = try await OTAService.shared.getOTAHistory(authData: authData)
                                DispatchQueue.main.async {
                                    self.history = history
                                }
                            } catch {
                                print("OTAManager: Failed to fetch history: \(error)")
                            }
                        }
                    case .failure(let error):
                        print("OTAManager: Failed to get auth data for history: \(error)")
                    }
                }
            }
        }
    }
}
