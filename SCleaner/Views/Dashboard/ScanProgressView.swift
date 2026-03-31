import SwiftUI

/// Animated scan progress bar with label.
/// Shows combined progress: scanning (0-40%), analyzing (40-90%), done (100%).
struct ScanProgressView: View {
    let progress: ScanProgress

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))

                    Capsule()
                        .fill(ColorTokens.primaryBlue)
                        .frame(width: max(0, geo.size.width * fillWidth))
                }
            }
            .frame(height: 8)

            // Label
            HStack {
                if progress.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(ColorTokens.primaryBlue)
                }

                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.secondaryText)

                Spacer()

                if progress.isScanning {
                    Text(percentageText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
        .padding(.horizontal, AppConstants.UI.horizontalPadding)
        .animation(.easeInOut(duration: 0.3), value: fillWidth)
    }

    private var fillWidth: CGFloat {
        CGFloat(progress.progressFraction)
    }

    private var statusText: String {
        switch progress {
        case .idle:
            return NSLocalizedString("scan.readyToScan", comment: "")
        case .scanning(let processed, let total):
            return String(format: NSLocalizedString("scan.scanning", comment: ""), processed, total)
        case .partialResult(let processed, let total, _):
            return String(format: NSLocalizedString("scan.scanning", comment: ""), processed, total)
        case .hashing(let processed, let total):
            return String(format: NSLocalizedString("scan.analyzingPhotos", comment: ""), processed, total)
        case .detecting:
            return NSLocalizedString("scan.analyzingPhotos", comment: "")
        case .completed:
            return NSLocalizedString("scan.completed", comment: "")
        case .failed(let message):
            return String(format: NSLocalizedString("scan.error", comment: ""), message)
        }
    }

    private var percentageText: String {
        let pct = Int(fillWidth * 100)
        return "\(pct)%"
    }
}
