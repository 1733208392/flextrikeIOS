import SwiftUI

// MARK: - Gesture Utilities

struct GestureState {
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastScale: CGFloat = 1.0
}

// MARK: - Image Utilities

extension UIImage {
    /// Crop image to a specific rect
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Resize image to a specific size
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Mask Configuration

struct MaskConfiguration {
    static let portraitRatio: CGFloat = 9.0 / 16.0
    static let headHeightRatio: CGFloat = 1.0 / 3.0
    static let bodyWidthRatio: CGFloat = 1.0 / 2.0
    
    static func calculateHeadRadius(frameHeight: CGFloat) -> CGFloat {
        frameHeight * headHeightRatio / 2
    }
    
    static func calculateBodyDimensions(
        frameWidth: CGFloat,
        frameHeight: CGFloat
    ) -> (width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        let headRadius = calculateHeadRadius(frameHeight: frameHeight)
        let bodyWidth = frameWidth * bodyWidthRatio
        let bodyHeight = frameHeight - (2 * headRadius)
        let bodyX = (frameWidth - bodyWidth) / 2
        let bodyY = 2 * headRadius
        
        return (bodyWidth, bodyHeight, bodyX, bodyY)
    }
}

// MARK: - Animation

extension Animation {
    static var smoothSpring: Animation {
        Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    }
}
