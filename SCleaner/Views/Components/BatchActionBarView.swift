import SwiftUI

/// Sticky bottom bar showing selection count and delete button.
struct BatchActionBarView: View {
    let selectedCount: Int
    let potentialSavings: Int64
    let accentColor: Color
    let onDelete: () -> Void

    init(
        selectedCount: Int,
        potentialSavings: Int64,
        accentColor: Color = ColorTokens.destructiveRed,
        onDelete: @escaping () -> Void
    ) {
        self.selectedCount = selectedCount
        self.potentialSavings = potentialSavings
        self.accentColor = accentColor
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount) selecionado(s)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryText)

                    if potentialSavings > 0 {
                        Text("Liberar \(potentialSavings.formattedSize)")
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.secondaryText)
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Text("Excluir")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selectedCount > 0 ? accentColor : Color(.systemGray4))
                        )
                }
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ColorTokens.cardBackground
                    .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
            )
        }
    }
}
