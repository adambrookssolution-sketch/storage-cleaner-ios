import SwiftUI

/// Full-screen success view shown after photos are deleted.
struct DeletionSuccessView: View {
    let result: DeleteResult
    let onDismiss: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(ColorTokens.successGreen.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ColorTokens.successGreen)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            VStack(spacing: 8) {
                Text("\(result.deletedCount) fotos excluídas")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTokens.primaryText)

                Text("\(result.savedBytes.formattedSize) liberados")
                    .font(.system(size: 18))
                    .foregroundColor(ColorTokens.successGreen)
            }

            if result.failedCount > 0 {
                Text("\(result.failedCount) fotos não puderam ser excluídas")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTokens.warningOrange)
            }

            Spacer()

            Button("Concluído") {
                onDismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppConstants.UI.horizontalPadding)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.screenBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}
