import Foundation

// MARK: - Custom Errors

enum UserAPIError: Error, LocalizedError {
    case tokenExpired(String)
    case invalidResponse(String)
    case apiError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .tokenExpired(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .apiError(_, let message):
            return message
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unknown error"
    }
}

class UserAPIService {
    static let shared = UserAPIService()
    
    private let baseURL = "https://etarget.topoint-archery.cn"
    private let session = URLSession.shared
    
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
    
    struct LoginData: Codable {
        let user_uuid: String
        let access_token: String
        let refresh_token: String
    }
    
    struct RefreshTokenData: Codable {
        let user_uuid: String
        let access_token: String
        let refresh_token: String?
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
        let mobile: String
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
    
    // MARK: - API Methods
    
    func login(mobile: String, password: String) async throws -> LoginData {
        let url = URL(string: "\(baseURL)/user/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "mobile": mobile,
            "password": base64Encoded(password)
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<LoginData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }
    
    func refreshToken(refreshToken: String) async throws -> RefreshTokenData {
        let url = URL(string: "\(baseURL)/user/token/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<RefreshTokenData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let data = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return data
    }
    
    func logout(accessToken: String) async throws {
        let url = URL(string: "\(baseURL)/user/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<String> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
    }
    
    func editUser(username: String, accessToken: String) async throws -> EditUserData {
        let url = URL(string: "\(baseURL)/user/edit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["username": username]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
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
        
        let (data, _) = try await session.data(for: request)
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
    
    func getUser(accessToken: String) async throws -> UserGetData {
        let url = URL(string: "\(baseURL)/user/get")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<UserGetData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
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
    
    func relateDevice(authData: String, accessToken: String) async throws -> DeviceRelateData {
        let url = URL(string: "\(baseURL)/device/relate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["auth_data": authData]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<DeviceRelateData> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "UserAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let deviceData = response.data else {
            throw NSError(domain: "UserAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device data received"])
        }
        
        return deviceData
    }
}
