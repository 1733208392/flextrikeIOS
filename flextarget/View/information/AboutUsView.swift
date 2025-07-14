import SwiftUI

struct AboutUsView: View {
    var body: some View {
        WebView(htmlFileName: "aboutus")
            .navigationTitle("About Us")
            .edgesIgnoringSafeArea(.all)
    }
}
