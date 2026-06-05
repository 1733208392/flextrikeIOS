import SwiftUI

struct ShooterMatchSelectorView: View {
    @State private var matches: [IpscMatch] = []
    @State private var is_loading = false
    @State private var error_message: String?

    var body: some View {
        Group {
            if is_loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("shooter_mgmt_loading_matches", comment: ""))
                        .foregroundColor(.gray)
                }
            } else if matches.isEmpty {
                ShooterEmptyStateView(
                    systemImage: "flag.fill",
                    title: NSLocalizedString("shooter_mgmt_no_matches_title", comment: ""),
                    message: NSLocalizedString("shooter_mgmt_no_matches_desc", comment: "")
                )
            } else {
                List(matches) { match in
                    NavigationLink(destination: ShooterListView(match_id: match.id)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(match.name)
                                .font(.headline)
                            Text(String(format: NSLocalizedString("shooter_mgmt_match_date", comment: ""), match.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(NSLocalizedString("shooter_mgmt_nav_title", comment: ""))
        .task {
            await load_matches()
        }
        .alert(NSLocalizedString("shooter_mgmt_load_failed_title", comment: ""), isPresented: Binding(get: {
            error_message != nil
        }, set: { visible in
            if !visible {
                error_message = nil
            }
        })) {
            Button(NSLocalizedString("retry", comment: "Retry")) {
                Task { await load_matches() }
            }
            Button(NSLocalizedString("ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(error_message ?? NSLocalizedString("shooter_mgmt_unknown_error", comment: ""))
        }
    }

    private func load_matches() async {
        is_loading = true
        defer { is_loading = false }

        do {
            matches = try await IpscRepository.shared.getMatches(forceRefresh: true)
            error_message = nil
        } catch {
            error_message = error.localizedDescription
        }
    }
}

struct ShooterListView: View {
    let match_id: Int

    @State private var shooters: [IpscShooter] = []
    @State private var squads: [IpscSquad] = []
    @State private var selected_squad_id: Int?
    @State private var search_text = ""
    @State private var is_loading = false
    @State private var error_message: String?
    @State private var shooter_to_delete: IpscShooter?
    @State private var show_add_form = false

    private var filtered_shooters: [IpscShooter] {
        let keyword = search_text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return shooters }
        return shooters.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        List {
            Section {
                Picker(NSLocalizedString("shooter_mgmt_squad_filter", comment: ""), selection: Binding(get: {
                    selected_squad_id ?? -1
                }, set: { new_value in
                    selected_squad_id = new_value == -1 ? nil : new_value
                    Task { await load_shooters(force_refresh: true) }
                })) {
                    Text(NSLocalizedString("shooter_mgmt_all_squads", comment: "")).tag(-1)
                    ForEach(squads) { squad in
                        Text(squad.name).tag(squad.id)
                    }
                }
            }

            if is_loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView(NSLocalizedString("shooter_mgmt_loading_shooters", comment: ""))
                        Spacer()
                    }
                }
            } else if filtered_shooters.isEmpty {
                Section {
                    ShooterEmptyStateView(
                        systemImage: "person.3.sequence.fill",
                        title: NSLocalizedString("shooter_mgmt_no_shooters_title", comment: ""),
                        message: emptyShooterMessage
                    )
                }
            } else {
                Section {
                    ForEach(filtered_shooters) { shooter in
                        NavigationLink(destination: ShooterDetailView(match_id: match_id, shooter_id: shooter.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(shooter.name ?? NSLocalizedString("shooter_mgmt_unnamed_shooter", comment: ""))
                                    .font(.headline)
                                Text(shooter.division_name ?? NSLocalizedString("shooter_mgmt_unset_division", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                                shooter_to_delete = shooter
                            }
                        }
                    }
                }
            }
        }
        .searchable(
            text: $search_text,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: NSLocalizedString("shooter_mgmt_search_name", comment: "")
        )
        .navigationTitle(NSLocalizedString("shooter_mgmt_nav_title", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    show_add_form = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await load_initial_data()
        }
        .refreshable {
            await load_shooters(force_refresh: true)
        }
        .sheet(isPresented: $show_add_form, onDismiss: {
            Task { await load_shooters(force_refresh: true) }
        }) {
            NavigationStack {
                ShooterFormView(match_id: match_id, mode: .create, shooter_id: nil)
            }
        }
        .alert(NSLocalizedString("shooter_mgmt_delete_title", comment: ""), isPresented: Binding(get: {
            shooter_to_delete != nil
        }, set: { visible in
            if !visible {
                shooter_to_delete = nil
            }
        })) {
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                Task { await confirm_delete() }
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("shooter_mgmt_delete_confirm_message", comment: ""))
        }
        .alert(NSLocalizedString("shooter_mgmt_operation_failed_title", comment: ""), isPresented: Binding(get: {
            error_message != nil
        }, set: { visible in
            if !visible {
                error_message = nil
            }
        })) {
            Button(NSLocalizedString("ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(error_message ?? NSLocalizedString("shooter_mgmt_unknown_error", comment: ""))
        }
    }

    private func load_initial_data() async {
        is_loading = true
        defer { is_loading = false }

        do {
            squads = try await IpscRepository.shared.getSquads(matchId: match_id, forceRefresh: true)
            await load_shooters(force_refresh: true)
            error_message = nil
        } catch {
            error_message = error.localizedDescription
        }
    }

    private func load_shooters(force_refresh: Bool) async {
        if !is_loading {
            is_loading = true
        }
        defer { is_loading = false }

        do {
            shooters = try await IpscRepository.shared.getShooters(
                matchId: match_id,
                squadId: selected_squad_id,
                forceRefresh: force_refresh
            )
            error_message = nil
        } catch {
            error_message = error.localizedDescription
        }
    }

    private func confirm_delete() async {
        guard let shooter_to_delete else { return }

        do {
            try await IpscRepository.shared.deleteShooter(matchId: match_id, id: shooter_to_delete.id)
            self.shooter_to_delete = nil
            await load_shooters(force_refresh: true)
        } catch {
            error_message = error.localizedDescription
        }
    }

    private var emptyShooterMessage: String {
        search_text.isEmpty
            ? NSLocalizedString("shooter_mgmt_no_shooters_desc", comment: "")
            : NSLocalizedString("shooter_mgmt_no_search_result_desc", comment: "")
    }
}

private struct ShooterEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
