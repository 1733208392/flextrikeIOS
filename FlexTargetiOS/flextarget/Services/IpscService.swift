import Foundation

// MARK: - IPSC Server Base URL
private let ipscBaseURL = "http://124.222.233.30"

// MARK: - Response Wrapper

struct IpscApiResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

// MARK: - Match

struct IpscMatch: Decodable, Identifiable {
    let id: Int
    let name: String
    let date: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, date, status
        case createdAt = "created_at"
    }
}

// MARK: - Stage

struct IpscStage: Decodable, Identifiable {
    let id: Int
    let matchId: Int
    let name: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case matchId = "match_id"
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        matchId = try container.decodeIfPresent(Int.self, forKey: .matchId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Stage"
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

// MARK: - Squad / Shooter

struct IpscShooter: Decodable, Identifiable {
    let id: Int
    let name: String
    let bibNumber: String
    let divisionName: String
    let categoryName: String?
    let powerFactor: String
    let stagesDone: Int
    let status: String  // "waiting" | "shooting" | "done"
    let isDq: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case bibNumber    = "bib_number"
        case divisionName = "division_name"
        case categoryName = "category_name"
        case categoryAlias = "category"
        case powerFactor  = "power_factor"
        case stagesDone   = "stages_done"
        case isDq         = "is_dq"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bibNumber = try container.decode(String.self, forKey: .bibNumber)
        divisionName = try container.decode(String.self, forKey: .divisionName)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
            ?? container.decodeIfPresent(String.self, forKey: .categoryAlias)
        powerFactor = try container.decodeIfPresent(String.self, forKey: .powerFactor) ?? "Unknown"
        stagesDone = try container.decode(Int.self, forKey: .stagesDone)
        status = try container.decode(String.self, forKey: .status)
        isDq = try container.decodeIfPresent(Bool.self, forKey: .isDq) ?? false
    }
}

struct IpscSquad: Decodable, Identifiable {
    let id: Int
    let name: String
    let sortOrder: Int
    let shooterCount: Int
    let stagesTotal: Int
    let shooters: [IpscShooter]

    enum CodingKeys: String, CodingKey {
        case id, name, shooters
        case sortOrder    = "sort_order"
        case shooterCount = "shooter_count"
        case stagesTotal  = "stages_total"
    }
}

struct IpscLockedSelectionContext {
    let matchId: Int
    let matchName: String
    let stageId: Int
    let stageName: String
    let squadId: Int
    let squadName: String
    let shooter: IpscShooter
}

// MARK: - Score Submit Request

struct IpscScoreHits: Encodable {
    let A: Int
    let C: Int
    let D: Int
    let M: Int
    let N: Int
}

struct IpscScorePenalties: Encodable {
    let PE: Int
}

enum IpscScoreStatus: String, Encodable {
    case normal
    case dq
}

struct IpscScoreTargetRow: Encodable {
    let rowType: String
    let rowNo: Int
    let A: Int
    let C: Int
    let D: Int
    let M: Int
    let N: Int

    enum CodingKeys: String, CodingKey {
        case A, C, D, M, N
        case rowType = "row_type"
        case rowNo = "row_no"
    }
}

struct IpscScoreSubmitRequest: Encodable {
    let shooterBib: String
    let stageId: String
    let totalTime: Double
    let status: IpscScoreStatus
    let hits: IpscScoreHits?
    let rows: [IpscScoreTargetRow]?
    let penalties: IpscScorePenalties
    let firstShot: Double?
    let fastestSplit: Double?

    enum CodingKeys: String, CodingKey {
        case status, hits, rows, penalties
        case shooterBib   = "shooter_bib"
        case stageId      = "stage_id"
        case totalTime    = "total_time"
        case firstShot    = "first_shot"
        case fastestSplit = "fastest_split"
    }
}

// MARK: - Score Submit Response

struct IpscScoreRecord: Decodable {
    let id: Int
    let matchId: Int
    let shooterId: Int
    let stageId: Int
    let totalTime: Double
    let aHits: Int
    let cHits: Int
    let dHits: Int
    let mHits: Int
    let nHits: Int
    let pe: Int
    let firstShot: Double?
    let fastestSplit: Double?
    let totalPoints: Int
    let hitFactor: Double

    enum CodingKeys: String, CodingKey {
        case id, pe
        case matchId      = "match_id"
        case shooterId    = "shooter_id"
        case stageId      = "stage_id"
        case totalTime    = "total_time"
        case aHits        = "a_hits"
        case cHits        = "c_hits"
        case dHits        = "d_hits"
        case mHits        = "m_hits"
        case nHits        = "n_hits"
        case firstShot    = "first_shot"
        case fastestSplit = "fastest_split"
        case totalPoints  = "total_points"
        case hitFactor    = "hit_factor"
    }

    init(
        id: Int,
        matchId: Int,
        shooterId: Int,
        stageId: Int,
        totalTime: Double,
        aHits: Int,
        cHits: Int,
        dHits: Int,
        mHits: Int,
        nHits: Int,
        pe: Int,
        firstShot: Double?,
        fastestSplit: Double?,
        totalPoints: Int,
        hitFactor: Double
    ) {
        self.id = id
        self.matchId = matchId
        self.shooterId = shooterId
        self.stageId = stageId
        self.totalTime = totalTime
        self.aHits = aHits
        self.cHits = cHits
        self.dHits = dHits
        self.mHits = mHits
        self.nHits = nHits
        self.pe = pe
        self.firstShot = firstShot
        self.fastestSplit = fastestSplit
        self.totalPoints = totalPoints
        self.hitFactor = hitFactor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        matchId = try container.decodeIfPresent(Int.self, forKey: .matchId) ?? 0
        shooterId = try container.decodeIfPresent(Int.self, forKey: .shooterId) ?? 0
        stageId = try container.decodeIfPresent(Int.self, forKey: .stageId) ?? 0
        totalTime = try container.decodeIfPresent(Double.self, forKey: .totalTime) ?? 0
        aHits = try container.decodeIfPresent(Int.self, forKey: .aHits) ?? 0
        cHits = try container.decodeIfPresent(Int.self, forKey: .cHits) ?? 0
        dHits = try container.decodeIfPresent(Int.self, forKey: .dHits) ?? 0
        mHits = try container.decodeIfPresent(Int.self, forKey: .mHits) ?? 0
        nHits = try container.decodeIfPresent(Int.self, forKey: .nHits) ?? 0
        pe = try container.decodeIfPresent(Int.self, forKey: .pe) ?? 0
        firstShot = try container.decodeIfPresent(Double.self, forKey: .firstShot)
        fastestSplit = try container.decodeIfPresent(Double.self, forKey: .fastestSplit)
        totalPoints = try container.decodeIfPresent(Int.self, forKey: .totalPoints) ?? 0
        hitFactor = try container.decodeIfPresent(Double.self, forKey: .hitFactor) ?? 0
    }
}

struct IpscScoreSubmitData: Decodable {
    let score: IpscScoreRecord
    let totalPoints: Int
    let hitFactor: Double

    enum CodingKeys: String, CodingKey {
        case score
        case totalPoints = "total_points"
        case hitFactor = "hit_factor"
        case totalPointsCamel = "totalPoints"
        case hitFactorCamel = "hitFactor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Some server builds only return `score` and omit top-level totals.
        // Fallback to values from `score` to prevent decode failure.
        score = try container.decodeIfPresent(IpscScoreRecord.self, forKey: .score) ?? IpscScoreRecord(
            id: 0,
            matchId: 0,
            shooterId: 0,
            stageId: 0,
            totalTime: 0,
            aHits: 0,
            cHits: 0,
            dHits: 0,
            mHits: 0,
            nHits: 0,
            pe: 0,
            firstShot: nil,
            fastestSplit: nil,
            totalPoints: 0,
            hitFactor: 0
        )

        totalPoints =
            try container.decodeIfPresent(Int.self, forKey: .totalPointsCamel)
            ?? container.decodeIfPresent(Int.self, forKey: .totalPoints)
            ?? score.totalPoints
        hitFactor =
            try container.decodeIfPresent(Double.self, forKey: .hitFactorCamel)
            ?? container.decodeIfPresent(Double.self, forKey: .hitFactor)
            ?? score.hitFactor
    }
}

// MARK: - Drill Replay Upload

/// Request payload for `POST /api/v1/matches/{matchId}/drill-replays`.
/// `payload` is the full `DetailData` (one entry per shot — hit area, hit
/// position, target type/name, timing) so the admin viewer can rewind
/// what happened during the run.
struct IpscDrillReplayUploadRequest: Encodable {
    let shooterId: Int
    let stageId: Int
    let drillName: String?
    let totalTime: Double
    let numShots: Int
    let score: Int?
    let clientDrillResultId: String?
    let deviceId: String?
    let payload: DetailData

    enum CodingKeys: String, CodingKey {
        case shooterId            = "shooter_id"
        case stageId              = "stage_id"
        case drillName            = "drill_name"
        case totalTime            = "total_time"
        case numShots             = "num_shots"
        case score
        case clientDrillResultId  = "client_drill_result_id"
        case deviceId             = "device_id"
        case payload
    }
}

struct IpscDrillReplayUploadData: Decodable {
    let id: Int
    let matchId: Int
    let shooterId: Int
    let stageId: Int
    let numShots: Int

    enum CodingKeys: String, CodingKey {
        case id
        case matchId  = "match_id"
        case shooterId = "shooter_id"
        case stageId  = "stage_id"
        case numShots = "num_shots"
    }
}

// MARK: - IpscService

/// Stateless URLSession wrapper for the IPSC match server.
/// All requests go to the configured IPSC server at `ipscBaseURL`.
final class IpscService {

    static let shared = IpscService()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private let decoder = JSONDecoder()

    private func authHeaderValue() throws -> String {
        guard let token = AuthManager.shared.currentAccessToken(), !token.isEmpty else {
            throw IpscError.notLoggedIn
        }
        return "Bearer \(token)"
    }

    // MARK: Matches — GET /api/v1/matches
    func getMatches() async throws -> [IpscMatch] {
        let url = try makeURL("api/v1/matches")
        let response: IpscApiResponse<[IpscMatch]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load matches")
        }
        return data
    }

    // MARK: Squad Queue — GET /api/v1/matches/{matchId}/squads/queue
    func getSquadQueue(matchId: Int) async throws -> [IpscSquad] {
        let url = try makeURL("api/v1/matches/\(matchId)/squads/queue")
        let response: IpscApiResponse<[IpscSquad]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load squads")
        }
        return data
    }

    // MARK: Stages — GET /api/v1/matches/{matchId}/stages
    func getStages(matchId: Int) async throws -> [IpscStage] {
        let url = try makeURL("api/v1/matches/\(matchId)/stages")
        let response: IpscApiResponse<[IpscStage]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load stages")
        }
        return data
    }

    // MARK: Submit Score — POST /api/v1/matches/{matchId}/scores/flextarget
    func submitScore(matchId: Int, request: IpscScoreSubmitRequest) async throws -> IpscScoreSubmitData {
        let url = try makeURL("api/v1/matches/\(matchId)/scores/flextarget")
        let response: IpscApiResponse<IpscScoreSubmitData> = try await post(url, body: request)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Submission failed")
        }
        return data
    }

    // MARK: Upload Drill Replay — POST /api/v1/matches/{matchId}/drill-replays
    ///
    /// Uploads the raw drill data (shots with hit area, hit position, target
    /// type/name, timing) so the GCS admin can rewind/replay the run.
    /// The full `DetailData` payload is sent verbatim under `payload`.
    func uploadDrillReplay(
        matchId: Int,
        request: IpscDrillReplayUploadRequest
    ) async throws -> IpscDrillReplayUploadData {
        let url = try makeURL("api/v1/matches/\(matchId)/drill-replays")
        let response: IpscApiResponse<IpscDrillReplayUploadData> = try await post(url, body: request)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Replay upload failed")
        }
        return data
    }

    // MARK: - Internals

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(ipscBaseURL)/\(path)") else {
            throw IpscError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(try authHeaderValue(), forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try authHeaderValue(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - IpscRepository (5-min cache)

/// Wraps `IpscService` with a simple in-memory cache (5-minute TTL) for
/// matches and squad queue. Score submission always hits the network.
@MainActor
final class IpscRepository {

    static let shared = IpscRepository()
    private init() {}

    private let service = IpscService.shared
    private let cacheTTL: TimeInterval = 5 * 60

    private var cachedMatches: [IpscMatch]?
    private var matchesCachedAt: Date?

    private var squadCache: [Int: (date: Date, squads: [IpscSquad])] = [:]
    private var stageCache: [Int: (date: Date, stages: [IpscStage])] = [:]

    func getMatches(forceRefresh: Bool = false) async throws -> [IpscMatch] {
        if !forceRefresh,
           let cached = cachedMatches,
           let cachedAt = matchesCachedAt,
           Date().timeIntervalSince(cachedAt) < cacheTTL {
            return cached
        }
        let matches = try await service.getMatches()
        cachedMatches = matches
        matchesCachedAt = Date()
        return matches
    }

    func getSquadQueue(matchId: Int, forceRefresh: Bool = false) async throws -> [IpscSquad] {
        if !forceRefresh,
           let entry = squadCache[matchId],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.squads
        }
        let squads = try await service.getSquadQueue(matchId: matchId)
        squadCache[matchId] = (date: Date(), squads: squads)
        return squads
    }

    func getStages(matchId: Int, forceRefresh: Bool = false) async throws -> [IpscStage] {
        if !forceRefresh,
           let entry = stageCache[matchId],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.stages
        }

        let stages = try await service.getStages(matchId: matchId)
        stageCache[matchId] = (date: Date(), stages: stages)
        return stages
    }

    func submitScore(matchId: Int, request: IpscScoreSubmitRequest) async throws -> IpscScoreSubmitData {
        let result = try await service.submitScore(matchId: matchId, request: request)
        invalidateCache(matchId: matchId)
        return result
    }

    func invalidateCache(matchId: Int? = nil) {
        if let id = matchId {
            squadCache.removeValue(forKey: id)
            stageCache.removeValue(forKey: id)
        } else {
            cachedMatches = nil
            matchesCachedAt = nil
            squadCache.removeAll()
            stageCache.removeAll()
        }
    }
}

// MARK: - IpscError

enum IpscError: LocalizedError {
    case invalidURL
    case serverError(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid server URL"
        case .serverError(let m):  return m
        case .notLoggedIn:         return "未登陆"
        }
    }
}
