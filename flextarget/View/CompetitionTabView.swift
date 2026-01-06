import SwiftUI
import CoreData

struct CompetitionTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @ObservedObject var authManager = AuthManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if authManager.isAuthenticated {
                competitionMenuView
            } else {
                LoginView(onDismiss: {
                    // Handle dismiss if needed
                })
            }
        }
        .navigationTitle(NSLocalizedString("competition", comment: "Competition tab"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var competitionMenuView: some View {
        VStack(spacing: 20) {            
            // Competitions Link
            NavigationLink(destination: 
                ZStack {
                    Color.black.ignoresSafeArea()
                    CompetitionListView()
                }
            ) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("competitions", comment: "Competitions menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("view_competitions", comment: "View competitions description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            
            // Shooters/Athletes Link
            NavigationLink(destination: 
                ZStack {
                    Color.black.ignoresSafeArea()
                    AthletesManagementView()
                }
            ) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("shooters", comment: "Shooters menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("manage_shooters", comment: "Manage shooters description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            
            // Leaderboard Link
            NavigationLink(destination: 
                ZStack {
                    Color.black.ignoresSafeArea()
                    LeaderboardView()
                }
            ) {
                HStack {
                    Image(systemName: "list.number")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("leaderboard", comment: "Leaderboard menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("view_leaderboard", comment: "View leaderboard description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        CompetitionTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
