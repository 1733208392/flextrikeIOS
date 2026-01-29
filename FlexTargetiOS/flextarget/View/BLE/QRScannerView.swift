import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scanY: CGFloat = 0
    @State private var scannedText: String = ""
    @State private var showResult: Bool = false
    @StateObject private var qrScanner = QRCodeScanner()
    
    var onQRScanned: ((String) -> Void)?
    var hideBackButton: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let scanFrameWidth = geometry.size.width * 0.75
            let scanFrameHeight = scanFrameWidth
            
            ZStack {
                // Camera Preview - fills entire screen
                QRCameraPreview(qrScanner: qrScanner) { code in
                    if !showResult {
                        scannedText = code
                        showResult = true
                        onQRScanned?(code)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                
                // Dark overlay with transparent cutout effect
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                // Scan frame and animated bar
                VStack {
                    Spacer()
                    
                    ZStack {
                        // White border frame
                        // RoundedRectangle(cornerRadius: 20)
                        //     .stroke(Color.white, lineWidth: 3)
                        //     .frame(width: scanFrameWidth, height: scanFrameHeight)
                        
                        // Animated green scanning bar
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(0.0),
                                        Color.green.opacity(0.8),
                                        Color.green.opacity(0.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: scanFrameWidth - 40, height: 3)
                            .blur(radius: 2)
                            .offset(y: scanY - scanFrameHeight / 2 + 20)
                            .onAppear {
                                withAnimation(
                                    Animation.linear(duration: 2.0)
                                        .repeatForever(autoreverses: true)
                                ) {
                                    scanY = scanFrameHeight - 40
                                }
                            }
                        
                        // Corner brackets
                        CornerBracketsView()
                            .frame(width: scanFrameWidth, height: scanFrameHeight)
                    }
                    .frame(width: scanFrameWidth, height: scanFrameHeight)
                    
                    // Instructions
                    Text(NSLocalizedString("align_qr_code", comment: "QR scanner instruction to align code within frame"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 30)
                    
                    Spacer()
                }
                
                // Back button - top left corner with red color
                if !hideBackButton {
                    VStack {
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 20)
                            .padding(.top, 50)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Result overlay
                if showResult {
                    VStack(spacing: 20) {
                        Text("QR Code Scanned")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(scannedText)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 120, height: 44)
                                .background(Color.green)
                                .cornerRadius(22)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.85))
                }
            }
            .onAppear {
                qrScanner.startScanning()
            }
            .onDisappear {
                qrScanner.stopScanning()
            }
        }
    }
}

// Corner brackets for scan frame
struct CornerBracketsView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let bracketLength: CGFloat = 30
            let bracketThickness: CGFloat = 4
            
            ZStack {
                // Top-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: bracketLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: bracketLength, y: 0))
                }
                .stroke(Color.green, lineWidth: bracketThickness)
                
                // Top-right corner
                Path { path in
                    path.move(to: CGPoint(x: width - bracketLength, y: 0))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: bracketLength))
                }
                .stroke(Color.green, lineWidth: bracketThickness)
                
                // Bottom-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height - bracketLength))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: bracketLength, y: height))
                }
                .stroke(Color.green, lineWidth: bracketThickness)
                
                // Bottom-right corner
                Path { path in
                    path.move(to: CGPoint(x: width - bracketLength, y: height))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: width, y: height - bracketLength))
                }
                .stroke(Color.green, lineWidth: bracketThickness)
            }
        }
    }
}

// QR Code Scanner Logic
class QRCodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String = ""
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var onCodeScanned: ((String) -> Void)?
    
    func setupCamera(previewLayer: AVCaptureVideoPreviewLayer, onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
        self.previewLayer = previewLayer
        
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Could not add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Could not add metadata output")
            return
        }
        
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedCode = stringValue
            onCodeScanned?(stringValue)
        }
    }
}

// Camera Preview UIViewRepresentable
struct QRCameraPreview: UIViewRepresentable {
    @ObservedObject var qrScanner: QRCodeScanner
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        qrScanner.setupCamera(previewLayer: previewLayer, onCodeScanned: onCodeScanned)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
