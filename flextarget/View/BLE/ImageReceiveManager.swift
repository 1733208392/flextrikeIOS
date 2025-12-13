//
//  ImageReceiveManager.swift
//  flextarget
//
//  Manages receiving images from device over BLE
//

import Foundation
import UIKit

class ImageReceiveManager {
    static let shared = ImageReceiveManager()
    
    private let bleManager: BLEManager
    private let chunkSize: Int = 200  // Bytes per chunk (safe MTU)
    private let timeoutInterval: TimeInterval = 10.0
    private let completionGraceInterval: TimeInterval = 1.5
    
    // Transfer state
    private var receiveInProgress = false
    private var receivedChunks: [Data] = []
    private var expectedChunks = 0
    private var receivedChunkCount = 0
    
    // Callbacks
    var onProgressUpdate: ((Int, String) -> Void)?
    var onImageReceived: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    
    // Observers
    private var imageChunkObserver: NSObjectProtocol?
    private var receiveTimeout: Timer?
    private var completionDelayTimer: Timer?
    private var transferStartObserver: NSObjectProtocol?
    private var completionReceived = false
    
    init(bleManager: BLEManager = .shared) {
        self.bleManager = bleManager
    }
    
    // MARK: - Public Methods
    
    func requestImageFromDevice() {
        guard !receiveInProgress else {
            onError?(NSLocalizedString("receive_in_progress_error", comment: "Receive already in progress"))
            return
        }
        
        guard bleManager.isConnected else {
            onError?(NSLocalizedString("ble_not_connected", comment: "BLE not connected"))
            return
        }
        
        receiveInProgress = true
        receivedChunks.removeAll()
        expectedChunks = 0
        receivedChunkCount = 0
        
        sendImageRequestCommand()
    }
    
    // MARK: - Private Methods
    
    private func sendImageRequestCommand() {
        let command: [String: Any] = [
            "action": "request_image",
            "request_type": "screenshot"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📸 Requesting image from device...")
                bleManager.writeJSON(jsonString)
                
                // Register observer for incoming image chunks
                setupImageChunkObserver()
                
                // Start timeout timer
                startReceiveTimeout()
                
                // Update UI
                onProgressUpdate?(0, NSLocalizedString("waiting_for_image", comment: "Waiting for image from device..."))
            }
        } catch {
            finishReceive(success: false, message: NSLocalizedString("failed_send_request", comment: "Failed to send image request"))
        }
    }
    
    private func setupImageChunkObserver() {
        imageChunkObserver = NotificationCenter.default.addObserver(
            forName: .bleImageChunkReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let json = notification.userInfo?["json"] as? [String: Any] {
                self.handleImageChunk(json)
            }
        }
        
        // Also listen for image_transfer_start to capture total_chunks and image_transfer_complete
        transferStartObserver = NotificationCenter.default.addObserver(
            forName: .bleNetlinkForwardReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let json = notification.userInfo?["json"] as? [String: Any],
               let content = json["content"] as? [String: Any],
               let command = content["command"] as? String {
                
                if command == "image_transfer_start" {
                    // Capture total_chunks from the start message
                    if let totalChunks = content["total_chunks"] as? Int {
                        self.expectedChunks = totalChunks
                        self.receivedChunks.removeAll()
                        self.receivedChunks.reserveCapacity(totalChunks)
                        for _ in 0..<totalChunks {
                            self.receivedChunks.append(Data())
                        }
                        self.receivedChunkCount = 0
                        print("📊 Image transfer start: expecting \(totalChunks) chunks")
                    }
                } else if command == "image_transfer_complete" {
                    self.completionReceived = true
                    self.cancelCompletionDelayTimer()
                    print("✅ Device confirmed transfer complete")
                    if let chunksSent = content["chunks_sent"] as? Int {
                        print("   Chunks sent by device: \(chunksSent)")
                        print("   Chunks received by app: \(self.receivedChunkCount)")
                    }

                    if self.expectedChunks > 0 && self.receivedChunkCount < self.expectedChunks {
                        self.startCompletionDelayTimer()
                    } else {
                        self.assembleAndDisplayImage()
                    }
                }
            }
        }
    }
    
    private func handleImageChunk(_ json: [String: Any]) {
        guard receiveInProgress else { return }
        
        // Extract chunk info - could be nested in content or at top level
        var chunkIndex: Int?
        var base64Data: String?
        
        // First try to get from content field (nested structure)
        if let content = json["content"] as? [String: Any] {
            chunkIndex = content["chunk_index"] as? Int
            base64Data = content["data"] as? String
        }
        
        // Fallback to top-level fields
        if chunkIndex == nil {
            chunkIndex = json["chunk_index"] as? Int
        }
        if base64Data == nil {
            base64Data = json["data"] as? String
        }
        
        guard let chunkIdx = chunkIndex,
              let data = base64Data,
              let chunkData = Data(base64Encoded: data) else {
            print("❌ Invalid chunk format - missing fields")
            print("  chunkIndex: \(chunkIndex?.description ?? "nil")")
            print("  data: \(base64Data?.prefix(50) ?? "nil")...")
            finishReceive(success: false, message: NSLocalizedString("invalid_chunk_format", comment: "Invalid chunk format"))
            return
        }
        
        let expectedText = expectedChunks > 0 ? "\(expectedChunks)" : "?"
        print("📦 Received chunk \(chunkIdx + 1)/\(expectedText)")
        
        // Store chunk and track count when slot was empty
        if chunkIdx < receivedChunks.count {
            if receivedChunks[chunkIdx].isEmpty {
                receivedChunkCount += 1
            }
            receivedChunks[chunkIdx] = chunkData
        }
        
        // Update progress
        if expectedChunks > 0 {
            let progress = Int((Double(receivedChunkCount) / Double(expectedChunks)) * 100)
            onProgressUpdate?(progress, "Receiving chunk \(chunkIdx + 1)/\(expectedText)")
        } else {
            onProgressUpdate?(0, "Receiving chunk \(chunkIdx + 1)/\(expectedText)")
        }
        
        // Reset timeout
        receiveTimeout?.invalidate()
        startReceiveTimeout()
        
        // Check if all chunks received
        if expectedChunks > 0 && receivedChunkCount >= expectedChunks {
            cancelCompletionDelayTimer()
            assembleAndDisplayImage()
        }
    }

    private func startCompletionDelayTimer() {
        completionDelayTimer?.invalidate()
        completionDelayTimer = Timer.scheduledTimer(withTimeInterval: completionGraceInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.assembleAndDisplayImage()
        }
    }

    private func cancelCompletionDelayTimer() {
        completionDelayTimer?.invalidate()
        completionDelayTimer = nil
    }
    
    private func assembleAndDisplayImage() {
        guard receiveInProgress else { return }
        
        // Cancel timeout
        receiveTimeout?.invalidate()
        receiveTimeout = nil
        
        // Verify all chunks are received (no empty data)
        for (index, chunk) in receivedChunks.enumerated() {
            if chunk.isEmpty {
                print("❌ Missing chunk at index \(index)")
                finishReceive(success: false, message: NSLocalizedString("incomplete_image_data", comment: "Incomplete image data - missing chunks"))
                return
            }
        }
        
        // Combine all chunks in order
        var completeData = Data()
        for (index, chunk) in receivedChunks.enumerated() {
            completeData.append(chunk)
            print("  ✓ Assembled chunk \(index): \(chunk.count) bytes")
        }
        
        print("🖼️ Image assembly complete: \(completeData.count) bytes")
        
        // Convert to UIImage
        guard let image = UIImage(data: completeData) else {
            finishReceive(success: false, message: NSLocalizedString("failed_decode_image", comment: "Failed to decode image"))
            return
        }
        
        print("✅ Image decoded successfully")
        
        finishReceive(success: true, message: NSLocalizedString("image_received_success", comment: "Image received successfully"))
        
        DispatchQueue.main.async {
            self.onImageReceived?(image)
        }
    }
    
    private func startReceiveTimeout() {
        receiveTimeout = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.finishReceive(success: false, message: NSLocalizedString("image_receive_timeout", comment: "Image receive timeout"))
        }
    }
    
    private func finishReceive(success: Bool, message: String) {
        receiveInProgress = false

        completionReceived = false
        cancelCompletionDelayTimer()
        
        if success {
            print("✅ \(message)")
        } else {
            print("❌ \(message)")
            onError?(message)
        }
        
        // Cleanup
        receiveTimeout?.invalidate()
        receiveTimeout = nil
        
        if let obs = imageChunkObserver {
            NotificationCenter.default.removeObserver(obs)
            imageChunkObserver = nil
        }
        
        if let obs = transferStartObserver {
            NotificationCenter.default.removeObserver(obs)
            transferStartObserver = nil
        }
        receivedChunkCount = 0
    }
    
    func cancelReceive() {
        guard receiveInProgress else { return }
        
        receiveInProgress = false
        receivedChunks.removeAll()
        expectedChunks = 0
        receivedChunkCount = 0
        
        receiveTimeout?.invalidate()
        receiveTimeout = nil

        completionReceived = false
        cancelCompletionDelayTimer()
        
        if let obs = imageChunkObserver {
            NotificationCenter.default.removeObserver(obs)
            imageChunkObserver = nil
        }
        
        if let obs = transferStartObserver {
            NotificationCenter.default.removeObserver(obs)
            transferStartObserver = nil
        }
        
        print("🛑 Image receive cancelled")
    }
    
    func cleanup() {
        cancelReceive()
    }
}
