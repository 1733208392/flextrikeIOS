import SwiftUI

struct AboutUsView: View {
    var body: some View {
        WebView(htmlFileName: "aboutus")
            .navigationTitle(NSLocalizedString("about_us", comment: "About Us navigation title"))
            .edgesIgnoringSafeArea(.all)
    }
}
