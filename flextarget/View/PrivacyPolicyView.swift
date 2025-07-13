import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 16)

                Text("Your privacy is important to us. This app does **not** collect, store, or share any personal information from users.")
                    .font(.body)

                Text("Data Collection")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                Text("""
- The app does not collect any personal data, usage data, or location data.
- No information is transmitted to external servers or third parties.
""")
                    .font(.body)

                Text("Data Usage")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                Text("""
- All features and data processing occur locally on your device.
- No user data is used for analytics, advertising, or marketing purposes.
""")
                    .font(.body)

                Text("Contact")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("If you have any questions or concerns about this privacy policy, please contact us at ")
                        .font(.body)
                    Text("business@grwolftactical.com")
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "mailto:business@grwolftactical.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                }

                Text("_Last updated: June 2024_")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Privacy Policy")
    }
}
