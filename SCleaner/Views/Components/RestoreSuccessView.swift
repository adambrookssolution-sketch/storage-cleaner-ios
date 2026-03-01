import SwiftUI

/// Fullscreen success view for file restoration from trash.
struct RestoreSuccessView: View {
    let restoredCount: Int
    let failedCount: Int
    let onDismiss: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(ColorTokens.successGreen.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ColorTokens.successGreen)
                    .scaleEffect(showCheckmark ? 1 : 0.3)
                    .opacity(showCheckmark ? 1 : 0)
            }

            Text("\(restoredCount) arquivos restaurados")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Os arquivos foram restaurados ao local original.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if failedCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ColorTokens.warningOrange)

                    Text("\(failedCount) arquivos não puderam ser restaurados")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.warningOrange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.warningOrange.opacity(0.1))
                )
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Concluído")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius)
                            .fill(ColorTokens.successGreen)
                    )
            }
            .padding(.horizontal, AppConstants.UI.horizontalPadding)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.screenBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                showCheckmark = true
            }
        }
    }
}
