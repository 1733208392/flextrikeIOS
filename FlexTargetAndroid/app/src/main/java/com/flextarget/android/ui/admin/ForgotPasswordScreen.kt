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
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
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
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flextarget.android.R
import com.flextarget.android.data.remote.api.*
import com.flextarget.android.di.AppContainer
import kotlinx.coroutines.launch

/**
 * Forgot Password Screen
 * 
 * Allows users to reset their password using email and verification code.
 * Two-step flow:
 * 1. Enter email and request verification code
 * 2. Enter verification code and new password, then reset
 */
@Composable
fun ForgotPasswordScreen(
    onResetSuccess: () -> Unit = {},
    onBackClick: () -> Unit = {}
) {
    val redColor = Color(0xFFDE3823)
    
    var email by remember { mutableStateOf("") }
    var newPassword by remember { mutableStateOf("") }
    var verifyCode by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var codeVerifySent by remember { mutableStateOf(false) }
    
    val scope = rememberCoroutineScope()
    
    val isResetButtonEnabled = codeVerifySent && verifyCode.isNotEmpty() && newPassword.length >= 6
    
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.reset_password), color = redColor, style = MaterialTheme.typography.titleSmall) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = redColor)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Black,
                    titleContentColor = redColor
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(top = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
        // Title icon and text
        Icon(
            imageVector = Icons.Default.Key,
            contentDescription = "Reset Password",
            modifier = Modifier
                .size(64.dp)
                .padding(bottom = 24.dp),
            tint = redColor
        )
        
        // Email input field
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text(stringResource(R.string.login_email), color = Color.Gray, style = MaterialTheme.typography.bodyMedium) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = redColor,
                unfocusedBorderColor = Color.Gray,
                cursorColor = redColor
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            enabled = !isLoading
        )
        
        // Verification code input field
        OutlinedTextField(
            value = verifyCode,
            onValueChange = { verifyCode = it },
            label = { Text(stringResource(R.string.verify_code), color = Color.Gray, style = MaterialTheme.typography.bodyMedium) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = redColor,
                unfocusedBorderColor = Color.Gray,
                cursorColor = redColor
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Number,
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            enabled = codeVerifySent && !isLoading
        )
        
        // New password input field with show/hide toggle
        OutlinedTextField(
            value = newPassword,
            onValueChange = { newPassword = it },
            label = { Text(stringResource(R.string.new_password), color = Color.Gray, style = MaterialTheme.typography.bodyMedium) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 24.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = redColor,
                unfocusedBorderColor = Color.Gray,
                cursorColor = redColor
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
            singleLine = true,
            enabled = codeVerifySent && !isLoading
        )
        
        // Error message display
        if (errorMessage != null) {
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
                    tint = Color.Red
                )
                Text(
                    text = errorMessage ?: "Unknown error",
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        // Send Verify Code Button (Step 1)
        if (!codeVerifySent) {
            Button(
                onClick = {
                    scope.launch {
                        isLoading = true
                        errorMessage = null
                        try {
                            val request = SendResetPasswordVerifyCodeRequest(email = email)
                            val response = AppContainer.flexTargetAPI.sendResetPasswordVerifyCode(request)
                            if (response.code == 0) {
                                codeVerifySent = true
                            } else {
                                errorMessage = response.msg
                            }
                        } catch (e: Exception) {
                            errorMessage = e.message ?: "Failed to send verification code"
                        }
                        isLoading = false
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(bottom = 8.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Red,
                    disabledContainerColor = Color.Red.copy(alpha = 0.5f)
                ),
                shape = RoundedCornerShape(8.dp),
                enabled = email.isNotEmpty() && !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        stringResource(R.string.send_code),
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        } else {
            // Reset Password Button (Step 2)
            Button(
                onClick = {
                    scope.launch {
                        isLoading = true
                        errorMessage = null
                        try {
                            val request = ResetPasswordRequest(
                                email = email,
                                password = encodeBase64(newPassword),
                                verify_code = verifyCode
                            )
                            val response = AppContainer.flexTargetAPI.resetPassword(request)
                            if (response.code == 0) {
                                // Password reset successful
                                // Redirect to login - user will login with new password
                                onResetSuccess()
                            } else {
                                errorMessage = response.msg
                            }
                        } catch (e: Exception) {
                            errorMessage = e.message ?: "Failed to reset password"
                        }
                        isLoading = false
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(bottom = 8.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Red,
                    disabledContainerColor = Color.Red.copy(alpha = 0.5f)
                ),
                shape = RoundedCornerShape(8.dp),
                enabled = isResetButtonEnabled && !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        stringResource(R.string.reset_password_button),
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.weight(1f))
    }
    }
}

/**
 * Helper function to encode password to Base64 without padding
 */
private fun encodeBase64(password: String): String {
    val encoded = android.util.Base64.encodeToString(
        password.toByteArray(Charsets.UTF_8),
        android.util.Base64.NO_WRAP
    )
    // Remove padding
    return encoded.trimEnd('=')
}
