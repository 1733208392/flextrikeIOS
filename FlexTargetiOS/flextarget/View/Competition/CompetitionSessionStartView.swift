import SwiftUI
import CoreData

struct CompetitionSessionStartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var bleManager: BLEManager

    @StateObject private var viewModel = CompetitionSessionSetupViewModel()

    @State private var drillSetupForTimer: DrillSetup?
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    @State private var lockedContext: IpscLockedSelectionContext?

    @State private var navigateToTimerSession = false
    @State private var navigateToDrillSummary = false
    @State private var showStartError = false
    @State private var startErrorMessage = ""

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
                        onDrillComplete: { summaries in
                            DispatchQueue.main.async {
                                drillRepeatSummaries = summaries
                                navigateToTimerSession = false
                                navigateToDrillSummary = true
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

            NavigationLink(isActive: $navigateToDrillSummary) {
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
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadMatchesIfNeeded()
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
        viewModel.selectedContext != nil && bleManager.isConnected && !viewModel.isLoading
    }

    private var startButtonColor: Color {
        canStartDrill
            ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
            : Color.gray
    }

    private var selectionCard: some View {
        VStack(spacing: 12) {
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
                value: viewModel.selectedShooter?.name ?? NSLocalizedString("competition_session_select_shooter", comment: "Select shooter placeholder"),
                options: viewModel.availableShooters.map { .init(id: $0.id, title: "\($0.bibNumber) · \($0.name)") },
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
        guard let context = viewModel.selectedContext else {
            return
        }

        do {
            let drill = try createCompetitionDrill(in: viewContext, bleManager: bleManager, stageName: context.stageName)
            drillSetupForTimer = drill
            lockedContext = context
            navigateToTimerSession = true
        } catch {
            startErrorMessage = error.localizedDescription
            showStartError = true
        }
    }

    private func createCompetitionDrill(
        in context: NSManagedObjectContext,
        bleManager: BLEManager,
        stageName: String
    ) throws -> DrillSetup {
        let drill = DrillSetup(context: context)
        drill.id = UUID()
        drill.name = stageName.isEmpty ? "COMPETITION DRILL" : stageName
        drill.desc = ""
        drill.repeats = 1
        drill.pause = 5
        drill.drillDuration = 5.0
        drill.mode = "ipsc"

        let devices: [NetworkDevice] = {
            if !bleManager.networkDevices.isEmpty {
                return bleManager.networkDevices
            }
            if let connectedName = bleManager.connectedPeripheral?.name {
                return [NetworkDevice(name: connectedName, mode: "active")]
            }
            return [NetworkDevice(name: "01", mode: "active")]
        }()

        for (index, device) in devices.enumerated() {
            let target = DrillTargetsConfig(context: context)
            target.id = UUID()
            target.seqNo = Int32(index + 1)
            target.targetName = device.name
            target.targetType = DrillTargetsConfigData.encodeTargetTypes(["ipsc"])
            target.timeout = 30.0
            target.countedShots = 2
            target.action = "none"
            target.duration = 0.0
            target.targetVariant = "[]"
            target.hasPhysicalPopper = false
            drill.addToTargets(target)
        }

        try context.save()
        return drill
    }
}

private struct SelectionOption: Identifiable {
    let id: Int
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
            await loadStages(matchId: matchId, forceRefresh: true)
        }
    }

    func refreshSquads() {
        guard let matchId = selectedMatchId else { return }
        Task {
            await loadSquads(matchId: matchId, forceRefresh: true)
        }
    }

    func selectMatch(matchId: Int) {
        selectedMatchId = matchId
        selectedStageId = nil
        selectedSquadId = nil
        selectedShooterId = nil
        stages = []
        squads = []

        Task {
            await loadStages(matchId: matchId, forceRefresh: false)
            await loadSquads(matchId: matchId, forceRefresh: false)
        }
    }

    func selectStage(stageId: Int) {
        selectedStageId = stageId
    }

    func selectSquad(squadId: Int) {
        selectedSquadId = squadId
        selectedShooterId = nil
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
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadStages(matchId: Int, forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            stages = try await repository.getStages(matchId: matchId, forceRefresh: forceRefresh)
            if selectedStageId == nil {
                selectedStageId = stages.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadSquads(matchId: Int, forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            squads = try await repository.getSquadQueue(matchId: matchId, forceRefresh: forceRefresh)
            if let firstSquad = squads.first {
                selectedSquadId = firstSquad.id
                selectedShooterId = firstSquad.shooters.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationView {
        CompetitionSessionStartView()
            .environmentObject(BLEManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
