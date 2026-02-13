import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared
    
    let onDismiss: () -> Void
    
    @State private var email = ""
    @State private var newPassword = ""
    @State private var verifyCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var codeVerifySent = false
    @State private var showPassword = false
    
    var isResetButtonEnabled: Bool {
        codeVerifySent && verifyCode.count > 0 && newPassword.count >= 6
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.circle")
                .font(.system(size: 64))
                .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            
            Text(NSLocalizedString("reset_password", comment: "Reset password title"))
                .font(.title)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                // Email input field
                TextField(NSLocalizedString("email", comment: "Email placeholder"), text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .disabled(codeVerifySent || isLoading)
                
                // Verify code input field
                TextField(NSLocalizedString("verify_code", comment: "Verify code placeholder"), text: $verifyCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .disabled(isLoading)
                
                // New password input field with show/hide toggle
                HStack {
                    if showPassword {
                        TextField(NSLocalizedString("new_password", comment: "New password placeholder"), text: $newPassword)


                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField(NSLocalizedString("new_password", comment: "New password placeholder"), text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                .disabled(isLoading)
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        .font(.caption)
                }
                
                // Send Verify Code Button (Step 1)
                if !codeVerifySent {
                    Button(action: sendVerifyCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(NSLocalizedString("send_code", comment: "Send code button"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || email.isEmpty)
                } else {
                    // Reset Password Button (Step 2)
                    Button(action: resetPassword) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(NSLocalizedString("reset_password_button", comment: "Reset password button"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isResetButtonEnabled ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : Color.gray)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || !isResetButtonEnabled)
                    
                    // Back to send code button
                    Button(action: { codeVerifySent = false }) {
                        Text(NSLocalizedString("back", comment: "Back button"))
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433), lineWidth: 2)
                            )
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("reset_password", comment: "Reset password navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
        }
        .onAppear {
            showError = false
            errorMessage = ""
        }
    }
    
    private func sendVerifyCode() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                try await authManager.sendResetPasswordVerifyCode(email: email)
                await MainActor.run {
                    codeVerifySent = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                _ = try await authManager.resetPassword(email: email, password: newPassword, verifyCode: verifyCode)
                
                await MainActor.run {
                    isLoading = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView(onDismiss: {})
            .preferredColorScheme(.dark)
    }
}
