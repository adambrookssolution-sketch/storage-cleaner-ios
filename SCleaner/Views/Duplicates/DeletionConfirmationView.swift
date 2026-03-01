import SwiftUI

/// Custom deletion confirmation sheet showing what will be deleted.
struct DeletionConfirmationView: View {
    let selectedCount: Int
    let savedBytes: Int64
    let itemLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        selectedCount: Int,
        savedBytes: Int64,
        itemLabel: String = "fotos",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedCount = selectedCount
        self.savedBytes = savedBytes
        self.itemLabel = itemLabel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.destructiveRed)

            Text("Excluir \(selectedCount) \(itemLabel)?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Libere \(savedBytes.formattedSize) de espaço.\nOs \(itemLabel) serão movidos para a Lixeira por 30 dias.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button("Excluir \(itemLabel)") {
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
