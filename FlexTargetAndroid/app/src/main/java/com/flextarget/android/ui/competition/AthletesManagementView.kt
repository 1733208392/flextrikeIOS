package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

// Placeholder data class for Athlete
data class AthleteItem(
    val id: String,
    val name: String,
    val club: String,
    val avatarUrl: String? = null
)

@Composable
fun AthletesManagementView(onBack: () -> Unit) {
    val athletes = remember { mutableStateOf(emptyList<AthleteItem>()) }
    val newAthleteNameInput = remember { mutableStateOf("") }
    val newAthleteClubInput = remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        TopAppBar(
            title = { Text("Shooters") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White,
                navigationIconContentColor = Color.Red
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // New Athlete Section
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.Gray.copy(alpha = 0.2f)
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "New Athlete",
                            color = Color.White,
                            style = MaterialTheme.typography.titleSmall
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Avatar Placeholder
                            Box(
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(Color.Gray.copy(alpha = 0.3f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "📷",
                                    fontSize = MaterialTheme.typography.headlineMedium.fontSize
                                )
                            }

                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                OutlinedTextField(
                                    value = newAthleteNameInput.value,
                                    onValueChange = { newAthleteNameInput.value = it },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(40.dp),
                                    placeholder = { Text("Athlete name", fontSize = MaterialTheme.typography.labelSmall.fontSize) },
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedTextColor = Color.White,
                                        unfocusedTextColor = Color.White,
                                        focusedBorderColor = Color.Red,
                                        unfocusedBorderColor = Color.Gray
                                    ),
                                    textStyle = MaterialTheme.typography.labelSmall,
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = newAthleteClubInput.value,
                                    onValueChange = { newAthleteClubInput.value = it },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(40.dp),
                                    placeholder = { Text("Club", fontSize = MaterialTheme.typography.labelSmall.fontSize) },
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedTextColor = Color.White,
                                        unfocusedTextColor = Color.White,
                                        focusedBorderColor = Color.Red,
                                        unfocusedBorderColor = Color.Gray
                                    ),
                                    textStyle = MaterialTheme.typography.labelSmall,
                                    singleLine = true
                                )
                            }
                        }

                        Button(
                            onClick = { /* Add athlete logic */ },
                            modifier = Modifier
                                .align(Alignment.End)
                                .height(32.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.Red
                            ),
                            shape = RoundedCornerShape(4.dp),
                            contentPadding = PaddingValues(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "Add",
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }

            // Athletes List
            if (athletes.value.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No athletes yet",
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            } else {
                items(athletes.value) { athlete ->
                    AthleteListItem(athlete)
                }
            }
        }
    }
}

@Composable
private fun AthleteListItem(athlete: AthleteItem) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.Gray.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = athlete.name.firstOrNull()?.toString() ?: "A",
                    color = Color.White,
                    style = MaterialTheme.typography.titleSmall
                )
            }

            // Athlete Info
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = athlete.name,
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = athlete.club,
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            // Delete Button
            IconButton(
                onClick = { /* Delete athlete logic */ },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.Red,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}
