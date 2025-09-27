import SwiftUI
import PhotosUI
import AVFoundation

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
    
    @State private var isDescriptionExpanded: Bool = true
    @State private var isGeneratingThumbnail: Bool = false
    
    var body: some View {
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
            }
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