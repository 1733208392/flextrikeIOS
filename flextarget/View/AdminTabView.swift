import SwiftUI
import CoreData

struct AdminTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var authToken: String? = nil
    @State private var isAuthenticated = false
    @State private var tokenInput = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoadingAuth = false
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isAuthenticated {
                AdminContentView()
                    .environment(\.managedObjectContext, managedObjectContext)
            } else {
                adminLoginView
            }
        }
        .navigationTitle(NSLocalizedString("admin", comment: "Admin tab title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAuthToken()
        }
    }
    
    private var adminLoginView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text(NSLocalizedString("admin_access", comment: "Admin access title"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(NSLocalizedString("admin_access_hint", comment: "Admin access hint"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            
            VStack(spacing: 12) {
                SecureField(NSLocalizedString("enter_token", comment: "Enter token placeholder"), text: $tokenInput)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(Color.white)
                    .tint(Color.red)
                
                Button(action: authenticateWithToken) {
                    if isLoadingAuth {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Text(NSLocalizedString("authorize", comment: "Authorize button"))
                            .foregroundColor(Color.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.red)
                .cornerRadius(8)
                .disabled(tokenInput.isEmpty || isLoadingAuth)
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    private func authenticateWithToken() {
        isLoadingAuth = true
        showError = false
        
        // Simulate token validation - replace with actual API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if tokenInput.trimmingCharacters(in: .whitespaces).count >= 6 {
                // Save token to CoreData
                saveTokenToCoreData(tokenInput)
                authToken = tokenInput
                isAuthenticated = true
                isLoadingAuth = false
            } else {
                errorMessage = NSLocalizedString("invalid_token", comment: "Invalid token message")
                showError = true
                isLoadingAuth = false
            }
        }
    }
    
    private func saveTokenToCoreData(_ token: String) {
        let context = persistenceController.container.viewContext
        
        // Clear existing tokens
        let fetchRequest: NSFetchRequest<AppAuth> = AppAuth.fetchRequest()
        do {
            let existingAuth = try context.fetch(fetchRequest)
            for auth in existingAuth {
                context.delete(auth)
            }
            
            // Create new token
            let newAuth = AppAuth(context: context)
            newAuth.id = UUID()
            newAuth.token = token
            
            try context.save()
        } catch {
            errorMessage = NSLocalizedString("save_token_error", comment: "Error saving token")
            showError = true
        }
    }
    
    private func loadAuthToken() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppAuth> = AppAuth.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let auth = results.first, let token = auth.token {
                authToken = token
                isAuthenticated = true
            }
        } catch {
            // No token found, stay on login screen
        }
    }
}

struct AdminContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var selectedAdminTab = 0
    @State private var showLogoutAlert = false
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker("Admin Section", selection: $selectedAdminTab) {
                    Text(NSLocalizedString("athletes", comment: "Athletes section")).tag(0)
                    Text(NSLocalizedString("drill_submission", comment: "Drill submission section")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(12)
                .tint(.red)
                
                if selectedAdminTab == 0 {
                    AthletesManagementView()
                        .environment(\.managedObjectContext, managedObjectContext)
                } else {
                    DrillSubmissionView()
                        .environment(\.managedObjectContext, managedObjectContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLogoutAlert = true }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert(NSLocalizedString("logout", comment: "Logout"), isPresented: $showLogoutAlert) {
                Button(NSLocalizedString("logout", comment: "Logout"), role: .destructive) {
                    logout()
                }
                Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("logout_confirm", comment: "Logout confirmation message"))
            }
        }
    }
    
    private func logout() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppAuth> = AppAuth.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            for auth in results {
                context.delete(auth)
            }
            try context.save()
        } catch {
            print("Error during logout: \(error)")
        }
    }
}

struct DrillSubmissionView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @FetchRequest(
        entity: DrillResult.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)],
        animation: .default
    ) private var drillResults: FetchedResults<DrillResult>
    
    @FetchRequest(
        entity: Athlete.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Athlete.name, ascending: true)],
        animation: .default
    ) private var athletes: FetchedResults<Athlete>
    
    @State private var selectedDrillResult: DrillResult? = nil
    @State private var selectedAthlete: Athlete? = nil
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Select Drill Result
            if drillResults.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text(NSLocalizedString("no_drills_to_submit", comment: "No drills to submit"))
                            .font(.headline)
                        Text(NSLocalizedString("no_drills_hint", comment: "No drills hint"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Drill Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("select_drill_result", comment: "Select drill result"))
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            Menu {
                                ForEach(drillResults, id: \.objectID) { result in
                                    Button(action: { selectedDrillResult = result }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(result.drillSetup?.name ?? NSLocalizedString("untitled", comment: "Untitled"))
                                                if let date = result.date {
                                                    Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            if selectedDrillResult == result {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedDrillResult?.drillSetup?.name ?? NSLocalizedString("choose_drill", comment: "Choose drill"))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            }
                        }
                        
                        // Athlete Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("select_athlete", comment: "Select athlete"))
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            if athletes.isEmpty {
                                Text(NSLocalizedString("no_athletes", comment: "No athletes"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Menu {
                                    ForEach(athletes, id: \.objectID) { athlete in
                                        Button(action: { selectedAthlete = athlete }) {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(athlete.name ?? NSLocalizedString("untitled", comment: "Untitled"))
                                                    if let club = athlete.club {
                                                        Text(club)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                if selectedAthlete == athlete {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedAthlete?.name ?? NSLocalizedString("choose_athlete", comment: "Choose athlete"))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Submit Button
                        Button(action: submitDrillResult) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(NSLocalizedString("submit_to_leaderboard", comment: "Submit to leaderboard"))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(selectedDrillResult != nil && selectedAthlete != nil ? Color.red : Color.gray)
                        .cornerRadius(8)
                        .disabled(selectedDrillResult == nil || selectedAthlete == nil || isSubmitting)
                        
                        if showSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(NSLocalizedString("submission_success", comment: "Submission success"))
                            }
                            .foregroundColor(.green)
                            .padding(12)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                        }
                        
                        if showError {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }
    
    private func submitDrillResult() {
        guard let drillResult = selectedDrillResult, let athlete = selectedAthlete else { return }
        
        isSubmitting = true
        showError = false
        showSuccess = false
        
        // Prepare submission data
        let submissionData: [String: Any] = [
            "athleteId": athlete.id?.uuidString ?? "",
            "athleteName": athlete.name ?? "",
            "athleteClub": athlete.club ?? "",
            "drillResultId": drillResult.id?.uuidString ?? "",
            "drillSetupId": drillResult.drillSetup?.id?.uuidString ?? "",
            "drillSetupName": drillResult.drillSetup?.name ?? "",
            "drillMode": drillResult.drillSetup?.mode ?? "",
            "totalTime": drillResult.totalTime,
            "date": drillResult.date?.timeIntervalSince1970 ?? 0,
            "shotCount": (drillResult.shots as? Set<Shot>)?.count ?? 0
        ]
        
        // Call web API (implementation will be provided)
        // For now, simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            
            // Simulate success
            if Int.random(in: 0...1) == 0 {
                showSuccess = true
                selectedDrillResult = nil
                selectedAthlete = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccess = false
                }
            } else {
                errorMessage = NSLocalizedString("submission_error", comment: "Submission error")
                showError = true
            }
        }
    }
}

#Preview {
    NavigationView {
        AdminTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
