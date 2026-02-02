package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
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
import com.flextarget.android.ui.viewmodel.AuthViewModel
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import kotlinx.coroutines.delay

/**
 * Email Registration Screen
 *
 * Allows users to register with email, password, and verification code.
 * Flow:
 * 1. User enters email and requests verification code
 * 2. System sends code to email
 * 3. User enters password and code
 * 4. Registration succeeds and auto-logs in the user
 */
@Composable
fun RegistrationScreen(
    authViewModel: AuthViewModel,
    onRegistrationSuccess: () -> Unit = {},
    onBackClick: () -> Unit = {}
) {
    val authUiState by authViewModel.authUiState.collectAsState()
    
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var verifyCode by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var codeSent by remember { mutableStateOf(false) }
    var codeCountdown by remember { mutableStateOf(0) }
    var showSendCodeError by remember { mutableStateOf(false) }
    var sendCodeErrorMessage by remember { mutableStateOf("") }
    
    // Email validation regex
    val emailRegex = remember { Regex("""^[A-Za-z0-9+_.-]+@(.+)$""") }
    val isEmailValid = email.isNotEmpty() && emailRegex.matches(email)
    val isPasswordValid = password.length >= 6
    val isVerifyCodeValid = verifyCode.length == 6 && verifyCode.all { it.isDigit() }
    
    // Navigate on successful registration
    LaunchedEffect(authUiState.isAuthenticated) {
        if (authUiState.isAuthenticated) {
            onRegistrationSuccess()
        }
    }
    
    // Handle countdown timer for code resend
    LaunchedEffect(codeCountdown) {
        if (codeCountdown > 0) {
            delay(1000)
            codeCountdown--
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
            .padding(top = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Back button and title
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 32.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(
                onClick = onBackClick,
                colors = ButtonDefaults.textButtonColors(),
                modifier = Modifier.wrapContentSize()
            ) {
                Text(
                    stringResource(R.string.registration_back),
                    color = Color.Red,
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                stringResource(R.string.registration_title),
                style = MaterialTheme.typography.displaySmall,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 16.dp)
            )
        }
        
        // Email input field
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text(stringResource(R.string.registration_email), color = Color.Gray) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = Color.Red,
                unfocusedBorderColor = Color.Gray,
                cursorColor = Color.Red
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            enabled = !authUiState.isLoading && !codeSent
        )
        
        // Email error message
        if (email.isNotEmpty() && !isEmailValid) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Error,
                    contentDescription = "Error",
                    modifier = Modifier.size(16.dp),
                    tint = Color.Red
                )
                Text(
                    stringResource(R.string.registration_email_invalid),
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        // Send verification code button
        Button(
            onClick = {
                authViewModel.sendVerifyCode(email)
                codeSent = true
                codeCountdown = 60
                showSendCodeError = false
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(bottom = 20.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Red,
                disabledContainerColor = Color.Red.copy(alpha = 0.5f)
            ),
            shape = RoundedCornerShape(8.dp),
            enabled = isEmailValid && !authUiState.isLoading && codeCountdown == 0 && !codeSent
        ) {
            if (authUiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    if (codeCountdown > 0) {
                        stringResource(R.string.registration_resend_code, codeCountdown)
                    } else {
                        stringResource(R.string.registration_send_code)
                    },
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        
        // Send code error message
        if (showSendCodeError) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Error,
                    contentDescription = "Error",
                    modifier = Modifier.size(16.dp),
                    tint = Color.Red
                )
                Text(
                    sendCodeErrorMessage,
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        Divider(color = Color.Gray.copy(alpha = 0.3f), thickness = 1.dp, modifier = Modifier.padding(vertical = 20.dp))
        
        // Verification code input field (6 digits only)
        OutlinedTextField(
            value = verifyCode,
            onValueChange = { newValue ->
                // Allow only digits, max 6
                if (newValue.all { it.isDigit() } && newValue.length <= 6) {
                    verifyCode = newValue
                }
            },
            label = { Text(stringResource(R.string.registration_verify_code), color = Color.Gray) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = Color.Red,
                unfocusedBorderColor = Color.Gray,
                cursorColor = Color.Red
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Number,
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            enabled = !authUiState.isLoading && codeSent,
            placeholder = { Text("000000", color = Color.Gray) }
        )
        
        // Password input field with show/hide toggle
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text(stringResource(R.string.registration_password), color = Color.Gray) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = Color.Red,
                unfocusedBorderColor = Color.Gray,
                cursorColor = Color.Red
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
            enabled = !authUiState.isLoading && codeSent
        )
        
        // Password error message
        if (password.isNotEmpty() && !isPasswordValid) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Error,
                    contentDescription = "Error",
                    modifier = Modifier.size(16.dp),
                    tint = Color.Red
                )
                Text(
                    stringResource(R.string.registration_password_invalid),
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        // General error message display
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
                    tint = Color.Red
                )
                Text(
                    text = authUiState.error ?: "Unknown error",
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
        // Register button
        Button(
            onClick = {
                authViewModel.registerWithEmail(email, password, verifyCode)
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
            enabled = isEmailValid && isPasswordValid && isVerifyCodeValid && !authUiState.isLoading && codeSent
        ) {
            if (authUiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    stringResource(R.string.registration_register_button),
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
    }
}
