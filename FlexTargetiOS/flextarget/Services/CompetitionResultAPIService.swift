import Foundation
import CoreData

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
    
    struct GamePlayListResponse: Codable {
        let total_count: Int
        let limit: Int
        let page: Int
        let rows: [GamePlayRow]
    }
    
    struct GamePlayRow: Codable {
        let play_uuid: String
        let device_uuid: String
        let bluetooth_name: String?
        let game_type: String
        let game_ver: String
        let score: Float
        let play_time: String
        let player_mobile: String?
        let player_nickname: String?
        let is_public: Bool
    }
    
    struct RankingRow: Codable {
        let play_uuid: String
        let bluetooth_name: String?
        let game_type: String
        let game_ver: String
        let score: Float
        let rank: Int
        let play_time: String
        let player_mobile: String?
        let player_nickname: String?
        var athleteName: String?
        var athleteClub: String?
        var factor: Double?
    }
    
    struct GamePlayDetailData: Codable {
        let drillName: String?
        let score: Int?
        let factor: Double?
        let totalTime: TimeInterval?
        let numShots: Int?
        let fastest: TimeInterval?
        let firstShot: TimeInterval?
        let shotData: [ShotData]?
        let hitZones: [String: Int]?
        let athleteName: String?
        let athleteClub: String?
    }
    
    struct GamePlayDetailResponse: Codable {
        let play_uuid: String
        let device_uuid: String
        let bluetooth_name: String?
        let game_type: String
        let game_ver: String
        let score: Float
        let detail: GamePlayDetailData?
        let play_time: String
        let player_mobile: String?
        let player_nickname: String?
        let is_public: Bool
    }
    
    // GameRankingResponse is just [RankingRow] array
    typealias GameRankingResponse = [RankingRow]
    
    // MARK: - API Methods
    
    /// Fetch competition results from the server
    /// Uses the device UUID saved from the /device/relate endpoint
    /// - Parameters:
    ///   - gameType: Game/competition type
    ///   - gameVer: Game version
    ///   - page: Page number (default: 1)
    ///   - limit: Records per page (default: 30)
    ///   - namespace: Namespace (default: "default")
    /// - Returns: GamePlayListResponse with paginated results
    func getGamePlayList(
        gameType: String,
        gameVer: String,
        page: Int = 1,
        limit: Int = 30,
        namespace: String = "default"
    ) async throws -> GamePlayListResponse {
        let url = URL(string: "\(baseURL)/game/play/list")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get user access token from AuthManager
        guard let userAccessToken = AuthManager.shared.currentUser?.accessToken else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get device UUID from DeviceAuthManager
        guard let deviceUUID = DeviceAuthManager.shared.deviceUUID else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device UUID not available. Please ensure device is properly authenticated"])
        }
        
        // Get authorization header with user token only (user authentication required)
        let authHeader = "Bearer \(userAccessToken)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "game_type": gameType,
//            "game_ver": gameVer,
            "device_uuid": deviceUUID,
            "page": page,
            "limit": limit,
            "namespace": namespace
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<GamePlayListResponse> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "CompetitionResultAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let listData = response.data else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return listData
    }
    
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
    
    /// Fetch game play detail including shot data from the server
    /// - Parameters:
    ///   - playUuid: The play record UUID to fetch details for
    /// - Returns: GamePlayDetailResponse with full detail including shots
    func getGamePlayDetail(
        playUuid: String
    ) async throws -> GamePlayDetailResponse {
        let url = URL(string: "\(baseURL)/game/play/detail")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get user access token from AuthManager
        guard let userAccessToken = AuthManager.shared.currentUser?.accessToken else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get authorization header with user token only (user authentication required)
        let authHeader = "Bearer \(userAccessToken)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "play_uuid": playUuid
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<GamePlayDetailResponse> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "CompetitionResultAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let detailData = response.data else {
            throw NSError(domain: "CompetitionResultAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No detail data received"])
        }
        
        return detailData
    }
    
    /// Fetch game ranking from the server
    /// - Parameters:
    ///   - gameType: Game/competition type (required) - uses the competition ID
    ///   - namespace: Namespace (default: "default")
    ///   - gameVer: Game version (optional)
    ///   - page: Page number (default: 1)
    ///   - limit: Records per page (default: 30)
    /// - Returns: Array of RankingRow with ranked results
    func getGameRanking(
        gameType: String,
        namespace: String = "default",
        gameVer: String = "1.0.0",
        page: Int = 1,
        limit: Int = 30,
        viewContext: NSManagedObjectContext? = nil
    ) async throws -> [RankingRow] {
        let url = URL(string: "\(baseURL)/game/play/ranking")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "game_type": gameType,
            "namespace": namespace,
            "page": page,
            "limit": limit,
//            "game_ver": gameVer?
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await session.data(for: request)
        
        // Decode the response wrapper first
        var response: APIResponse<[RankingRow]> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "CompetitionResultAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard var rankingData = response.data else {
            return [] // Return empty array if no data
        }

        // Enrich ranking rows with local athlete info via play_uuid -> DrillResult.serverPlayId
        if let context = viewContext {
            for index in rankingData.indices {
                let row = rankingData[index]
                let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
                fetchRequest.predicate = NSPredicate(format: "serverPlayId == %@", row.play_uuid)
                fetchRequest.fetchLimit = 1

                if let drillResult = try? context.fetch(fetchRequest).first,
                   let athlete = drillResult.athlete {
                    rankingData[index].athleteName = athlete.name
                    rankingData[index].athleteClub = athlete.club
                    
                    // Compute factor on-the-fly
                    let isIPSC = drillResult.drillSetup?.mode?.lowercased() == "ipsc"
                    let score: Double
                    if let adjusted = drillResult.adjustedHitZones,
                       let jsonData = adjusted.data(using: .utf8),
                       let zones = try? JSONDecoder().decode([String: Int].self, from: jsonData),
                       let drillSetup = drillResult.drillSetup {
                        score = Double(ScoringUtility.calculateScoreFromAdjustedHitZones(zones, drillSetup: drillSetup))
                    } else if let shots = drillResult.shots?.allObjects as? [Shot] {
                        let shotData = shots.compactMap { shot -> ShotData? in
                            guard let jsonString = shot.data,
                                  let jsonData = jsonString.data(using: .utf8),
                                  let shotData = try? JSONDecoder().decode(ShotData.self, from: jsonData) else { return nil }
                            return shotData
                        }
                        if let drillSetup = drillResult.drillSetup {
                            score = Double(ScoringUtility.calculateTotalScore(shots: shotData, drillSetup: drillSetup))
                        } else {
                            score = 0
                        }
                    } else {
                        score = 0
                    }
                    
                    rankingData[index].factor = isIPSC ? (drillResult.totalTime?.doubleValue ?? 0 > 0 ? score / (drillResult.totalTime?.doubleValue ?? 0) : 0) : score
                }
            }
        }

        return rankingData
    }
}
