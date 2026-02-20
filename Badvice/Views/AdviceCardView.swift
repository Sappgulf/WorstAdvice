import SwiftUI

struct AdviceCardView: View {
    let record: AdviceRecord
    let theme: ThemeMode
    var reduceMotion: Bool = false

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var lastRecordID: UUID = UUID()
    
    // Triple-A Polish: Tilt & Parallax State
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0
    
    // Performance: Cache computed values
    @State private var cachedShadow: (color: Color, radius: CGFloat, y: CGFloat)?
    @State private var cachedAccent: Color?

    private let moderation = ContentModeration()

    private var isMotionReduced: Bool {
        reduceMotion || accessibilityReduceMotion
    }
    
    // Performance: Memoize expensive computations
    private var primaryShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        if let cached = cachedShadow {
            return cached
        }
        let shadow = Theme.cardShadow(for: theme)
        return shadow
    }
    
    private var accentColor: Color {
        if let cached = cachedAccent {
            return cached
        }
        return Theme.accent(for: theme)
    }

    var body: some View {
        let accent = accentColor
        let tertiaryStroke = Theme.secondaryAccent(for: theme)?.opacity(0.4) ?? accent.opacity(0.3)
        let primaryText = Theme.primaryText(for: theme)
        let secondaryText = Theme.secondaryText(for: theme)
        let cardColor = Theme.cardColor(for: theme)
        let glassOpacity = Theme.glassMorphismOpacity(for: theme)
        let shadow = primaryShadow
        let secondaryShadow = Theme.cardSecondaryShadow(for: theme)
        let glowColor = Theme.glowColor(for: theme)
        let safetyScore = moderation.safetyScore(for: record.adviceLine + " " + (record.rationaleLine ?? ""))

        VStack(alignment: .leading, spacing: 0) {
            // Meta row
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Label(record.category.title, systemImage: record.category.icon)
                        .font(Theme.chipFont)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.13))
                        )

                    Spacer()

                    SafetyIndicator(score: safetyScore, theme: theme)
                        .accessibilityLabel("Safety score")

                    IntensityIndicator(tone: record.tone, theme: theme)
                        .accessibilityLabel("Tone intensity")
                }

                Label(record.tone.title, systemImage: "dial.medium")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(secondaryText)
            }

            // Decorative quote mark
            Text("\u{201C}")
                .font(.system(size: 56, weight: .heavy, design: .serif))
                .foregroundStyle(accent.opacity(0.22))
                .frame(height: 24)
                .padding(.top, 10)
                .offset(y: 4)

            // Advice text
            Text(record.adviceLine)
                .font(Theme.cardFont)
                .foregroundStyle(primaryText)
                .lineSpacing(5)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
                .accessibilityLabel("Advice")
                .accessibilityValue(record.adviceLine)

            if let rationale = record.rationaleLine, !rationale.isEmpty {
                Rectangle()
                    .fill(secondaryText.opacity(0.15))
                    .frame(height: 1)
                    .padding(.vertical, 14)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent.opacity(0.65))
                        .padding(.top, 2)
                    Text(rationale)
                        .font(Theme.bodyFont)
                        .foregroundStyle(secondaryText)
                        .accessibilityLabel("Fake rationale")
                        .accessibilityValue(rationale)
                }
            } else {
                Spacer().frame(height: 12)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(cardColor)
                
                // Add Glassmorphism depth with improved opacity
                if theme != .minimal {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(glassOpacity)
                }
                
                // Add subtle inner glow for glow-supporting themes
                if let glowColor, !isMotionReduced {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(glowColor.opacity(0.15), lineWidth: 2)
                        .blur(radius: 4)
                }
            }
            .conditionalDrawingGroup(!isMotionReduced)
        }

        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.5),
                            accent.opacity(0.15),
                            tertiaryStroke
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay {
            // Shimmer effect
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.25), .white.opacity(0.0)],
                        startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .allowsHitTesting(false)
                .opacity(isMotionReduced ? 0 : (shimmerOffset >= 0 && shimmerOffset <= 1.0 ? 1 : 0))
            
            // Cybernetic Ripple Effect
            if theme == .cybernetic {
                Circle()
                    .stroke(accent.opacity(rippleOpacity), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .allowsHitTesting(false)
            }
        }
        .shadow(
            color: shadow.color,
            radius: shadow.radius,
            y: shadow.y
        )
        .overlay {
            // Secondary shadow for enhanced depth on select themes
            if let secondaryShadow {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .shadow(
                        color: secondaryShadow.color,
                        radius: secondaryShadow.radius,
                        y: secondaryShadow.y
                    )
                    .allowsHitTesting(false)
            }
        }
        // Apply 3D rotation based on drag position
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationX), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationY), axis: (x: 0, y: 1, z: 0))
        .overlay {
            // Dynamic Glint Overlay (Triple-A Polish)
            if theme != .minimal && !isMotionReduced {
                GeometryReader { geo in
                    let glintX = (rotationY / 8.0) * (geo.size.width * 0.5)
                    let glintY = (rotationX / -8.0) * (geo.size.height * 0.5)
                    
                    RadialGradient(
                        colors: [
                            .white.opacity(0.18),
                            .white.opacity(0.04),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5 + (glintX / geo.size.width), y: 0.5 + (glintY / geo.size.height)),
                        startRadius: 0,
                        endRadius: geo.size.width * 0.95
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    guard !isMotionReduced else { return }
                    let maxRotation: Double = 8
                    let horizontalWeight = abs(value.translation.width)
                    let verticalWeight = abs(value.translation.height)
                    // Keep vertical list scrolling responsive by only reacting to mostly horizontal drags.
                    guard horizontalWeight >= verticalWeight * 0.8 else { return }

                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                        let nextY = Double(value.translation.width / 18)
                        let nextX = Double(-value.translation.height / 24)
                        rotationY = min(max(nextY, -maxRotation), maxRotation)
                        rotationX = min(max(nextX, -maxRotation), maxRotation)
                    }
                }
                .onEnded { _ in
                    guard !isMotionReduced else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        rotationX = 0
                        rotationY = 0
                    }
                }
        )
        .onChange(of: record.id) { _, newID in
            guard newID != lastRecordID else { return }
            lastRecordID = newID
            
            // Refresh cached visuals for the new card.
            cachedShadow = Theme.cardShadow(for: theme)
            cachedAccent = Theme.accent(for: theme)

            guard !isMotionReduced else {
                shimmerOffset = -1.0
                rotationX = 0
                rotationY = 0
                return
            }
            
            // "Deal" Animation: Triple-A bounce and haptic feel
            shimmerOffset = -0.3
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 1.3
            }
            
            // Pop out and slam down effect
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                rotationX = -12 // Deeper tilt back
            }
            
            // Trigger Cybernetic Ripple
            if theme == .cybernetic {
                rippleScale = 0.5
                rippleOpacity = 0.8
                withAnimation(.easeOut(duration: 0.6)) {
                    rippleScale = 2.5
                    rippleOpacity = 0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    rotationX = 0
                }
            }
        }
        .onAppear {
            lastRecordID = record.id
            // Initialize cache
            cachedShadow = Theme.cardShadow(for: theme)
            cachedAccent = Theme.accent(for: theme)
            
            if isMotionReduced {
                shimmerOffset = -1.0
            }
        }
        .onChange(of: theme) { _, _ in
            cachedShadow = Theme.cardShadow(for: theme)
            cachedAccent = Theme.accent(for: theme)
            if isMotionReduced {
                shimmerOffset = -1.0
                rotationX = 0
                rotationY = 0
            }
        }
        .accessibilityElement(children: .contain)
    }
}
