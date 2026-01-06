import SwiftUI
import CoreData

struct AthletePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Athlete) -> Void

    @FetchRequest(
        entity: Athlete.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Athlete.name, ascending: true)],
        animation: .default
    )
    private var athletes: FetchedResults<Athlete>

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                if athletes.isEmpty {
                    Text(NSLocalizedString("athletes_empty", comment: "Empty athletes list"))
                        .foregroundColor(.gray)
                        .listRowBackground(Color.gray.opacity(0.2))
                } else {
                    ForEach(athletes) { athlete in
                        Button {
                            onSelect(athlete)
                            dismiss()
                        } label: {
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
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .navigationTitle(NSLocalizedString("select_athlete_title", comment: "Select athlete title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private func avatarPreview(data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    NavigationView {
        AthletePickerSheet(onSelect: { _ in })
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}
