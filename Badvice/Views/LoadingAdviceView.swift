import SwiftUI
import UIKit

struct LoadingAdviceView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    private var accessibilityReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    private var effectiveReduceMotion: Bool {
        reduceMotion || accessibilityReduceMotionEnabled
    }
    private var accentColor: Color { Theme.accent(for: theme) }
    private var cardColor: Color { Theme.cardColor(for: theme) }
    private var primaryTextColor: Color { Theme.primaryText(for: theme) }
    private var secondaryTextColor: Color { Theme.secondaryText(for: theme) }

    @State private var ringRotation: Double = 0
    @State private var ringPulse = false

    private let loadingPhrase = "Summoning bad judgment..."

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor.opacity(0.98))
                .overlay {
                    LinearGradient(
                        colors: [accentColor.opacity(0.08), .clear, .black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                }

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.18), lineWidth: 4)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0.12, to: 0.82)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.9), accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(effectiveReduceMotion ? 0 : ringRotation))
                        .animation(
                            effectiveReduceMotion
                                ? nil
                                : .linear(duration: 0.85).repeatForever(autoreverses: false),
                            value: ringRotation
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .scaleEffect(ringPulse ? 1.0 : 0.92)
                        .animation(
                            effectiveReduceMotion
                                ? nil
                                : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: ringPulse
                        )
                }

                Text(loadingPhrase)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)

                Text("Generating advice")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(secondaryTextColor.opacity(0.8))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generating advice")
        .accessibilityValue(loadingPhrase)
        .onAppear {
            ringPulse = true
            guard !effectiveReduceMotion else { return }
            ringRotation = 360
        }
        .onDisappear {
            ringRotation = 0
            ringPulse = false
        }
    }
}
