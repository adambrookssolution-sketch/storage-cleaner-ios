import SwiftUI

/// A thumbnail photo cell with a circular selection checkbox overlay.
/// Reused in both DuplicateGroupCardView and SimilarGroupCardView.
struct SelectablePhotoView: View {
    let assetId: String
    let isSelected: Bool
    let isBestResult: Bool
    let thumbnail: UIImage?
    let onToggle: () -> Void

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

            // Best Result badge (bottom-left)
            if isBestResult {
                VStack {
                    Spacer()
                    HStack {
                        Text("Melhor")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(ColorTokens.primaryBlue))
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? ColorTokens.destructiveRed : Color.clear, lineWidth: 2)
        )
    }
}
