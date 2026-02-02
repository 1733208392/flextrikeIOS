import SwiftUI

struct RegistrationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared
    
    let onDismiss: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var verifyCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var codeSent = false
    @State private var codeCountdown = 0
    @State private var showPasswordField = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with back button
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text(NSLocalizedString("registration_back", comment: "Back button"))
                    }
                    .foregroundColor(.red)
                }
                Spacer()
                Text(NSLocalizedString("registration_title", comment: "Registration title"))
                    .font(.title)
                    .foregroundColor(.white)
                Spacer()
                // Placeholder to balance layout
                Color.clear.frame(width: 60)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Email input field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("registration_email", comment: "Email label"))
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        TextField(NSLocalizedString("registration_email", comment: "Email placeholder"), text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(isLoading || codeSent)
                        
                        if !email.isEmpty && !isValidEmail(email) {
                            Text(NSLocalizedString("registration_email_invalid", comment: "Invalid email error"))
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Send verification code button
                    Button(action: sendVerificationCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(codeCountdown > 0 ? String(format: NSLocalizedString("registration_resend_code", comment: "Resend code"), codeCountdown) : NSLocalizedString("registration_send_code", comment: "Send code button"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || !isValidEmail(email) || codeCountdown > 0 || codeSent && codeCountdown > 0)
                    
                    if showError && !codeSent {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Verification code input (6 digits only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("registration_verify_code", comment: "Verify code label"))
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        TextField("000000", text: $verifyCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .disabled(isLoading || !codeSent)
                            .onChange(of: verifyCode) { newValue in
                                // Allow only digits, max 6
                                if newValue.allSatisfy({ $0.isNumber }) && newValue.count <= 6 {
                                    verifyCode = newValue
                                } else {
                                    verifyCode = String(newValue.filter { $0.isNumber }.prefix(6))
                                }
                                // Show password field once code is entered
                                if verifyCode.count == 6 {
                                    showPasswordField = true
                                }
                            }
                    }
                    
                    // Password input field (shown after code entry)
                    if showPasswordField {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("registration_password", comment: "Password label"))
                                .foregroundColor(.gray)
                                .font(.caption)
                            
                            SecureField(NSLocalizedString("registration_password", comment: "Password placeholder"), text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLoading)
                            
                            if !password.isEmpty && password.count < 6 {
                                Text(NSLocalizedString("registration_password_invalid", comment: "Invalid password error"))
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    if showError && codeSent {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Register button
                    Button(action: registerUser) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(NSLocalizedString("registration_register_button", comment: "Register button"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || !isValidEmail(email) || verifyCode.count != 6 || password.count < 6 || !codeSent)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            showError = false
            errorMessage = ""
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if codeCountdown > 0 {
                codeCountdown -= 1
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Za-z0-9+_.-]+@(.+)$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func sendVerificationCode() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                try await authManager.sendVerifyCode(email: email)
                await MainActor.run {
                    codeSent = true
                    codeCountdown = 60
                    isLoading = false
                    print("[RegistrationView] Verification code sent to: \(email)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    print("[RegistrationView] Failed to send verification code: \(error)")
                }
            }
        }
    }
    
    private func registerUser() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                let loginData = try await AuthManager.shared.register(email: email, password: password, verifyCode: verifyCode)
                
                // Fetch user info and update username if available
                do {
                    let userGetData = try await UserAPIService.shared.getUser(accessToken: loginData.access_token)
                    authManager.updateUserInfo(username: userGetData.username)
                    print("[RegistrationView] User info fetched after registration: \(userGetData.username)")
                } catch {
                    print("[RegistrationView] Failed to fetch user info after registration: \(error)")
                    // Continue even if user info fetch fails
                }
                
                await MainActor.run {
                    isLoading = false
                    print("[RegistrationView] Registration and login successful")
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    print("[RegistrationView] Registration failed: \(error)")
                }
            }
        }
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView(onDismiss: {})
    }
}
