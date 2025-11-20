import SwiftUI
import PhotosUI

struct ImageCropView: View {
    @StateObject private var viewModel = ImageCropViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    
    // Canvas dimensions (9:16 portrait ratio)
    let canvasRatio: CGFloat = 9.0 / 16.0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Canvas Area
                VStack {
                    if let image = viewModel.selectedImage {
                        ZStack {
                            // Image with transform
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(viewModel.scale)
                                .offset(CGSize(
                                    width: viewModel.offset.width + dragTranslation.width,
                                    height: viewModel.offset.height + dragTranslation.height
                                ))
//                                .gesture(
//                                    MagnificationGesture()
//                                        .onChanged { value in
//                                            let delta = value / lastScale
//                                            let newScale = viewModel.scale * delta
//                                            viewModel.scale = min(max(newScale, 1.0), 5.0)
//                                            lastScale = value
//                                        }
//                                        .onEnded { _ in
//                                            lastScale = 1.0
//                                        }
//                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragTranslation = value.translation
                                        }
                                        .onEnded { _ in
                                            viewModel.offset = CGSize(
                                                width: viewModel.offset.width + dragTranslation.width,
                                                height: viewModel.offset.height + dragTranslation.height
                                            )
                                            dragTranslation = .zero
                                        }
                                )
                            
                            // Silhouette mask overlay
                            SilhouetteMaskView(width: 320, height: 320)
                                .allowsHitTesting(false)
                            
//                            // Dark mask guide
//                            MaskGuideOverlay(frameWidth: 480, frameHeight: 480)
                        }
                        .frame(height: 480)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    } else {
                        // Placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Select a Photo")
                                .font(.headline)
                            Text("Tap the button below to choose an image from your library")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .background(Color(.systemGray6))
                    }
                }
                .background(Color.black)
                
                // Controls Section
                VStack(spacing: 16) {
                    // Scale Slider
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
                    
                    // Action Buttons
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
                                        lastOffset = .zero
                                        dragTranslation = .zero
                                    }
                                }
                            }
                        }
                        
                        if viewModel.selectedImage != nil {
                            Button(action: {
                                viewModel.resetTransform()
                                lastOffset = .zero
                                dragTranslation = .zero
                            }) {
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
                    
                    // Preview and Crop Buttons
                    if viewModel.selectedImage != nil {
                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.showLivePreview.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("Preview")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(viewModel.showLivePreview ? Color.red.opacity(0.7) : Color(.systemGray5))
                                .foregroundColor(viewModel.showLivePreview ? .white : .primary)
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                // TODO: Save cropped image or proceed with it
                                // viewModel.cropImage(within: cropFrame, canvasSize: canvasSize)
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
            }
            .navigationTitle("Position & Crop")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showLivePreview) {
                LivePreviewSheet(viewModel: viewModel)
            }
        }
    }
}

struct LivePreviewSheet: View {
    @ObservedObject var viewModel: ImageCropViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main preview with mask
                ZStack {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(viewModel.scale)
                            .offset(viewModel.offset)
                    }
                    
                    // Silhouette mask guide
                    SilhouetteMaskView(width: 180, height: 320)
                    
                    // Dark overlay mask
                    MaskGuideOverlay(frameWidth: 180, frameHeight: 320)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .clipped()
                .background(Color.black)
                
                // Information
                VStack(spacing: 12) {
                    Text("Live Preview")
                        .font(.headline)
                    Text("This shows how your photo will be positioned and cropped with the silhouette guide.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Text("Zoom Level:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1fx", viewModel.scale))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Offset:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "x: %.0f, y: %.0f", viewModel.offset.width, viewModel.offset.height))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Close Preview")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(16)
            }
            .navigationTitle("Live Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ImageCropView()
}
