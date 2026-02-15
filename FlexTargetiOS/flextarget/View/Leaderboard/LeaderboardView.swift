import SwiftUI
import CoreData

struct LeaderboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        entity: Competition.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Competition.date, ascending: false)],
        animation: .default
    )
    private var competitions: FetchedResults<Competition>
    
    @State private var selectedCompetition: Competition?
    @State private var rankingRows: [CompetitionResultAPIService.RankingRow] = []
    @State private var isLoadingRanking = false
    @State private var rankingError: String?
    @State private var showRankingError = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var selectedSummaryContext: SelectedSummaryContext? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Competition Filter
                if !competitions.isEmpty {
                    Menu {
                        Text(NSLocalizedString("choose_competition", comment: "Choose competition"))
                            .foregroundColor(.gray)
                        
                        Divider()
                        
                        ForEach(competitions, id: \.self) { competition in
                            Button(competition.name ?? NSLocalizedString("untitled_competition", comment: "")) {
                                selectedCompetition = competition
                                resetAndFetchRanking()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text(selectedCompetition?.name ?? NSLocalizedString("choose_competition", comment: "Choose competition"))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .menuOrder(.fixed)
                    .padding(12)
                } else {
                    VStack {
                        Text(NSLocalizedString("no_competitions", comment: "No competitions available"))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()

                if isLoadingRanking {
                    VStack {
                        ProgressView()
                            .tint(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        Text(NSLocalizedString("loading_ranking", comment: "Loading ranking"))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = rankingError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                        Text(NSLocalizedString("ranking_error", comment: "Error loading ranking"))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: { resetAndFetchRanking() }) {
                            Text(NSLocalizedString("retry", comment: "Retry"))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                                .cornerRadius(6)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rankingRows.isEmpty && selectedCompetition != nil {
                    VStack {
                        Text(NSLocalizedString("no_ranking_data", comment: "No ranking data"))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !rankingRows.isEmpty {
                    rankingList
                }
            }
        }
        .navigationTitle(Text(NSLocalizedString("leaderboard_title", comment: "Leaderboard title")).foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
        }
    }
    
    private var rankingList: some View {
        List {
            ForEach(Array(rankingRows.enumerated()), id: \.element.play_uuid) { index, row in
                rankingRow(rank: index + 1, row: row, isEven: index % 2 == 0)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background(Color.black)
    }

    private struct SelectedSummaryContext {
        let drillSetup: DrillSetup
        let summaries: [DrillRepeatSummary]
    }

    private func resetAndFetchRanking() {
        currentPage = 1
        rankingRows = []
        rankingError = nil
        
        guard let competition = selectedCompetition,
              let competitionId = competition.id?.uuidString else {
            rankingRows = []
            return
        }
        
        isLoadingRanking = true
        
        Task {
            do {
                let ranking = try await CompetitionResultAPIService.shared.getGameRanking(
                    gameType: competitionId,
                    page: currentPage,
                    viewContext: viewContext)
                await MainActor.run {
                    rankingRows = ranking
                    isLoadingRanking = false
                }
            } catch {
                await MainActor.run {
                    rankingError = error.localizedDescription
                    isLoadingRanking = false
                }
            }
        }
    }

    private func rankingRow(rank: Int, row: CompetitionResultAPIService.RankingRow, isEven: Bool) -> some View {
        let background = isEven ? Color.gray.opacity(0.25) : Color.gray.opacity(0.15)
        let displayName: String = {
            if let name = row.athleteName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            if let nick = row.player_nickname, !nick.isEmpty {
                return nick
            }
            return row.player_mobile ?? NSLocalizedString("untitled", comment: "")
        }()

        return HStack(spacing: 16) {
            Text("\(row.rank)")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 44, alignment: .center)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let club = row.athleteClub, !club.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(club)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else if let deviceName = row.bluetooth_name {
                    Text(deviceName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", row.score))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(NSLocalizedString("points", comment: "Points label"))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(background)
    }
}

#Preview {
    NavigationView {
        LeaderboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}
