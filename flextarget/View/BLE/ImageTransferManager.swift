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
            completion(false, "Transfer already in progress")
            return
        }
        
        guard bleManager.isConnected else {
            completion(false, "BLE not connected")
            return
        }
        
        // Compress image
        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(false, "Failed to compress image")
            return
        }
        
        print("📦 Starting image transfer: \(imageName)")
        print("   Original size: \(jpegData.count) bytes")
        
        transferInProgress = true
        transferCompletion = completion
        progressHandler = progress
        currentChunkIndex = 0
        currentChunks = jpegData.chunked(into: chunkSize)
        
        print("   Compressed size: \(jpegData.count) bytes")
        print("   Chunks: \(currentChunks.count) × \(chunkSize) bytes")
        
        // Send transfer start command
        sendTransferStart(imageName: imageName, totalSize: jpegData.count, totalChunks: currentChunks.count)
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
            "dest": "ET02",
            "content": content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            finishTransfer(success: false, message: "Failed to encode start command")
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
            "dest": "ET02",
            "content": content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            finishTransfer(success: false, message: "Failed to encode chunk")
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
            "dest": "ET02",
            "content": content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            finishTransfer(success: false, message: "Failed to encode complete command")
            return
        }
        
        bleManager.writeJSON(jsonString)
        finishTransfer(success: true, message: "Image transferred successfully")
    }
    
    private func finishTransfer(success: Bool, message: String) {
        transferInProgress = false
        progressHandler?(success ? 100 : 0)
        progressHandler = nil
        ackTimer?.invalidate()
        ackTimer = nil
        
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
        progressHandler?(0)
        progressHandler = nil
        transferCompletion?(false, "Transfer cancelled")
        transferCompletion = nil
    }
}

// MARK: - Helper Extensions

extension Data {
    /// Splits data into chunks of specified size
    func chunked(into size: Int) -> [Data] {
        stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
