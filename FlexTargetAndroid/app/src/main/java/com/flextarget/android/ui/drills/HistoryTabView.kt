package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.HistoryTabViewModel
import java.text.SimpleDateFormat
import java.util.*

// Data classes for the history view
data class DrillSession(
    val sessionId: String,
    val setup: DrillSetupEntity,
    val date: Date?,
    val results: List<DrillRepeatSummary>
) {
    val repeatCount: Int = results.size
    val totalShots: Int = results.sumOf { it.numShots }
}

enum class DateRange {
    ALL,
    WEEK,
    MONTH;

    val startDate: Date?
        get() {
            val calendar = Calendar.getInstance()
            val now = Date()
            return when (this) {
                ALL -> null
                WEEK -> {
                    calendar.time = now
                    calendar.add(Calendar.DAY_OF_YEAR, -7)
                    calendar.time
                }
                MONTH -> {
                    calendar.time = now
                    calendar.add(Calendar.MONTH, -1)
                    calendar.time
                }
            }
        }

    val endDate: Date = Date()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryTabView(
    onNavigateToSummary: (DrillSetupEntity, List<DrillRepeatSummary>) -> Unit
) {
    val context = LocalContext.current
    val viewModel: HistoryTabViewModel = viewModel(
        factory = HistoryTabViewModel.Factory(
            DrillResultRepository.getInstance(context),
            DrillSetupRepository.getInstance(context)
        )
    )

    var selectedDrillType by remember { mutableStateOf<String?>(null) }
    var selectedDrillName by remember { mutableStateOf<String?>(null) }
    var selectedDateRange by remember { mutableStateOf(DateRange.ALL) }
    var expandedDrillSetups by remember { mutableStateOf<Set<String>>(emptySet()) }

    val groupedResults by viewModel.groupedResults.collectAsState()
    val uniqueDrillTypes by viewModel.uniqueDrillTypes.collectAsState()
    val uniqueDrillNames by viewModel.uniqueDrillNames.collectAsState()

    // Localized strings for date range options
    val allTimeString = stringResource(R.string.all_time)
    val pastWeekString = stringResource(R.string.past_week)
    val pastMonthString = stringResource(R.string.past_month)

    // Apply filters
    val filteredGroupedResults = remember(groupedResults, selectedDrillType, selectedDrillName, selectedDateRange) {
        groupedResults.mapValues { (_, sessions) ->
            sessions.filter { session ->
                // Filter by date range
                val sessionDate = session.date
                if (selectedDateRange.startDate != null && sessionDate != null) {
                    if (sessionDate < selectedDateRange.startDate!! || sessionDate > selectedDateRange.endDate) {
                        return@filter false
                    }
                }

                // Filter by drill type
                if (selectedDrillType != null && session.setup.mode != selectedDrillType) {
                    return@filter false
                }

                // Filter by drill name
                if (selectedDrillName != null && session.setup.name != selectedDrillName) {
                    return@filter false
                }

                true
            }
        }.filter { it.value.isNotEmpty() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.history_title), color = Color.White) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Filter Controls
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Drill Type Filter
                FilterDropdown(
                    label = stringResource(R.string.all_modes),
                    selectedValue = selectedDrillType,
                    options = uniqueDrillTypes,
                    onValueSelected = { selectedDrillType = it }
                )

                // Date Range Filter
                FilterDropdown(
                    label = dateRangeLabel(selectedDateRange),
                    selectedValue = null,
                    options = listOf(allTimeString, pastWeekString, pastMonthString),
                    onValueSelected = { selection ->
                        selectedDateRange = when (selection) {
                            pastWeekString -> DateRange.WEEK
                            pastMonthString -> DateRange.MONTH
                            else -> DateRange.ALL
                        }
                    }
                )

                // Drill Name Filter
                FilterDropdown(
                    label = stringResource(R.string.all_drill_setups),
                    selectedValue = selectedDrillName,
                    options = uniqueDrillNames,
                    onValueSelected = { selectedDrillName = it }
                )
            }

            Divider(color = Color.Red.copy(alpha = 0.3f))

            // Results List
            if (filteredGroupedResults.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            Icons.Default.History,
                            contentDescription = null,
                            tint = Color.Red,
                            modifier = Modifier.size(48.dp)
                        )
                        Text(
                            stringResource(R.string.no_results_found),
                            color = Color.White,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(
                            stringResource(R.string.complete_drills_history),
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    filteredGroupedResults.forEach { (dateKey, sessions) ->
                        item {
                            Text(
                                dateKey,
                                color = Color.Red,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        items(sessions) { session ->
                            val isExpanded = expandedDrillSetups.contains(session.sessionId)

                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(Color.DarkGray.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                            ) {
                                // Session Header
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            if (isExpanded) {
                                                expandedDrillSetups = expandedDrillSetups - session.sessionId
                                            } else {
                                                expandedDrillSetups = expandedDrillSetups + session.sessionId
                                            }
                                        }
                                        .padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            session.setup.name ?: "Untitled",
                                            color = Color.White,
                                            style = MaterialTheme.typography.bodyLarge
                                        )
                                        Text(
                                            "${session.repeatCount} ${stringResource(R.string.repeats_label)}",
                                            color = Color.Gray,
                                            style = MaterialTheme.typography.bodyMedium
                                        )
                                    }
                                    Icon(
                                        if (isExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                                        contentDescription = null,
                                        tint = Color.Red
                                    )
                                }

                                // Expanded Results
                                if (isExpanded) {
                                    Column(
                                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                                        verticalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        session.results.forEach { summary ->
                                            DrillSummaryCard(
                                                drillSetup = session.setup,
                                                summary = summary,
                                                onClick = {
                                                    onNavigateToSummary(session.setup, listOf(summary))
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterDropdown(
    label: String,
    selectedValue: String?,
    options: List<String>,
    onValueSelected: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = Color.Red,
                containerColor = Color.Black
            ),
            border = ButtonDefaults.outlinedButtonBorder,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    selectedValue ?: label,
                    color = Color.White,
                    modifier = Modifier.weight(1f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Start
                )
                Icon(
                    Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = Color.Red
                )
            }
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.background(Color.Black)
        ) {
            DropdownMenuItem(
                text = { Text(label, color = Color.White) },
                onClick = {
                    onValueSelected(null)
                    expanded = false
                },
                modifier = Modifier.background(Color.Black)
            )
            Divider()
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option, color = Color.White) },
                    onClick = {
                        onValueSelected(option)
                        expanded = false
                    },
                    modifier = Modifier.background(Color.Black)
                )
            }
        }
    }
}

@Composable
private fun DrillSummaryCard(
    drillSetup: DrillSetupEntity,
    summary: DrillRepeatSummary,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = Color.DarkGray.copy(alpha = 0.3f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    drillSetup.name ?: "Untitled",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(
                    drillSetup.mode?.uppercase() ?: "N/A",
                    color = Color.Red,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    String.format("%.2fs", summary.totalTime),
                    color = Color.Red,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "${summary.numShots} ${stringResource(R.string.shots_label)}",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

@Composable
private fun dateRangeLabel(dateRange: DateRange): String {
    return when (dateRange) {
        DateRange.ALL -> stringResource(R.string.all_time)
        DateRange.WEEK -> stringResource(R.string.past_week)
        DateRange.MONTH -> stringResource(R.string.past_month)
    }
}