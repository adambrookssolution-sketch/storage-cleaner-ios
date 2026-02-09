import SwiftUI

/// Stats line: "XXXX arquivos • XX.XX GB do armazenamento"
struct StatsLineView: View {
    let fileCount: Int
    let totalSize: String
    let isLoaded: Bool

    var body: some View {
        if isLoaded {
            HStack(spacing: 0) {
                Text("\(fileCount)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(" arquivos • ")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)

                Text(totalSize)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(" do armazenamento")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
            }
            .padding(.horizontal, AppConstants.UI.horizontalPadding)
            .transition(.opacity)
        }
    }
}
