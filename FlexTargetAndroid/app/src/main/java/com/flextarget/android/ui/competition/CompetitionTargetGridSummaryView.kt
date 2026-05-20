package com.flextarget.android.ui.competition

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.local.entity.primaryTargetType
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ShotData
import com.flextarget.android.data.model.ScoringUtility

private data class CompetitionTargetRowState(
    val key: String,
    val rowNo: Int,
    val label: String,
    val targetType: String,
    val a: Int,
    val c: Int,
    val d: Int,
    val m: Int,
    val ns: Int,
    val npm: Int
)

private enum class CompetitionTargetColumn {
    A, C, D, M, NS, NPM
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CompetitionTargetGridSummaryView(
    drillSetup: DrillSetupEntity,
    targets: List<DrillTargetsConfigEntity>,
    summaries: List<DrillRepeatSummary>,
    shooterName: String?,
    stageName: String?,
    onBack: () -> Unit,
    onReview: (List<DrillRepeatSummary>) -> Unit
) {
    var rows by remember(drillSetup.id, summaries, targets) {
        mutableStateOf(buildRows(targets = targets, summary = summaries.firstOrNull()))
    }

    var additionalPenalties by remember(summaries, rows) {
        val totalPe = summaries.firstOrNull()?.adjustedHitZones?.get("PE") ?: 0
        val npmTotal = rows.sumOf { it.npm }
        mutableStateOf(maxOf(0, totalPe - npmTotal))
    }

    val totals = remember(rows, additionalPenalties) {
        mapOf(
            "A" to rows.sumOf { it.a },
            "C" to rows.sumOf { it.c },
            "D" to rows.sumOf { it.d },
            "M" to rows.sumOf { it.m },
            "N" to rows.sumOf { it.ns },
            "PE" to rows.sumOf { it.npm } + additionalPenalties
        )
    }

    val score = remember(totals) {
        ScoringUtility.calculateScoreFromAdjustedHitZones(totals, drillSetup)
    }

    fun updateCell(index: Int, column: CompetitionTargetColumn, reset: Boolean) {
        if (index !in rows.indices) return
        val row = rows[index]
        val updated = when (column) {
            CompetitionTargetColumn.A -> row.copy(a = if (reset) 0 else row.a + 1)
            CompetitionTargetColumn.C -> row.copy(c = if (reset) 0 else row.c + 1)
            CompetitionTargetColumn.D -> row.copy(d = if (reset) 0 else row.d + 1)
            CompetitionTargetColumn.M -> row.copy(m = if (reset) 0 else row.m + 1)
            CompetitionTargetColumn.NS -> row.copy(ns = if (reset) 0 else row.ns + 1)
            CompetitionTargetColumn.NPM -> row.copy(npm = if (reset) 0 else row.npm + 1)
        }
        rows = rows.toMutableList().also { it[index] = updated }
    }

    fun buildUpdatedSummaries(): List<DrillRepeatSummary> {
        if (summaries.isEmpty()) return summaries
        val updatedZones = totals.toMap()
        val first = summaries.first().copy(
            adjustedHitZones = updatedZones,
            score = ScoringUtility.calculateScoreFromAdjustedHitZones(updatedZones, drillSetup)
        )
        return listOf(first) + summaries.drop(1)
    }

    fun buildDnfSummaries(): List<DrillRepeatSummary> {
        if (summaries.isEmpty()) return summaries
        val zeroZones = mapOf("A" to 0, "C" to 0, "D" to 0, "M" to 0, "N" to 0, "PE" to 0)
        return summaries.map { summary ->
            summary.copy(adjustedHitZones = zeroZones, score = 0)
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "Competition Summary",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color(0xFFDE3823)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
        ) {
            Text(
                text = shooterName?.ifBlank { "Unknown Shooter" } ?: "Unknown Shooter",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = stageName?.ifBlank { "-" } ?: "-",
                color = Color.Gray,
                style = MaterialTheme.typography.titleMedium
            )

            Spacer(modifier = Modifier.height(12.dp))

            HeaderRow()

            Spacer(modifier = Modifier.height(6.dp))

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(rows) { index, row ->
                    TargetRow(
                        row = row,
                        onCellTap = { column -> updateCell(index, column, reset = false) },
                        onCellLongPress = { column -> updateCell(index, column, reset = true) }
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Additional Penalties", color = Color.Gray)
                Spacer(modifier = Modifier.weight(1f))
                Text("$additionalPenalties", color = Color.White)
                Text(
                    text = "−",
                    color = Color(0xFF3F51B5),
                    modifier = Modifier
                        .padding(horizontal = 10.dp)
                        .combinedClickable(onClick = {
                            additionalPenalties = maxOf(0, additionalPenalties - 1)
                        })
                )
                Text(
                    text = "+",
                    color = Color(0xFF3F51B5),
                    modifier = Modifier
                        .padding(horizontal = 10.dp)
                        .combinedClickable(onClick = {
                            additionalPenalties += 1
                        })
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Score", color = Color.Gray)
                Spacer(modifier = Modifier.weight(1f))
                Text(score.toString(), color = Color.White, fontWeight = FontWeight.Bold)
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = {
                        rows = rows.map { it.copy(a = 0, c = 0, d = 0, m = 0, ns = 0, npm = 0) }
                        additionalPenalties = 0
                        onReview(buildDnfSummaries())
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3F51B5)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("DNF/0.0", color = Color.White)
                }

                Button(
                    onClick = { onReview(buildUpdatedSummaries()) },
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDE3823)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("Review", color = Color.White)
                }
            }
        }
    }
}

@Composable
private fun HeaderRow() {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text("T#", color = Color.Gray, modifier = Modifier.width(40.dp))
        HeaderCell("A")
        HeaderCell("C")
        HeaderCell("D")
        HeaderCell("M")
        HeaderCell("NS")
        HeaderCell("NPM")
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TargetRow(
    row: CompetitionTargetRowState,
    onCellTap: (CompetitionTargetColumn) -> Unit,
    onCellLongPress: (CompetitionTargetColumn) -> Unit
) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(row.rowNo.toString(), color = Color.Gray, modifier = Modifier.width(40.dp))
        ScoreCell(value = row.a, onTap = { onCellTap(CompetitionTargetColumn.A) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.A) })
        ScoreCell(value = row.c, onTap = { onCellTap(CompetitionTargetColumn.C) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.C) })
        ScoreCell(value = row.d, onTap = { onCellTap(CompetitionTargetColumn.D) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.D) })
        ScoreCell(value = row.m, onTap = { onCellTap(CompetitionTargetColumn.M) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.M) })
        ScoreCell(value = row.ns, onTap = { onCellTap(CompetitionTargetColumn.NS) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.NS) })
        ScoreCell(value = row.npm, onTap = { onCellTap(CompetitionTargetColumn.NPM) }, onLongPress = { onCellLongPress(CompetitionTargetColumn.NPM) })
    }
}

@Composable
private fun HeaderCell(text: String) {
    Box(modifier = Modifier.width(44.dp), contentAlignment = Alignment.Center) {
        Text(text = text, color = Color.Gray)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ScoreCell(value: Int, onTap: () -> Unit, onLongPress: () -> Unit) {
    Box(
        modifier = Modifier
            .width(44.dp)
            .height(40.dp)
            .padding(horizontal = 2.dp)
            .background(if (value > 0) Color(0xFF00FF00) else Color(0xFFFF6B6B), RoundedCornerShape(6.dp))
            .combinedClickable(onClick = onTap, onLongClick = onLongPress),
        contentAlignment = Alignment.Center
    ) {
        Text(value.toString(), color = Color.Black, fontWeight = FontWeight.Bold)
    }
}

private fun buildRows(
    targets: List<DrillTargetsConfigEntity>,
    summary: DrillRepeatSummary?
): List<CompetitionTargetRowState> {
    val targetList = targets.sortedWith(compareBy<DrillTargetsConfigEntity> { it.seqNo }.thenBy { it.targetName ?: "" })
    val groupedShots = mutableMapOf<String, MutableList<ShotData>>()
    (summary?.shots ?: emptyList()).forEach { shot ->
        val key = normalizedTargetKey(shot)
        groupedShots.getOrPut(key) { mutableListOf() }.add(shot)
    }

    return targetList.mapIndexed { index, target ->
        val name = target.targetName?.trim()?.lowercase().orEmpty().ifEmpty { "target_${index + 1}" }
        val type = target.primaryTargetType().trim().lowercase()
        val key = "$name|$type"
        val rowShots = groupedShots[key].orEmpty()

        var a = 0
        var c = 0
        var d = 0
        var m = 0
        var ns = 0

        rowShots.forEach { shot ->
            when (normalizeHitArea(shot.content.actualHitArea)) {
                "azone", "a", "circlearea", "popperzone", "apopper" -> a += 1
                "czone", "c" -> c += 1
                "dzone", "d" -> d += 1
                "whitezone" -> ns += 1
                "miss", "m" -> m += 1
            }
        }

        CompetitionTargetRowState(
            key = key,
            rowNo = if (target.seqNo > 0) target.seqNo else index + 1,
            label = target.targetName ?: "T${index + 1}",
            targetType = type,
            a = a,
            c = c,
            d = d,
            m = m,
            ns = ns,
            npm = 0
        )
    }
}

private fun normalizedTargetKey(shot: ShotData): String {
    val type = shot.content.actualTargetType.trim().lowercase()
    val name = shot.target?.trim()?.takeIf { it.isNotEmpty() }
    if (name != null) return "${name.lowercase()}|$type"

    val device = shot.content.device ?: shot.device
    if (!device.isNullOrBlank()) return "${device.trim().lowercase()}|$type"
    return "unknown|$type"
}

private fun normalizeHitArea(raw: String?): String {
    val trimmed = raw?.trim()?.lowercase().orEmpty()
    if (trimmed.isEmpty()) return "miss"
    return when (trimmed) {
        "circle", "circlearea", "circle_area", "circle-area" -> "circlearea"
        "popper", "popperzone", "popper_zone", "popper-zone" -> "popperzone"
        "azone", "a", "a-zone", "a_zone" -> "azone"
        "apopper", "a_popper", "a-popper" -> "apopper"
        "czone", "c", "c-zone", "c_zone" -> "czone"
        "dzone", "d", "d-zone", "d_zone" -> "dzone"
        "whitezone", "white_zone", "white-zone" -> "whitezone"
        "blackzone", "black_zone", "black-zone",
        "blackzoneleft", "black_zone_left", "black-zone-left",
        "blackzoneright", "black_zone_right", "black-zone-right" -> "miss"
        "miss", "m" -> "miss"
        else -> trimmed
    }
}
