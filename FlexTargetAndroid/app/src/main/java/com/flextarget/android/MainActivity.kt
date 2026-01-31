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
import androidx.compose.runtime.*

class MainActivity : ComponentActivity() {

    private val requiredPermissions = arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT,
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.CAMERA
    )

    private val requestPermissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (!allGranted) {
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
                    LaunchedEffect(Unit) {
                        if (!BLEManager.shared.isConnected) {
                            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                            if (bluetoothAdapter?.isEnabled == true) {
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

    private fun requestPermissionsIfNeeded() {
        val permissionsToRequest = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (permissionsToRequest.isNotEmpty()) {
            requestPermissionsLauncher.launch(permissionsToRequest)
        }
    }
}
