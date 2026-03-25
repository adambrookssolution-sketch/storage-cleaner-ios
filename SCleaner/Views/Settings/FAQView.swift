import SwiftUI

/// Frequently Asked Questions screen
struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(question: String, answer: String)] = [
        (
            NSLocalizedString("faq.q1.title", comment: ""),
            NSLocalizedString("faq.q1.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q2.title", comment: ""),
            NSLocalizedString("faq.q2.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q3.title", comment: ""),
            NSLocalizedString("faq.q3.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q4.title", comment: ""),
            NSLocalizedString("faq.q4.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q5.title", comment: ""),
            NSLocalizedString("faq.q5.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q6.title", comment: ""),
            NSLocalizedString("faq.q6.answer", comment: "")
        ),
        (
            NSLocalizedString("faq.q7.title", comment: ""),
            NSLocalizedString("faq.q7.answer", comment: "")
        )
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(faqs.indices, id: \.self) { index in
                    DisclosureGroup {
                        Text(faqs[index].answer)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                            .padding(.vertical, 4)
                    } label: {
                        Text(faqs[index].question)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ColorTokens.primaryText)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("faq.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
    }
}
