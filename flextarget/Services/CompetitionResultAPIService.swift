import Foundation

class CompetitionResultAPIService {
    static let shared = CompetitionResultAPIService()
    
    private let baseURL = "https://etarget.topoint-archery.cn"
    private let session = URLSession.shared
    
    // MARK: - Response Models
    
    struct APIResponse<T: Codable>: Codable {
        let code: Int
        let msg: String
        let data: T?
    }
    
    struct GamePlayResponse: Codable {
        let device_uuid: String
        let play_uuid: String
    }
    
    // MARK: - API Methods
    
    /// Submit competition result to the server
    /// The competition info itself is always saved locally in Core Data.
    /// This method submits the result and links it back to the competition created locally.
    /// - Parameters:
    ///   - gameType: Competition ID saved locally (required) - used to link result back to local competition
    ///   - gameVer: Game version (required)
    ///   - score: Game score (required)
    ///   - detail: Game details as JSON (shot data, metrics, etc.)
    ///   - playTime: Time of play in format "2025-12-12 12:23:35" (required)
    ///   - playerMobile: Player's mobile number (optional)
    ///   - playerNickname: Player's nickname (optional)
    ///   - isPublic: Whether the competition result is public (default: true)
    ///   - namespace: Namespace (default: "default")
    /// - Returns: GamePlayResponse with device_uuid and play_uuid for linking to local record
    func addGamePlay(
        gameType: String,
        gameVer: String,
        score: Float,
        detail: [String: Any],
        playTime: String,
        playerMobile: String?,
        playerNickname: String?,
        isPublic: Bool = true,
        namespace: String = "default"
    ) async throws -> GamePlayResponse {
        let url = URL(string: "\(baseURL)/game/play/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get user access token from AuthManager
        guard let userAccessToken = AuthManager.shared.currentUser?.accessToken else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get authorization header with device token (device token required for game play submission)
        let authHeader = try DeviceAuthManager.shared.getAuthorizationHeaderValue(userAccessToken: userAccessToken, requireDeviceToken: true)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "game_type": gameType,
            "game_ver": gameVer,
            "player_mobile": playerMobile ?? "",
            "player_nickname": playerNickname ?? "",
            "score": score,
            "detail": detail,
            "play_time": playTime,
            "is_public": isPublic,
            "namespace": namespace
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<GamePlayResponse> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "CompetitionResultAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let gameData = response.data else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return gameData
    }
}
