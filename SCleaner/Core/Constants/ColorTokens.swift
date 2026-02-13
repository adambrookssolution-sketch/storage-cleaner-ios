import SwiftUI

enum ColorTokens {
    // MARK: - Primary Colors
    static let primaryBlue = Color(hex: "007AFF")
    static let destructiveRed = Color(hex: "FF3B30")
    static let warningOrange = Color(hex: "FF9500")
    static let successGreen = Color(hex: "34C759")

    // MARK: - Storage Bar Gradient
    static let storageBarGradient = LinearGradient(
        colors: [Color(hex: "FF6B6B"), Color(hex: "FF3B30"), Color(hex: "CC0000")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Backgrounds
    static let cardBackground = Color(.systemBackground)
    static let screenBackground = Color(.systemGroupedBackground)
    static let elevatedBackground = Color(.secondarySystemGroupedBackground)

    // MARK: - Text
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    // MARK: - Badge
    static let badgeBackground = Color(hex: "007AFF")
    static let badgeText = Color.white

    // MARK: - Separator
    static let separator = Color(.separator)
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
