import SwiftUI

struct CQBTargetResultRow: View {
    let results: [CQBShotResult]
    
    var body: some View {
        if results.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(Color.white.opacity(0.1))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(results, id: \.targetName) { result in
                            CQBTargetResultCard(result: result)
                        }
                        Spacer() // Ensure end padding
                    }
                    .padding(.horizontal, 12)
                    .frame(minWidth: UIScreen.main.bounds.width)
                }
                .frame(height: 130)
                .background(Color.white.opacity(0.02))
                
                Divider()
                    .frame(height: 1)
                    .background(Color.white.opacity(0.1))
            }
            .frame(height: 132) // 130 + 2 for dividers
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    CQBTargetResultRow(
        results: [
            CQBShotResult(
                targetName: "cqb_front",
                isThreat: true,
                expectedShots: 2,
                actualValidShots: 2,
                cardStatus: .green
            ),
            CQBShotResult(
                targetName: "cqb_swing",
                isThreat: true,
                expectedShots: 2,
                actualValidShots: 1,
                cardStatus: .red,
                failureReason: "Missed 1 shot"
            ),
            CQBShotResult(
                targetName: "cqb_hostage",
                isThreat: false,
                expectedShots: 0,
                actualValidShots: 0,
                cardStatus: .green
            )
        ]
    )
    .background(Color.black)
}

