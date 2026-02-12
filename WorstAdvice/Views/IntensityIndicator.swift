import SwiftUI

// MARK: - IntensityIndicator

/// Four ascending bars. Filled bars use tier-aware color. Unfilled are ghosted.
struct IntensityIndicator: View {

    let tier: AdviceTier
    var showLabel: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(index <= tier.rawValue
                              ? Theme.tierAccent(tier)
                              : Color.primary.opacity(0.10))
                        .frame(width: 16, height: barHeight(for: index))
                }
            }
            .frame(height: 18, alignment: .bottom)

            if showLabel {
                Text("Tier \(tier.rawValue)")
                    .font(.system(.caption2, design: .serif, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tier)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 5
        let step: CGFloat = 3.5
        return base + step * CGFloat(index - 1)
    }
}

#Preview {
    VStack(spacing: 20) {
        IntensityIndicator(tier: .tier1, showLabel: true)
        IntensityIndicator(tier: .tier2, showLabel: true)
        IntensityIndicator(tier: .tier3, showLabel: true)
        IntensityIndicator(tier: .tier4, showLabel: true)
    }
    .padding()
}
