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
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerView
                    listView
                    completeButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Target Configuration")
                    .font(.title2)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(height: 60)
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
        .scrollContentBackground(.hidden)
        .onChange(of: targetConfigs) { _, _ in
            saveTargetConfigs()
        }
    }

    private var completeButton: some View {
        HStack(spacing: 20) {
            Button(action: {
                addNewTarget()
            }) {
                Text("Add")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .disabled(targetConfigs.count >= deviceList.count)
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
            targetType: "hostage",
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
        HStack {
            Text("\(config.seqNo)")
                .foregroundColor(.white)
                .frame(width: 40, alignment: .leading)

            Picker("Target Name", selection: $config.targetName) {
                ForEach(availableDevices, id: \.name) { device in
                    Text(device.name).tag(device.name)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(.white)
            .tint(.white)

            Spacer()

            Image(config.targetType)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)

            Picker("Target Type", selection: $config.targetType) {
                ForEach(iconNames, id: \.self) { icon in
                    HStack {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(icon)
                    }.tag(icon)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(.white)
            .tint(.white)
        }
        .listRowBackground(Color.gray.opacity(0.2))
    }
}

#Preview {
    TargetConfigListView(deviceList: [], targetConfigs: .constant([]), onDone: {})
}