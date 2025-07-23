import SwiftUI

struct AddDrillConfigView: View {
    @State private var drillName: String = ""
    @State private var isEditingName = false
    @State private var description: String = ""
    @State private var isEditingDescription = false
    @State private var demoVideoURL: URL? = nil
    @State private var showVideoPicker = false
    @State private var delayType: DelayType = .fixed
    @State private var delayValue: Double = 0
    @State private var numberOfSets: Int = 1
    @State private var setDuration: Double = 30
    @State private var shotsPerSet: Int = 5
    @State private var gunType: GunType = .airsoft
    @State private var targetType: TargetType = .paper
    @State private var isSendEnabled: Bool = false
    @State private var isDescriptionExpanded: Bool = false
    @State private var showDrillSetupModal = false
    @State private var sets: [DrillSetConfigEditable] = DrillConfigStorage.shared.loadEditableSets()
    @Environment(\.presentationMode) var presentationMode
    
    enum DelayType: String, CaseIterable { case fixed, random }
    enum GunType: String, CaseIterable { case airsoft = "airsoft", laser = "laser" }
    enum TargetType: String, CaseIterable { case paper = "paper", electronic = "electronic" }
    
    private func buildDrillConfig() -> DrillConfig {
        // Step 1: Map sets to DrillSetConfig
        let drillSets = sets.map { set in
            DrillSetConfig(
                duration: Double(set.duration),
                numberOfShots: set.shots ?? -1, // -1 for infinite
                distance: Double(set.distance)
            )
        }

        // Step 2: Calculate pauseBetweenSets
        let pauseBetweenSets: Double = {
            guard let firstSet = sets.first else { return 0 }
            return Double(firstSet.pauseTime)
        }()

        // Step 3: Return DrillConfig
        return DrillConfig(
            name: drillName,
            description: description,
            demoVideoURL: demoVideoURL,
            numberOfSets: sets.count,
            startDelay: delayValue,
            pauseBetweenSets: pauseBetweenSets,
            sets: drillSets,
            targetType: targetType.rawValue,
            gunType: gunType.rawValue
        )
    }
    
    private func validateFields() {
        isSendEnabled = !drillName.isEmpty && !description.isEmpty && numberOfSets > 0 && setDuration > 0 && shotsPerSet > 0
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Title Bar
                HStack {
                    Button(action: {
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.red))
                    }
                    Spacer()
                    Text("Add a Drill")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    // Placeholder for alignment
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal)
                .frame(height: 56)
                .background(Color.red)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // History Record Button
                        HStack {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.red, lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.clear))
                                .frame(height: 36)
                                .overlay(
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.red)
                                            .font(.title3)
                                        Text("History Record")
                                            .foregroundColor(.white)
                                            .font(.footnote)
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.top)
                        }
                        // Grouped Section: Drill Name, Description, Add Video
                        VStack(spacing: 20) {
                            // Drill Name
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center, spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        // Use a hidden UITextField for focus control
                                        TextField("Drill Name", text: $drillName, onEditingChanged: { editing in
                                            isEditingName = editing
                                        })
                                        .foregroundColor(.white)
                                        .opacity(isEditingName ? 1 : 0.01) // Hide when not editing, but keep tappable
                                        .disabled(!isEditingName)
                                        .font(.title3)
                                        .padding(.vertical, 4)
                                        .background(Color.clear)
                                        if !isEditingName {
                                            Text(drillName.isEmpty ? "Drill Name" : drillName)
                                                .foregroundColor(.white)
                                                .font(.title3)
                                                .padding(.vertical, 4)
                                                .onTapGesture {
                                                    isEditingName = true
                                                }
                                        }
                                    }
                                    Spacer()
                                    if isEditingName {
                                        Button(action: {
                                            drillName = ""
                                            isEditingName = false
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    } else {
                                        Button(action: {
                                            isEditingName = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(isEditingName ? .red : Color.gray.opacity(0.5))
                                    .animation(.easeInOut, value: isEditingName)
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Description")
                                        .foregroundColor(.white)
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.red)
                                        .onTapGesture {
                                            withAnimation {
                                                isDescriptionExpanded.toggle()
                                            }
                                        }
                                }
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $description)
                                        .frame(height: isDescriptionExpanded ? 180 : 54)
                                        .foregroundColor(.white)
                                        .scrollContentBackground(.hidden) // <-- This hides the default background
                                        .background(Color.clear)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                isDescriptionExpanded = true
                                            }
                                        }
                                    if description.isEmpty {
                                        Text("Enter description...")
                                            .foregroundColor(Color.white.opacity(0.4))
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                    }
                                }
                            }
                            
                            // Demo Video Upload
                            Button(action: { showVideoPicker = true }) {
                                VStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundColor(.red)
                                        .frame(height: 120)
                                        .overlay(
                                            VStack {
                                                Image(systemName: "video.badge.plus")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.red)
                                                Text("Add Demo Video")
                                                    .foregroundColor(.white)
                                                    .font(.footnote)
                                            }
                                        )
                                }
                            }
                            .sheet(isPresented: $showVideoPicker) {
                                // TODO: Video picker/recorder
                                Text("Video Picker/Recorder (TBD)")
                                    .foregroundColor(.white)
                                    .background(Color.black)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Delay of Set Starting
                        HStack {
                            Text("Delay(s)")
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    delayType = (delayType == .random) ? .fixed : .random
                                    if delayType == .random {
                                        delayValue = 2 // default random min
                                    } else {
                                        delayValue = 0 // default fixed
                                    }
                                }
                            }) {
                                Image(systemName: "shuffle")
                                    .foregroundColor(delayType == .random ? .red : .gray)
                                    .padding(10)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                                    .overlay(
                                        Circle().stroke(delayType == .random ? Color.red : Color.gray, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                            if delayType == .random {
                                // Random mode: show spinner for 2...4
                                Picker("Random Delay", selection: $delayValue) {
                                    ForEach(1...60, id: \.self) { value in
                                        Text("\(value)")
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 60)
                                .clipped()
                            } else {
                                // Fixed mode: show stepper
                                
                                Text("2...4")
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        
                        // Drill Setup Field
                        Button(action: {
                            showDrillSetupModal = true
                        }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundColor(.red)
                                    Text("Drills Setup")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                HStack(alignment: .center, spacing: 0) {
                                    VStack {
                                        Text("\(numberOfSets)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("Sets")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer(minLength: 0)
                                    Text("|")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                    Spacer(minLength: 0)
                                    VStack {
                                        Text("\(Int(setDuration))")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("Seconds/Set")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer(minLength: 0)
                                    Text("|")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                    Spacer(minLength: 0)
                                    VStack {
                                        Text("\(shotsPerSet)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("Shots/Set")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .sheet(isPresented: $showDrillSetupModal, onDismiss: {
                            DrillConfigStorage.shared.saveEditableSets(sets)
                        }) {
                            DrillSetupSheetView(sets: $sets, isPresented: $showDrillSetupModal)
                        }
                        Spacer()
                        
                        // Gun Type Radio Toggle
                        HStack {
                            Text("Gun")
                                .foregroundColor(.red)
                            Spacer()
                            HStack(spacing: 20) {
                                ForEach(GunType.allCases, id: \.self) { type in
                                    Button(action: {
                                        gunType = type
                                    }) {
                                        HStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.red, lineWidth: 2)
                                                    .frame(width: 24, height: 24)
                                                if gunType == type {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 14, height: 14)
                                                }
                                            }
                                            Text(type.rawValue.capitalized)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Bottom Buttons
                        HStack {
                            // Removed Cancel button
                            Button(action: {
                                let config = buildDrillConfig()
                                DrillConfigStorage.shared.add(config)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Save Drill")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isSendEnabled ? Color.red : Color.gray)
                                    .cornerRadius(8)
                            }
                            .disabled(!isSendEnabled)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
//                    .onChange(of: drillName) { _ in validateFields() }
//                    .onChange(of: description) { _ in validateFields() }
//                    .onChange(of: numberOfSets) { _ in validateFields() }
//                    .onChange(of: setDuration) { _ in validateFields() }
//                    .onChange(of: shotsPerSet) { _ in validateFields() }
//                    .onChange(of: sets) { _ in
//                        numberOfSets = sets.count
//                        setDuration = sets.first?.duration != nil ? Double(sets.first!.duration) : 30
//                        shotsPerSet = sets.first?.shots ?? 5
//                        validateFields()
//                    }
//                    .onAppear { validateFields() }
                }
            }
        }
    }
}

struct AddDrillConfigView_Previews: PreviewProvider {
    static var previews: some View {
        AddDrillConfigView()
    }
}
