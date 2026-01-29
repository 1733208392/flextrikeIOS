import SwiftUI

struct CompetitionLoginView: View {
    @AppStorage("isCompetitionLoggedIn") private var isCompetitionLoggedIn = false
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .padding(.bottom, 20)
                
                Text(NSLocalizedString("competition_login", comment: "Competition Login Title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    TextField(NSLocalizedString("username", comment: "Username field"), text: $username, prompt: Text(NSLocalizedString("username", comment: "Username field")).foregroundColor(.gray))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                    
                    SecureField(NSLocalizedString("password", comment: "Password field"), text: $password, prompt: Text(NSLocalizedString("password", comment: "Password field")).foregroundColor(.gray))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    // For testing purpose, any user name and password will pass
                    if !username.isEmpty && !password.isEmpty {
                        isCompetitionLoggedIn = true
                    }
                }) {
                    Text(NSLocalizedString("login", comment: "Login button"))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                Text(NSLocalizedString("login_hint", comment: "Login hint"))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct CompetitionLoginView_Previews: PreviewProvider {
    static var previews: some View {
        CompetitionLoginView()
    }
}
