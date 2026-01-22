package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.platform.LocalContext
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.FlexTargetDatabase
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillSetupWithTargets
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.DrillFormViewModel
import com.flextarget.android.ui.viewmodel.DrillListViewModel
import kotlinx.coroutines.launch
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillListView(
    bleManager: BLEManager,
    onBack: (() -> Unit)? = null,
    onShowConnectView: () -> Unit = {},
    onShowQRScanner: () -> Unit = {}
) {
    val context = LocalContext.current
    val viewModel: DrillListViewModel = viewModel(
        factory = com.flextarget.android.ui.viewmodel.DrillListViewModel.Factory(
            DrillSetupRepository.getInstance(LocalContext.current)
        )
    )
    val coroutineScope = rememberCoroutineScope()
    var searchQuery by remember { mutableStateOf("") }
    var showDeleteDialog by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var showConnectionAlert by remember { mutableStateOf(false) }
    var showDrillForm by remember { mutableStateOf(false) }
    var drillFormMode by remember { mutableStateOf(DrillFormMode.ADD) }
    var selectedDrill by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var showDrillRecord by remember { mutableStateOf(false) }
    var selectedDrillForRecord by remember { mutableStateOf<DrillSetupEntity?>(null) }

    val showTopBar by remember(showDrillForm, showDrillRecord) {
        derivedStateOf { !showDrillForm && !showDrillRecord }
    }

    val drillSetups by viewModel.drillSetups.collectAsState(initial = emptyList())

    val filteredDrills = remember(drillSetups, searchQuery) {
        if (searchQuery.isEmpty()) {
            drillSetups
        } else {
            drillSetups.filter { drill ->
                drill.drillSetup.name?.contains(searchQuery, ignoreCase = true) == true
            }
        }
    }

    Scaffold(
        topBar = {
            // Only show TopAppBar when DrillForm or DrillRecord is not visible
            if (showTopBar) {
                TopAppBar(
                    title = {
                        Text(if (onBack != null) stringResource(R.string.my_drills) else stringResource(R.string.drills), color = Color.White)
                    },
                    navigationIcon = {
                        if (onBack != null) {
                            IconButton(onClick = onBack) {
                                Icon(
                                    Icons.Default.ArrowBack,
                                    contentDescription = stringResource(R.string.back),
                                    tint = Color.Red
                                )
                            }
                        } else {
                            // iOS-like connection status pill
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .padding(start = 16.dp)
                                    .background(Color.Gray.copy(alpha = 0.2f), androidx.compose.foundation.shape.RoundedCornerShape(16.dp))
                                    .padding(vertical = 4.dp, horizontal = 12.dp)
                                    .clickable {
                                        if (bleManager.isConnected) {
                                            onShowConnectView()
                                        } else {
                                            onShowQRScanner()
                                        }
                                    }
                            ) {
                                Text(
                                    text = if (bleManager.isConnected) stringResource(R.string.device_connected) else stringResource(R.string.device_disconnected),
                                    color = Color.Gray,
                                    fontSize = 12.sp
                                )
                                if (bleManager.isConnected) {
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = bleManager.connectedPeripheralName ?: "Target",
                                        color = Color.White,
                                        fontSize = 12.sp
                                    )
                                }
                            }
                        }
                    },
                    actions = {
                        if (bleManager.isConnected) {
                            IconButton(onClick = {
                                drillFormMode = DrillFormMode.ADD
                                selectedDrill = null
                                showDrillForm = true
                            }) {
                                Icon(
                                    Icons.Default.Add,
                                    contentDescription = "Add Drill",
                                    tint = Color.Red
                                )
                            }
                        } else {
                            IconButton(onClick = { showConnectionAlert = true }) {
                                Icon(
                                    Icons.Default.Add,
                                    contentDescription = "Add Drill (Disabled)",
                                    tint = Color.Gray
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
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Search bar
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text(stringResource(R.string.search_drills), color = Color.Gray) },
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = "Search", tint = Color.Gray)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Red,
                        unfocusedBorderColor = Color.Gray,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        cursorColor = Color.Red
                    )
                )

                // Drill list
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp)
                ) {
                    items(filteredDrills) { drillWithTargets ->
                        // Inline drill row
                        val drillWithTargetsItem = drillWithTargets
                        var showMenu by remember { mutableStateOf(false) }

                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(onClick = {
                                    drillFormMode = DrillFormMode.EDIT
                                    selectedDrill = drillWithTargetsItem.drillSetup
                                    showDrillForm = true
                                })
                                .padding(vertical = 12.dp, horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Status indicator
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .background(Color.Gray, CircleShape)
                            )

                            Spacer(modifier = Modifier.width(12.dp))

                            // Drill info
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = drillWithTargetsItem.drillSetup.name ?: stringResource(R.string.untitled),
                                    color = Color.White,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold
                                )

                                // Inline drill info
                                val drill = drillWithTargetsItem.drillSetup
                                val targetCount = drillWithTargetsItem.targets.size

                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "$targetCount targets",
                                        color = Color.Gray,
                                        fontSize = 12.sp
                                    )

                                    if (drill.repeats > 1) {
                                        Text(
                                            text = "Repeats: ${drill.repeats}",
                                            color = Color.Gray,
                                            fontSize = 12.sp
                                        )
                                    }

                                    if (drill.pause > 0) {
                                        Text(
                                            text = "Pause: ${drill.pause}s",
                                            color = Color.Gray,
                                            fontSize = 12.sp
                                        )
                                    }

                                    if (drill.delay > 0) {
                                        Text(
                                            text = "Delay: ${drill.delay.toInt()}s",
                                            color = Color.Gray,
                                            fontSize = 12.sp
                                        )
                                    }

                                    drill.mode?.let { mode ->
                                        val modeDisplay = when (mode.lowercase()) {
                                            "ipsc" -> "IPSC"
                                            "idpa" -> "IDPA"
                                            "cqb" -> "CQB"
                                            else -> mode.uppercase()
                                        }
                                        Text(
                                            text = modeDisplay,
                                            color = Color.Red,
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium
                                        )
                                    }
                                }
                            }

                            // Menu button
                            Box {
                                IconButton(onClick = { showMenu = true }) {
                                    Icon(
                                        Icons.Default.MoreVert,
                                        contentDescription = "Menu",
                                        tint = Color.Gray
                                    )
                                }

                                DropdownMenu(
                                    expanded = showMenu,
                                    onDismissRequest = { showMenu = false }
                                ) {
                                    DropdownMenuItem(
                                        text = { Text(stringResource(R.string.copy)) },
                                        onClick = {
                                            coroutineScope.launch {
                                                viewModel.copyDrill(drillWithTargetsItem.drillSetup)
                                            }
                                            showMenu = false
                                        },
                                        leadingIcon = {
                                            Icon(Icons.Default.Add, contentDescription = "Copy")
                                        }
                                    )
                                    DropdownMenuItem(
                                        text = { Text(stringResource(R.string.delete), color = Color.Red) },
                                        onClick = {
                                            showDeleteDialog = drillWithTargetsItem.drillSetup
                                            showMenu = false
                                        },
                                        leadingIcon = {
                                            Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.Red)
                                        }
                                    )
                                }
                            }

                            // Chevron
                            Icon(
                                Icons.Default.ArrowForward,
                                contentDescription = "Navigate",
                                tint = Color.Gray
                            )
                        }
                    }
                }
            }
        }
    }

    // Delete confirmation dialog
    showDeleteDialog?.let { drill ->
        AlertDialog(
            onDismissRequest = { showDeleteDialog = null },
            title = { Text(stringResource(R.string.delete_drill)) },
            text = { Text(stringResource(R.string.are_you_sure_delete, drill.name ?: stringResource(R.string.untitled))) },
            confirmButton = {
                TextButton(
                    onClick = {
                        coroutineScope.launch {
                            viewModel.deleteDrill(drill)
                            showDeleteDialog = null
                        }
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color.Red)
                ) {
                    Text(stringResource(R.string.delete))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = null }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }

    // Connection required alert
    if (showConnectionAlert) {
        AlertDialog(
            onDismissRequest = { showConnectionAlert = false },
            title = { Text(stringResource(R.string.connection_required)) },
            text = { Text(stringResource(R.string.connection_required_message)) },
            confirmButton = {
                TextButton(onClick = { showConnectionAlert = false }) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }

    // Drill Form
    if (showDrillForm) {
        DrillFormView(
            bleManager = bleManager,
            mode = drillFormMode,
            existingDrill = selectedDrill,
            onBack = { showDrillForm = false },
            onDrillSaved = { savedDrill ->
                // Refresh the list or handle the saved drill
                showDrillForm = false
            },
            viewModel = viewModel(
                factory = com.flextarget.android.ui.viewmodel.DrillFormViewModel.Factory(
                    DrillSetupRepository.getInstance(LocalContext.current)
                )
            )
        )
    }

    // Drill Record
    if (showDrillRecord && selectedDrillForRecord != null) {
        DrillRecordView(
            drillSetup = selectedDrillForRecord!!,
            onBack = { showDrillRecord = false }
        )
    }


}