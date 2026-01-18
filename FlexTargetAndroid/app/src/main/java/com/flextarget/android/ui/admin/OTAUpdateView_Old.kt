package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun OTAUpdateView(onBack: () -> Unit) {
    val updateAvailable = remember { mutableStateOf(false) }
    val isChecking = remember { mutableStateOf(false) }
    val isUpdating = remember { mutableStateOf(false) }
    val updateProgress = remember { mutableStateOf(0f) }
    val currentVersion = remember { mutableStateOf("1.0.0") }
    val availableVersion = remember { mutableStateOf("1.1.0") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        TopAppBar(
            title = { Text("System Updates", color = Color.White) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.Red)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Current Version Info
            item {
                StatusCard(
                    title = "Current Version",
                    version = currentVersion.value,
                    status = "Up to date"
                )
            }

            // Check for Updates Button
            item {
                Button(
                    onClick = { isChecking.value = true },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                    shape = RoundedCornerShape(8.dp),
                    enabled = !isChecking.value && !isUpdating.value
                ) {
                    if (isChecking.value) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(
                        if (isChecking.value) "Checking..." else "Check for Updates",
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Available Update Info
            if (updateAvailable.value) {
                item {
                    UpdateAvailableCard(
                        currentVersion = currentVersion.value,
                        availableVersion = availableVersion.value,
                        isUpdating = isUpdating.value,
                        progress = updateProgress.value,
                        onUpdate = {
                            isUpdating.value = true
                            updateProgress.value = 0f
                            // Simulate update progress
                            for (i in 0..100 step 10) {
                                updateProgress.value = i / 100f
                            }
                        }
                    )
                }
            } else {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                color = Color.White.copy(alpha = 0.05f),
                                shape = RoundedCornerShape(8.dp)
                            )
                            .padding(16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = Color.Green,
                                modifier = Modifier.size(48.dp)
                            )
                            Text(
                                "Your system is up to date",
                                color = Color.White,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold,
                                textAlign = TextAlign.Center
                            )
                            Text(
                                "You have the latest version installed",
                                color = Color.Gray,
                                style = MaterialTheme.typography.bodySmall,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                }
            }

            // Info Card
            item {
                InfoCard(
                    title = "About OTA Updates",
                    description = "Over-the-Air (OTA) updates allow you to install the latest features and security improvements for your device. Updates are checked automatically and can also be manually checked using the button above."
                )
            }
        }
    }
}

@Composable
private fun StatusCard(
    title: String,
    version: String,
    status: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                title,
                color = Color.Gray,
                style = MaterialTheme.typography.labelSmall
            )
            Text(
                version,
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                status,
                color = Color.Green,
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
private fun UpdateAvailableCard(
    currentVersion: String,
    availableVersion: String,
    isUpdating: Boolean,
    progress: Float,
    onUpdate: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Red.copy(alpha = 0.1f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Download,
                    contentDescription = null,
                    tint = Color.Red,
                    modifier = Modifier.size(32.dp)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Update Available",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Version $availableVersion",
                        color = Color.Gray,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            Text(
                "A new system update is available. Update now to get the latest features and security improvements.",
                color = Color.White,
                style = MaterialTheme.typography.bodySmall
            )

            if (isUpdating) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    LinearProgressIndicator(
                        progress = progress,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp),
                        color = Color.Red,
                        trackColor = Color.Gray.copy(alpha = 0.3f)
                    )
                    Text(
                        "Updating... ${(progress * 100).toInt()}%",
                        color = Color.Gray,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            } else {
                Button(
                    onClick = onUpdate,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Update Now", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun InfoCard(
    title: String,
    description: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color.Gray,
                    modifier = Modifier.size(20.dp)
                )
                Column {
                    Text(
                        title,
                        color = Color.White,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        description,
                        color = Color.Gray,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}
