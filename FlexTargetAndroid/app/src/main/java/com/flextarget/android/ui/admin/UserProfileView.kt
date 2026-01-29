package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.flextarget.android.ui.viewmodel.AuthViewModel
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R

@Composable
fun UserProfileView(
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    onLogout: () -> Unit = {}
) {
    val authUiState by authViewModel.authUiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    
    val selectedTab = remember { mutableStateOf(0) }
    val username = remember { mutableStateOf(authUiState.userName ?: "") }
    val oldPassword = remember { mutableStateOf("") }
    val newPassword = remember { mutableStateOf("") }
    val confirmPassword = remember { mutableStateOf("") }
    val showLogoutConfirm = remember { mutableStateOf(false) }

    // Update username when it changes in authUiState (e.g. after refresh or update succeed)
    LaunchedEffect(authUiState.userName) {
        if (authUiState.userName != null) {
            username.value = authUiState.userName!!
        }
    }
    
    // Handle auto-logout on 401 error (token expired)
    LaunchedEffect(authUiState.isAuthenticated) {
        if (!authUiState.isAuthenticated) {
            // User has been logged out (likely due to 401 token expiration)
            onLogout()
        }
    }

    // Handle messages and errors
    LaunchedEffect(authUiState.message, authUiState.error) {
        authUiState.message?.let {
            snackbarHostState.showSnackbar(it)
            authViewModel.clearStatus()
        }
        authUiState.error?.let {
            snackbarHostState.showSnackbar(it)
            authViewModel.clearStatus()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            TopAppBar(
                title = { Text(stringResource(R.string.user_profile), color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.Red)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black,
                    titleContentColor = Color.White
                )
            )

            // Tab Selector
            TabRow(
                selectedTabIndex = selectedTab.value,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Black),
                containerColor = Color.Black,
                contentColor = Color.Red
            ) {
                Tab(
                    selected = selectedTab.value == 0,
                    onClick = { selectedTab.value = 0 },
                    text = {
                        Text(
                            stringResource(R.string.update_profile),
                            color = if (selectedTab.value == 0) Color.Red else Color.Gray
                        )
                    }
                )
                Tab(
                    selected = selectedTab.value == 1,
                    onClick = { selectedTab.value = 1 },
                    text = {
                        Text(
                            stringResource(R.string.change_password),
                            color = if (selectedTab.value == 1) Color.Red else Color.Gray
                        )
                    }
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            ) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    if (selectedTab.value == 0) {
                        // Edit Profile Tab
                        item {
                            Text(
                                stringResource(R.string.update_profile),
                                color = Color.White,
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(bottom = 8.dp)
                            )
                        }

                        item {
                            OutlinedTextField(
                                value = username.value,
                                onValueChange = { username.value = it },
                                label = { Text(stringResource(R.string.username), color = Color.Gray) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(
                                        color = Color.White.copy(alpha = 0.05f),
                                        shape = RoundedCornerShape(8.dp)
                                    ),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedBorderColor = Color.Red,
                                    unfocusedBorderColor = Color.Gray
                                ),
                                singleLine = true,
                                enabled = !authUiState.isLoading
                            )
                        }

                        item {
                            Button(
                                onClick = { 
                                    when {
                                        username.value.isBlank() -> {
                                            authViewModel.setShowError("Username cannot be empty")
                                        }
                                        username.value.length <= 5 -> {
                                            authViewModel.setShowError("Username must be longer than 5 characters")
                                        }
                                        username.value == authUiState.userName -> {
                                            authViewModel.setShowError("New username must be different from current one")
                                        }
                                        else -> {
                                            authViewModel.updateProfile(username.value)
                                        }
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !authUiState.isLoading,
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color.Red
                                ),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(stringResource(R.string.update_profile), color = Color.White, fontWeight = FontWeight.Bold)
                            }
                        }
                    } else {
                        // Change Password Tab
                        item {
                            Text(
                                stringResource(R.string.change_password),
                                color = Color.White,
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(bottom = 8.dp)
                            )
                        }

                        item {
                            PasswordField(
                                value = oldPassword.value,
                                onValueChange = { oldPassword.value = it },
                                label = "Old Password",
                                enabled = !authUiState.isLoading
                            )
                        }

                        item {
                            PasswordField(
                                value = newPassword.value,
                                onValueChange = { newPassword.value = it },
                                label = "New Password",
                                enabled = !authUiState.isLoading
                            )
                        }

                        item {
                            PasswordField(
                                value = confirmPassword.value,
                                onValueChange = { confirmPassword.value = it },
                                label = "Confirm Password",
                                enabled = !authUiState.isLoading
                            )
                        }

                        item {
                            Button(
                                onClick = { 
                                    when {
                                        oldPassword.value.isEmpty() || newPassword.value.isEmpty() || confirmPassword.value.isEmpty() -> {
                                            authViewModel.setShowMessage("Please fill in all fields")
                                        }
                                        newPassword.value != confirmPassword.value -> {
                                            authViewModel.setShowMessage("Passwords do not match")
                                        }
                                        newPassword.value.length < 6 -> {
                                            authViewModel.setShowMessage("Password must be at least 6 characters")
                                        }
                                        else -> {
                                            authViewModel.changePassword(oldPassword.value, newPassword.value)
                                            oldPassword.value = ""
                                            newPassword.value = ""
                                            confirmPassword.value = ""
                                        }
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !authUiState.isLoading,
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color.Red
                                ),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(stringResource(R.string.change_password), color = Color.White, fontWeight = FontWeight.Bold)
                            }
                        }
                    }

                    // Logout Button - as last item in LazyColumn
                    item {
                        Button(
                            onClick = { showLogoutConfirm.value = true },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp),
                            enabled = !authUiState.isLoading,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.Red.copy(alpha = 0.8f)
                            ),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(stringResource(R.string.logout), color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // Loading Overlay
        if (authUiState.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.5f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color.Red)
            }
        }

        // Snackbar for feedback
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }

    // Logout Confirmation Dialog
    if (showLogoutConfirm.value) {
        AlertDialog(
            onDismissRequest = { showLogoutConfirm.value = false },
            title = { Text(stringResource(R.string.logout), color = Color.White) },
            text = { Text(stringResource(R.string.logout_confirm), color = Color.White) },
            confirmButton = {
                Button(
                    onClick = {
                        authViewModel.logout()
                        showLogoutConfirm.value = false
                        onBack()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text(stringResource(R.string.logout), color = Color.White)
                }
            },
            dismissButton = {
                Button(
                    onClick = { showLogoutConfirm.value = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Gray)
                ) {
                    Text(stringResource(R.string.cancel), color = Color.White)
                }
            },
            containerColor = Color.Black,
            textContentColor = Color.White
        )
    }
}

@Composable
private fun PasswordField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    enabled: Boolean = true
) {
    val showPassword = remember { mutableStateOf(false) }

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label, color = Color.Gray) },
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color.White.copy(alpha = 0.05f),
                shape = RoundedCornerShape(8.dp)
            ),
        enabled = enabled,
        visualTransformation = if (showPassword.value) {
            VisualTransformation.None
        } else {
            PasswordVisualTransformation()
        },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = {
            IconButton(
                onClick = { showPassword.value = !showPassword.value },
                modifier = Modifier.size(20.dp)
            ) {
                Icon(
                    imageVector = if (showPassword.value) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                    contentDescription = null,
                    tint = Color.Gray,
                    modifier = Modifier.size(20.dp)
                )
            }
        },
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = Color.Red,
            unfocusedBorderColor = Color.Gray
        ),
        singleLine = true
    )
}
