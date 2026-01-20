package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.BorderStroke
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.DrillFormViewModel
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.DrillTargetsConfigData
import com.flextarget.android.ui.drills.TargetConfigListView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject

enum class DrillFormMode {
    ADD,
    EDIT
}

enum class DrillFormScreen {
    FORM,
    TARGET_CONFIG
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillFormView(
    bleManager: BLEManager,
    mode: DrillFormMode,
    existingDrill: DrillSetupEntity? = null,
    onBack: () -> Unit,
    onDrillSaved: (DrillSetupEntity) -> Unit = {},
    viewModel: DrillFormViewModel
) {
    val coroutineScope = rememberCoroutineScope()
    val androidBleManager = bleManager.androidManager

    // Form state
    var drillName by remember { mutableStateOf(existingDrill?.name ?: "") }
    var description by remember { mutableStateOf(existingDrill?.desc ?: "") }
    var drillMode by remember { mutableStateOf(existingDrill?.mode ?: "ipsc") }
    var repeats by remember { mutableStateOf(existingDrill?.repeats ?: 1) }
    var pause by remember { mutableStateOf(existingDrill?.pause ?: 5) }
    var targets by remember { mutableStateOf<List<DrillTargetsConfigData>>(emptyList()) }
    var isTargetListReceived by remember { mutableStateOf(false) }
    var currentScreen by remember { mutableStateOf(DrillFormScreen.FORM) }
    var showEditDisabledAlert by remember { mutableStateOf(false) }
    var drillResultCount by remember { mutableStateOf(0) }

    var isSaving by remember { mutableStateOf(false) }

    // Check if editing is disabled (drill has results or is linked to a competition)
    val isEditingDisabled = existingDrill != null && drillResultCount > 0

    val isFormValid = drillName.isNotBlank() && bleManager.isConnected && !isEditingDisabled

    // Query device list on appear
    LaunchedEffect(Unit) {
        queryDeviceList(bleManager)
    }

    // Load drill result count if editing existing drill
    existingDrill?.id?.let { drillId ->
        LaunchedEffect(drillId) {
            try {
                drillResultCount = viewModel.getDrillResultCount(drillId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // Observe device list updates
    LaunchedEffect(bleManager.networkDevices, bleManager.lastDeviceListUpdate) {
        if (bleManager.networkDevices.isNotEmpty()) {
            isTargetListReceived = true
        }
    }

    // Load targets for existing drill
    existingDrill?.id?.let { drillId ->
        LaunchedEffect(drillId) {
            try {
                val loadedTargets = viewModel.getTargetsForDrill(drillId)
                targets = loadedTargets
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // Observe error alerts
    if (bleManager.showErrorAlert && bleManager.errorMessage != null) {
        AlertDialog(
            onDismissRequest = { bleManager.showErrorAlert = false },
            title = { Text("Error") },
            text = { Text(bleManager.errorMessage ?: "Unknown error occurred") },
            confirmButton = {
                Button(
                    onClick = { bleManager.showErrorAlert = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text("OK")
                }
            }
        )
    }

    // Alert for editing disabled drills
    if (showEditDisabledAlert) {
        AlertDialog(
            onDismissRequest = { showEditDisabledAlert = false },
            title = { Text("Training Records Available") },
            text = { Text("Changing the configuration is not allowed. Please create a new Drill") },
            confirmButton = {
                Button(
                    onClick = { showEditDisabledAlert = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text("OK")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = when (currentScreen) {
                            DrillFormScreen.FORM -> if (mode == DrillFormMode.ADD) "Add Drill" else "Edit Drill"
                            DrillFormScreen.TARGET_CONFIG -> "Targets"
                        },
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        when (currentScreen) {
                            DrillFormScreen.FORM -> onBack()
                            DrillFormScreen.TARGET_CONFIG -> currentScreen = DrillFormScreen.FORM
                        }
                    }) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.Red
                        )
                    }
                },
                actions = {
                    if (currentScreen == DrillFormScreen.TARGET_CONFIG) {
                        val maxTargets = bleManager.networkDevices.size
                        val canAddMore = targets.size < maxTargets
                        IconButton(
                            onClick = {
                                val maxTargets = bleManager.networkDevices.size
                                if (targets.size < maxTargets) {
                                    val nextSeqNo = (targets.maxOfOrNull { it.seqNo } ?: 0) + 1
                                    targets = targets + DrillTargetsConfigData(
                                        seqNo = nextSeqNo,
                                        targetName = "",
                                        targetType = "ipsc",
                                        timeout = 30.0,
                                        countedShots = 5
                                    )
                                }
                            },
                            enabled = targets.size < bleManager.networkDevices.size
                        ) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = "Add Target",
                                tint = if (canAddMore) Color.Red else Color.Gray
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        }
    ) { paddingValues ->
        when (currentScreen) {
            DrillFormScreen.FORM -> {
                FormScreen(
                    drillName = drillName,
                    onDrillNameChange = { drillName = it },
                    description = description,
                    onDescriptionChange = { description = it },
                    drillMode = drillMode,
                    onDrillModeChange = { drillMode = it },
                    repeats = repeats,
                    onRepeatsChange = { repeats = it },
                    pause = pause,
                    onPauseChange = { pause = it },
                    targets = targets,
                    isTargetListReceived = isTargetListReceived,
                    bleManager = bleManager,
                    onNavigateToTargetConfig = { if (!isEditingDisabled) currentScreen = DrillFormScreen.TARGET_CONFIG else showEditDisabledAlert = true },
                    isSaving = isSaving,
                    isFormValid = isFormValid,
                    mode = mode,
                    existingDrill = existingDrill,
                    onDrillSaved = onDrillSaved,
                    onBack = onBack,
                    viewModel = viewModel,
                    coroutineScope = coroutineScope,
                    paddingValues = paddingValues,
                    androidBleManager = androidBleManager,
                    isEditingDisabled = isEditingDisabled
                )
            }
            DrillFormScreen.TARGET_CONFIG -> {
                TargetConfigScreen(
                    bleManager = bleManager,
                    targetConfigs = targets,
                    drillMode = drillMode,
                    onAddTarget = {
                        val availableDevices = bleManager.networkDevices.filter { device ->
                            targets.none { it.targetName == device.name }
                        }
                        if (availableDevices.isNotEmpty()) {
                            val nextSeqNo = targets.size + 1
                            val newTarget = DrillTargetsConfigData(
                                seqNo = nextSeqNo,
                                targetName = availableDevices.first().name,
                                targetType = DrillTargetsConfigData.getDefaultTargetTypeForDrillMode(drillMode),
                                timeout = 30.0,
                                countedShots = 5
                            )
                            targets = targets + newTarget
                        }
                    },
                    onDeleteTarget = { index ->
                        targets = targets.filterIndexed { i, _ -> i != index }
                            .mapIndexed { i, config -> config.copy(seqNo = i + 1) }
                    },
                    onUpdateTargetDevice = { index, deviceName ->
                        targets = targets.mapIndexed { i, config ->
                            if (i == index) config.copy(targetName = deviceName) else config
                        }
                    },
                    onUpdateTargetType = { index, type ->
                        targets = targets.mapIndexed { i, config ->
                            if (i == index) config.copy(targetType = type) else config
                        }
                    },
                    onDone = { currentScreen = DrillFormScreen.FORM },
                    onBack = { currentScreen = DrillFormScreen.FORM },
                    paddingValues = paddingValues
                )
            }
        }
    }
}

@Composable
private fun FormScreen(
    drillName: String,
    onDrillNameChange: (String) -> Unit,
    description: String,
    onDescriptionChange: (String) -> Unit,
    drillMode: String,
    onDrillModeChange: (String) -> Unit,
    repeats: Int,
    onRepeatsChange: (Int) -> Unit,
    pause: Int,
    onPauseChange: (Int) -> Unit,
    targets: List<DrillTargetsConfigData>,
    isTargetListReceived: Boolean,
    bleManager: BLEManager,
    onNavigateToTargetConfig: () -> Unit,
    isSaving: Boolean,
    isFormValid: Boolean,
    mode: DrillFormMode,
    existingDrill: DrillSetupEntity?,
    onDrillSaved: (DrillSetupEntity) -> Unit,
    onBack: () -> Unit,
    viewModel: DrillFormViewModel,
    coroutineScope: CoroutineScope,
    paddingValues: PaddingValues,
    androidBleManager: AndroidBLEManager?,
    isEditingDisabled: Boolean = false
) {
    var showTimerSession by remember { mutableStateOf(false) }
    var timerSessionDrill by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var timerSessionTargets by remember { mutableStateOf<List<DrillTargetsConfigEntity>>(emptyList()) }
    var showDrillSummary by remember { mutableStateOf(false) }
    var drillSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }
    var showDrillResult by remember { mutableStateOf(false) }
    var selectedResultSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var showDrillReplay by remember { mutableStateOf(false) }
    var selectedReplaySummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(paddingValues)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Warning label if editing is disabled
            if (isEditingDisabled) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Settings,
                        contentDescription = "Lock",
                        tint = Color(0xFFFFA500),
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        "Editing is disabled because this drill has results or is linked to a competition.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFFFA500)
                    )
                }
            }

            // Drill Name Section
            DrillNameSection(
                drillName = drillName,
                onDrillNameChange = onDrillNameChange
            )

            // Description Section
            DrillDescriptionSection(
                description = description,
                onDescriptionChange = onDescriptionChange
            )

            // Drill Mode Section
            DrillModeSection(
                drillMode = drillMode,
                onDrillModeChange = onDrillModeChange
            )

            // Configuration Sections
            DrillConfigurationSection(
                repeats = repeats,
                onRepeatsChange = onRepeatsChange,
                pause = pause,
                onPauseChange = onPauseChange
            )

            // Targets Section
            DrillTargetsSection(bleManager, targets, isTargetListReceived, onNavigateToTargetConfig)

            // Action Buttons
            Spacer(modifier = Modifier.weight(1f))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Save Button
                Button(
                    onClick = {
                        coroutineScope.launch {
                            try {
                                val drill = DrillSetupEntity(
                                    name = drillName,
                                    desc = description,
                                    mode = drillMode,
                                    drillDuration = 5.0,
                                    repeats = repeats,
                                    pause = pause
                                )

                                val savedDrill = if (mode == DrillFormMode.ADD) {
                                    viewModel.saveNewDrillWithTargets(drill, targets)
                                } else {
                                    existingDrill?.let { viewModel.updateDrillWithTargets(it.copy(
                                        name = drillName,
                                        desc = description,
                                        drillDuration = 5.0,
                                        repeats = repeats,
                                        pause = pause
                                    ), targets) } ?: drill
                                }

                                onDrillSaved(savedDrill)
                                onBack()
                            } catch (e: Exception) {
                                // Handle error
                                e.printStackTrace()
                            }
                        }
                    },
                    enabled = isFormValid && !isSaving,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isFormValid) Color.Red else Color.Gray
                    )
                ) {
                    Text(
                        text = if (isSaving) "Saving..." else if (mode == DrillFormMode.ADD) "Save Drill" else "Save Changes",
                        color = Color.White
                    )
                }

                // Start drill session
                Button(
                    onClick = {
                        val sessionDrill = (existingDrill ?: DrillSetupEntity()).copy(
                            name = drillName,
                            desc = description,
                            mode = drillMode,
                            drillDuration = 5.0,
                            repeats = repeats,
                            pause = pause
                        )

                        val sessionTargets = targets.map { target ->
                            DrillTargetsConfigEntity(
                                id = target.id,
                                seqNo = target.seqNo,
                                targetName = target.targetName.takeIf { it.isNotBlank() },
                                targetType = target.targetType,
                                timeout = target.timeout,
                                countedShots = target.countedShots,
                                drillSetupId = sessionDrill.id
                            )
                        }

                        timerSessionDrill = sessionDrill
                        timerSessionTargets = sessionTargets
                        showTimerSession = true
                    },
                    enabled = bleManager.isConnected && androidBleManager != null,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (bleManager.isConnected && androidBleManager != null) Color.Green else Color.Gray
                    )
                ) {
                    Text("Start Drill", color = Color.White)
                }
            }
        }

        if (isSaving) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = Color.Red
            )
        }
        if (showTimerSession && timerSessionDrill != null && androidBleManager != null) {
            TimerSessionView(
                drillSetup = timerSessionDrill!!,
                targets = timerSessionTargets,
                bleManager = androidBleManager,
                drillResultRepository = DrillResultRepository.getInstance(LocalContext.current),
                onDrillComplete = { summaries ->
                    println("[DrillFormView] onDrillComplete called with ${summaries.size} summaries")
                    summaries.forEach { summary ->
                        println("[DrillFormView] Summary ${summary.repeatIndex}: ${summary.numShots} shots, score: ${summary.score}, time: ${summary.totalTime}")
                    }
                    drillSummaries = summaries
                    showTimerSession = false
                    showDrillSummary = true
                },
                onDrillFailed = {
                    showTimerSession = false
                },
                onBack = {
                    showTimerSession = false
                }
            )
        }

        if (showDrillSummary && timerSessionDrill != null) {
            DrillSummaryView(
                drillSetup = timerSessionDrill!!,
                summaries = drillSummaries,
                onBack = {
                    showDrillSummary = false
                },
                onViewResult = { summary ->
                    selectedResultSummary = summary
                    showDrillResult = true
                },
                onReplay = { summary ->
                    selectedReplaySummary = summary
                    showDrillReplay = true
                }
            )
        }

        if (showDrillResult && timerSessionDrill != null && selectedResultSummary != null) {
            DrillResultView(
                drillSetup = timerSessionDrill!!,
                targets = timerSessionTargets.map { DrillTargetsConfigData.fromEntity(it) },
                repeatSummary = selectedResultSummary,
                onBack = {
                    showDrillResult = false
                    selectedResultSummary = null
                }
            )
        }

        if (showDrillReplay && selectedReplaySummary != null) {
            DrillReplayView(
                drillSetup = timerSessionDrill!!,
                shots = selectedReplaySummary!!.shots,
                onBack = {
                    showDrillReplay = false
                    selectedReplaySummary = null
                }
            )
        }
    }
}

@Composable
private fun TargetConfigScreen(
    bleManager: BLEManager,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onAddTarget: () -> Unit,
    onDeleteTarget: (Int) -> Unit,
    onUpdateTargetDevice: (Int, String) -> Unit,
    onUpdateTargetType: (Int, String) -> Unit,
    onDone: () -> Unit,
    onBack: () -> Unit,
    paddingValues: PaddingValues
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(paddingValues)
    ) {
        TargetConfigListView(
            bleManager = bleManager,
            targetConfigs = targetConfigs,
            drillMode = drillMode,
            onAddTarget = onAddTarget,
            onDeleteTarget = onDeleteTarget,
            onUpdateTargetDevice = onUpdateTargetDevice,
            onUpdateTargetType = onUpdateTargetType,
            onDone = onDone,
            onBack = onBack
        )
    }
}

private fun queryDeviceList(bleManager: BLEManager) {
    if (!bleManager.isConnected) {
        println("BLE not connected, cannot query device list")
        return
    }

    val command = mapOf("action" to "netlink_query_device_list")
    val jsonString = JSONObject(command).toString()

    println("Query message length: ${jsonString.toByteArray().size}")
    bleManager.writeJSON(jsonString)
    println("Sent netlink_query_device_list command: $jsonString")
}

@Composable
private fun DrillNameSection(
    drillName: String,
    onDrillNameChange: (String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Drill Name",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = drillName,
                onValueChange = onDrillNameChange,
                placeholder = { Text("Enter drill name", color = Color.Gray) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Red,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    cursorColor = Color.Red
                )
            )
        }
    }
}

@Composable
private fun DrillDescriptionSection(
    description: String,
    onDescriptionChange: (String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Description",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = description,
                onValueChange = onDescriptionChange,
                placeholder = { Text("Enter drill description (optional)", color = Color.Gray) },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Red,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    cursorColor = Color.Red
                )
            )
        }
    }
}

@Composable
private fun DrillModeSection(
    drillMode: String,
    onDrillModeChange: (String) -> Unit
) {
    val drillModes = listOf("ipsc", "idpa", "cqb")
    val modeTitles = mapOf(
        "ipsc" to "IPSC",
        "idpa" to "IDPA",
        "cqb" to "CQB"
    )

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Drill Mode",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                drillModes.forEach { mode ->
                    val isSelected = drillMode == mode
                    OutlinedButton(
                        onClick = { onDrillModeChange(mode) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (isSelected) Color.Red else Color.Transparent,
                            contentColor = if (isSelected) Color.White else Color.Gray
                        ),
                        border = BorderStroke(1.dp, if (isSelected) Color.Red else Color.Gray)
                    ) {
                        Text(
                            text = modeTitles[mode] ?: mode.uppercase(),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DrillConfigurationSection(
    repeats: Int,
    onRepeatsChange: (Int) -> Unit,
    pause: Int,
    onPauseChange: (Int) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Configuration",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )

            // Repeats
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Repeats:", color = Color.White, modifier = Modifier.weight(1f))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { if (repeats > 1) onRepeatsChange(repeats - 1) }) {
                        Text("-", color = Color.Red, fontSize = 20.sp)
                    }
                    Text(repeats.toString(), color = Color.White, modifier = Modifier.padding(horizontal = 8.dp))
                    IconButton(onClick = { onRepeatsChange(repeats + 1) }) {
                        Text("+", color = Color.Red, fontSize = 20.sp)
                    }
                }
            }

            // Pause
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Pause (seconds):", color = Color.White, modifier = Modifier.weight(1f))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { if (pause > 0) onPauseChange(pause - 1) }) {
                        Text("-", color = Color.Red, fontSize = 20.sp)
                    }
                    Text(pause.toString(), color = Color.White, modifier = Modifier.padding(horizontal = 8.dp))
                    IconButton(onClick = { onPauseChange(pause + 1) }) {
                        Text("+", color = Color.Red, fontSize = 20.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun DrillTargetsSection(
    bleManager: BLEManager,
    targets: List<DrillTargetsConfigData>,
    isTargetListReceived: Boolean,
    onNavigateToTargetConfig: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = isTargetListReceived) { onNavigateToTargetConfig() }
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Shield icon
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(Color.White.copy(alpha = 0.1f), shape = androidx.compose.foundation.shape.CircleShape)
                    .border(2.dp, Color.Red, shape = androidx.compose.foundation.shape.CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Settings,
                    contentDescription = "Targets",
                    tint = Color.Red,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            // Text label
            Text(
                text = "Targets",
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.White else Color.Gray
            )

            Spacer(modifier = Modifier.weight(1f))

            // Count
            Text(
                text = "${targets.size} targets",
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.White else Color.Gray
            )

            Spacer(modifier = Modifier.weight(1f))

            // Arrow
            Text(
                text = ">",
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.Gray else Color.LightGray
            )
        }
    }
}