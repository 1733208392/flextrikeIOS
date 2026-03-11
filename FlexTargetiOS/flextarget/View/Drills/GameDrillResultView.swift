import SwiftUI

struct GameDrillResultView: View {
    let gameName: String
    let score: String
    let hits: String
    let misses: String
    var onReplay: () -> Void
    var onDone: () -> Void
    
    private let accentRed = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
    private let darkBackground = Color.black
    private let darkText = Color(red: 0.098, green: 0.098, blue: 0.098) // #191919

    var body: some View {
        ZStack {
            darkBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: onDone) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accentRed)
                    }
                    Spacer()
                    Text(NSLocalizedString("game_results", comment: "Game Results"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentRed)
                    Spacer()
                    // Hidden placeholder for symmetry
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Header Info
                    VStack(spacing: 8) {
                        Text(gameName.uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(accentRed)
                        
                        Spacer().frame(height: 40)
                        
                        // Big Score Display
                        Text(NSLocalizedString("score", comment: "Score").uppercased())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(score)
                            .font(.system(size: 72, weight: .black))
                            .foregroundColor(accentRed)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Stats Row
                    HStack {
                        Spacer()
                        GameStatItem(label: NSLocalizedString("hits", comment: "Hits").uppercased(), value: hits, color: .green)
                        Spacer()
                        GameStatItem(label: NSLocalizedString("misses", comment: "Misses").uppercased(), value: misses, color: accentRed)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: onReplay) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text(NSLocalizedString("replay", comment: "Replay").uppercased())
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(darkText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(accentRed)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onDone) {
                            Text(NSLocalizedString("done", comment: "Done").uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60) // Move buttons up as requested
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct GameStatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 32, weight: .black))
                .foregroundColor(color)
        }
    }
}
