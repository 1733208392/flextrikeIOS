//
//  FAQDetailView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/14.
//
import SwiftUI

struct FAQDetailView: View {
    let question: String
    let htmlFileName: String

    var body: some View {
        WebView(htmlFileName: htmlFileName)
            .navigationTitle(question)
            .navigationBarTitleDisplayMode(.inline)
            .edgesIgnoringSafeArea(.bottom)
    }
}
