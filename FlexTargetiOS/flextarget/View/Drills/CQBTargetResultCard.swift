import SwiftUI

struct CQBTargetResultCard: View {
    let result: CQBShotResult
    
    private var targetName: String {
        switch result.targetName {
        case "cqb_front":
            return NSLocalizedString("cqb_front", comment: "CQB front target")
        case "cqb_swing":
            return NSLocalizedString("cqb_swing", comment: "CQB swing target")
        case "cqb_moving":
            return NSLocalizedString("cqb_moving", comment: "CQB moving target")
        case "cqb_hostage":
            return NSLocalizedString("cqb_hostage", comment: "CQB hostage")
        case "disguised_enemy":
            return NSLocalizedString("disguised_enemy", comment: "Disguised enemy")
        case "disguised_enemy_surrender":
            return NSLocalizedString("disguised_enemy_surrender", comment: "Disguised enemy surrender")
        default:
            return result.targetName
        }
    }
    
    private var overlayColor: Color {
        result.cardStatus == .green ? .green : Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
    }
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            // Text content
            VStack(spacing: 4) {
                Text(targetName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Colored overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(overlayColor.opacity(0.7))
        }
        .frame(width: 90, height: 110)
    }
}

#Preview {
    HStack(spacing: 12) {
        CQBTargetResultCard(
            result: CQBShotResult(
                targetName: "cqb_front",
                isThreat: true,
                expectedShots: 2,
                actualValidShots: 2,
                cardStatus: .green
            )
        )
        CQBTargetResultCard(
            result: CQBShotResult(
                targetName: "cqb_swing",
                isThreat: true,
                expectedShots: 2,
                actualValidShots: 1,
                cardStatus: .red,
                failureReason: "Missed 1 shot"
            )
        )
    }
    .padding()
    .background(Color.black)
}
