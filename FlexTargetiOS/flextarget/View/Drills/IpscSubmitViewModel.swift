import Foundation
import Combine

// MARK: - Step

enum IpscSubmitStep: Equatable {
    case idle
    case confirm(context: IpscLockedSelectionContext)
    case submitting
    case success(hitFactor: Double, totalPoints: Int)
    case error(message: String)

    static func == (lhs: IpscSubmitStep, rhs: IpscSubmitStep) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.submitting, .submitting):
            return true
        case (.confirm(let a), .confirm(let b)):
            return a.matchId == b.matchId && a.stageId == b.stageId && a.squadId == b.squadId && a.shooter.id == b.shooter.id
        case (.success(let a, let b), .success(let c, let d)):
            return a == c && b == d
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
final class IpscSubmitViewModel: ObservableObject {

    @Published private(set) var step: IpscSubmitStep = .idle

    private let repository = IpscRepository.shared

    // Summaries provided at the call site (the current drill result)
    var summaries: [DrillRepeatSummary] = []
    var lockedContext: IpscLockedSelectionContext?

    /// Caller-provided row grid (e.g. from the on-screen IPSC editor in
    /// `DrillSummaryView`). When set, this is sent verbatim to the backend so
    /// the payload always carries one row per expected target — including
    /// unengaged targets that default to M=2 — even when no shots were fired.
    var prebuiltRows: [IpscScoreTargetRow]?

    // MARK: - Navigation

    func start() {
        if let lockedContext {
            step = .confirm(context: lockedContext)
            return
        }
        step = .error(message: "Competition context missing. Please start from Competition Session.")
    }

    func dismiss() {
        step = .idle
    }

    func back() {
        switch step {
        case .confirm(let context):
            _ = context
            step = .idle
        case .error:
            step = .idle
        default:
            step = .idle
        }
    }

    /// Build and submit the score.
    func submit(context: IpscLockedSelectionContext, summary: DrillRepeatSummary, isDq: Bool = false) {
        let hitZones = summary.adjustedHitZones
            ?? ScoringUtility.calculateEffectiveCounts(shots: summary.shots, drillSetup: nil)

        let request = IpscScoreSubmitRequest(
            shooterBib: context.shooter.bibNumber,
            stageId: String(context.stageId),
            totalTime: summary.totalTime,
            status: isDq ? .dq : .normal,
            hits: IpscScoreHits(
                A: hitZones["A"] ?? 0,
                C: hitZones["C"] ?? 0,
                D: hitZones["D"] ?? 0,
                M: hitZones["M"] ?? 0,
                N: hitZones["N"] ?? 0
            ),
            rows: prebuiltRows ?? buildRows(from: summary),
            penalties: IpscScorePenalties(PE: hitZones["PE"] ?? 0),
            firstShot: summary.firstShot > 0 ? summary.firstShot : nil,
            fastestSplit: summary.fastest > 0 ? summary.fastest : nil
        )

        step = .submitting
        Task {
            do {
                let data = try await repository.submitScore(matchId: context.matchId, request: request)
                step = .success(hitFactor: data.hitFactor, totalPoints: data.totalPoints)
            } catch {
                if error is DecodingError {
                    step = .error(message: "Server returned incomplete score data. Please retry.")
                } else {
                    step = .error(message: error.localizedDescription)
                }
            }
        }
    }

    private func buildRows(from summary: DrillRepeatSummary) -> [IpscScoreTargetRow]? {
        struct RowAccumulator {
            let rowType: String
            let key: String
            var a: Int = 0
            var c: Int = 0
            var d: Int = 0
            var m: Int = 0
            var n: Int = 0
        }

        var grouped: [String: RowAccumulator] = [:]

        for shot in summary.shots {
            let targetType = shot.content.targetType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rawHitArea = shot.content.hitArea
            let isAPopper = isAPopperHitArea(rawHitArea)
            let rowType = (isAPopper || targetType.contains("steel") || targetType.contains("popper") || targetType.contains("paddle")) ? "steel" : "paper"
            let targetName = (shot.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? shot.target!.trimmingCharacters(in: .whitespacesAndNewlines)
                : (shot.content.device?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? shot.content.device!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : (shot.device?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? shot.device!.trimmingCharacters(in: .whitespacesAndNewlines)
                        : "target"))

            let keyTargetType = isAPopper ? "apopper" : targetType
            let key = "\(rowType)|\(targetName.lowercased())|\(keyTargetType)"
            var row = grouped[key] ?? RowAccumulator(rowType: rowType, key: key)

            switch normalizeHitArea(rawHitArea) {
            case "a": row.a += 1
            case "c": row.c += 1
            case "d": row.d += 1
            case "m": row.m += 1
            case "n": row.n += 1
            default: break
            }

            grouped[key] = row
        }

        if grouped.isEmpty {
            return nil
        }

        let steelRows = grouped.values
            .filter { $0.rowType == "steel" }
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { index, row in
                IpscScoreTargetRow(
                    rowType: "steel",
                    rowNo: index + 1,
                    A: row.a,
                    C: row.c,
                    D: row.d,
                    M: row.m,
                    N: row.n
                )
            }

        let paperRows = grouped.values
            .filter { $0.rowType == "paper" }
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { index, row in
                IpscScoreTargetRow(
                    rowType: "paper",
                    rowNo: index + 1,
                    A: row.a,
                    C: row.c,
                    D: row.d,
                    M: row.m,
                    N: row.n
                )
            }

        return steelRows + paperRows
    }

    private func isAPopperHitArea(_ raw: String) -> Bool {
        return ScoringUtility.normalizeHitArea(raw) == "apopper"
    }

    private func normalizeHitArea(_ raw: String) -> String {
        switch ScoringUtility.normalizeHitArea(raw) {
        case "azone", "circlearea", "popperzone", "apopper":
            return "a"
        case "czone":
            return "c"
        case "dzone":
            return "d"
        case "whitezone":
            return "n"
        case "miss":
            return "m"
        case "n", "ns", "no_shoot", "no-shoot", "noshoot":
            return "n"
        default:
            return "unknown"
        }
    }
}
