//
//  InfoItem.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/12.
//


import SwiftUI

struct InfoItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct InformationPage: View {
    let items: [InfoItem] = [
        InfoItem(icon: "questionmark.circle", title: "Help", description: "Get assistance and FAQs."),
        InfoItem(icon: "person.2.circle", title: "About Us", description: "Learn more about our team."),
        InfoItem(icon: "lock.shield", title: "Privacy Policy", description: "Read our privacy practices.")
    ]
    
    var body: some View {
        NavigationView {
            List(items) { item in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Information")
        }
    }
}