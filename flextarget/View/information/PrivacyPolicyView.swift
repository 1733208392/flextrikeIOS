import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        WebView(htmlFileName: "privacy")
            .navigationTitle("Privacy Policy")
            .edgesIgnoringSafeArea(.all)
    }
}
