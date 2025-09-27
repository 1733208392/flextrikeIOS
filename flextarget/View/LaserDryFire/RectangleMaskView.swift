import SwiftUI

struct RectangleMaskView: View {
    var rectSize: CGSize
    @State private var scanY: CGFloat = 0
    private let scanSpeed: CGFloat = 4 // pixels per frame
    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let width = rectSize.width
            let height = rectSize.height
            let x = (geo.size.width - width) / 2
            let y = (geo.size.height - height) / 2

            ZStack {
                // Dimmed overlay
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .fill(style: FillStyle(eoFill: true))
                            .overlay(
                                Rectangle()
                                    .frame(width: width, height: height)
                                    .position(x: geo.size.width/2, y: geo.size.height/2)
                                    .blendMode(.destinationOut)
                            )
                    )
                // Rectangle border
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: width, height: height)
                    .position(x: geo.size.width/2, y: geo.size.height/2)

                // Radar scan line
                Path { path in
                    let scanLineY = y + scanY
                    if scanLineY >= y && scanLineY <= y + height {
                        path.move(to: CGPoint(x: x, y: scanLineY))
                        path.addLine(to: CGPoint(x: x + width, y: scanLineY))
                    }
                }
                .stroke(Color.green, lineWidth: 2)
                .shadow(color: Color.green.opacity(0.6), radius: 32, x: 0, y: 0)
            }
            .compositingGroup()
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 1/60)) {
                    scanY += scanSpeed
                    if scanY > height { scanY = 0 }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
