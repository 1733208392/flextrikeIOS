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
            NavigationLink(destination: CompetitionSessionStartView()) {
                HStack {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("competition_session_start", comment: "Start competition session title"))
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(NSLocalizedString("competition_session_start_hint", comment: "Start competition session hint"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.tail)
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
