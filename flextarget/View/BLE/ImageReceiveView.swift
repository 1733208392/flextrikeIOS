//
//  ImageReceiveView.swift
//  flextarget
//
//  Image receive view for receiving images from the device over BLE
//

import SwiftUI
import UIKit

struct ImageReceiveView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var bleManager: BLEManager
    @State private var isReceiving = false
    @State private var receivedImage: UIImage?
    @State private var showImagePreview = false
    @State private var progressPercentage: Int = 0
    @State private var statusMessage = ""
    @State private var errorMessage: String?
    @State private var showError = false
    
    private let imageReceiveManager = ImageReceiveManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text(NSLocalizedString("back", comment: "Back button"))
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                    Text(NSLocalizedString("receive_image", comment: "Receive Image"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Placeholder for spacing
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("")
                    }
                    .foregroundColor(.clear)
                }
                .padding()
                
                Spacer()
                
                // Content
                if isReceiving {
                    VStack(spacing: 20) {
                        // Receiving indicator
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text(NSLocalizedString("receiving_image", comment: "Receiving Image..."))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Progress bar
                        VStack(spacing: 8) {
                            ProgressView(value: Double(progressPercentage), total: 100)
                                .tint(.blue)
                            
                            Text("\(progressPercentage)%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Cancel button
                        Button(action: cancelReceive) {
                            Text(NSLocalizedString("cancel", comment: "Cancel button"))
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(NSLocalizedString("ready_receive_image", comment: "Ready to Receive Image"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("image_receive_description", comment: "Tap the button below to request an image from the device"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        // Request image button
                        Button(action: startReceive) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc")
                                Text(NSLocalizedString("request_image", comment: "Request Image"))
                            }
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                }
                
                Spacer()
            }
            
            // Image preview sheet
            if showImagePreview, let image = receivedImage {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text(NSLocalizedString("image_preview", comment: "Image Preview"))
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { showImagePreview = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        
                        // Image
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: saveImageToPhotos) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text(NSLocalizedString("save", comment: "Save button"))
                                }
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                            
                            Button(action: { showImagePreview = false }) {
                                Text(NSLocalizedString("close", comment: "Close button"))
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                    }
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .onAppear {
            setupImageReceiveManager()
        }
        .onDisappear {
            imageReceiveManager.cleanup()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text(NSLocalizedString("error", comment: "Error")),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK")))
            )
        }
    }
    
    private func setupImageReceiveManager() {
        // Register callbacks
        imageReceiveManager.onProgressUpdate = { progress, message in
            DispatchQueue.main.async {
                self.progressPercentage = progress
                self.statusMessage = message
            }
        }
        
        imageReceiveManager.onImageReceived = { image in
            DispatchQueue.main.async {
                self.receivedImage = image
                self.isReceiving = false
                self.showImagePreview = true
                self.progressPercentage = 0
                self.statusMessage = ""
            }
        }
        
        imageReceiveManager.onError = { error in
            DispatchQueue.main.async {
                self.errorMessage = error
                self.showError = true
                self.isReceiving = false
                self.progressPercentage = 0
            }
        }
    }
    
    private func startReceive() {
        isReceiving = true
        progressPercentage = 0
        statusMessage = ""
        imageReceiveManager.requestImageFromDevice()
    }
    
    private func cancelReceive() {
        isReceiving = false
        progressPercentage = 0
        statusMessage = ""
        imageReceiveManager.cancelReceive()
    }
    
    private func saveImageToPhotos() {
        guard let image = receivedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // TODO: Add success feedback
    }
}

#Preview {
    ImageReceiveView()
        .environmentObject(BLEManager.shared)
}
