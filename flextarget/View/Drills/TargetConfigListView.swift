import Foundation
import SwiftUI

struct TargetConfigListView: View {
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    let drillMode: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDisabledMessage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                listView
                AddButton
            }
        }
        .navigationTitle(NSLocalizedString("targets", comment: "Targets label"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if targetConfigs.count >= deviceList.count {
                        showDisabledMessage = true
                    } else {
                        addNewTarget()
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.red)
                }
                .help(targetConfigs.count >= deviceList.count ? "Maximum targets reached (\(targetConfigs.count)/\(deviceList.count))" : "")
            }
        }
        .alert(NSLocalizedString("maximum_targets_title", comment: "Maximum targets reached alert title"), isPresented: $showDisabledMessage) {
            Button("OK") { }
        } message: {
            Text(String(format: NSLocalizedString("maximum_targets_message", comment: "Maximum targets reached message"), targetConfigs.count, deviceList.count))
        }
        .onAppear {
            addAllAvailableTargets()
        }
    }

    private var listView: some View {
        List {
            ForEach($targetConfigs, id: \.id) { $config in
                TargetRowView(
                    config: $config,
                    availableDevices: availableDevices(for: config),
                    drillMode: drillMode
                )
            }
            .onMove { indices, newOffset in
                targetConfigs.move(fromOffsets: indices, toOffset: newOffset)
                updateSeqNos()
                saveTargetConfigs()
            }
            .onDelete { indices in
                targetConfigs.remove(atOffsets: indices)
                updateSeqNos()
                saveTargetConfigs()
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackgroundHidden()
        .onChange(of: targetConfigs) { _ in
            saveTargetConfigs()
        }
    }

    private var AddButton: some View {
        HStack(spacing: 20) {
            Button(action: {
                onDone()
                dismiss()
            }) {
                Text(NSLocalizedString("save", comment: "Save button"))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func availableDevices(for config: DrillTargetsConfigData) -> [NetworkDevice] {
        deviceList.filter { device in
            !targetConfigs.contains(where: { $0.targetName == device.name && $0.id != config.id })
        }
    }

    private var sortedUnusedNetworkDevices: [NetworkDevice] {
        let existingNames = Set(targetConfigs.map { $0.targetName })
        return sortedNetworkDevices().filter { !existingNames.contains($0.name) }
    }

    private func sortedNetworkDevices() -> [NetworkDevice] {
        deviceList.sorted { lhs, rhs in
            let lhsNumber = numericValue(from: lhs.name)
            let rhsNumber = numericValue(from: rhs.name)

            if let lhsNumber, let rhsNumber, lhsNumber != rhsNumber {
                return lhsNumber < rhsNumber
            }
            if lhsNumber != nil && rhsNumber == nil {
                return true
            }
            if rhsNumber != nil && lhsNumber == nil {
                return false
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func numericValue(from name: String) -> Int? {
        let digits = name.compactMap { $0.isNumber ? String($0) : nil }.joined()
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    private func addAllAvailableTargets() {
        let currentDeviceNames = Set(deviceList.map { $0.name })
        
        // Remove targets that are no longer in the network device list
        targetConfigs.removeAll { !currentDeviceNames.contains($0.targetName) }
        
        let newDevices = sortedUnusedNetworkDevices
        guard !newDevices.isEmpty else { return }

        for device in newDevices {
            appendTarget(named: device.name)
        }
        updateSeqNos()
        saveTargetConfigs()
    }

    private func defaultTargetType() -> String {
        switch drillMode {
        case "ipsc":
            return "ipsc"
        case "idpa":
            return "idpa"
        case "cqb":
            return "cqb_enemy_front"
        default:
            return "ipsc"
        }
    }

    private func appendTarget(named name: String) {
        let newConfig = DrillTargetsConfigData(
            seqNo: targetConfigs.count + 1,
            targetName: name,
            targetType: defaultTargetType(),
            timeout: 30.0,
            countedShots: 5
        )
        targetConfigs.append(newConfig)
    }

    private func addNewTarget() {
        let nextSeqNo = (targetConfigs.map { $0.seqNo }.max() ?? 0) + 1
        let newConfig = DrillTargetsConfigData(
            seqNo: nextSeqNo,
            targetName: "",
            targetType: defaultTargetType(),
            timeout: 30.0,
            countedShots: 5
        )
        targetConfigs.append(newConfig)
        saveTargetConfigs()
    }

    private func deleteTarget(at index: Int) {
        targetConfigs.remove(at: index)
        updateSeqNos()
        saveTargetConfigs()
    }

    private func updateSeqNos() {
        for (index, _) in targetConfigs.enumerated() {
            targetConfigs[index].seqNo = index + 1
        }
    }

    private func saveTargetConfigs() {
        let userDefaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(targetConfigs)
            userDefaults.set(data, forKey: "targetConfigs")
        } catch {
            print("Failed to save targetConfigs: \(error)")
        }
    }
}

struct TargetRowView: View {
    @Binding var config: DrillTargetsConfigData
    let availableDevices: [NetworkDevice]
    var drillMode: String = "ipsc"

    // Single active sheet state
    @State private var activeSheet: ActiveSheet? = nil

    private enum ActiveSheet: Identifiable {
        case type
        case action
        case duration

        var id: Int { 
            switch self {
            case .type: return 0
            case .action: return 1
            case .duration: return 2
            }
        }
    }

    private var iconNames: [String] {
        switch drillMode {
        case "ipsc":
            return [
                "ipsc",
                "hostage",
                "paddle",
                "popper",
                "rotation",
                "special_1",
                "special_2"
            ]
        case "idpa":
            return [
                "idpa",
                "idpa_ns",
                "idpa_hard_cover_1",
                "idpa_hard_cover_2"
            ]
        case "cqb":
            return [
                "cqb_enemy_swing",
                "cqb_enemy_front",
                "cqb_enemy_moving"
            ]
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title row
            Text(config.targetName.isEmpty ? NSLocalizedString("select_device", comment: "Select Device placeholder") : config.targetName)
                .foregroundColor(.red)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color.gray.opacity(0.4))

            // Details rows
            VStack(spacing: 12) {
                cardColumn(title: NSLocalizedString("type", comment: "Type label"), value: config.targetType, icon: config.targetType, action: { activeSheet = .type })

                if drillMode == "cqb" {
                    cardColumn(title: NSLocalizedString("action", comment: "Action label"), value: config.action.isEmpty ? NSLocalizedString("select_action", comment: "Select action") : config.action, icon: nil, action: { activeSheet = .action })

                    cardColumn(title: NSLocalizedString("duration", comment: "Duration label"), value: config.duration == 0 ? NSLocalizedString("select_duration", comment: "Select duration") : String(format: NSLocalizedString("duration_value_format", comment: "Duration value"), config.duration), icon: nil, action: { activeSheet = .duration })
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .listRowBackground(Color.clear)
        .buttonStyle(.plain)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .type:
                TargetTypePickerView(
                    iconNames: iconNames,
                    selectedType: $config.targetType,
                    onDone: { activeSheet = nil }
                )
            case .action:
                ActionPickerView(
                    selectedAction: $config.action,
                    onDone: { activeSheet = nil }
                )
            case .duration:
                ActionDurationPickerView(
                    selectedDuration: $config.duration,
                    onDone: { activeSheet = nil }
                )
            }
        }
    }

    @ViewBuilder
    private func cardColumn(title: String, value: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 12))

            Button(action: action) {
                HStack {
                    if let icon {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }

                    Text(value)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                        .frame(width: 36, height: 24)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(activeSheet != nil)
        }
        .frame(maxWidth: .infinity)
    }
}
struct TargetNamePickerView: View {
    let availableDevices: [NetworkDevice]
    @Binding var selectedDevice: String
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(availableDevices, id: \.name) { device in
                        Button(action: {
                            // set selection and dismiss
                            selectedDevice = device.name
                            onDone?()
                        }) {
                            HStack {
                                Text(device.name)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDevice == device.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackgroundHidden()
            }
            .navigationTitle(NSLocalizedString("select_device", comment: "Select Device navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct TargetTypePickerView: View {
    let iconNames: [String]
    @Binding var selectedType: String
    var onDone: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(iconNames, id: \.self) { icon in
                        Button(action: {
                            // set selection and dismiss
                            selectedType = icon
                            onDone?()
                        }) {
                            HStack {
                                Image(icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                Text(icon)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedType == icon {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackgroundHidden()
            }
            .navigationTitle(NSLocalizedString("select_target_type", comment: "Select Target Type navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct ActionPickerView: View {
    @Binding var selectedAction: String
    var onDone: (() -> Void)? = nil
    
    private let actions = ["flash", "swing_left", "swing_right", "run_through", "run_through_reverse"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(actions, id: \.self) { action in
                        Button(action: {
                            selectedAction = action
                            onDone?()
                        }) {
                            HStack {
                                Text(action)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedAction == action {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackgroundHidden()
            }
            .navigationTitle("Select Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct ActionDurationPickerView: View {
    @Binding var selectedDuration: Double
    var onDone: (() -> Void)? = nil
    
    private let durations = [1.5, 2.5, 3.5, 5.0]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(durations, id: \.self) { duration in
                        Button(action: {
                            selectedDuration = duration
                            onDone?()
                        }) {
                            HStack {
                                Text(String(format: "%.1fs", duration))
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDuration == duration {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackgroundHidden()
            }
            .navigationTitle("Select Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

#Preview {
    let mockDevices = [
        NetworkDevice(name: "Target 1", mode: "active"),
        NetworkDevice(name: "Target 2", mode: "active"),
        NetworkDevice(name: "Target 3", mode: "active"),
        NetworkDevice(name: "Target 4", mode: "active")
    ]
    
    let mockConfigs = [
        DrillTargetsConfigData(seqNo: 1, targetName: "Target 1", targetType: "ipsc", timeout: 30.0, countedShots: 5),
        DrillTargetsConfigData(seqNo: 2, targetName: "Target 2", targetType: "paddle", timeout: 25.0, countedShots: 3),
        DrillTargetsConfigData(seqNo: 3, targetName: "Target 3", targetType: "popper", timeout: 20.0, countedShots: 1)
    ]
    
    TargetConfigListView(deviceList: mockDevices, targetConfigs: .constant(mockConfigs), onDone: {}, drillMode: "ipsc")
}
