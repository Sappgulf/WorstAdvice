import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}

struct TabCommandMetric: View {
    let title: String
    let value: String
    let accent: Color
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.2),
                            accent.opacity(0.08),
                            accent.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct TabCommandCard<Metrics: View, Actions: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    @ViewBuilder let metrics: () -> Metrics
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            metrics()
                .frame(maxWidth: .infinity, alignment: .leading)

            actions()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.mediumCornerRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.75), accent.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)
                .padding(.horizontal, 16)
                .padding(.top, 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct TabCommandActionButton: View {
    let title: String
    let systemImage: String?
    let accent: Color
    let buttonText: Color
    var prominent = true
    var isDisabled = false
    var accessibilityIdentifier: String? = nil
    var minHeight: CGFloat = Theme.commandActionMinHeight
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        actionButton
    }

    private var actionButton: some View {
        Button(action: action) {
            actionLabel
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? buttonText : accent)
        .opacity(isDisabled ? 0.7 : 1.0)
        .tint(accent)
        .disabled(isDisabled)
        .modifier(ConditionalAccessibilityIdentifier(accessibilityIdentifier: accessibilityIdentifier))
        .accessibilityLabel(title)
        .contentShape(Capsule(style: .continuous))
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(prominent ? (isDisabled ? accent.opacity(0.10) : accent.opacity(0.16)) : .clear)
                if !isDisabled {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(prominent ? 0.24 : 0.14),
                                    accent.opacity(prominent ? 0.08 : 0.0),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(prominent ? 0.45 : 0.16)
                }
            }
            .overlay(
                Capsule(style: .continuous)
                        .stroke(
                            isDisabled ? accent.opacity(0.22) : accent.opacity(prominent ? 0.48 : 0.3),
                            lineWidth: 1
                        )
            )
        }
    }

    @ViewBuilder
    private var actionLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

private struct ConditionalAccessibilityIdentifier: ViewModifier {
    let accessibilityIdentifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let accessibilityIdentifier,
           !accessibilityIdentifier.isEmpty {
            content.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            content
        }
    }
}

struct SectionShell<Header: View, Content: View>: View {
    let accent: Color
    let cardColor: Color
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.shellSpacing) {
            header()
            content()
        }
        .padding(Theme.shellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
    }
}

struct InlineStatusBanner: View {
    let text: String
    let systemImage: String
    let tint: Color
    let primaryText: Color
    let cardColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(primaryText)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct AdviceCategoryFilterChips: View {
    @Binding var selectedCategory: AdviceCategory?
    var categories: [AdviceCategory] = AdviceCategory.concrete
    let accent: Color
    let secondaryText: Color
    let hapticsEnabled: Bool
    var reduceMotion = false
    var accessibilityPrefix = "categoryFilter"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    accessibilityID: "\(accessibilityPrefix).all"
                ) {
                    selectedCategory = nil
                }

                ForEach(categories) { category in
                    let isSelected = selectedCategory == category
                    chip(
                        title: category.title,
                        isSelected: isSelected,
                        accessibilityID: "\(accessibilityPrefix).\(category.rawValue)"
                    ) {
                        selectedCategory = isSelected ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(
        title: String,
        isSelected: Bool,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            HapticsManager.playSelection(isEnabled: hapticsEnabled)
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(minHeight: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? accent.opacity(0.2) : secondaryText.opacity(0.12))
                )
                .foregroundStyle(isSelected ? accent : secondaryText)
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.68),
                    value: isSelected
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TabEmptyStatePanel<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    let reduceMotion: Bool
    @ViewBuilder let actions: () -> Actions

    @State private var appeared = false
    @State private var floatOffset: CGFloat = 0

    init(
        icon: String,
        title: String,
        message: String,
        accent: Color,
        primaryText: Color,
        secondaryText: Color,
        cardColor: Color,
        reduceMotion: Bool,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accent = accent
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.cardColor = cardColor
        self.reduceMotion = reduceMotion
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Thin arc behind the badge for depth, not a full second circle
                Circle()
                    .trim(from: 0.08, to: 0.62)
                    .stroke(accent.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(-40))
                    .opacity(appeared ? 1.0 : 0)
                    .scaleEffect(appeared ? 1.0 : 0.8)

                // Small satellite accent, offset for an asymmetric, hand-placed feel
                Circle()
                    .fill(accent.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .offset(x: 34, y: -30 + floatOffset * 0.4)
                    .opacity(appeared ? 1.0 : 0)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.13))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-6))
                    .offset(y: floatOffset)

                if reduceMotion {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                        .symbolEffect(.bounce, options: .repeating, value: appeared)
                }
            }
            .frame(height: 112)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 14)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 12)
            }

            actions()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.74)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    floatOffset = -9
                }
            }
        }
        .onDisappear {
            appeared = false
            floatOffset = 0
        }
    }
}

struct TabFocusModeToggle: View {
    let isEnabled: Bool
    let accent: Color
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Label(
                isEnabled ? "Focus" : "Focus",
                systemImage: isEnabled ? "eye.slash.fill" : "eye"
            )
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill((isEnabled ? accent : accent.opacity(0.12)).opacity(isEnabled ? 0.16 : 0.08))
            )
            .foregroundStyle(isEnabled ? accent : accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("focus.mode.toggle")
        .accessibilityLabel(isEnabled ? "Disable focus mode" : "Enable focus mode")
    }
}

struct ThemeBackgroundView: View {
    let mode: ThemeMode
    var budget: RenderBudget = .balanced
    var lowPowerModeEnabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var shouldRenderEffects = true

    var body: some View {
        ZStack {
            Theme.canvasColor(for: mode)
            Theme.backgroundGradient(for: mode)
            ThemeAtmosphereView(mode: mode)

            if scenePhase == .active && shouldRenderEffects {
                let allowsDynamic = budget != .reduced && !lowPowerModeEnabled
                let allowsFullEffects = budget == .full && !lowPowerModeEnabled

                if allowsDynamic && mode != .minimal {
                    DynamicChaosView(theme: mode, budget: budget)
                        .opacity(allowsFullEffects ? 0.4 : 0.26)
                        .blendMode(.screen)
                        .drawingGroup(opaque: false)
                        .allowsHitTesting(false)
                }

                if allowsFullEffects && (mode == .badvice || mode == .ember || mode == .evergreen || mode == .midnight) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)

                    PaperGrainView(budget: budget)
                        .blendMode(.multiply)
                        .opacity(mode == .badvice ? 0.3 : 0.25)
                        .drawingGroup()
                        .allowsHitTesting(false)
                }

                if allowsFullEffects && mode == .neon {
                    NeonGridView(budget: budget)
                        .opacity(0.15)
                        .blendMode(.screen)
                        .drawingGroup()
                        .allowsHitTesting(false)
                }

                if allowsFullEffects && mode == .cosmic {
                    StarFieldView(budget: budget)
                        .opacity(0.6)
                        .drawingGroup()
                        .allowsHitTesting(false)
                }

                if allowsFullEffects && (mode == .retro || mode == .fallout) {
                    ScanlineView(budget: budget)
                        .opacity(mode == .fallout ? 0.16 : 0.1)
                        .blendMode(.overlay)
                        .drawingGroup()
                        .allowsHitTesting(false)
                }

                if allowsDynamic && mode == .fallout {
                    LinearGradient(
                        colors: [Color(hex: "8CFF7A").opacity(0.08), Color.clear, Color(hex: "4D8F45").opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                }

                if mode == .cybernetic {
                    CyberneticView(budget: budget)
                        .drawingGroup()
                        .allowsHitTesting(false)
                }
            }

            CinematicVignetteView()
                .opacity(mode == .minimal ? 0.24 : 0.52)
                .allowsHitTesting(false)
        }
        .onChange(of: scenePhase) { _, newPhase in
            shouldRenderEffects = newPhase == .active
        }
    }
}

private struct ThemeAtmosphereView: View {
    let mode: ThemeMode

    private var accent: Color { Theme.accent(for: mode) }
    private var secondaryAccent: Color { Theme.secondaryAccent(for: mode) ?? accent }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(mode == .minimal ? 0.06 : 0.1),
                    .clear,
                    Color.black.opacity(mode == .minimal ? 0.04 : 0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            RadialGradient(
                colors: [accent.opacity(mode == .minimal ? 0.06 : 0.18), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: mode == .minimal ? 280 : 360
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [secondaryAccent.opacity(mode == .minimal ? 0.04 : 0.12), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: mode == .minimal ? 260 : 340
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [.clear, Color.black.opacity(mode == .minimal ? 0.16 : 0.34)],
                center: .bottom,
                startRadius: 90,
                endRadius: 760
            )
            .blendMode(.multiply)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct CinematicVignetteView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [.clear, .black.opacity(0.34)],
                center: .center,
                startRadius: 120,
                endRadius: 620
            )
            .blendMode(.multiply)

            LinearGradient(
                colors: [Color.black.opacity(0.12), .clear, Color.black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}

struct DynamicChaosView: View {
    let theme: ThemeMode
    let budget: RenderBudget
    @Environment(\.scenePhase) private var scenePhase

    @State private var start = Date()

    private var frameInterval: TimeInterval {
        switch budget {
        case .full:
            return 1.0 / 20.0
        case .balanced:
            return 1.0 / 12.0
        case .reduced:
            return 1.0 / 6.0
        }
    }

    private var throttledInterval: TimeInterval {
        let multiplier: Double = scenePhase == .active ? 1.0 : 2.5
        return frameInterval * multiplier
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: throttledInterval, paused: scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(start)
                let accentColor = Theme.accent(for: theme)
                let blobCount = budget == .full ? 3 : 2
                let blobOpacity: Double = budget == .full ? 0.15 : 0.1
                let blobScale: CGFloat = budget == .full ? 1.0 : 0.82

                for i in 0..<blobCount {
                    let offset = Double(i) * 2.0
                    let speed = 0.2 + Double(i) * 0.1
                    let x = size.width * (0.5 + 0.3 * sin(time * speed + offset))
                    let y = size.height * (0.5 + 0.3 * cos(time * speed * 0.8 + offset * 1.5))
                    let blobSize = size.width * (0.52 + 0.08 * sin(time * 0.5 + offset)) * blobScale

                    let rect = CGRect(
                        x: x - blobSize / 2,
                        y: y - blobSize / 2,
                        width: blobSize,
                        height: blobSize
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [accentColor.opacity(blobOpacity), .clear]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0,
                            endRadius: blobSize / 2
                        )
                    )
                }
            }
        }
    }
}

private struct PaperGrainView: View {
    let budget: RenderBudget

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let step: CGFloat = budget == .full ? 16 : 20
            let dotOpacity: Double = budget == .full ? 0.025 : 0.018
            let threshold: CGFloat = budget == .full ? 18 : 12

            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let hash = (x * 374761 + y * 668265).truncatingRemainder(dividingBy: 100)
                    if hash < threshold {
                        let dotSize: CGFloat = hash < threshold / 3 ? 1.0 : 0.6
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(dotOpacity)))
                    }
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct ThemeTransition: ViewModifier {
    let theme: ThemeMode

    func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.35), value: theme)
    }
}

extension View {
    func themeTransition(_ theme: ThemeMode) -> some View {
        modifier(ThemeTransition(theme: theme))
    }

    @ViewBuilder
    func conditionalDrawingGroup(_ enabled: Bool) -> some View {
        if enabled {
            drawingGroup()
        } else {
            self
        }
    }

    @ViewBuilder
    func conditionalAnimation<V: Equatable>(_ animation: Animation?, value: V, enabled: Bool) -> some View {
        if enabled {
            self.animation(animation, value: value)
        } else {
            self.animation(nil, value: value)
        }
    }
}

private struct NeonGridView: View {
    let budget: RenderBudget
    @Environment(\.scenePhase) private var scenePhase

    private var frameInterval: TimeInterval {
        switch budget {
        case .full:
            return 1.0 / 18.0
        case .balanced:
            return 1.0 / 10.0
        case .reduced:
            return 1.0 / 5.0
        }
    }

    private var throttledInterval: TimeInterval {
        let multiplier: Double = scenePhase == .active ? 1.0 : 2.5
        return frameInterval * multiplier
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: throttledInterval, paused: scenePhase != .active)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = sin(time * 1.35)
                let gridSize: CGFloat = 40
                let lineOpacity = 0.24 + 0.14 * phase

                for x in stride(from: 0, to: size.width, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(Color(hex: "FF00FF").opacity(lineOpacity)), lineWidth: 1)
                }

                for y in stride(from: 0, to: size.height, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color(hex: "00FFFF").opacity(lineOpacity)), lineWidth: 1)
                }
            }
        }
    }
}

private struct StarFieldView: View {
    let budget: RenderBudget
    @State private var start = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var frameInterval: TimeInterval {
        switch budget {
        case .full:
            return 1.0 / 18.0
        case .balanced:
            return 1.0 / 10.0
        case .reduced:
            return 1.0 / 5.0
        }
    }

    private var throttledInterval: TimeInterval {
        let multiplier: Double = scenePhase == .active ? 1.0 : 2.5
        return frameInterval * multiplier
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: throttledInterval, paused: scenePhase != .active)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSince(start)

                for i in 0..<50 {
                    let seed = Double(i)
                    let x = size.width * CGFloat((seed * 73).truncatingRemainder(dividingBy: 100) / 100)
                    let y = size.height * CGFloat((seed * 37).truncatingRemainder(dividingBy: 100) / 100)
                    let twinkle = 0.3 + 0.7 * sin(time * 2 + seed)
                    let radius = CGFloat(1 + (seed.truncatingRemainder(dividingBy: 3)))

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(twinkle)))
                }
            }
        }
    }
}

private struct ScanlineView: View {
    let budget: RenderBudget
    @Environment(\.scenePhase) private var scenePhase

    private var frameInterval: TimeInterval {
        switch budget {
        case .full:
            return 1.0 / 24.0
        case .balanced:
            return 1.0 / 16.0
        case .reduced:
            return 1.0 / 8.0
        }
    }

    private var throttledInterval: TimeInterval {
        let multiplier: Double = scenePhase == .active ? 1.0 : 2.5
        return frameInterval * multiplier
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: throttledInterval, paused: scenePhase != .active)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let cycle = timeline.date.timeIntervalSinceReferenceDate
                let offset = CGFloat((cycle.truncatingRemainder(dividingBy: 8.0) / 8.0) * 6.0)
                let lineHeight: CGFloat = 2
                let gapHeight: CGFloat = 4

                for y in stride(from: -offset, to: size.height, by: lineHeight + gapHeight) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color(hex: "00FF9F").opacity(0.3)), lineWidth: lineHeight)
                }
            }
        }
    }
}

private struct CyberneticView: View {
    let budget: RenderBudget
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: true) { context, size in
                let step: CGFloat = 32
                let lineColor = Color(hex: "00F3FF").opacity(0.08)

                for x in stride(from: 0, to: size.width, by: step) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }

                for y in stride(from: 0, to: size.height, by: step) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
            }

            if budget != .reduced && !accessibilityReduceMotion {
                GlitchView(budget: budget)
                    .opacity(0.4)
            }

            RadialGradient(
                colors: [Color(hex: "00F3FF").opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 600
            )
            .blendMode(.plusLighter)
        }
    }
}

private struct GlitchView: View {
    let budget: RenderBudget
    @Environment(\.scenePhase) private var scenePhase

    private var frameInterval: TimeInterval {
        switch budget {
        case .full: return 1.0 / 12.0
        case .balanced: return 1.0 / 6.0
        case .reduced: return 0.5
        }
    }

    private var throttledInterval: TimeInterval {
        frameInterval * (scenePhase == .active ? 1.0 : 2.5)
    }

    private func seededValue(seed: UInt64, salt: UInt64) -> Double {
        var value = seed &+ (salt &* 0x9E37_79B9_7F4A_7C15)
        value ^= value >> 33
        value &*= 0xff51_afd7_ed55_8ccd
        value ^= value >> 33
        value &*= 0xc4ce_b9fe_1a85_ec53
        value ^= value >> 33
        return Double(value % 10_000) / 10_000.0
    }

    private func seededRange(
        seed: UInt64,
        salt: UInt64,
        lower: Double,
        upper: Double
    ) -> Double {
        lower + (seededValue(seed: seed, salt: salt) * (upper - lower))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: throttledInterval, paused: scenePhase != .active)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                if Int(time * 10) % 5 == 0 {
                    let glitchCount = budget == .full ? 10 : 5
                    let neonColors = [
                        Color(hex: "00F3FF"),
                        Color(hex: "FF00FF"),
                        Color(hex: "7000FF"),
                    ]
                    let frameSeed = UInt64(time * 24)

                    for index in 0..<glitchCount {
                        let seed = frameSeed &+ UInt64(index + 1)
                        let maxWidth = max(40, size.width * 0.6)
                        let width = CGFloat(seededRange(seed: seed, salt: 1, lower: 40, upper: maxWidth))
                        let height = CGFloat(seededRange(seed: seed, salt: 2, lower: 1, upper: 12))
                        let xRange = max(0, size.width - width)
                        let yRange = max(0, size.height - height)
                        let x = CGFloat(seededRange(seed: seed, salt: 3, lower: 0, upper: xRange))
                        let y = CGFloat(seededRange(seed: seed, salt: 4, lower: 0, upper: yRange))
                        let alpha = 0.26 + (seededValue(seed: seed, salt: 5) * 0.14)
                        let color = neonColors[Int(seed % UInt64(neonColors.count))]

                        let rect = CGRect(x: x, y: y, width: width, height: height)
                        context.fill(Path(rect), with: .color(color.opacity(alpha)))

                        if seededValue(seed: seed, salt: 6) > 0.58 {
                            context.fill(
                                Path(rect.offsetBy(dx: 4, dy: 0)),
                                with: .color(Color(hex: "FF00FF").opacity(alpha * 0.55))
                            )
                        }
                    }
                }

                let scanlineY = (time * 150.0).truncatingRemainder(dividingBy: size.height)
                var scanPath = Path()
                scanPath.move(to: CGPoint(x: 0, y: scanlineY))
                scanPath.addLine(to: CGPoint(x: size.width, y: scanlineY))
                context.stroke(scanPath, with: .color(Color(hex: "00F3FF").opacity(0.05)), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
