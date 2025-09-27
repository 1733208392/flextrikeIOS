import SwiftUI

struct OrientationView: View {
    @State var steps: [OrientationStep] = []
    @State var selectedStep: Int = 0
    @State private var navigateToConnect = false
    
    // Use environment-injected BLEManager
    @EnvironmentObject var bleManager: BLEManager
    
    // Add parameter to track entry source
    let isFromInfoItem: Bool
    
    // Add initializer
    init(isFromInfoItem: Bool = false) {
        self.isFromInfoItem = isFromInfoItem
    }

    var body: some View {
        NavigationStack {
            VStack {
                if !steps.isEmpty && selectedStep < steps.count {
                    OrientationStepView(
                        step: $steps[selectedStep],
                        onNext: shouldShowNext() ? {
                            if selectedStep < steps.count - 1 {
                                selectedStep += 1
                            } else {
                                navigateToConnect = true
                            }
                        } : nil,
                        onStepCompleted: {
                            saveStepsToLocal()
                        }
                    )
                    .id(selectedStep) // Force view recreation when step changes
                }
            }
            .onAppear {
                loadStepsFromLocal()
                if let firstIncomplete = steps.firstIndex(where: { !$0.isCompleted }) {
                    selectedStep = firstIncomplete
                } else {
                    // All steps complete, go to next screen
                    navigateToConnect = true
                }
            }
            .navigationDestination(isPresented: $navigateToConnect) {
                ConnectSmartTargetView(bleManager: bleManager)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
    
    // Helper function to determine if Next button should be shown
    private func shouldShowNext() -> Bool {
        // Hide Next button on last step if coming from info item
        if isFromInfoItem && selectedStep == steps.count - 1 {
            return false
        }
        return true
    }

    private func loadStepsFromLocal() {
        if let data = UserDefaults.standard.data(forKey: "orientationSteps"),
           let savedSteps = try? JSONDecoder().decode([OrientationStep].self, from: data) {
            steps = savedSteps
        } else {
            let videoFiles = [
                "tutorial-target-setup",
                "tutorial-mobile-setup",
                "tutorial-select-drills",
                "tutorial-view-results"
            ]
            
            let videoURLs = videoFiles.compactMap { fileName in
                Bundle.main.url(forResource: fileName, withExtension: "mp4")
            }
            
            guard videoURLs.count == 4 else {
                print("One or more tutorial videos not found in bundle")
                return
            }
            
            steps = [
                OrientationStep(step: "Step 1", title: "Target Setup", videoURL: videoURLs[0],
                                subTitle: "Assemble target → power on", thumbNail: "test", isCompleted: false),
                OrientationStep(step: "Step 2", title: "Mobile Setup", videoURL: videoURLs[1],
                                subTitle: "Download app → connect to target", thumbNail: "", isCompleted: false),
                OrientationStep(step: "Step 3", title: "Select Drills", videoURL: videoURLs[2],
                                subTitle: "Use remote to select → start drill", thumbNail: "", isCompleted: false),
                OrientationStep(step: "Step 4", title: "View Results", videoURL: videoURLs[3],
                                subTitle: "Pause with right button → use ↑↓ to review shots", thumbNail: "", isCompleted: false)
            ]
        }
    }

    private func saveStepsToLocal() {
        if let data = try? JSONEncoder().encode(steps) {
            UserDefaults.standard.set(data, forKey: "orientationSteps")
        }
    }
}
