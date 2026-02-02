import SwiftUI

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared
    
    let onDismiss: () -> Void
    
    @State private var mobile = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showRegistration = false
    @State private var showForgotPassword = false
    
    var body: some View {
        if showRegistration {
            RegistrationView(
                onDismiss: {
                    showRegistration = false
                    onDismiss()
                }
            )
        } else if showForgotPassword {
            ForgotPasswordView(
                onDismiss: {
                    showForgotPassword = false
                    onDismiss()
                }
            )
        } else {
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text(NSLocalizedString("user_login", comment: "User login title"))
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    TextField(NSLocalizedString("mobile_number", comment: "Mobile number placeholder"), text: $mobile)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.default)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField(NSLocalizedString("password", comment: "Password placeholder"), text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(NSLocalizedString("login", comment: "Login button"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || mobile.isEmpty || password.isEmpty)
                    
                    // Forgot Password button
                    Button(action: { showForgotPassword = true }) {
                        Text(NSLocalizedString("forgot_password", comment: "Forgot password button"))
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .disabled(isLoading)
                    
                    // Register button
                    Button(action: { showRegistration = true }) {
                        Text(NSLocalizedString("login_register_button", comment: "Register button"))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("login_title", comment: "Login navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                // Clear any previous error
                showError = false
                errorMessage = ""
            }
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                let loginData = try await authManager.loginWithAutoDetect(input: mobile, password: password)
                let user = User(
                    userUUID: loginData.user_uuid,
                    mobile: mobile,
                    accessToken: loginData.access_token,
                    refreshToken: loginData.refresh_token
                )
                authManager.login(user: user)
                
                // Fetch user info and update username
                do {
                    let userGetData = try await UserAPIService.shared.getUser(accessToken: loginData.access_token)
                    authManager.updateUserInfo(username: userGetData.username)
                    print("[LoginView] User info fetched and updated: \(userGetData.username)")
                } catch {
                    print("[LoginView] Failed to fetch user info: \(error)")
                    // Continue with login even if user info fetch fails
                }
                
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}