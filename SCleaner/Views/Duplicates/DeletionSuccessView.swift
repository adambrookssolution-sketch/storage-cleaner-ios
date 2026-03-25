import SwiftUI

/// Full-screen success view shown after photos are deleted.
struct DeletionSuccessView: View {
    let result: DeleteResult
    let itemLabel: String
    let destination: DeletionDestination
    let onDismiss: () -> Void

    init(
        result: DeleteResult,
        itemLabel: String = NSLocalizedString("general.photos", comment: ""),
        destination: DeletionDestination = .photoLibrary,
        onDismiss: @escaping () -> Void
    ) {
        self.result = result
        self.itemLabel = itemLabel
        self.destination = destination
        self.onDismiss = onDismiss
    }

    @State private var showCheckmark = false

    private var guidanceText: String? {
        switch destination {
        case .photoLibrary:
            return String(format: NSLocalizedString("deletion.guidancePhotoLibrary", comment: ""), itemLabel)
        case .appTrashBin:
            return String(format: NSLocalizedString("deletion.guidanceAppTrash", comment: ""), itemLabel)
        case .permanent:
            return nil
        }
    }

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
                Text(String(format: NSLocalizedString("deletion.successCount", comment: ""), result.deletedCount, itemLabel))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(String(format: NSLocalizedString("deletion.freedSpace", comment: ""), result.savedBytes.formattedSize))
                    .font(.system(size: 18))
                    .foregroundColor(ColorTokens.successGreen)
            }

            if result.failedCount > 0 {
                Text(String(format: NSLocalizedString("deletion.failedCount", comment: ""), result.failedCount, itemLabel))
                    .font(.system(size: 14))
                    .foregroundColor(ColorTokens.warningOrange)
            }

            if let guidance = guidanceText {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ColorTokens.primaryBlue)

                    Text(guidance)
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.primaryBlue.opacity(0.08))
                )
                .padding(.horizontal, AppConstants.UI.horizontalPadding)
            }

            Spacer()

            Button(NSLocalizedString("general.done", comment: "")) {
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
            ReviewPromptService.shared.recordDeletionSuccess(itemCount: result.deletedCount)
        }
    }
}
