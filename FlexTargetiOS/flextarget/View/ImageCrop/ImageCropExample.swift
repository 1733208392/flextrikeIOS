import SwiftUI
import PhotosUI

/// Example integration of the ImageCropView
/// This demonstrates how to use the image cropping feature in your app
struct ImageCropExampleView: View {
    @State private var showImageCrop = false
    @State private var croppedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Display cropped result if available
                if let croppedImage = croppedImage {
                    VStack(spacing: 12) {
                        Text("Cropped Result")
                            .font(.headline)
                        
                        Image(uiImage: croppedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        Button(action: { self.croppedImage = nil }) {
                            Text("Clear")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No Cropped Image")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Launch button
                NavigationLink(destination: ImageCropViewWithCallback(onCropComplete: { image in
                    self.croppedImage = image
                    showImageCrop = false
                })) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Open Image Cropper")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Image Crop Example")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Wrapper view that allows you to handle the cropped image
struct ImageCropViewWithCallback: View {
    @StateObject private var viewModel = ImageCropViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastScale: CGFloat = 1.0
    @Environment(\.dismiss) var dismiss
    
    let onCropComplete: (UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Canvas Area
            VStack {
                if let image = viewModel.selectedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(viewModel.scale)
                            .offset(viewModel.offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            let newScale = viewModel.scale * delta
                                            viewModel.scale = min(max(newScale, 1.0), 5.0)
                                            lastScale = value
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            viewModel.offset = CGSize(
                                                width: value.translation.width,
                                                height: value.translation.height
                                            )
                                        }
                                )
                            )
                        
                        SilhouetteMaskView(width: 320, height: 320)
                        MaskGuideOverlay(frameWidth: 320, frameHeight: 320)
                    }
                    .frame(height: 320)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Select a Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .background(Color(.systemGray6))
                }
            }
            .background(Color.black)
            
            // Controls
            VStack(spacing: 16) {
                if viewModel.selectedImage != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Zoom")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1fx", viewModel.scale))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $viewModel.scale, in: 1.0...5.0)
                            .tint(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text("Choose Photo")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedPhotoItem) { newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    viewModel.selectedImage = uiImage
                                    viewModel.resetTransform()
                                }
                            }
                        }
                    }
                    
                    if viewModel.selectedImage != nil {
                        Button(action: { viewModel.resetTransform() }) {
                            HStack {
                                Image(systemName: "arrow.circlepath")
                                Text("Reset")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                if viewModel.selectedImage != nil {
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // TODO: Extract the cropped image from current view
                            // For now, pass the selected image
                            onCropComplete(viewModel.selectedImage!)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply Crop")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemBackground))
            
            Spacer()
        }
        .navigationTitle("Position & Crop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ImageCropExampleView()
}
