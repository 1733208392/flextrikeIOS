import SwiftUI
import Combine

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
    
    func cropImage(within cropFrame: CGRect, canvasSize: CGSize) {
        guard let image = selectedImage else { return }
        
        // Calculate the actual crop region accounting for scale and offset
        let scaledWidth = image.size.width / scale
        let scaledHeight = image.size.height / scale
        
        let croppedX = (-offset.width + cropFrame.minX) / cropFrame.width * scaledWidth
        let croppedY = (-offset.height + cropFrame.minY) / cropFrame.height * scaledHeight
        let croppedWidth = cropFrame.width / scale
        let croppedHeight = cropFrame.height / scale
        
        let cropRect = CGRect(
            x: max(0, croppedX),
            y: max(0, croppedY),
            width: min(croppedWidth, image.size.width - croppedX),
            height: min(croppedHeight, image.size.height - croppedY)
        )
        
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            self.croppedImage = UIImage(cgImage: cgImage)
        }
    }
    
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
