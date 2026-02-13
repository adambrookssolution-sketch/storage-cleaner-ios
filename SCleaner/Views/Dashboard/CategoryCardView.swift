import SwiftUI

/// Reusable category card matching the reference app design.
/// Shows category title, thumbnail preview area, and a blue badge with count/size.
struct CategoryCardView: View {
    let cardData: DashboardViewModel.CategoryCardData
    let thumbnailCache: [String: UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row
            HStack {
                Text(cardData.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ColorTokens.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTokens.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Thumbnail area
            thumbnailSection
                .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            // Badge
            if !cardData.isEmpty {
                badgeView
                    .padding(.horizontal, 16)
            }

            Spacer().frame(height: 16)
        }
        .cardStyle()
    }

    // MARK: - Thumbnail Section

    @ViewBuilder
    private var thumbnailSection: some View {
        if cardData.isEmpty {
            // Empty state
            emptyThumbnailView
        } else if cardData.category.showsComparisonLayout {
            // Comparison layout (2 side-by-side) for duplicates/similar
            comparisonThumbnailView
        } else {
            // Single large thumbnail
            singleThumbnailView
        }
    }

    @ViewBuilder
    private var emptyThumbnailView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .frame(height: 140)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: cardData.category.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(cardData.category.iconColor.opacity(0.5))
                    Text("Nenhum item encontrado")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTokens.tertiaryText)
                }
            )
    }

    @ViewBuilder
    private var comparisonThumbnailView: some View {
        HStack(spacing: 8) {
            thumbnailImage(for: cardData.sampleAssetIds.first)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            thumbnailImage(for: cardData.sampleAssetIds.dropFirst().first)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var singleThumbnailView: some View {
        thumbnailImage(for: cardData.sampleAssetIds.first)
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func thumbnailImage(for assetId: String?) -> some View {
        if let assetId, let image = thumbnailCache[assetId] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: cardData.category.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(cardData.category.iconColor.opacity(0.4))
                )
        }
    }

    // MARK: - Badge

    private var badgeView: some View {
        HStack(spacing: 6) {
            Text(cardData.badgeTextSingleLine)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(ColorTokens.primaryBlue)
        )
    }
}
