import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var tokenExpired: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "currentUser"
    private var tokenRefreshTimer: Timer?
    private let tokenRefreshInterval: TimeInterval = 55 * 60 // Refresh every 55 minutes
    
    private init() {
        print("[AuthManager] Initializing AuthManager")
        loadUser()
        if currentUser != nil {
            print("[AuthManager] User loaded successfully, starting token refresh timer")
            startTokenRefreshTimer()
        } else {
            print("[AuthManager] No user loaded, user is not authenticated")
        }
    }
    
    func login(user: User) {
        print("[AuthManager] Logging in user: \(user.username ?? "unknown") with UUID: \(user.userUUID)")
        currentUser = user
        isAuthenticated = true
        saveUser()
        startTokenRefreshTimer()
        print("[AuthManager] Login successful, token refresh timer started")
    }
    
    func logout() async {
        print("[AuthManager] Starting logout process")
        if let accessToken = currentUser?.accessToken {
            do {
                try await UserAPIService.shared.logout(accessToken: accessToken)
                print("[AuthManager] Logout API call successful")
            } catch {
                print("[AuthManager] Logout API call failed: \(error)")
            }
        } else {
            print("[AuthManager] No access token available for logout API call")
        }
        
        stopTokenRefreshTimer()
        currentUser = nil
        isAuthenticated = false
        tokenExpired = false
        userDefaults.removeObject(forKey: userKey)
        
        // Clear device authentication on logout
        DeviceAuthManager.shared.clearDeviceAuth()
        print("[AuthManager] Logout completed, user data cleared")
    }
    
    func register(email: String, password: String, verifyCode: String) async throws -> UserAPIService.LoginData {
        print("[AuthManager] Attempting to register with email: \(email)")
        do {
            // Step 1: Register with email (just confirms success, no data returned)
            try await UserAPIService.shared.register(email: email, password: password, verifyCode: verifyCode)
            print("[AuthManager] Registration successful for email: \(email), now logging in...")
            
            // Step 2: Auto-detect and login with email or mobile
            let loginData = try await loginWithAutoDetect(input: email, password: password)
            
            let user = User(
                userUUID: loginData.user_uuid,
                mobile: email,
                accessToken: loginData.access_token,
                refreshToken: loginData.refresh_token
            )
            
            await MainActor.run {
                self.login(user: user)
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
                try await UserAPIService.shared.loginWithMobile(mobile: input, password: password)
            }
            
            let loginType = isEmail ? "email" : "mobile"
            print("[AuthManager] Login successful with \(loginType): \(input)")
            return loginData
        } catch {
            let loginType = isEmail ? "email" : "mobile"
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
    
    func updateTokens(accessToken: String, refreshToken: String) {
        guard var user = currentUser else { 
            print("[AuthManager] updateTokens called but no current user")
            return 
        }
        print("[AuthManager] Updating tokens for user: \(user.username ?? "unknown")")
        user.accessToken = accessToken
        user.refreshToken = refreshToken
        currentUser = user
        saveUser()
        print("[AuthManager] Tokens updated successfully")
    }
    
    func updateUserInfo(username: String) {
        guard var user = currentUser else { 
            print("[AuthManager] updateUserInfo called but no current user")
            return 
        }
        print("[AuthManager] Updating user info for user: \(user.username ?? "unknown") to new username: \(username)")
        user.username = username
        currentUser = user
        saveUser()
        print("[AuthManager] User info updated successfully")
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async {
        guard let refreshToken = currentUser?.refreshToken else {
            print("[AuthManager] No refresh token available for refresh")
            return
        }
        
        print("[AuthManager] Starting token refresh")
        do {
            let refreshData = try await UserAPIService.shared.refreshToken(refreshToken: refreshToken)
            await MainActor.run {
                self.updateTokens(accessToken: refreshData.access_token, refreshToken: refreshData.refresh_token ?? refreshToken)
                print("[AuthManager] Token refreshed successfully")
            }
        } catch {
            print("[AuthManager] Token refresh failed: \(error)")
            // If refresh fails, logout the user
            await logout()
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
    
    private func saveUser() {
        if let user = currentUser {
            print("[AuthManager] Saving user data for: \(user.username ?? "unknown")")
            do {
                let data = try JSONEncoder().encode(user)
                userDefaults.set(data, forKey: userKey)
                print("[AuthManager] User data saved successfully")
            } catch {
                print("[AuthManager] Failed to save user: \(error)")
            }
        } else {
            print("[AuthManager] No user to save")
        }
    }
    
    
    private func loadUser() {
        print("[AuthManager] Loading user from UserDefaults")
        if let data = userDefaults.data(forKey: userKey) {
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                print("[AuthManager] User data decoded successfully for: \(user.username ?? "unknown")")
                currentUser = user
                isAuthenticated = true
                print("[AuthManager] User loaded successfully, refreshing tokens")
                
                // Refresh tokens immediately on app start
                Task {
                    await self.refreshToken()
                }
            } catch {
                print("[AuthManager] Failed to load user: \(error)")
                userDefaults.removeObject(forKey: userKey)
            }
        } else {
            print("[AuthManager] No user data found in UserDefaults")
        }
    }
}
