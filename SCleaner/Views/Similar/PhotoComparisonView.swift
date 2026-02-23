import SwiftUI

/// Side-by-side comparison of two photos with metadata.
struct PhotoComparisonView: View {
    let leftPhoto: PhotoHash
    let rightPhoto: PhotoHash
    let leftThumbnail: UIImage?
    let rightThumbnail: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                photoColumn(photo: leftPhoto, image: leftThumbnail, label: "Original")
                photoColumn(photo: rightPhoto, image: rightThumbnail, label: "Similar")
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                metadataRow(
                    label: "Resolução",
                    left: "\(leftPhoto.pixelWidth)×\(leftPhoto.pixelHeight)",
                    right: "\(rightPhoto.pixelWidth)×\(rightPhoto.pixelHeight)"
                )
                metadataRow(
                    label: "Tamanho",
                    left: leftPhoto.fileSize.formattedSize,
                    right: rightPhoto.fileSize.formattedSize
                )
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Comparar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func photoColumn(photo: PhotoHash, image: UIImage?, label: String) -> some View {
        VStack(spacing: 8) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .overlay(ProgressView())
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func metadataRow(label: String, left: String, right: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ColorTokens.secondaryText)
                .frame(width: 80, alignment: .leading)

            Text(left)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.primaryText)
                .frame(maxWidth: .infinity)

            Text(right)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.primaryText)
                .frame(maxWidth: .infinity)
        }
    }
}
