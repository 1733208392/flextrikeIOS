import SwiftUI
import CoreData
import PhotosUI

struct AthletesManagementView: View {
    @Environment(\.managedObjectContext) private var environmentContext
    @Environment(\.dismiss) private var dismiss

    // Use the shared persistence controller's viewContext as a fallback to
    // ensure we always point at a live store even if the environment is missing
    private var viewContext: NSManagedObjectContext {
        if let coordinator = environmentContext.persistentStoreCoordinator,
           coordinator.persistentStores.isEmpty == false {
            return environmentContext
        }
        return PersistenceController.shared.container.viewContext
    }

    @FetchRequest(
        entity: Athlete.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Athlete.name, ascending: true)],
        animation: .default
    )
    private var athletes: FetchedResults<Athlete>

    @State private var name: String = ""
    @State private var club: String = ""

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedAvatarData: Data? = nil

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var athleteToDelete: Athlete? = nil
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }

            List {
                Section(header: Text(NSLocalizedString("new_athlete", comment: "New athlete section header"))
                    .foregroundColor(.white)) {

                    HStack(spacing: 12) {
                        avatarPreview(data: selectedAvatarData)

                        VStack(spacing: 10) {
                            TextField(NSLocalizedString("athlete_name", comment: "Athlete name placeholder"), text: $name, prompt: Text(NSLocalizedString("athlete_name", comment: "Athlete name placeholder")).foregroundColor(.white.opacity(0.6)))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)

                            TextField(NSLocalizedString("athlete_club", comment: "Athlete club placeholder"), text: $club, prompt: Text(NSLocalizedString("athlete_club", comment: "Athlete club placeholder")).foregroundColor(.white.opacity(0.6)))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.2))

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(NSLocalizedString("select_avatar", comment: "Select avatar button"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.red)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.gray.opacity(0.2))
                    .onChange(of: selectedPhoto) { newItem in
                        guard let newItem else {
                            selectedAvatarData = nil
                            return
                        }
                        Task {
                            do {
                                if let data = try await newItem.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        selectedAvatarData = data
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    }

                    Button {
                        addAthlete()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.red)
                            Text(NSLocalizedString("add_athlete", comment: "Add athlete button"))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.gray.opacity(0.2))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section(header: Text(NSLocalizedString("athletes", comment: "Athletes section header"))
                    .foregroundColor(.white)) {
                    if athletes.isEmpty {
                        Text(NSLocalizedString("athletes_empty", comment: "Empty athletes list"))
                            .foregroundColor(.gray)
                            .listRowBackground(Color.gray.opacity(0.2))
                    } else {
                        ForEach(athletes) { athlete in
                            athleteRow(athlete)
                                .listRowBackground(Color.gray.opacity(0.2))
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        athleteToDelete = athlete
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label(NSLocalizedString("delete", comment: "Delete button"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .simultaneousGesture(
                TapGesture().onEnded {
                    hideKeyboard()
                }
            )
        }
        .navigationTitle(NSLocalizedString("athletes_title", comment: "Athletes screen title"))
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("back", comment: "Back button")) {
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button")))
            )
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(NSLocalizedString("delete_athlete", comment: "Delete athlete")),
                message: Text(NSLocalizedString("delete_athlete_confirm", comment: "Confirm athlete deletion with competition results cleanup")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete button"))) {
                    if let athlete = athleteToDelete {
                        deleteAthleteWithResults(athlete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private func avatarPreview(data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundColor(.gray)
        }
    }

    private func athleteRow(_ athlete: Athlete) -> some View {
        HStack(spacing: 12) {
            avatarPreview(data: athlete.avatarData)

            VStack(alignment: .leading, spacing: 4) {
                Text(athlete.name?.isEmpty == false ? athlete.name! : NSLocalizedString("untitled", comment: "Fallback name"))
                    .foregroundColor(.white)
                    .font(.headline)

                if let club = athlete.club, !club.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(club)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func addAthlete() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClub = club.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        let athlete = Athlete(context: viewContext)
        athlete.id = UUID()
        athlete.name = trimmedName
        athlete.club = trimmedClub.isEmpty ? nil : trimmedClub
        athlete.avatarData = selectedAvatarData

        do {
            try viewContext.save()
            name = ""
            club = ""
            selectedPhoto = nil
            selectedAvatarData = nil
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteAthleteWithResults(_ athlete: Athlete) {
        // Fetch all competition results associated with this athlete
        let fetchRequest = NSFetchRequest<DrillResult>(entityName: "DrillResult")
        fetchRequest.predicate = NSPredicate(format: "ANY leaderboardEntries.athlete == %@", athlete)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            for result in results {
                viewContext.delete(result)
            }
            
            // Delete the athlete
            viewContext.delete(athlete)
            
            try viewContext.save()
            athleteToDelete = nil
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationView {
        AthletesManagementView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}
