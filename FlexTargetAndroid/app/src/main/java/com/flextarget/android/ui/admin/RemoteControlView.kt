package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.BorderStroke
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.google.gson.Gson
import android.util.Log
import kotlin.math.abs

@Composable
fun RemoteControlView(
    bleManager: BLEManager = BLEManager.shared,
    onBack: () -> Unit
) {
    val lastSwipeTime = remember { mutableStateOf(0L) }
    val swipeDebounceMs = 300 // Debounce swipe gestures
    val showVolumeBar = remember { mutableStateOf(false) }
    val showPasswordDialog = remember { mutableStateOf(false) }
    val currentSsid = remember { mutableStateOf("") }
    val passwordInput = remember { mutableStateOf("") }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        LaunchedEffect(Unit) {
            bleManager.onForwardReceived = { message ->
                val content = message["content"] as? Map<String, Any>
                val ssid = content?.get("ssid") as? String
                if (ssid != null) {
                    currentSsid.value = ssid
                    passwordInput.value = ""
                    showPasswordDialog.value = true
                }
            }
        }
        // Top bar with volume (left), centered device name+icon, and close (right)
        TopAppBar(
            title = {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Smartphone,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = (bleManager.connectedPeripheralName ?: stringResource(R.string.device)),
                            color = Color.White,
                            fontSize = 16.sp
                        )
                    }
                }
            },
            navigationIcon = {
                // Volume button on left
                IconButton(onClick = { showVolumeBar.value = !showVolumeBar.value }) {
                    Icon(Icons.Default.VolumeUp, contentDescription = "Volume", tint = Color.White)
                }
            },
            actions = {
                // Close button on right
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White
            )
        )

        // Volume vertical bar will be shown as an overlay inside the pad (see pad content)

        // Main remote control area (single larger pad)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            // Pad background (slightly lighter than black) with thin edge
            val padColor = Color(0xFF1E1F20)
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.96f)
                    .heightIn(min = 480.dp)
                    .widthIn(max = 420.dp)
                    .background(padColor, shape = RoundedCornerShape(28.dp))
                    .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.06f)), RoundedCornerShape(28.dp))
                    .pointerInput(Unit) {
                        detectDragGestures { _, dragAmount ->
                            val currentTime = System.currentTimeMillis()

                            // Check debounce
                            if (currentTime - lastSwipeTime.value < swipeDebounceMs) {
                                return@detectDragGestures
                            }

                            val (deltaX, deltaY) = dragAmount
                            val threshold = 80f // Minimum swipe distance

                            when {
                                abs(deltaX) > abs(deltaY) && abs(deltaX) > threshold -> {
                                    // Horizontal swipe
                                    if (deltaX < 0) {
                                        Log.d("RemoteControl", "Swipe left")
                                        sendRemoteCommand("left")
                                        lastSwipeTime.value = currentTime
                                    } else {
                                        Log.d("RemoteControl", "Swipe right")
                                        sendRemoteCommand("right")
                                        lastSwipeTime.value = currentTime
                                    }
                                }
                                abs(deltaY) > abs(deltaX) && abs(deltaY) > threshold -> {
                                    // Vertical swipe
                                    if (deltaY < 0) {
                                        Log.d("RemoteControl", "Swipe up")
                                        sendRemoteCommand("up")
                                        lastSwipeTime.value = currentTime
                                    } else {
                                        Log.d("RemoteControl", "Swipe down")
                                        sendRemoteCommand("down")
                                        lastSwipeTime.value = currentTime
                                    }
                                }
                            }
                        }
                    }
                    .pointerInput(Unit) {
                        detectTapGestures(onTap = {
                            Log.d("RemoteControl", "Tap")
                            sendRemoteCommand("enter")
                        })
                    }
            )
        }

        // Bottom navigation buttons (Row with two buttons)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Back round button
            OutlinedButton(
                onClick = { sendRemoteCommand("back") },
                modifier = Modifier
                    .size(84.dp),
                shape = CircleShape,
                border = BorderStroke(1.dp, Color.LightGray.copy(alpha = 0.45f)),
                colors = ButtonDefaults.outlinedButtonColors(containerColor = Color(0xFF0F0F0F)),
                contentPadding = PaddingValues(0.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = stringResource(R.string.back_button),
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Spacer(modifier = Modifier.width(48.dp))

            // Home round button
            OutlinedButton(
                onClick = { sendRemoteCommand("homepage") },
                modifier = Modifier
                    .size(84.dp),
                shape = CircleShape,
                border = BorderStroke(1.dp, Color.LightGray.copy(alpha = 0.45f)),
                colors = ButtonDefaults.outlinedButtonColors(containerColor = Color(0xFF0F0F0F)),
                contentPadding = PaddingValues(0.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Home,
                    contentDescription = stringResource(R.string.home_button),
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }
        }

        // Volume buttons below
        if (showVolumeBar.value) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // - button
                OutlinedButton(
                    onClick = { sendRemoteCommand("volume_down") },
                    modifier = Modifier
                        .size(84.dp),
                    shape = CircleShape,
                    border = BorderStroke(1.dp, Color.LightGray.copy(alpha = 0.45f)),
                    colors = ButtonDefaults.outlinedButtonColors(containerColor = Color(0xFF0F0F0F)),
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = "Volume Down",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }

                Spacer(modifier = Modifier.width(48.dp))

                // + button
                OutlinedButton(
                    onClick = { sendRemoteCommand("volume_up") },
                    modifier = Modifier
                        .size(84.dp),
                    shape = CircleShape,
                    border = BorderStroke(1.dp, Color.LightGray.copy(alpha = 0.45f)),
                    colors = ButtonDefaults.outlinedButtonColors(containerColor = Color(0xFF0F0F0F)),
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Volume Up",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Instruction text
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                stringResource(R.string.remote_control_instruction),
                color = Color.Gray,
                fontSize = 12.sp
            )
        }

        if (showPasswordDialog.value) {
            AlertDialog(
                onDismissRequest = { showPasswordDialog.value = false },
                title = { Text("Enter WiFi Password") },
                text = {
                    Column {
                        Text("Enter password for WiFi: ${currentSsid.value}")
                        OutlinedTextField(
                            value = passwordInput.value,
                            onValueChange = { passwordInput.value = it },
                            label = { Text("Password") },
                            singleLine = true
                        )
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val command = mapOf(
                            "action" to "forward",
                            "content" to mapOf(
                                "ssid" to currentSsid.value,
                                "password" to passwordInput.value
                            )
                        )
                        val json = Gson().toJson(command)
                        bleManager.writeJSON(json)
                        showPasswordDialog.value = false
                    }) {
                        Text("Connect")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showPasswordDialog.value = false }) {
                        Text("Cancel")
                    }
                }
            )
        }
    }
}

/**
 * Send a remote control command via BLE
 * Maps swipe/tap inputs to target device commands
 */
private fun sendRemoteCommand(command: String) {
    val commandMap = mapOf(
        "action" to "remote_control",
        "directive" to when (command) {
            "left" -> "left"
            "right" -> "right"
            "up" -> "up"
            "down" -> "down"
            "enter" -> "enter"
            "back" -> "back"
            "homepage" -> "homepage"
            "volume_up" -> "volume_up"
            "volume_down" -> "volume_down"
            else -> "enter"
        }
    )
    
    try {
        val json = Gson().toJson(commandMap)
        BLEManager.shared.writeJSON(json)
    } catch (e: Exception) {
        e.printStackTrace()
    }
}
