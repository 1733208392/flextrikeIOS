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
    
    var body: some View {
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
                    .keyboardType(.phonePad)
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
    
    private func login() {
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                let loginData = try await UserAPIService.shared.login(mobile: mobile, password: password)
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