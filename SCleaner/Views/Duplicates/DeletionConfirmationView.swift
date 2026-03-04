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
        itemLabel: String = "fotos",
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
            return "Libere \(savedBytes.formattedSize) de espaço.\nAs \(itemLabel) serão movidas para Apagados Recentemente do iOS por 30 dias."
        case .appTrashBin:
            return "Libere \(savedBytes.formattedSize) de espaço.\nOs \(itemLabel) serão movidos para a Lixeira do app por 30 dias."
        case .permanent:
            return "Libere \(savedBytes.formattedSize) de espaço.\nOs \(itemLabel) serão excluídos permanentemente. Esta ação não pode ser desfeita."
        }
    }

    private var confirmButtonText: String {
        switch destination {
        case .permanent:
            return "Excluir permanentemente"
        default:
            return "Excluir \(itemLabel)"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: destination == .permanent ? "trash.slash.fill" : "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.destructiveRed)

            Text("Excluir \(selectedCount) \(itemLabel)?")
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

                Button("Cancelar") {
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
