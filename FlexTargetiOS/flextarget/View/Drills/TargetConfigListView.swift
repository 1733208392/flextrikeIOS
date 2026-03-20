import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TargetConfigListView: View {
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    let drillMode: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDisabledMessage = false
    @State private var showDisconnectAlert = false
    @ObservedObject private var bleManager = BLEManager.shared
    
    private var isDeviceAvailable: Bool {
        !bleManager.networkDevices.isEmpty
    }

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
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
            // Warning banner when no device connected
            if !isDeviceAvailable {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Device Connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Connect a device to edit targets and start drill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(red: 0.3, green: 0.2, blue: 0.0))
                .cornerRadius(8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            
            ForEach(targetConfigs.indices, id: \.self) { index in
                TargetRowView(
                    config: $targetConfigs[index],
                    availableDevices: availableDevices(for: targetConfigs[index]),
                    drillMode: drillMode,
                    onDisguisedEnemySelected: { _ in
                        createDisguisedEnemyVariants(forTargetIndex: index)
                    }
                )
            }
            .onMove { indices, newOffset in
                if isDeviceAvailable {
                    targetConfigs.move(fromOffsets: indices, toOffset: newOffset)
                    updateSeqNos()
                } else {
                    showDisconnectAlert = true
                }
            }
            .onDelete { indices in
                if isDeviceAvailable {
                    targetConfigs.remove(atOffsets: indices)
                    updateSeqNos()
                } else {
                    showDisconnectAlert = true
                }
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackgroundHidden()
        .opacity(isDeviceAvailable ? 1.0 : 0.5)
        .disabled(!isDeviceAvailable)
        .alert("Cannot Edit Targets", isPresented: $showDisconnectAlert) {
            Button("OK") { }
        } message: {
            Text("Please connect a device first.")
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
                    .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .cornerRadius(8)
            }
            .opacity(isDeviceAvailable ? 1.0 : 0.6)
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
    }

    private func defaultTargetType() -> String {
        switch drillMode {
        case "ipsc":
            return "ipsc"
        case "idpa":
            return "idpa"
        case "cqb":
            return "cqb_front"
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
    }

    private func deleteTarget(at index: Int) {
        targetConfigs.remove(at: index)
        updateSeqNos()
    }

    private func updateSeqNos() {
        for (index, _) in targetConfigs.enumerated() {
            targetConfigs[index].seqNo = index + 1
        }
    }



    private func createDisguisedEnemyVariants(forTargetIndex index: Int) {
        guard index < targetConfigs.count else { return }
        
        // Create two variants: surrender (0-5s) and enemy (5.1-10s)
        let variants: [TargetVariant] = [
            TargetVariant(targetType: "disguised_enemy_surrender", startTime: 0, endTime: 5),
            TargetVariant(targetType: "disguised_enemy", startTime: 5.1, endTime: 10)
        ]
        
        // Encode variants as JSON and set on the target config
        let variantJSON = DrillTargetsConfigData.encodeVariants(variants)
        targetConfigs[index].targetVariant = variantJSON
    }
}

struct TargetRowView: View {
    @Binding var config: DrillTargetsConfigData
    let availableDevices: [NetworkDevice]
    var drillMode: String = "ipsc"
    var onDisguisedEnemySelected: ((Int) -> Void)? = nil

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
                "idpa_black_1",
                "idpa_black_2"
            ]
        case "cqb":
            return [
                "disguised_enemy",
                "cqb_swing",
                "cqb_front",
                "cqb_hostage",
                "cqb_move"
            ]
        default:
            return []
        }
    }

    private func allowedActions(for targetType: String) -> [String] {
        guard drillMode == "cqb" else { return [] }
        switch targetType {
        case "cqb_front":
            return ["flash"]
        case "cqb_swing":
            return ["swing_right"]
        case "cqb_move":
            return ["run_through"]
        case "cqb_hostage":
            return ["flash"]
        case "disguised_enemy":
            return ["disguised_enemy_flash"]
        default:
            return ["flash", "swing_right", "run_through"]
        }
    }

    private func normalizeActionForCurrentTargetType() {
        guard drillMode == "cqb" else { return }
        let allowed = allowedActions(for: config.targetType)
        guard let firstAllowed = allowed.first else { return }
        if config.action.isEmpty || !allowed.contains(config.action) {
            config.action = firstAllowed
        }
        if config.targetType == "disguised_enemy" {
            config.duration = -1.0
            config.action = "disguised_enemy_flash"
        }
    }

    private func localizedTargetTypeName(_ type: String) -> String {
        switch type {
        case "cqb_swing":
            return NSLocalizedString("cqb_swing", comment: "Peeking action")
        case "cqb_front":
            return NSLocalizedString("cqb_front", comment: "Aiming action")
        case "cqb_move":
            return NSLocalizedString("cqb_move", comment: "Passing action")
        case "cqb_hostage":
            return NSLocalizedString("hostage", comment: "Hostage target")
        case "disguised_enemy":
            return NSLocalizedString("disguised_enemy", comment: "Disguised Threat target")
        default:
            return type
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title row
            Text(config.targetName.isEmpty ? NSLocalizedString("select_device", comment: "Select Device placeholder") : config.targetName)
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color.gray.opacity(0.4))

            // Details rows
            VStack(spacing: 12) {
                cardColumn(title: NSLocalizedString("type", comment: "Type label"), value: localizedTargetTypeName(config.targetType), icon: config.primaryTargetType(), action: { activeSheet = .type })

                if drillMode == "cqb" {
                    let isCQBType = ["cqb_swing", "cqb_front", "cqb_move", "disguised_enemy", "cqb_hostage"].contains(config.targetType)
                    let allowed = allowedActions(for: config.targetType)
                    
                    // Don't show action for CQB targets or disguised_enemy (device handles actions)
                    if !isCQBType {
                        cardColumn(title: NSLocalizedString("action", comment: "Action label"), value: config.action.isEmpty ? NSLocalizedString("select_action", comment: "Select action") : config.action, icon: nil, action: { activeSheet = .action })
                            .disabled(allowed.count <= 1)
                    }

                    // Disable duration for disguised_enemy
                    cardColumn(title: NSLocalizedString("duration", comment: "Duration label"), value: config.duration == 0 ? NSLocalizedString("select_duration", comment: "Select duration") : String(format: NSLocalizedString("duration_value_format", comment: "Duration value"), config.duration), icon: nil, action: { activeSheet = .duration })
                        .disabled(config.targetType == "disguised_enemy")
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
                    actions: allowedActions(for: config.targetType),
                    onDone: { activeSheet = nil }
                )
            case .duration:
                ActionDurationPickerView(
                    selectedDuration: $config.duration,
                    onDone: { activeSheet = nil }
                )
            }
        }
        .onAppear {
            normalizeActionForCurrentTargetType()
        }
        .onChange(of: config.targetType) { newType in
            normalizeActionForCurrentTargetType()
            if newType == "disguised_enemy" && drillMode == "cqb" {
                onDisguisedEnemySelected?(0)  // Index is not needed here; callback will handle it
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
                                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
    
    private func localizedTypeName(_ type: String) -> String {
        switch type {
        case "cqb_swing":
            return NSLocalizedString("cqb_swing", comment: "Peeking action")
        case "cqb_front":
            return NSLocalizedString("cqb_front", comment: "Aiming action")
        case "cqb_move":
            return NSLocalizedString("cqb_move", comment: "Passing action")
        case "cqb_hostage":
            return NSLocalizedString("hostage", comment: "Hostage target")
        case "disguised_enemy":
            return NSLocalizedString("disguised_enemy", comment: "Disguised Threat target")
        default:
            return type
        }
    }
    
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
                                Text(localizedTypeName(icon))
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedType == icon {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct ActionPickerView: View {
    @Binding var selectedAction: String
    let actions: [String]
    var onDone: (() -> Void)? = nil

    init(selectedAction: Binding<String>, actions: [String] = ["flash", "swing_left", "swing_right", "run_through", "run_through_reverse"], onDone: (() -> Void)? = nil) {
        self._selectedAction = selectedAction
        self.actions = actions
        self.onDone = onDone
    }
    
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
                                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct ActionDurationPickerView: View {
    @Binding var selectedDuration: Double
    var onDone: (() -> Void)? = nil
    
    private let durations = [-1.0, 1.5, 2.5, 3.5, 5.0]
    
    private func durationLabel(_ duration: Double) -> String {
        if duration == -1.0 {
            return NSLocalizedString("duration_continuous", comment: "Continuous duration option")
        } else {
            return String(format: NSLocalizedString("duration_seconds_format", comment: "Duration in seconds"), duration)
        }
    }
    
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
                                Text(durationLabel(duration))
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDuration == duration {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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
            .navigationTitle(NSLocalizedString("select_duration", comment: "Select duration sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
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

struct TargetConfigListViewV2: View {
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    @Binding var drillMode: String
    var singleDeviceMode: Bool = false
    var deviceNameFilter: String? = nil
    var isFromTargetLink: Bool = false
    var onSettings: (() -> Void)? = nil
    var onStartDrill: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentTypeIndex: Int = 0
    @State private var randomEnabled: Bool = true
    @State private var draggingTypeFromRect: String? = nil
    @State private var isDraggingOverSelection: Bool = false
    @State private var showDisconnectAlert = false
    @ObservedObject private var bleManager = BLEManager.shared
    
    private var isDeviceAvailable: Bool {
        !bleManager.networkDevices.isEmpty
    }

    var body: some View {
        ZStack {
            // Use #191919 as background color
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 10)
                // Drill Mode Segment Control
                if !isFromTargetLink {
                    HStack(spacing: 0) {
                        // IPSC Button
                        Button(action: {
                            drillMode = "ipsc"
                        }) {
                            HStack(spacing: 6) {
                                if drillMode == "ipsc" {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("IPSC")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(drillMode == "ipsc" ? .white : .gray)
                            .background(drillMode == "ipsc" ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : Color.gray.opacity(0.2))
                        }
                        
                        // CQB Button
                        Button(action: {
                            drillMode = "cqb"
                        }) {
                            HStack(spacing: 6) {
                                if drillMode == "cqb" {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("CQB")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(drillMode == "cqb" ? .white : .gray)
                            .background(drillMode == "cqb" ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.1372549019607843) : Color.gray.opacity(0.2))
                        }

                        // Gaming Button
                        if singleDeviceMode {
                            Button(action: {
                                drillMode = "gaming"
                            }) {
                                HStack(spacing: 6) {
                                    if drillMode == "gaming" {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    Text("Gaming")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundColor(drillMode == "gaming" ? .white : .gray)
                                .background(drillMode == "gaming" ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.1372549019607843) : Color.gray.opacity(0.2))
                            }
                        }
                    }
                    .frame(maxWidth: singleDeviceMode ? 280 : 200)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .onChange(of: drillMode) { newValue in
                        // Re-filter existing selections to only include types available in the new drill mode
                        let currentSelected = primaryConfig?.parseTargetTypes() ?? []
                        updateSelectedTargetTypes(currentSelected)
                        currentTypeIndex = min(currentTypeIndex, max(0, selectedTargetTypes.count - 1))
                    }
                }
                
                targetRectSection
                Text(singleDeviceMode ? 
                    NSLocalizedString("drag_to_set_target", comment: "Drag to set target") : 
                    NSLocalizedString("long_press_drag_add_delete_target", comment: "Long press and drag to add/delete target"))
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .font(.caption)
                    .multilineTextAlignment(.center)

                // Spacer(minLength: 0)
                targetTypeSelectionView
                RoundedRectangle(cornerRadius: 2)
                     .fill(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .frame(width: 240)
                    .frame(height: 4)
                Spacer(minLength: 0)
                
                if let onStartDrill = onStartDrill {
                    Button(action: {
                        if isDeviceAvailable {
                            onStartDrill()
                        } else {
                            showDisconnectAlert = true
                        }
                    }) {
                        Text(NSLocalizedString("start_drill", comment: "Start drill button"))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .cornerRadius(12)
                    }
                    .opacity(isDeviceAvailable ? 1.0 : 0.5)
                    .disabled(!isDeviceAvailable)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .alert("Cannot Start Drill", isPresented: $showDisconnectAlert) {
                Button("OK") { }
            } message: {
                Text("Please connect a device first.")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }

            ToolbarItem(placement: .principal) {
                Text(currentTargetName)
                    .font(.headline)
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    .lineLimit(1)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if let onSettings = onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    }
                }
            }
        }
        .onAppear {
            ensurePrimaryTarget()
            clampCurrentTypeIndex()
        }
    }

    private var availableTargetTypes: [String] {
        switch drillMode {
        case "ipsc":
            return ["ipsc", "hostage", "paddle", "popper", "special_1", "special_2"]
        case "idpa":
            return ["idpa", "idpa_ns", "idpa_black_1", "idpa_black_2"]
        case "cqb":
            return ["cqb_swing", "cqb_front", "cqb_move", "disguised_enemy", "cqb_hostage"]
        case "gaming":
            return ["clay pigeon"]
        default:
            return ["ipsc"]
        }
    }

    private var availableTargetTypesFiltered: [String] {
        availableTargetTypes.filter { !selectedTargetTypes.contains($0) }
    }

    private var defaultTargetType: String {
        switch drillMode {
        case "ipsc":
            return "ipsc"
        case "idpa":
            return "idpa"
        case "cqb":
            return "cqb_front"
        case "gaming":
            return "clay pigeon"
        default:
            return "ipsc"
        }
    }

    private var currentTargetName: String {
        guard let config = primaryConfig else {
            return NSLocalizedString("targets", comment: "Targets label")
        }
        return config.targetName.isEmpty ? NSLocalizedString("targets", comment: "Targets label") : config.targetName
    }

    private var primaryConfigIndex: Int? {
        if singleDeviceMode, let deviceName = deviceNameFilter {
            // In single device mode, find the config matching the device name
            return targetConfigs.firstIndex { $0.targetName == deviceName }
        } else {
            // In multi-device mode, use first config
            guard !targetConfigs.isEmpty else { return nil }
            return 0
        }
    }

    private var primaryConfig: DrillTargetsConfigData? {
        guard let index = primaryConfigIndex else { return nil }
        return targetConfigs[index]
    }

    private var selectedTargetTypes: [String] {
        let allSelected = primaryConfig?.parseTargetTypes() ?? []
        return allSelected.filter { availableTargetTypes.contains($0) }
    }

    private var badgeCount: Int {
        selectedTargetTypes.count
    }

    private var targetRectSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 0)
                     .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 8)
                    .frame(width: 180)
                    .frame(height: 320)
                    .overlay(targetRectContent)
                    .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                        if isDeviceAvailable {
                            return handleDropToRect(providers: providers)
                        }
                        return false
                    }
                    .opacity(isDeviceAvailable ? 1.0 : 0.5)
            }
            
        }
    }

    @ViewBuilder
    private var targetRectContent: some View {
        if selectedTargetTypes.isEmpty {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white.opacity(0.75))
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    handleDropToRect(providers: providers)
                }
        } else {
            TabView(selection: Binding(
                get: { min(currentTypeIndex, max(0, selectedTargetTypes.count - 1)) },
                set: { newValue in currentTypeIndex = newValue }
            )) {
                ForEach(Array(selectedTargetTypes.enumerated()), id: \.offset) { index, type in
                    Image(type)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .tag(index)
                        .onDrag {
                            draggingTypeFromRect = type
                            return NSItemProvider(object: type as NSString)
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTargetTypes)
            .overlay(alignment: .bottom) {
                if selectedTargetTypes.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<selectedTargetTypes.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentTypeIndex ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                handleDropToRect(providers: providers)
            }
        }
    }

    private var randomToggleSection: some View {
        HStack(spacing: 14) {
            Spacer()
            Text("RANDOM")
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .font(.system(size: 24, weight: .bold))

            Toggle("", isOn: $randomEnabled)
                .labelsHidden()
                .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .frame(width: 86)
        }
    }

    private var targetTypeSelectionView: some View {
        // In multi-device mode, show only unselected types
        let typesToShow = availableTargetTypesFiltered.isEmpty ? [defaultTargetType] : availableTargetTypesFiltered

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(typesToShow, id: \.self) { type in
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 0)
                        .frame(width: 90, height: 160)
                        .overlay(
                            Group {
                                if availableTargetTypesFiltered.isEmpty && type == defaultTargetType {
                                    Image(systemName: "folder.badge.plus")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(10)
                                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                } else {
                                    Image(type)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(10)
                                }
                            }
                        )
                        .onDrag {
                            // Only allow drag if it's not the default placeholder
                            if !(availableTargetTypesFiltered.isEmpty && type == defaultTargetType) {
                                return NSItemProvider(object: type as NSString)
                            } else {
                                return NSItemProvider() // Empty provider to prevent drag
                            }
                        }
                        .opacity(isDeviceAvailable ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(height: 160)
        .disabled(!isDeviceAvailable)
        .onDrop(of: [UTType.plainText], isTargeted: $isDraggingOverSelection) { providers in
            return handleDropToSelection(providers: providers)
        }
    }

    private var saveButton: some View {
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
                .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .cornerRadius(8)
        }
    }

    private func ensurePrimaryTarget() {
        if targetConfigs.isEmpty {
            let targetName = deviceList.first?.name ?? NSLocalizedString("targets", comment: "Targets label")
            var config = DrillTargetsConfigData(
                seqNo: 1,
                targetName: targetName,
                targetType: defaultTargetType,
                timeout: 30.0,
                countedShots: 5
            )
            config.setTargetTypes([])
            targetConfigs = [config]
            return
        }

        if targetConfigs[0].targetName.isEmpty {
            targetConfigs[0].targetName = deviceList.first?.name ?? targetConfigs[0].targetName
        }

        let parsed = targetConfigs[0].parseTargetTypes()
        if parsed.isEmpty, !targetConfigs[0].targetType.isEmpty, !targetConfigs[0].targetType.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            targetConfigs[0].setTargetTypes([targetConfigs[0].targetType])
        }
    }

    private func clampCurrentTypeIndex() {
        let maxIndex = max(0, selectedTargetTypes.count - 1)
        currentTypeIndex = min(currentTypeIndex, maxIndex)
    }

    private func updateSelectedTargetTypes(_ newValues: [String]) {
        guard let index = primaryConfigIndex else { return }
        let filteredValues = newValues.filter { availableTargetTypes.contains($0) }
        targetConfigs[index].setTargetTypes(filteredValues)
        if filteredValues.isEmpty {
            targetConfigs[index].targetVariant = nil
        }

        if drillMode == "cqb", let first = newValues.first {
            targetConfigs[index].action = defaultAction(for: first)
            if first == "disguised_enemy" {
                targetConfigs[index].duration = -1.0
                let variants: [TargetVariant] = [
                    TargetVariant(targetType: "disguised_enemy_surrender", startTime: 0, endTime: 5),
                    TargetVariant(targetType: "disguised_enemy", startTime: 5.1, endTime: 10)
                ]
                targetConfigs[index].targetVariant = DrillTargetsConfigData.encodeVariants(variants)
            }
        }

        clampCurrentTypeIndex()
    }

    private func defaultAction(for targetType: String) -> String {
        guard drillMode == "cqb" else { return "" }
        switch targetType {
        case "cqb_front":
            return "flash"
        case "cqb_swing":
            return "swing_right"
        case "cqb_move":
            return "run_through"
        case "cqb_hostage":
            return "flash"
        case "disguised_enemy":
            return "disguised_enemy_flash"
        default:
            return ""
        }
    }

    private func handleDropToRect(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let targetType = object as? String else { return }
            DispatchQueue.main.async {
                // For both single and multi-device modes, append to the list
                var updated = selectedTargetTypes
                if !updated.contains(targetType) {
                    updated.append(targetType)
                    updateSelectedTargetTypes(updated)
                    currentTypeIndex = max(0, updated.count - 1)
                }
            }
        }
        return true
    }

    private func handleDropToSelection(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let targetType = object as? String else { return }
            DispatchQueue.main.async {
                guard let fromRectType = draggingTypeFromRect, fromRectType == targetType else { return }
                var updated = selectedTargetTypes
                if let removeIndex = updated.firstIndex(of: targetType) {
                    updated.remove(at: removeIndex)
                    updateSelectedTargetTypes(updated)
                    currentTypeIndex = max(0, min(currentTypeIndex, updated.count - 1))
                }
                draggingTypeFromRect = nil
            }
        }
        return true
    }
}
