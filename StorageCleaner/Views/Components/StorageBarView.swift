import SwiftUI

/// Gradient storage bar with usage label — matches reference app design
struct StorageBarView: View {
    let usedBytes: Int64
    let totalBytes: Int64
    var showLabel: Bool = true
    var height: CGFloat = 14
    @State private var animatedRatio: CGFloat = 0

    private var ratio: CGFloat {
        guard totalBytes > 0 else { return 0 }
        return min(CGFloat(usedBytes) / CGFloat(totalBytes), 1.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: height)

                    // Gradient fill
                    Capsule()
                        .fill(ColorTokens.storageBarGradient)
                        .frame(width: max(0, geo.size.width * animatedRatio), height: height)
                }
            }
            .frame(height: height)

            if showLabel {
                storageLabel
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animatedRatio = ratio
            }
        }
        .onChange(of: ratio) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedRatio = newValue
            }
        }
    }

    private var storageLabel: some View {
        (
            Text("\(usedBytes.formattedGBInteger)")
                .font(.system(size: 17, weight: .bold))
            + Text(" de ")
                .font(.system(size: 17, weight: .regular))
            + Text("\(totalBytes.formattedGBInteger)")
                .font(.system(size: 17, weight: .bold))
            + Text(" GB ")
                .font(.system(size: 17, weight: .regular))
            + Text("usados")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(ColorTokens.destructiveRed)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct StorageBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            StorageBarView(
                usedBytes: 120_000_000_000,
                totalBytes: 128_000_000_000
            )

            StorageBarView(
                usedBytes: 50_000_000_000,
                totalBytes: 256_000_000_000
            )

            StorageBarView(
                usedBytes: 10_000_000_000,
                totalBytes: 64_000_000_000,
                showLabel: false,
                height: 8
            )
        }
        .padding(40)
    }
}
#endif
