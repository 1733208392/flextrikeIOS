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

@Composable
fun UserProfileView(onBack: () -> Unit) {
    val selectedTab = remember { mutableStateOf(0) }
    val username = remember { mutableStateOf("") }
    val oldPassword = remember { mutableStateOf("") }
    val newPassword = remember { mutableStateOf("") }
    val confirmPassword = remember { mutableStateOf("") }
    val showLogoutConfirm = remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        TopAppBar(
            title = { Text("User Profile", color = Color.White) },
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
                        "Edit Profile",
                        color = if (selectedTab.value == 0) Color.Red else Color.Gray
                    )
                }
            )
            Tab(
                selected = selectedTab.value == 1,
                onClick = { selectedTab.value = 1 },
                text = {
                    Text(
                        "Change Password",
                        color = if (selectedTab.value == 1) Color.Red else Color.Gray
                    )
                }
            )
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (selectedTab.value == 0) {
                // Edit Profile Tab
                item {
                    Text(
                        "Edit Profile",
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
                        label = { Text("Username", color = Color.Gray) },
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
                        singleLine = true
                    )
                }

                item {
                    Button(
                        onClick = { /* TODO: Update profile */ },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.Red
                        ),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Update Profile", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            } else {
                // Change Password Tab
                item {
                    Text(
                        "Change Password",
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
                        label = "Old Password"
                    )
                }

                item {
                    PasswordField(
                        value = newPassword.value,
                        onValueChange = { newPassword.value = it },
                        label = "New Password"
                    )
                }

                item {
                    PasswordField(
                        value = confirmPassword.value,
                        onValueChange = { confirmPassword.value = it },
                        label = "Confirm Password"
                    )
                }

                item {
                    Button(
                        onClick = { /* TODO: Change password */ },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.Red
                        ),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Change Password", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Logout Button
        Button(
            onClick = { showLogoutConfirm.value = true },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Red.copy(alpha = 0.8f)
            ),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text("Logout", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }

    // Logout Confirmation Dialog
    if (showLogoutConfirm.value) {
        AlertDialog(
            onDismissRequest = { showLogoutConfirm.value = false },
            title = { Text("Logout", color = Color.White) },
            text = { Text("Are you sure you want to logout?", color = Color.White) },
            confirmButton = {
                Button(
                    onClick = {
                        // TODO: Perform logout
                        showLogoutConfirm.value = false
                        onBack()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text("Logout", color = Color.White)
                }
            },
            dismissButton = {
                Button(
                    onClick = { showLogoutConfirm.value = false },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Gray)
                ) {
                    Text("Cancel", color = Color.White)
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
    label: String
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
