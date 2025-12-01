import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

class ImageCropViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var croppedImage: UIImage?
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var showImagePicker = false
    @Published var showLivePreview = false
    
    // Calculated properties
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 5.0
    
    func resetTransform() {
        scale = 1.0
        offset = .zero
    }

    /// Enforce minimum scale so the image always fills the provided cropSize
    /// and clamp offset so the crop rectangle remains covered by the image.
    func enforceConstraints(containerSize: CGSize, cropSize: CGSize) {
        // Ensure the user-visible image (container frame scaled by `scale`) fully
        // covers the crop rectangle `cropSize`. Adjust `scale` if it's too small
        // and clamp the `offset` so the crop rect never reveals background.

        // Compute the minimum user scale needed so the displayed image covers the crop area.
        // displayed size = containerSize * scale, so requiredScale = cropSize / containerSize
        let requiredScaleX = cropSize.width / max(0.0001, containerSize.width)
        let requiredScaleY = cropSize.height / max(0.0001, containerSize.height)
        let minAllowedScale = max(1.0, requiredScaleX, requiredScaleY)

        if scale < minAllowedScale {
            scale = minAllowedScale
        }

        // Compute the displayed image size (points) after applying base fill scale and user scale.
        // If we have the image, calculate how the image is scaled to fill the container (scaledToFill semantics):
        //   baseFillScale = max(containerWidth / imageWidth, containerHeight / imageHeight)
        // Displayed image size = image.size * baseFillScale * userScale
        let (displayedWidth, displayedHeight): (CGFloat, CGFloat) = {
            if let img = selectedImage {
                let baseFill = max(containerSize.width / max(0.0001, img.size.width),
                                   containerSize.height / max(0.0001, img.size.height))
                return (img.size.width * baseFill * scale, img.size.height * baseFill * scale)
            } else {
                // Fallback to container-based calculation if no image is available
                return (containerSize.width * scale, containerSize.height * scale)
            }
        }()

        // Allowed half-range for the center offset so the crop rect stays fully covered.
        let allowedHalfX = max(0, (displayedWidth - cropSize.width) / 2.0)
        let allowedHalfY = max(0, (displayedHeight - cropSize.height) / 2.0)

        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            return Swift.min(Swift.max(value, lower), upper)
        }

        let clampedX = clamp(offset.width, -allowedHalfX, allowedHalfX)
        let clampedY = clamp(offset.height, -allowedHalfY, allowedHalfY)

        offset = CGSize(width: clampedX, height: clampedY)
    }

    /// Return a clamped offset for a proposed offset without mutating state.
    func clampedOffset(for proposed: CGSize, containerSize: CGSize, cropSize: CGSize, scaleOverride: CGFloat? = nil) -> CGSize {
        // Allow clamping even when `selectedImage` is nil; the math doesn't need the UIImage itself.
        let effectiveScale = scaleOverride ?? scale

        // Displayed image size (points) = container frame size * effective scale
        // Compute displayed image size (points) using image intrinsic size when possible
        let (displayedWidth, displayedHeight): (CGFloat, CGFloat) = {
            if let img = selectedImage {
                let baseFill = max(containerSize.width / max(0.0001, img.size.width),
                                   containerSize.height / max(0.0001, img.size.height))
                return (img.size.width * baseFill * effectiveScale, img.size.height * baseFill * effectiveScale)
            } else {
                return (containerSize.width * effectiveScale, containerSize.height * effectiveScale)
            }
        }()

        // Allowed half-range for the center offset so the crop rect remains fully covered
        let allowedHalfX = max(0, (displayedWidth - cropSize.width) / 2.0)
        let allowedHalfY = max(0, (displayedHeight - cropSize.height) / 2.0)

        // Helper to clamp a single value into [lower, upper]
        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            return Swift.min(Swift.max(value, lower), upper)
        }

        let clampedX = clamp(proposed.width, -allowedHalfX, allowedHalfX)
        let clampedY = clamp(proposed.height, -allowedHalfY, allowedHalfY)

        return CGSize(width: clampedX, height: clampedY)
    }
    
    func cropImage(within cropFrame: CGRect, canvasSize: CGSize) {
        // Normalize the source image first so orientation is upright and size matches its pixel data
        #if canImport(UIKit)
        guard let src = selectedImage else { return }
        let norm = normalizedImage(src)
        guard let cg = norm.cgImage else { return }

        // Compute baseFillScale using the normalized image size
        let baseFill = max(canvasSize.width / max(0.0001, norm.size.width),
                           canvasSize.height / max(0.0001, norm.size.height))

        // The displayed image size in points after baseFill and user scale
        let displayedImageSize = CGSize(width: norm.size.width * baseFill * scale,
                                        height: norm.size.height * baseFill * scale)

        // Top-left of the displayed image inside the container (points)
        let imageOrigin = CGPoint(x: (canvasSize.width - displayedImageSize.width) / 2.0 + offset.width,
                                  y: (canvasSize.height - displayedImageSize.height) / 2.0 + offset.height)

        // Convert cropFrame (in container points) to normalized image points: (point - imageOrigin) / (baseFill * scale)
        let invScale = 1.0 / (baseFill * scale)

        let imgX = (cropFrame.minX - imageOrigin.x) * invScale
        let imgY = (cropFrame.minY - imageOrigin.y) * invScale
        let imgW = cropFrame.width * invScale
        let imgH = cropFrame.height * invScale

        // Convert image points to image pixels (cgImage coordinate) using normalized image.scale
        let pxPerPoint = norm.scale
        let origin = CGPoint(x: CGFloat(imgX * pxPerPoint), y: CGFloat(imgY * pxPerPoint))
        let size = CGSize(width: CGFloat(imgW * pxPerPoint), height: CGFloat(imgH * pxPerPoint))
        var cropRectPixels = CGRect(origin: origin, size: size)

        // Clamp to cgImage bounds
        cropRectPixels.origin.x = max(0, cropRectPixels.origin.x)
        cropRectPixels.origin.y = max(0, cropRectPixels.origin.y)
        if cropRectPixels.maxX > CGFloat(cg.width) {
            cropRectPixels.size.width = max(0, CGFloat(cg.width) - cropRectPixels.origin.x)
        }
        if cropRectPixels.maxY > CGFloat(cg.height) {
            cropRectPixels.size.height = max(0, CGFloat(cg.height) - cropRectPixels.origin.y)
        }

        if let cropped = cg.cropping(to: cropRectPixels) {
            // Create UIImage from cropped CGImage and normalize orientation to .up so transfers/viewing show correct rotation
            var ui = UIImage(cgImage: cropped, scale: norm.scale, orientation: .up)
            ui = normalizedImage(ui)

            // Resize to target output resolution (720x1280) while preserving aspect ratio.
            // We scale the cropped image to fill the target area (aspect-fill), then draw it centered
            // into the target canvas so the final image is exactly targetSize but aspect ratio is preserved.
            let targetSize = CGSize(width: 720, height: 1280)
            let srcSize = ui.size

            // Compute scale to fill target (preserve aspect ratio)
            let scaleX = targetSize.width / max(0.0001, srcSize.width)
            let scaleY = targetSize.height / max(0.0001, srcSize.height)
            let scaleToFill = max(scaleX, scaleY)

            let scaledSize = CGSize(width: srcSize.width * scaleToFill, height: srcSize.height * scaleToFill)
            // Center the scaled image in the target canvas (may crop overflow)
            let drawOrigin = CGPoint(x: (targetSize.width - scaledSize.width) / 2.0,
                                     y: (targetSize.height - scaledSize.height) / 2.0)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            let resized = renderer.image { _ in
                ui.draw(in: CGRect(origin: drawOrigin, size: scaledSize))
            }

            self.croppedImage = resized
        }
        #endif
    }

#if canImport(UIKit)
    private func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered
    }
#endif
    
    func getImagePosition(in size: CGSize) -> CGPoint {
        let imageWidth = size.width * scale
        let imageHeight = size.height * scale
        
        let x = (size.width - imageWidth) / 2 + offset.width
        let y = (size.height - imageHeight) / 2 + offset.height
        
        return CGPoint(x: x, y: y)
    }
    
    func getImageSize(in size: CGSize) -> CGSize {
        guard let image = selectedImage else { return .zero }
        
        let aspectRatio = image.size.width / image.size.height
        let scaledHeight = size.height * scale
        let scaledWidth = scaledHeight * aspectRatio
        
        return CGSize(width: scaledWidth, height: scaledHeight)
    }
}
