import SwiftUI

struct FAQView: View {
    let faqs = [
        ("How do I set up the target?", "targetSetup", "target"),
        ("How to Use the Netlink Feature to Customize the Drill?", "netlink", "network")
    ]
    
    private func faqRow(question: String, answer: String, icon: String) -> some View {
        NavigationLink(destination: FAQDetailView(question: question, htmlFileName: answer.isEmpty ? "" : answer)) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(question)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(faqs, id: \.0) { question, answer, icon in
                    faqRow(question: question, answer: answer, icon: icon)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(NSLocalizedString("faq", comment: "FAQ navigation title"))
        .navigationBarTitleDisplayMode(.large)
        .mobilePhoneLayout()
    }
}
