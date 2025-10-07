import SwiftUI

/**
 `DelayConfigurationView` is a SwiftUI component for configuring drill start delays.
 
 This view provides:
 - Toggle between fixed and random delay modes
 - Visual feedback for the selected mode
 - Different UI controls based on the delay type
 - Fixed mode: Shows "2...4" text indicating random range
 - Random mode: Provides a picker for selecting specific delay values
 
 ## Features
 - Animated toggle button with shuffle icon
 - Mode-specific UI controls
 - Clean visual design matching app style
 - Automatic value updates when switching modes
 */

struct DelayConfigurationView: View {
    // DelayType removed - this view now only supports random delay mode
    @Binding var delayValue: Double

    var body: some View {
        HStack {
            Text(NSLocalizedString("delay_seconds_label", comment: "Delay in seconds label"))
                .foregroundColor(.white)

            Spacer()

            // Keep shuffle icon as an indicator for randomness but remove toggle behavior
            Image(systemName: "shuffle")
                .foregroundColor(.red)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(
                    Circle().stroke(Color.red, lineWidth: 2)
                )

            Spacer()

            // Random range display - fixed value picker removed
            Text(NSLocalizedString("delay_range", comment: "Delay range display"))
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

struct DelayConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                DelayConfigurationView(
                    delayValue: .constant(3)
                )
            }
            .padding()
        }
    }
}
