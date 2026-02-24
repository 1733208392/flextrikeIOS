package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.flextarget.android.ui.viewmodel.AuthViewModel
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import com.flextarget.android.ui.theme.AppButton

/**
 * Login Screen
 * 
 * Allows users to authenticate with mobile number and password.
 * Displays loading state during authentication and error messages on failure.
 */
@Composable
fun LoginScreen(
    authViewModel: AuthViewModel,
    onLoginSuccess: () -> Unit = {},
    onRegisterClick: () -> Unit = {},
    onForgotPasswordClick: () -> Unit = {},
    onBackClick: () -> Unit = {}
) {
    val authUiState by authViewModel.authUiState.collectAsState()
    
    var mobile by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    
    val customRed = Color(0xFFde3823)
    
    // Navigate on successful login
    LaunchedEffect(authUiState.isAuthenticated) {
        if (authUiState.isAuthenticated) {
            onLoginSuccess()
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top toolbar
        CenterAlignedTopAppBar(
            title = { Text("Login", color = customRed) },
            navigationIcon = {
                IconButton(onClick = onBackClick) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back",
                        tint = customRed
                    )
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = Color.Black
            )
        )
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
        // App icon
        Icon(
            imageVector = Icons.Filled.Person,
            contentDescription = stringResource(R.string.app_name),
            modifier = Modifier
                .size(120.dp)
                .padding(top = 24.dp, bottom = 48.dp),
            tint = customRed
        )
        
        // Mobile input field
        OutlinedTextField(
            value = mobile,
            onValueChange = { mobile = it },
            label = { Text(stringResource(R.string.login_account), color = Color.Gray) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = customRed,
                unfocusedBorderColor = Color.Gray,
                cursorColor = customRed
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            enabled = !authUiState.isLoading
        )
        
        // Password input field with show/hide toggle
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text(stringResource(R.string.login_password), color = Color.Gray) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 24.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = customRed,
                unfocusedBorderColor = Color.Gray,
                cursorColor = customRed
            ),
            visualTransformation = if (showPassword) {
                VisualTransformation.None
            } else {
                PasswordVisualTransformation()
            },
            trailingIcon = {
                IconButton(
                    onClick = { showPassword = !showPassword }
                ) {
                    Icon(
                        imageVector = if (showPassword) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
                        contentDescription = if (showPassword) "Hide password" else "Show password",
                        tint = Color.Gray
                    )
                }
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done
            ),
            keyboardActions = KeyboardActions(
                onDone = {
                    if (mobile.isNotEmpty() && password.isNotEmpty()) {
                        authViewModel.login(mobile, password)
                    }
                }
            ),
            singleLine = true,
            enabled = !authUiState.isLoading
        )
        
        // Error message display
        if (!authUiState.error.isNullOrEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp)
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Error,
                    contentDescription = "Error",
                    modifier = Modifier.size(24.dp),
                    tint = customRed
                )
                Text(
                    text = authUiState.error ?: "Unknown error",
                    color = customRed,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        // Login button
        AppButton(
            onClick = {
                authViewModel.login(mobile, password)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .padding(bottom = 8.dp),
            enabled = mobile.isNotEmpty() && password.isNotEmpty() && !authUiState.isLoading
        ) {
            if (authUiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    stringResource(R.string.login_button).uppercase(),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        
        // Forgot Password and Register buttons in a row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Forgot Password button
            Button(
                onClick = onForgotPasswordClick,
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent
                ),
                shape = RoundedCornerShape(8.dp),
                enabled = !authUiState.isLoading
            ) {
                Text(
                    stringResource(R.string.login_forgot_password).uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = customRed
                )
            }
            
            // Register button
            Button(
                onClick = onRegisterClick,
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent
                ),
                shape = RoundedCornerShape(8.dp),
                enabled = !authUiState.isLoading
            ) {
                Text(
                    stringResource(R.string.login_register_button).uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = customRed
                )
            }
        }

        }
    }
}

/**
 * Login Screen Preview
 */
// @androidx.compose.ui.tooling.preview.Preview(showBackground = true)
// @Composable
// fun LoginScreenPreview() {
//     MaterialTheme {
//         LoginScreen()
//     }
// }
