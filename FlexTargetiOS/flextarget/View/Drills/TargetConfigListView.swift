import Foundation
import SwiftUI
import UniformTypeIdentifiers
struct TargetConfigListViewV2: View {
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    @Binding var drillMode: String
    var singleDeviceMode: Bool = false
    var deviceNameFilter: String? = nil
    var isFromTargetLink: Bool = false
    var hasResults: Bool = false
    var onSettings: (() -> Void)? = nil
    var onStartDrill: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentTypeIndex: Int = 0
    @State private var randomEnabled: Bool = true
    @State private var draggingTypeFromRect: String? = nil
    @State private var isDraggingOverSelection: Bool = false
    @State private var showDisconnectAlert = false
    @ObservedObject private var bleManager = BLEManager.shared
    
    private var isDraggingEnabled: Bool {
        isDeviceAvailable && !hasResults
    }

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
                            if !hasResults {
                                drillMode = "ipsc"
                            }
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
                        .disabled(hasResults)
                        
                        // CQB Button
                        Button(action: {
                            if !hasResults {
                                drillMode = "cqb"
                            }
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
                        .disabled(hasResults)
                    }
                    .frame(maxWidth: 200)
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
                if !hasResults {
                    Text(singleDeviceMode ? 
                        NSLocalizedString("drag_to_set_target", comment: "Drag to set target") : 
                        NSLocalizedString("long_press_drag_add_delete_target", comment: "Long press and drag to add/delete target"))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                } else {
                    Text(NSLocalizedString("drill_editing_disabled_hint", comment: "Configurations cannot be changed because this drill has existing results."))
                        .foregroundColor(.gray)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

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
            // Force an update check on appear in case networkDevices was already populated but view didn't react
            updateTargetNamesForConnectedDevices(bleManager.networkDevices)
        }
        .onReceive(bleManager.$networkDevices) { devices in
            updateTargetNamesForConnectedDevices(devices)
        }
    }
    
    private func updateTargetNamesForConnectedDevices(_ devices: [NetworkDevice]) {
        // 1. If we're in multi-device mode, we should generally keep the list synced, 
        //    but let's focus on the single device case (most common for drills)
        guard singleDeviceMode else { return }
        
        // 2. We need at least one device to identify what we are looking for
        guard !devices.isEmpty else { return }
        
        // 3. Find our target configuration (typically at index 0 in single-device mode)
        guard let index = primaryConfigIndex else { return }
        
        let currentTargetName = targetConfigs[index].targetName
        
        // 4. Try to find the exact match in the current network
        if devices.contains(where: { $0.name == currentTargetName }) {
            // Found exact match, device is correctly linked
            return
        }
        
        // 5. If we only have ONE device connected, it's highly likely it's the 
        //    device the user wanted, even if the name changed (or it's a new device)
        if devices.count == 1 {
            let newDevice = devices.first!
            if targetConfigs[index].targetName != newDevice.name {
                print("TargetConfigListViewV2: Auto-updating target from \(currentTargetName) to \(newDevice.name)")
                targetConfigs[index].targetName = newDevice.name
                
                // If this is a drill with restricted editing but the device name changed,
                // we should still allow it to be "available" even if it wasn't the exact name stored.
            }
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
        if singleDeviceMode {
            // In single-device mode, we typically have only one config.
            // If deviceNameFilter exists, find that one, otherwise default to first.
            if let deviceName = deviceNameFilter, 
               let idx = targetConfigs.firstIndex(where: { $0.targetName == deviceName }) {
                return idx
            }
            return targetConfigs.isEmpty ? nil : 0
        } else {
            // In multi-device mode, look at the first config for the main target type selection
            return targetConfigs.isEmpty ? nil : 0
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
                        if isDraggingEnabled {
                            return handleDropToRect(providers: providers)
                        }
                        return false
                    }
                    .opacity(isDraggingEnabled ? 1.0 : 0.5)
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
                            if isDraggingEnabled {
                                draggingTypeFromRect = type
                                return NSItemProvider(object: type as NSString)
                            } else {
                                return NSItemProvider()
                            }
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
                            // Only allow drag if it's not the default placeholder and dragging is enabled
                            if isDraggingEnabled && !(availableTargetTypesFiltered.isEmpty && type == defaultTargetType) {
                                return NSItemProvider(object: type as NSString)
                            } else {
                                return NSItemProvider() // Empty provider to prevent drag
                            }
                        }
                        .opacity(isDraggingEnabled ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(height: 160)
        .disabled(!isDraggingEnabled)
        .onDrop(of: [UTType.plainText], isTargeted: $isDraggingOverSelection) { providers in
            if isDraggingEnabled {
                return handleDropToSelection(providers: providers)
            }
            return false
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
        guard !hasResults else { return false }
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
        guard !hasResults else { return false }
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
