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

class MainActivity : ComponentActivity() {

    private val requiredPermissions: Array<String>
        get() = buildPermissionsArray()

    private val runtimePermissions: Array<String>
        get() = buildRuntimePermissionsArray()

    private val showBackgroundLocationDialog = mutableStateOf(false)

    private fun buildPermissionsArray(): Array<String> {
        val permissions = mutableListOf<String>()

        // Always needed permissions
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        permissions.add(Manifest.permission.CAMERA)

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

        // ACCESS_BACKGROUND_LOCATION is available from API 29 (Android 10)
        // Note: This cannot be requested at runtime on API 29+, must be granted in settings
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        return permissions.toTypedArray()
    }

    private fun buildRuntimePermissionsArray(): Array<String> {
        val permissions = mutableListOf<String>()

        // Always needed permissions
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        permissions.add(Manifest.permission.CAMERA)

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

        // ACCESS_BACKGROUND_LOCATION can only be requested at runtime on API 28 and below
        // On API 29+, it must be granted in settings
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        return permissions.toTypedArray()
    }
    private val requestPermissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (allGranted) {
            // Check if we need to handle background location separately
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                // On API 29+, background location needs to be granted in settings
                // Show a dialog directing user to settings
                showBackgroundLocationDialog.value = true
            }
        } else {
            // Handle permission denial - could show a dialog explaining why permissions are needed
            println("Some permissions were denied")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("MainActivity", "MainActivity onCreate called")

        // Request permissions if not granted
        requestPermissionsIfNeeded()

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
                    
                    if (showBackgroundLocationDialog.value) {
                        BackgroundLocationDialog(
                            onConfirm = {
                                showBackgroundLocationDialog.value = false
                                openAppSettings()
                            }
                        )
                    } else {
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
                        } else {
                            TabNavigationView()
                        }
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

    private fun openAppSettings() {
        val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = android.net.Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}

@Composable
fun BackgroundLocationDialog(onConfirm: () -> Unit) {
    androidx.compose.material3.AlertDialog(
        onDismissRequest = { },
        title = { androidx.compose.material3.Text("Background Location Required") },
        text = { androidx.compose.material3.Text("This app requires background location permission to function properly when not in use. Please grant 'Allow all the time' location permission in the app settings.") },
        confirmButton = {
            androidx.compose.material3.TextButton(onClick = onConfirm) {
                androidx.compose.material3.Text("Open Settings")
            }
        }
    )
}
