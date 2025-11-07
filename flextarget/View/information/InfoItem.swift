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
    let type: ItemType

    enum ItemType {
        case intro, help, about, privacy
    }
}

struct InformationPage: View {
    let items: [InfoItem] = [
        InfoItem(icon: "questionmark.circle", title: "Help", description: "Get assistance and FAQs.", type: .help),
        InfoItem(icon: "play.circle", title: "Intros", description: "Introduction Videos for the New User.", type: .intro),
        InfoItem(icon: "person.2.circle", title: "About Us", description: "Learn more about our team.", type: .about),
        InfoItem(icon: "lock.shield", title: "Privacy Policy", description: "Read our privacy practices.", type: .privacy)
    ]
    
    @ViewBuilder
    func destination(for type: InfoItem.ItemType) -> some View {
        switch type {
        case .help:
            FAQView()
        case .intro:
            OrientationView(isFromInfoItem: true)
        case .about:
            AboutUsView()
        case .privacy:
            PrivacyPolicyView()
        }
    }
    
    var body: some View {
        NavigationView {
            List(items) { item in
                NavigationLink(destination: destination(for: item.type))
                {
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
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
}
