import SwiftUI

struct ShooterDetailView: View {
    let match_id: Int
    let shooter_id: Int

    @State private var shooter: IpscShooter?
    @State private var is_loading = false
    @State private var error_message: String?
    @State private var show_edit_form = false

    var body: some View {
        Group {
            if is_loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("shooter_mgmt_loading_shooter_detail", comment: ""))
                        .foregroundColor(.gray)
                }
            } else if let shooter {
                Form {
                    Section(NSLocalizedString("shooter_mgmt_section_basic", comment: "")) {
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_name", comment: ""), value: shooter.name)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_gender", comment: ""), value: gender_label(shooter.gender))
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_age", comment: ""), value: shooter.age.map(String.init))
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_division", comment: ""), value: shooter.division_name)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_category", comment: ""), value: shooter.category_code)
                    }

                    Section(NSLocalizedString("shooter_mgmt_section_grouping", comment: "")) {
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_squad", comment: ""), value: shooter.squad_name)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_region", comment: ""), value: shooter.region)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_club", comment: ""), value: shooter.club)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_club_id", comment: ""), value: shooter.club_id.map(String.init))
                    }

                    Section(NSLocalizedString("shooter_mgmt_section_system", comment: "")) {
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_shooter_uid", comment: ""), value: shooter.shooter_uid)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_status", comment: ""), value: shooter.status)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_dq", comment: ""), value: shooter.is_dq == 1 ? NSLocalizedString("shooter_mgmt_yes", comment: "") : NSLocalizedString("shooter_mgmt_no", comment: ""))
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_created_at", comment: ""), value: shooter.created_at)
                        detail_row(title: NSLocalizedString("shooter_mgmt_field_updated_at", comment: ""), value: shooter.updated_at)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("shooter_mgmt_not_found_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("shooter_mgmt_not_found_desc", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle(NSLocalizedString("shooter_mgmt_detail_nav_title", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("shooter_mgmt_edit", comment: "")) {
                    show_edit_form = true
                }
                .disabled(shooter == nil)
            }
        }
        .task {
            await load_shooter()
        }
        .sheet(isPresented: $show_edit_form, onDismiss: {
            Task { await load_shooter() }
        }) {
            NavigationStack {
                ShooterFormView(match_id: match_id, mode: .edit, shooter_id: shooter_id)
            }
        }
        .alert(NSLocalizedString("shooter_mgmt_load_failed_title", comment: ""), isPresented: Binding(get: {
            error_message != nil
        }, set: { visible in
            if !visible {
                error_message = nil
            }
        })) {
            Button(NSLocalizedString("retry", comment: "Retry")) {
                Task { await load_shooter() }
            }
            Button(NSLocalizedString("ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(error_message ?? NSLocalizedString("shooter_mgmt_unknown_error", comment: ""))
        }
    }

    private func load_shooter() async {
        is_loading = true
        defer { is_loading = false }

        do {
            let all_shooters = try await IpscRepository.shared.getShooters(matchId: match_id, squadId: nil, forceRefresh: true)
            shooter = all_shooters.first(where: { $0.id == shooter_id })
            error_message = nil
        } catch {
            error_message = error.localizedDescription
        }
    }

    private func detail_row(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text((value ?? NSLocalizedString("shooter_mgmt_placeholder_dash", comment: "")).isEmpty ? NSLocalizedString("shooter_mgmt_placeholder_dash", comment: "") : (value ?? NSLocalizedString("shooter_mgmt_placeholder_dash", comment: "")))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func gender_label(_ value: String?) -> String {
        switch value {
        case "male":
            return NSLocalizedString("shooter_mgmt_gender_male", comment: "")
        case "female":
            return NSLocalizedString("shooter_mgmt_gender_female", comment: "")
        default:
            return value ?? NSLocalizedString("shooter_mgmt_placeholder_dash", comment: "")
        }
    }
}
