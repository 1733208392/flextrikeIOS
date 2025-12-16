package com.flextarget.android.data.ble

import android.bluetooth.BluetoothDevice
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
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

    // Shot notification callback
    var onShotReceived: ((Map<String, Any>) -> Unit)? = null

    val connectedPeripheralName: String?
        get() = connectedPeripheral?.name

    fun initialize(context: Context) {
        androidBLEManager = AndroidBLEManager(context)
    }

    fun startScan() {
        androidBLEManager?.startScan() ?: run {
            // Fallback for when not initialized
            isScanning = true
            error = null
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