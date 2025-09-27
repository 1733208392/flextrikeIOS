import SwiftUI
import AVFoundation
import Vision
import Photos
import CoreImage

// MARK: - CameraProcessor

class CameraProcessor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    // MARK: Published Properties
    @Published var previewImage: UIImage? = nil
    @Published var boundingBox: CGRect? = nil
    @Published var zoomFactor: CGFloat = 1.0
    @Published var lastFocusPoint: CGPoint? = nil
    
    // MARK: Camera Processing State
    @Published var showStabilityWarning: Bool = false
    @Published var qrCodeFound: Bool = false
    @Published var qrCount = 0
    @Published var startProcessing: Bool = false
    @Published var rectified: Bool = false
    
    // MARK: Camera Session
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isSessionRunning = false
    private var shouldAdjustExposure = false
    
    // MARK: State
    private var frameCount = 0
    private var previousFrame: UIImage?
    private var lastDetectedQRCorners: [[CGPoint]]?
    private var rectifiedImage: UIImage?
    private var didRectify = false
    private var baselineHSV: (h: Float, s: Float, v: Float)? = nil
    private var stabilityWarningTimer: Timer?
    private var stableStartTime: Date?
    private var hasDrawnDottedLine = false
    private var pauseProcessing = false
    private(set) var lastRectifyMatrix: [[Double]]?
    private let sharedCIContext = CIContext()
    private var baselineShotTimestamp: Int?

    //MARK: BLE Related
    var bleManager: BLEManagerProtocol?
    private(set) var bleStateTimestamp: Int = 0
    
    // MARK: Stability
    
    // MARK: - Init
    init(bleManager: BLEManagerProtocol?) {
        super.init()
        self.bleManager = bleManager
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.sessionPreset = .high
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBLEStateNotification(_:)),
                name: .bleStateNotificationReceived,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                forName: .motionStabilityChanged,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let isStable = notification.userInfo?["isStable"] as? Bool, !isStable {
                    self?.lastRectifyMatrix = nil
                    self?.rectified = false
                    self?.shouldAdjustExposure = false
//                    Restore the device exposure settings
                    self?.restoreAutoExposure()
                    print("Motion unstable, resetting rectification state.")
                }
            }
            
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else { return }
            
            self.session.addInput(input)
            self.output.setSampleBufferDelegate(self, queue: self.queue)
            
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            // Add metadata output for QR codes
            if self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                self.metadataOutput.metadataObjectTypes = [.qr]
            }
            
            self.session.startRunning()
            self.isSessionRunning = true
        }
    }
    
    deinit {
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        let qrCodes = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .filter { $0.type == .qr }
        
        self.qrCount = qrCodes.count
        
        if qrCodes.count == 4 {
            DispatchQueue.main.async {
                self.qrCodeFound = true
                
                // Flip y-coordinates to match AV output
                let allQRCorners: [[CGPoint]] = qrCodes.compactMap { code in
                    guard let corners = code.corners as? [CGPoint], corners.count == 4 else { return nil }
                    return corners.map { CGPoint(x: $0.x, y: $0.y) }
                }
                
                self.lastDetectedQRCorners = allQRCorners
                
                // Optionally, update boundingBox as before
                let allPoints = allQRCorners.flatMap { $0 }
                guard !allPoints.isEmpty else { return }
                let minX = allPoints.map { $0.x }.min() ?? 0
                let maxX = allPoints.map { $0.x }.max() ?? 0
                let minY = allPoints.map { $0.y }.min() ?? 0
                let maxY = allPoints.map { $0.y }.max() ?? 0
                
                self.boundingBox = CGRect(x: minY, y: minX, width: maxY - minY, height: maxX - minX)
            }
        } else {
            self.boundingBox = nil
            self.lastDetectedQRCorners = nil
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        if frameCount % 1 != 0 { return }
        
        //Debug Purpose
        if(self.pauseProcessing == true) {return}
        
        //DONT DO THIS AS AVMETADATA OUTPUT WILL NOT WORK
        //updateVideoOrientation(for: connection)
        
        if shouldAdjustExposure {
            reduceExposure(to: -4.0) // Reduce exposure bias
            shouldAdjustExposure = false
        }
        
        //Check if 4 QR corners are detecte with the MetaDataOutput
        if self.qrCount != 4 {
            // If QR code is found, we can skip further processing, just preview
            DispatchQueue.main.async {
                self.previewImage = self.uiImageFromSampleBuffer(sampleBuffer)
                NotificationCenter.default.post(name: .newFrameProcessed, object: nil)
            }
            return
        }
        else { // If 4 QR codes are detected, proceed with processing
            if self.qrCodeFound, let corners = self.lastDetectedQRCorners, corners.count == 4 {
                
                if(self.lastRectifyMatrix != nil) {
                    //Apply the last rectify matrix to the image
                    if let matrix = self.lastRectifyMatrix,
                       let image = self.uiImageFromSampleBuffer(sampleBuffer) {
                        let outputSize = image.size //Adjust as needed
                        let nsMatrix = doubleMatrixToNSNumber(matrix)
                        if let warped = OpenCVWrapper.warpImage(image, withMatrix: nsMatrix, outputSize: outputSize) {
                            DispatchQueue.main.async {
                                self.previewImage = warped
                                self.rectified = true
                            }
                        }
                    }
                } else {//Calculate the transformation matrix for rectification
                    
                    // Compute centroids to identify each QR code's position
                    let centroids = corners.map { pts in
                        CGPoint(
                            x: pts.map { $0.x }.reduce(0, +) / 4,
                            y: pts.map { $0.y }.reduce(0, +) / 4
                        )
                    }
                    // Find indices for each position
                    guard let topLeftIdx = centroids.enumerated().min(by: { $0.element.x + $0.element.y < $1.element.x + $1.element.y })?.offset,
                          let topRightIdx = centroids.enumerated().min(by: { $0.element.x - $0.element.y > $1.element.x - $1.element.y })?.offset,
                          let bottomRightIdx = centroids.enumerated().max(by: { $0.element.x + $0.element.y < $1.element.x + $1.element.y })?.offset,
                          let bottomLeftIdx = centroids.enumerated().min(by: { $0.element.y - $0.element.x > $1.element.y - $1.element.x })?.offset
                    else { return }
                    
                    // Select the correct corner from each QR code
                    let topLeftPoint = corners[topLeftIdx][3]      // top-left corner of top-left QR
                    let topRightPoint = corners[topRightIdx][2]    // top-right corner of top-right QR
                    let bottomRightPoint = corners[bottomRightIdx][1] // bottom-right corner of bottom-right QR
                    let bottomLeftPoint = corners[bottomLeftIdx][0]   // bottom-left corner of bottom-left QR
                    
                    let dotPoints = [topLeftPoint, topRightPoint, bottomRightPoint, bottomLeftPoint]
                    
                    //Rectify Image with a Animation and Save the transform Matrix for later use
                    DispatchQueue.main.async {
                        let dotted = self.uiImageFromSampleBuffer(sampleBuffer)?.drawDots(at: dotPoints, color: .orange, radius: 20)
                        self.previewImage = dotted
                        AudioServicesPlaySystemSound(SystemSoundID(1057)) // Beep sound
                        
                        let width = self.previewImage?.size.width ?? 1080
                        let height = self.previewImage?.size.height ?? 1920
                        let denormPoints = dotPoints.prefix(4).map { pt in
                            NSValue(cgPoint: CGPoint(x: pt.x * width, y: pt.y * height))
                        }
                        let outputSize = CGSize(width: 1920, height: 1080)
                        
                        let result = OpenCVWrapper.rectifyImageAndMatrix(from: dotted, withPoints: denormPoints, outputSize: outputSize)
                        if let rectified = result?["image"] as? UIImage,
                           let matrix = result?["matrix"] as? [[Double]] {
                            self.animateDottedToRectified(dotted: dotted!, rectified: rectified)
                            self.previewImage = rectified
                            self.lastRectifyMatrix = matrix
                            self.rectified = true
                            self.shouldAdjustExposure = true // Set flag to adjust exposure next time
//                            print("Rectification matrix: \(matrix)")
                        }
                    }
                } // ELS OF IF Transformation Matrix Found
                
                if(self.rectified == true){
                    let binarized = OpenCVWrapper.metalBinaryRedHSV(self.previewImage)
                                        
                    if let nsCenters = OpenCVWrapper.centersOfContours(from: binarized) {
                        let centers = nsCenters.map { $0.cgPointValue }

                        if centers.count > 0 {
//                            print("Contour centers: \(centers)")
                            // In your processing logic, replace where you set `t`:
                            let now = Int(Date().timeIntervalSince1970 * 1000)
                            if baselineShotTimestamp == nil {
                                baselineShotTimestamp = now
                            }
                            let t = now - (baselineShotTimestamp ?? now) // interval since baseline
                            let xScale: CGFloat = 476.4 / 1920.0
                            let yScale: CGFloat = 268.0 / 1080.0
                            let centersWithTimestamp = centers.map { center in
                                let xPhys = 268 - center.y * yScale    //Transform to physical coordinates
                                let yPhys = 476.4 - center.x * xScale  //Transform to physical coordinates
                                return (t: t, x: xPhys, y: yPhys, a: 0)
                            }
                            let filteredCenters = filterBoundaryCenters(filterDuplicateCenters(centersWithTimestamp))
                            let centerString = self.jsonStringForCenters(filteredCenters)
                            print("centerString: \(centerString ?? "")")
                            self.saveToLocalStorageAndSendBLE(key: "0", value: centerString ?? "{}") // Don't send timestamp for now
                        }
                    } // Image Binarized
                } // Image Rectified
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .newFrameProcessed, object: nil)
                }
            } // QR Code Found
        } // IF QR Code Found
    }
    
    // MARK: - Stability Warning
    
    func setStabilityWarning(_ show: Bool) {
        if show {
            if !showStabilityWarning {
                showStabilityWarning = true
                stabilityWarningTimer?.invalidate()
                stabilityWarningTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.showStabilityWarning = false
                    }
                }
            }
        }
        // Do nothing if show == false; let the timer hide the warning
    }
    
    func handleMotionUnstable() {
        DispatchQueue.main.async {
            self.lastRectifyMatrix = nil
            self.rectified = false
        }
    }
    
    
    // MARK: - Helpers
    func restoreAutoExposure() {
        sessionQueue.async {
            if let device = AVCaptureDevice.default(for: .video) {
                do {
                    try device.lockForConfiguration()
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    // Reset exposure bias to neutral
                    let minBias = device.minExposureTargetBias
                    let maxBias = device.maxExposureTargetBias
                    let neutralBias: Float = 0.0
                    let clampedBias = max(min(neutralBias, maxBias), minBias)
                    device.setExposureTargetBias(clampedBias, completionHandler: nil)
                    device.unlockForConfiguration()
                } catch {
                    print("Failed to restore exposure: \(error)")
                }
            }
        }
    }
    
    func reduceExposure(to bias: Float = -4.0) {
        sessionQueue.async {
            if let device = AVCaptureDevice.default(for: .video) {
                do {
                    try device.lockForConfiguration()
                    let minBias = device.minExposureTargetBias
                    let maxBias = device.maxExposureTargetBias
                    let clampedBias = max(min(bias, maxBias), minBias)
                    device.setExposureTargetBias(clampedBias, completionHandler: nil)
                    device.unlockForConfiguration()
                } catch {
                    print("Failed to reduce exposure: \(error)")
                }
            }
        }
    }
    
    func filterDuplicateCenters(_ centers: [(t: Int, x: CGFloat, y: CGFloat, a: Int)], minTimeDiff: Int = 90, minDist: CGFloat = 50) -> [(t: Int, x: CGFloat, y: CGFloat, a: Int)] {
        var filtered: [(t: Int, x: CGFloat, y: CGFloat, a: Int)] = []
        for center in centers {
            if let last = filtered.last {
                let dt = abs(center.t - last.t)
                let dx = center.x - last.x
                let dy = center.y - last.y
                let dist = sqrt(dx * dx + dy * dy)
                if dt <= minTimeDiff { //This is unhumanly fast, ignore the minDist for now
                    continue
                }
            }
            filtered.append(center)
        }
        return filtered
    }
    
    //Those are likely to be flares from the center
    func filterBoundaryCenters(_ centers: [(t: Int, x: CGFloat, y: CGFloat, a: Int)], width: CGFloat = 1920, height: CGFloat = 1080, boundaryMargin: CGFloat = 50) -> [(t: Int, x: CGFloat, y: CGFloat, a: Int)] {
        var result: [(t: Int, x: CGFloat, y: CGFloat, a: Int)] = []
        let grouped = Dictionary(grouping: centers, by: { $0.t })
        for (_, group) in grouped {
            if group.count == 1 {
                result.append(group[0])
            } else {
                // Remove the one closest to the boundary
                let sorted = group.sorted {
                    let d0 = min($0.x, width - $0.x, $0.y, height - $0.y)
                    let d1 = min($1.x, width - $1.x, $1.y, height - $1.y)
                    return d0 > d1 // Keep the one farther from boundary
                }
                // Keep all except the one closest to boundary
                result.append(contentsOf: sorted.dropLast(1))
            }
        }
        return result
    }
    
    func doubleMatrixToNSNumber(_ matrix: [[Double]]) -> [[NSNumber]] {
        return matrix.map { row in row.map { NSNumber(value: $0) } }
    }
    
    func animateDottedToRectified(dotted: UIImage, rectified: UIImage, duration: TimeInterval = 1.0, steps: Int = 20) {
        self.pauseProcessing = true
        var currentStep = 0
        let interval = duration / Double(steps)
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            let alpha = CGFloat(currentStep) / CGFloat(steps)
            UIGraphicsBeginImageContextWithOptions(dotted.size, false, dotted.scale)
            dotted.draw(at: .zero)
            rectified.draw(at: .zero, blendMode: .normal, alpha: alpha)
            let blended = UIGraphicsGetImageFromCurrentImageContext() ?? rectified
            UIGraphicsEndImageContext()
            DispatchQueue.main.async {
                self.previewImage = blended
            }
            currentStep += 1
            if currentStep > steps {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.previewImage = rectified
                    self.pauseProcessing = false
                }
            }
        }
    }
    // Save a value
    func saveToLocalStorage(key: String, value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func saveToLocalStorageAndSendBLE(key: String, value: String) {
        // Save to local storage first
        //        UserDefaults.standard.set(value, forKey: key)
        // Check BLE connection
        guard let bleManager = bleManager, bleManager.isConnected else { return }
        // Try to send via BLE
        //        print("Attempting to send \(key) via BLE: \(value)")
        if let data = value.data(using: .utf8) {
            bleManager.write(data: data) { [weak self] success in
                print("BLE write success: \(success) for key: \(key)")
                if success {
                    // Remove from local storage if sent successfully
                    //                    self?.removeFromLocalStorage(key: key)
                    //                    print("Removed \(key) from local storage after successful BLE write.")
                }
            }
        }
    }
    
    // Load a value
    func loadFromLocalStorage(key: String) -> String? {
        return UserDefaults.standard.string(forKey: key)
    }
    
    func removeFromLocalStorage(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func jsonStringForCenters(_ centers: [(t: Int, x: CGFloat, y: CGFloat, a: Int)]) -> String? {
        let dataArray = centers.map { ["t": $0.t, "x": Int($0.x), "y": Int($0.y), "a": $0.a] }
        let dict: [String: Any] = [
            "action": "report_data",
            "data": dataArray
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            return String(data: data, encoding: .utf8)?.appending("\r\n")
        }
        return nil
    }
    
    func rotateImage90CCW(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let transform = CGAffineTransform(rotationAngle: .pi / 2) // 90° CCW
            .translatedBy(x: 0, y: -ciImage.extent.width)
        let rotated = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(rotated, from: CGRect(x: 0, y: 0, width: ciImage.extent.height, height: ciImage.extent.width)) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    func saveProcessedImageToPhotoGallery() {
        guard let image = self.previewImage else {
            print("No processed image to save.")
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("Image saved to photo gallery.")
            } else {
                print("Photo library access denied.")
            }
        }
    }
    
    func uiImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = sharedCIContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    func saveProcessedImageToFile(filename: String = "processed_image.jpg") {
        guard let image = self.previewImage,
              let data = image.jpegData(compressionQuality: 0.9) else {
            print("No processed image to save.")
            return
        }
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return }
        let fileURL = documentsURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            print("Image saved to \(fileURL.path)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    func updateVideoOrientation(for connection: AVCaptureConnection) {
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight // Camera is mirrored
        case .landscapeRight:
            videoOrientation = .landscapeLeft // Camera is mirrored
        default:
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
    
    private func orderCornersForDrawing(_ points: [CGPoint]) -> [CGPoint]? {
        guard points.count >= 4 else { return nil }
        let topLeft = points.min(by: { $0.x + $0.y < $1.x + $1.y })!
        let topRight = points.min(by: { $0.x - $0.y > $1.x - $1.y })!
        let bottomRight = points.max(by: { $0.x + $0.y < $1.x + $1.y })!
        let bottomLeft = points.min(by: { $0.y - $0.x > $1.y - $1.x })!
        return [topLeft, topRight, bottomRight, bottomLeft, topLeft]
    }
    
    func detectQRCorners(in image: UIImage) -> (corners: [[CGPoint]], minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let enhanced = ciImage.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.2])
        let context = CIContext()
        guard let enhancedCGImage = context.createCGImage(enhanced, from: enhanced.extent) else {
            print("Failed to create enhanced CGImage")
            return nil
        }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: enhancedCGImage, options: [:])
        do {
            try handler.perform([request])
            let qrObservations = (request.results)?.filter { $0.symbology == .qr } ?? []
            guard qrObservations.count == 4 else { return nil }
            let corners = qrObservations.map { obs in
                [
                    CGPoint(x: obs.topLeft.x * width,     y: (1 - obs.topLeft.y) * height),
                    CGPoint(x: obs.topRight.x * width,    y: (1 - obs.topRight.y) * height),
                    CGPoint(x: obs.bottomRight.x * width, y: (1 - obs.bottomRight.y) * height),
                    CGPoint(x: obs.bottomLeft.x * width,  y: (1 - obs.bottomLeft.y) * height)
                ]
            }
            let allPoints = corners.flatMap { $0 }
            guard let minX = allPoints.min(by: { $0.x < $1.x })?.x,
                  let maxX = allPoints.max(by: { $0.x < $1.x })?.x,
                  let minY = allPoints.min(by: { $0.y < $1.y })?.y,
                  let maxY = allPoints.max(by: { $0.y < $1.y })?.y else {
                return nil
            }
            return (corners, minX, maxX, minY, maxY)
        } catch {
            return nil
        }
    }
    
    func focus(at point: CGPoint, in viewSize: CGSize) {
        
        print("Setting focus at point: \(point)")
        let normalizedPOI = CGPoint(x: point.x / viewSize.width, y: point.y / viewSize.height)
        DispatchQueue.main.async {
            self.lastFocusPoint = point
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = normalizedPOI
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = normalizedPOI
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                print("Failed to set focus: \(error)")
            }
        }
    }
    
    func setZoom(factor: CGFloat) {
        let clamped = max(1.0, min(factor, 3.0)) // Clamp between 1x and 5x (adjust as needed)
        DispatchQueue.main.async {
            self.zoomFactor = clamped
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                print("Failed to set zoom: \(error)")
            }
        }
    }
    
    private func hasCameraViewChanged(current: UIImage, previous: UIImage?, threshold: Double = 10.0) -> Bool {
        guard let previous = previous else { return true }
        let diff = OpenCVWrapper.metalMeanAbsDiffBetween(current, and: previous)
        return diff > threshold
    }
    
    @objc private func handleBLEStateNotification(_ notification: Notification) {
        print("BLE state notification received")
        if let userInfo = notification.userInfo,
           let stateCode = userInfo["state_code"] as? Int {
            if stateCode == 2 {
                // Record current timestamp in milliseconds
                bleStateTimestamp = Int(Date().timeIntervalSince1970 * 1000)
//                print("State Notification Receieved, timestamp: \(bleStateTimestamp)")
            } else {
                // Reset timestamp
                bleStateTimestamp = 0
            }
            print("BLE state_code: \(stateCode), timestamp: \(bleStateTimestamp)")
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    
    func drawBoundingBox(_ rect: CGRect, color: UIColor = .red, lineWidth: CGFloat = 4.0) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: .zero)
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(color.cgColor)
        context?.setLineWidth(lineWidth)
        context?.stroke(rect)
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
    
    func drawDottedLineConnecting(points: [CGPoint], color: UIColor, lineWidth: CGFloat, dashPattern: [CGFloat]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return self
        }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineDash(phase: 0, lengths: dashPattern)
        context.setLineCap(.round)
        if points.count > 1 {
            context.move(to: points[0])
            for pt in points.dropFirst() {
                context.addLine(to: pt)
            }
            context.strokePath()
        }
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
    
    func drawDot(at point: CGPoint, color: UIColor, radius: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: .zero)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.addArc(center: point, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context?.fillPath()
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
    
    func drawDots(at points: [CGPoint], color: UIColor = .red, radius: CGFloat = 8.0) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return self
        }
        context.setFillColor(color.cgColor)
        //Denormalize points if needed with the width and height of the image
        let width = self.size.width
        let height = self.size.height
        print("Image size: \(width) x \(height)")
        let denormalizedPoints = points.map { CGPoint(x: $0.x * width, y: $0.y * height) }
        
        for point in denormalizedPoints {
            let rect = CGRect(x: point.x - radius/2, y: point.y - radius/2, width: radius, height: radius)
            context.fillEllipse(in: rect)
        }
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }
    
    func cropToQRCorners(_ corners: [CGPoint]) -> UIImage? {
        guard corners.count == 4 else { return nil }
        let minX = corners.map { $0.x }.min() ?? 0
        let maxX = corners.map { $0.x }.max() ?? 0
        let minY = corners.map { $0.y }.min() ?? 0
        let maxY = corners.map { $0.y }.max() ?? 0
        let rect = CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
        guard let cgImage = self.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    func meanHSVOfWhitePixels() -> (h: Float, s: Float, v: Float)? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: Int(height * width * 4))
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var hSum: Float = 0, sSum: Float = 0, vSum: Float = 0
        var count: Int = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(pixelData[offset]) / 255.0
                let g = Float(pixelData[offset + 1]) / 255.0
                let b = Float(pixelData[offset + 2]) / 255.0
                
                let maxVal = max(r, g, b)
                let minVal = min(r, g, b)
                let delta = maxVal - minVal
                
                var h: Float = 0
                let s: Float = maxVal == 0 ? 0 : delta / maxVal
                let v: Float = maxVal
                
                if delta != 0 {
                    if maxVal == r {
                        h = (g - b) / delta
                    } else if maxVal == g {
                        h = 2 + (b - r) / delta
                    } else {
                        h = 4 + (r - g) / delta
                    }
                    h *= 60
                    if h < 0 { h += 360 }
                }
                
                if s < 0.2 && v > 0.8 {
                    hSum += h
                    sSum += s
                    vSum += v
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return (h: hSum/Float(count), s: sSum/Float(count), v: vSum/Float(count))
    }
    
    func binarizeRedHSV() -> UIImage {
        let targetWidth: CGFloat = 960
        let scaleFactor = targetWidth / size.width
        let targetSize = CGSize(width: targetWidth, height: size.height * scaleFactor)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage.cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: Int(height * width * 4))
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(pixelData[offset]) / 255.0
                let g = Float(pixelData[offset + 1]) / 255.0
                let b = Float(pixelData[offset + 2]) / 255.0
                
                let maxVal = max(r, g, b)
                let minVal = min(r, g, b)
                let delta = maxVal - minVal
                
                var h: Float = 0
                let s: Float = maxVal == 0 ? 0 : delta / maxVal
                let v: Float = maxVal
                
                if delta != 0 {
                    if maxVal == r {
                        h = (g - b) / delta
                    } else if maxVal == g {
                        h = 2 + (b - r) / delta
                    } else {
                        h = 4 + (r - g) / delta
                    }
                    h *= 60
                    if h < 0 { h += 360 }
                }
                
                let isRed = ((h >= 0 && h <= 20) || (h >= 340 && h <= 360)) && s > 0.4 && v > 0.2
                
                let value: UInt8 = isRed ? 255 : 0
                pixelData[offset] = value
                pixelData[offset + 1] = value
                pixelData[offset + 2] = value
            }
        }
        
        guard let outputContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outputCGImage = outputContext.makeImage() else {
            return self
        }
        
        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .right)
    }
}
