import SwiftUI

struct FAQView: View {
    let faqs = [
        ("How do I set up the target", "targetSetup"),
        ("Why does the app keep connecting to the target?", "bleConnect"),
        ("Why are no shots being captured?", "rectify"),
        ("How can I view my drill results?", "results")
    ]
    
    private func faqRow(question: String, answer: String) -> some View {
        NavigationLink(destination: FAQDetailView(htmlFileName: answer.isEmpty ? "" : answer)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question)
                    .font(.headline)
                    .foregroundColor(.black)
                if !answer.isEmpty {
                    Text(answer)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Frequently Asked Questions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 16)
                        .padding(.horizontal)
                    
                    ForEach(faqs, id: \.0) { question, answer in
                        faqRow(question: question, answer: answer)
                    }
                }
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
