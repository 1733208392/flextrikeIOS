import SwiftUI

/**
 `DrillSetupSectionView` is a SwiftUI component for displaying and configuring drill setup parameters.
 
 This view provides:
 - A button to open drill setup modal
 - Visual display of current drill configuration (sets, duration, shots)
 - Conditional styling based on setup enabled state
 - Integration with drill setup sheet
 
 ## Features
 - Shows current drill parameters in a clean layout
 - Disabled state when setup is not enabled
 - Modal sheet presentation for detailed configuration
 - Consistent styling with app design system
 */

struct DrillSetupSectionView: View {
    @Binding var targets: [DrillTargetsConfig]
    @Binding var isTargetListReceived: Bool

    var body: some View {
        NavigationLink(destination: TargetConfigView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.red)
                    Text("Drills Setup")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .center, spacing: 0) {
                    VStack {
                        Text("\(targets.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Targets")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Text("|")
                        .foregroundColor(.gray)
                        .font(.title2)
                    
                    Spacer(minLength: 0)
                    
                    VStack {
                        Text("\(Int(targets.first?.timeout ?? 0))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Timeout")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Text("|")
                        .foregroundColor(.gray)
                        .font(.title2)
                    
                    Spacer(minLength: 0)
                    
                    VStack {
                        Text("\(targets.first?.countedShots ?? 0  )")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Shots/Target")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(targets.count > 0 ? 0.2 : 0.1))
            .cornerRadius(16)
            .opacity(isTargetListReceived ? 1.0 : 0.6)
        }
        .disabled(!isTargetListReceived)
    }
}

struct DrillSetupSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                DrillSetupSectionView(
                    targets: .constant([
                        DrillTargetsConfig(seqNo: 1, targetName: "Target A", targetType: "Standard", timeout: 30, countedShots: 5),
                        DrillTargetsConfig(seqNo: 2, targetName: "Target B", targetType: "Paper", timeout: 25, countedShots: 3),
                        DrillTargetsConfig(seqNo: 3, targetName: "Target C", targetType: "Electronic", timeout: 20, countedShots: 10)
                    ]),
                    isTargetListReceived: .constant(true)
                )
            }
            .padding()
        }
    }
}
