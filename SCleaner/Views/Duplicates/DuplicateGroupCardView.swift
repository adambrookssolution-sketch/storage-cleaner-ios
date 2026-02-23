import SwiftUI

/// Card displaying one duplicate group with horizontally scrollable selectable photos.
struct DuplicateGroupCardView: View {
    let group: DuplicateGroup
    let selectedIds: Set<String>
    let thumbnailCache: [String: UIImage]
    let onToggleSelection: (String) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(group.count) fotos duplicadas")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Spacer()

                Text(group.totalSize.formattedSize)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.secondaryText)
            }

            // Horizontal scroll of photos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                        SelectablePhotoView(
                            assetId: photo.id,
                            isSelected: selectedIds.contains(photo.id),
                            isBestResult: index == group.bestResultIndex,
                            thumbnail: thumbnailCache[photo.id],
                            onToggle: { onToggleSelection(photo.id) }
                        )
                        .frame(width: 110)
                    }
                }
            }

            // Group action buttons
            HStack(spacing: 12) {
                Button("Manter todos") {
                    onDeselectAll()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.primaryBlue)

                Button("Selecionar duplicatas") {
                    onSelectAll()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.destructiveRed)

                Spacer()
            }
        }
        .padding(16)
        .cardStyle()
    }
}
