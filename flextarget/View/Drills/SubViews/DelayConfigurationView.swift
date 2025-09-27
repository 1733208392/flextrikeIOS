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
    @Binding var delayType: DelayType
    @Binding var delayValue: Double
    
    enum DelayType: String, CaseIterable { 
        case fixed, random 
    }
    
    var body: some View {
        HStack {
            Text("Delay(s)")
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    delayType = (delayType == .random) ? .fixed : .random
                    if delayType == .random {
                        delayValue = 2 // default random min
                    } else {
                        delayValue = 0 // default fixed
                    }
                }
            }) {
                Image(systemName: "shuffle")
                    .foregroundColor(delayType == .random ? .red : .gray)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .overlay(
                        Circle().stroke(delayType == .random ? Color.red : Color.gray, lineWidth: 2)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            if delayType == .random {
                // Random mode: show spinner for 2...4
                Picker("Random Delay", selection: $delayValue) {
                    ForEach(1...60, id: \.self) { value in
                        Text("\(value)")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 60)
                .clipped()
            } else {
                // Fixed mode: show stepper
                Text("2...4")
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
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
                    delayType: .constant(.fixed),
                    delayValue: .constant(0)
                )
                DelayConfigurationView(
                    delayType: .constant(.random),
                    delayValue: .constant(3)
                )
            }
            .padding()
        }
    }
}