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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var lastRecordID: UUID = UUID()
    @State private var isAdviceExpanded = false
    @State private var isGoodAdviceRevealed = false

    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0
    @State private var rotationResetTask: Task<Void, Never>?

    // Infernal editorial: seal + reveal
    @State private var sealScale: CGFloat = 0.4
    @State private var sealOpacity: Double = 0
    @State private var sealRotation: Double = -18
    @State private var revealProgress: CGFloat = 1
    @State private var takeBlur: CGFloat = 0

    @State private var lastTiltTranslation: CGSize = .zero
    private static let tiltUpdateThreshold: CGFloat = 2.0

    @ScaledMetric(relativeTo: .title) private var quoteFontSize: CGFloat = 56

    private var isMotionReduced: Bool {
        reduceMotion || accessibilityReduceMotion
    }
    private var allowsInteractiveTilt: Bool { false }

    private var score: BadviceScore { BadviceScore(record: record) }
    private var intensityScore: Int { score.wrongness }
    private var railWidth: CGFloat { Theme.intensityRailWidth(score: intensityScore) }

    private var takeLabel: String {
        switch record.tone {
        case .corporateConsultant, .linkedInInfluencer:
            return "INTERNAL MEMO"
        case .wizard, .minimalistMonk:
            return "THE PROPHECY"
        case .cryptoBro:
            return "ALPHA TAKE"
        case .conspiracyTheorist:
            return "CLASSIFIED"
        case .redditCommenter:
            return "TOP COMMENT"
        case .lifeCoach, .influencer, .astrologyGirlie:
            return "THE HOT TAKE"
        case .oldMoney:
            return "DISPATCH"
        default:
            return "THE TAKE"
        }
    }

    private var takeLineSpacing: CGFloat {
        switch record.tone {
        case .corporateConsultant, .linkedInInfluencer: return 3
        case .wizard, .oldMoney: return 6
        default: return 5
        }
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
        let cardRadius = Theme.cardCornerRadius + 2
        let takeFont = Theme.editorialCardFont(for: theme, tone: record.tone)

        VStack(alignment: .leading, spacing: 0) {
            // Context rail — two lines so category/tone never clip the wax seal
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: record.category.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                        Text(record.category.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "dial.medium")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(toneBadgeTint)
                        Text(record.tone.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(toneBadgeTint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if let sourceBadgeText, !sourceBadgeText.isEmpty {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(secondaryText.opacity(0.4))
                            Label(sourceBadgeText, systemImage: "cpu")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(providerBadgeTint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .accessibilityLabel("Generation source")
                                .accessibilityValue(sourceBadgeText)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Wax seal — brand mark stamped on each take
                ZStack {
                    Circle()
                        .fill(Theme.copperEmbossGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: Theme.copperFoilDeep.opacity(0.45), radius: 4, y: 2)
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    if UIImage(named: "BadviceMark") != nil {
                        Image("BadviceMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    } else {
                        Text("B")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.espressoInk)
                    }
                }
                .scaleEffect(sealScale)
                .opacity(sealOpacity)
                .rotationEffect(.degrees(sealRotation))
                .accessibilityHidden(true)
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(record.category.title), \(record.tone.title)")

            Rectangle()
                .fill(accent.opacity(0.16))
                .frame(height: 1)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Text(takeLabel)
                    .font(.caption2.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(secondaryText.opacity(0.72))
                Rectangle()
                    .fill(secondaryText.opacity(0.18))
                    .frame(height: 1)
                Text("\(intensityScore)%")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(accent.opacity(0.75))
                    .accessibilityLabel("Wrongness intensity \(intensityScore) percent")
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
            .padding(.top, 14)

            if !dynamicTypeSize.isAccessibilitySize {
                Text("\u{201C}")
                    .font(.system(size: quoteFontSize, weight: .heavy, design: .serif))
                    .foregroundStyle(accent.opacity(0.22))
                    .frame(height: 24)
                    .offset(y: 4)
            }

            Text(displayAdviceLine)
                .font(takeFont)
                .foregroundStyle(primaryText)
                .lineSpacing(takeLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .blur(radius: takeBlur)
                .opacity(Double(revealProgress))
                .accessibilityLabel("Advice")
                .accessibilityValue(record.adviceLine)

            if shouldCollapseAdvice {
                Button {
                    withAnimation(isMotionReduced ? nil : .easeInOut(duration: Theme.animFast)) {
                        isAdviceExpanded.toggle()
                    }
                } label: {
                    Label(isAdviceExpanded ? "Show less" : "Read more", systemImage: isAdviceExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .padding(.top, 10)
                .accessibilityIdentifier("advice.card.readMore")
            }

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

            BadviceScoreView(record: record, accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                .padding(.top, 14)

            DisclosureGroup(
                isExpanded: $isGoodAdviceRevealed.animation(isMotionReduced ? nil : .easeInOut(duration: Theme.animFast))
            ) {
                Text(actuallyGoodAdviceLine)
                    .font(.footnote)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            } label: {
                Label("Actually good advice", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .padding(.top, 10)
            .accessibilityIdentifier("advice.card.goodAdvice")
        }
        .padding(Theme.cardPadding)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(cardColor)

                if theme != .minimal {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(glassOpacity)
                }

                // Soft top copper wash for default editorial theme
                if theme == .badvice {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.copperFoilMid.opacity(0.12),
                                    .clear,
                                    Color.black.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                if Theme.usesPaperGrain(for: theme) {
                    PaperGrainOverlay(opacity: theme == .minimal ? 0.04 : 0.07)
                        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                }

                if let glowColor, !isMotionReduced {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(glowColor.opacity(0.10), lineWidth: 1.5)
                        .blur(radius: 3)
                }
            }
            .conditionalDrawingGroup(!isMotionReduced)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.55),
                            accent.opacity(0.18),
                            tertiaryStroke
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // Intensity rail — wrongness drives copper edge weight
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(theme == .minimal ? 0.18 : 0.75),
                            (Theme.secondaryAccent(for: theme) ?? accent).opacity(theme == .minimal ? 0.12 : 0.45),
                            accent.opacity(0.15),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: theme == .minimal ? 2 : railWidth)
                .padding(.vertical, Theme.cardPadding * 0.65)
                .padding(.leading, 6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.22), .white.opacity(0.0)],
                        startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .allowsHitTesting(false)
                .opacity(isMotionReduced ? 0 : (shimmerOffset >= 0 && shimmerOffset <= 1.0 ? 1 : 0))

            if theme == .cybernetic {
                Circle()
                    .stroke(accent.opacity(rippleOpacity), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
        .shadow(
            color: secondaryShadow?.color ?? .clear,
            radius: secondaryShadow?.radius ?? 0,
            y: secondaryShadow?.y ?? 0
        )
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationX), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(isMotionReduced ? 0 : rotationY), axis: (x: 0, y: 1, z: 0))
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    guard !isMotionReduced, allowsInteractiveTilt else { return }
                    let t = value.translation
                    let dx = abs(t.width  - lastTiltTranslation.width)
                    let dy = abs(t.height - lastTiltTranslation.height)
                    guard dx > Self.tiltUpdateThreshold || dy > Self.tiltUpdateThreshold else { return }
                    lastTiltTranslation = t

                    let maxRotation: Double = 5
                    let horizontalWeight = abs(t.width)
                    let verticalWeight   = abs(t.height)
                    guard horizontalWeight >= verticalWeight * 0.8 else { return }

                    withAnimation(Theme.springSnappy) {
                        let nextY = Double(t.width  / 28)
                        let nextX = Double(-t.height / 34)
                        rotationY = min(max(nextY, -maxRotation), maxRotation)
                        rotationX = min(max(nextX, -maxRotation), maxRotation)
                    }
                }
                .onEnded { _ in
                    guard !isMotionReduced, allowsInteractiveTilt else { return }
                    lastTiltTranslation = .zero
                    withAnimation(Theme.smugSettle) {
                        rotationX = 0
                        rotationY = 0
                    }
                }
        )
        .onChange(of: record.id) { _, newID in
            guard newID != lastRecordID else { return }
            lastRecordID = newID
            isAdviceExpanded = false
            isGoodAdviceRevealed = false
            playNewTakeFlourish()
        }
        .onAppear {
            lastRecordID = record.id
            if isMotionReduced {
                shimmerOffset = -1.0
                sealScale = 1
                sealOpacity = 1
                sealRotation = 0
                revealProgress = 1
                takeBlur = 0
            } else {
                // First appear: settle seal without full reveal drama
                sealScale = 1
                sealOpacity = 1
                sealRotation = 0
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
            playNewTakeFlourish()
        }
    }

    private func playNewTakeFlourish() {
        guard !isMotionReduced else {
            shimmerOffset = -1.0
            rotationX = 0
            rotationY = 0
            sealScale = 1
            sealOpacity = 1
            sealRotation = 0
            revealProgress = 1
            takeBlur = 0
            return
        }

        // Reveal: blur → clear
        revealProgress = 0.15
        takeBlur = 4
        withAnimation(Theme.smugSettle) {
            revealProgress = 1
            takeBlur = 0
        }

        // Seal stamp
        sealScale = 0.35
        sealOpacity = 0
        sealRotation = -22
        withAnimation(Theme.badBounce) {
            sealScale = 1.08
            sealOpacity = 1
            sealRotation = 0
        }
        withAnimation(Theme.smugSettle.delay(0.12)) {
            sealScale = 1.0
        }

        shimmerOffset = -0.3
        withAnimation(.easeInOut(duration: 0.55)) {
            shimmerOffset = 1.15
        }

        withAnimation(Theme.springSmooth) {
            rotationX = -5
        }

        if theme == .cybernetic {
            rippleScale = 0.5
            rippleOpacity = 0.55
            withAnimation(.easeOut(duration: 0.45)) {
                rippleScale = 2.0
                rippleOpacity = 0
            }
        }

        scheduleRotationReset(after: 0.18)
    }

    private func scheduleRotationReset(after delay: TimeInterval) {
        rotationResetTask?.cancel()
        rotationResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.smugSettle) {
                rotationX = 0
                rotationY = 0
            }
        }
    }

    private var shouldCollapseAdvice: Bool {
        record.adviceLine.count > AdviceEngineConstants.adviceOutputMaxLength
    }

    private var displayAdviceLine: String {
        guard shouldCollapseAdvice, !isAdviceExpanded else { return record.adviceLine }
        return Self.wordSafeTruncate(record.adviceLine, maxLength: AdviceEngineConstants.adviceOutputMaxLength)
    }

    private var actuallyGoodAdviceLine: String {
        switch record.category {
        case .dating:
            return "Be clear about what you want, be kind about what you cannot offer, and do not confuse intensity for compatibility."
        case .fitness:
            return "Choose a repeatable plan, increase effort gradually, and treat recovery as part of the work."
        case .productivity:
            return "Pick one real next step, shrink it until it is boring, and do that before adding a system."
        case .career:
            return "Ask for the context, write down the tradeoffs, then make the smallest reversible move."
        case .parenting:
            return "Lower the volume, keep the boundary clear, and make the next step understandable."
        case .tech:
            return "Prefer the boring fix you can verify, document the tradeoff, and avoid shipping mystery."
        case .social:
            return "Make the invitation easy, respect the answer, and do not turn silence into a strategy."
        case .cooking:
            return "Read the whole recipe, season thoughtfully, and fix one variable at a time."
        case .travel:
            return "Book the essentials, leave buffer, and make the fallback plan before you need it."
        case .pets:
            return "Reward the behavior you want, stay consistent, and ask a vet or trainer when safety is involved."
        case .relationships:
            return "Say the clear thing kindly, listen for the actual concern, and avoid performing certainty."
        case .money:
            return "Slow down, check the downside, and never let confidence replace math."
        case .spirituality:
            return "Use reflection to become more honest and useful, not to escape feedback."
        case .financeCrypto:
            return "Assume volatility is real, size risk conservatively, and never let hype replace diligence."
        case .gaming:
            return "Take the loss, mute the tilt, and step away before the next queue if you need to."
        case .weddings:
            return "Set the budget together first, protect one non-negotiable each, and let the rest be optional."
        case .random:
            return "Pause long enough to name the real problem, then choose the least dramatic useful action."
        }
    }

    private static func wordSafeTruncate(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let limit = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        var prefix = String(trimmed[..<limit])
        if let lastBoundary = prefix.lastIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            prefix = String(prefix[..<lastBoundary])
        }
        prefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return prefix.isEmpty ? String(trimmed.prefix(maxLength)) : "\(prefix)…"
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
    let theme: ThemeMode

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(Theme.chipFont(for: theme))
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

private struct BadviceScoreView: View {
    let record: AdviceRecord
    let accent: Color
    let primaryText: Color
    let secondaryText: Color

    private var score: BadviceScore {
        BadviceScore(record: record)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Badvice Score", systemImage: "gauge.with.dots.needle.67percent")
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)

            // Single compact row — less vertical chrome under the take
            HStack(spacing: 6) {
                scorePill(title: "Wrong", value: score.wrongness)
                scorePill(title: "Confident", value: score.confidence)
                scorePill(title: "HR Risk", value: score.hrRisk)
                scorePill(title: "Useful", value: score.usefulness)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Badvice Score. Wrongness \(score.wrongness) percent. Confidence \(score.confidence) percent. HR Risk \(score.hrRisk) percent. Usefulness \(score.usefulness) percent."
        )
        .accessibilityIdentifier("advice.card.badviceScore")
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func scorePill(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(value)%")
                .font(.caption.weight(.heavy))
                .foregroundStyle(primaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }
}

private struct BadviceScore {
    let wrongness: Int
    let confidence: Int
    let hrRisk: Int
    let usefulness: Int

    init(record: AdviceRecord) {
        let seed = Self.stableSeed(for: "\(record.id.uuidString)|\(record.categoryRaw)|\(record.toneRaw)|\(record.adviceLine)")
        let categoryBias = record.category == .relationships ? 8 : record.category == .career ? 6 : 0
        let toneBias: Int
        switch record.tone {
        case .corporateConsultant, .linkedInInfluencer, .alphaPodcast:
            toneBias = 8
        case .toxicBestFriend, .friendRoast:
            toneBias = 12
        case .minimalistMonk:
            toneBias = -8
        default:
            toneBias = 0
        }
        wrongness = Self.clamped(76 + seed.positiveModulo(20) + max(toneBias, 0), min: 61, max: 99)
        confidence = Self.clamped(68 + (seed / 7).positiveModulo(27) + toneBias, min: 54, max: 98)
        hrRisk = Self.clamped(45 + (seed / 13).positiveModulo(36) + categoryBias + max(toneBias / 2, 0), min: 18, max: 96)
        usefulness = Self.clamped(2 + (seed / 19).positiveModulo(12) - max(toneBias / 4, 0), min: 1, max: 18)
    }

    private static func stableSeed(for text: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in text.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1_099_511_628_211
        }
        return Int(hash & 0x7FFF_FFFF)
    }

    private static func clamped(_ value: Int, min lower: Int, max upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), upper)
    }
}
