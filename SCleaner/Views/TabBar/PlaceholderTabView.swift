import SwiftUI

/// Placeholder view for tabs that are not yet implemented (Contacts, Emails, Compress)
struct PlaceholderTabView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(ColorTokens.primaryBlue.opacity(0.3))

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text(NSLocalizedString("tab.comingSoon", comment: ""))
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.secondaryText)

            Text(NSLocalizedString("tab.comingSoonMessage", comment: ""))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.screenBackground.ignoresSafeArea())
    }
}
