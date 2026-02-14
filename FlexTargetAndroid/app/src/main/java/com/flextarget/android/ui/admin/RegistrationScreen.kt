package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PersonAdd
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
    
    val customRed = Color(0xFFDE3823)

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
    
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.registration_title), color = customRed, style = MaterialTheme.typography.titleMedium) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back", tint = customRed)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Black,
                    titleContentColor = customRed
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
                imageVector = Icons.Filled.PersonAdd,
                contentDescription = "Register",
                modifier = Modifier
                    .size(64.dp)
                    .padding(bottom = 24.dp),
                tint = customRed
            )
        
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
                    tint = customRed
                )
                Text(
                    stringResource(R.string.registration_email_invalid),
                    color = customRed,
                    style = MaterialTheme.typography.bodySmall
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
                    tint = customRed
                )
                Text(
                    sendCodeErrorMessage,
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
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
                focusedBorderColor = customRed,
                unfocusedBorderColor = Color.Gray,
                cursorColor = customRed
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
        
        // Combined button
        Button(
            onClick = {
                if (!codeSent) {
                    authViewModel.sendVerifyCode(email)
                    codeSent = true
                    codeCountdown = 60
                    showSendCodeError = false
                } else {
                    authViewModel.registerWithEmail(email, password, verifyCode)
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .padding(bottom = 8.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = customRed,
                disabledContainerColor = customRed.copy(alpha = 0.5f)
            ),
            shape = RoundedCornerShape(8.dp),
            enabled = if (!codeSent) {
                isEmailValid && !authUiState.isLoading && codeCountdown == 0
            } else {
                isEmailValid && isPasswordValid && isVerifyCodeValid && !authUiState.isLoading
            }
        ) {
            if (authUiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    if (!codeSent) {
                        if (codeCountdown > 0) {
                            stringResource(R.string.registration_resend_code, codeCountdown)
                        } else {
                            stringResource(R.string.registration_send_code)
                        }
                    } else {
                        stringResource(R.string.registration_register_button)
                    },
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
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
                    tint = customRed
                )
                Text(
                    text = authUiState.error ?: "Unknown error",
                    color = customRed,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}
