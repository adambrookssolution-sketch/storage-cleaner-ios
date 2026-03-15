import SwiftUI

/// Animated scan progress bar with label.
/// Shows combined progress: scanning (0-40%), analyzing (40-90%), finalizing (90-100%).
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

    /// Combined progress: scanning = 0→40%, hashing = 40→90%, completed = 100%
    private var fillWidth: CGFloat {
        switch progress {
        case .scanning(let processed, let total):
            guard total > 0 else { return 0 }
            let phase1 = Double(processed) / Double(total)
            return CGFloat(phase1 * 0.4)  // 0% → 40%
        case .hashing(let processed, let total):
            guard total > 0 else { return 0.4 }
            let phase2 = Double(processed) / Double(total)
            return CGFloat(0.4 + phase2 * 0.5)  // 40% → 90%
        case .completed:
            return 1.0
        default:
            return 0
        }
    }

    private var statusText: String {
        switch progress {
        case .idle:
            return "Pronto para escanear"
        case .scanning(let processed, let total):
            return "Escaneando… \(processed) de \(total)"
        case .hashing(let processed, let total):
            return "Analisando fotos… \(processed) de \(total)"
        case .completed:
            return "Escaneamento concluído"
        case .failed(let message):
            return "Erro: \(message)"
        }
    }

    private var percentageText: String {
        let pct = Int(fillWidth * 100)
        return "\(pct)%"
    }
}
