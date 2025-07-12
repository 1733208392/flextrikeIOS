import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("GrwolfLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 360, height: 360)
        }
    }
}
