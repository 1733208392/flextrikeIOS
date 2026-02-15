import SwiftUI
import CoreData

struct CompetitionListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        entity: Competition.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Competition.date, ascending: false)],
        animation: .default
    ) private var competitions: FetchedResults<Competition>
    
    @State private var searchText = ""
    
    var filteredCompetitions: [Competition] {
        if searchText.isEmpty {
            return Array(competitions)
        } else {
            return competitions.filter { competition in
                (competition.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (competition.venue?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Search and Filter
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField(NSLocalizedString("search_competition", comment: "Search competition placeholder"), text: $searchText, prompt: Text(NSLocalizedString("search_competition", comment: "Search competition placeholder")).foregroundColor(.gray))
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
                
                List {
                    ForEach(filteredCompetitions, id: \.self) { competition in
                        NavigationLink(destination: CompetitionDetailView(competition: competition)) {
                            CompetitionRow(competition: competition)
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                    }
                    .onDelete(perform: deleteCompetitionsFiltered)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
        }
        .navigationTitle(NSLocalizedString("competitions", comment: "Competitions title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .accentColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
        .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddCompetitionView()) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
        }
    }
    
    private func deleteCompetitionsFiltered(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredCompetitions[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting competition: \(error)")
            }
        }
    }
}

struct CompetitionRow: View {
    let competition: Competition
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(competition.name ?? NSLocalizedString("untitled_competition", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                    Text(competition.venue ?? "")
                        .font(.subheadline)
                }
                .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(competition.date ?? Date(), style: .date)
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let drillName = competition.drillSetup?.name {
                Text(drillName)
                    .font(.caption)
                    .padding(5)
                    .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433).opacity(0.2))
                    .cornerRadius(5)
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            }
        }
        .padding(.vertical, 5)
    }
}
