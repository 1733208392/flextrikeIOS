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
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.local.entity.AthleteEntity
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R

@Composable
fun AthletesManagementView(
    onBack: () -> Unit,
    viewModel: CompetitionViewModel
) {
    val uiState by viewModel.competitionUiState.collectAsState()
    val newAthleteNameInput = remember { mutableStateOf("") }
    val newAthleteClubInput = remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        TopAppBar(
            title = { Text(stringResource(R.string.shooters)) },
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
                .weight(1f)
                .fillMaxWidth()
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
                        containerColor = Color.White.copy(alpha = 0.1f)
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.new_athlete),
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
                                Icon(Icons.Default.Add, contentDescription = null, tint = Color.White)
                            }

                            Column(modifier = Modifier.weight(1f)) {
                                TextField(
                                    value = newAthleteNameInput.value,
                                    onValueChange = { newAthleteNameInput.value = it },
                                    placeholder = { Text(stringResource(R.string.name), color = Color.Gray) },
                                    colors = TextFieldDefaults.colors(
                                        unfocusedContainerColor = Color.Transparent,
                                        focusedContainerColor = Color.Transparent,
                                        unfocusedTextColor = Color.White,
                                        focusedTextColor = Color.White
                                    ),
                                    modifier = Modifier.fillMaxWidth()
                                )
                                TextField(
                                    value = newAthleteClubInput.value,
                                    onValueChange = { newAthleteClubInput.value = it },
                                    placeholder = { Text(stringResource(R.string.club_optional), color = Color.Gray) },
                                    colors = TextFieldDefaults.colors(
                                        unfocusedContainerColor = Color.Transparent,
                                        focusedContainerColor = Color.Transparent,
                                        unfocusedTextColor = Color.White,
                                        focusedTextColor = Color.White
                                    ),
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }

                        Button(
                            onClick = {
                                if (newAthleteNameInput.value.isNotEmpty()) {
                                    viewModel.addAthlete(
                                        newAthleteNameInput.value,
                                        newAthleteClubInput.value
                                    )
                                    newAthleteNameInput.value = ""
                                    newAthleteClubInput.value = ""
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                            enabled = newAthleteNameInput.value.isNotEmpty()
                        ) {
                            Text(stringResource(R.string.add_athlete))
                        }
                    }
                }
            }

            // Athletes List
            items(uiState.athletes) { athlete ->
                AthleteRow(
                    athlete = athlete,
                    onDelete = { viewModel.deleteAthlete(athlete) }
                )
            }
        }
    }
}

@Composable
fun AthleteRow(
    athlete: AthleteEntity,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        )
    ) {
        Row(
            modifier = Modifier
                .padding(12.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.Red.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = athlete.name?.take(1)?.uppercase() ?: "?",
                    color = Color.Red,
                    style = MaterialTheme.typography.titleMedium
                )
            }

            Column(
                modifier = Modifier
                    .padding(horizontal = 12.dp)
                    .weight(1f)
            ) {
                Text(
                    text = athlete.name ?: stringResource(R.string.unknown),
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge
                )
                if (!athlete.club.isNullOrEmpty()) {
                    Text(
                        text = athlete.club ?: "",
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }

            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.Gray)
            }
        }
    }
}
