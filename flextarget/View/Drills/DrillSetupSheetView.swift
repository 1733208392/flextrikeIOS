import SwiftUI

struct DrillSetConfigEditable: Identifiable, Codable {
    let id: UUID
    var duration: Int
    var shots: Int? // nil means infinite
    var distance: Int
    var pauseTime: Int
    
    init(id: UUID = UUID(), duration: Int, shots: Int?, distance: Int, pauseTime: Int) {
        self.id = id
        self.duration = duration
        self.shots = shots
        self.distance = distance
        self.pauseTime = pauseTime
    }
}

extension DrillSetConfigEditable {
    func toDrillSetConfig() -> DrillSetConfig {
        DrillSetConfig(
            id: self.id,
            duration: TimeInterval(self.duration),
            numberOfShots: self.shots ?? Int.max, // Use Int.max for infinite
            distance: Double(self.distance)
        )
    }
}

struct DrillSetupSheetView: View {
    @Binding var sets: [DrillSetConfigEditable]
    @Binding var isPresented: Bool
    
    let durationRange = Array(5...30)
    let shotsRange = Array(1...12)
    let distanceOptions = [3, 5, 10, 30, 50]
    let pauseOptions = [10, 30, 60]
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set \(idx + 1)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        VStack(spacing: 0) {
                            // Duration
                            HStack {
                                Text("Duration(sec)")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                                Spacer()
                                Picker("Duration", selection: $sets[idx].duration) {
                                    ForEach(durationRange, id: \.self) { v in
                                        Text("\(v)").foregroundColor(.red)
                                            .font(.system(size: 22, weight: .bold))
                                            .rotationEffect(.degrees(90))
                                            .bold()
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                            }
                            Divider().background(Color.gray)
                            // Shots
                            HStack {
                                Text("Shots")
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Shots", selection: Binding<Int?>(
                                    get: { sets[idx].shots },
                                    set: { sets[idx].shots = $0 }
                                )) {
                                    Image(systemName: "infinity")
                                        .foregroundColor(.red)
                                        .font(.system(size: 22, weight: .bold))
                                        .rotationEffect(.degrees(90))
                                        .tag(nil as Int?)
                                    ForEach(shotsRange, id: \.self) { v in
                                        Text("\(v)").foregroundColor(.red)
                                            .font(.system(size: 22, weight: .bold))
                                            .rotationEffect(.degrees(90))
                                            .tag(Optional(v))
                                            .bold()
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                            }
                            Divider().background(Color.gray)
                            // Distance
                            HStack {
                                Text("Distance")
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Distance", selection: $sets[idx].distance) {
                                    ForEach(distanceOptions, id: \.self) { v in
                                        Text("\(v)").foregroundColor(.red)
                                            .font(.system(size: 22, weight: .bold))
                                            .rotationEffect(.degrees(90))
                                            .bold()
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                            }
                            Divider().background(Color.gray)
                            // Pause Time
                            HStack {
                                Text("Pause Time(sec)")
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Pause", selection: $sets[idx].pauseTime) {
                                    ForEach(pauseOptions, id: \.self) { v in
                                        Text("\(v)").foregroundColor(.red)
                                            .font(.system(size: 22, weight: .bold))
                                            .rotationEffect(.degrees(90))
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                            }
                        }
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear) // Clear the default row background
                    .padding(.horizontal)
                }
                .onDelete(perform: deleteSet)
            }
            .listStyle(PlainListStyle())
            .background(Color.black)
            Button(action: {
                sets.append(DrillSetConfigEditable(duration: 10, shots: 5, distance: 5, pauseTime: 10))
            }) {
                Text("Add a New Set")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private func deleteSet(at offsets: IndexSet) {
        sets.remove(atOffsets: offsets)
    }
}
