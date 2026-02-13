import SwiftUI

/// Segmented horizontal progress bar for onboarding steps
/// Matches reference app: 4 horizontal capsule segments, filled = blue, unfilled = gray
struct OnboardingProgressBar: View {
    let totalSteps: Int
    let currentStep: Int  // 0-indexed
    var spacing: CGFloat = 6
    var height: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? ColorTokens.primaryBlue : Color(.systemGray4))
                    .frame(height: height)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            OnboardingProgressBar(totalSteps: 4, currentStep: 0)
            OnboardingProgressBar(totalSteps: 4, currentStep: 1)
            OnboardingProgressBar(totalSteps: 4, currentStep: 2)
            OnboardingProgressBar(totalSteps: 4, currentStep: 3)
        }
        .padding(30)
    }
}
#endif
