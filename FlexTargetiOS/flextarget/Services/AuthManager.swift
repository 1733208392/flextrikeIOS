import Foundation
import Combine
import Security

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var tokenExpired: Bool = false
    @Published var authNotice: String?
    
    private let userDefaults = UserDefaults.standard
    private var tokenRefreshTimer: Timer?
    private let tokenRefreshInterval: TimeInterval = 55 * 60
    private let refreshLeadTime: TimeInterval = 120
    private var accessTokenExpireAt: Date?
    private let sessionStore = AuthSessionStore(service: "com.flextarget.auth.session")
    private let refreshCoordinator = RefreshCoordinator()
    
    private init() {
        print("[AuthManager] Initializing AuthManager")
        serverConfig.initializeServer()
        Task {
            await restoreSessionOnLaunch()
        }
    }
    
    func login(user: User, expiresIn: Int? = nil) {
        print("[AuthManager] Logging in user: \(user.username ?? "unknown") with UUID: \(user.userUUID)")
        currentUser = user
        isAuthenticated = true
        tokenExpired = false
        authNotice = nil
        if let expiresIn {
            accessTokenExpireAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            accessTokenExpireAt = Date().addingTimeInterval(24 * 60 * 60)
        }
        saveSession()
        startTokenRefreshTimer()
        print("[AuthManager] Login successful, token refresh timer started")
    }

    func applyLoginData(_ loginData: UserAPIService.LoginData, accountHint: String? = nil) {
        let userId = loginData.user_uuid ?? String(loginData.user?.id ?? 0)
        let username = loginData.user?.username ?? loginData.user?.name
        let mobile = loginData.user?.phone ?? accountHint

        let user = User(
            userUUID: userId,
            username: username,
            mobile: mobile,
            accessToken: loginData.access_token,
            refreshToken: loginData.refresh_token
        )
        login(user: user, expiresIn: loginData.expires_in)
    }
    
    func logout() async {
        print("[AuthManager] Starting logout process")
        if let accessToken = currentUser?.accessToken,
           let refreshToken = currentUser?.refreshToken {
            do {
                try await UserAPIService.shared.logout(accessToken: accessToken, refreshToken: refreshToken)
                print("[AuthManager] Logout API call successful")
            } catch {
                print("[AuthManager] Logout API call failed: \(error)")
            }
        } else {
            print("[AuthManager] Missing tokens for logout API call")
        }

        clearLocalSession()
        print("[AuthManager] Logout completed, user data cleared")
    }

    func handleRefreshTokenRejected() async {
        print("[AuthManager] Refresh token rejected, forcing local logout")
        await MainActor.run {
            self.clearLocalSession()
            self.tokenExpired = true
            self.authNotice = NSLocalizedString("session_expired_message", comment: "Your session has expired. Please login again.")
        }
    }

    private func clearLocalSession() {
        stopTokenRefreshTimer()
        currentUser = nil
        isAuthenticated = false
        accessTokenExpireAt = nil
        tokenExpired = false
        sessionStore.clear()
        userDefaults.removeObject(forKey: "currentUser")
        
        DeviceAuthManager.shared.clearDeviceAuth()
    }
    
    func register(email: String, password: String, verifyCode: String) async throws -> UserAPIService.LoginData {
        print("[AuthManager] Attempting to register with email: \(email)")
        do {
            // Step 1: Register with email (just confirms success, no data returned)
            try await UserAPIService.shared.register(email: email, password: password, verifyCode: verifyCode)
            print("[AuthManager] Registration successful for email: \(email), now logging in...")
            
            // Step 2: Auto-detect and login with email or mobile
            let loginData = try await loginWithAutoDetect(input: email, password: password)

            await MainActor.run {
                self.applyLoginData(loginData, accountHint: email)
                print("[AuthManager] Registration and login successful")
            }
            
            return loginData
        } catch {
            print("[AuthManager] Registration failed: \(error)")
            throw error
        }
    }
    
    func loginWithAutoDetect(input: String, password: String) async throws -> UserAPIService.LoginData {
        print("[AuthManager] Attempting login with auto-detection for input: \(input)")
        let isEmail = input.contains("@")
        
        do {
            let loginData = if isEmail {
                try await UserAPIService.shared.loginWithEmail(email: input, password: password)
            } else {
                try await UserAPIService.shared.loginWithAccount(account: input, password: password)
            }
            
            let loginType = isEmail ? "email" : "account"
            print("[AuthManager] Login successful with \(loginType): \(input)")
            return loginData
        } catch {
            let loginType = isEmail ? "email" : "account"
            print("[AuthManager] Login failed with \(loginType) \(input): \(error)")
            throw error
        }
    }
    
    func sendVerifyCode(email: String) async throws {
        print("[AuthManager] Sending verification code to email: \(email)")
        do {
            let response = try await UserAPIService.shared.sendVerifyCode(email: email)
            print("[AuthManager] Verification code sent successfully, response code: \(response.code)")
        } catch {
            print("[AuthManager] Failed to send verification code: \(error)")
            throw error
        }
    }
    
    func sendResetPasswordVerifyCode(email: String) async throws {
        print("[AuthManager] Sending password reset verification code to email: \(email)")
        do {
            let response = try await UserAPIService.shared.sendResetPasswordVerifyCode(email: email)
            print("[AuthManager] Password reset verification code sent successfully, response code: \(response.code)")
        } catch {
            print("[AuthManager] Failed to send password reset verification code: \(error)")
            throw error
        }
    }
    
    func resetPassword(email: String, password: String, verifyCode: String) async throws {
        print("[AuthManager] Attempting to reset password for email: \(email)")
        do {
            // Call reset password API
            try await UserAPIService.shared.resetPassword(email: email, password: password, verifyCode: verifyCode)
            print("[AuthManager] Password reset successful for email: \(email)")
            print("[AuthManager] User will need to login with their new password")
        } catch {
            print("[AuthManager] Password reset failed: \(error)")
            throw error
        }
    }
    
    func updateTokens(accessToken: String, refreshToken: String) {
        guard var user = currentUser else {
            print("[AuthManager] updateTokens called but no current user")
            return
        }
        print("[AuthManager] Updating tokens for user: \(user.username ?? "unknown")")
        user.accessToken = accessToken
        user.refreshToken = refreshToken
        currentUser = user
        accessTokenExpireAt = Date().addingTimeInterval(24 * 60 * 60)
        saveSession()
        print("[AuthManager] Tokens updated successfully")
    }

    func updateTokens(accessToken: String, refreshToken: String, expiresIn: Int?) {
        guard var user = currentUser else {
            print("[AuthManager] updateTokens called but no current user")
            return
        }
        user.accessToken = accessToken
        user.refreshToken = refreshToken
        currentUser = user
        if let expiresIn {
            accessTokenExpireAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            accessTokenExpireAt = Date().addingTimeInterval(24 * 60 * 60)
        }
        saveSession()
    }
    
    func updateUserInfo(username: String) {
        guard var user = currentUser else { 
            print("[AuthManager] updateUserInfo called but no current user")
            return 
        }
        print("[AuthManager] Updating user info for user: \(user.username ?? "unknown") to new username: \(username)")
        user.username = username
        currentUser = user
        saveSession()
        print("[AuthManager] User info updated successfully")
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async {
        do {
            _ = try await refreshAccessToken(force: true)
        } catch {
            print("[AuthManager] Token refresh failed: \(error)")
        }
    }

    func currentAccessToken() -> String? {
        currentUser?.accessToken
    }

    func currentRefreshToken() -> String? {
        currentUser?.refreshToken
    }

    func shouldRefreshAccessToken() -> Bool {
        guard let expireAt = accessTokenExpireAt else {
            return true
        }
        return expireAt.timeIntervalSinceNow <= refreshLeadTime
    }

    func refreshAccessToken(force: Bool = false) async throws -> String {
        guard isAuthenticated, let user = currentUser else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        if !force, !shouldRefreshAccessToken() {
            return user.accessToken
        }

        guard let refreshToken = currentUser?.refreshToken, !refreshToken.isEmpty else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }

        return try await refreshCoordinator.run {
            do {
                let refreshData = try await UserAPIService.shared.refreshToken(refreshToken: refreshToken)
                let newRefreshToken = refreshData.refresh_token
                await MainActor.run {
                    self.updateTokens(
                        accessToken: refreshData.access_token,
                        refreshToken: newRefreshToken,
                        expiresIn: refreshData.expires_in
                    )
                    if let refreshedUser = refreshData.user {
                        self.updateUserInfo(username: refreshedUser.username ?? refreshedUser.name ?? self.currentUser?.username ?? "")
                    }
                    self.authNotice = nil
                    self.tokenExpired = false
                }
                return refreshData.access_token
            } catch {
                if self.isTransientNetworkError(error) {
                    await MainActor.run {
                        self.authNotice = NSLocalizedString("network_error_try_again", comment: "Network unavailable. Please retry.")
                    }
                    throw error
                }
                await self.handleRefreshTokenRejected()
                throw error
            }
        }
    }
    
    private func startTokenRefreshTimer() {
        stopTokenRefreshTimer()
        print("[AuthManager] Starting token refresh timer with interval: \(tokenRefreshInterval) seconds")
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: tokenRefreshInterval, repeats: true) { [weak self] _ in
            print("[AuthManager] Token refresh timer fired")
            Task {
                await self?.refreshToken()
            }
        }
    }
    
    private func stopTokenRefreshTimer() {
        if tokenRefreshTimer != nil {
            print("[AuthManager] Stopping token refresh timer")
            tokenRefreshTimer?.invalidate()
            tokenRefreshTimer = nil
        }
    }
    
    private func saveSession() {
        guard let user = currentUser else {
            print("[AuthManager] No user to save")
            return
        }
        let expireAt = accessTokenExpireAt ?? Date().addingTimeInterval(24 * 60 * 60)
        let payload = AuthSessionPayload(user: user, accessTokenExpireAt: expireAt)
        do {
            try sessionStore.save(payload)
            print("[AuthManager] Session saved securely")
        } catch {
            print("[AuthManager] Failed to save secure session: \(error)")
        }
    }

    private func restoreSessionOnLaunch() async {
        print("[AuthManager] Restoring secure session")
        guard let payload = sessionStore.load() else {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
            return
        }

        await MainActor.run {
            self.currentUser = payload.user
            self.accessTokenExpireAt = payload.accessTokenExpireAt
            self.isAuthenticated = true
            self.tokenExpired = false
            self.startTokenRefreshTimer()
        }

        if shouldRefreshAccessToken() {
            do {
                _ = try await refreshAccessToken(force: true)
            } catch {
                if isTransientNetworkError(error) {
                    print("[AuthManager] Startup refresh skipped due to transient network: \(error.localizedDescription)")
                    await MainActor.run {
                        self.authNotice = NSLocalizedString("network_error_try_again", comment: "Network unavailable. Please retry.")
                    }
                } else {
                    print("[AuthManager] Startup refresh failed, clearing session: \(error.localizedDescription)")
                    await handleRefreshTokenRejected()
                }
            }
        }
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }
        return urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .timedOut
            || urlError.code == .cannotFindHost
            || urlError.code == .cannotConnectToHost
    }

    lazy var serverConfig = ServerConfig()

    func toggleServer() {
        serverConfig.toggleServer()
    }

    func isInternational() -> Bool {
        return serverConfig.isInternational()
    }
}

private struct AuthSessionPayload: Codable {
    let user: User
    let accessTokenExpireAt: Date
}

private actor RefreshCoordinator {
    private var inFlight: Task<String, Error>?

    func run(_ refreshBlock: @escaping () async throws -> String) async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task {
            try await refreshBlock()
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

private final class AuthSessionStore {
    private let service: String
    private let account = "session"

    init(service: String) {
        self.service = service
    }

    func save(_ payload: AuthSessionPayload) throws {
        let data = try JSONEncoder().encode(payload)
        var query = baseQuery()

        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "AuthSessionStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to save auth session"])
        }
    }

    func load() -> AuthSessionPayload? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let payload = try? JSONDecoder().decode(AuthSessionPayload.self, from: data) else {
            return nil
        }
        return payload
    }

    func clear() {
        let query = baseQuery()
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }
}
