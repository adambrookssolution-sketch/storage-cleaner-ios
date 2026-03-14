import SwiftUI

/// Card component for a single TrashedFile in the trash bin.
struct TrashItemCardView: View {
    let file: TrashedFile
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var thumbnailImage: UIImage?

    private var fileType: DownloadedFileType {
        DownloadedFileType(rawValue: file.fileType) ?? .other
    }

    private var canShowThumbnail: Bool {
        fileType == .image
    }

    private var storedFileURL: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs
            .appendingPathComponent(AppConstants.TrashBin.directoryName, isDirectory: true)
            .appendingPathComponent(file.storedFileName)
    }

    var body: some View {
        HStack(spacing: 12) {
            // File type icon or thumbnail preview
            if let uiImage = thumbnailImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fileType.iconColor.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Image(systemName: fileType.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(fileType.iconColor)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.originalFileName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ColorTokens.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.formattedSize)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTokens.secondaryText)

                    Text("Excluído: \(file.formattedDeletionDate)")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTokens.tertiaryText)
                }

                // Days until purge badge
                Text("\(file.daysUntilPurge) dias restantes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        file.daysUntilPurge <= 7
                            ? ColorTokens.destructiveRed
                            : ColorTokens.warningOrange
                    )
                    .clipShape(Capsule())
            }

            Spacer()

            // Selection checkbox
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? ColorTokens.destructiveRed : Color(.systemGray3),
                        lineWidth: 2
                    )
                    .frame(width: 26, height: 26)

                if isSelected {
                    Circle()
                        .fill(ColorTokens.destructiveRed)
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
                    isSelected ? ColorTokens.destructiveRed : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onTapGesture { onToggle() }
        .task {
            guard canShowThumbnail, thumbnailImage == nil, let url = storedFileURL else { return }
            thumbnailImage = await Self.loadThumbnailAsync(from: url)
        }
    }

    private static func loadThumbnailAsync(from url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                // Downscale to thumbnail size
                let maxDimension: CGFloat = 100
                let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: thumbnail)
            }
        }
    }
}
