import SwiftUI
import UIKit

struct RecentTrainingView: View {
    @State private var selectedPage: Int = 0
    @State private var summaries: [DrillSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @StateObject private var repository = DrillRepository.shared
    
    private var pageCount: Int { min(summaries.count, 3) }
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
            Text("Failed to load drills")
                .font(.headline)
                .foregroundColor(.white)
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            Button("Retry") {
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
            Text("No recent drills")
                .font(.headline)
                .foregroundColor(.white)
            Text("Complete some drills to see them here")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(height: cardHeight)
        .padding()
    }

    private func contentView() -> some View {
        TabView(selection: $selectedPage) {
            let toShow = Array(summaries.prefix(pageCount))
            ForEach(Array(toShow.enumerated()), id: \ .1.id) { idx, summary in
                cardView(for: summary)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }

    private func cardView(for summary: DrillSummary) -> some View {
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
                    Text("Hit Factor")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack {
                    // Date in center
                    Text(Self.dateFormatter.string(from: summary.drillDate))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack {
                    Text(String(format: "%.2fs", summary.fastestShoot))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Fastest")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Page Indicator (re-using circles)
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \ .self) { i in
                    Circle()
                        .fill(i == selectedPage ? Color.red : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 0)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(20)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(height: cardHeight)
        .padding(.horizontal, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Drills")
                .font(.headline)
                .foregroundColor(.white)

            if isLoading {
                loadingView
            } else if errorMessage != nil {
                errorView
            } else if summaries.isEmpty {
                emptyView
            } else {
                contentView()
            }
        }
        .onAppear {
            loadRecentDrills()
        }
        .onChange(of: summaries) { _, _ in
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
                let recentSummaries = try repository.fetchRecentSummaries(limit: 3)
                
                await MainActor.run {
                    self.summaries = recentSummaries
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    
                    // Fallback to mock data if repository fails
                    if summaries.isEmpty {
                        self.summaries = DrillSummary.mock
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
}

struct RecentTrainingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RecentTrainingView()
                .padding()
        }
        .previewLayout(.sizeThatFits)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(BLEManager.shared)
    }
}
