import SwiftUI
import UIKit
import CoreData

struct RecentTrainingView: View {
    @Binding var selectedDrillSetup: DrillSetup?
    @Binding var selectedDrillShots: [ShotData]?
    @State private var selectedPage: Int = 0
    @State private var drills: [(DrillSummary, DrillResult)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @StateObject private var repository = DrillRepository.shared
    
    private var pageCount: Int { min(drills.count, 3) }
    private let cardHeight: CGFloat = 288

    private var loadingView: some View {
        VStack {
            ProgressView("Loading recent drills...")
                .foregroundColor(.white)
        }
        .frame(height: cardHeight)
    }

    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(NSLocalizedString("failed_to_load_drills", comment: "Failed to load drills message"))
                .font(.headline)
                .foregroundColor(.white)
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            Button(NSLocalizedString("retry", comment: "Retry button")) {
                loadRecentDrills()
            }
            .padding(.top, 8)
            .foregroundColor(.blue)
        }
        .frame(height: cardHeight)
        .padding()
    }

    private var emptyView: some View {
        VStack {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(NSLocalizedString("no_recent_drills", comment: "No recent drills message"))
                .font(.headline)
                .foregroundColor(.white)
            Text(NSLocalizedString("complete_drills_message", comment: "Complete drills message"))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(height: cardHeight)
        .padding()
    }

    private func contentView() -> some View {
        TabView(selection: $selectedPage) {
            let toShow = Array(drills.prefix(pageCount))
            ForEach(Array(toShow.enumerated()), id: \ .offset) { idx, drill in
                cardView(for: drill.0, drillResult: drill.1)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page)
        .frame(height: cardHeight)
    }

    private func cardView(for summary: DrillSummary, drillResult: DrillResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            //Title
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundColor(.red)
                Text(summary.drillName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            
            // TargetTypeIcon (use first targetType -> asset name)
            let _ = summary.targetType.first ?? ""
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")

            HStack(spacing: 12) {
                Spacer()
                // Render up to two icons
                ForEach(Array(summary.targetType.prefix(2).enumerated()), id: \ .offset) { _, raw in
                    let name = raw
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "_")
                    Group {
                        if let uiImage = UIImage(named: name) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                        }
                    }
                    .scaledToFit()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12)
                }
                Spacer()
            }
            .padding(.top, 8)
            
            // Info Row (date moved to center, reduced numeric font size)
            HStack {
                VStack {
                    Text(String(format: "%.1f", summary.hitFactor))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("hit_factor", comment: "Hit Factor label"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack {
                    // Date in center
                    Text(Self.dateFormatter.string(from: summary.drillDate))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("date", comment: "Date label"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack {
                    Text(String(format: "%.2fs", summary.fastestShoot))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("fastest", comment: "Fastest label"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.top, 0)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(20)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(height: cardHeight)
        .padding(.horizontal, 4)
        .onTapGesture {
            guard let setup = drillResult.drillSetup else { return }
            selectedDrillSetup = setup
            selectedDrillShots = convertShots(drillResult.shots)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                loadingView
            } else if errorMessage != nil {
                errorView
            } else if drills.isEmpty {
                emptyView
            } else {
                contentView()
            }
        }
        .onAppear {
            loadRecentDrills()
        }
        .onChange(of: drills.count) { _, _ in
            // Clamp selected page to valid range when data changes
            if selectedPage >= pageCount {
                selectedPage = max(0, pageCount - 1)
            }
        }
    }

    // Date formatter used for displaying the drill date
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    // MARK: - Data Loading
    
    private func loadRecentDrills() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let recentDrills = try repository.fetchRecentDrills(limit: 3)
                
                await MainActor.run {
                    self.drills = recentDrills
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    
                    // Fallback to mock data if repository fails
                    if drills.isEmpty {
                        // For mock data, we need to create dummy DrillSetup
                        // Since we don't have real DrillSetup for mock, we'll keep empty for now
                        self.errorMessage = nil
                    }
                }
            }
        }
    }

    private func convertShots(_ shots: NSSet?) -> [ShotData] {
        guard let shots = shots as? Set<Shot> else { return [] }
        let decoded = shots.compactMap { shot -> ShotData? in
            guard let data = shot.data, let jsonData = data.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ShotData.self, from: jsonData)
        }
        return decoded.sorted { $0.content.timeDiff < $1.content.timeDiff }
    }
}

struct RecentTrainingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RecentTrainingView(selectedDrillSetup: .constant(nil), selectedDrillShots: .constant(nil))
                .padding()
        }
        .previewLayout(.sizeThatFits)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(BLEManager.shared)
    }
}
