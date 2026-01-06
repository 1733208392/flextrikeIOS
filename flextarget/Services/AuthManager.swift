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
        loadUser()
        if currentUser != nil {
            startTokenRefreshTimer()
        }
    }
    
    func login(user: User) {
        currentUser = user
        isAuthenticated = true
        saveUser()
        startTokenRefreshTimer()
    }
    
    func logout() async {
        if let accessToken = currentUser?.accessToken {
            do {
                try await UserAPIService.shared.logout(accessToken: accessToken)
            } catch {
                print("Logout API call failed: \(error)")
            }
        }
        
        stopTokenRefreshTimer()
        currentUser = nil
        isAuthenticated = false
        tokenExpired = false
        userDefaults.removeObject(forKey: userKey)
        
        // Clear device authentication on logout
        DeviceAuthManager.shared.clearDeviceAuth()
    }
    
    func updateTokens(accessToken: String, refreshToken: String) {
        guard var user = currentUser else { return }
        user.accessToken = accessToken
        user.refreshToken = refreshToken
        currentUser = user
        saveUser()
    }
    
    func updateUserInfo(username: String) {
        guard var user = currentUser else { return }
        user.username = username
        currentUser = user
        saveUser()
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async {
        guard let refreshToken = currentUser?.refreshToken else {
            print("No refresh token available")
            return
        }
        
        do {
            let refreshData = try await UserAPIService.shared.refreshToken(refreshToken: refreshToken)
            await MainActor.run {
                self.updateTokens(accessToken: refreshData.access_token, refreshToken: refreshToken)
                print("Token refreshed successfully")
            }
        } catch {
            print("Token refresh failed: \(error)")
            // If refresh fails, logout the user
            await logout()
        }
    }
    
    private func startTokenRefreshTimer() {
        stopTokenRefreshTimer()
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: tokenRefreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshToken()
            }
        }
    }
    
    private func stopTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    private func saveUser() {
        if let user = currentUser {
            do {
                let data = try JSONEncoder().encode(user)
                userDefaults.set(data, forKey: userKey)
            } catch {
                print("Failed to save user: \(error)")
            }
        }
    }
    
    private func loadUser() {
        if let data = userDefaults.data(forKey: userKey) {
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                currentUser = user
                isAuthenticated = true
            } catch {
                print("Failed to load user: \(error)")
                userDefaults.removeObject(forKey: userKey)
            }
        }
    }
}
