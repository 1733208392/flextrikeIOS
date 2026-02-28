package com.flextarget.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.core.content.ContextCompat
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.ui.TabNavigationView
import coil.Coil
import coil.ImageLoader
import coil.decode.SvgDecoder
import android.bluetooth.BluetoothAdapter
import android.os.Build
import androidx.compose.runtime.*
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.Button

class MainActivity : ComponentActivity() {

    private val requiredPermissions: Array<String>
        get() = buildPermissionsArray()

    private val runtimePermissions: Array<String>
        get() = buildRuntimePermissionsArray()

    private val blePermissions: Array<String>
        get() = buildBlePermissionsArray()

    private fun buildPermissionsArray(): Array<String> {
        val permissions = mutableListOf<String>()

        // Location permissions are still required for BLE on most Android devices
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)

        // Handle Bluetooth permissions based on API level
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12+ (API 31+): Use new granular Bluetooth permissions
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 11 and below: Use legacy Bluetooth permissions
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
        }

        return permissions.toTypedArray()
    }

    private fun buildRuntimePermissionsArray(): Array<String> {
        val permissions = mutableListOf<String>()

        // Location permissions are still required for BLE on most Android devices
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)

        // Handle Bluetooth permissions based on API level
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12+ (API 31+): Use new granular Bluetooth permissions
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 11 and below: Use legacy Bluetooth permissions
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
        }

        return permissions.toTypedArray()
    }

    private fun buildBlePermissionsArray(): Array<String> {
        val permissions = mutableListOf<String>()

        // Handle Bluetooth permissions based on API level
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12+ (API 31+): BLE scanning doesn't require location permissions
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 11 and below: BLE scanning required location permissions
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        return permissions.toTypedArray()
    }

    private var showDisclosure by mutableStateOf(false)

    private val requestBackgroundLocationLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (!isGranted) {
            // Handle denial - inform user that background BLE may not work
            println("Background location permission denied")
        }
    }

    private val requestPermissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (!allGranted) {
            // Handle permission denial - could show a dialog explaining why permissions are needed
            println("Some permissions were denied")
        } else {
            // Check if foreground location is granted, then show disclosure for background
            if (hasForegroundLocationPermissions()) {
                showDisclosure = true
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("MainActivity", "MainActivity onCreate called")

        // Request permissions if not granted
        requestPermissionsIfNeeded()

        // If foreground location is already granted, show disclosure for background
        if (hasForegroundLocationPermissions() && !hasBackgroundLocationPermission()) {
            showDisclosure = true
        }

        // Initialize BLE Manager
        BLEManager.shared.initialize(this)

        // Set up Coil with SVG decoder
        val imageLoader = ImageLoader.Builder(this)
            .components {
                add(SvgDecoder.Factory())
            }
            .build()
        Coil.setImageLoader(imageLoader)

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val showAutoConnect = remember { mutableStateOf(false) }
                    
                    LaunchedEffect(Unit) {
                        if (!BLEManager.shared.isConnected) {
                            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                            if (bluetoothAdapter?.isEnabled == true && hasRequiredPermissions()) {
                                BLEManager.shared.autoDetectMode = true
                                BLEManager.shared.startScan()
                                showAutoConnect.value = true
                            }
                        }
                    }
                    if (showAutoConnect.value) {
                        com.flextarget.android.ui.ble.ConnectSmartTargetView(
                            onDismiss = { showAutoConnect.value = false },
                            onConnected = { showAutoConnect.value = false }
                        )
                    } else if (showDisclosure) {
                        BackgroundLocationDisclosureDialog(
                            onAllow = {
                                showDisclosure = false
                                requestBackgroundLocationLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                            },
                            onDeny = {
                                showDisclosure = false
                                // Optionally show a message
                            }
                        )
                    } else {
                        TabNavigationView()
                    }
                }
            }
        }
    }

    private fun requestPermissionsIfNeeded() {
        val permissionsToRequest = runtimePermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (permissionsToRequest.isNotEmpty()) {
            requestPermissionsLauncher.launch(permissionsToRequest)
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return requiredPermissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasForegroundLocationPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
               ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasBackgroundLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
}

@Composable
fun BackgroundLocationDisclosureDialog(onAllow: () -> Unit, onDeny: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDeny,
        title = { Text("Background Location Permission") },
        text = { Text("This app requires background location access to maintain Bluetooth connections for device functionality. Location data is not collected or stored.") },
        confirmButton = {
            Button(onClick = onAllow) {
                Text("Allow")
            }
        },
        dismissButton = {
            Button(onClick = onDeny) {
                Text("Deny")
            }
        }
    )
}
