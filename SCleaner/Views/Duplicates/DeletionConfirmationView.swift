import SwiftUI

/// The type of deletion, which determines the confirmation message shown.
enum DeletionDestination {
    /// Photos/videos deleted via PHPhotoLibrary → iOS "Apagados Recentemente"
    case photoLibrary
    /// Files moved to app internal trash bin (Downloads)
    case appTrashBin
    /// Permanent deletion from trash bin (no recovery)
    case permanent
}

/// Custom deletion confirmation sheet showing what will be deleted.
struct DeletionConfirmationView: View {
    let selectedCount: Int
    let savedBytes: Int64
    let itemLabel: String
    let destination: DeletionDestination
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        selectedCount: Int,
        savedBytes: Int64,
        itemLabel: String = NSLocalizedString("general.photos", comment: ""),
        destination: DeletionDestination = .photoLibrary,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedCount = selectedCount
        self.savedBytes = savedBytes
        self.itemLabel = itemLabel
        self.destination = destination
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var descriptionText: String {
        switch destination {
        case .photoLibrary:
            return String(format: NSLocalizedString("deletion.descriptionPhotoLibrary", comment: ""), savedBytes.formattedSize, itemLabel)
        case .appTrashBin:
            return String(format: NSLocalizedString("deletion.descriptionAppTrash", comment: ""), savedBytes.formattedSize, itemLabel)
        case .permanent:
            return String(format: NSLocalizedString("deletion.descriptionPermanent", comment: ""), savedBytes.formattedSize, itemLabel)
        }
    }

    private var confirmButtonText: String {
        switch destination {
        case .permanent:
            return NSLocalizedString("deletion.deletePermanently", comment: "")
        default:
            return String(format: NSLocalizedString("deletion.deleteItems", comment: ""), itemLabel)
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: destination == .permanent ? "trash.slash.fill" : "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.destructiveRed)

            Text(String(format: NSLocalizedString("deletion.confirmTitle", comment: ""), selectedCount, itemLabel))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text(descriptionText)
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button(confirmButtonText) {
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle(backgroundColor: ColorTokens.destructiveRed))
                .padding(.horizontal, 40)

                Button(NSLocalizedString("general.cancel", comment: "")) {
                    onCancel()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ColorTokens.primaryBlue)
            }

            Spacer()
        }
        .background(ColorTokens.screenBackground.ignoresSafeArea())
    }
}
