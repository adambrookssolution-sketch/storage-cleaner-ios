import SwiftUI

/// Custom deletion confirmation sheet showing what will be deleted.
struct DeletionConfirmationView: View {
    let selectedCount: Int
    let savedBytes: Int64
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.destructiveRed)

            Text("Excluir \(selectedCount) fotos?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Libere \(savedBytes.formattedSize) de espaço.\nAs fotos serão movidas para Apagados Recentemente por 30 dias.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button("Excluir fotos") {
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
