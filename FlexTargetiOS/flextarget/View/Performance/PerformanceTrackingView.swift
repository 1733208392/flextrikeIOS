import SwiftUI
import Combine

@MainActor
class PerformanceTrackingViewModel: ObservableObject {
    @Published var dataPoints: [PerformanceDataPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let drillId: UUID
    let repository: DrillRepositoryProtocol
    
    init(drillId: UUID, repository: DrillRepositoryProtocol = DrillRepository.shared) {
        self.drillId = drillId
        self.repository = repository
        
        loadData()
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Fetch DrillResult objects on the main thread (viewContext is main-thread-only)
                let results = try repository.fetchDrillResults(for: drillId, limit: 50)
                
                // 2. Run the CPU-heavy trend calculation on a background thread
                let trends = try await Task.detached(priority: .userInitiated) {
                    PerformanceCalculator.calculateTrends(from: results)
                }.value
                
                dataPoints = trends
                isLoading = false
            } catch {
                errorMessage = "Failed to load performance data: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
}

struct PerformanceTrackingView: View {
    @StateObject var viewModel: PerformanceTrackingViewModel
    @Environment(\.dismiss) var dismiss
    
    private let accentRed = Color(red: 222/255, green: 56/255, blue: 35/255)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(accentRed)
                    }
                    
                    Spacer()
                    
                    Text("PERFORMANCE TRACKING")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { viewModel.loadData() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(accentRed)
                    }
                }
                .padding()
                
                if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(accentRed)
                        Text("Calculating performance data...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Button("Retry") { viewModel.loadData() }
                            .foregroundColor(accentRed)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.dataPoints.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Not enough data to track performance yet.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Text("Complete at least two sessions of this drill.")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding()
                    Spacer()
                } else {
                    // Upper: Moving average trend charts
                    VStack(spacing: 10) {
                        LineChartView(
                            dataPoints: viewModel.dataPoints.map { $0.reactionTime },
                            title: "Reaction Time",
                            unit: "s",
                            color: accentRed
                        )
                        LineChartView(
                            dataPoints: viewModel.dataPoints.map { $0.fastestSplit },
                            title: "Fastest Split",
                            unit: "s",
                            color: .orange
                        )
                        LineChartView(
                            dataPoints: viewModel.dataPoints.map { $0.grouping },
                            title: "Grouping",
                            unit: "",
                            color: Color(red: 0, green: 0.8, blue: 0.9)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.vertical, 8)
                        .padding(.horizontal)

                    // Lower: Scrollable session data
                    ScrollView {
                        PerformanceTableView(dataPoints: viewModel.dataPoints)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}
