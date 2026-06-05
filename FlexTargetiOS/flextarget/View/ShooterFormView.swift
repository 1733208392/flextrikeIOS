import SwiftUI

enum ShooterFormMode {
    case create
    case edit
}

struct ShooterFormView: View {
    let match_id: Int
    let mode: ShooterFormMode
    let shooter_id: Int?

    @Environment(\.dismiss) private var dismiss

    @State private var divisions: [IpscDivision] = []
    @State private var squads: [IpscSquad] = []
    @State private var categories: [IpscCategory] = []
    @State private var original_shooter: IpscShooter?

    @State private var division_id: Int?
    @State private var name = ""
    @State private var gender = ""
    @State private var age_text = ""
    @State private var category_code = ""
    @State private var squad_id: Int?
    @State private var region = ""
    @State private var club = ""

    @State private var is_loading = false
    @State private var is_submitting = false
    @State private var error_message: String?

    private var is_edit_mode: Bool {
        mode == .edit
    }

    private var can_submit: Bool {
        if is_submitting || is_loading {
            return false
        }
        return division_id != nil
    }

    var body: some View {
        Form {
            Section(NSLocalizedString("shooter_mgmt_section_basic", comment: "")) {
                Picker(NSLocalizedString("shooter_mgmt_form_division_required", comment: ""), selection: Binding(get: {
                    division_id ?? -1
                }, set: { value in
                    division_id = value == -1 ? nil : value
                })) {
                    Text(NSLocalizedString("shooter_mgmt_please_select", comment: "")).tag(-1)
                    ForEach(divisions) { division in
                        Text(division.name ?? NSLocalizedString("shooter_mgmt_unnamed_division", comment: "")).tag(division.id)
                    }
                }

                TextField(NSLocalizedString("shooter_mgmt_field_name", comment: ""), text: $name)

                Picker(NSLocalizedString("shooter_mgmt_field_gender", comment: ""), selection: $gender) {
                    Text(NSLocalizedString("shooter_mgmt_unselected", comment: "")).tag("")
                    Text(NSLocalizedString("shooter_mgmt_gender_male", comment: "")).tag("male")
                    Text(NSLocalizedString("shooter_mgmt_gender_female", comment: "")).tag("female")
                }

                TextField(NSLocalizedString("shooter_mgmt_field_age", comment: ""), text: $age_text)
                    .keyboardType(.numberPad)
            }

            Section(NSLocalizedString("shooter_mgmt_form_section_category_squad", comment: "")) {
                Picker(NSLocalizedString("shooter_mgmt_field_category", comment: ""), selection: $category_code) {
                    Text(NSLocalizedString("shooter_mgmt_unselected", comment: "")).tag("")
                    ForEach(categories) { category in
                        Text(category.name ?? NSLocalizedString("shooter_mgmt_unnamed_category", comment: "")).tag(category_picker_tag(for: category))
                    }
                }

                Picker(NSLocalizedString("shooter_mgmt_field_squad", comment: ""), selection: Binding(get: {
                    squad_id ?? -1
                }, set: { value in
                    squad_id = value == -1 ? nil : value
                })) {
                    Text(NSLocalizedString("shooter_mgmt_unselected", comment: "")).tag(-1)
                    ForEach(squads) { squad in
                        Text(squad.name).tag(squad.id)
                    }
                }
            }

            Section(NSLocalizedString("shooter_mgmt_form_section_extra", comment: "")) {
                TextField(NSLocalizedString("shooter_mgmt_field_region", comment: ""), text: $region)
                TextField(NSLocalizedString("shooter_mgmt_field_club", comment: ""), text: $club)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if is_submitting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(is_edit_mode ? NSLocalizedString("shooter_mgmt_save_changes", comment: "") : NSLocalizedString("shooter_mgmt_create_shooter", comment: ""))
                        Spacer()
                    }
                }
                .disabled(!can_submit)
            }
        }
        .navigationTitle(is_edit_mode ? NSLocalizedString("shooter_mgmt_edit_nav_title", comment: "") : NSLocalizedString("shooter_mgmt_add_nav_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    dismiss()
                }
            }
        }
        .overlay {
            if is_loading {
                ProgressView(NSLocalizedString("shooter_mgmt_loading", comment: ""))
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .task {
            await load_data()
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

    private func load_data() async {
        is_loading = true
        defer { is_loading = false }

        do {
            async let loaded_divisions = IpscRepository.shared.getDivisions(matchId: match_id, forceRefresh: false)
            async let loaded_squads = IpscRepository.shared.getSquads(matchId: match_id, forceRefresh: false)
            async let loaded_categories = IpscRepository.shared.getCategories(matchId: match_id, forceRefresh: false)

            divisions = try await loaded_divisions
            squads = try await loaded_squads
            categories = try await loaded_categories

            if is_edit_mode, let shooter_id {
                let shooters = try await IpscRepository.shared.getShooters(matchId: match_id, squadId: nil, forceRefresh: true)
                original_shooter = shooters.first(where: { $0.id == shooter_id })
                fill_fields_for_edit()
            }

            if division_id == nil {
                division_id = divisions.first?.id
            }

            error_message = nil
        } catch {
            error_message = error.localizedDescription
        }
    }

    private func fill_fields_for_edit() {
        guard let original_shooter else { return }
        division_id = original_shooter.division_id
        name = original_shooter.name ?? ""
        gender = original_shooter.gender ?? ""
        age_text = original_shooter.age.map(String.init) ?? ""
        category_code = normalized_category_code(original_shooter.category_code) ?? (original_shooter.category_code ?? "")
        squad_id = original_shooter.squad_id
        region = original_shooter.region ?? ""
        club = original_shooter.club ?? ""
    }

    private func submit() async {
        guard let division_id else {
            error_message = NSLocalizedString("shooter_mgmt_choose_division_error", comment: "")
            return
        }

        is_submitting = true
        defer { is_submitting = false }

        do {
            if is_edit_mode {
                guard let shooter_id else {
                    error_message = NSLocalizedString("shooter_mgmt_missing_shooter_id_error", comment: "")
                    return
                }

                let request = build_update_request(required_division_id: division_id)
                _ = try await IpscRepository.shared.updateShooter(matchId: match_id, id: shooter_id, request: request)
            } else {
                let request = IpscShooterCreateRequest(
                    division_id: division_id,
                    name: normalized_string(name),
                    gender: normalized_gender(gender),
                    age: normalized_age(age_text),
                    category_code: normalized_category_code(category_code),
                    squad_id: squad_id,
                    region: normalized_string(region),
                    club: normalized_string(club)
                )
                _ = try await IpscRepository.shared.createShooter(matchId: match_id, request: request)
            }

            dismiss()
        } catch {
            error_message = error.localizedDescription
        }
    }

    private func build_update_request(required_division_id: Int) -> IpscShooterUpdateRequest {
        guard let original_shooter else {
            return IpscShooterUpdateRequest(
                division_id: required_division_id,
                name: normalized_string(name),
                gender: normalized_gender(gender),
                age: normalized_age(age_text),
                category_code: normalized_string(category_code),
                squad_id: squad_id,
                region: normalized_string(region),
                club: normalized_string(club)
            )
        }

        let new_name = normalized_string(name)
        let new_gender = normalized_gender(gender)
        let new_age = normalized_age(age_text)
        let new_category_code = normalized_category_code(category_code)
        let new_region = normalized_string(region)
        let new_club = normalized_string(club)

        return IpscShooterUpdateRequest(
            division_id: original_shooter.division_id == required_division_id ? nil : required_division_id,
            name: original_shooter.name == new_name ? nil : new_name,
            gender: original_shooter.gender == new_gender ? nil : new_gender,
            age: original_shooter.age == new_age ? nil : new_age,
            category_code: original_shooter.category_code == new_category_code ? nil : new_category_code,
            squad_id: original_shooter.squad_id == squad_id ? nil : squad_id,
            region: original_shooter.region == new_region ? nil : new_region,
            club: original_shooter.club == new_club ? nil : new_club
        )
    }

    private func normalized_string(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalized_gender(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalized_age(_ value: String) -> Int? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        return Int(normalized)
    }

    private func category_picker_tag(for category: IpscCategory) -> String {
        normalized_category_code(category.code)
            ?? normalized_category_code(category.name)
            ?? ""
    }

    private func normalized_category_code(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let upper = trimmed.uppercased()
        if ["J", "S", "SJ", "L"].contains(upper) {
            return upper
        }

        if (upper.contains("SUPER") && upper.contains("JUNIOR")) || upper.contains("SUPERJUNIOR") || upper == "S/J" {
            return "SJ"
        }
        if upper.contains("JUNIOR") {
            return "J"
        }
        if upper.contains("SENIOR") {
            return "S"
        }
        if upper.contains("LADY") {
            return "L"
        }

        if trimmed.contains("超") && trimmed.contains("青") {
            return "SJ"
        }
        if trimmed.contains("青") {
            return "J"
        }
        if trimmed.contains("资深") || trimmed.contains("資深") || trimmed.contains("高龄") || trimmed.contains("高齡") {
            return "S"
        }
        if trimmed.contains("女") {
            return "L"
        }

        return nil
    }
}
