import SwiftUI

/// Animated scan progress bar with label
struct ScanProgressView: View {
    let progress: ScanProgress

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(.systemGray5))

                    // Fill
                    Capsule()
                        .fill(ColorTokens.primaryBlue)
                        .frame(width: max(0, geo.size.width * fillWidth))
                        .shimmer(isActive: progress.isScanning && fillWidth < 0.05)
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

    // MARK: - Computed Properties

    private var fillWidth: CGFloat {
        CGFloat(progress.progressFraction)
    }

    private var statusText: String {
        switch progress {
        case .idle:
            return "Pronto para escanear"
        case .scanning(let processed, let total):
            return "Escaneando… \(processed) de \(total)"
        case .completed:
            return "Escaneamento concluído"
        case .failed(let message):
            return "Erro: \(message)"
        }
    }

    private var percentageText: String {
        let pct = Int(progress.progressFraction * 100)
        return "\(pct)%"
    }
}
