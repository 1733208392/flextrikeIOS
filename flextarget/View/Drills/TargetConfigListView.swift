import Foundation
import SwiftUI

struct TargetConfigListView: View {
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDisabledMessage = false

    private let iconNames = [
        "hostage",
        "ipsc",
        "paddle",
        "popper",
        "rotation",
        "special_1",
        "special_2",
        "testTarget"
    ]

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
                    availableDevices: availableDevices(for: config)
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

    private func appendTarget(named name: String) {
        let newConfig = DrillTargetsConfigData(
            seqNo: targetConfigs.count + 1,
            targetName: name,
            targetType: "ipsc",
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
            targetType: "ipsc",
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

    // Single active sheet state
    @State private var activeSheet: ActiveSheet? = nil

    private enum ActiveSheet: Identifiable {
        case name
        case type

        var id: Int { self == .name ? 0 : 1 }
    }

    private let iconNames = [
        "hostage",
        "ipsc",
        "paddle",
        "popper",
        "rotation",
        "special_1",
        "special_2",
    ]

    var body: some View {
        HStack(spacing: 16) {
            // 1) seqNo
//            Text("\(config.seqNo)")
//                .foregroundColor(.white)
//                .frame(width: 20, alignment: .leading)
//                .font(.system(size: 16, weight: .medium))

            // 2) Device (targetName)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("device", comment: "Device label"))
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                
                HStack {
                    Text(config.targetName.isEmpty ? "Select Device" : config.targetName)
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // chevron button only
                    Button(action: {
                        activeSheet = .name
                    }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .frame(width: 36, height: 24)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(activeSheet != nil)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .frame(maxWidth: .infinity)

            // Link icon
            Image(systemName: "link")
                .foregroundColor(.gray)
                .font(.system(size: 16))

            // 3) TargetType (icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("type", comment: "Type label"))
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                
                HStack {
                    Image(config.targetType)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)

                    Text(config.targetType)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // chevron button only
                    Button(action: {
                        activeSheet = .type
                    }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .frame(width: 36, height: 24)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(activeSheet != nil)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .listRowBackground(Color.black.opacity(0.8))
        .listRowInsets(EdgeInsets())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .name:
                TargetNamePickerView(
                    availableDevices: availableDevices,
                    selectedDevice: $config.targetName,
                    onDone: { activeSheet = nil }
                )
            case .type:
                TargetTypePickerView(
                    iconNames: iconNames,
                    selectedType: $config.targetType,
                    onDone: { activeSheet = nil }
                )
            }
        }
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
    
    TargetConfigListView(deviceList: mockDevices, targetConfigs: .constant(mockConfigs), onDone: {})
}
