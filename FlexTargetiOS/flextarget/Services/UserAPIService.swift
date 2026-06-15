import Foundation

// MARK: - Custom Errors

enum UserAPIError: Error, LocalizedError {
    case tokenExpired(String)
    case invalidResponse(String)
    case apiError(code: Int, message: String)
    case unauthorizedRefresh
    
    var errorDescription: String? {
        switch self {
        case .tokenExpired(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .apiError(_, let message):
            return message
        case .unauthorizedRefresh:
            return "Session expired"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unknown error"
    }
}

class UserAPIService {
    static let shared = UserAPIService()
    
    private let session = URLSession.shared
    lazy var serverConfig = ServerConfig()
    private let retryCoordinator = AuthorizedRetryCoordinator()
    private var v1AuthBaseURL: String { serverConfig.getServerUrl() }
    
    private var baseURL: String { serverConfig.getServerUrl() }
    
    // MARK: - Helper Methods
    
    private func base64Encoded(_ string: String) -> String {
        let data = string.data(using: .utf8)!
        var base64String = data.base64EncodedString()
        
        // Remove any padding "=" characters
        base64String = base64String.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        return base64String
    }
    
    // MARK: - API Response Models
    
    struct APIResponse<T: Codable>: Codable {
        let code: Int
        let msg: String
        let data: T?
    }

    struct AuthAPIResponse<T: Codable>: Codable {
        let success: Bool
        let data: T?
        let message: String?
    }
    
    struct EmptyData: Codable {
        // Empty structure for API responses with no data
    }
    
    struct LoginData: Codable {
        let token: String?
        let access_token: String
        let refresh_token: String
        let expires_in: Int?
        let user: AuthUser?
        let user_uuid: String?
    }

    struct AuthUser: Codable {
        let id: Int
        let username: String?
        let role: String?
        let club_id: Int?
        let name: String?
        let phone: String?
        let status: String?
    }
    
    struct RefreshTokenData: Codable {
        let token: String?
        let access_token: String
        let refresh_token: String
        let expires_in: Int?
        let user: AuthUser?
    }
    
    struct EditUserData: Codable {
        let user_uuid: String
    }
    
    struct ChangePasswordData: Codable {
        let user_uuid: String
    }
    
    struct UserGetData: Codable {
        let user_uuid: String
        let username: String
        let mobile: String?
    }
    
    struct DeviceRelateData: Codable {
        let device_uuid: String
        let device_token: String
        let expiration: Date?
        
        enum CodingKeys: String, CodingKey {
            case device_uuid
            case device_token
            case expiration
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            device_uuid = try container.decode(String.self, forKey: .device_uuid)
            device_token = try container.decode(String.self, forKey: .device_token)
            
            // Try to decode expiration as either Int (timestamp) or Date
            if let timestamp = try container.decodeIfPresent(Int.self, forKey: .expiration) {
                expiration = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else if let dateString = try container.decodeIfPresent(String.self, forKey: .expiration) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                expiration = formatter.date(from: dateString)
            } else {
                expiration = nil
            }
        }
    }
    
    struct SendVerifyCodeData: Codable {
        let code: Int
        let msg: String
    }
    
    struct RegisterData: Codable {
        let user_uuid: String
        let access_token: String
        let refresh_token: String
    }
    
    // MARK: - API Methods
    
    func login(mobile: String, password: String) async throws -> LoginData {
        do {
            return try await loginV1(username: mobile, password: password)
        } catch {
            // Keep compatibility with existing production servers that still expose legacy auth routes.
            if shouldFallbackToLegacyLogin(error) {
                return try await loginLegacy(account: mobile, password: password)
            }
            throw error
        }
    }

    private func loginV1(username: String, password: String) async throws -> LoginData {
        let url = URL(string: "\(v1AuthBaseURL)/api/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "username": username,
            "account": username,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, httpResponse) = try await execute(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "UserAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: extractServerErrorMessage(data: data, fallback: "Login failed")]
            )
        }
        let response: AuthAPIResponse<LoginData> = try JSONDecoder().decode(AuthAPIResponse.self, from: data)

        if response.success == false {
            throw NSError(domain: "UserAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Login failed"])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }

    private func loginLegacy(account: String, password: String) async throws -> LoginData {
        let encodedPassword = base64Encoded(password)
        let plainPassword = password
        let isEmail = account.contains("@")
        let isMobile = isLikelyMobile(account)

        var attempts: [(path: String, body: [String: String])] = []

        if isEmail {
            attempts.append(("/user/login/email", ["email": account, "password": encodedPassword]))
            attempts.append(("/user/login", ["email": account, "password": encodedPassword]))
        } else if isMobile {
            attempts.append(("/user/login/mobile", ["mobile": account, "password": encodedPassword]))
            attempts.append(("/user/login", ["mobile": account, "password": encodedPassword]))
        } else {
            // Username-style accounts (for example seeded admin accounts) may still be deserialized by
            // legacy handlers that require the `mobile` field to exist.
            attempts.append((
                "/user/login",
                [
                    "mobile": account,
                    "username": account,
                    "account": account,
                    "password": plainPassword
                ]
            ))
            attempts.append((
                "/user/login",
                [
                    "mobile": account,
                    "username": account,
                    "account": account,
                    "password": encodedPassword
                ]
            ))
            attempts.append((
                "/user/login/username",
                [
                    "mobile": account,
                    "username": account,
                    "account": account,
                    "password": plainPassword
                ]
            ))
            attempts.append((
                "/user/login/username",
                [
                    "mobile": account,
                    "username": account,
                    "account": account,
                    "password": encodedPassword
                ]
            ))
            attempts.append(("/user/login", ["username": account, "password": plainPassword]))
            attempts.append(("/user/login", ["username": account, "password": encodedPassword]))
            attempts.append(("/user/login", ["account": account, "password": plainPassword]))
            attempts.append(("/user/login", ["account": account, "password": encodedPassword]))
        }

        var lastError: Error?
        var nonMobileFormatError: Error?
        for attempt in attempts {
            do {
                return try await loginLegacyViaPath(path: attempt.path, body: attempt.body)
            } catch {
                lastError = error
                if !isMobileFormatError(error) {
                    nonMobileFormatError = error
                }
            }
        }

        throw nonMobileFormatError ?? lastError ?? NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Login failed"])
    }

    private func loginLegacyViaPath(path: String, body: [String: String]) async throws -> LoginData {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, httpResponse) = try await execute(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "UserAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: extractServerErrorMessage(data: data, fallback: "Login failed")]
            )
        }

        let response: APIResponse<LoginData> = try JSONDecoder().decode(APIResponse.self, from: data)
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }

        guard let payload = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        return payload
    }
    
    func loginWithMobile(mobile: String, password: String) async throws -> LoginData {
        try await login(mobile: mobile, password: password)
    }

    func loginWithAccount(account: String, password: String) async throws -> LoginData {
        // Keep one canonical auth path so v1/legacy fallback behavior is consistent
        // and username logins do not end up surfacing legacy "missing mobile" format errors.
        try await login(mobile: account, password: password)
    }
    
    func loginWithEmail(email: String, password: String) async throws -> LoginData {
        try await login(mobile: email, password: password)
    }
    
    func refreshToken(refreshToken: String) async throws -> RefreshTokenData {
        let url = URL(string: "\(v1AuthBaseURL)/api/v1/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, httpResponse) = try await execute(request)
        if httpResponse.statusCode == 401 {
            throw UserAPIError.unauthorizedRefresh
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "UserAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Token refresh failed"])
        }

        let response: AuthAPIResponse<RefreshTokenData> = try JSONDecoder().decode(AuthAPIResponse.self, from: data)
        if response.success == false {
            throw NSError(domain: "UserAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Token refresh failed"])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }
    
    func logout(accessToken: String, refreshToken: String) async throws {
        let url = URL(string: "\(v1AuthBaseURL)/api/v1/auth/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
        
        let (data, httpResponse) = try await execute(request)
        if !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "UserAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Logout failed"])
        }
    }

    func performAuthorizedRequest(path: String, method: String = "POST", body: [String: Any]? = nil, requireDeviceToken: Bool = false) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw UserAPIError.invalidResponse("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        request.setValue(try authorizationHeader(requireDeviceToken: requireDeviceToken), forHTTPHeaderField: "Authorization")

        let (data, _) = try await sendWithAutoRefresh(
            request,
            requireDeviceToken: requireDeviceToken
        )
        return data
    }
    
    func editUser(username: String, accessToken: String) async throws -> EditUserData {
        let url = URL(string: "\(baseURL)/user/edit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["username": username]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await sendWithAutoRefresh(request)
        let response: APIResponse<EditUserData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            // Check for token expiration (code 401)
            if response.code == 401 && response.msg.lowercased().contains("token") && response.msg.lowercased().contains("expired") {
                throw UserAPIError.tokenExpired(response.msg)
            }
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }
    
    func changePassword(oldPassword: String, newPassword: String, accessToken: String) async throws -> ChangePasswordData {
        let url = URL(string: "\(baseURL)/user/change-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "old_password": base64Encoded(oldPassword),
            "new_password": base64Encoded(newPassword)
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await sendWithAutoRefresh(request)
        let response: APIResponse<ChangePasswordData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            // Check for token expiration (code 401)
            if response.code == 401 && response.msg.lowercased().contains("token") && response.msg.lowercased().contains("expired") {
                throw UserAPIError.tokenExpired(response.msg)
            }
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }
    
    func getUser(accessToken: String? = nil) async throws -> UserGetData {
        let url = URL(string: "\(v1AuthBaseURL)/api/v1/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try authorizationHeader(requireDeviceToken: false), forHTTPHeaderField: "Authorization")

        let (data, _) = try await sendWithAutoRefresh(request)
        let response: AuthAPIResponse<AuthUser> = try JSONDecoder().decode(AuthAPIResponse.self, from: data)

        guard response.success, let authUser = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Failed to get user"])
        }

        guard let userUUID = AuthManager.shared.currentUser?.userUUID else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }

        return UserGetData(
            user_uuid: userUUID,
            username: authUser.username ?? authUser.name ?? "",
            mobile: authUser.phone
        )
    }
    
    func relateDevice(authData: String, accessToken: String) async throws -> DeviceRelateData {
        let url = URL(string: "\(baseURL)/device/relate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["auth_data": authData]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await sendWithAutoRefresh(request)
        let response: APIResponse<DeviceRelateData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let deviceData = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device data received"])
        }
        
        return deviceData
    }
    
    func sendVerifyCode(email: String) async throws -> SendVerifyCodeData {
        let url = URL(string: "\(baseURL)/user/register/email/send-verify-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("[UserAPIService] sendVerifyCode response status: \(httpResponse.statusCode)")
        }
        
        // Try to log the raw response as string for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[UserAPIService] sendVerifyCode raw response: \(responseString)")
        }
        
        // Use EmptyData since the data field is empty in the response
        do {
            let response: APIResponse<EmptyData> = try JSONDecoder().decode(APIResponse.self, from: data)
            
            if response.code != 0 {
                throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
            }
            
            return SendVerifyCodeData(code: response.code, msg: response.msg)
        } catch {
            print("[UserAPIService] sendVerifyCode JSON decode failed: \(error)")
            throw error
        }
    }
    
    func register(email: String, password: String, verifyCode: String) async throws {
        let url = URL(string: "\(baseURL)/user/register/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "password": base64Encoded(password),
            "verify_code": verifyCode
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("[UserAPIService] register response status: \(httpResponse.statusCode)")
        }
        
        // Try to log the raw response as string for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[UserAPIService] register raw response: \(responseString)")
        }
        
        // Use EmptyData since the data field is empty in the response
        do {
            let response: APIResponse<EmptyData> = try JSONDecoder().decode(APIResponse.self, from: data)
            
            if response.code != 0 {
                throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
            }
        } catch {
            print("[UserAPIService] register JSON decode failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Password Reset
    
    func sendResetPasswordVerifyCode(email: String) async throws -> SendVerifyCodeData {
        let url = URL(string: "\(baseURL)/user/reset-password/email/send-verify-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("[UserAPIService] sendResetPasswordVerifyCode response status: \(httpResponse.statusCode)")
        }
        
        // Try to log the raw response as string for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[UserAPIService] sendResetPasswordVerifyCode raw response: \(responseString)")
        }
        
        // Use EmptyData since the data field is empty in the response
        do {
            let response: APIResponse<EmptyData> = try JSONDecoder().decode(APIResponse.self, from: data)
            
            if response.code != 0 {
                throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
            }
            
            return SendVerifyCodeData(code: response.code, msg: response.msg)
        } catch {
            print("[UserAPIService] sendResetPasswordVerifyCode JSON decode failed: \(error)")
            throw error
        }
    }
    
    func resetPassword(email: String, password: String, verifyCode: String) async throws {
        let url = URL(string: "\(baseURL)/user/reset-password/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "password": base64Encoded(password),
            "verify_code": verifyCode
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("[UserAPIService] resetPassword response status: \(httpResponse.statusCode)")
        }
        
        // Try to log the raw response as string for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[UserAPIService] resetPassword raw response: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        do {
            let response: APIResponse<EmptyData> = try decoder.decode(APIResponse.self, from: data)
            
            if response.code != 0 {
                throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
            }
            
            print("[UserAPIService] Password reset successful")
        } catch {
            print("[UserAPIService] resetPassword JSON decode failed: \(error)")
            throw error
        }
    }

    private func authorizationHeader(requireDeviceToken: Bool) throws -> String {
        guard let accessToken = AuthManager.shared.currentAccessToken() else {
            throw NSError(domain: "UserAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        return try DeviceAuthManager.shared.getAuthorizationHeaderValue(
            userAccessToken: accessToken,
            requireDeviceToken: requireDeviceToken
        )
    }

    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserAPIError.invalidResponse("Invalid HTTP response")
        }
        return (data, httpResponse)
    }

    private func loginWithAttempts(_ attempts: [(url: String, body: [String: String])]) async throws -> LoginData {
        var lastError: Error?
        for attempt in attempts {
            do {
                return try await loginAuto(urlString: attempt.url, body: attempt.body)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Login failed"])
    }

    private func loginAuto(urlString: String, body: [String: String]) async throws -> LoginData {
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, httpResponse) = try await execute(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "UserAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: extractServerErrorMessage(data: data, fallback: "Login failed")]
            )
        }

        if let v1 = try? JSONDecoder().decode(AuthAPIResponse<LoginData>.self, from: data) {
            if v1.success, let payload = v1.data {
                return payload
            }
            throw NSError(domain: "UserAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: v1.message ?? "Login failed"])
        }

        if let legacy = try? JSONDecoder().decode(APIResponse<LoginData>.self, from: data) {
            if legacy.code == 0, let payload = legacy.data {
                return payload
            }
            throw NSError(domain: "UserAPI", code: legacy.code, userInfo: [NSLocalizedDescriptionKey: legacy.msg])
        }

        throw UserAPIError.invalidResponse("Unexpected login response format")
    }

    private func isNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "UserAPI" && nsError.code == 404
    }

    private func shouldFallbackToLegacyLogin(_ error: Error) -> Bool {
        if isNotFound(error) {
            return true
        }

        let nsError = error as NSError
        guard nsError.domain == "UserAPI" else {
            return false
        }

        if nsError.code == 400 || nsError.code == 422 {
            let message = nsError.localizedDescription.lowercased()
            return message.contains("missing field")
                || message.contains("invalid mobile")
                || message.contains("deserialize")
                || message.contains("field 'mobile'")
        }

        return false
    }

    private func isLikelyMobile(_ value: String) -> Bool {
        let digitsOnly = value.allSatisfy { $0.isNumber }
        return digitsOnly && value.count >= 8 && value.count <= 15
    }

    private func isMobileFormatError(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("invalid mobile number format") || message.contains("field 'mobile'")
    }

    private func extractServerErrorMessage(data: Data, fallback: String) -> String {
        if let v1 = try? JSONDecoder().decode(AuthAPIResponse<EmptyData>.self, from: data),
           let message = v1.message,
           !message.isEmpty {
            return message
        }
        if let legacy = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data), !legacy.msg.isEmpty {
            return legacy.msg
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        return fallback
    }

    private func sendWithAutoRefresh(_ request: URLRequest, requireDeviceToken: Bool = false) async throws -> (Data, HTTPURLResponse) {
        let firstAttempt = try await execute(request)
        if !isUnauthorized(data: firstAttempt.0, response: firstAttempt.1) {
            return firstAttempt
        }

        let refreshed = try await retryCoordinator.retryAfterRefresh {
            _ = try await AuthManager.shared.refreshAccessToken(force: true)
        }
        guard refreshed else {
            await AuthManager.shared.handleRefreshTokenRejected()
            throw UserAPIError.unauthorizedRefresh
        }

        var retryRequest = request
        retryRequest.setValue(try authorizationHeader(requireDeviceToken: requireDeviceToken), forHTTPHeaderField: "Authorization")
        return try await execute(retryRequest)
    }

    private func isUnauthorized(data: Data, response: HTTPURLResponse) -> Bool {
        if response.statusCode == 401 {
            return true
        }
        if let envelope = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data), envelope.code == 401 {
            return true
        }
        return false
    }
}

private actor AuthorizedRetryCoordinator {
    private var activeRefreshTask: Task<Bool, Error>?

    func retryAfterRefresh(_ refreshBlock: @escaping () async throws -> Void) async throws -> Bool {
        if let activeRefreshTask {
            return try await activeRefreshTask.value
        }

        let task = Task<Bool, Error> {
            do {
                try await refreshBlock()
                return true
            } catch {
                return false
            }
        }

        activeRefreshTask = task
        defer { activeRefreshTask = nil }
        return try await task.value
    }
}
