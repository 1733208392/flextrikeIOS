import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        WebView(htmlFileName: "privacy")
            .navigationTitle(NSLocalizedString("privacy_policy", comment: "Privacy Policy navigation title"))
            .edgesIgnoringSafeArea(.all)
            .mobilePhoneLayout()
    }
}

