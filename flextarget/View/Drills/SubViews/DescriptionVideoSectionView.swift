import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/**
 `DescriptionVideoSectionView` is a SwiftUI component that handles drill description and demo video functionality.
 
 This view provides:
 - Expandable/collapsible description editor
 - Video picker integration with PhotosPicker
 - Video thumbnail generation and display
 - Video playback functionality
 - Delete video functionality
 
 ## Features
 - Single-line preview or 5-line editor based on expansion state
 - Video thumbnail with play icon overlay
 - Progress indicator during thumbnail generation
 - Video player sheet presentation
 - Drag-and-drop style video picker UI
 */

struct DescriptionVideoSectionView: View {
    @Binding var description: String
    @Binding var demoVideoURL: URL?
    @Binding var selectedVideoItem: PhotosPickerItem?
    @Binding var demoVideoThumbnail: UIImage?
    @Binding var thumbnailFileURL: URL?
    @Binding var showVideoPlayer: Bool
    
    @State private var isGeneratingThumbnail: Bool = false
    @State private var isDownloadingVideo: Bool = false
    @FocusState private var isDescriptionFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description")
                    .foregroundColor(.white)
                    .font(.body)
                Spacer()
                if isDescriptionFocused {
                    Image(systemName: "checkmark")
                        .foregroundColor(.red)
                        .onTapGesture {
                            isDescriptionFocused = false
                        }
                }
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $description)
                    .frame(height: 120) // Fixed height for 5 lines
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.sentences)
                    .focused($isDescriptionFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                if description.isEmpty && !isDescriptionFocused {
                    Text("Enter description...")
                        .font(.footnote)
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .onTapGesture {
                            isDescriptionFocused = true
                        }
                }
            }
            
            // Demo Video Upload
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
        }
        .onChange(of: selectedVideoItem) {
            guard let item = selectedVideoItem else { return }
            isGeneratingThumbnail = true
            Task {
                // Ensure the loading flag is cleared on main when finished
                defer { Task { await MainActor.run { isGeneratingThumbnail = false } } }

                // 1) Try to get a URL representation and copy it into a temporary file (do NOT persist into Documents yet)
                if let url = try? await item.loadTransferable(type: URL.self) {
                    // Try to copy the selected file into app Documents for persistence
                    if let persisted = copyFileToAppStorage(from: url) {
                        await MainActor.run { demoVideoURL = persisted }
                        if let thumbnail = await generateThumbnail(for: persisted) {
                            // Save thumbnail into Documents as well
                            if let thumbData = thumbnail.jpegData(compressionQuality: 0.8), let savedThumb = writeDataToAppStorage(data: thumbData, ext: "jpg") {
                                await MainActor.run {
                                    demoVideoThumbnail = thumbnail
                                    thumbnailFileURL = savedThumb
                                }
                            } else {
                                await MainActor.run {
                                    demoVideoThumbnail = thumbnail
                                }
                            }
                        }
                        return
                    }
                }

                // 2) Fallback: try to load raw Data and write to app storage
                await MainActor.run { isDownloadingVideo = true }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // Write the raw data into Documents for persistence
                    if let written = writeDataToAppStorage(data: data, ext: "mov") {
                        await MainActor.run { demoVideoURL = written }
                        if let thumbnail = await generateThumbnail(for: written) {
                            if let thumbData = thumbnail.jpegData(compressionQuality: 0.8), let savedThumb = writeDataToAppStorage(data: thumbData, ext: "jpg") {
                                await MainActor.run {
                                    demoVideoThumbnail = thumbnail
                                    thumbnailFileURL = savedThumb
                                }
                            } else {
                                await MainActor.run {
                                    demoVideoThumbnail = thumbnail
                                }
                            }
                        }
                        return
                    }
                }
                await MainActor.run { isDownloadingVideo = false }

                // If we got here, nothing usable was produced
                print("Failed to obtain a usable video file from selected item")
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
                    // Return a default image if thumbnail generation fails
                    let defaultImage = UIImage(systemName: "video") ?? UIImage()
                    continuation.resume(returning: defaultImage)
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
    // Helper: copy a file URL into the app Documents directory and return the new URL
    func copyFileToAppStorage(from url: URL) -> URL? {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension))
        do {
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
            return dest
        } catch {
            print("Failed to copy file to app storage: \(error)")
            return nil
        }
    }

    // Helper: write Data into app Documents directory and return file URL
    func writeDataToAppStorage(data: Data, ext: String) -> URL? {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try data.write(to: dest)
            return dest
        } catch {
            print("Failed to write data to app storage: \(error)")
            return nil
        }
    }

    // Helper: copy a file URL into temporary directory and return the temp URL
    func copyFileToTemp(from url: URL) -> URL? {
        let fileManager = FileManager.default
        let temp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension))
        do {
            if fileManager.fileExists(atPath: temp.path) {
                try fileManager.removeItem(at: temp)
            }
            try fileManager.copyItem(at: url, to: temp)
            return temp
        } catch {
            print("Failed to copy file to temp: \(error)")
            return nil
        }
    }

    // Helper: write Data into temp directory and return the temp URL
    func writeDataToTemp(data: Data, ext: String) -> URL? {
        let fileManager = FileManager.default
        let temp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try data.write(to: temp)
            return temp
        } catch {
            print("Failed to write data to temp: \(error)")
            return nil
        }
    }

    
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

struct DescriptionVideoSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                DescriptionVideoSectionView(
                    description: .constant("Sample description"),
                    demoVideoURL: .constant(nil),
                    selectedVideoItem: .constant(nil),
                    demoVideoThumbnail: .constant(nil),
                    thumbnailFileURL: .constant(nil),
                    showVideoPlayer: .constant(false)
                )
                .padding()
            }
        }
    }
}
