//
//  WebView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/13.
//


import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let fileName: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "html") {
            uiView.loadFileURL(url, allowingReadAccessTo: url)
        }
    }
}

// Usage in your SwiftUI view
struct FAQViewTest: View {
    var body: some View {
        WebView(fileName: "FAQ")
            .edgesIgnoringSafeArea(.all)
    }
}
