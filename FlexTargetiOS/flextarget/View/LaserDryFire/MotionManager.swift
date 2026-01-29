//
//  MotionManager.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/30.
//
import CoreMotion
import UIKit


class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    @Published var isStable: Bool = true
    @Published var orientation: UIDeviceOrientation = .unknown

    private var orientationObserver: NSObjectProtocol?
    private let threshold: Double = 0.02 // Adjust as needed

    init() {
        // Start generating device orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientation = UIDevice.current.orientation
        orientationObserver = NotificationCenter.default.addObserver(
             forName: UIDevice.orientationDidChangeNotification,
             object: nil,
             queue: .main
         ) { [weak self] _ in
             self?.orientation = UIDevice.current.orientation
         }
        
        
        startUpdates()
    }

    private func startUpdates() {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.2
        motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            let totalAcceleration = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            let deviation = abs(totalAcceleration - 1.0)
            let stable = deviation < self.threshold
            DispatchQueue.main.async {
                if self.isStable != stable {
                    self.isStable = stable
                    NotificationCenter.default.post(
                        name: .motionStabilityChanged,
                        object: self,
                        userInfo: ["isStable": stable]
                    )
                }
            }
        }
    }

    deinit {
        motion.stopAccelerometerUpdates()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

extension Notification.Name {
    static let motionStabilityChanged = Notification.Name("motionStabilityChanged")
}
