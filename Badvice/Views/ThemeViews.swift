import Foundation
import SwiftUI

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

            if scenePhase == .active && shouldRenderEffects {
                let allowsDynamic = budget != .reduced && !lowPowerModeEnabled
                let allowsFullEffects = budget == .full && !lowPowerModeEnabled

                if allowsDynamic && mode != .minimal {
                    DynamicChaosView(theme: mode, budget: budget)
                        .opacity(allowsFullEffects ? 0.4 : 0.26)
                        .blendMode(.screen)
                        .drawingGroup(opaque: false)
                }

                if allowsFullEffects && (mode == .badvice || mode == .ember || mode == .evergreen || mode == .midnight) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.overlay)

                    PaperGrainView()
                        .blendMode(.multiply)
                        .opacity(mode == .badvice ? 0.3 : 0.25)
                        .drawingGroup()
                }

                if allowsFullEffects && mode == .neon {
                    NeonGridView(budget: budget)
                        .opacity(0.15)
                        .blendMode(.screen)
                        .drawingGroup()
                }

                if allowsFullEffects && mode == .cosmic {
                    StarFieldView(budget: budget)
                        .opacity(0.6)
                        .drawingGroup()
                }

                if allowsFullEffects && (mode == .retro || mode == .fallout) {
                    ScanlineView(budget: budget)
                        .opacity(mode == .fallout ? 0.16 : 0.1)
                        .blendMode(.overlay)
                        .drawingGroup()
                }

                if allowsDynamic && mode == .fallout {
                    LinearGradient(
                        colors: [Color(hex: "8CFF7A").opacity(0.08), Color.clear, Color(hex: "4D8F45").opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                }

                if mode == .cybernetic {
                    CyberneticView(budget: budget)
                        .drawingGroup()
                }
            }

            CinematicVignetteView()
                .opacity(mode == .minimal ? 0.3 : 0.6)
                .allowsHitTesting(false)
        }
        .onChange(of: scenePhase) { _, newPhase in
            shouldRenderEffects = newPhase == .active
        }
    }
}

struct CinematicVignetteView: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.4)],
            center: .center,
            startRadius: 100,
            endRadius: 600
        )
        .blendMode(.multiply)
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

                for i in 0..<3 {
                    let offset = Double(i) * 2.0
                    let speed = 0.2 + Double(i) * 0.1
                    let x = size.width * (0.5 + 0.3 * sin(time * speed + offset))
                    let y = size.height * (0.5 + 0.3 * cos(time * speed * 0.8 + offset * 1.5))
                    let blobSize = size.width * (0.6 + 0.1 * sin(time * 0.5 + offset))

                    let rect = CGRect(
                        x: x - blobSize / 2,
                        y: y - blobSize / 2,
                        width: blobSize,
                        height: blobSize
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [accentColor.opacity(0.15), .clear]),
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
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let step: CGFloat = 12
            let dotOpacity: Double = 0.03

            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let hash = (x * 374761 + y * 668265).truncatingRemainder(dividingBy: 100)
                    if hash < 20 {
                        let dotSize: CGFloat = hash < 6 ? 1.0 : 0.6
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

    private var frameInterval: TimeInterval {
        switch budget {
        case .full: return 1.0 / 12.0
        case .balanced: return 1.0 / 6.0
        case .reduced: return 0.5
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let hash = Int(time * 10)

                if hash % 5 == 0 {
                    let glitchCount = budget == .full ? 10 : 5
                    for _ in 0..<glitchCount {
                        let w = CGFloat.random(in: 40...size.width * 0.6)
                        let h = CGFloat.random(in: 1...12)
                        let x = CGFloat.random(in: 0...size.width - w)
                        let y = CGFloat.random(in: 0...size.height - h)

                        let rect = CGRect(x: x, y: y, width: w, height: h)
                        let neonColors = [Color(hex: "00F3FF"), Color(hex: "FF00FF"), Color(hex: "7000FF")]
                        let color = neonColors.randomElement() ?? Color(hex: "00F3FF")

                        context.fill(Path(rect), with: .color(color.opacity(0.35)))

                        if Bool.random() {
                            context.fill(Path(rect.offsetBy(dx: 4, dy: 0)), with: .color(Color(hex: "FF00FF").opacity(0.2)))
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
