package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.platform.LocalContext
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.DrillRecordViewModel
import java.text.SimpleDateFormat
import java.util.*

// Sealed class for list items
private sealed class ListItem {
    data class Header(val monthKey: String) : ListItem()
    data class SessionItem(val session: com.flextarget.android.ui.viewmodel.DrillRecordViewModel.SessionData) : ListItem()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillRecordView(
    drillSetup: DrillSetupEntity,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val viewModel: DrillRecordViewModel = viewModel(
        factory = DrillRecordViewModel.Factory(
            DrillResultRepository.getInstance(context),
            DrillSetupRepository.getInstance(context)
        )
    )

    val groupedResults by viewModel.getGroupedResults(drillSetup.id).collectAsState(initial = emptyList())
    
    // Flatten the grouped results for LazyColumn
    val flatItems = remember(groupedResults) {
        groupedResults.flatMap { group ->
            listOf(ListItem.Header(group.monthKey)) + 
            group.sessions.map { ListItem.SessionItem(it) }
        }
    }
    
    var showDrillSummary by remember { mutableStateOf(false) }
    var selectedSummaries by remember { mutableStateOf<List<com.flextarget.android.data.model.DrillRepeatSummary>>(emptyList()) }
    var showDrillResult by remember { mutableStateOf(false) }
    var selectedResultSummary by remember { mutableStateOf<com.flextarget.android.data.model.DrillRepeatSummary?>(null) }
    var drillTargets by remember { mutableStateOf<List<com.flextarget.android.data.model.DrillTargetsConfigData>>(emptyList()) }

    // Load targets on composition
    LaunchedEffect(drillSetup.id) {
        drillTargets = viewModel.getTargetsForDrill(drillSetup.id)
    }

    if (showDrillSummary && selectedSummaries.isNotEmpty()) {
        DrillSummaryView(
            drillSetup = drillSetup,
            summaries = selectedSummaries,
            onBack = { showDrillSummary = false },
            onViewResult = { summary ->
                selectedResultSummary = summary
                showDrillResult = true
                showDrillSummary = false  // Hide the summary view when showing result view
            },
            onReplay = {summary -> selectedResultSummary = summary}
        )
    } else if (showDrillResult && selectedResultSummary != null) {
        DrillResultView(
            drillSetup = drillSetup,
            targets = drillTargets,
            repeatSummary = selectedResultSummary,
            onBack = {
                showDrillResult = false
                selectedResultSummary = null
                showDrillSummary = true  // Show summary view again when going back
            }
        )
    } else {
        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                    title = { Text(stringResource(R.string.drill_history), color = Color.White) },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                Icons.Default.ArrowBack,
                                contentDescription = "Back",
                                tint = Color.Red
                            )
                        }
                    },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = Color.Black
                    )
                )
            },
            containerColor = Color.Black
        ) { paddingValues ->
            if (flatItems.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No drill history found for this drill setup.",
                        color = Color.Gray,
                        fontSize = 16.sp,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .background(Color.Black),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    flatItems.forEach { item ->
                        when (item) {
                            is ListItem.Header -> {
                                item {
                                    Text(
                                        text = item.monthKey.uppercase(),
                                        color = Color.White,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(horizontal = 16.dp, vertical = 12.dp)
                                    )
                                }
                            }
                            is ListItem.SessionItem -> {
                                item {
                                    DrillRecordRowView(
                                        model = DrillRecordRowView.Model(
                                            sessionId = item.session.sessionId,
                                            date = item.session.firstResult.drillResult.date ?: Date(),
                                            repeats = item.session.allResults.size,
                                            totalShots = item.session.summaries.sumOf { it.numShots },
                                            fastestShot = item.session.summaries.mapNotNull { it.fastest.takeIf { it > 0 } }.minOrNull() ?: 0.0
                                        ),
                                        onClick = {
                                            selectedSummaries = item.session.summaries
                                            showDrillSummary = true
                                        },
                                        onDelete = {
                                            viewModel.deleteSession(item.session.sessionId)
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

@Composable
private fun DrillRecordRowView(
    model: DrillRecordRowView.Model,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Date circle
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(Color.Red, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = model.dayText.uppercase(),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Metrics card
        Card(
            modifier = Modifier.weight(1f),
            colors = CardDefaults.cardColors(
                containerColor = Color.Gray.copy(alpha = 0.2f)
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                DrillMetricColumn(
                    value = model.repeatsText,
                    label = "#repeats"
                )

                Spacer(modifier = Modifier.width(8.dp))

                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(44.dp)
                        .background(Color.Red)
                )

                Spacer(modifier = Modifier.width(8.dp))

                DrillMetricColumn(
                    value = model.totalShotsText,
                    label = "#Shots"
                )

                Spacer(modifier = Modifier.width(8.dp))

                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(44.dp)
                        .background(Color.Red)
                )

                Spacer(modifier = Modifier.width(8.dp))

                DrillMetricColumn(
                    value = model.fastestShotText,
                    label = "Fastest"
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Delete button
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = Color.Red
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        Icon(
            Icons.Default.KeyboardArrowRight,
            contentDescription = "Navigate",
            tint = Color.Gray
        )
    }
}

@Composable
private fun DrillMetricColumn(
    value: String,
    label: String
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = value,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Text(
            text = label,
            color = Color.Gray,
            fontSize = 12.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

private object DrillRecordRowView {
    data class Model(
        val sessionId: UUID,
        val date: Date,
        val repeats: Int,
        val totalShots: Int,
        val fastestShot: Double
    ) {
        val dayText: String
            get() = dayFormatter.format(date)

        val repeatsText: String
            get() = repeats.toString()

        val totalShotsText: String
            get() = totalShots.toString()

        val fastestShotText: String
            get() = if (fastestShot > 0) {
                String.format("%.2fs", fastestShot)
            } else {
                "--"
            }

        companion object {
            private val dayFormatter = SimpleDateFormat("d", Locale.getDefault())
        }
    }
}