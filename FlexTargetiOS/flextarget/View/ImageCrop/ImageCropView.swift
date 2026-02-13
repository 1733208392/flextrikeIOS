import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
import Photos
#endif

struct ImageCropView: View {
    private enum TransferOverlayState {
        case waiting
        case transferring
        case notReady
    }
    @StateObject private var viewModel = ImageCropViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var guideAspect: CGFloat? = nil
    @State private var currentContainerSize: CGSize? = nil
    @State private var currentGuideSize: CGSize? = nil
    @State private var transferManager = ImageTransferManager()
    @State private var transferInProgress: Bool = false
    @State private var transferProgress: Int = 0
    @State private var showTransferOverlay: Bool = false
    @State private var showCancelAlert: Bool = false
    @State private var transferOverlayState: TransferOverlayState = .notReady
    @State private var transferWaitingObserver: NSObjectProtocol?
    @State private var transferTimeoutObserver: NSObjectProtocol?
    
    // Canvas dimensions (9:16 portrait ratio)
    let canvasRatio: CGFloat = 9.0 / 16.0

    // Compute the displayed guide size given the container size and optional guide aspect
    private func computeGuideSize(containerSize: CGSize) -> CGSize {
        if let aspect = guideAspect {
            let containerAspect = containerSize.width / containerSize.height
            if aspect > containerAspect {
                // guide is wider than container -> fit width
                let w = containerSize.width
                let h = w / aspect
                return CGSize(width: w, height: h)
            } else {
                // guide is taller (or equal) -> fit height
                let h = containerSize.height
                let w = min(containerSize.width, h * aspect)
                return CGSize(width: w, height: h)
            }
        } else {
            // unknown aspect: fallback to full container
            return containerSize
        }
    }

    // Use a lightweight AnyView wrapper around a small `MainCanvasView` struct to help the compiler.
    private func mainCanvasView() -> some View {
        return AnyView(
            MainCanvasView(
                viewModel: viewModel,
                dragTranslation: $dragTranslation,
                lastScale: $lastScale,
                pinchScale: $pinchScale,
                currentContainerSize: $currentContainerSize,
                currentGuideSize: $currentGuideSize,
                guideAspect: $guideAspect
            )
        )
    }

    private struct MainCanvasView: View {
        @ObservedObject var viewModel: ImageCropViewModel
        @Binding var dragTranslation: CGSize
        @Binding var lastScale: CGFloat
        @Binding var pinchScale: CGFloat
        @Binding var currentContainerSize: CGSize?
        @Binding var currentGuideSize: CGSize?
        @Binding var guideAspect: CGFloat?

        private let containerHeight: CGFloat = 480

        var body: some View {
            GeometryReader { geo in
                let containerSize = CGSize(width: geo.size.width, height: containerHeight)
                let guideSize = computeGuideSizeStatic(containerSize: containerSize, guideAspect: guideAspect)
                let cropSize = guideSize

                ZStack {
                    if let image = viewModel.selectedImage {
                        let effectiveOffset = viewModel.clampedOffset(for: CGSize(width: viewModel.offset.width + dragTranslation.width,
                                                                                  height: viewModel.offset.height + dragTranslation.height), containerSize: containerSize, cropSize: cropSize)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: containerHeight)
                            .scaleEffect(viewModel.scale, anchor: .center)
                            .offset(x: effectiveOffset.width, y: effectiveOffset.height)
                            .clipped()
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let proposed = CGSize(width: viewModel.offset.width + value.translation.width,
                                                              height: viewModel.offset.height + value.translation.height)
                                        let clamped = viewModel.clampedOffset(for: proposed, containerSize: containerSize, cropSize: cropSize)
                                        dragTranslation = CGSize(width: clamped.width - viewModel.offset.width,
                                                                 height: clamped.height - viewModel.offset.height)
                                    }
                                    .onEnded { _ in
                                        let proposed = CGSize(width: viewModel.offset.width + dragTranslation.width,
                                                              height: viewModel.offset.height + dragTranslation.height)
                                        viewModel.offset = viewModel.clampedOffset(for: proposed, containerSize: containerSize, cropSize: cropSize)
                                        dragTranslation = .zero
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        pinchScale = value
                                        let proposed = lastScale * pinchScale
                                        let clamped = min(max(proposed, viewModel.minScale), viewModel.maxScale)
                                        viewModel.scale = clamped
                                        viewModel.offset = viewModel.clampedOffset(for: viewModel.offset, containerSize: containerSize, cropSize: cropSize, scaleOverride: viewModel.scale)
                                    }
                                    .onEnded { _ in
                                        lastScale = viewModel.scale
                                        pinchScale = 1.0
                                    }
                            )
                            .onChange(of: viewModel.scale) { _ in
                                viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                            }
                            .onAppear {
                                viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                            }
                            .onChange(of: viewModel.selectedImage) { _ in
                                viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                            }
                    }

                    if let cropped = viewModel.croppedImage {
                        Image(uiImage: cropped)
                            .resizable()
                            .scaledToFill()
                            .frame(width: guideSize.width, height: guideSize.height)
                            .clipped()
                            .allowsHitTesting(false)
                            .position(x: containerSize.width / 2.0, y: containerSize.height / 2.0)
                    }

                    Image("custom-target-guide")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: guideSize.width, height: guideSize.height)
                        .allowsHitTesting(false)
                        .onAppear {
                            DispatchQueue.main.async {
                                if containerSize.width > 0 {
                                    currentContainerSize = containerSize
                                    currentGuideSize = guideSize
                                }
                            }
                        }
                        .onChange(of: containerSize) { newSize in
                            DispatchQueue.main.async {
                                if newSize.width > 0 {
                                    currentContainerSize = newSize
                                    currentGuideSize = computeGuideSizeStatic(containerSize: newSize, guideAspect: guideAspect)
                                }
                            }
                        }

                    let borderInset: CGFloat = 10.0
                    Image("custom-target-border")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: guideSize.width+borderInset, height: guideSize.height+borderInset)
                        .allowsHitTesting(false)
                }
                .frame(height: containerHeight)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            }
            .frame(height: containerHeight)
        }

        private func computeGuideSizeStatic(containerSize: CGSize, guideAspect: CGFloat?) -> CGSize {
            if let aspect = guideAspect {
                let containerAspect = containerSize.width / containerSize.height
                if aspect > containerAspect {
                    let w = containerSize.width
                    let h = w / aspect
                    return CGSize(width: w, height: h)
                } else {
                    let h = containerSize.height
                    let w = min(containerSize.width, h * aspect)
                    return CGSize(width: w, height: h)
                }
            } else {
                return containerSize
            }
        }
    }

    // MARK: - Controls Subviews
    private struct ImagePickerControls: View {
        @Binding var selectedPhotoItem: PhotosPickerItem?
        @ObservedObject var viewModel: ImageCropViewModel
        @Binding var lastOffset: CGSize
        @Binding var dragTranslation: CGSize

        // Helper to load image data and save to temp file URL
        private func loadFileURL(from item: PhotosPickerItem) async throws -> URL? {
            guard let imageData = try? await item.loadTransferable(type: Data.self) else {
                return nil
            }
            let tmp = FileManager.default.temporaryDirectory
            let dest = tmp.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            try imageData.write(to: dest)
            return dest
        }

        // Preferred: write the PhotosPickerItem data to a temp file and return its URL.
        // This avoids FileProvider/XPC issues and keeps memory usage lower for large images.
        private func savePhotosPickerItemToTempFile(_ item: PhotosPickerItem) async -> URL? {
            // Try to load Data first
            if let data = try? await item.loadTransferable(type: Data.self) {
                let tmp = FileManager.default.temporaryDirectory
                let dest = tmp.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                do {
                    try data.write(to: dest)
                    return dest
                } catch {
                    print("   ❌ Failed to write temp file: \(error)")
                    return nil
                }
            }
            return nil
        }

        var body: some View {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.fill")
                    Text(NSLocalizedString("choose_photo", comment: "Choose photo button"))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                .foregroundColor(.white)
                .cornerRadius(8)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .onChange(of: selectedPhotoItem) { newValue in
                Task {
                    guard let item = newValue else { return }

                    var loadedImage: UIImage? = nil
                    var retryCount = 0
                    let maxRetries = 3

                    while loadedImage == nil && retryCount < maxRetries {
                        retryCount += 1
                        print("📸 Loading photo (attempt \(retryCount)/\(maxRetries))...")

                        // Primary (Method 3): Save Data to temp file and load via UIImage(contentsOfFile:)
                        if loadedImage == nil {
                            if let dest = await savePhotosPickerItemToTempFile(item) {
                                do {
                                    if let uiImage = UIImage(contentsOfFile: dest.path) {
                                        let cgSize = uiImage.cgImage?.width ?? 0
                                        print("   ✓ Data->File->UIImage: \(uiImage.size) (actual: \(cgSize)px)")
                                        if cgSize > 500 {
                                            loadedImage = uiImage
                                            print("   ✅ Accepted")
                                        } else {
                                            print("   ⚠️ Image too small, will retry...")
                                        }
                                    }
                                }
                                try? FileManager.default.removeItem(at: dest)
                            }
                        }

                        // Fallback (Method 2): load Data directly into UIImage
                        if loadedImage == nil {
                            if let imageData = try? await item.loadTransferable(type: Data.self) {
                                if let uiImage = UIImage(data: imageData) {
                                    let cgSize = uiImage.cgImage?.width ?? 0
                                    print("   ✓ Data->UIImage: \(uiImage.size) (actual: \(cgSize)px)")
                                    if cgSize > 500 {
                                        loadedImage = uiImage
                                        print("   ✅ Accepted")
                                    } else {
                                        print("   ⚠️ Image too small, will retry...")
                                    }
                                }
                            }
                        }

                        // Optional fallback (Method 1): try to copy file representation if available
                        if loadedImage == nil {
                            if let fileURL = try? await loadFileURL(from: item) {
                                let tmp = FileManager.default.temporaryDirectory
                                let dest = tmp.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileURL.pathExtension)
                                do {
                                    try FileManager.default.copyItem(at: fileURL, to: dest)
                                    if let uiImage = UIImage(contentsOfFile: dest.path) {
                                        let cgSize = uiImage.cgImage?.width ?? 0
                                        print("   ✓ File method: \(uiImage.size) (actual: \(cgSize)px)")
                                        if cgSize > 500 {
                                            loadedImage = uiImage
                                            print("   ✅ Accepted")
                                        } else {
                                            print("   ⚠️ Image too small, will retry...")
                                        }
                                    }
                                    try? FileManager.default.removeItem(at: dest)
                                } catch {
                                    print("   ❌ File method failed: \(error)")
                                }
                            }
                        }

                        // Wait before retry on iPhone 15 Pro Max (device-specific timing)
                        if loadedImage == nil && retryCount < maxRetries {
                            print("   ⏳ Retrying in 100ms...")
                            try? await Task.sleep(nanoseconds: 100_000_000)
                        }
                    }

                    // Apply the loaded image
                    if let image = loadedImage {
                        await MainActor.run {
                            viewModel.selectedImage = image
                            viewModel.resetTransform()
                            lastOffset = .zero
                            dragTranslation = .zero
                        }
                    } else {
                        print("❌ Failed to load valid image after \(maxRetries) attempts")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Canvas Area
                mainCanvasView()
                
                // Controls Section
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Spacer()
                        ImagePickerControls(selectedPhotoItem: $selectedPhotoItem, viewModel: viewModel, lastOffset: $lastOffset, dragTranslation: $dragTranslation)
                        // Apply Crop moved to navigation bar as 'Complete'
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    Spacer()
                }
                .frame(minHeight: 120)
                .background(Color.black)
            }
//                .navigationTitle(NSLocalizedString("position_and_crop", comment: "Position and crop title"))
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            if transferInProgress {
                                showCancelAlert = true
                            } else {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.backward")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.selectedImage != nil {
                            Button(NSLocalizedString("transfer", comment: "Transfer button")) {
                                // Compute crop frame from last-known container & guide sizes
                                // Fallback to screen width if container is missing or invalid (width=0)
                                var container = currentContainerSize ?? CGSize(width: UIScreen.main.bounds.width, height: 480)
                                if container.width <= 0 {
                                    container = CGSize(width: UIScreen.main.bounds.width, height: 480)
                                }
                                
                                // Recompute guide size based on the valid container
                                let guide = computeGuideSize(containerSize: container)
                                
                                // Inset the guide by the border width (10 pts) to avoid cropping into the white border
                                let inset: CGFloat = 10.0
                                let cropWidth = max(10, guide.width - inset * 2)  // Full guide width minus insets on both sides
                                let cropHeight = max(10, guide.height - inset * 2)  // Full guide height minus insets on both sides
                                let origin = CGPoint(x: (container.width - cropWidth) / 2.0,
                                                     y: (container.height - cropHeight) / 2.0)
                                let cropFrame = CGRect(origin: origin, size: CGSize(width: cropWidth, height: cropHeight))
                                // Perform crop
                                viewModel.cropImage(within: cropFrame, canvasSize: container)

                                // Start transfer if we have a cropped image
                                #if canImport(UIKit)
                                if let cropped = viewModel.croppedImage {
                                    transferInProgress = true
                                    transferProgress = 0
                                    // start in waiting state while device acknowledges readiness
                                    transferOverlayState = .waiting
                                    showTransferOverlay = true
                                    // Kick off transfer with progress handler
                                    transferManager.transferImage(cropped, named: "cropped-") { progress in
                                        DispatchQueue.main.async {
                                            transferProgress = progress
                                            // once progress updates, show transferring state
                                            transferOverlayState = .transferring
                                        }
                                    } completion: { success, message in
                                        DispatchQueue.main.async {
                                            transferInProgress = false
                                            transferProgress = 0
                                            // Clear cropped image on both success and failure/timeout.
                                            // On success, also clear the selected source image and hide overlay.
                                            viewModel.croppedImage = nil
                                            if success {
                                                showTransferOverlay = false
                                                transferOverlayState = .transferring
                                                viewModel.selectedImage = nil
                                            } else {
                                                // Leave overlay handling to the timeout observer (it will show 'notReady' then hide after 3s)
                                            }
                                            // You could show a toast or alert here on success/failure
                                        }
                                    }
                                }
                                #endif
                            }
                        }
                    }
                }
            .overlay(
                Group {
                    if showTransferOverlay {
                        ZStack {
                            Color.black.opacity(0.6)
                                .ignoresSafeArea()
                            VStack(spacing: 16) {
                                switch transferOverlayState {
                                case .waiting:
                                    Text(NSLocalizedString("ensure_target_ready", comment: "Ensure the target is ready"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Button(action: {
                                        // Allow user to cancel while waiting
                                        showCancelAlert = true
                                    }) {
                                        Text(NSLocalizedString("cancel_transfer", comment: "Cancel transfer button"))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.white)
                                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                            .cornerRadius(8)
                                    }
                                case .transferring:
                                    Text(NSLocalizedString("transferring_image", comment: "Transferring image overlay title"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    ProgressView(value: Double(transferProgress), total: 100)
                                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)))
                                        .frame(maxWidth: 300)
                                    Text("\(transferProgress)%")
                                        .foregroundColor(.white)
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            // Prompt to cancel
                                            showCancelAlert = true
                                        }) {
                                            Text(NSLocalizedString("cancel_transfer", comment: "Cancel transfer button"))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color.white)
                                                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                                .cornerRadius(8)
                                        }
                                    }
                                case .notReady:
                                    Text(NSLocalizedString("target_not_ready", comment: "Target not ready to receive"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(24)
                            .background(Color(.secondarySystemBackground).opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            )
                .alert(NSLocalizedString("cancel_transfer_confirm_title", comment: "Cancel transfer confirm title"), isPresented: $showCancelAlert) {
                    Button(NSLocalizedString("yes_cancel", comment: "Yes cancel button")) {
                    // Cancel and cleanup
                    transferManager.cancelTransfer()
                    transferInProgress = false
                    showTransferOverlay = false
                    viewModel.croppedImage = nil
                    viewModel.selectedImage = nil
                    dismiss()
                }
                    Button(NSLocalizedString("no", comment: "No button"), role: .cancel) { }
            } message: {
                    Text(NSLocalizedString("cancel_transfer_message", comment: "Cancel transfer confirm message"))
            }
            .onAppear {
                // ensure guideAspect is available as early as possible so clamping uses guide bounds
                #if canImport(UIKit)
                if guideAspect == nil, let img = UIImage(named: "custom-target-guide") {
                    guideAspect = img.size.width / max(1.0, img.size.height)
                }
                #endif

                // Observe transfer waiting/timeout notifications to update overlay text/state
                if transferWaitingObserver == nil {
                    transferWaitingObserver = NotificationCenter.default.addObserver(forName: .imageTransferWaitingForAck, object: nil, queue: .main) { _ in
                        transferOverlayState = .waiting
                        showTransferOverlay = true
                    }
                }
                if transferTimeoutObserver == nil {
                    transferTimeoutObserver = NotificationCenter.default.addObserver(forName: .imageTransferTargetNotReady, object: nil, queue: .main) { _ in
                        transferOverlayState = .notReady
                        showTransferOverlay = true
                        // After 3 seconds, hide overlay and allow retry
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            transferInProgress = false
                            showTransferOverlay = false
                            transferProgress = 0
                            // Clear the cropped image so user can re-crop/retry
                            viewModel.croppedImage = nil
                        }
                    }
                }
            }
            .onDisappear {
                if let obs = transferWaitingObserver {
                    NotificationCenter.default.removeObserver(obs)
                    transferWaitingObserver = nil
                }
                if let obs = transferTimeoutObserver {
                    NotificationCenter.default.removeObserver(obs)
                    transferTimeoutObserver = nil
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

#Preview {
    ImageCropView()
}

// (Crop guide now provided by the `customer-image-guide` asset in Assets.xcassets)
