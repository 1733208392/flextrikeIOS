import Foundation

// MARK: - IPSC Server Base URL
// Uses the same login/server selection for competition endpoints.
// China uses a direct IP endpoint; international uses the AWS host from ServerConfig.


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
    let match_id: Int?
    let squad_id: Int?
    let division_id: Int?
    let name: String?
    let gender: String?
    let age: Int?
    let category_code: String?
    let region: String?
    let club: String?
    let club_id: Int?
    let shooter_uid: String?
    let bib_number: String?
    let division_name: String?
    let squad_name: String?
    let category_name: String?
    let power_factor: String?
    let stages_done: Int?
    let status: String?
    let is_dq: Int?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case match_id
        case squad_id
        case division_id
        case name
        case gender
        case age
        case category_code
        case region
        case club
        case club_id
        case shooter_uid
        case bib_number
        case division_name
        case squad_name
        case category_name
        case category
        case power_factor
        case stages_done
        case status
        case is_dq
        case created_at
        case updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id) ?? 0
        match_id = container.decodeFlexibleInt(forKey: .match_id)
        squad_id = container.decodeFlexibleInt(forKey: .squad_id)
        division_id = container.decodeFlexibleInt(forKey: .division_id)
        name = container.decodeFlexibleString(forKey: .name)
        gender = container.decodeFlexibleString(forKey: .gender)
        age = container.decodeFlexibleInt(forKey: .age)
        category_code = container.decodeFlexibleString(forKey: .category_code)
        region = container.decodeFlexibleString(forKey: .region)
        club = container.decodeFlexibleString(forKey: .club)
        club_id = container.decodeFlexibleInt(forKey: .club_id)
        shooter_uid = container.decodeFlexibleString(forKey: .shooter_uid)
        bib_number = container.decodeFlexibleString(forKey: .bib_number)
        division_name = container.decodeFlexibleString(forKey: .division_name)
        squad_name = container.decodeFlexibleString(forKey: .squad_name)
        category_name = container.decodeFlexibleString(forKey: .category_name)
            ?? container.decodeFlexibleString(forKey: .category)
        power_factor = container.decodeFlexibleString(forKey: .power_factor)
        stages_done = container.decodeFlexibleInt(forKey: .stages_done)
        status = container.decodeFlexibleString(forKey: .status)
        if let dq_int = try? container.decodeIfPresent(Int.self, forKey: .is_dq) {
            is_dq = dq_int
        } else if let dq_bool = try? container.decodeIfPresent(Bool.self, forKey: .is_dq) {
            is_dq = dq_bool ? 1 : 0
        } else if let dq_string = try? container.decodeIfPresent(String.self, forKey: .is_dq),
                  let dq_int = Int(dq_string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            is_dq = dq_int
        } else {
            is_dq = nil
        }
        created_at = container.decodeFlexibleString(forKey: .created_at)
        updated_at = container.decodeFlexibleString(forKey: .updated_at)
    }

    var bibNumber: String { bib_number ?? "" }
    var divisionName: String { division_name ?? "" }
    var categoryName: String? { category_name }
    var powerFactor: String { power_factor ?? "Unknown" }
    var stagesDone: Int { stages_done ?? 0 }
    var isDq: Bool { (is_dq ?? 0) == 1 }
}

struct IpscShooterCreateRequest: Encodable {
    let division_id: Int
    let name: String?
    let gender: String?
    let age: Int?
    let category_code: String?
    let squad_id: Int?
    let region: String?
    let club: String?
}

struct IpscShooterUpdateRequest: Encodable {
    let division_id: Int?
    let name: String?
    let gender: String?
    let age: Int?
    let category_code: String?
    let squad_id: Int?
    let region: String?
    let club: String?
}

struct IpscDivision: Decodable, Identifiable {
    let id: Int
    let name: String?
    let code: String?
    let sort_order: Int?
    let power_factor: String?
}

struct IpscCategory: Decodable, Identifiable {
    let id: Int
    let code: String?
    let name: String?
    let min_age: Int?
    let max_age: Int?
    let gender: String?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id) ?? 0
        name = container.decodeFlexibleString(forKey: .name) ?? ""
        sortOrder = container.decodeFlexibleInt(forKey: .sortOrder) ?? 0
        shooterCount = container.decodeFlexibleInt(forKey: .shooterCount) ?? 0
        stagesTotal = container.decodeFlexibleInt(forKey: .stagesTotal) ?? 0
        shooters = try container.decodeIfPresent([IpscShooter].self, forKey: .shooters) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: K) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: K) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? 1 : 0
        }
        return nil
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
    let squadId: Int?
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
        case squadId      = "squad_id"
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

    private struct IpscSquadQueuePayload: Decodable {
        let squads: [IpscSquad]?
        let rows: [IpscSquad]?
        let items: [IpscSquad]?
        let list: [IpscSquad]?
        let data: [IpscSquad]?
    }

    static let shared = IpscService()
    private init() {}

    private lazy var serverConfig = ServerConfig()
    private var ipscBaseURL: String { serverConfig.getServerUrl() }

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

        let rawData = try await makeRawRequest(url: url, method: "GET")

        if let response = try? decoder.decode(IpscApiResponse<[IpscSquad]>.self, from: rawData) {
            guard response.success, let data = response.data else {
                throw IpscError.serverError(response.error ?? "Failed to load squads")
            }
            return data
        }

        if let response = try? decoder.decode(IpscApiResponse<IpscSquadQueuePayload>.self, from: rawData) {
            guard response.success else {
                throw IpscError.serverError(response.error ?? "Failed to load squads")
            }

            if let data = extractSquads(from: response.data) {
                return data
            }

            return []
        }

        if let direct = try? decoder.decode([IpscSquad].self, from: rawData) {
            return direct
        }

        if let payload = try? decoder.decode(IpscSquadQueuePayload.self, from: rawData),
           let squads = extractSquads(from: payload) {
            return squads
        }

        throw IpscError.serverError("Failed to load squads: invalid response format")
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

    // MARK: Shooters — GET /api/v1/matches/{matchId}/shooters[?squad_id=N]
    func getShooters(matchId: Int, squadId: Int? = nil) async throws -> [IpscShooter] {
        var path = "api/v1/matches/\(matchId)/shooters"
        if let squadId {
            path += "?squad_id=\(squadId)"
        }

        let url = try makeURL(path)
        let response: IpscApiResponse<[IpscShooter]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load shooters")
        }
        return data
    }

    // MARK: Shooter Create — POST /api/v1/matches/{matchId}/shooters
    func createShooter(matchId: Int, request: IpscShooterCreateRequest) async throws -> IpscShooter {
        let url = try makeURL("api/v1/matches/\(matchId)/shooters")
        let response: IpscApiResponse<IpscShooter> = try await post(url, body: request)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to create shooter")
        }
        return data
    }

    // MARK: Shooter Update — PUT /api/v1/matches/{matchId}/shooters/{id}
    func updateShooter(matchId: Int, id: Int, request: IpscShooterUpdateRequest) async throws -> IpscShooter {
        do {
            return try await updateShooterAtPath("api/v1/matches/\(matchId)/shooters/\(id)", request: request)
        } catch let IpscError.serverError(message) where isNotFoundMessage(message) {
            // Compatibility fallback for deployments that still expose global shooter update routes.
            return try await updateShooterAtPath("api/v1/shooters/\(id)", request: request)
        }
    }

    // MARK: Shooter Delete — DELETE /api/v1/shooters/{id}
    func deleteShooter(id: Int) async throws {
        let url = try makeURL("api/v1/shooters/\(id)")
        let response: IpscApiResponse<Bool> = try await delete(url)
        guard response.success else {
            throw IpscError.serverError(response.error ?? "Failed to delete shooter")
        }
    }

    // MARK: Shooter Delete — DELETE /api/v1/matches/{matchId}/shooters/{id}
    func deleteShooter(matchId: Int, id: Int) async throws {
        let url = try makeURL("api/v1/matches/\(matchId)/shooters/\(id)")
        let response: IpscApiResponse<Bool> = try await delete(url)
        guard response.success else {
            throw IpscError.serverError(response.error ?? "Failed to delete shooter")
        }
    }

    // MARK: Squads — GET /api/v1/matches/{matchId}/squads
    func getSquads(matchId: Int) async throws -> [IpscSquad] {
        let url = try makeURL("api/v1/matches/\(matchId)/squads")
        let response: IpscApiResponse<[IpscSquad]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load squads")
        }
        return data
    }

    // MARK: Divisions — GET /api/v1/matches/{matchId}/divisions
    func getDivisions(matchId: Int) async throws -> [IpscDivision] {
        let url = try makeURL("api/v1/matches/\(matchId)/divisions")
        let response: IpscApiResponse<[IpscDivision]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load divisions")
        }
        return data
    }

    // MARK: Categories — GET /api/v1/matches/{matchId}/categories
    func getCategories(matchId: Int) async throws -> [IpscCategory] {
        let url = try makeURL("api/v1/matches/\(matchId)/categories")
        let response: IpscApiResponse<[IpscCategory]> = try await get(url)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to load categories")
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
        try await makeRequest(url: url, method: "GET", body: Optional<Data>.none)
    }

    private func post<Body: Encodable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        try await makeRequest(url: url, method: "POST", body: body)
    }

    private func put<Body: Encodable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        try await makeRequest(url: url, method: "PUT", body: body)
    }

    private func delete<T: Decodable>(_ url: URL) async throws -> T {
        try await makeRequest(url: url, method: "DELETE", body: Optional<Data>.none)
    }

    private func makeRequest<Body: Encodable, T: Decodable>(url: URL, method: String, body: Body?) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(try authHeaderValue(), forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, _) = try await session.data(for: request)
        return try decoder.decode(T.self, from: data)
    }

    private func makeRawRequest(url: URL, method: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(try authHeaderValue(), forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        return data
    }

    private func extractSquads(from payload: IpscSquadQueuePayload?) -> [IpscSquad]? {
        guard let payload else { return nil }
        return payload.squads ?? payload.rows ?? payload.items ?? payload.list ?? payload.data
    }

    private func updateShooterAtPath(_ path: String, request: IpscShooterUpdateRequest) async throws -> IpscShooter {
        let url = try makeURL(path)
        let response: IpscApiResponse<IpscShooter> = try await put(url, body: request)
        guard response.success, let data = response.data else {
            throw IpscError.serverError(response.error ?? "Failed to update shooter")
        }
        return data
    }

    private func isNotFoundMessage(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("not found") || message.contains("404")
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
    private var shooterCache: [String: (date: Date, shooters: [IpscShooter])] = [:]
    private var divisionCache: [Int: (date: Date, divisions: [IpscDivision])] = [:]
    private var categoryCache: [Int: (date: Date, categories: [IpscCategory])] = [:]

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

    func getShooters(matchId: Int, squadId: Int? = nil, forceRefresh: Bool = false) async throws -> [IpscShooter] {
        let cacheKey = "\(matchId)-\(squadId ?? -1)"
        if !forceRefresh,
           let entry = shooterCache[cacheKey],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.shooters
        }

        let shooters = try await service.getShooters(matchId: matchId, squadId: squadId)
        shooterCache[cacheKey] = (date: Date(), shooters: shooters)
        return shooters
    }

    func createShooter(matchId: Int, request: IpscShooterCreateRequest) async throws -> IpscShooter {
        let shooter = try await service.createShooter(matchId: matchId, request: request)
        invalidateCache(matchId: matchId)
        return shooter
    }

    func updateShooter(matchId: Int, id: Int, request: IpscShooterUpdateRequest) async throws -> IpscShooter {
        let shooter = try await service.updateShooter(matchId: matchId, id: id, request: request)
        invalidateCache(matchId: matchId)
        return shooter
    }

    func deleteShooter(matchId: Int, id: Int) async throws {
        try await service.deleteShooter(matchId: matchId, id: id)
        invalidateCache(matchId: matchId)
    }

    func getDivisions(matchId: Int, forceRefresh: Bool = false) async throws -> [IpscDivision] {
        if !forceRefresh,
           let entry = divisionCache[matchId],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.divisions
        }

        let divisions = try await service.getDivisions(matchId: matchId)
        divisionCache[matchId] = (date: Date(), divisions: divisions)
        return divisions
    }

    func getSquads(matchId: Int, forceRefresh: Bool = false) async throws -> [IpscSquad] {
        if !forceRefresh,
           let entry = squadCache[matchId],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.squads
        }

        let squads = try await service.getSquads(matchId: matchId)
        squadCache[matchId] = (date: Date(), squads: squads)
        return squads
    }

    func getCategories(matchId: Int, forceRefresh: Bool = false) async throws -> [IpscCategory] {
        if !forceRefresh,
           let entry = categoryCache[matchId],
           Date().timeIntervalSince(entry.date) < cacheTTL {
            return entry.categories
        }

        let categories = try await service.getCategories(matchId: matchId)
        categoryCache[matchId] = (date: Date(), categories: categories)
        return categories
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
            divisionCache.removeValue(forKey: id)
            categoryCache.removeValue(forKey: id)
            shooterCache = shooterCache.filter { !$0.key.hasPrefix("\(id)-") }
        } else {
            cachedMatches = nil
            matchesCachedAt = nil
            squadCache.removeAll()
            stageCache.removeAll()
            shooterCache.removeAll()
            divisionCache.removeAll()
            categoryCache.removeAll()
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
