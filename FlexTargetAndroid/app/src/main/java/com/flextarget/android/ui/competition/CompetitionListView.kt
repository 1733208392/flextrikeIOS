package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.CallToAction
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.ui.window.Dialog
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.theme.ttNormFontFamily
import java.text.SimpleDateFormat
import java.util.*
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import com.flextarget.android.ui.theme.md_theme_dark_primary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompetitionListView(
    onBack: () -> Unit,
    viewModel: CompetitionViewModel,
    drillViewModel: DrillViewModel,
    bleManager: com.flextarget.android.data.ble.BLEManager
) {
    val uiState by viewModel.competitionUiState.collectAsState()
    val drillUiState by drillViewModel.drillUiState.collectAsState()
    val searchQuery = remember { mutableStateOf("") }
    val showAddDialog = remember { mutableStateOf(false) }

    val filteredCompetitions = uiState.competitions.filter { competition ->
        competition.name.contains(searchQuery.value, ignoreCase = true) ||
                (competition.venue?.contains(searchQuery.value, ignoreCase = true) ?: false)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        CenterAlignedTopAppBar(
            title = { Text(stringResource(R.string.competitions)) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                }
            },
            actions = {
                IconButton(onClick = { showAddDialog.value = true }) {
                    Icon(Icons.Default.Add, contentDescription = "Add Competition")
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = Color.Black,
                titleContentColor = md_theme_dark_onPrimary,
                navigationIconContentColor = Color.Red,
                actionIconContentColor = Color.Red
            )
        )

        // Search Bar
        SearchBar(
            value = searchQuery.value,
            onValueChange = { searchQuery.value = it },
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
        )

        // Competitions List
        if (filteredCompetitions.isEmpty()) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CallToAction,
                        contentDescription = "Add Drill",
                        tint = md_theme_dark_onPrimary,
                        modifier = Modifier.size(48.dp)
                    )
                    Text(
                        text = stringResource(R.string.no_competitions_yet),
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .background(Color.Black),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(filteredCompetitions) { competition ->
                    CompetitionCard(
                        competition = competition,
                        onClick = { viewModel.selectCompetition(competition) },
                        onDelete = { viewModel.deleteCompetition(competition.id) }
                    )
                }
            }
        }
    }

    if (showAddDialog.value) {
        AddCompetitionDialog(
            drills = drillUiState.drills,
            onDismiss = { showAddDialog.value = false },
            onConfirm = { name, venue, date, drillId ->
                viewModel.createCompetition(name, venue, date, drillSetupId = drillId)
                showAddDialog.value = false
            }
        )
    }
}

@Composable
fun CompetitionCard(
    competition: CompetitionEntity,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val dateFormat = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                        text = competition.name.uppercase(),
                        color = md_theme_dark_onPrimary,
                )
                
                if (!competition.venue.isNullOrEmpty()) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 4.dp)
                    ) {
                        Icon(
                            Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = Color.Gray,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = competition.venue ?: "",
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 4.dp)
                ) {
                    Icon(
                        Icons.Default.DateRange,
                        contentDescription = null,
                        tint = Color.Red,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = dateFormat.format(competition.date),
                        color = Color.Red,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            }

            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.Gray.copy(alpha = 0.5f)
                )
            }
        }
    }
}

@Composable
private fun SearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        placeholder = { Text(stringResource(R.string.search_competitions), color = Color.Gray) },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color.Gray) },
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = Color.Red,
            unfocusedBorderColor = Color.Gray
        ),
        singleLine = true,
        shape = RoundedCornerShape(10.dp)
    )
}

@Composable
fun AddCompetitionDialog(
    drills: List<DrillSetupEntity>,
    onDismiss: () -> Unit,
    onConfirm: (String, String, Date, UUID?) -> Unit
) {
    val name = remember { mutableStateOf("") }
    val venue = remember { mutableStateOf("") }
    val date = remember { mutableStateOf(Date()) }
    val selectedDrill = remember { mutableStateOf<DrillSetupEntity?>(null) }
    var showDrillPicker by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.new_competition), style = MaterialTheme.typography.titleLarge.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TextField(
                    value = name.value,
                    onValueChange = { name.value = it },
                    label = { Text(stringResource(R.string.competition_name), style = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)) },
                    modifier = Modifier.fillMaxWidth()
                    ,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)
                )
                TextField(
                    value = venue.value,
                    onValueChange = { venue.value = it },
                    label = { Text(stringResource(R.string.venue_optional), style = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)) },
                    modifier = Modifier.fillMaxWidth()
                    ,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)
                )

                // Drill Selector
                OutlinedCard(
                    onClick = { showDrillPicker = true },
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.outlinedCardColors(
                        containerColor = md_theme_dark_primary
                    )
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = selectedDrill.value?.name
                                ?: stringResource(R.string.select_drill_setup),
                            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary)
                        )
                        Icon(
                            Icons.Default.ArrowDropDown,
                            contentDescription = null,
                            tint = md_theme_dark_onPrimary
                        )
                    }
                }

                Text(
                    text = stringResource(R.string.date_label) + SimpleDateFormat(
                        "MMM dd, yyyy",
                        Locale.getDefault()
                    ).format(date.value),
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary),
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onConfirm(
                        name.value,
                        venue.value,
                        date.value,
                        selectedDrill.value?.id
                    )
                },
                enabled = name.value.isNotEmpty() && selectedDrill.value != null,
                colors = ButtonDefaults.buttonColors(containerColor = md_theme_dark_onPrimary, contentColor = md_theme_dark_primary)
            ) {
                Text(stringResource(R.string.create), style = MaterialTheme.typography.labelLarge.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_primary))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, colors = ButtonDefaults.buttonColors(containerColor = md_theme_dark_onPrimary, contentColor = md_theme_dark_primary)) {
                Text(stringResource(R.string.cancel), style = MaterialTheme.typography.labelLarge.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_primary))
            }
        },
        containerColor = md_theme_dark_primary

    )

    if (showDrillPicker) {
        DrillPickerDialog(
            drills = drills,
            onDismiss = { showDrillPicker = false },
            onSelect = {
                selectedDrill.value = it
                showDrillPicker = false
            }
        )
    }
}

@Composable
fun DrillPickerDialog(
    drills: List<DrillSetupEntity>,
    onDismiss: () -> Unit,
    onSelect: (DrillSetupEntity) -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.5f),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = md_theme_dark_primary)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                text = stringResource(R.string.select_drill_setup).uppercase(),
                style = MaterialTheme.typography.titleMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary),
                    modifier = Modifier.padding(bottom = 16.dp)
                )

                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(drills) { drill ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onSelect(drill) }
                                .padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = drill.name ?: stringResource(R.string.untitled),
                                style = MaterialTheme.typography.bodyMedium.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_onPrimary),
                                modifier = Modifier.padding(start = 12.dp)
                            )
                        }
                        Divider(
                            color = Color.Gray.copy(alpha = 0.2f),
                            thickness = 1.dp
                        )
                    }
                }

                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.End),
                    colors = ButtonDefaults.buttonColors(containerColor = md_theme_dark_onPrimary, contentColor = md_theme_dark_primary)
                ) {
                    Text(stringResource(R.string.cancel), style = MaterialTheme.typography.labelLarge.copy(fontFamily = ttNormFontFamily, color = md_theme_dark_primary))
                }
            }
        }
    }
}
