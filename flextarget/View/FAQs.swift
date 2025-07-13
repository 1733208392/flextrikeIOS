import SwiftUI

struct FAQView: View {
    let faqs = [
        ("How do I set up the target", ""),
        ("Why does the app keep connecting to the target?", ""),
        ("Why are no shots being captured?", ""),
        ("How can I view my drill results?", "")
    ]

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
                        NavigationLink(destination: FAQDetailView(question: question, answer: answer)) {
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
                }
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}

struct FAQDetailView: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(question)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            if !answer.isEmpty {
                Text(answer)
                    .font(.body)
            } else {
                Text("Answer coming soon.")
                    .foregroundColor(.secondary)
                    .font(.body)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("FAQ")
    }
}
