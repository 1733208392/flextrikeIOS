import SwiftUI

/**
 `GunTypeSelectionView` is a SwiftUI component for selecting gun types in drill configuration.
 
 This view provides:
 - Radio button style selection between different gun types
 - Visual feedback for selected option
 - Clean, consistent styling matching the app design
 
 ## Features
 - Radio button interface with red accent color
 - Support for multiple gun types
 - Immediate visual feedback on selection
 */

struct GunTypeSelectionView: View {
    @Binding var gunType: GunType
    
    enum GunType: String, CaseIterable {
        case airsoft = "airsoft", laser = "laser"
    }
    
    var body: some View {
        HStack {
            Text(NSLocalizedString("gun", comment: "Gun type selection label"))
                .foregroundColor(.red)
            Spacer()
            HStack(spacing: 20) {
                ForEach(GunType.allCases, id: \.self) { type in
                    Button(action: {
                        gunType = type
                    }) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                if gunType == type {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 14, height: 14)
                                }
                            }
                            Text(type.rawValue.capitalized)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

struct GunTypeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                GunTypeSelectionView(gunType: .constant(.airsoft))
                GunTypeSelectionView(gunType: .constant(.laser))
            }
            .padding()
        }
    }
}