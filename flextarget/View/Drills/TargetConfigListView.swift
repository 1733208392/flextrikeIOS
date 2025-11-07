import Foundation
import SwiftUI

struct TargetConfigListView: View {
    @Environment(\.dismiss) private var dismiss
    let deviceList: [NetworkDevice]
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void

    private let iconNames = [
        "hostage",
        "ipsc",
        "paddle",
        "popper",
        "rotation",
        "special_1",
        "special_2"
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    listView
                    AddButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // moved Add into the navigation bar as a '+' button
                    Button(action: { addNewTarget() }) {
                        Image(systemName: "plus")
                            .foregroundColor(.red)
                    }
                    .disabled(targetConfigs.count >= deviceList.count)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(targetConfigs.indices, id: \.self) { index in
                TargetRowView(
                    config: $targetConfigs[index],
                    availableDevices: availableDevices(for: targetConfigs[index])
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
        "special_2"
    ]

    var body: some View {
        HStack(spacing: 16) {
            // 1) seqNo
            Text("\(config.seqNo)")
                .foregroundColor(.white)
                .frame(width: 40, alignment: .leading)
                .font(.system(size: 16, weight: .medium))

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
