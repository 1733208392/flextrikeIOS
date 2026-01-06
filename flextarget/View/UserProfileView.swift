import SwiftUI

struct UserProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared
    
    let onDismiss: () -> Void
    
    @State private var username = ""
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var selectedTab = 0
    @State private var showLogoutAlert = false
    
    var body: some View {
        VStack {
            Picker(NSLocalizedString("profile", comment: "Profile"), selection: $selectedTab) {
                Text(NSLocalizedString("edit_profile", comment: "Edit Profile")).tag(0)
                Text(NSLocalizedString("change_password", comment: "Change Password")).tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if selectedTab == 0 {
                editProfileView
            } else {
                changePasswordView
            }
            
            // Logout Button
            Button(action: {
                showLogoutAlert = true
            }) {
                Text(NSLocalizedString("logout", comment: "Logout"))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("user_profile", comment: "User Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.red)
                }
            }
        }
        .alert(isPresented: $showSuccess) {
            Alert(title: Text(NSLocalizedString("success_title", comment: "Success")), message: Text(NSLocalizedString("profile_updated_success", comment: "Profile updated successfully")), dismissButton: .default(Text(NSLocalizedString("ok_button", comment: "OK"))))
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text(NSLocalizedString("logout", comment: "Logout")),
                message: Text(NSLocalizedString("logout_confirm", comment: "Are you sure you want to logout?")),
                primaryButton: .destructive(Text(NSLocalizedString("logout", comment: "Logout"))) {
                    Task {
                        await authManager.logout()
                        onDismiss() // Dismiss the profile view after logout
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            if let user = authManager.currentUser {
                username = user.username ?? ""
            }
        }
    }
    
    private var editProfileView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                TextField(NSLocalizedString("username", comment: "Username"), text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: updateProfile) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(NSLocalizedString("update_profile", comment: "Update Profile"))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading || username.isEmpty)
            }
            .padding(.horizontal, 32)
        }
    }
    
    private var changePasswordView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                SecureField(NSLocalizedString("current_password", comment: "Current Password"), text: $oldPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField(NSLocalizedString("new_password", comment: "New Password"), text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField(NSLocalizedString("confirm_password", comment: "Confirm New Password"), text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: changePassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(NSLocalizedString("change_password", comment: "Change Password"))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func updateProfile() {
        guard let accessToken = authManager.currentUser?.accessToken else { return }
        
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                _ = try await UserAPIService.shared.editUser(username: username, accessToken: accessToken)
                authManager.updateUserInfo(username: username)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    private func changePassword() {
        guard let accessToken = authManager.currentUser?.accessToken else { return }
        
        isLoading = true
        errorMessage = ""
        showError = false
        
        Task {
            do {
                _ = try await UserAPIService.shared.changePassword(oldPassword: oldPassword, newPassword: newPassword, accessToken: accessToken)
                showSuccess = true
                // Clear fields
                oldPassword = ""
                newPassword = ""
                confirmPassword = ""
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}