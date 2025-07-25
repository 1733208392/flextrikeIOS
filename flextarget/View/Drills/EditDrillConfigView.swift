import SwiftUI
import PhotosUI
import AVFoundation

struct EditDrillConfigView: View {
    @State private var drillName: String
    @State private var isEditingName = false
    @State private var description: String
    @State private var isEditingDescription = false
    @State private var demoVideoURL: URL?
    @State private var demoVideoThumbnailUrl: URL? = nil
    @State private var showVideoPicker = false
    @State private var delayType: AddDrillConfigView.DelayType
    @State private var delayValue: Double
    @State private var numberOfSets: Int
    @State private var setDuration: Double
    @State private var shotsPerSet: Int
    @State private var gunType: AddDrillConfigView.GunType
    @State private var targetType: AddDrillConfigView.TargetType
    @State private var isDescriptionExpanded: Bool = true
    @State private var showDrillSetupModal = false
    @State private var sets: [DrillSetConfigEditable]
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var isGeneratingThumbnail: Bool = false
    @State private var showVideoPlayer: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isDrillNameFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    let originalDrill: DrillConfig

    init(drill: DrillConfig) {
        self.originalDrill = drill
        _drillName = State(initialValue: drill.name)
        _description = State(initialValue: drill.description)
        _demoVideoURL = State(initialValue: drill.demoVideoURL)
        _demoVideoThumbnailUrl = State(initialValue: drill.thumbnailURL)
        _delayType = State(initialValue: .fixed)
        _delayValue = State(initialValue: drill.startDelay)
        _numberOfSets = State(initialValue: drill.sets.count)
        _setDuration = State(initialValue: drill.sets.first?.duration ?? 30)
        _shotsPerSet = State(initialValue: drill.sets.first?.numberOfShots ?? 5)
        _gunType = State(initialValue: AddDrillConfigView.GunType(rawValue: drill.gunType) ?? .airsoft)
        _targetType = State(initialValue: AddDrillConfigView.TargetType(rawValue: drill.targetType) ?? .paper)
        _sets = State(initialValue: drill.sets.map { DrillSetConfigEditable(from: $0) })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // History Button
                Button(action: { /* Show history */ }) {
                    
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(Color(red: 1, green: 0.38, blue: 0.22))
                        Text("Training History")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(red: 1, green: 0.38, blue: 0.22), lineWidth: 2)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                // Content in the middle
                ScrollView {
                    // Drill Name & Description Card
                    VStack(alignment: .leading, spacing: 0) {
                        // Title and Chevron Button
                        HStack(alignment: .center) {
                            if isEditingName {
                                TextField("Drill Name", text: $drillName)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .cornerRadius(8)
                                    .focused($isDrillNameFocused)
                            } else {
                                Text(drillName)
                                    .foregroundColor(.white)
                                    .font(.title3)
                                    .onTapGesture { isEditingName = true; isDrillNameFocused = true }
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
                                    .foregroundColor(Color(red: 1, green: 0.38, blue: 0.22))
                            }
                        }
                        .padding(.bottom, 2)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(isEditingName ? .red : Color.gray.opacity(0.5))
                            .animation(.easeInOut, value: isEditingName)
                        HStack(alignment: .top) {
                            if isDescriptionExpanded {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        if isEditingDescription {
                                            TextEditor(text: $description)
                                                .foregroundColor(.white)
                                                .scrollContentBackground(.hidden)
                                                .padding(8)
                                                .cornerRadius(8)
                                                .focused($isDescriptionFocused)
                                        } else {
                                            Text(description)
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                                .padding(.bottom, 2)
                                                .onTapGesture {
                                                    isEditingDescription = true
                                                    isDescriptionFocused = true
                                                }
                                        }
                                        Spacer()
                                        Button(action: {
                                            isDescriptionExpanded.toggle()
                                            isDescriptionFocused.toggle()
                                        }) {
                                            Image(systemName: isDescriptionExpanded ? "chevron.down" : "chevron.up")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    // Demo Video Area
                                    VStack {
                                        ZStack {
                                            if fileExists(at: demoVideoThumbnailUrl), demoVideoURL != nil {
                                                if let url = demoVideoThumbnailUrl {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            Color.gray.opacity(0.2)
                                                        case .success(let image):
                                                            image
                                                                .resizable()
                                                                .aspectRatio(16/9, contentMode: .fill)
                                                                .frame(height: 200)
                                                                .clipped()
                                                        case .failure:
                                                            Color.gray.opacity(0.2)
                                                        @unknown default:
                                                            Color.gray.opacity(0.2)
                                                        }
                                                    }
                                                }
                                                // Play icon only if video exists
                                                Image(systemName: "play.circle.fill")
                                                    .resizable()
                                                    .frame(width: 56, height: 56)
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 8)
                                                    .onTapGesture {
                                                        showVideoPlayer = true
                                                    }
                                            } else {
                                                Color.gray.opacity(0.2)
                                                // Directly show the camera roll picker when tapping the AddVideo icon
                                                PhotosPicker(selection: $selectedVideoItem, matching: .videos, photoLibrary: .shared()) {
                                                    Image(systemName: "video.badge.plus")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.red)
                                                }
                                            }
                                        }
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.top, 12)
                                        // Video Action Buttons
                                        HStack(spacing: 16) {
                                            Button(action: {
                                                demoVideoURL = nil
                                                demoVideoThumbnailUrl = nil
                                                selectedVideoItem = nil
                                            }) {
                                                HStack {
                                                    Image(systemName: "trash")
                                                    Text("Delete")
                                                }
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 24)
                                                .background(Color(red: 0.22, green: 0.22, blue: 0.22))
                                                .cornerRadius(24)
                                            }
                                            PhotosPicker(selection: $selectedVideoItem, matching: .videos, photoLibrary: .shared()) {
                                                HStack {
                                                    Image(systemName: "video")
                                                    Text("Select")
                                                }
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 24)
                                                .background(Color(red: 1, green: 0.38, blue: 0.22))
                                                .cornerRadius(24)
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            } else {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(description)
                                        .foregroundColor(.gray)
                                        .font(.system(size: 15))
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                    Spacer()
                                    Button(action: {
                                        isDescriptionExpanded.toggle()
                                        isDescriptionFocused.toggle()
                                    }) {
                                        Image(systemName: isDescriptionExpanded ? "chevron.down" : "chevron.up")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                        
                    // Delay Card
                    HStack {
                        Text("延迟(秒)")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Color(red: 1, green: 0.38, blue: 0.22))
                            .font(.system(size: 24))
                        Text("2...4")
                            .foregroundColor(Color(red: 1, green: 0.38, blue: 0.22))
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding()
                    .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    // Step Design Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .foregroundColor(Color(red: 1, green: 0.38, blue: 0.22))
                            Text("设计步骤")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.bottom, 8)
                        HStack {
                            VStack {
                                Text("2")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                                Text("组")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            Spacer()
                            VStack {
                                Text("5s")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                                Text("时长")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            Spacer()
                            VStack {
                                Text("∞")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                                Text("射击次数")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    // Gun Type Card
                    HStack {
                        Text("枪支类型")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        HStack(spacing: 16) {
                            HStack {
                                Circle()
                                    .fill(gunType == .airsoft ? Color(red: 1, green: 0.38, blue: 0.22) : Color.clear)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                Text("airsoft")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                            .onTapGesture { gunType = .airsoft }
                            HStack {
                                Circle()
                                    .fill(gunType == .laser ? Color(red: 1, green: 0.38, blue: 0.22) : Color.clear)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                Text("激光")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                            .onTapGesture { gunType = .laser }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.13, green: 0.13, blue: 0.13))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    Spacer()
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)

                // Bottom Buttons
                HStack(spacing: 24) {
                    Button(action: { /* Save action */ }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存")
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.22, green: 0.22, blue: 0.22))
                        .cornerRadius(32)
                    }
                    Button(action: { /* Send action */ }) {
                        HStack {
                            Image(systemName: "paperplane")
                            Text("发送练习")
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 1, green: 0.38, blue: 0.22))
                        .cornerRadius(32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: selectedVideoItem) { newItem in
            guard let newItem = newItem else { return }
            isGeneratingThumbnail = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov") as URL? {
                    do {
                        try data.write(to: tempURL)
                        demoVideoURL = tempURL
                        if let thumbnail = generateThumbnail(for: tempURL) {
                            let thumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                            if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
                                try? jpegData.write(to: thumbnailURL)
                                demoVideoThumbnailUrl = thumbnailURL
                            }
                        }
                    } catch {
                        print("Failed to save video or generate thumbnail: \(error)")
                    }
                }
                isGeneratingThumbnail = false
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let demoVideoURL = demoVideoURL {
                VideoPlayerView(url: demoVideoURL)
            }
        }
    }

    // Helper to generate thumbnail from video URL
    func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }

    // Helper to check if a file exists at a given URL
    func fileExists(at url: URL?) -> Bool {
        guard let url = url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

extension DrillSetConfigEditable {
    init(from set: DrillSetConfig) {
        self.init(duration: Int(set.duration), shots: set.numberOfShots, distance: Int(set.distance), pauseTime: 5) // Adjust pauseTime if needed
    }
}
