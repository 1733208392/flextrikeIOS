//
//  ImageTransferManager.swift
//  flextarget
//
//  Image transfer manager for efficient BLE transmission
//

import Foundation
import UIKit

/// Manages chunked image transfer over BLE with compression
class ImageTransferManager {
    private let bleManager: BLEManager
    private let chunkSize: Int = 200  // Bytes per chunk (safe MTU)
    private let timeoutInterval: TimeInterval = 5.0
    
    // Transfer state
    private var transferInProgress = false
    private var currentChunks: [Data] = []
    private var currentChunkIndex = 0
    private var transferCompletion: ((Bool, String) -> Void)?
    private var progressHandler: ((Int) -> Void)?
    private var ackTimer: Timer?
    // Observer and timer for ready-ack handshake
    private var readyObserver: NSObjectProtocol?
    private var readyTimer: Timer?
    // Device list management
    private var deviceListObserver: NSObjectProtocol?
    private var masterDeviceName: String = "ET02"  // Default fallback
    
    init(bleManager: BLEManager = .shared) {
        self.bleManager = bleManager
    }
    
    // MARK: - Public Methods
    
    /// Transfer an image over BLE with automatic compression
    /// - Parameters:
    ///   - image: UIImage to transfer
    ///   - imageName: Name identifier for the image
    ///   - compressionQuality: JPEG quality 0.0-1.0 (default 0.6)
    ///   - completion: (success, message)
    func transferImage(
        _ image: UIImage,
        named imageName: String,
        compressionQuality: CGFloat = 0.2,
        progress: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !transferInProgress else {
            completion(false, NSLocalizedString("transfer_in_progress_error", comment: "Transfer already in progress"))
            return
        }
        
        guard bleManager.isConnected else {
            completion(false, NSLocalizedString("ble_not_connected", comment: "BLE not connected"))
            return
        }
        
        // Query device list to get the master device name
        queryAndPrepareTransfer(image, imageName: imageName, compressionQuality: compressionQuality, progress: progress, completion: completion)
    }

    // MARK: - Device List Query
    
    private func queryAndPrepareTransfer(
        _ image: UIImage,
        imageName: String,
        compressionQuality: CGFloat,
        progress: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        // Register observer for device list updates
        deviceListObserver = NotificationCenter.default.addObserver(forName: .bleDeviceListUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let deviceList = userInfo["device_list"] as? [NetworkDevice] {
                // Find the master device
                if let masterDevice = deviceList.first(where: { $0.mode == "master" }) {
                    self.masterDeviceName = masterDevice.name
                    print("🎯 Master device found: \(masterDevice.name)")
                } else if !deviceList.isEmpty {
                    // Fallback to first device if no master found
                    self.masterDeviceName = deviceList[0].name
                    print("⚠️ No master device found, using first device: \(self.masterDeviceName)")
                }
                
                // Clean up observer and proceed with transfer
                if let obs = self.deviceListObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self.deviceListObserver = nil
                }
                
                // Now proceed with image compression and transfer setup
                self.prepareAndStartTransfer(image, imageName: imageName, compressionQuality: compressionQuality, progress: progress, completion: completion)
            }
        }
        
        // Send query command
        queryDeviceList()
    }
    
    private func queryDeviceList() {
        let command = ["action": "netlink_query_device_list"]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📡 Querying device list...")
                bleManager.writeJSON(jsonString)
            }
        } catch {
            print("Failed to serialize device list query: \(error)")
        }
    }
    
    private func prepareAndStartTransfer(
        _ image: UIImage,
        imageName: String,
        compressionQuality: CGFloat,
        progress: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        // Compress image
        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(false, NSLocalizedString("failed_compress_image", comment: "Failed to compress image"))
            return
        }

        print("📦 Preparing image transfer: \(imageName)")
        print("   Original size: \(jpegData.count) bytes")

        // Prepare chunks but do not start sending until the device ACKs readiness
        transferInProgress = true
        transferCompletion = completion
        progressHandler = progress
        currentChunkIndex = 0
        currentChunks = jpegData.chunked(into: chunkSize)

        print("   Compressed size: \(jpegData.count) bytes")
        print("   Chunks: \(currentChunks.count) × \(chunkSize) bytes")
        print("   Target device: \(masterDeviceName)")

        // Send a readiness command to the device and wait for an ACK
        sendReadyCommandAndAwaitAck(imageName: imageName, totalSize: jpegData.count, totalChunks: currentChunks.count)
    }
    
    // MARK: - Ready handshake

    private func sendReadyCommandAndAwaitAck(imageName: String, totalSize: Int, totalChunks: Int) {
        // Build minimal ready message (netlink_forward) — only command
        let content: [String: Any] = [
            "command": "image_transfer_ready"
        ]
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": masterDeviceName,
            "content": content
        ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
                            let jsonString = String(data: jsonData, encoding: .utf8) else {
                        finishTransfer(success: false, message: NSLocalizedString("failed_encode_ready", comment: "Failed to encode ready command"))
                        return
                }

        // Register observer for incoming netlink forward messages
        readyObserver = NotificationCenter.default.addObserver(forName: .bleNetlinkForwardReceived, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            guard let json = notification.userInfo?["json"] as? [String: Any] else { return }

            // The ACK may appear at top-level or inside content
            var ackValue: String? = nil
            if let content = json["content"] as? [String: Any], let ack = content["ack"] as? String {
                ackValue = ack
            } else if let ack = json["ack"] as? String {
                ackValue = ack
            }

            if let ack = ackValue, ack == "image_transfer_ready" {
                // ACK received — cancel timer & observer and start transfer
                self.readyTimer?.invalidate()
                self.readyTimer = nil
                if let obs = self.readyObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self.readyObserver = nil
                }

                // Small delay to ensure target has finished handshake processing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.sendTransferStart(imageName: imageName, totalSize: totalSize, totalChunks: totalChunks)
                }
            }
        }


        // Send the ready command
        bleManager.writeJSON(jsonString)

        // Notify UI that we're waiting for the target to acknowledge readiness
        NotificationCenter.default.post(name: .imageTransferWaitingForAck, object: nil)

        // Start guard timer: if no ACK within configured timeout, cancel transfer
        readyTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Remove observer
            if let obs = self.readyObserver {
                NotificationCenter.default.removeObserver(obs)
                self.readyObserver = nil
            }
            self.readyTimer = nil
            // Notify UI that target didn't respond and abort transfer
            NotificationCenter.default.post(name: .imageTransferTargetNotReady, object: nil)
            self.finishTransfer(success: false, message: NSLocalizedString("image_transfer_target_not_ready", comment: "Target not ready to receive image"))
        }
    }
    
    // MARK: - Private Methods
    
    private func sendTransferStart(imageName: String, totalSize: Int, totalChunks: Int) {
        let content: [String: Any] = [
            "command": "image_transfer_start",
            "image_name": imageName,
            "total_size": totalSize,
            "total_chunks": totalChunks,
            "chunk_size": chunkSize
        ]
        
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": masterDeviceName,
            "content": content
        ]
        
                guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
                            let jsonString = String(data: jsonData, encoding: .utf8) else {
                        finishTransfer(success: false, message: NSLocalizedString("failed_encode_start_command", comment: "Failed to encode start command"))
                        return
                }
        
        bleManager.writeJSON(jsonString)
        
        // Wait for acknowledgment then start sending chunks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendNextChunk()
        }
    }
    
    private func sendNextChunk() {
        guard transferInProgress else { return }
        guard currentChunkIndex < currentChunks.count else {
            sendTransferComplete()
            return
        }
        
        let chunk = currentChunks[currentChunkIndex]
        let base64String = chunk.base64EncodedString()
        
        // Create message with base64 data as direct string (not JSON-encoded)
        let content: [String: Any] = [
            "command": "image_chunk",
            "chunk_index": currentChunkIndex,
            "data": base64String
        ]
        
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": masterDeviceName,
            "content": content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
                    var jsonString = String(data: jsonData, encoding: .utf8) else {
                finishTransfer(success: false, message: NSLocalizedString("failed_encode_chunk", comment: "Failed to encode chunk"))
                return
        }
        
        // Verify base64 string integrity - log it for debugging
        print("   📋 Base64 length: \(base64String.count) chars")
        
        bleManager.writeJSON(jsonString)
        currentChunkIndex += 1
        
        // Show progress
        let progress = Int((Double(currentChunkIndex) / Double(currentChunks.count)) * 100)
        // Report progress via handler
        progressHandler?(progress)
        print("   📤 Sent chunk \(currentChunkIndex)/\(currentChunks.count) (\(progress)%)")
        
        // Schedule next chunk (0.2s delay between chunks)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // only continue if transfer still in progress
            if self.transferInProgress {
                self.sendNextChunk()
            }
        }
    }
    
    private func sendTransferComplete() {
        let content: [String: Any] = [
            "command": "image_transfer_complete",
            "status": "success"
        ]
        
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": masterDeviceName,
            "content": content
        ]
        
                guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
                            let jsonString = String(data: jsonData, encoding: .utf8) else {
                        finishTransfer(success: false, message: NSLocalizedString("failed_encode_complete_command", comment: "Failed to encode complete command"))
                        return
                }
        
        bleManager.writeJSON(jsonString)
        finishTransfer(success: true, message: NSLocalizedString("image_transferred_success", comment: "Image transferred successfully"))
    }
    
    private func finishTransfer(success: Bool, message: String) {
        transferInProgress = false
        // Only report final progress on success. Avoid sending a 0% progress update
        // on failure because that can race with UI timeout handling and cause
        // the overlay to briefly switch to 'Transferring 0%'.
        if success {
            progressHandler?(100)
        }
        progressHandler = nil
        ackTimer?.invalidate()
        ackTimer = nil
        // Clean up ready observer / timer if still present
        if let obs = readyObserver {
            NotificationCenter.default.removeObserver(obs)
            readyObserver = nil
        }
        readyTimer?.invalidate()
        readyTimer = nil
        // Clean up device list observer if still present
        if let obs = deviceListObserver {
            NotificationCenter.default.removeObserver(obs)
            deviceListObserver = nil
        }
        
        if success {
            print("✅ \(message)")
        } else {
            print("❌ \(message)")
        }
        
        transferCompletion?(success, message)
        transferCompletion = nil
    }

    /// Cancel an ongoing transfer. This will stop sending further chunks and call the completion with failure.
    func cancelTransfer() {
        guard transferInProgress else { return }
        transferInProgress = false
        currentChunks.removeAll()
        currentChunkIndex = 0
        ackTimer?.invalidate()
        ackTimer = nil
        if let obs = readyObserver {
            NotificationCenter.default.removeObserver(obs)
            readyObserver = nil
        }
        readyTimer?.invalidate()
        readyTimer = nil
        if let obs = deviceListObserver {
            NotificationCenter.default.removeObserver(obs)
            deviceListObserver = nil
        }
        progressHandler?(0)
        progressHandler = nil
        transferCompletion?(false, NSLocalizedString("transfer_cancelled", comment: "Transfer cancelled"))
        transferCompletion = nil
    }
}

// MARK: - Helper Extensions

// Notifications posted by ImageTransferManager for UI feedback
extension Notification.Name {
    /// Posted when the manager has sent the ready command and is waiting for an ACK
    static let imageTransferWaitingForAck = Notification.Name("imageTransferWaitingForAck")
    /// Posted when the ready ACK did not arrive within the guard timer
    static let imageTransferTargetNotReady = Notification.Name("imageTransferTargetNotReady")
}

extension Data {
    /// Splits data into chunks of specified size
    func chunked(into size: Int) -> [Data] {
        stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
