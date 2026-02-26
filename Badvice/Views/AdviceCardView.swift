import SwiftUI

struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

struct AdviceCardView: View {
    let record: AdviceRecord
    let theme: ThemeMode
    var reduceMotion: Bool = false
    var sourceBadgeText: String? = nil

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var lastRecordID: UUID = UUID()
    
    // Triple-A Polish: Tilt & Parallax State
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0
    
    // Polish: Screen Shake
    @State private var shakeCount: Int = 0
    @State private var rotationResetTask: Task<Void, Never>?

    private var isMotionReduced: Bool {
        reduceMotion || accessibilityReduceMotion
    }

    var body: some View {
        let accent = Theme.accent(for: theme)
        let tertiaryStroke = Theme.secondaryAccent(for: theme)?.opacity(0.4) ?? accent.opacity(0.3)
        let primaryText = Theme.primaryText(for: theme)
        let secondaryText = Theme.secondaryText(for: theme)
        let cardColor = Theme.cardColor(for: theme)
        let glassOpacity = Theme.glassMorphismOpacity(for: theme)
        let shadow = Theme.cardShadow(for: theme)
        let secondaryShadow = Theme.cardSecondaryShadow(for: theme)
        let glowColor = Theme.glowColor(for: theme)
        let providerBadgeTint = Theme.secondaryAccent(for: theme) ?? accent
        let toneBadgeTint = secondaryText

        VStack(alignment: .leading, spacing: 0) {
            // Meta row
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    AdviceBadgePill(
                        text: record.category.title,
                        systemImage: record.category.icon,
                        tint: accent,
                        fill: accent.opacity(0.13),
                        stroke: .clear,
                        showsStroke: false,
                        minWidth: nil
                    )
                    .layoutPriority(1)

                    AdviceBadgePill(
                        text: record.tone.title,
                        systemImage: "dial.medium",
                        tint: toneBadgeTint,
                        fill: secondaryText.opacity(theme == .minimal ? 0.13 : 0.10),
                        stroke: secondaryText.opacity(0.12),
                        showsStroke: true,
                        minWidth: nil
                    )
                    .layoutPriority(0)

                    Spacer(minLength: 0)
                }

                if let sourceBadgeText, !sourceBadgeText.isEmpty {
                    HStack(spacing: 0) {
                        AdviceBadgePill(
                            text: sourceBadgeText,
                            systemImage: nil,
                            tint: providerBadgeTint,
                            fill: providerBadgeTint.opacity(theme == .minimal ? 0.16 : 0.14),
                            stroke: providerBadgeTint.opacity(0.25),
                            showsStroke: true,
                            minWidth: nil
                        )
                        .shadow(
                            color: isMotionReduced ? .clear : providerBadgeTint.opacity(0.08),
                            radius: 4,
                            y: 1
                        )
                        .accessibilityLabel("Generation source")
                        .accessibilityValue(sourceBadgeText)

                        Spacer(minLength: 0)
                    }
                }
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
                .fixedSize(horizontal: false, vertical: true)
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
                        .font(.footnote)
                        .lineSpacing(2)
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
        .modifier(Shake(animatableData: CGFloat(shakeCount)))
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
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(theme == .minimal ? 0.18 : 0.55),
                            (Theme.secondaryAccent(for: theme) ?? accent).opacity(theme == .minimal ? 0.12 : 0.35),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: theme == .minimal ? 2 : 3)
                .padding(.vertical, Theme.cardPadding * 0.75)
                .padding(.leading, 8)
                .allowsHitTesting(false)
        }
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

                    withAnimation(Theme.springSnappy) {
                        let nextY = Double(value.translation.width / 18)
                        let nextX = Double(-value.translation.height / 24)
                        rotationY = min(max(nextY, -maxRotation), maxRotation)
                        rotationX = min(max(nextX, -maxRotation), maxRotation)
                    }
                }
                .onEnded { _ in
                    guard !isMotionReduced else { return }
                    withAnimation(Theme.springSmooth) {
                        rotationX = 0
                        rotationY = 0
                    }
                }
        )
        .onChange(of: record.id) { _, newID in
            guard newID != lastRecordID else { return }
            lastRecordID = newID

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
            withAnimation(Theme.springBouncy) {
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
            
            scheduleRotationReset(after: 0.15)

            // Screen Shake for intense tones
            let intenseTones: Set<ToneMode> = [.toxicBestFriend, .alphaPodcast, .cryptoBro, .conspiracyTheorist]
            if intenseTones.contains(record.tone) {
                withAnimation(.linear(duration: 0.3)) {
                    shakeCount += 1
                }
            }
        }
        .onAppear {
            lastRecordID = record.id
            if isMotionReduced {
                shimmerOffset = -1.0
            }
        }
        .onDisappear {
            rotationResetTask?.cancel()
            rotationResetTask = nil
        }
        .onChange(of: theme) { _, _ in
            if isMotionReduced {
                shimmerOffset = -1.0
                rotationX = 0
                rotationY = 0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Animate card") {
            guard !isMotionReduced else { return }
            withAnimation(Theme.springBouncy) {
                rotationX = -8
            }
            scheduleRotationReset(after: 0.2)
            shimmerOffset = -0.3
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 1.3
            }
        }
    }

    private func scheduleRotationReset(after delay: TimeInterval) {
        rotationResetTask?.cancel()
        rotationResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.springSmooth) {
                rotationX = 0
            }
        }
    }
}

private struct AdviceBadgePill: View {
    let text: String
    let systemImage: String?
    let tint: Color
    let fill: Color
    let stroke: Color
    let showsStroke: Bool
    let minWidth: CGFloat?

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(Theme.chipFont)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.chipHorizontalPadding)
        .padding(.vertical, Theme.chipVerticalPadding)
        .frame(minHeight: Theme.chipMinHeight)
        .frame(minWidth: minWidth, alignment: .center)
        .background(
            Capsule(style: .continuous)
                .fill(fill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(stroke, lineWidth: showsStroke ? 1 : 0)
        )
    }
}
