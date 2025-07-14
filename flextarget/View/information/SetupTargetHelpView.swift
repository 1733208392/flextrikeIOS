//
//  SVGImage.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/13.
//


import SwiftUI
import SVGKit

struct SVGImage: View {
    let name: String
    var body: some View {
        if let svgImage = SVGKImage(named: name) {
            Image(uiImage: svgImage.uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
        } else {
            Rectangle()
                .fill(Color.gray)
                .frame(width: 60, height: 60)
        }
    }
}

struct ColumnItem: Identifiable {
    let id = UUID()
    let imageName: String
    let description: String
}

struct SetupTargetHelpView: View {
    let items: [ColumnItem] = [
        .init(imageName: "accessory", description: "Description for image 1."),
        .init(imageName: "image2", description: "Description for image 2."),
        .init(imageName: "image3", description: "Description for image 3."),
        .init(imageName: "image4", description: "Description for image 4."),
        .init(imageName: "image5", description: "Description for image 5.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 16) {
                        SVGImage(name: item.imageName)
                        Text(item.description)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}
