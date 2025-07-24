import SwiftUI
import UIKit
import PhotosUI
import SwiftUI
import UIKit
import PhotosUI

/**
 `AddDrillConfigView` is a SwiftUI view for creating and configuring a new drill in the FlexTarget app.

 This view allows users to:
 - Enter a drill name and description.
 - Optionally add a demo video from the camera roll, with thumbnail preview, play, and delete functionality.
 - Configure drill parameters such as delay, sets, gun type, and target type.
 - Save the configured drill.

 ## Features

 - **Drill Name**: Editable text field with a pencil icon for editing and a clear button.
 - **Description**: Collapsible/expandable section with a single-line preview or a 5-line editor.
 - **Demo Video**:
    - Add a video from the camera roll using `PhotosPicker`.
    - Shows a progress indicator while generating a thumbnail.
    - Displays a cropped thumbnail with a play icon overlay and a delete button.
    - Tapping the thumbnail opens a video player sheet; tapping delete resets the video state.
 - **Drill Setup**: Button to configure sets, duration, and shots.
 - **Gun/Target Type**: Radio toggle for selecting gun and target types.
 - **Save**: Button to save the drill configuration.

 ## State Variables

 - `drillName`, `description`: User input for drill details.
 - `demoVideoURL`, `demoVideoThumbnail`: Video file URL and its thumbnail.
 - `selectedVideoItem`: The selected video from the picker.
 - `isGeneratingThumbnail`: Shows a progress view while generating the thumbnail.
 - `showVideoPlayer`: Controls the presentation of the video player sheet.
 - `isDescriptionExpanded`: Controls the expand/collapse state of the description and video section.
 - Other state variables for drill configuration.

 ## Helper Methods

 - `buildDrillConfig()`: Constructs a `DrillConfig` object from the current state.
 - `validateFields()`: Enables/disables the save button based on input validation.
 - `generateThumbnail(for:)`: Asynchronously generates a cropped thumbnail from a video URL.
 - `cropToAspect(image:aspectWidth:aspectHeight:)`: Crops a UIImage to a specified aspect ratio.

 ## Usage

 This view is typically presented as part of the drill creation workflow. It uses SwiftUI's state management and leverages system components like `PhotosPicker` and a custom `VideoPlayerView` for video playback.

 */

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
    @State private var isDescriptionExpanded: Bool = false
    @State private var showDrillSetupModal = false
    @State private var sets: [DrillSetConfigEditable] = DrillConfigStorage.shared.loadEditableSets()
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var demoVideoThumbnail: UIImage? = nil
    @State private var isGeneratingThumbnail: Bool = false
    @State private var showVideoPlayer: Bool = false
    @State private var thumbnailFileURL: URL? = nil
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
            thumbnailURL: thumbnailFileURL, // Pass the saved thumbnail URL
            numberOfSets: sets.count,
            startDelay: delayValue,
            pauseBetweenSets: pauseBetweenSets,
            sets: drillSets,
            targetType: targetType.rawValue,
            gunType: gunType.rawValue
        )
    }
    
    private func validateFields() -> Bool {
        // Title and description must not be empty
        guard !drillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        // Number of sets must be > 0
        guard sets.count > 0 else {
            return false
        }
        // For each set, duration, shots(NOTE: nil is infinte for shot), distance, pauseTime must not be nil or zero
        for set in sets {
            if set.duration <= 0 || set.distance <= 0 || set.pauseTime <= 0 {
                return false
            }
        }
        
        return true
    }
    
    @FocusState private var isDrillNameFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.ignoresSafeArea()
                    .onTapGesture {
                        isDrillNameFocused = false
                    }
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
                        ScrollView {
                        // Grouped Section: Drill Name, Description, Add Video
                        VStack(spacing: 20) {
                            // Drill Name
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center, spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        TextField("Drill Name", text: Binding(
                                            get: { String(drillName.prefix(30)) },
                                            set: { newValue in
                                                drillName = String(newValue.prefix(30))
                                            }
                                        ), onEditingChanged: { editing in
                                            isEditingName = editing
                                        })
                                        .focused($isDrillNameFocused)
                                        .foregroundColor(.white)
                                        .opacity(isEditingName ? 1 : 0.01) // Hide when not editing, but keep tappable
                                        .font(.title3)
                                        .padding(.vertical, 4)
                                        .background(Color.clear)
                                        .submitLabel(.done)
                                        if !isEditingName {
                                            Text(drillName.isEmpty ? "Drill Name" : drillName)
                                                .foregroundColor(.white)
                                                .font(.title3)
                                                .padding(.vertical, 4)
                                                .onTapGesture {
                                                    isEditingName = true
                                                    isDrillNameFocused = true
                                                }
                                        }
                                    }
                                    Spacer()
                                    Button(action: {
                                        if isEditingName {
                                            isEditingName = false
                                            isDrillNameFocused = false
                                        } else {
                                            isEditingName = true
                                            isDrillNameFocused = true
                                        }
                                    }) {
                                        Image(systemName: isEditingName ? "xmark" : "pencil")
                                            .foregroundColor(.red)
                                    }
                                }
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(isEditingName ? .red : Color.gray.opacity(0.5))
                                    .animation(.easeInOut, value: isEditingName)
                            }
                            
                            // Description & Add Video Section
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
                                        .frame(height: isDescriptionExpanded ? 120 : 24) // 5 lines or 1 line
                                        .foregroundColor(.white)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                        .disabled(!isDescriptionExpanded) // Only editable when expanded
                                    if description.isEmpty {
                                        Text("Enter description...")
                                            .font(.footnote)
                                            .foregroundColor(Color.white.opacity(0.4))
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                    }
                                }
                                if isDescriptionExpanded {
                                    // Demo Video Upload (only visible when expanded)
                                    PhotosPicker(
                                        selection: $selectedVideoItem,
                                        matching: .videos,
                                        photoLibrary: .shared()
                                    ) {
                                        VStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                .foregroundColor(.red)
                                                .frame(height: 120)
                                                .overlay(
                                                    Group {
                                                        if isGeneratingThumbnail {
                                                            ProgressView()
                                                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                                                .scaleEffect(1.5)
                                                        } else if let thumbnail = demoVideoThumbnail, demoVideoURL != nil {
                                                            ZStack {
                                                                Image(uiImage: thumbnail)
                                                                    .resizable()
                                                                    .scaledToFill()
                                                                    .frame(height: 120)
                                                                    .clipped()
                                                                    .cornerRadius(16)
                                                                    .contentShape(Rectangle())
                                                                // Play icon in center
                                                                if demoVideoURL != nil {
                                                                    Image(systemName: "play.circle.fill")
                                                                        .resizable()
                                                                        .frame(width: 48, height: 48)
                                                                        .foregroundColor(.white)
                                                                        .shadow(radius: 4)
                                                                        .opacity(0.85)
                                                                }
                                                                // Delete button at top right
                                                                VStack {
                                                                    HStack {
                                                                        Spacer()
                                                                        Button(action: {
                                                                            demoVideoThumbnail = nil
                                                                            demoVideoURL = nil
                                                                            selectedVideoItem = nil
                                                                        }) {
                                                                            Image(systemName: "xmark.circle.fill")
                                                                                .resizable()
                                                                                .frame(width: 28, height: 28)
                                                                                .foregroundColor(.red)
                                                                                .background(Color.white.opacity(0.8))
                                                                                .clipShape(Circle())
                                                                                .shadow(radius: 2)
                                                                        }
                                                                        .padding(8)
                                                                    }
                                                                    Spacer()
                                                                }
                                                            }
                                                            .onTapGesture {
                                                                showVideoPlayer = true
                                                            }
                                                        } else {
                                                            VStack {
                                                                Image(systemName: "video.badge.plus")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.red)
                                                                Text("Add Demo Video")
                                                                    .foregroundColor(.white)
                                                                    .font(.footnote)
                                                            }
                                                        }
                                                    }
                                                )
                                        }
                                    }
                                    .sheet(isPresented: $showVideoPlayer) {
                                        if let url = demoVideoURL {
                                            VideoPlayerView(url: url)
                                        }
                                    }
                                }
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
                                        Text("\(sets.count)")
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
                                        Text("\(sets.first?.duration ?? Int(setDuration))")
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
                                        Text("\(sets.first?.shots ?? shotsPerSet)")
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
                            Button(action: {
                                validateFields()
                                let config = buildDrillConfig()
                                DrillConfigStorage.shared.add(config)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Save Drill")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                        .onChange(of: selectedVideoItem) { newItem in
                        guard let item = newItem else { return }
                        isGeneratingThumbnail = true
                        Task {
                            // Try to get a URL first
                            if let url = try? await item.loadTransferable(type: URL.self) {
                                demoVideoURL = url
                                if let thumbnail = await generateThumbnail(for: url) {
                                    demoVideoThumbnail = thumbnail
                                    thumbnailFileURL = saveThumbnailToDocuments(thumbnail)
                                }
                            } else if let data = try? await item.loadTransferable(type: Data.self) {
                                // Save to temp file
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                                do {
                                    try data.write(to: tempURL)
                                    demoVideoURL = tempURL
                                    if let thumbnail = await generateThumbnail(for: tempURL) {
                                        demoVideoThumbnail = thumbnail
                                        thumbnailFileURL = saveThumbnailToDocuments(thumbnail)
                                    }
                                } catch {
                                    print("Failed to write video data to temp file: \(error)")
                                }
                            }
                            isGeneratingThumbnail = false
                        }
                    }
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
        }
    }
    // Helper to generate thumbnail from video URL
    func generateThumbnail(for url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let asset = AVAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 0.1, preferredTimescale: 600)
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let uiImage = UIImage(cgImage: cgImage)
                    // Crop to fit area (aspect fill 16:9)
                    let cropped = cropToAspect(image: uiImage, aspectWidth: 16, aspectHeight: 9)
                    continuation.resume(returning: cropped)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    // Helper to crop UIImage to aspect ratio
    func cropToAspect(image: UIImage, aspectWidth: CGFloat, aspectHeight: CGFloat) -> UIImage {
        let imgSize = image.size
        let targetAspect = aspectWidth / aspectHeight
        let imgAspect = imgSize.width / imgSize.height
        var cropRect: CGRect
        if imgAspect > targetAspect {
            // Wider than target: crop width
            let newWidth = imgSize.height * targetAspect
            let x = (imgSize.width - newWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: imgSize.height)
        } else {
            // Taller than target: crop height
            let newHeight = imgSize.width / targetAspect
            let y = (imgSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: imgSize.width, height: newHeight)
        }
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
    // Helper to save thumbnail image to documents directory
    func saveThumbnailToDocuments(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save thumbnail: \(error)")
            return nil
        }
    }
}

struct AddDrillConfigView_Previews: PreviewProvider {
    static var previews: some View {
        AddDrillConfigView()
    }
}
