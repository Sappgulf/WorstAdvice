import SwiftUI

// MARK: - Theme

/// Centralized design tokens for the app.
enum Theme {

    // MARK: Colors (adaptive light/dark)

    static let backgroundTop = Color("BackgroundTop")
    static let backgroundBottom = Color("BackgroundBottom")

    // Fallback computed gradients when asset catalog colors are absent
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(light: .init(white: 0.97), dark: .init(white: 0.07)),
                Color(light: .init(white: 0.93), dark: .init(white: 0.04))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var cardFill: some ShapeStyle {
        Color(light: .white.opacity(0.85), dark: .white.opacity(0.06))
    }

    static var cardBorder: some ShapeStyle {
        Color(light: .black.opacity(0.04), dark: .white.opacity(0.08))
    }

    static let accentTint = Color(light: .init(red: 0.15, green: 0.15, blue: 0.15),
                                  dark: .init(white: 0.92))

    static let subtleGlow = Color(light: .black.opacity(0.03), dark: .white.opacity(0.03))

    // MARK: Tier colors (subtle, neutral tones that darken with tier)

    static func tierAccent(_ tier: AdviceTier) -> Color {
        switch tier {
        case .tier1: return Color(light: .init(white: 0.55), dark: .init(white: 0.50))
        case .tier2: return Color(light: .init(white: 0.40), dark: .init(white: 0.62))
        case .tier3: return Color(light: .init(white: 0.25), dark: .init(white: 0.75))
        case .tier4: return Color(light: .init(white: 0.10), dark: .init(white: 0.92))
        }
    }

    // MARK: Typography

    static let headlineFont: Font = .system(.largeTitle, design: .serif, weight: .bold)
    static let subheadlineFont: Font = .system(.subheadline, design: .serif, weight: .regular)
    static let cardFont: Font = .system(.title3, design: .serif, weight: .medium)
    static let buttonFont: Font = .system(.headline, design: .serif, weight: .semibold)
    static let captionFont: Font = .system(.caption, design: .serif, weight: .regular)

    // MARK: Dimensions

    static let cardCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 32
    static let screenPadding: CGFloat = 24
}

// MARK: - Adaptive Color Helper

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase)
                .mask(content)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    phase = 40
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
