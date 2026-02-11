package com.flextarget.android.data.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.util.Date
import java.util.UUID

/**
 * BLE Manager for Android - ported from iOS BLEManager
 * Handles Bluetooth Low Energy communication with smart targets
 */
class BLEManager private constructor() {
    companion object {
        val shared = BLEManager()
    }

    private var androidBLEManager: AndroidBLEManager? = null

    val androidManager: AndroidBLEManager?
        get() = androidBLEManager

    // Observable state
    var discoveredPeripherals by mutableStateOf<List<DiscoveredPeripheral>>(emptyList())
    var isConnected by mutableStateOf(false)
    var isReady by mutableStateOf(false)
    var isScanning by mutableStateOf(false)
    var error by mutableStateOf<BLEError?>(null)
    var connectedPeripheral by mutableStateOf<DiscoveredPeripheral?>(null)
    var autoConnectTargetName by mutableStateOf<String?>(null)

    // Global device list data for sharing across views
    var networkDevices by mutableStateOf<List<NetworkDevice>>(emptyList())
    var lastDeviceListUpdate by mutableStateOf<Date?>(null)

    // Error message for displaying alerts
    var errorMessage by mutableStateOf<String?>(null)
    var showErrorAlert by mutableStateOf(false)
    
    // Multi-device selection UI state
    var showMultiDevicePicker by mutableStateOf(false)

    // Provision related
    var autoDetectMode by mutableStateOf(true)
    var provisionInProgress by mutableStateOf(false)
    var provisionCompleted by mutableStateOf(false)
    var shouldShowRemoteControl by mutableStateOf(false)

    // Provision verification timer
    private var provisionVerifyHandler: Handler? = null
    private var provisionVerifyRunnable: Runnable? = null

    // Auto-detection properties
    private var autoDetectHandler: Handler? = null
    private var autoDetectRunnable: Runnable? = null
    private val autoDetectInterval: Long = 10000L
    private var isAppInForeground = true

    // Shot notification callback
    var onShotReceived: ((com.flextarget.android.data.model.ShotData) -> Unit)? = null

    // Netlink forward message callback
    var onNetlinkForwardReceived: ((Map<String, Any>) -> Unit)? = null

    // Forward message callback
    var onForwardReceived: ((Map<String, Any>) -> Unit)? = null

    // Auth data response callback
    var onAuthDataReceived: ((String) -> Unit)? = null

    // OTA Callbacks
    var onGameDiskOTAReady: (() -> Unit)? = null
    var onOTAPreparationFailed: ((String) -> Unit)? = null
    var onBLEErrorOccurred: (() -> Unit)? = null
    var onReadyToDownload: (() -> Unit)? = null
    var onDownloadComplete: ((String) -> Unit)? = null
    var onVersionInfoReceived: ((String) -> Unit)? = null
    var onDeviceVersionUpdated: ((String) -> Unit)? = null

    // Provision status callback
    var onProvisionStatusReceived: ((String) -> Unit)? = null

    val connectedPeripheralName: String?
        get() = connectedPeripheral?.name

    // Bluetooth state change receiver
    private var bluetoothStateReceiver: android.content.BroadcastReceiver? = null
    private var appContext: Context? = null

    init {
        // Initialize provision status handler at singleton level
        // This ensures the handler persists across initialize() calls
        onProvisionStatusReceived = { status ->
            println("[BLEManager] onProvisionStatusReceived called with status: $status")
            if (status == "incomplete") {
                if (isConnected && isReady) {
                    println("[BLEManager] Device connected and ready. Received provision_status: incomplete")
                    println("[BLEManager] Setting shouldShowRemoteControl = true to trigger RemoteControlView")
                    provisionInProgress = true
                    provisionCompleted = false
                    shouldShowRemoteControl = true
                    writeJSON("{\"action\":\"forward\", \"content\": {\"provision_step\": \"wifi_connection\"}}")
                    startProvisionVerification()
                } else {
                    println("[BLEManager] Device not ready yet. isConnected: $isConnected, isReady: $isReady")
                }
            }
        }
    }

    fun initialize(context: Context) {
        // Don't reinitialize if already connected
        if (androidBLEManager != null && isConnected) {
            return
        }
        androidBLEManager = AndroidBLEManager(context).apply {
            onShotReceived = { shotData ->
                this@BLEManager.onShotReceived?.invoke(shotData)
            }
            onNetlinkForwardReceived = { message ->
                val provisionStatus = message["provision_status"] as? String
                if (provisionStatus != null) {
                    onProvisionStatusReceived?.invoke(provisionStatus)
                }

                this@BLEManager.onNetlinkForwardReceived?.invoke(message)
            }
            onForwardReceived = { message ->
                // Note: Provision completion is now handled directly in AndroidBLEManager
                // before this callback is invoked, so we don't need to check for it here.
                // This callback is kept for any UI-level forward message handling.
                this@BLEManager.onForwardReceived?.invoke(message)
            }
            onAuthDataReceived = { authData ->
                this@BLEManager.onAuthDataReceived?.invoke(authData)
            }
            onGameDiskOTAReady = {
                this@BLEManager.onGameDiskOTAReady?.invoke()
            }
            onOTAPreparationFailed = { errorReason ->
                this@BLEManager.onOTAPreparationFailed?.invoke(errorReason)
            }
            onBLEErrorOccurred = {
                this@BLEManager.onBLEErrorOccurred?.invoke()
            }
            onReadyToDownload = {
                this@BLEManager.onReadyToDownload?.invoke()
            }
            onDownloadComplete = { version ->
                this@BLEManager.onDownloadComplete?.invoke(version)
            }
            onVersionInfoReceived = { version ->
                this@BLEManager.onVersionInfoReceived?.invoke(version)
            }
            onDeviceVersionUpdated = { version ->
                this@BLEManager.onDeviceVersionUpdated?.invoke(version)
            }
        }

        // Add lifecycle observer for app foreground/background
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                // App came to foreground
                isAppInForeground = true
                if (autoDetectMode && !isConnected) {
                    startAutoDetection()
                }
            }

            override fun onStop(owner: LifecycleOwner) {
                // App went to background
                isAppInForeground = false
                stopAutoDetection()
            }
        })

        // Start auto-detection if app is already in foreground
        if (autoDetectMode && !isConnected) {
            startAutoDetection()
        }
        
        // Store context and register Bluetooth state change receiver
        appContext = context
        registerBluetoothStateReceiver(context)
    }
    
    private fun registerBluetoothStateReceiver(context: Context) {
        // Unregister if already registered
        bluetoothStateReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                println("[BLEManager] Error unregistering Bluetooth receiver: ${e.message}")
            }
        }
        
        bluetoothStateReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    when (state) {
                        BluetoothAdapter.STATE_OFF -> {
                            println("[BLEManager] Bluetooth turned off externally")
                            // Auto-disconnect when Bluetooth is turned off
                            if (isConnected) {
                                errorMessage = "Bluetooth has been turned off. Device disconnected."
                                showErrorAlert = true
                                disconnect()
                            }
                            // Clear discovered peripherals
                            discoveredPeripherals = emptyList()
                            error = BLEError.BluetoothOff
                        }
                        BluetoothAdapter.STATE_TURNING_OFF -> {
                            println("[BLEManager] Bluetooth turning off")
                        }
                        BluetoothAdapter.STATE_ON -> {
                            println("[BLEManager] Bluetooth turned on")
                            error = null
                            if (autoDetectMode && !isConnected) {
                                startAutoDetection()
                            }
                        }
                        BluetoothAdapter.STATE_TURNING_ON -> {
                            println("[BLEManager] Bluetooth turning on")
                        }
                    }
                }
            }
        }
        
        try {
            val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            context.registerReceiver(bluetoothStateReceiver, filter)
            println("[BLEManager] Bluetooth state receiver registered")
        } catch (e: Exception) {
            println("[BLEManager] Error registering Bluetooth receiver: ${e.message}")
        }
    }
    
    fun unregisterBluetoothStateReceiver() {
        bluetoothStateReceiver?.let {
            appContext?.let { context ->
                try {
                    context.unregisterReceiver(it)
                    println("[BLEManager] Bluetooth state receiver unregistered")
                } catch (e: Exception) {
                    println("[BLEManager] Error unregistering Bluetooth receiver: ${e.message}")
                }
            }
        }
        bluetoothStateReceiver = null
    }

    private fun startProvisionVerification() {
        stopProvisionVerification() // Stop any existing
        if (!isConnected || !isReady) {
            println("[BLEManager] Cannot start provision verification: isConnected=$isConnected, isReady=$isReady")
            return
        }
        provisionVerifyHandler = Handler(Looper.getMainLooper())
        provisionVerifyRunnable = Runnable {
            // Check connection before sending
            if (isConnected && isReady && provisionInProgress) {
                println("[BLEManager] Sending provision verification status request")
                writeJSON("{\"action\":\"forward\", \"content\": {\"provision_step\": \"verify_targetlink_status\"}}")
                provisionVerifyHandler?.postDelayed(provisionVerifyRunnable!!, 5000) // 5 seconds
            } else {
                println("[BLEManager] Stopping provision verification: isConnected=$isConnected, isReady=$isReady, provisionInProgress=$provisionInProgress")
                stopProvisionVerification()
            }
        }
        provisionVerifyHandler?.post(provisionVerifyRunnable!!)
    }

    private fun stopProvisionVerification() {
        provisionVerifyRunnable?.let { provisionVerifyHandler?.removeCallbacks(it) }
        provisionVerifyHandler = null
        provisionVerifyRunnable = null
    }
    
    // Public accessor for stopping provision verification from AndroidBLEManager
    fun stopProvisionVerificationPublic() {
        stopProvisionVerification()
    }
    
    // MARK: - Auto-Detection
    fun startAutoDetection() {
        stopAutoDetection()
        if (!autoDetectMode || isConnected || !isAppInForeground) return
        autoDetectHandler = Handler(Looper.getMainLooper())
        autoDetectRunnable = Runnable {
            performAutoDetectionScan()
            autoDetectHandler?.postDelayed(autoDetectRunnable!!, autoDetectInterval)
        }
        autoDetectHandler?.post(autoDetectRunnable!!)
    }
    
    fun stopAutoDetection() {
        autoDetectRunnable?.let { autoDetectHandler?.removeCallbacks(it) }
        autoDetectHandler = null
        autoDetectRunnable = null
    }
    
    private fun performAutoDetectionScan() {
        if (!isScanning && isAppInForeground) {
            startScan()
        }
    }

    fun startScan() {
        androidBLEManager?.startScan() ?: run {
            // Fallback for when not initialized
            if (!isScanning) {
                isScanning = true
                error = null
            }
        }
    }

    fun stopScan() {
        androidBLEManager?.stopScan() ?: run {
            isScanning = false
        }
    }

    fun connect(peripheral: BluetoothDevice) {
        val discovered = DiscoveredPeripheral(UUID.randomUUID(), peripheral.name ?: "Unknown", peripheral)
        androidBLEManager?.connectToSelectedPeripheral(discovered) ?: run {
            error = null
        }
    }

    fun connectToSelectedPeripheral(discoveredPeripheral: DiscoveredPeripheral) {
        androidBLEManager?.connectToSelectedPeripheral(discoveredPeripheral) ?: run {
            error = null
        }
    }

    fun disconnect() {
        androidBLEManager?.disconnect() ?: run {
            isConnected = false
            isReady = false
            connectedPeripheral = null
        }
        stopProvisionVerification()
        provisionInProgress = false
        provisionCompleted = false
        shouldShowRemoteControl = false
    }

    fun write(data: ByteArray, completion: (Boolean) -> Unit) {
        androidBLEManager?.write(data, completion) ?: run {
            completion(isConnected)
        }
    }

    fun writeJSON(jsonString: String) {
        androidBLEManager?.writeJSON(jsonString) ?: run {
            if (isConnected) {
                println("Writing JSON data to BLE: $jsonString")
            }
        }
    }

    fun findPeripheral(named: String, caseInsensitive: Boolean = true, contains: Boolean = false): DiscoveredPeripheral? {
        return androidBLEManager?.findPeripheral(named, caseInsensitive, contains)
    }

    fun setAutoConnectTarget(name: String?) {
        autoConnectTargetName = name
        if (name != null) {
            // Start scanning when auto-connect target is set
            startScan()
        }
    }
    
    /// Called by UI when user dismisses device picker without selection
    fun dismissDevicePicker() {
        showMultiDevicePicker = false
    }
    
    /// Called by UI when user selects a device from picker
    fun selectDeviceFromPicker(discoveredPeripheral: DiscoveredPeripheral) {
        showMultiDevicePicker = false
        connectToSelectedPeripheral(discoveredPeripheral)
    }
}

// Data classes
data class NetworkDevice(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val mode: String
)

data class DeviceListResponse(
    val type: String,
    val action: String,
    val data: List<NetworkDevice>
)

data class DiscoveredPeripheral(
    val id: UUID,
    val name: String,
    val device: BluetoothDevice
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is DiscoveredPeripheral) return false
        return id == other.id
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }
}

sealed class BLEError(val message: String) {
    object BluetoothOff : BLEError("Bluetooth is turned off.")
    object Unauthorized : BLEError("Bluetooth access is unauthorized.")
    class ConnectionFailed(msg: String) : BLEError("Connection failed: $msg")
    class Disconnected(msg: String) : BLEError("Disconnected: $msg")
    class Unknown(msg: String) : BLEError("Unknown error: $msg")
}

// Protocol interface
interface BLEManagerProtocol {
    val isConnected: Boolean
    fun write(data: ByteArray, completion: (Boolean) -> Unit)
    fun writeJSON(jsonString: String)
}

// Make BLEManager implement the protocol
class BLEManagerImpl : BLEManagerProtocol {
    override val isConnected: Boolean
        get() = BLEManager.shared.isConnected

    override fun write(data: ByteArray, completion: (Boolean) -> Unit) {
        BLEManager.shared.write(data, completion)
    }

    override fun writeJSON(jsonString: String) {
        BLEManager.shared.writeJSON(jsonString)
    }
}