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
import org.json.JSONArray

/**
 * Android BLE Manager implementation
 * Handles Bluetooth Low Energy operations for smart target communication
 */
class AndroidBLEManager(private val context: Context) {

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
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

    // Callback for netlink forward messages (acks, etc.)
    var onNetlinkForwardReceived: ((Map<String, Any>) -> Unit)? = null

    // Callback for auth data response
    var onAuthDataReceived: ((String) -> Unit)? = null

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

    private var writeCompletion: ((Boolean) -> Unit)? = null
    private val messageBuffer = mutableListOf<Byte>()
    private var pendingPeripheral: DiscoveredPeripheral? = null

    // Scan callback
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name ?: "Unknown"

            val scanRecord = result.scanRecord
            val serviceUuids = scanRecord?.serviceUuids
            val hasTargetService = serviceUuids?.any { it.uuid == advServiceUUID } == true
            val shouldProcess = hasTargetService || BLEManager.shared.autoConnectTargetName != null

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

            BLEManager.shared.autoConnectTargetName?.let { targetName ->
                if (matchesName(deviceName, targetName)) {
                    BLEManager.shared.autoConnectTargetName = null
                    connectToSelectedPeripheral(discovered)
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            BLEManager.shared.error = BLEError.Unknown("Scan failed with code: $errorCode")
            BLEManager.shared.isScanning = false
        }
    }

    // GATT callback
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            println("[AndroidBLEManager] onConnectionStateChange - status: $status, newState: $newState")
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    println("[AndroidBLEManager] Connected to device")
                    BLEManager.shared.error = null
                    bluetoothGatt = gatt
                    // Discover services
                    if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                        gatt.discoverServices()
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    println("[AndroidBLEManager] Disconnected from device")
                    BLEManager.shared.isConnected = false
                    BLEManager.shared.isReady = false
                    BLEManager.shared.connectedPeripheral = null
                    bluetoothGatt = null
                    writeCharacteristic = null
                    notifyCharacteristic = null
                    pendingPeripheral = null

                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        this@AndroidBLEManager.error = "Disconnected with status: $status"
                    }
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
                        println("[AndroidBLEManager] Ready: $ready (write: ${writeCharacteristic != null}, notify: ${notifyCharacteristic != null})")
                        if (ready) {
                            this@AndroidBLEManager.isConnected = true
                            BLEManager.shared.isConnected = true
                            pendingPeripheral?.let {
                                BLEManager.shared.connectedPeripheral = it
                            }
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

            // Process received data (similar to iOS implementation)
            messageBuffer.addAll(data.toList())

            // First, try to process if the buffer contains a complete JSON message
            val currentString = String(messageBuffer.toByteArray(), Charsets.UTF_8)
            try {
                JSONObject(currentString)
                // If parsing succeeds, it's a complete JSON message
                processMessage(currentString)
                messageBuffer.clear()
                return
            } catch (e: Exception) {
                // Not a complete JSON, check for separators
            }

            // Look for message separators (\r\r or \r\n)
            val separator1 = listOf(0x0D.toByte(), 0x0D.toByte()) // \r\r
            val separator2 = listOf(0x0D.toByte(), 0x0A.toByte()) // \r\n

            val index1 = findLastSeparator(messageBuffer, separator1)
            val index2 = findLastSeparator(messageBuffer, separator2)

            val separatorIndex = maxOf(index1, index2)
            if (separatorIndex >= 0) {
                val completeBytes = messageBuffer.take(separatorIndex).toByteArray()
                val remaining = messageBuffer.drop(separatorIndex + 2)
                messageBuffer.clear()
                messageBuffer.addAll(remaining)

                val message = String(completeBytes, Charsets.UTF_8)
                processMessage(message)
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            writeCompletion?.invoke(status == BluetoothGatt.GATT_SUCCESS)
            writeCompletion = null
        }
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
                        }
                        println("Received netlink device_list: $devices")
                        BLEManager.shared.networkDevices = devices
                        BLEManager.shared.lastDeviceListUpdate = Date()
                        // TODO: Post notification or callback for device list updated
                    }
                }
                type == "netlink" && action == "forward" -> {
                    // Handle all netlink forward messages
                    val messageMap = jsonToMap(json)
                    this.onNetlinkForwardReceived?.invoke(messageMap)

                    // Specifically handle shot data from targets
                    val content = json.optJSONObject("content")
                    if (content != null && (content.optString("command") == "shot" || content.optString("cmd") == "shot")) {
                        println("Received shot data: $json")
                        val shotData = Gson().fromJson(json.toString(), ShotData::class.java)
                        this.onShotReceived?.invoke(shotData)
                    }
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
                // Handle forward messages for OTA
                type == "forward" && json.has("content") -> {
                    val content = json.getJSONObject("content")
                    
                    // Check for OTA "ready_to_download" notification
                    if (content.optString("notification") == "ready_to_download") {
                        println("[AndroidBLEManager] Received OTA ready_to_download notification")
                        BLEManager.shared.onReadyToDownload?.invoke()
                    }
                    // Check for OTA "download_complete" notification
                    else if (content.optString("notification") == "download_complete") {
                        val version = content.optString("version")
                        println("[AndroidBLEManager] Received OTA download complete (forwarded): $version")
                        // Note: iOS calls reloadUI() here, but we'll handle it in the repository
                        BLEManager.shared.onDownloadComplete?.invoke(version)
                    }
                    // Check for OTA version info - treat as device version update
                    else if (content.has("version")) {
                        val version = content.optString("version")
                        println("[AndroidBLEManager] Received device version info (forwarded): $version")
                        BLEManager.shared.onDeviceVersionUpdated?.invoke(version)
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

        BLEManager.shared.discoveredPeripherals = emptyList()
        BLEManager.shared.error = null
        BLEManager.shared.isScanning = true

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        bluetoothLeScanner?.startScan(null, scanSettings, scanCallback)

        // Stop scan after 60 seconds
        handler.postDelayed({
            stopScan()
        }, 60000)
    }

    fun stopScan() {
        bluetoothLeScanner?.stopScan(scanCallback)
        BLEManager.shared.isScanning = false
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

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            bluetoothGatt = discoveredPeripheral.device.connectGatt(context, false, gattCallback)
        }
    }

    fun disconnect() {
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        writeCharacteristic = null
        notifyCharacteristic = null
        this.isConnected = false
        this.isReady = false
        this.connectedPeripheral = null
        pendingPeripheral = null
        BLEManager.shared.isConnected = false
        BLEManager.shared.isReady = false
        BLEManager.shared.connectedPeripheral = null
    }

    fun write(data: ByteArray, completion: (Boolean) -> Unit) {
        if (!this.isConnected || writeCharacteristic == null) {
            println("[AndroidBLEManager] Write failed - isConnected: ${this.isConnected}, writeCharacteristic: ${writeCharacteristic != null}, gatt: ${bluetoothGatt != null}")
            completion(false)
            return
        }

        writeCompletion = completion

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            writeCharacteristic?.value = data
            bluetoothGatt?.writeCharacteristic(writeCharacteristic)
        } else {
            println("[AndroidBLEManager] Missing BLUETOOTH_CONNECT permission")
            completion(false)
        }
    }

    fun writeJSON(jsonString: String) {
        val commandStr = "$jsonString\r\n"
        val data = commandStr.toByteArray(Charsets.UTF_8)

        if (data.size <= 100) {
            write(data) { success ->
                if (!success) {
                    println("Failed to write JSON: $jsonString")
                } else {
                    println("Successfully wrote JSON: $jsonString")
                }
            }
        } else {
            // Split into chunks and send sequentially
            writeChunks(data, 0)
        }
    }

    private fun writeChunks(data: ByteArray, startIndex: Int) {
        if (startIndex >= data.size) return

        val endIndex = minOf(startIndex + 100, data.size)
        val chunk = data.copyOfRange(startIndex, endIndex)
        write(chunk) { success ->
            if (!success) {
                println("Failed to write chunk starting at $startIndex")
            } else {
                // Add delay before sending next chunk (similar to iOS 0.1s)
                handler.postDelayed({
                    writeChunks(data, endIndex)
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
        return ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
               ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
               ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
               ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
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