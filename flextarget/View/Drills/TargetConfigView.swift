import SwiftUI

struct TargetConfigView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width * 0.4
            let frameHeight = geometry.size.height * 0.35
            
            VStack(spacing: 0) {
                // Top Bar with back icon and title
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Target #1")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to center the title
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(height: 60)
                
                // Middle part: Rectangle frame
                VStack {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 10)
                        .frame(width: frameWidth, height: frameHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Label above horizontal scroller
                HStack {
                    Text("Please select a available target")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                
                // Bottom part: Horizontal scroller of icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack {
                                Image(systemName: iconNames[index % iconNames.count])
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(8)
                                
                                Text("Item \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 100)
                
                // Two buttons below the horizontal scroller
                HStack(spacing: 20) {
                    Button(action: {
                        // Add Next button action
                    }) {
                        Text("Add Next")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Complete button action
                    }) {
                        Text("Complete")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // Sample icon names for the horizontal scroller
    private let iconNames = [
        "star.fill",
        "heart.fill",
        "bell.fill",
        "camera.fill",
        "gear",
        "folder.fill",
        "calendar",
        "book.fill",
        "music.note",
        "gamecontroller.fill"
    ]
}

#Preview {
    TargetConfigView()
}
