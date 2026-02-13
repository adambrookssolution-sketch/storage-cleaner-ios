import SwiftUI

/// Blue full-width button style matching the reference app design
struct PrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = ColorTokens.primaryBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.UI.buttonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary button style (outline)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(ColorTokens.primaryBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius)
                    .stroke(ColorTokens.primaryBlue, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension View {
    func primaryButtonStyle(color: Color = ColorTokens.primaryBlue) -> some View {
        self.buttonStyle(PrimaryButtonStyle(backgroundColor: color))
    }
}
