//
//  WebView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/14.
//


import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlFileName: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
            let readAccessURL = url.deletingLastPathComponent().deletingLastPathComponent()
            uiView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
        }
    }
}
