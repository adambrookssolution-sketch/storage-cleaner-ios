import SwiftUI

/// A thumbnail photo cell with a circular selection checkbox overlay.
/// Shows file size badge and "Melhor" badge for best result.
struct SelectablePhotoView: View {
    let assetId: String
    let isSelected: Bool
    let isBestResult: Bool
    let thumbnail: UIImage?
    let fileSize: Int64
    let onToggle: () -> Void

    init(
        assetId: String,
        isSelected: Bool,
        isBestResult: Bool,
        thumbnail: UIImage?,
        fileSize: Int64 = 0,
        onToggle: @escaping () -> Void
    ) {
        self.assetId = assetId
        self.isSelected = isSelected
        self.isBestResult = isBestResult
        self.thumbnail = thumbnail
        self.fileSize = fileSize
        self.onToggle = onToggle
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .overlay(ProgressView())
            }

            // Selection checkbox (top-right)
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isSelected ? ColorTokens.destructiveRed : Color.white.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .shadow(radius: 2)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(6)

            // Bottom overlay: "Melhor" badge (left) + size badge (right)
            VStack {
                Spacer()
                HStack {
                    // Best Result badge (bottom-left)
                    if isBestResult {
                        Text(NSLocalizedString("general.bestResultBadge", comment: ""))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(ColorTokens.primaryBlue))
                    }

                    Spacer()

                    // File size badge (bottom-right)
                    if fileSize > 0 {
                        Text(fileSize.formattedSize)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(ColorTokens.primaryBlue.opacity(0.85))
                            )
                    }
                }
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? ColorTokens.destructiveRed : Color.clear, lineWidth: 2)
        )
    }
}
