import SwiftUI

struct SilhouetteMask: Shape {
    let rectWidth: CGFloat
    let rectHeight: CGFloat
    
    // Head spec: circle with 1/3 of rect height
    // Body spec: capsule with 1/2 of rect width and remaining height
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let frameWidth = rect.width
        let frameHeight = rect.height
        
        // Dimensions
        let headRadius = frameHeight / 6  // 1/3 of rect height (diameter = 1/3)
        let bodyWidth = frameWidth / 2
        let bodyHeight = frameHeight - (2 * headRadius)
        let bodyX = (frameWidth - bodyWidth) / 2
        let bodyY = 2 * headRadius
        
        // Head (circle)
        let headCenterX = frameWidth / 2
        let headCenterY = headRadius
        path.addEllipse(in: CGRect(
            x: headCenterX - headRadius,
            y: headCenterY - headRadius,
            width: 2 * headRadius,
            height: 2 * headRadius
        ))
        
        // Body (capsule/rounded rectangle)
        let bodyCornerRadius = bodyWidth / 3
        path.addPath(
            UIBezierPath(
                roundedRect: CGRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight),
                cornerRadius: bodyCornerRadius
            ).bezierPath
        )
        
        return path
    }
}

extension UIBezierPath {
    var bezierPath: Path {
        let path = Path(self.cgPath)
        return path
    }
}

struct SilhouetteMaskView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let headRadius = height / 6
            let bodyWidth = width / 2
            let bodyHeight = height - (2 * headRadius)
            let bodyX = (width - bodyWidth) / 2
            let bodyY = 2 * headRadius
            
            // Draw head circle
            let headCenterX = width / 2
            let headCenterY = headRadius
            var headPath = Path()
            headPath.addEllipse(in: CGRect(
                x: headCenterX - headRadius,
                y: headCenterY - headRadius,
                width: 2 * headRadius,
                height: 2 * headRadius
            ))
            context.stroke(headPath, with: .color(.white.opacity(0.6)), lineWidth: 2)
            
            // Draw body capsule
            let bodyCornerRadius = bodyWidth / 3
            let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
            let bodyPath = Path(
                roundedRect: bodyRect,
                cornerRadius: bodyCornerRadius
            )
            context.stroke(bodyPath, with: .color(.white.opacity(0.6)), lineWidth: 2)
        }
        .frame(width: width, height: height)
    }
}

struct MaskGuideOverlay: View {
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
            
            // Clear mask area
            SilhouetteMaskView(width: frameWidth, height: frameHeight)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: frameWidth, height: frameHeight)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Silhouette Mask Guide")
            .font(.headline)
        
        ZStack {
            Color.gray
            
            SilhouetteMaskView(width: 480, height: 400)
        }
        .frame(width: 480, height: 480)
        .cornerRadius(4)
        
        Text("Mask overlay with dark background")
            .font(.caption)
        
        ZStack {
            Color.gray
            
            MaskGuideOverlay(frameWidth: 480, frameHeight: 400)
        }
        .frame(width: 480, height: 480)
        .cornerRadius(4)
    }
    .padding()
}
