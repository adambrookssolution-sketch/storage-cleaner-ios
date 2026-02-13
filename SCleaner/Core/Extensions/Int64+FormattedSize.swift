import Foundation

extension Int64 {
    /// Formats bytes into human-readable string like "32.28 GB" or "78.7 MB"
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }

    /// Formats as GB with 2 decimal places: "32.28"
    var formattedGB: String {
        let gb = Double(self) / 1_073_741_824.0
        if gb >= 100 {
            return String(format: "%.0f", gb)
        } else if gb >= 10 {
            return String(format: "%.1f", gb)
        }
        return String(format: "%.2f", gb)
    }

    /// Formats as GB integer: "128"
    var formattedGBInteger: String {
        let gb = Double(self) / 1_073_741_824.0
        return String(format: "%.0f", gb)
    }
}
