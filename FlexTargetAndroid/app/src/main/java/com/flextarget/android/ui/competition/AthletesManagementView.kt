package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
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
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import coil.compose.AsyncImage
import androidx.compose.foundation.clickable
import androidx.compose.ui.platform.LocalContext
import com.flextarget.android.ui.theme.AppTextField
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.theme.md_theme_dark_primary

@Composable
fun AthletesManagementView(
    onBack: () -> Unit,
    viewModel: CompetitionViewModel
) {
    val uiState by viewModel.competitionUiState.collectAsState()
    val newAthleteNameInput = remember { mutableStateOf("") }
    val newAthleteClubInput = remember { mutableStateOf("") }
    val newAthleteAvatarData = remember { mutableStateOf<ByteArray?>(null) }
    val context = LocalContext.current

    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            // Decode URI to Bitmap
            val bitmap = if (Build.VERSION.SDK_INT < 28) {
                MediaStore.Images.Media.getBitmap(context.contentResolver, it)
            } else {
                val source = ImageDecoder.createSource(context.contentResolver, it)
                ImageDecoder.decodeBitmap(source)
            }
            // Compress to ByteArray
            val outputStream = java.io.ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
            newAthleteAvatarData.value = outputStream.toByteArray()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        CenterAlignedTopAppBar(
            title = { Text(stringResource(R.string.shooters)) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = Color.Black,
                titleContentColor = md_theme_dark_onPrimary,
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
                            text = stringResource(R.string.new_athlete).uppercase(),
                            color = md_theme_dark_onPrimary,
                            style = MaterialTheme.typography.titleSmall
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            // Avatar Placeholder
                            Box(
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(Color.Gray.copy(alpha = 0.3f))
                                    .clickable { imagePickerLauncher.launch("image/*") },
                                contentAlignment = Alignment.Center
                            ) {
                                if (newAthleteAvatarData.value != null) {
                                    AsyncImage(
                                        model = newAthleteAvatarData.value,
                                        contentDescription = "Avatar",
                                        modifier = Modifier.fillMaxSize(),
                                        contentScale = ContentScale.Crop
                                    )
                                } else {
                                    Icon(
                                        Icons.Default.Add,
                                        contentDescription = null,
                                        tint = Color.White
                                    )
                                }
                            }

                            Column(modifier = Modifier.weight(1f)) {
                                AppTextField(
                                    value = newAthleteNameInput.value,
                                    onValueChange = { newAthleteNameInput.value = it },
                                    placeholder = {
                                        Text(
                                            stringResource(R.string.name),
                                            color = Color.Gray
                                        )
                                    },
                                    isError = newAthleteNameInput.value.isNotEmpty() && newAthleteNameInput.value.length < 4,
                                    colors = TextFieldDefaults.colors(
                                        unfocusedContainerColor = Color.Transparent,
                                        focusedContainerColor = Color.Transparent,
                                        unfocusedTextColor = Color.White,
                                        focusedTextColor = Color.White,
                                        errorContainerColor = Color.Transparent,
                                        errorCursorColor = Color.Red,
                                        cursorColor = md_theme_dark_onPrimary
                                    ),
                                    modifier = Modifier.fillMaxWidth()
                                )
                                if (newAthleteNameInput.value.isNotEmpty() && newAthleteNameInput.value.length < 4) {
                                    Text(
                                        text = "Name must be at least 4 characters",
                                        color = Color.Red,
                                        style = MaterialTheme.typography.bodySmall,
                                        modifier = Modifier.padding(start = 0.dp, top = 2.dp)
                                    )
                                }
                                AppTextField(
                                    value = newAthleteClubInput.value,
                                    onValueChange = { newAthleteClubInput.value = it },
                                    placeholder = {
                                        Text(
                                            stringResource(R.string.club_optional),
                                            color = Color.Gray
                                        )
                                    },
                                    colors = TextFieldDefaults.colors(
                                        unfocusedContainerColor = Color.Transparent,
                                        focusedContainerColor = Color.Transparent,
                                        unfocusedTextColor = Color.White,
                                        focusedTextColor = Color.White,
                                        cursorColor = md_theme_dark_onPrimary
                                    ),
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }

                        Button(
                            onClick = {
                                if (newAthleteNameInput.value.length >= 4) {
                                    viewModel.addAthlete(
                                        newAthleteNameInput.value,
                                        newAthleteClubInput.value,
                                        newAthleteAvatarData.value
                                    )
                                    newAthleteNameInput.value = ""
                                    newAthleteClubInput.value = ""
                                    newAthleteAvatarData.value = null
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = md_theme_dark_onPrimary),
                            enabled = newAthleteNameInput.value.length >= 4
                        ) {
                            Text(stringResource(R.string.add_athlete), color = md_theme_dark_primary)
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
                if (athlete.avatarData != null) {
                    AsyncImage(
                        model = athlete.avatarData,
                        contentDescription = "Avatar",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = athlete.name?.take(1)?.uppercase() ?: "?",
                        color = md_theme_dark_onPrimary,
                        style = MaterialTheme.typography.titleMedium
                    )
                }
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
