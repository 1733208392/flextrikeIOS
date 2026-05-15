package com.flextarget.android.data.ble

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.ActivityCompat
import java.util.*
import org.json.JSONObject
import com.google.gson.Gson
import com.flextarget.android.data.model.ShotData
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import org.json.JSONArray

/**
 * Android BLE Manager implementation
 * Handles Bluetooth Low Energy operations for smart target communication
 */
class AndroidBLEManager(private val context: Context) {

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    // Use a property getter so bluetoothLeScanner is fetched fresh on every access.
    // Caching it at construction time returns null when BLUETOOTH_SCAN permission
    // hasn't been granted yet, permanently breaking all subsequent scans.
    private val bluetoothLeScanner get() = bluetoothAdapter?.bluetoothLeScanner
    private val handler = Handler(Looper.getMainLooper())

    // BLE service and characteristic UUIDs (matching iOS)
    private val advServiceUUID = UUID.fromString("0000FFC9-0000-1000-8000-00805F9B34FB")
    private val targetServiceUUID = UUID.fromString("0000FFC9-0000-1000-8000-00805F9B34FB")
    private val notifyCharacteristicUUID = UUID.fromString("0000FFE1-0000-1000-8000-00805F9B34FB")
    private val writeCharacteristicUUID = UUID.fromString("0000FFE2-0000-1000-8000-00805F9B34FB")

    // Connection state
    var isConnected = false
    var isReady = false
    var connectedPeripheral: BluetoothDevice? = null
    var error: String? = null

    // Callback for shot data
    var onShotReceived: ((ShotData) -> Unit)? = null

    private val _netlinkForwardMessage = MutableSharedFlow<JSONObject>(extraBufferCapacity = 10)
    val netlinkForwardMessage: SharedFlow<JSONObject> = _netlinkForwardMessage.asSharedFlow()

    // Callback for netlink forward messages (acks, etc.)
    var onNetlinkForwardReceived: ((Map<String, Any>) -> Unit)? = null

    // Callback for forward messages
    var onForwardReceived: ((Map<String, Any>) -> Unit)? = null

    // Callback for auth data response
    var onAuthDataReceived: ((String) -> Unit)? = null

    // Physical popper hit callback — invoked when compose directive arrives from a target device.
    // The string parameter is the constructed target name (shortDeviceId + "-01").
    var onPopperHitReceived: ((String) -> Unit)? = null

    // OTA Callbacks
    var onGameDiskOTAReady: (() -> Unit)? = null
    var onOTAPreparationFailed: ((String) -> Unit)? = null
    var onBLEErrorOccurred: (() -> Unit)? = null
    var onReadyToDownload: (() -> Unit)? = null
    var onDownloadComplete: ((String) -> Unit)? = null
    var onVersionInfoReceived: ((String) -> Unit)? = null
    var onDeviceVersionUpdated: ((String) -> Unit)? = null

    private var bluetoothGatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null

    @Volatile internal var writeCompletion: ((Boolean) -> Unit)? = null

    // Message-level send queue — serialises concurrent writeJSON() calls so that all chunks of one
    // JSON message are delivered before the next message begins. The low-level write() / writeChunks()
    // are unchanged and remain "one chunk at a time via callback" as before.
    private val messageQueue: ArrayDeque<String> = ArrayDeque()
    private var isSendingMessage: Boolean = false
    private val messageSendLock = Any()

    private val messageBuffer = mutableListOf<Byte>()
    private val messageBufferLock = Any() // Thread-safe synchronization for buffer operations
    private val MAX_BUFFER_SIZE = 1024 * 10 // 10KB max buffer size
    private val netlinkForwardListeners = mutableListOf<((Map<String, Any>) -> Unit)>()
    private val netlinkForwardListenersLock = Any()
    private var pendingPeripheral: DiscoveredPeripheral? = null
    
    // Multi-device discovery properties
    private var discoveryTimeoutHandler: Handler? = null
    private var discoveryTimeoutRunnable: Runnable? = null
    private val discoveryTimeout: Long = 3000L // 3 seconds
    private val serviceDiscoveryDelayMs = 600L
    private val connectRetryDelayMs = 1200L
    private var hasRetriedConnection = false

    // Scan callback
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val scanRecord = result.scanRecord
            // On Android 12+, BluetoothDevice.name requires BLUETOOTH_CONNECT and returns
            // null for unpaired devices. The advertisement "Complete/Shortened Local Name"
            // field is the correct source for the device name during scanning.
            val deviceName = scanRecord?.deviceName ?: device.name ?: "Unknown"

            val serviceUuids = scanRecord?.serviceUuids
            val hasTargetService = serviceUuids?.any { it.uuid == advServiceUUID } == true
            // Only process devices that advertise the target service UUID, or that
            // explicitly match the auto-connect target name.  Accepting every device
            // when autoConnectTargetName is set floods discoveredPeripherals with
            // unrelated devices.
            val shouldProcess = hasTargetService ||
                (BLEManager.shared.autoConnectTargetName?.let { matchesName(deviceName, it) } ?: false)

            if (!shouldProcess) {
                return
            }

            val discovered = DiscoveredPeripheral(
                id = UUID.randomUUID(),
                name = deviceName,
                device = device
            )

            if (BLEManager.shared.discoveredPeripherals.none { it.device.address == device.address }) {
                BLEManager.shared.discoveredPeripherals = BLEManager.shared.discoveredPeripherals + discovered
            }

            // If an auto-connect target name is set, connect to matching device
            BLEManager.shared.autoConnectTargetName?.let { targetName ->
                if (matchesName(deviceName, targetName)) {
                    stopScan()
                    connectToSelectedPeripheral(discovered)
                }
            } ?: run {
                // No auto-connect target set, start/extend discovery timeout to collect multiple devices
                startDiscoveryTimeout()
            }
        }

        override fun onScanFailed(errorCode: Int) {
            BLEManager.shared.error = BLEError.Unknown("Scan failed with code: $errorCode")
            BLEManager.shared.isScanning = false
        }
    }
    
    private fun startDiscoveryTimeout() {
        // Reset the discovery timeout timer to allow more time for other devices to be discovered
        discoveryTimeoutRunnable?.let { discoveryTimeoutHandler?.removeCallbacks(it) }
        
        discoveryTimeoutHandler = Handler(Looper.getMainLooper())
        discoveryTimeoutRunnable = Runnable {
            handleDiscoveryTimeout()
        }
        discoveryTimeoutHandler?.postDelayed(discoveryTimeoutRunnable!!, discoveryTimeout)
    }
    
    private fun handleDiscoveryTimeout() {
        println("[AndroidBLEManager] Discovery timeout reached. Total devices found: ${BLEManager.shared.discoveredPeripherals.size}")
        
        when {
            BLEManager.shared.discoveredPeripherals.isEmpty() -> {
                println("[AndroidBLEManager] No devices discovered within timeout")
                stopScan()
                // On Samsung devices, if BLE scan starts (MESSAGE_SCAN_START in logcat) but
                // delivers zero results and onScanFailed never fires, the root cause is the
                // "Bluetooth scanning" toggle in Settings → Location → Location services being off.
                if (android.os.Build.MANUFACTURER.equals("samsung", ignoreCase = true)) {
                    android.util.Log.w("AndroidBLEManager",
                        "Samsung + 0 scan results + no onScanFailed: 'Bluetooth scanning' location toggle is likely OFF")
                    BLEManager.shared.error = BLEError.SamsungBluetoothScanningDisabled
                }
            }
            BLEManager.shared.discoveredPeripherals.size == 1 -> {
                // Single device found - auto-connect if in auto-detect mode
                if (BLEManager.shared.autoDetectMode && !BLEManager.shared.isConnected) {
                    println("[AndroidBLEManager] Single device found: ${BLEManager.shared.discoveredPeripherals[0].name}. Auto-connecting.")
                    stopScan()
                    connectToSelectedPeripheral(BLEManager.shared.discoveredPeripherals[0])
                } else {
                    // Auto-detect mode off or already connected - just stop scan
                    stopScan()
                }
            }
            else -> {
                // Multiple devices found - show picker for user selection
                println("[AndroidBLEManager] Multiple devices found: ${BLEManager.shared.discoveredPeripherals.map { it.name }}. Showing device picker.")
                stopScan()
                BLEManager.shared.showMultiDevicePicker = true
            }
        }
    }
    
    fun clearDiscoveryTimeout() {
        discoveryTimeoutRunnable?.let { discoveryTimeoutHandler?.removeCallbacks(it) }
        discoveryTimeoutHandler = null
        discoveryTimeoutRunnable = null
    }

    // GATT callback
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            println("[AndroidBLEManager] onConnectionStateChange - status: $status, newState: $newState")
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    println("[AndroidBLEManager] Connected to device")
                    BLEManager.shared.error = null
                    hasRetriedConnection = false
                    synchronized(this@AndroidBLEManager) {
                        bluetoothGatt = gatt
                    }
                    // Samsung devices can be flaky if service discovery starts immediately.
                    // Delay briefly after connect to avoid transient 129/133 failures.
                    handler.postDelayed({
                        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                            gatt.discoverServices()
                        }
                    }, serviceDiscoveryDelayMs)
                    // Stop auto-detection when connected
                    BLEManager.shared.stopAutoDetection()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    println("[AndroidBLEManager] Disconnected from device")
                    // Synchronize to prevent conflict with explicit disconnect() calls
                    synchronized(this@AndroidBLEManager) {
                        // Only update state if we still have this GATT object
                        // (disconnect() may have already cleared it)
                        if (bluetoothGatt === gatt) {
                            BLEManager.shared.isConnected = false
                            BLEManager.shared.isReady = false
                            BLEManager.shared.connectedPeripheral = null
                            bluetoothGatt = null
                            writeCharacteristic = null
                            notifyCharacteristic = null
                            pendingPeripheral = null
                        }
                    }

                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        this@AndroidBLEManager.error = "Disconnected with status: $status"
                        if (!hasRetriedConnection && shouldRetryConnection(status)) {
                            hasRetriedConnection = true
                            val retryPeripheral = pendingPeripheral
                            if (retryPeripheral != null) {
                                println("[AndroidBLEManager] Retrying connection after transient GATT status: $status")
                                handler.postDelayed({
                                    connectToSelectedPeripheral(retryPeripheral)
                                }, connectRetryDelayMs)
                                return
                            }
                        }
                    }
                    // Start auto-detection when disconnected
                    BLEManager.shared.startAutoDetection()
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(targetServiceUUID)
                if (service != null) {
                    println("[AndroidBLEManager] Service discovered, looking for characteristics...")
                    // Discover characteristics
                    if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                        service.characteristics.forEach { characteristic ->
                            println("[AndroidBLEManager] Found characteristic: ${characteristic.uuid}")
                            when (characteristic.uuid) {
                                writeCharacteristicUUID -> {
                                    writeCharacteristic = characteristic
                                    println("[AndroidBLEManager] Found write characteristic")
                                }
                                notifyCharacteristicUUID -> {
                                    notifyCharacteristic = characteristic
                                    println("[AndroidBLEManager] Found notify characteristic")
                                    // Enable notifications
                                    gatt.setCharacteristicNotification(characteristic, true)
                                    val descriptor = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                                    descriptor?.let {
                                        it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                        gatt.writeDescriptor(it)
                                    }
                                }
                            }
                        }

                        // Check if ready
                        val ready = writeCharacteristic != null && notifyCharacteristic != null
                        this@AndroidBLEManager.isReady = ready
                        BLEManager.shared.isReady = ready
                        println("[AndroidBLEManager] Ready: $ready (write: ${writeCharacteristic != null}, notify: ${notifyCharacteristic != null})")
                        if (ready) {
                            this@AndroidBLEManager.isConnected = true
                            BLEManager.shared.isConnected = true
                            pendingPeripheral?.let {
                                BLEManager.shared.connectedPeripheral = it
                            }
                            // Auto-query device version on first connection
                            queryVersion()
                            println("[AndroidBLEManager] Auto-querying device version on connection")
                        }
                    }
                } else {
                    println("[AndroidBLEManager] Target service not found")
                    this@AndroidBLEManager.error = "Target service not found"
                    disconnect()
                }
            } else {
                println("[AndroidBLEManager] Service discovery failed with status: $status")
                BLEManager.shared.error = BLEError.Unknown("Service discovery failed: $status")
                BLEManager.shared.isConnected = false
                pendingPeripheral = null
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val data = characteristic.value ?: return
            println("[AndroidBLEManager] onCharacteristicChanged - received ${data.size} bytes")

            // Accumulate received data in buffer and extract complete messages atomically.
            // BLE callbacks can arrive on multiple Binder threads - synchronized for thread safety.
            val completeMessages = synchronized(messageBufferLock) {
                // Check buffer size before adding new data
                if (messageBuffer.size + data.size > MAX_BUFFER_SIZE) {
                    println("[AndroidBLEManager] Buffer overflow detected (${messageBuffer.size + data.size} bytes), clearing buffer")
                    messageBuffer.clear()
                }

                messageBuffer.addAll(data.toList())
                extractCompleteMessagesFromBuffer()
            }

            println("[AndroidBLEManager] Extracted ${completeMessages.size} complete messages from buffer")
            completeMessages.forEach { completeMessage ->
                try {
                    processMessage(completeMessage)
                } catch (e: Exception) {
                    println("[AndroidBLEManager] Failed to parse BLE message: $completeMessage, error: ${e.message}")
                    e.printStackTrace()
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            writeCompletion?.invoke(status == BluetoothGatt.GATT_SUCCESS)
            writeCompletion = null
        }
    }

    private fun extractCompleteMessagesFromBuffer(): List<String> {
        // FW Workaround: Extract complete JSON objects from buffer using brace-counting
        // This prevents corrupted partial messages from being parsed
        var currentIndex = 0
        var braceCount = 0
        var messageStart = -1
        val completeMessages = mutableListOf<String>()

        val bufferString = String(messageBuffer.toByteArray(), Charsets.UTF_8)
        println("[AndroidBLEManager] extractCompleteMessagesFromBuffer - buffer has ${messageBuffer.size} bytes, string: $bufferString")

        for (i in bufferString.indices) {
            val char = bufferString[i]

            if (char == '{') {
                if (braceCount == 0) {
                    messageStart = i
                }
                braceCount++
            } else if (char == '}') {
                braceCount--

                // Complete message found
                if (braceCount == 0 && messageStart != -1) {
                    val message = bufferString.substring(messageStart, i + 1)
                    completeMessages.add(message)
                    println("[AndroidBLEManager] Extracted complete message: $message")
                    currentIndex = i + 1
                }
            }
        }

        // Remove processed messages from buffer, including any garbage before the next message
        if (currentIndex > 0) {
            repeat(currentIndex.coerceAtMost(messageBuffer.size)) {
                if (messageBuffer.isNotEmpty()) {
                    messageBuffer.removeAt(0)
                }
            }
            println("[AndroidBLEManager] Removed $currentIndex bytes from buffer, remaining: ${messageBuffer.size} bytes")
        }
        
        // If there's still data left and it doesn't start with {, find the next { and discard everything before it
        // This cleans up any garbage that might have been received before a new message
        if (messageBuffer.isNotEmpty()) {
            val remainingString = String(messageBuffer.toByteArray(), Charsets.UTF_8)
            val nextOpenBrace = remainingString.indexOf('{')
            if (nextOpenBrace > 0) {
                val garbageFound = remainingString.substring(0, nextOpenBrace)
                println("[AndroidBLEManager] Found garbage before next message: $garbageFound")
                println("[AndroidBLEManager] Discarding $nextOpenBrace garbage bytes")
                repeat(nextOpenBrace) {
                    if (messageBuffer.isNotEmpty()) {
                        messageBuffer.removeAt(0)
                    }
                }
            }
        }

        return completeMessages
    }

    private fun findLastSeparator(buffer: List<Byte>, separator: List<Byte>): Int {
        if (buffer.size < separator.size) return -1

        for (i in buffer.size - separator.size downTo 0) {
            if (buffer.subList(i, i + separator.size) == separator) {
                return i
            }
        }
        return -1
    }

    private fun processMessage(message: String) {
        println("[AndroidBLEManager] Received BLE message: $message")
        // Parse JSON and handle notifications similar to iOS
        try {
            val json = org.json.JSONObject(message)
            val type = json.optString("type")
            val action = json.optString("action")

            when {
                type == "auth_data" && json.has("content") -> {
                    // Handle auth data response from device
                    val authData = json.getString("content")
                    println("[AndroidBLEManager] Received auth_data: $authData")
                    this.onAuthDataReceived?.invoke(authData)
                }
                type == "notice" && action == "netlink_query_device_list" && json.optString("state") == "failure" -> {
                    // Handle netlink not enabled failure
                    val message = json.optString("message", "Unknown error")
                    println("[AndroidBLEManager] Received netlink failure notice: $message")
                    BLEManager.shared.error = BLEError.Unknown(message)
                    BLEManager.shared.errorMessage = message
                    BLEManager.shared.showErrorAlert = true
                }
                type == "netlink" && action == "device_list" -> {
                    val dataArray = json.optJSONArray("data")
                    println("[AndroidBLEManager] Processing netlink device_list, dataArray: $dataArray")
                    if (dataArray != null) {
                        val devices = mutableListOf<NetworkDevice>()
                        for (i in 0 until dataArray.length()) {
                            val deviceJson = dataArray.getJSONObject(i)
                            val device = NetworkDevice(
                                id = UUID.randomUUID(),
                                name = deviceJson.optString("name", "Unknown"),
                                mode = deviceJson.optString("mode", "")
                            )
                            devices.add(device)
                            println("[AndroidBLEManager] Added device: ${device.name} (mode: ${device.mode})")
                        }
                        println("[AndroidBLEManager] Received netlink device_list with ${devices.size} devices: $devices")
                        BLEManager.shared.networkDevices = devices
                        BLEManager.shared.lastDeviceListUpdate = Date()
                        println("[AndroidBLEManager] Updated BLEManager.shared.networkDevices to ${BLEManager.shared.networkDevices.size} devices")
                    } else {
                        println("[AndroidBLEManager] device_list dataArray is null!")
                    }
                }
                type == "netlink" && action == "forward" -> {
                    // Handle all netlink forward messages
                    val messageMap = jsonToMap(json)
                    
                    // Emit to SharedFlow for modern reactive handling
                    _netlinkForwardMessage.tryEmit(json)
                    
                    // Notify legacy callback for backward compatibility
                    this.onNetlinkForwardReceived?.invoke(messageMap)
                    
                    // Notify all registered listeners
                    synchronized(netlinkForwardListenersLock) {
                        netlinkForwardListeners.forEach { listener ->
                            try {
                                listener(messageMap)
                            } catch (e: Exception) {
                                println("[AndroidBLEManager] Error in netlink forward listener: ${e.message}")
                            }
                        }
                    }

                    // Specifically handle shot data from targets
                    val content = json.optJSONObject("content")
                    if (content != null && (content.optString("command") == "shot" || content.optString("cmd") == "shot")) {
                        println("Received shot data: $json")
                        val shotData = Gson().fromJson(json.toString(), ShotData::class.java)
                        this.onShotReceived?.invoke(shotData)
                    }

                    // Handle physical popper trigger: compose directive from a target device
                    if (content != null &&
                        content.optString("action") == "remote_control" &&
                        content.optString("directive") == "compose") {
                        val shortId = json.optString("device")
                        if (shortId.isNotEmpty()) {
                            val targetName = "$shortId-01"
                            println("[AndroidBLEManager] Physical popper hit from device: $shortId -> targetName: $targetName")
                            this.onPopperHitReceived?.invoke(targetName)
                        }
                    }
                }
                type == "forward" -> {
                    // Handle forward messages with different content types
                    val content = json.optJSONObject("content")
                    if (content != null) {
                        // Check for provision completion FIRST (started: true, work_mode: master)
                        val started = content.opt("started")
                        val isStarted = started == true || started == 1
                        val workMode = content.optString("work_mode")
                        if (isStarted && workMode == "master") {
                            println("[AndroidBLEManager] Detected provision completion: started=true, work_mode=master")
                            BLEManager.shared.provisionInProgress = false
                            BLEManager.shared.provisionCompleted = true
                            BLEManager.shared.stopProvisionVerificationPublic()
                            // Invoke callback for any listeners
                            val messageMap = jsonToMap(json)
                            this.onForwardReceived?.invoke(messageMap)
                        }
                        // Check for WiFi SSID request
                        else if (content.has("ssid")) {
                            val messageMap = jsonToMap(json)
                            this.onForwardReceived?.invoke(messageMap)
                        }
                        // Check for workmode from Godot
                        else if (content.has("workmode")) {
                            val messageMap = jsonToMap(json)
                            this.onForwardReceived?.invoke(messageMap)
                        }
                        // Check for provision_status
                        else if (content.has("provision_status")) {
                            val provisionStatus = content.optString("provision_status")
                            println("[AndroidBLEManager] Received provision_status: $provisionStatus")
                            BLEManager.shared.onProvisionStatusReceived?.invoke(provisionStatus)
                        }
                        // Check for OTA notifications
                        else if (content.optString("notification") == "ready_to_download") {
                            println("[AndroidBLEManager] Received OTA ready_to_download notification")
                            BLEManager.shared.onReadyToDownload?.invoke()
                        }
                        else if (content.optString("notification") == "download_complete") {
                            val version = content.optString("version")
                            println("[AndroidBLEManager] Received OTA download complete (forwarded): $version")
                            BLEManager.shared.onDownloadComplete?.invoke(version)
                        }
                        // Check for OTA version info
                        else if (content.has("version")) {
                            val version = content.optString("version")
                            println("[AndroidBLEManager] Received device version info (forwarded): $version")
                            BLEManager.shared.onDeviceVersionUpdated?.invoke(version)
                        }
                    }
                    
                    // Always emit forward messages to the netlink flow for game UI listeners
                    _netlinkForwardMessage.tryEmit(json)
                }
                // OTA Messages - matching iOS format
                // Handle prepare_game_disk_ota success
                type == "notice" && action == "prepare_game_disk_ota" && json.optString("state") == "success" -> {
                    println("[AndroidBLEManager] Received prepare_game_disk_ota success confirmation: Device entering OTA mode")
                    BLEManager.shared.onGameDiskOTAReady?.invoke()
                }
                // Handle prepare_game_disk_ota failure
                type == "notice" && action == "prepare_game_disk_ota" && json.optString("state") == "failure" -> {
                    val failureReason = json.optString("failure_reason", "Unknown error")
                    val message = json.optString("message", "Device failed to enter OTA mode")
                    println("[AndroidBLEManager] Received prepare_game_disk_ota failure: $failureReason - $message")
                    
                    // Check if it's a game disk not found error
                    if (failureReason.lowercase().contains("game disk not found") || 
                        message.lowercase().contains("game disk not found")) {
                        BLEManager.shared.onOTAPreparationFailed?.invoke("game_disk_not_found")
                    } else {
                        BLEManager.shared.onBLEErrorOccurred?.invoke()
                    }
                }
                // Handle OTA "download complete" notification (Top-level fallback)
                json.has("notification") && json.optString("notification") == "download_complete" -> {
                    val version = json.optString("version")
                    println("[AndroidBLEManager] Received OTA download complete: $version")
                    BLEManager.shared.onDownloadComplete?.invoke(version)
                }
                // Handle OTA version query response (Top-level fallback)
                type == "version" && json.has("version") -> {
                    val version = json.optString("version")
                    println("[AndroidBLEManager] Received OTA version info: $version")
                    BLEManager.shared.onVersionInfoReceived?.invoke(version)
                }
                // Add other message types as needed
            }
        } catch (e: Exception) {
            println("Failed to parse BLE message: $message, error: ${e.message}")
        }
    }

    private fun matchesName(deviceName: String, targetName: String): Boolean {
        // Normalize strings (similar to iOS implementation)
        fun normalize(s: String): String {
            return s.trim().replace(Regex("[\\u2019\\u2018\\u201C\\u201D]"), "'")
        }

        val normalizedDevice = normalize(deviceName)
        val normalizedTarget = normalize(targetName)

        return normalizedDevice.contains(normalizedTarget, ignoreCase = true)
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.get(key)
            if (value is JSONObject) {
                map[key] = jsonToMap(value)
            } else if (value is JSONArray) {
                map[key] = jsonArrayToList(value)
            } else {
                map[key] = value
            }
        }
        return map
    }

    private fun jsonArrayToList(array: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until array.length()) {
            val value = array.get(i)
            if (value is JSONObject) {
                list.add(jsonToMap(value))
            } else if (value is JSONArray) {
                list.add(jsonArrayToList(value))
            } else {
                list.add(value)
            }
        }
        return list
    }

    fun startScan() {
        if (!hasPermissions()) {
            BLEManager.shared.error = BLEError.Unauthorized
            return
        }

        if (bluetoothAdapter?.isEnabled != true) {
            BLEManager.shared.error = BLEError.BluetoothOff
            return
        }

        if (BLEManager.shared.isScanning) return // Avoid restarting if already scanning

        BLEManager.shared.discoveredPeripherals = emptyList()
        BLEManager.shared.error = null
        BLEManager.shared.isScanning = true

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        // No service UUID filter: let onScanResult do app-level filtering so devices
        // that don't include the service UUID in their advertisement packets are not
        // silently dropped by the OS hardware filter.
        // Stop any existing scan first
        bluetoothLeScanner?.stopScan(scanCallback)
        bluetoothLeScanner?.startScan(null, scanSettings, scanCallback)

        // Stop scan after 60 seconds
        handler.postDelayed({
            stopScan()
        }, 60000)
    }

    fun stopScan() {
        // Only stop scan if Bluetooth is enabled
        if (bluetoothAdapter?.isEnabled == true) {
            bluetoothLeScanner?.stopScan(scanCallback)
        }
        BLEManager.shared.isScanning = false
        clearDiscoveryTimeout()
    }

    fun connectToSelectedPeripheral(discoveredPeripheral: DiscoveredPeripheral) {
        if (!hasPermissions()) {
            BLEManager.shared.error = BLEError.Unauthorized
            return
        }

        stopScan()
        BLEManager.shared.error = null
        pendingPeripheral = discoveredPeripheral
        BLEManager.shared.connectedPeripheral = discoveredPeripheral
        BLEManager.shared.autoConnectTargetName = discoveredPeripheral.name

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            bluetoothGatt = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                discoveredPeripheral.device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                discoveredPeripheral.device.connectGatt(context, false, gattCallback)
            }
        }
    }

    fun disconnect() {
        // Synchronize to prevent race condition with GATT callback
        // The callback may fire while we're cleaning up state
        synchronized(this) {
            val gatt = bluetoothGatt
            bluetoothGatt = null
            writeCharacteristic = null
            notifyCharacteristic = null
            this.isConnected = false
            this.isReady = false
            this.connectedPeripheral = null
            pendingPeripheral = null

            // Clear message buffer to prevent corruption from affecting future connections
            // Thread-safe synchronization ensures no concurrent access during cleanup
            synchronized(messageBufferLock) {
                messageBuffer.clear()
            }

            // Drain the message queue so a future reconnect starts clean.
            synchronized(messageSendLock) {
                messageQueue.clear()
                isSendingMessage = false
            }

            // Reset shared state immediately
            BLEManager.shared.isConnected = false
            BLEManager.shared.isReady = false
            BLEManager.shared.connectedPeripheral = null

            // Now disconnect and close the GATT, using the reference we saved
            try {
                gatt?.disconnect()
                gatt?.close()
            } catch (e: Exception) {
                println("[AndroidBLEManager] Error closing GATT: ${e.message}")
            }
        }
    }

    fun write(data: ByteArray, completion: (Boolean) -> Unit) {
        // Check multiple conditions to ensure device is truly connected
        if (!this.isConnected || writeCharacteristic == null || bluetoothGatt == null) {
            println("[AndroidBLEManager] Write failed - isConnected: ${this.isConnected}, writeCharacteristic: ${writeCharacteristic != null}, gatt: ${bluetoothGatt != null}")
            // If we detected an inconsistent state, reset the connection
            if (this.isConnected && (writeCharacteristic == null || bluetoothGatt == null)) {
                println("[AndroidBLEManager] Detected stale connection state - resetting")
                this.isConnected = false
                BLEManager.shared.isConnected = false
                BLEManager.shared.isReady = false
            }
            completion(false)
            return
        }

        writeCompletion = completion

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            writeCharacteristic?.value = data
            val initiated = bluetoothGatt?.writeCharacteristic(writeCharacteristic) ?: false
            if (!initiated) {
                // writeCharacteristic() returned false — callback will never fire; drain the queue now.
                println("[AndroidBLEManager] writeCharacteristic() returned false, calling completion immediately")
                writeCompletion = null
                completion(false)
            }
            // else: wait for onCharacteristicWrite callback
        } else {
            println("[AndroidBLEManager] Missing BLUETOOTH_CONNECT permission")
            writeCompletion = null
            completion(false)
        }
    }

    fun writeJSON(jsonString: String) {
        // Serialise at the message level: enqueue if a send is already in-progress so that
        // all byte-chunks of the current message finish before the next one starts.
        synchronized(messageSendLock) {
            if (isSendingMessage) {
                messageQueue.addLast(jsonString)
                return
            }
            isSendingMessage = true
        }
        dispatchMessage(jsonString)
    }

    private fun dispatchMessage(jsonString: String) {
        val commandStr = "$jsonString\r\n"
        val data = commandStr.toByteArray(Charsets.UTF_8)

        if (data.size <= 100) {
            write(data) { success ->
                if (!success) println("[AndroidBLEManager] Failed to write JSON: $jsonString")
                else println("[AndroidBLEManager] Successfully wrote JSON: $jsonString")
                onMessageSent()
            }
        } else {
            writeChunks(data, 0) { onMessageSent() }
        }
    }

    private fun onMessageSent() {
        val next: String?
        synchronized(messageSendLock) {
            next = if (messageQueue.isEmpty()) null else messageQueue.removeFirst()
            if (next == null) {
                isSendingMessage = false
                return
            }
        }
        next?.let { handler.post { dispatchMessage(it) } }
    }

    /**
     * Sends a JSON message to the connected device.
     */
    fun sendMessage(message: String) {
        writeJSON(message)
    }

    private fun writeChunks(data: ByteArray, startIndex: Int, onComplete: () -> Unit = {}) {
        if (startIndex >= data.size) {
            onComplete()
            return
        }

        val endIndex = minOf(startIndex + 100, data.size)
        val chunk = data.copyOfRange(startIndex, endIndex)
        write(chunk) { success ->
            if (!success) {
                println("[AndroidBLEManager] Failed to write chunk starting at $startIndex")
                onComplete() // unblock the queue even on chunk failure
            } else {
                // Delay before sending next chunk (mirrors iOS 0.1 s pacing)
                handler.postDelayed({
                    writeChunks(data, endIndex, onComplete)
                }, 100)
            }
        }
    }

    fun findPeripheral(named: String, caseInsensitive: Boolean = true, contains: Boolean = false): DiscoveredPeripheral? {
        return BLEManager.shared.discoveredPeripherals.find { peripheral ->
            matchesName(peripheral.name, named)
        }
    }

    private fun hasPermissions(): Boolean {
        // BLE permissions are required on all Android versions
        // Location permissions are still required in practice for BLE scanning on most devices
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            return ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else {
            // On older versions, use legacy Bluetooth permissions + location
            return ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                   ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun shouldRetryConnection(status: Int): Boolean {
        // Common transient Android BLE failures observed in the field.
        return status == 8 || status == 19 || status == 22 || status == 62 || status == 129 || status == 133
    }

    // OTA Methods
    fun prepareGameDiskOTA() {
        val command = mapOf(
            "action" to "prepare_game_disk_ota"
        )
        writeJSON(Gson().toJson(command))
    }

    fun startGameUpgrade(address: String, checksum: String, otaVersion: String) {
        val content = mapOf(
            "action" to "start_game_upgrade",
            "address" to address,
            "checksum" to checksum,
            "version" to otaVersion
        )
        val command = mapOf(
            "action" to "forward",
            "content" to content
        )
        writeJSON(Gson().toJson(command))
    }

    fun reloadUI() {
        val command = mapOf(
            "action" to "reload_ui"
        )
        writeJSON(Gson().toJson(command))
    }

    fun queryVersion() {
        val content = mapOf(
            "command" to "query_version"
        )
        val command = mapOf(
            "action" to "forward",
            "content" to content
        )
        writeJSON(Gson().toJson(command))
    }

    // Netlink forward listener management for multiple components
    fun addNetlinkForwardListener(listener: (Map<String, Any>) -> Unit) {
        synchronized(netlinkForwardListenersLock) {
            if (!netlinkForwardListeners.contains(listener)) {
                netlinkForwardListeners.add(listener)
            }
        }
    }

    fun removeNetlinkForwardListener(listener: (Map<String, Any>) -> Unit) {
        synchronized(netlinkForwardListenersLock) {
            netlinkForwardListeners.remove(listener)
        }
    }

    fun finishGameDiskOTA() {
        val command = mapOf(
            "action" to "finish_game_disk_ota"
        )
        writeJSON(Gson().toJson(command))
    }

    fun recoveryGameDiskOTA() {
        val command = mapOf(
            "action" to "recovery_game_disk_ota"
        )
        writeJSON(Gson().toJson(command))
    }
}