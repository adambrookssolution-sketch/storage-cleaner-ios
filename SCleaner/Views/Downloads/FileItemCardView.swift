import SwiftUI

/// Reusable card component for a single DownloadedFile.
struct FileItemCardView: View {
    let file: DownloadedFile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.fileType.iconColor.opacity(0.12))
                    .frame(width: 50, height: 50)

                Image(systemName: file.fileType.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(file.fileType.iconColor)
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ColorTokens.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.formattedSize)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTokens.secondaryText)

                    Text(file.formattedModificationDate)
                        .font(.system(size: 13))
                        .foregroundColor(ColorTokens.tertiaryText)
                }

                if file.isStale {
                    Text("6+ meses sem uso")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ColorTokens.warningOrange)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Selection checkbox
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? ColorTokens.primaryBlue : Color(.systemGray3),
                        lineWidth: 2
                    )
                    .frame(width: 26, height: 26)

                if isSelected {
                    Circle()
                        .fill(ColorTokens.primaryBlue)
                        .frame(width: 26, height: 26)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cardCornerRadius)
                .strokeBorder(
                    isSelected ? ColorTokens.primaryBlue : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onTapGesture { onToggle() }
    }
}
