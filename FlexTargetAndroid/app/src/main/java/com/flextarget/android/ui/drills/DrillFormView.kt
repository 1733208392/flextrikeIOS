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
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
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

enum class DrillSessionScreen {
    NONE,
    TIMER,
    SUMMARY,
    RESULT,
    REPLAY
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
    var drillName by remember(existingDrill) { mutableStateOf(existingDrill?.name ?: "") }
    var description by remember(existingDrill) { mutableStateOf(existingDrill?.desc ?: "") }
    var drillMode by remember(existingDrill) { mutableStateOf(existingDrill?.mode ?: "ipsc") }
    var repeats by remember(existingDrill) { mutableStateOf(existingDrill?.repeats ?: 1) }
    var pause by remember(existingDrill) { mutableStateOf(existingDrill?.pause ?: 5) }
    var targets by remember { mutableStateOf<List<DrillTargetsConfigData>>(emptyList()) }
    val isTargetListReceivedDerived by derivedStateOf { bleManager.networkDevices.isNotEmpty() }
    var currentScreen by remember { mutableStateOf(DrillFormScreen.FORM) }
    var showEditDisabledAlert by remember { mutableStateOf(false) }
    var drillResultCount by remember { mutableStateOf(0) }

    var isSaving by remember { mutableStateOf(false) }

    // Check if editing is disabled (drill has results or is linked to a competition)
    val isEditingDisabled = existingDrill != null && drillResultCount > 0

    val isFormValid = drillName.isNotBlank() && bleManager.isConnected && !isEditingDisabled && isTargetListReceivedDerived

    // Query device list on appear
    LaunchedEffect(Unit) {
        queryDeviceList(bleManager)
    }

    // Load drill result count if editing existing drill
    existingDrill?.id?.let { drillId ->
        LaunchedEffect(Unit) {
            try {
                drillResultCount = viewModel.getDrillResultCount(drillId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // Observe device list updates - now handled by derivedStateOf

    // Load targets for existing drill
    existingDrill?.id?.let { drillId ->
        LaunchedEffect(Unit) {
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
            title = { Text(stringResource(R.string.error)) },
            text = { Text(bleManager.errorMessage ?: stringResource(R.string.error_unknown)) },
            confirmButton = {
                Button(
                    onClick = { bleManager.showErrorAlert = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }

    // Alert for editing disabled drills
    if (showEditDisabledAlert) {
        AlertDialog(
            onDismissRequest = { showEditDisabledAlert = false },
            title = { Text(stringResource(R.string.training_records_available)) },
            text = { Text(stringResource(R.string.changing_config_not_allowed)) },
            confirmButton = {
                Button(
                    onClick = { showEditDisabledAlert = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }

    // State for showing TimerSessionView - used to hide toolbar
    var showTimerSession by remember { mutableStateOf(false) }
    var showDrillSummary by remember { mutableStateOf(false) }

    // Drill session management state
    var timerSessionDrill by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var timerSessionTargets by remember { mutableStateOf<List<DrillTargetsConfigEntity>>(emptyList()) }
    var drillSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }
    var selectedResultSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var selectedReplaySummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    
    // Navigation state machine - only one screen can be active at a time
    var drillSessionScreen by remember { mutableStateOf(DrillSessionScreen.NONE) }

    // Callbacks without remember - recreated on each composition with fresh state references
    val onReplayCallback: (DrillRepeatSummary) -> Unit = { summary: DrillRepeatSummary ->
        println("[DrillFormView.onReplayCallback] ===START=== Callback invoked with summary ${summary.repeatIndex}, shots=${summary.shots.size}")
        try {
            println("[DrillFormView.onReplayCallback] Setting selectedReplaySummary...")
            selectedReplaySummary = summary
            println("[DrillFormView.onReplayCallback] selectedReplaySummary set to ${selectedReplaySummary?.repeatIndex}, drillSessionScreen=$drillSessionScreen")
            println("[DrillFormView.onReplayCallback] About to set drillSessionScreen to REPLAY...")
            drillSessionScreen = DrillSessionScreen.REPLAY
            println("[DrillFormView.onReplayCallback] drillSessionScreen set to $drillSessionScreen ===END===")
        } catch (e: Exception) {
            println("[DrillFormView.onReplayCallback] EXCEPTION: ${e.message}")
            e.printStackTrace()
        }
    }

    val onViewResultCallback: (DrillRepeatSummary) -> Unit = { summary: DrillRepeatSummary ->
        println("[DrillFormView.onViewResultCallback] onViewResult called with summary ${summary.repeatIndex}")
        selectedResultSummary = summary
        drillSessionScreen = DrillSessionScreen.RESULT
    }

    val onBackFromSummaryCallback: () -> Unit = {
        println("[DrillFormView.onBackFromSummaryCallback] DrillSummaryView back")
        drillSessionScreen = DrillSessionScreen.NONE
        showDrillSummary = false
    }

    val onBackFromResultCallback: () -> Unit = {
        println("[DrillFormView.onBackFromResultCallback] DrillResultView back")
        drillSessionScreen = DrillSessionScreen.SUMMARY
        selectedResultSummary = null
    }

    val onBackFromReplayCallback: () -> Unit = {
        println("[DrillFormView.onBackFromReplayCallback] DrillReplayView back pressed")
        drillSessionScreen = DrillSessionScreen.SUMMARY
        selectedReplaySummary = null
    }

    val showTopBar by remember(showTimerSession, showDrillSummary) {
        derivedStateOf { !showTimerSession && !showDrillSummary }
    }

    Scaffold(
        topBar = {
            // Only show TopAppBar when TimerSessionView or DrillSummaryView is not visible
            if (showTopBar) {
                TopAppBar(
                title = {
                    Text(
                        text = when (currentScreen) {
                            DrillFormScreen.FORM -> if (mode == DrillFormMode.ADD) stringResource(R.string.add_drill) else stringResource(R.string.edit_drill)
                            DrillFormScreen.TARGET_CONFIG -> stringResource(R.string.targets_screen)
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
                            contentDescription = stringResource(R.string.back),
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
                                contentDescription = stringResource(R.string.add_target),
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
        }
    ) { paddingValues ->
        println("[DrillFormView] Composable body rendering - drillSessionScreen=$drillSessionScreen, timerSessionDrill=${timerSessionDrill != null}, selectedReplaySummary=${selectedReplaySummary != null}")
        // Check if we're in a drill session (override normal screen selection)
        if (drillSessionScreen != DrillSessionScreen.NONE) {
            when (drillSessionScreen) {
                DrillSessionScreen.NONE -> {} // handled above
                
                DrillSessionScreen.TIMER -> {
                    if (timerSessionDrill != null && androidBleManager != null) {
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
                                drillSessionScreen = DrillSessionScreen.SUMMARY
                                showTimerSession = false
                                showDrillSummary = true
                            },
                            onDrillFailed = {
                                drillSessionScreen = DrillSessionScreen.NONE
                                showTimerSession = false
                            },
                            onBack = {
                                drillSessionScreen = DrillSessionScreen.NONE
                                showTimerSession = false
                            }
                        )
                    }
                }
                
                DrillSessionScreen.SUMMARY -> {
                    if (timerSessionDrill != null) {
                        DrillSummaryView(
                            drillSetup = timerSessionDrill!!,
                            summaries = drillSummaries,
                            onBack = onBackFromSummaryCallback,
                            onViewResult = onViewResultCallback,
                            onReplay = onReplayCallback
                        )
                    }
                }
                
                DrillSessionScreen.RESULT -> {
                    if (timerSessionDrill != null && selectedResultSummary != null) {
                        DrillResultView(
                            drillSetup = timerSessionDrill!!,
                            targets = timerSessionTargets.map { DrillTargetsConfigData.fromEntity(it) },
                            repeatSummary = selectedResultSummary,
                            onBack = onBackFromResultCallback
                        )
                    }
                }
                
                DrillSessionScreen.REPLAY -> {
                    println("[DrillFormView] REPLAY state reached - timerSessionDrill=${timerSessionDrill != null}, selectedReplaySummary=${selectedReplaySummary != null}")
                    if (timerSessionDrill != null && selectedReplaySummary != null) {
                        println("[DrillFormView] Showing DrillReplayView with ${selectedReplaySummary!!.shots.size} shots")
                        DrillReplayView(
                            drillSetup = timerSessionDrill!!,
                            shots = selectedReplaySummary!!.shots,
                            onBack = onBackFromReplayCallback
                        )
                    } else {
                        println("[DrillFormView] REPLAY screen but drill=${timerSessionDrill} or replay summary=${selectedReplaySummary}")
                    }
                }
            }
        } else {
            // Normal form view
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
                        isTargetListReceived = isTargetListReceivedDerived,
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
                        isEditingDisabled = isEditingDisabled,
                        onStartDrill = { sessionDrill, sessionTargets ->
                            timerSessionDrill = sessionDrill
                            timerSessionTargets = sessionTargets
                            drillSessionScreen = DrillSessionScreen.TIMER
                            showTimerSession = true
                        }
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
    isEditingDisabled: Boolean = false,
    onStartDrill: (DrillSetupEntity, List<DrillTargetsConfigEntity>) -> Unit = { _, _ -> }
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(paddingValues)
    ) {
        // Show form content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 70.dp),
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
                        contentDescription = stringResource(R.string.lock),
                        tint = Color(0xFFFFA500),
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        stringResource(R.string.editing_disabled_message),
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
                                        mode = drillMode,
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
                        containerColor = if (isFormValid) Color.Red else Color.Gray,
                        disabledContainerColor = Color.Gray
                    )
                ) {
                    Text(
                        text = if (isSaving) stringResource(R.string.saving) else if (mode == DrillFormMode.ADD) stringResource(R.string.save_drill) else stringResource(R.string.save_changes),
                        color = Color.White
                    )
                }

                // Start drill session
                Button(
                    onClick = {
                        coroutineScope.launch {
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

                            // Auto-save if new drill
                            if (existingDrill == null) {
                                try {
                                    viewModel.saveNewDrillWithTargets(sessionDrill, targets)
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }

                            println("[FormScreen] Starting drill - calling onStartDrill callback")
                            onStartDrill(sessionDrill, sessionTargets)
                        }
                    },
                    enabled = bleManager.isConnected && androidBleManager != null && isTargetListReceived,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (bleManager.isConnected && androidBleManager != null && isTargetListReceived) Color.Green else Color.Gray,
                        disabledContainerColor = Color.Gray
                    )
                ) {
                    Text(stringResource(R.string.start_drill), color = Color.White)
                }
            }
        }

        if (isSaving) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = Color.Red
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
                text = stringResource(R.string.drill_name),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = drillName,
                onValueChange = onDrillNameChange,
                placeholder = { Text(stringResource(R.string.enter_drill_name), color = Color.Gray) },
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
                text = stringResource(R.string.description),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = description,
                onValueChange = onDescriptionChange,
                placeholder = { Text(stringResource(R.string.enter_drill_description), color = Color.Gray) },
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
        "ipsc" to stringResource(R.string.ipsc),
        "idpa" to stringResource(R.string.idpa),
        "cqb" to stringResource(R.string.cqb)
    )

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = stringResource(R.string.drill_mode),
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
                text = stringResource(R.string.configuration),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )

            // Repeats
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(stringResource(R.string.repeats), color = Color.White, modifier = Modifier.weight(1f))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { if (repeats > 1) onRepeatsChange(repeats - 1) }) {
                        Text(stringResource(R.string.minus), color = Color.Red, fontSize = 20.sp)
                    }
                    Text(repeats.toString(), color = Color.White, modifier = Modifier.padding(horizontal = 8.dp))
                    IconButton(onClick = { onRepeatsChange(repeats + 1) }) {
                        Text(stringResource(R.string.plus), color = Color.Red, fontSize = 20.sp)
                    }
                }
            }

            // Pause
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(stringResource(R.string.pause_seconds), color = Color.White, modifier = Modifier.weight(1f))
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
                    contentDescription = stringResource(R.string.targets_section),
                    tint = Color.Red,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            // Text label
            Text(
                text = stringResource(R.string.targets_section),
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.White else Color.Gray
            )

            Spacer(modifier = Modifier.weight(1f))

            // Count
            Text(
                text = stringResource(R.string.targets_count, targets.size),
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.White else Color.Gray
            )

            Spacer(modifier = Modifier.weight(1f))

            // Arrow
            Text(
                text = stringResource(R.string.arrow_right),
                style = MaterialTheme.typography.titleMedium,
                color = if (isTargetListReceived) Color.Gray else Color.LightGray
            )
        }
    }
}