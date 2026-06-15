import SwiftUI
import CoreData

struct CompetitionSessionStartView: View {
    @EnvironmentObject private var bleManager: BLEManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillSetup.name, ascending: true)],
        animation: .default
    ) private var drillSetups: FetchedResults<DrillSetup>

    @StateObject private var viewModel = CompetitionSessionSetupViewModel()

    @State private var selectedDrillId: UUID?
    @State private var drillSetupForTimer: DrillSetup?
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    @State private var lockedContext: IpscLockedSelectionContext?

    @State private var navigateToTimerSession = false
    @State private var navigateToCompetitionSummary = false
    @State private var showStartError = false
    @State private var startErrorMessage = ""

    private let selectedDrillCacheKey = "competition_session_selected_drill_id"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                selectionCard
                statusCard

                Button(action: startCompetitionDrill) {
                    Text(NSLocalizedString("start_competition_drill", comment: ""))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(startButtonColor)
                        .cornerRadius(10)
                }
                .disabled(!canStartDrill)

                Spacer()
            }
            .padding()

            NavigationLink(isActive: $navigateToTimerSession) {
                if let drill = drillSetupForTimer {
                    TimerSessionView(
                        drillSetup: drill,
                        bleManager: bleManager,
                        competition: nil,
                        athlete: nil,
                        isCompetitionSession: true,
                        onDrillComplete: { summaries in
                            DispatchQueue.main.async {
                                drillRepeatSummaries = summaries
                                navigateToTimerSession = false
                                navigateToCompetitionSummary = true
                            }
                        },
                        onDrillFailed: {
                            DispatchQueue.main.async {
                                navigateToTimerSession = false
                                startErrorMessage = NSLocalizedString("ack_timeout_message", comment: "")
                                showStartError = true
                            }
                        }
                    )
                }
            } label: {
                EmptyView()
            }

            NavigationLink(isActive: $navigateToCompetitionSummary) {
                if let drill = drillSetupForTimer {
                    DrillSummaryView(
                        drillSetup: drill,
                        summaries: drillRepeatSummaries,
                        competition: nil,
                        ipscContext: lockedContext
                    )
                }
            } label: {
                EmptyView()
            }
        }
        .navigationTitle(NSLocalizedString("competition", comment: "Competition tab"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadMatchesIfNeeded()
            restoreCachedDrillSelection()
        }
        .onChange(of: drillSetups.count) { _ in
            validateSelectedDrill()
        }
        .onChange(of: selectedDrillId) { id in
            guard let id else {
                UserDefaults.standard.removeObject(forKey: selectedDrillCacheKey)
                return
            }
            UserDefaults.standard.set(id.uuidString, forKey: selectedDrillCacheKey)
        }
        .alert(isPresented: $showStartError) {
            Alert(
                title: Text(NSLocalizedString("error_title", comment: "")),
                message: Text(startErrorMessage),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button")))
            )
        }
    }

    private var canStartDrill: Bool {
        viewModel.selectedContext != nil
            && selectedDrill != nil
            && bleManager.isConnected
            && !viewModel.isLoading
    }

    private var startButtonColor: Color {
        canStartDrill
            ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
            : Color.gray
    }

    private var selectionCard: some View {
        VStack(spacing: 12) {
            drillSelectionRow(
                title: NSLocalizedString("competition_session_drill", comment: "Drill selector title"),
                value: selectedDrill?.name ?? NSLocalizedString("competition_session_select_drill", comment: "Select drill placeholder"),
                options: drillOptions,
                onSelect: { selectedDrillId = $0 }
            )

            selectionRow(
                title: NSLocalizedString("competition_session_match", comment: "Match selector title"),
                value: viewModel.selectedMatch?.name ?? NSLocalizedString("competition_session_select_match", comment: "Select match placeholder"),
                options: viewModel.matches.map { .init(id: $0.id, title: $0.name) },
                onSelect: { viewModel.selectMatch(matchId: $0) }
            )

            selectionRow(
                title: NSLocalizedString("competition_session_stage", comment: "Stage selector title"),
                value: viewModel.selectedStage?.name ?? NSLocalizedString("competition_session_select_stage", comment: "Select stage placeholder"),
                options: viewModel.stages.map { .init(id: $0.id, title: $0.name) },
                onSelect: { viewModel.selectStage(stageId: $0) },
                disabled: viewModel.selectedMatch == nil
            )

            selectionRow(
                title: NSLocalizedString("competition_session_squad", comment: "Squad selector title"),
                value: viewModel.selectedSquad?.name ?? NSLocalizedString("competition_session_select_squad", comment: "Select squad placeholder"),
                options: viewModel.squads.map { .init(id: $0.id, title: $0.name) },
                onSelect: { viewModel.selectSquad(squadId: $0) },
                disabled: viewModel.selectedMatch == nil
            )

            selectionRow(
                title: NSLocalizedString("competition_session_shooter", comment: "Shooter selector title"),
                value: viewModel.selectedShooter.map { shooterLabel($0, includeBib: false) }
                    ?? NSLocalizedString("competition_session_select_shooter", comment: "Select shooter placeholder"),
                options: viewModel.availableShooters.map { .init(id: $0.id, title: shooterLabel($0, includeBib: true)) },
                onSelect: { viewModel.selectShooter(shooterId: $0) },
                disabled: viewModel.selectedSquad == nil
            )

            if !viewModel.isLoading {
                if viewModel.matches.isEmpty {
                    inlineEmptyState(
                        text: NSLocalizedString("competition_session_no_matches", comment: "No matches empty state"),
                        buttonTitle: NSLocalizedString("competition_session_retry_matches", comment: "Retry matches"),
                        action: { viewModel.refreshMatches() }
                    )
                } else if viewModel.selectedMatch != nil && viewModel.stages.isEmpty {
                    inlineEmptyState(
                        text: NSLocalizedString("competition_session_no_stages", comment: "No stages empty state"),
                        buttonTitle: NSLocalizedString("competition_session_retry_stages", comment: "Retry stages"),
                        action: { viewModel.refreshStages() }
                    )
                } else if viewModel.selectedMatch != nil && viewModel.squads.isEmpty {
                    inlineEmptyState(
                        text: NSLocalizedString("competition_session_no_squads", comment: "No squads empty state"),
                        buttonTitle: NSLocalizedString("competition_session_retry_squads", comment: "Retry squads"),
                        action: { viewModel.refreshSquads() }
                    )
                } else if viewModel.selectedSquad != nil && viewModel.availableShooters.isEmpty {
                    inlineEmptyState(
                        text: NSLocalizedString("competition_session_no_shooters", comment: "No shooters in squad empty state"),
                        buttonTitle: NSLocalizedString("competition_session_retry_squad_queue", comment: "Retry squad queue"),
                        action: { viewModel.refreshSquads() }
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private var drillOptions: [DrillSelectionOption] {
        drillSetups.compactMap { drill in
            guard let id = drill.id, let name = drill.name, !name.isEmpty else {
                return nil
            }
            return DrillSelectionOption(id: id, title: name)
        }
    }

    private var selectedDrill: DrillSetup? {
        guard let selectedDrillId else { return nil }
        return drillSetups.first(where: { $0.id == selectedDrillId })
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(NSLocalizedString("competition_session_loading", comment: "Loading competition setup data"))
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            } else if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .foregroundColor(.orange)
                        .font(.caption)

                    HStack(spacing: 8) {
                        retryPill(title: NSLocalizedString("competition_session_retry_matches_short", comment: "Retry matches short label"), action: { viewModel.refreshMatches() })
                        if viewModel.selectedMatch != nil {
                            retryPill(title: NSLocalizedString("competition_session_retry_stages_short", comment: "Retry stages short label"), action: { viewModel.refreshStages() })
                            retryPill(title: NSLocalizedString("competition_session_retry_squads_short", comment: "Retry squads short label"), action: { viewModel.refreshSquads() })
                        }
                    }
                }
            } else {
                Text(bleManager.isConnected
                    ? NSLocalizedString("competition_session_ble_connected_hint", comment: "BLE connected hint")
                    : NSLocalizedString("competition_session_ble_disconnected_hint", comment: "BLE disconnected hint"))
                    .foregroundColor(bleManager.isConnected ? .gray : .orange)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func selectionRow(
        title: String,
        value: String,
        options: [SelectionOption],
        onSelect: @escaping (Int) -> Void,
        disabled: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 84, alignment: .leading)

            Menu {
                ForEach(options) { option in
                    Button(option.title) {
                        onSelect(option.id)
                    }
                }
            } label: {
                HStack {
                    Text(value)
                        .foregroundColor(disabled ? .gray : .white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .disabled(disabled || options.isEmpty)
        }
    }

    private func drillSelectionRow(
        title: String,
        value: String,
        options: [DrillSelectionOption],
        onSelect: @escaping (UUID) -> Void,
        disabled: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 84, alignment: .leading)

            Menu {
                ForEach(options) { option in
                    Button(option.title) {
                        onSelect(option.id)
                    }
                }
            } label: {
                HStack {
                    Text(value)
                        .foregroundColor(disabled ? .gray : .white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .disabled(disabled || options.isEmpty)
        }
    }

    private func inlineEmptyState(text: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(text)
                .foregroundColor(.orange)
                .font(.caption)

            Spacer()

            Button(buttonTitle, action: action)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.14))
                .cornerRadius(8)
        }
        .padding(.horizontal, 2)
    }

    private func retryPill(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(format: NSLocalizedString("competition_session_retry_format", comment: "Retry %s format"), title))
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.14))
                .cornerRadius(8)
        }
    }

    private func startCompetitionDrill() {
        guard let context = viewModel.selectedContext,
              let drill = selectedDrill else {
            return
        }

        drillSetupForTimer = drill
        lockedContext = context
        navigateToTimerSession = true
    }

    private func shooterLabel(_ shooter: IpscShooter, includeBib: Bool) -> String {
        var parts: [String] = []
        if includeBib {
            parts.append(shooter.bibNumber)
        }
        parts.append(shooter.name ?? NSLocalizedString("unknown_athlete", comment: ""))

        var metadata: [String] = []
        if !shooter.divisionName.isEmpty {
            metadata.append(shooter.divisionName)
        }
        if let category = shooter.categoryName, !category.isEmpty {
            metadata.append(category)
        }

        if !metadata.isEmpty {
            parts.append(metadata.joined(separator: " / "))
        }

        return parts.joined(separator: " · ")
    }

    private func restoreCachedDrillSelection() {
        guard selectedDrillId == nil else { return }

        let cachedId = UserDefaults.standard.string(forKey: selectedDrillCacheKey)
            .flatMap(UUID.init(uuidString:))
        if let cachedId,
           drillSetups.contains(where: { $0.id == cachedId }) {
            selectedDrillId = cachedId
            return
        }

        selectedDrillId = drillSetups.first?.id
    }

    private func validateSelectedDrill() {
        if selectedDrillId == nil {
            restoreCachedDrillSelection()
            return
        }

        guard let selectedDrillId,
              drillSetups.contains(where: { $0.id == selectedDrillId }) else {
            self.selectedDrillId = drillSetups.first?.id
            return
        }
    }
}

private struct CompetitionTargetRowState: Identifiable {
    let id: String
    let rowNo: Int
    let label: String
    let targetType: String
    var a: Int
    var c: Int
    var d: Int
    var m: Int
    var ns: Int
    var npm: Int
}

private enum CompetitionTargetColumn {
    case a
    case c
    case d
    case m
    case ns
    case npm
}

struct CompetitionTargetGridSummaryView: View {
    let drillSetup: DrillSetup
    let competition: Competition?
    let ipscContext: IpscLockedSelectionContext?
    let competitionSquadId: Int?

    @State private var workingSummaries: [DrillRepeatSummary]
    @State private var rows: [CompetitionTargetRowState]
    @State private var additionalPenalties: Int
    @State private var navigateToDetailedSummary = false

    @Environment(\.dismiss) private var dismiss

    init(
        drillSetup: DrillSetup,
        summaries: [DrillRepeatSummary],
        competition: Competition?,
        ipscContext: IpscLockedSelectionContext?,
        competitionSquadId: Int? = nil
    ) {
        self.drillSetup = drillSetup
        self.competition = competition
        self.ipscContext = ipscContext
        self.competitionSquadId = competitionSquadId

        let baseSummary = summaries.first
        let initialRows = CompetitionTargetGridSummaryView.buildRows(
            drillSetup: drillSetup,
            summary: baseSummary
        )
        let initialAdditionalPenalties: Int = {
            let totalPE = baseSummary?.adjustedHitZones?["PE"] ?? 0
            let npms = initialRows.reduce(0) { $0 + $1.npm }
            return max(0, totalPE - npms)
        }()

        _workingSummaries = State(initialValue: summaries)
        _rows = State(initialValue: initialRows)
        _additionalPenalties = State(initialValue: initialAdditionalPenalties)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                topBar
                contextHeader
                tableHeader

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            rowView(row: row, index: idx)
                        }
                    }
                }

                additionalPenaltyRow
                totalsRow

                HStack(spacing: 12) {
                    Button(action: {
                        rows = rows.map { row in
                            var updated = row
                            updated.a = 0
                            updated.c = 0
                            updated.d = 0
                            updated.m = 0
                            updated.ns = 0
                            updated.npm = 0
                            return updated
                        }
                        additionalPenalties = 0
                        workingSummaries = buildDnfSummaries()
                        navigateToDetailedSummary = true
                    }) {
                        Text("DNF/0.0")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.2, green: 0.35, blue: 0.9))
                            .cornerRadius(10)
                    }

                    Button(action: { navigateToDetailedSummary = true }) {
                        Text("Review")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .cornerRadius(10)
                    }
                }

                NavigationLink(isActive: $navigateToDetailedSummary) {
                    DrillSummaryView(
                        drillSetup: drillSetup,
                        summaries: workingSummaries,
                        competition: competition,
                        ipscContext: ipscContext,
                        competitionSquadId: competitionSquadId
                    )
                } label: {
                    EmptyView()
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            applyEditsToSummary()
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .padding(8)
            }

            Spacer()

            Text("Competition Summary")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
    }

    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ipscContext?.shooter.name ?? NSLocalizedString("unknown_athlete", comment: ""))
                .font(.title2)
                .foregroundColor(.white)

            Text(ipscContext?.stageName ?? "-")
                .font(.title3)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableHeader: some View {
        HStack(spacing: 6) {
            Text("T#")
                .foregroundColor(.gray)
                .frame(width: 48, alignment: .leading)
            Text("A").headerCell()
            Text("C").headerCell()
            Text("D").headerCell()
            Text("M").headerCell()
            Text("NS").headerCell()
            Text("NPM").headerCell()
        }
    }

    private func rowView(row: CompetitionTargetRowState, index: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(row.rowNo)")
                .foregroundColor(.gray)
                .frame(width: 48, alignment: .leading)

            editableCell(value: row.a, column: .a, rowIndex: index)
            editableCell(value: row.c, column: .c, rowIndex: index)
            editableCell(value: row.d, column: .d, rowIndex: index)
            editableCell(value: row.m, column: .m, rowIndex: index)
            editableCell(value: row.ns, column: .ns, rowIndex: index)
            editableCell(value: row.npm, column: .npm, rowIndex: index)
        }
    }

    private func editableCell(value: Int, column: CompetitionTargetColumn, rowIndex: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(width: 44, height: 42)
            .background(value > 0 ? Color.green : Color.red.opacity(0.85))
            .cornerRadius(6)
            .onTapGesture {
                updateCell(rowIndex: rowIndex, column: column, reset: false)
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                updateCell(rowIndex: rowIndex, column: column, reset: true)
            }
    }

    private var additionalPenaltyRow: some View {
        HStack {
            Text("Additional Penalties")
                .foregroundColor(.gray)
            Spacer()
            Text("\(additionalPenalties)")
                .foregroundColor(.white)
                .frame(minWidth: 24)
            Button(action: {
                additionalPenalties = max(0, additionalPenalties - 1)
                applyEditsToSummary()
            }) {
                Text("−")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.35, blue: 0.9))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            Button(action: {
                additionalPenalties += 1
                applyEditsToSummary()
            }) {
                Text("+")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.35, blue: 0.9))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }

    private var totalsRow: some View {
        let totals = aggregateZones()
        let score = ScoringUtility.calculateScoreFromAdjustedHitZones(totals, drillSetup: drillSetup)

        return HStack {
            Text("Score")
                .foregroundColor(.gray)
            Spacer()
            Text("\(score)")
                .foregroundColor(.white)
                .font(.headline)
        }
    }

    private func updateCell(rowIndex: Int, column: CompetitionTargetColumn, reset: Bool) {
        guard rows.indices.contains(rowIndex) else { return }

        switch column {
        case .a:
            rows[rowIndex].a = reset ? 0 : rows[rowIndex].a + 1
        case .c:
            rows[rowIndex].c = reset ? 0 : rows[rowIndex].c + 1
        case .d:
            rows[rowIndex].d = reset ? 0 : rows[rowIndex].d + 1
        case .m:
            rows[rowIndex].m = reset ? 0 : rows[rowIndex].m + 1
        case .ns:
            rows[rowIndex].ns = reset ? 0 : rows[rowIndex].ns + 1
        case .npm:
            rows[rowIndex].npm = reset ? 0 : rows[rowIndex].npm + 1
        }

        applyEditsToSummary()
    }

    private func aggregateZones() -> [String: Int] {
        let totalA = rows.reduce(0) { $0 + $1.a }
        let totalC = rows.reduce(0) { $0 + $1.c }
        let totalD = rows.reduce(0) { $0 + $1.d }
        let totalM = rows.reduce(0) { $0 + $1.m }
        let totalNS = rows.reduce(0) { $0 + $1.ns }
        let totalNPM = rows.reduce(0) { $0 + $1.npm }

        return [
            "A": totalA,
            "C": totalC,
            "D": totalD,
            "M": totalM,
            "N": totalNS,
            "PE": totalNPM + additionalPenalties
        ]
    }

    private func applyEditsToSummary() {
        guard workingSummaries.isEmpty == false else { return }

        let zones = aggregateZones()
        workingSummaries[0].adjustedHitZones = zones
        workingSummaries[0].score = ScoringUtility.calculateScoreFromAdjustedHitZones(zones, drillSetup: drillSetup)
    }

    private func buildDnfSummaries() -> [DrillRepeatSummary] {
        let zeroZones = ["A": 0, "C": 0, "D": 0, "M": 0, "N": 0, "PE": 0]
        return workingSummaries.enumerated().map { idx, summary in
            var updated = summary
            updated.adjustedHitZones = zeroZones
            updated.score = 0
            if idx == 0 {
                updated.score = 0
            }
            return updated
        }
    }

    private static func buildRows(drillSetup: DrillSetup, summary: DrillRepeatSummary?) -> [CompetitionTargetRowState] {
        let targets = ((drillSetup.targets as? Set<DrillTargetsConfig>) ?? []).sorted { lhs, rhs in
            if lhs.seqNo == rhs.seqNo {
                return (lhs.targetName ?? "") < (rhs.targetName ?? "")
            }
            return lhs.seqNo < rhs.seqNo
        }

        let shots = summary?.shots ?? []
        var groupedShots: [String: [ShotData]] = [:]
        for shot in shots {
            let key = ScoringUtility.normalizedTargetKey(for: shot)
            groupedShots[key, default: []].append(shot)
        }

        // Expand each configured target into 1 or more display rows.
        // ipsc_mini_double has 2 panels (P0/P1) each treated as an independent paper target.
        struct ExpandedTarget {
            let target: DrillTargetsConfig
            let panel: String?     // "P0" / "P1" / nil
            let key: String        // grouping key matching ScoringUtility.normalizedTargetKey
            let rowSuffix: String  // appended to label for the panel row
        }

        var expanded: [ExpandedTarget] = []
        for target in targets {
            let name = target.targetName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let type = target.primaryTargetType().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if type == "ipsc_mini_double" {
                expanded.append(ExpandedTarget(target: target, panel: "P0", key: "\(name)+p0|\(type)", rowSuffix: " (P0)"))
                expanded.append(ExpandedTarget(target: target, panel: "P1", key: "\(name)+p1|\(type)", rowSuffix: " (P1)"))
            } else {
                expanded.append(ExpandedTarget(target: target, panel: nil, key: "\(name)|\(type)", rowSuffix: ""))
            }
        }

        return expanded.enumerated().map { idx, entry in
            let target = entry.target
            let type = target.primaryTargetType().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rowShots = groupedShots[entry.key] ?? []

            var a = 0
            var c = 0
            var d = 0
            var m = 0
            var ns = 0

            // For paper targets (incl. each ipsc_mini_double panel) credit best 2 hits;
            // any deficit becomes Ms. This mirrors ScoringUtility paper-target rules so
            // the per-panel row totals align with overall scoring.
            let isPaddleOrPopper = type.contains("paddle") || type.contains("popper")

            let nsShots = rowShots.filter { ScoringUtility.normalizeHitArea($0.content.hitArea) == "whitezone" }
            let otherShots = rowShots.filter { ScoringUtility.normalizeHitArea($0.content.hitArea) != "whitezone" }
            ns += nsShots.count

            let validHits = otherShots.filter { ScoringUtility.scoreForHitArea(ScoringUtility.normalizeHitArea($0.content.hitArea)) > 0 }

            if isPaddleOrPopper {
                let deficit = max(0, 1 - validHits.count)
                m += deficit
                for shot in validHits {
                    let area = ScoringUtility.normalizeHitArea(shot.content.hitArea)
                    switch area {
                    case "azone", "a", "circlearea", "popperzone", "apopper": a += 1
                    case "czone", "c": c += 1
                    case "dzone", "d": d += 1
                    default: break
                    }
                }
            } else {
                let deficit = max(0, 2 - validHits.count)
                m += deficit
                let sorted = validHits.sorted {
                    ScoringUtility.scoreForHitArea($0.content.hitArea) > ScoringUtility.scoreForHitArea($1.content.hitArea)
                }
                for shot in sorted.prefix(2) {
                    let area = ScoringUtility.normalizeHitArea(shot.content.hitArea)
                    switch area {
                    case "azone", "a": a += 1
                    case "czone", "c": c += 1
                    case "dzone", "d": d += 1
                    default: break
                    }
                }
            }

            let baseSeq = Int(target.seqNo) > 0 ? Int(target.seqNo) : idx + 1
            return CompetitionTargetRowState(
                id: entry.key,
                rowNo: baseSeq,
                label: (target.targetName ?? "T\(idx + 1)") + entry.rowSuffix,
                targetType: type,
                a: a,
                c: c,
                d: d,
                m: m,
                ns: ns,
                npm: 0
            )
        }
    }
}

private extension Text {
    func headerCell() -> some View {
        self
            .foregroundColor(.gray)
            .frame(width: 44)
    }
}

private struct SelectionOption: Identifiable {
    let id: Int
    let title: String
}

private struct DrillSelectionOption: Identifiable {
    let id: UUID
    let title: String
}

@MainActor
final class CompetitionSessionSetupViewModel: ObservableObject {
    @Published private(set) var matches: [IpscMatch] = []
    @Published private(set) var stages: [IpscStage] = []
    @Published private(set) var squads: [IpscSquad] = []

    @Published var selectedMatchId: Int?
    @Published var selectedStageId: Int?
    @Published var selectedSquadId: Int?
    @Published var selectedShooterId: Int?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository = IpscRepository.shared
    private let defaults = UserDefaults.standard
    private var hasAttemptedRestore = false

    private let selectedMatchIdKey = "competition_session_selected_match_id"
    private let selectedStageIdKey = "competition_session_selected_stage_id"
    private let selectedSquadIdKey = "competition_session_selected_squad_id"

    var selectedMatch: IpscMatch? {
        guard let selectedMatchId else { return nil }
        return matches.first(where: { $0.id == selectedMatchId })
    }

    var selectedStage: IpscStage? {
        guard let selectedStageId else { return nil }
        return stages.first(where: { $0.id == selectedStageId })
    }

    var selectedSquad: IpscSquad? {
        guard let selectedSquadId else { return nil }
        return squads.first(where: { $0.id == selectedSquadId })
    }

    var availableShooters: [IpscShooter] {
        selectedSquad?.shooters ?? []
    }

    var selectedShooter: IpscShooter? {
        guard let selectedShooterId else { return nil }
        return availableShooters.first(where: { $0.id == selectedShooterId })
    }

    var selectedContext: IpscLockedSelectionContext? {
        guard let match = selectedMatch,
              let stage = selectedStage,
              let squad = selectedSquad,
              let shooter = selectedShooter else {
            return nil
        }

        return IpscLockedSelectionContext(
            matchId: match.id,
            matchName: match.name,
            stageId: stage.id,
            stageName: stage.name,
            squadId: squad.id,
            squadName: squad.name,
            shooter: shooter
        )
    }

    func loadMatchesIfNeeded() {
        guard matches.isEmpty else { return }
        loadMatches(forceRefresh: false)
    }

    func refreshMatches() {
        loadMatches(forceRefresh: true)
    }

    func refreshStages() {
        guard let matchId = selectedMatchId else { return }
        Task {
            await loadStages(matchId: matchId, forceRefresh: true, preferredStageId: nil)
        }
    }

    func refreshSquads() {
        guard let matchId = selectedMatchId else { return }
        Task {
            await loadSquads(matchId: matchId, forceRefresh: true, preferredSquadId: nil)
        }
    }

    func selectMatch(matchId: Int) {
        selectMatch(
            matchId: matchId,
            preferredStageId: nil,
            preferredSquadId: nil,
            shouldResetCachedChildren: true
        )
    }

    private func selectMatch(
        matchId: Int,
        preferredStageId: Int?,
        preferredSquadId: Int?,
        shouldResetCachedChildren: Bool
    ) {
        defaults.set(matchId, forKey: selectedMatchIdKey)
        if shouldResetCachedChildren {
            defaults.removeObject(forKey: selectedStageIdKey)
            defaults.removeObject(forKey: selectedSquadIdKey)
        }

        selectedMatchId = matchId
        selectedStageId = nil
        selectedSquadId = nil
        selectedShooterId = nil
        stages = []
        squads = []

        Task {
            await loadStages(matchId: matchId, forceRefresh: false, preferredStageId: preferredStageId)
            await loadSquads(matchId: matchId, forceRefresh: false, preferredSquadId: preferredSquadId)
        }
    }

    func selectStage(stageId: Int) {
        selectedStageId = stageId
        defaults.set(stageId, forKey: selectedStageIdKey)
    }

    func selectSquad(squadId: Int) {
        selectedSquadId = squadId
        selectedShooterId = nil
        defaults.set(squadId, forKey: selectedSquadIdKey)
    }

    func selectShooter(shooterId: Int) {
        selectedShooterId = shooterId
    }

    private func loadMatches(forceRefresh: Bool) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                matches = try await repository.getMatches(forceRefresh: forceRefresh)
                restoreCachedMatchSelectionIfNeeded()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadStages(matchId: Int, forceRefresh: Bool, preferredStageId: Int?) async {
        isLoading = true
        errorMessage = nil

        do {
            stages = try await repository.getStages(matchId: matchId, forceRefresh: forceRefresh)
            if let preferredStageId,
               stages.contains(where: { $0.id == preferredStageId }) {
                selectedStageId = preferredStageId
            } else if let cachedStageId = defaults.object(forKey: selectedStageIdKey) as? Int,
                        stages.contains(where: { $0.id == cachedStageId }) {
                selectedStageId = cachedStageId
            } else {
                selectedStageId = stages.first?.id
            }

            if let selectedStageId {
                defaults.set(selectedStageId, forKey: selectedStageIdKey)
            } else {
                defaults.removeObject(forKey: selectedStageIdKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadSquads(matchId: Int, forceRefresh: Bool, preferredSquadId: Int?) async {
        isLoading = true
        errorMessage = nil

        do {
            squads = try await repository.getSquadQueue(matchId: matchId, forceRefresh: forceRefresh)
            if let preferredSquadId,
               squads.contains(where: { $0.id == preferredSquadId }) {
                selectedSquadId = preferredSquadId
            } else if let cachedSquadId = defaults.object(forKey: selectedSquadIdKey) as? Int,
                        squads.contains(where: { $0.id == cachedSquadId }) {
                selectedSquadId = cachedSquadId
            } else {
                selectedSquadId = squads.first?.id
            }
            selectedShooterId = nil

            if let selectedSquadId {
                defaults.set(selectedSquadId, forKey: selectedSquadIdKey)
            } else {
                defaults.removeObject(forKey: selectedSquadIdKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func restoreCachedMatchSelectionIfNeeded() {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true

        guard let cachedMatchId = defaults.object(forKey: selectedMatchIdKey) as? Int,
              matches.contains(where: { $0.id == cachedMatchId }) else {
            return
        }

        let cachedStageId = defaults.object(forKey: selectedStageIdKey) as? Int
        let cachedSquadId = defaults.object(forKey: selectedSquadIdKey) as? Int
        selectMatch(
            matchId: cachedMatchId,
            preferredStageId: cachedStageId,
            preferredSquadId: cachedSquadId,
            shouldResetCachedChildren: false
        )
    }
}

#Preview {
    NavigationView {
        CompetitionSessionStartView()
            .environmentObject(BLEManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
