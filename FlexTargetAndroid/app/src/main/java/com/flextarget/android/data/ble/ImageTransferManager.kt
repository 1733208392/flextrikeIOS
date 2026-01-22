package com.flextarget.android.data.ble

import android.graphics.Bitmap
import android.util.Log
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/// Manages chunked image transfer over BLE with compression
class ImageTransferManager(
    private val bleManager: BLEManager
) {
    private val chunkSize: Int = 100  // Bytes per chunk (safe MTU)
    private val timeoutInterval: Long = 10000  // 10 seconds

    // Transfer state
    private var transferInProgress = false
    private var currentChunks: List<ByteArray> = emptyList()
    private var currentChunkIndex = 0
    private var transferCompletion: ((Boolean, String) -> Unit)? = null
    private var progressHandler: ((Int) -> Unit)? = null
    private var transferJob: Job? = null

    // Device management
    private var masterDeviceName: String = "ET02"  // Default fallback
    private var readyObserver: Any? = null
    private var readyTimer: Job? = null

    // Public method to set the master device name
    fun setMasterDeviceName(name: String) {
        masterDeviceName = name
    }

    // MARK: - Public Methods

    /// Transfer an image over BLE with automatic compression
    /// - Parameters:
    ///   - image: Bitmap to transfer
    ///   - imageName: Name identifier for the image
    ///   - compressionQuality: JPEG quality 0.0-1.0 (default 0.2)
    ///   - completion: (success, message)
    fun transferImage(
        image: Bitmap,
        imageName: String,
        compressionQuality: Float = 0.2f,
        progress: ((Int) -> Unit)? = null,
        completion: (Boolean, String) -> Unit
    ) {
        if (transferInProgress) {
            completion(false, "Transfer already in progress")
            return
        }

        if (!bleManager.isConnected) {
            completion(false, "BLE not connected")
            return
        }

        // Query device list to get the master device name
        queryAndResolveDeviceList(image, imageName, compressionQuality, progress, completion)
    }

    fun cancelTransfer() {
        transferJob?.cancel()
        readyTimer?.cancel()
        transferInProgress = false
        currentChunks = emptyList()
        currentChunkIndex = 0
        transferCompletion = null
        progressHandler = null
        readyObserver = null
    }

    // MARK: - Device List Query

    /// Query device list and resolve the master device
    /// Only accepts devices with mode == "master"
    private fun queryAndResolveDeviceList(
        image: Bitmap,
        imageName: String,
        compressionQuality: Float,
        progress: ((Int) -> Unit)?,
        completion: (Boolean, String) -> Unit
    ) {
        // First, check if we already have devices and can find master
        if (resolveMasterDeviceFromCurrentList()) {
            Log.d("ImageTransfer", "🎯 Master device resolved: $masterDeviceName")
            prepareAndStartTransfer(image, imageName, compressionQuality, progress, completion)
            return
        }

        // If no master found in current list, send query command
        Log.d("ImageTransfer", "Querying device list to find master device...")
        
        val command = mapOf("action" to "netlink_query_device_list")
        val jsonString = org.json.JSONObject(command).toString()
        bleManager.writeJSON(jsonString)

        // Wait for device list update with timeout
        transferJob = CoroutineScope(Dispatchers.Main).launch {
            var attempts = 0
            val maxAttempts = 20  // 2 seconds with 100ms checks
            
            while (attempts < maxAttempts) {
                if (resolveMasterDeviceFromCurrentList()) {
                    Log.d("ImageTransfer", "🎯 Master device found: $masterDeviceName")
                    prepareAndStartTransfer(image, imageName, compressionQuality, progress, completion)
                    return@launch
                }
                delay(100)
                attempts++
            }
            
            // Timeout - no master device found
            Log.e("ImageTransfer", "❌ No master device found after device list query (waited ${maxAttempts * 100}ms)")
            Log.e("ImageTransfer", "Available devices: ${bleManager.networkDevices.size} (looking for mode='master')")
            transferInProgress = false
            completion(false, "No master device available")
        }
    }

    /// Resolve master device from current device list
    /// Only accepts devices with mode == "master"
    /// Returns true if master device is found and set
    private fun resolveMasterDeviceFromCurrentList(): Boolean {
        val devices = bleManager.networkDevices
        
        if (devices.isEmpty()) {
            return false
        }
        
        // Find device with mode == "master" - strict requirement
        val masterDevice = devices.firstOrNull { it.mode == "master" }
        
        return if (masterDevice != null) {
            masterDeviceName = masterDevice.name
            true
        } else {
            Log.d("ImageTransfer", "⚠️ No master device in list")
            false
        }
    }



    private fun prepareAndStartTransfer(
        image: Bitmap,
        imageName: String,
        compressionQuality: Float,
        progress: ((Int) -> Unit)?,
        completion: (Boolean, String) -> Unit
    ) {
        // Compress image to JPEG
        val compressedData = compressImage(image, compressionQuality)
        if (compressedData.isEmpty()) {
            completion(false, "Failed to compress image")
            return
        }

        Log.d("ImageTransfer", "Preparing image transfer: $imageName")
        Log.d("ImageTransfer", "Original size: ${compressedData.size} bytes")

        // Prepare chunks but do not start sending until the device ACKs readiness
        transferInProgress = true
        transferCompletion = completion
        progressHandler = progress
        currentChunkIndex = 0
        currentChunks = createChunks(compressedData, chunkSize)

        Log.d("ImageTransfer", "Compressed size: ${compressedData.size} bytes")
        Log.d("ImageTransfer", "Chunks: ${currentChunks.size} × $chunkSize bytes")
        Log.d("ImageTransfer", "Target device: $masterDeviceName")

        // Send a readiness command to the device and wait for an ACK
        sendReadyCommandAndAwaitAck(imageName, compressedData.size, currentChunks.size)
    }

    // MARK: - Ready handshake

    private fun sendReadyCommandAndAwaitAck(imageName: String, totalSize: Int, totalChunks: Int) {
        Log.d("ImageTransfer", "🤝 Registering observer for image_transfer_ready ACK...")
        
        // Register observer for incoming netlink forward messages
        bleManager.onNetlinkForwardReceived = { json ->
            Log.d("ImageTransfer", "📨 Received netlink message: $json")
            
            // The ACK may appear at top-level or inside content
            var ackValue: String? = null
            val content = json["content"] as? Map<String, Any>
            if (content != null) {
                ackValue = content["ack"] as? String
            } else {
                ackValue = json["ack"] as? String
            }

            Log.d("ImageTransfer", "Checking ACK value: $ackValue")
            
            if (ackValue == "image_transfer_ready") {
                Log.d("ImageTransfer", "✅ Received image_transfer_ready ACK!")
                // ACK received — cancel timer & observer and start transfer
                readyTimer?.cancel()
                readyTimer = null
                // Keep observer active until transfer starts - don't clear it here
                
                // Small delay to ensure target has finished handshake processing
                transferJob = CoroutineScope(Dispatchers.Main).launch {
                    delay(200)
                    sendTransferStart(imageName, totalSize, totalChunks)
                }
            }
        }

        // Send the ready command - build JSON with sorted keys (alphabetical order)
        val contentObj = org.json.JSONObject()
        contentObj.put("command", "image_transfer_ready")
        
        val messageObj = org.json.JSONObject()
        messageObj.put("action", "netlink_forward")
        messageObj.put("content", contentObj)
        messageObj.put("dest", masterDeviceName)
        
        val jsonString = messageObj.toString()
        Log.d("ImageTransfer", "📤 Sending image_transfer_ready command to $masterDeviceName...")
        Log.d("ImageTransfer", "JSON: $jsonString")
        bleManager.writeJSON(jsonString)

        // Start guard timer: if no ACK within configured timeout, cancel transfer
        readyTimer = CoroutineScope(Dispatchers.Main).launch {
            delay(timeoutInterval)
            // Remove observer
            bleManager.onNetlinkForwardReceived = null
            readyTimer = null
            Log.e("ImageTransfer", "❌ Timeout waiting for image_transfer_ready ACK")
            failTransfer("Target not ready to receive image")
        }
    }

    private fun sendTransferStart(imageName: String, totalSize: Int, totalChunks: Int) {
        // Build JSON with sorted keys (alphabetical order)
        // Content fields: chunk_size, command, image_name, total_chunks, total_size
        val contentObj = org.json.JSONObject()
        contentObj.put("chunk_size", chunkSize)
        contentObj.put("command", "image_transfer_start")
        contentObj.put("image_name", imageName)
        contentObj.put("total_chunks", totalChunks)
        contentObj.put("total_size", totalSize)
        
        val messageObj = org.json.JSONObject()
        messageObj.put("action", "netlink_forward")
        messageObj.put("content", contentObj)
        messageObj.put("dest", masterDeviceName)
        
        val jsonString = messageObj.toString()
        Log.d("ImageTransfer", "📤 Sending image_transfer_start command...")
        Log.d("ImageTransfer", "JSON: $jsonString")
        bleManager.writeJSON(jsonString)

        // Wait for acknowledgment then start sending chunks
        transferJob = CoroutineScope(Dispatchers.Main).launch {
            Log.d("ImageTransfer", "⏳ Waiting 500ms before starting chunk transfer...")
            delay(500)
            Log.d("ImageTransfer", "🚀 Starting chunk transmission (${currentChunks.size} chunks)...")
            sendNextChunk()
        }
    }

    private fun sendNextChunk() {
        Log.d("ImageTransfer", "sendNextChunk() called: transferInProgress=$transferInProgress, currentChunkIndex=$currentChunkIndex, totalChunks=${currentChunks.size}")
        
        if (!transferInProgress) {
            Log.e("ImageTransfer", "❌ Transfer not in progress, aborting sendNextChunk()")
            return
        }

        if (currentChunkIndex >= currentChunks.size) {
            Log.d("ImageTransfer", "✅ All chunks sent, sending transfer complete command...")
            // All chunks sent, send end command
            sendTransferEnd()
            return
        }

        val chunk = currentChunks[currentChunkIndex]
        Log.d("ImageTransfer", "📨 Sending chunk $currentChunkIndex/${currentChunks.size} (${chunk.size} bytes)...")
        
        if (!sendChunk(chunk, currentChunkIndex)) {
            Log.e("ImageTransfer", "❌ Failed to send chunk $currentChunkIndex")
            CoroutineScope(Dispatchers.Main).launch {
                failTransfer("Failed to send chunk $currentChunkIndex")
            }
            return
        }

        // Update progress
        val progress = ((currentChunkIndex + 1).toFloat() / currentChunks.size * 100).toInt()
        Log.d("ImageTransfer", "📊 Transfer progress: $progress% (${currentChunkIndex + 1}/${currentChunks.size})")
        progressHandler?.invoke(progress)

        currentChunkIndex++

        // Send next chunk after a small delay
        transferJob = CoroutineScope(Dispatchers.Main).launch {
            delay(500)  // Increased delay to match iOS (was 50ms)
            sendNextChunk()
        }
    }

    // MARK: - Private Methods

    private fun compressImage(image: Bitmap, quality: Float): ByteArray {
        Log.d("ImageTransfer", "Compressing image: ${image.width}x${image.height}, quality: $quality")
        val outputStream = ByteArrayOutputStream()
        val success = image.compress(Bitmap.CompressFormat.JPEG, (quality * 100).toInt(), outputStream)
        val data = outputStream.toByteArray()
        Log.d("ImageTransfer", "Compression ${if (success) "successful" else "failed"}, output size: ${data.size} bytes")
        if (data.isNotEmpty()) {
            Log.d("ImageTransfer", "First 10 bytes: ${data.take(10).joinToString(", ") { "0x%02x".format(it) }}")
        }
        return if (success) data else byteArrayOf()
    }

    private fun createChunks(data: ByteArray, chunkSize: Int): List<ByteArray> {
        Log.d("ImageTransfer", "Creating chunks: ${data.size} bytes, chunkSize: $chunkSize")
        val chunks = mutableListOf<ByteArray>()
        var offset = 0

        while (offset < data.size) {
            val remaining = data.size - offset
            val currentChunkSize = minOf(chunkSize, remaining)
            val chunk = data.copyOfRange(offset, offset + currentChunkSize)
            chunks.add(chunk)
            Log.d("ImageTransfer", "Created chunk ${chunks.size - 1}: $currentChunkSize bytes")
            offset += currentChunkSize
        }
        
        Log.d("ImageTransfer", "Total chunks created: ${chunks.size}")
        return chunks
    }

    private fun sendChunk(chunk: ByteArray, index: Int): Boolean {
        Log.d("ImageTransfer", "📦 Encoding chunk $index: ${chunk.size} bytes...")
        
        val base64String = android.util.Base64.encodeToString(chunk, android.util.Base64.NO_WRAP)
        
        // Build JSON with sorted keys (matching iOS .sortedKeys behavior)
        // iOS outputs: chunk_index, command, data (alphabetical order)
        val content = org.json.JSONObject()
        content.put("chunk_index", index)  // First alphabetically
        content.put("command", "image_chunk")  // Second alphabetically
        content.put("data", base64String)  // Third alphabetically
        
        val message = org.json.JSONObject()
        message.put("action", "netlink_forward")
        message.put("content", content)
        message.put("dest", masterDeviceName)
        
        val jsonString = message.toString()
        Log.d("ImageTransfer", "📤 Writing chunk $index to BLE (base64: ${base64String.length} chars)...")
        Log.d("ImageTransfer", "JSON: $jsonString")
        bleManager.writeJSON(jsonString)

        Log.d("ImageTransfer", "✓ Chunk $index sent successfully")
        return true
    }

    private fun sendTransferEnd() {
        // Build JSON with sorted keys (alphabetical order)
        // Content fields: command, status
        val contentObj = org.json.JSONObject()
        contentObj.put("command", "image_transfer_complete")
        contentObj.put("status", "success")
        
        val messageObj = org.json.JSONObject()
        messageObj.put("action", "netlink_forward")
        messageObj.put("content", contentObj)
        messageObj.put("dest", masterDeviceName)
        
        val jsonString = messageObj.toString()
        Log.d("ImageTransfer", "📋 Sending image_transfer_complete command...")
        Log.d("ImageTransfer", "JSON: $jsonString")
        bleManager.writeJSON(jsonString)

        // Success
        Log.d("ImageTransfer", "🎉 Image transferred successfully!")
        transferCompletion?.invoke(true, "Image transferred successfully")
        transferInProgress = false
    }

    private suspend fun failTransfer(message: String) {
        withContext(Dispatchers.Main) {
            transferCompletion?.invoke(false, message)
        }
        transferInProgress = false
    }
}