package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.model.ScoringUtility
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.model.ShotData
import com.google.gson.Gson
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Star
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun RecentTrainingView(
    modifier: Modifier = Modifier,
    onDrillSelected: ((List<DrillResultWithShots>) -> Unit)? = null
) {
    val context = LocalContext.current
    val drillResultRepository = remember { DrillResultRepository.getInstance(context) }
    val drillSetupRepository = remember { DrillSetupRepository.getInstance(context) }
    
    var recentDrills by remember { mutableStateOf<List<Pair<String, List<DrillResultWithShots>>>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    
    val coroutineScope = rememberCoroutineScope()
    
    suspend fun loadRecentDrills() {
        try {
            isLoading = true
            errorMessage = null
            
            // Get recent results with shots
            val allResults = drillResultRepository.allDrillResultsWithShots.first()
            println("RecentTrainingView: Found ${allResults.size} total results")
            
            // Group by session and take latest 3 sessions
            val groupedBySession = allResults
                .filter { it.drillResult.sessionId != null || true } // Temporarily allow null sessionId
                .groupBy { it.drillResult.sessionId ?: "no-session" }
                .toList()
                .sortedByDescending { (_, results) -> 
                    results.maxOfOrNull { it.drillResult.date ?: Date(0) } ?: Date(0)
                }
                .take(3)
            
            // For each session, get the drill name from the first result
            val drillsWithNames = groupedBySession.mapNotNull { (sessionId, results) ->
                val firstResult = results.firstOrNull() ?: return@mapNotNull null
                val drillSetup = firstResult.drillResult.drillSetupId?.let { setupId ->
                    drillSetupRepository.getDrillSetupById(setupId)
                }
                val drillName = drillSetup?.name ?: "Unknown Drill"
                drillName to results
            }
            
            println("RecentTrainingView: Final drills: ${drillsWithNames.size}")
            recentDrills = drillsWithNames
            isLoading = false
            
        } catch (e: Exception) {
            errorMessage = e.localizedMessage ?: context.getString(R.string.failed_to_load_recent_drills)
            isLoading = false
        }
    }
    
    LaunchedEffect(Unit) {
        coroutineScope.launch {
            loadRecentDrills()
        }
    }
    
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(288.dp)
            .background(Color.Gray.copy(alpha = 0.2f), RoundedCornerShape(16.dp)),
        contentAlignment = Alignment.Center
    ) {
        when {
            isLoading -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator(color = Color.White)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.loading_recent_drills),
                        color = Color.White,
                        fontSize = 14.sp
                    )
                }
            }
            errorMessage != null -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = stringResource(R.string.error),
                        tint = Color.Red,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = errorMessage ?: stringResource(R.string.error),
                        color = Color.White,
                        fontSize = 14.sp,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
            recentDrills.isEmpty() -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "Recent Training",
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "No recent drills available",
                        color = Color.Gray,
                        fontSize = 14.sp
                    )
                }
            }
            else -> {
                // Show the most recent drill
                val (drillName, results) = recentDrills.first()
                DrillCard(
                    drillName = drillName, 
                    results = results,
                    onClick = { onDrillSelected?.invoke(results) }
                )
            }
        }
    }
}

@Composable
private fun DrillCard(
    drillName: String,
    results: List<DrillResultWithShots>,
    onClick: () -> Unit
) {
    val gson = remember { Gson() }
    
    // Calculate summary stats from all results in session
    val allShots = results.flatMap { result ->
        result.shots.mapNotNull { shot ->
            shot.data?.let { json ->
                try {
                    gson.fromJson(json, ShotData::class.java)
                } catch (e: Exception) {
                    null
                }
            }
        }
    }
    
    // Calculate session totals using all shots
    val totalScore = allShots.sumOf { shot ->
        ScoringUtility.scoreForHitArea(shot.content.actualHitArea)
    }.toDouble()
    val totalTime = allShots.sumOf { it.content.actualTimeDiff }
    val hitFactor = if (totalTime > 0) totalScore / totalTime else 0.0
    
    val fastestShot = allShots.minOfOrNull { it.content.actualTimeDiff } ?: 0.0
    val latestDate = results.maxOfOrNull { it.drillResult.date ?: Date(0) } ?: Date(0)
    
    val dateFormatter = remember { SimpleDateFormat("MMM dd", Locale.getDefault()) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Title
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.Star,
                contentDescription = "Drill",
                tint = Color.Red,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = drillName,
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        }
        
        // Target icon placeholder
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(80.dp),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Star,
                contentDescription = "Target",
                tint = Color.Gray,
                modifier = Modifier.size(60.dp)
            )
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        // Stats row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatColumn(
                value = "%.1f".format(hitFactor),
                label = "Hit Factor"
            )
            StatColumn(
                value = dateFormatter.format(latestDate),
                label = "Date"
            )
            StatColumn(
                value = "%.2fs".format(fastestShot),
                label = "Fastest"
            )
        }
    }
}

@Composable
private fun StatColumn(
    value: String,
    label: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            color = Color.Gray,
            fontSize = 12.sp
        )
    }
}