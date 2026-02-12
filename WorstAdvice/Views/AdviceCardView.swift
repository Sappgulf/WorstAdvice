import SwiftUI

// MARK: - AdviceCardView

struct AdviceCardView: View {

    let text: String
    let tier: AdviceTier
    let category: AdviceCategory?
    let animationID: UUID

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            // Category tag
            if let cat = category {
                Text(cat.rawValue.uppercased())
                    .font(.system(.caption2, design: .serif, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.tertiary)
            }

            // Advice text
            Text(text)
                .font(Theme.cardFont)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .id(animationID)
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.95))
                            .combined(with: .offset(y: 8)),
                        removal: .opacity
                            .combined(with: .scale(scale: 1.02))
                            .combined(with: .offset(y: -4))
                    )
                )

            // Intensity bar
            IntensityIndicator(tier: tier, showLabel: true)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
                .shadow(color: .black.opacity(0.02), radius: 4, y: 2)
        }
        .padding(.horizontal, Theme.screenPadding)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        AdviceCardView(
            text: "Salt your food before tasting it. You already know what it needs. Trust yourself.",
            tier: .tier2,
            category: .daily,
            animationID: UUID()
        )
    }
}
