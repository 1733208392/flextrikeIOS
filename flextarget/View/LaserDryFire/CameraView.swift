import SwiftUI
import SVGKit

struct SVGImageView: UIViewRepresentable {
    let name: String
    let size: CGSize
    
    func makeUIView(context: Context) -> SVGKFastImageView {
        let svgImage = SVGKImage(named: name)
        svgImage?.size = size
        let imageView = SVGKFastImageView(svgkImage: svgImage)
        imageView?.contentMode = .scaleAspectFit
        return imageView!
    }
    
    func updateUIView(_ uiView: SVGKFastImageView, context: Context) {}
}

struct CameraGestureView: UIViewRepresentable {
    let onTap: (CGPoint) -> Void
    let onPinch: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Tap to focus
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        // Pinch to zoom
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPinch: onPinch)
    }

    class Coordinator: NSObject {
        let onTap: (CGPoint) -> Void
        let onPinch: (CGFloat) -> Void

        init(onTap: @escaping (CGPoint) -> Void, onPinch: @escaping (CGFloat) -> Void) {
            self.onTap = onTap
            self.onPinch = onPinch
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            onTap(point)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            onPinch(gesture.scale)
            gesture.scale = 1.0 // Reset for incremental zoom
        }
    }
}

struct CameraView: View {
    @State private var scanY: CGFloat = 0 //Initial position of the scanning bar
    @ObservedObject var bleManager: BLEManager
    @StateObject private var processor: CameraProcessor
    @StateObject private var motionManager = MotionManager()
    @State private var fps: Int = 0
    @State private var frameCount: Int = 0
    @State private var tapLocation: CGPoint? = nil
    @State private var focusTimer: Timer? = nil
    @State private var warningTimer: Timer? = nil
    @State private var previousIsStable: Bool = true
    @State private var currentZoom: CGFloat = 1.0
    @State private var isCapturing: Bool = false


    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var isPortrait: Bool {
        motionManager.orientation == .portrait || motionManager.orientation == .portraitUpsideDown
    }
    
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        _processor = StateObject(wrappedValue: CameraProcessor(bleManager: bleManager))
    }
    
    var scanframe: CGSize {
        CGSize(
            width: UIScreen.main.bounds.width * 0.8,
            height: UIScreen.main.bounds.height * 0.6
        )
    }
    
    var body: some View {
        ZStack{
            Color(.darkGray).ignoresSafeArea()
            if let img = processor.previewImage {
                GeometryReader { geo in
                    // Calculate scale to fit image within view, Must draw a diagram to understand how it works
                    let scaleX  =  img.size.height / img.size.width
                    let scaleY  =  geo.size.height / geo.size.width
                    
                    ZStack {
                        Image(uiImage: img)
                            .resizable()
                            .ignoresSafeArea()
                            .rotationEffect(.degrees(90))
                            .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                            .clipped()
                    }//Zstack for Image View
                }
            }
            
            // Overlay text at the top of the scan frame
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let scanFrame = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                let overlayWidth: CGFloat = scanframe.width * 0.8
                let overlayHeight: CGFloat = 48.0
                let overlayY = scanFrame.y - overlayHeight - 16 // 16pt padding above scan frame

                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(.darkGray))
                        .frame(width: overlayWidth, height: overlayHeight)
                    Text(
                        isCapturing
                        ? "SHOTS IS BEING CAPTURED..."
                        : (processor.showStabilityWarning
                           ? "PLEASE KEEP THE PHONE STEADY WITH THE TRIPOD"
                           : "PLEASE POINT YOUR PHONE TO THE TARGET")
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                .frame(width: overlayWidth, height: overlayHeight)
                .position(
                    x: scanFrame.x + scanframe.width / 2,
                    y: overlayY + overlayHeight / 2
                )
            }
            
            // Scanning bar and gray overlay
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let cutoutOrigin = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                ZStack(alignment: .top) {
                    // Gray overlay following the bar
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: scanframe.width, height: scanY)
                        .clipped()
                    
                    // SVG scan bar
                    SVGImageView(name: "scan-bar", size: CGSize(width: scanframe.width, height: 16))
                        .frame(width: scanframe.width, height: 32)
                        .offset(y: scanY-16)
                        .blur(radius: 4.0)
                }
                .frame(width: scanframe.width, height: scanframe.height, alignment: .top)
                .position(
                    x: cutoutOrigin.x + scanframe.width / 2,
                    y: cutoutOrigin.y + scanframe.height / 2
                )
                .onAppear {
                    scanY = 0
                    withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: true)) {
                        scanY = scanframe.height
                    }
                    // Debug print
                    DispatchQueue.main.async {
                        print("geo.width: \(geo.size.width), geo.height: \(geo.size.height)")
                    }
                }
            }
            
            // FPS overlay (top left)
//            VStack {
//                HStack {
//                    OverlayView(fps: fps)
//                        .padding([.top, .leading], 16)
//                    Spacer()
//                }
//                Spacer()
//            }
            
            // Top Left Icon
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let cutoutOrigin = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                SVGImageView(name: "corner", size: CGSize(width: 120, height: 120))
                    .frame(width: 120, height: 120)
                    .position(
                        x: cutoutOrigin.x + 16,
                        y: cutoutOrigin.y + 16
                    )
                    .opacity(0.8)
            }
            
            //Top Right Icon
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let cutoutOrigin = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                SVGImageView(name: "corner", size: CGSize(width: 120, height: 120))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(90), anchor: .center)
                    .position(
                        x: cutoutOrigin.x + scanframe.width - 16,
                        y: cutoutOrigin.y + 16
                    )
                    .opacity(0.8)
            }
            
            // Bottom Right Icon
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let cutoutOrigin = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                SVGImageView(name: "corner", size: CGSize(width: 120, height: 120))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(180), anchor: .center)
                    .position(
                        x: cutoutOrigin.x + scanframe.width - 16,
                        y: cutoutOrigin.y + scanframe.height - 16
                    )
                    .opacity(0.8)
            }
            
            //Bottom Left ICON
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let cutoutOrigin = CGPoint(
                    x: rect.midX - scanframe.width / 2,
                    y: rect.midY - scanframe.height / 2
                )
                SVGImageView(name: "corner", size: CGSize(width: 120, height: 120))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90), anchor: .center)
                    .position(
                        x: cutoutOrigin.x + 16,
                        y: cutoutOrigin.y + scanframe.height - 16
                    )
                    .opacity(0.8)
            }
            GeometryReader { geo in
                CameraGestureView(
                    onTap: { point in
                        print("Tapped at: \(point)")
                        processor.focus(at: point, in: geo.size)
                    },
                    onPinch: { scale in
                        // Accumulate zoom
                        let newZoom = max(1.0, min(currentZoom * scale, 5.0))
                        currentZoom = newZoom
                        processor.setZoom(factor: newZoom)                }
                )
                .ignoresSafeArea()
            }
            // Focus point indicator
            // Always show focus indicator, default to center if no user tap
            GeometryReader { geo in
                let circleDiameter: CGFloat = 60
                let scanWidth = scanframe.width
                let scanHeight = scanframe.height
                let rect = geo.frame(in: .local)
                let scanOrigin = CGPoint(
                    x: rect.midX - scanWidth / 2,
                    y: rect.midY - scanHeight / 2
                )
                // Use last focus point or default to center of scan frame
                let focus = processor.lastFocusPoint ?? CGPoint(
                    x: scanOrigin.x + scanWidth / 2,
                    y: scanOrigin.y + scanHeight / 2
                )
                // Clamp focus point inside scan frame, with padding for the circle radius
                let minX = scanOrigin.x + circleDiameter / 2
                let maxX = scanOrigin.x + scanWidth - circleDiameter / 2
                let minY = scanOrigin.y + circleDiameter / 2
                let maxY = scanOrigin.y + scanHeight - circleDiameter / 2
                let clampedX = min(max(focus.x, minX), maxX)
                let clampedY = min(max(focus.y, minY), maxY)
                let textOffset: CGFloat = circleDiameter / 2 + 12
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: circleDiameter, height: circleDiameter)
                        .position(x: clampedX, y: clampedY)
                        .opacity(0.8)
                        .animation(.easeOut(duration: 0.3), value: focus)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: circleDiameter * 0.8, height: 1)
                        .position(x: clampedX, y: clampedY)
                        .animation(.easeOut(duration: 0.3), value: focus)
                    Text(String(format: "%.1fx", processor.zoomFactor))
                        .font(.caption)
                        .foregroundColor(.black)
                        .bold()
                        .shadow(radius: 2)
                        .position(x: clampedX + textOffset, y: clampedY)
                        .animation(.easeOut(duration: 0.3), value: processor.zoomFactor)
                }
            }
            // Focus Point Indicator
        }//Outer Most Zstack
        .mobilePhoneLayout()
        .onReceive(timer) { _ in
            fps = frameCount
            frameCount = 0
        }
        .environmentObject(processor)
        .onReceive(NotificationCenter.default.publisher(for: .newFrameProcessed)) { _ in
            frameCount += 1
        }
        .onReceive(motionManager.$isStable) { isStable in
            if !isStable {
                warningTimer?.invalidate()
                processor.showStabilityWarning = true
            } else if previousIsStable == false && isStable == true {
                warningTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    if motionManager.isStable {
                        processor.showStabilityWarning = false
                    }
                }
            }
            previousIsStable = isStable
        }
    }//Body View
}

extension Notification.Name {
    static let newFrameProcessed = Notification.Name("newFrameProcessed")
}
