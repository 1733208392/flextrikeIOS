import Foundation
import Combine

class DeviceAuthManager: ObservableObject {
    static let shared = DeviceAuthManager()
    
    @Published var deviceToken: String?
    @Published var deviceTokenExpiration: Date?
    @Published var isObtainingToken: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let deviceTokenKey = "deviceToken"
    private let deviceTokenExpirationKey = "deviceTokenExpiration"
    private var cancellables = Set<AnyCancellable>()
    
    private weak var bleManager: BLEManager?
    
    private init() {
        loadCachedDeviceToken()
        setupBLEConnectionListener()
    }
    
    // MARK: - Setup
    
    private func setupBLEConnectionListener() {
        // Get BLE manager and listen for connection changes
        let bleManager = BLEManager.shared
        self.bleManager = bleManager
        
        // Subscribe to BLE connection state changes
        bleManager.$isConnected
            .dropFirst() // Skip initial value
            .filter { $0 == true } // Only react to connection becoming true
            .sink { [weak self] (_ : Bool) in
                print("DeviceAuthManager: BLE connection detected, attempting device auth")
                Task { @MainActor in
                    self?.obtainDeviceTokenIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Device Token Management
    
    /// Obtains a new device token if user is authenticated and device is connected
    func obtainDeviceTokenIfNeeded() {
        let authManager = AuthManager.shared
        let bleManager = BLEManager.shared
        
        print("DeviceAuthManager: obtainDeviceTokenIfNeeded called")
        print("  - isAuthenticated: \(authManager.isAuthenticated)")
        print("  - bleManager.isConnected: \(bleManager.isConnected)")
        print("  - isObtainingToken: \(isObtainingToken)")
        
        guard authManager.isAuthenticated,
              bleManager.isConnected,
              !isObtainingToken else {
            print("DeviceAuthManager: Guard condition failed, skipping token acquisition")
            return
        }
        
        print("DeviceAuthManager: Starting device token acquisition task")
        Task {
            await obtainDeviceToken()
        }
    }
    
    /// Obtains a new device token from the smart target device
    private func obtainDeviceToken() async {
        print("DeviceAuthManager: obtainDeviceToken() started")
        
        guard let bleManager = bleManager,
              AuthManager.shared.isAuthenticated,
              let accessToken = AuthManager.shared.currentUser?.accessToken else {
            print("DeviceAuthManager: Missing prerequisites for device token acquisition")
            print("  - bleManager: \(bleManager != nil)")
            print("  - isAuthenticated: \(AuthManager.shared.isAuthenticated)")
            print("  - accessToken: \(AuthManager.shared.currentUser?.accessToken != nil)")
            return
        }
        
        DispatchQueue.main.async {
            self.isObtainingToken = true
        }
        defer {
            DispatchQueue.main.async {
                self.isObtainingToken = false
            }
        }
        
        do {
            // Step 1: Get auth_data from BLE device
            print("DeviceAuthManager: Requesting auth_data from BLE device")
            let authData = try await getAuthDataFromBLE(bleManager: bleManager)
            print("DeviceAuthManager: Received auth_data from device, length: \(authData.count)")
            
            // Step 2: Exchange auth_data for device_token via API
            print("DeviceAuthManager: Exchanging auth_data for device_token via API")
            print("  - API endpoint: /device/relate")
            print("  - accessToken: \(accessToken.prefix(20))...")
            
            let response = try await UserAPIService.shared.relateDevice(
                authData: authData,
                accessToken: accessToken
            )
            
            print("DeviceAuthManager: API response received")
            print("  - device_token: \(response.device_token.prefix(20))...")
            print("  - expiration: \(response.expiration?.description ?? "nil")")
            
            // Step 3: Cache the device token
            DispatchQueue.main.async {
                self.deviceToken = response.device_token
                self.deviceTokenExpiration = response.expiration
                self.cacheDeviceToken(token: response.device_token, expiration: response.expiration)
                print("DeviceAuthManager: Device token obtained and cached successfully")
            }
        } catch {
            print("DeviceAuthManager: Failed to obtain device token")
            print("  - Error type: \(type(of: error))")
            print("  - Error: \(error.localizedDescription)")
            print("  - Full error: \(error)")
            // Silently fail - app continues with user-only auth
        }
    }
    
    /// Retrieves auth_data from the connected BLE device
    private func getAuthDataFromBLE(bleManager: BLEManager) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            print("DeviceAuthManager: Calling BLEManager.getAuthData()")
            bleManager.getAuthData { result in
                switch result {
                case .success(let authData):
                    print("DeviceAuthManager: BLE getAuthData success")
                    continuation.resume(returning: authData)
                case .failure(let error):
                    print("DeviceAuthManager: BLE getAuthData failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Token Caching
    
    private func cacheDeviceToken(token: String, expiration: Date?) {
        userDefaults.set(token, forKey: deviceTokenKey)
        if let expiration = expiration {
            userDefaults.set(expiration, forKey: deviceTokenExpirationKey)
        }
    }
    
    private func loadCachedDeviceToken() {
        guard let token = userDefaults.string(forKey: deviceTokenKey) else {
            return
        }
        
        // Check if token is still valid
        if let expiration = userDefaults.object(forKey: deviceTokenExpirationKey) as? Date,
           expiration > Date() {
            deviceToken = token
            deviceTokenExpiration = expiration
            print("DeviceAuthManager: Loaded cached device token")
        } else {
            // Token expired, remove it
            clearCachedDeviceToken()
        }
    }
    
    private func clearCachedDeviceToken() {
        userDefaults.removeObject(forKey: deviceTokenKey)
        userDefaults.removeObject(forKey: deviceTokenExpirationKey)
        DispatchQueue.main.async {
            self.deviceToken = nil
            self.deviceTokenExpiration = nil
        }
    }
    
    // MARK: - Authorization Header Generation
    
    /// Generates the Authorization header value for API requests
    /// - Parameters:
    ///   - userAccessToken: User's access token (required)
    ///   - requireDeviceToken: If true, throws error when device token is unavailable. If false (default), includes device token only if available
    /// - Returns: Authorization header value
    ///   - Format with device token: "Bearer {userToken}|{deviceToken}"
    ///   - Format without device token: "Bearer {userToken}"
    /// - Throws: Error if requireDeviceToken is true but device token is unavailable
    func getAuthorizationHeaderValue(userAccessToken: String, requireDeviceToken: Bool = false) throws -> String {
        if let deviceToken = deviceToken {
            return "Bearer \(userAccessToken)|\(deviceToken)"
        } else {
            if requireDeviceToken {
                throw NSError(domain: "DeviceAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device token required but unavailable"])
            }
            return "Bearer \(userAccessToken)"
        }
    }
    
    // MARK: - Reset on Logout
    
    func clearDeviceAuth() {
        clearCachedDeviceToken()
        deviceToken = nil
        deviceTokenExpiration = nil
    }
}
