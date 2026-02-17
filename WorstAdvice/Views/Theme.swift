import SwiftUI

enum RenderBudget {
    case full
    case balanced
    case reduced
}

enum Theme {
    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
    static let largeTapTargetHeight: CGFloat = 56

    static let headlineFont: Font = .system(.largeTitle, design: .serif, weight: .bold)
    static let cardFont: Font = .system(.title2, design: .default, weight: .semibold)
    static let bodyFont: Font = .system(.body, design: .default, weight: .regular)
    static let chipFont: Font = .system(.subheadline, design: .rounded, weight: .medium)

    static func cardShadow(for theme: ThemeMode) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch theme {
        case .badvice:
            return (Color.black.opacity(0.4), 16, 6)
        case .minimal:
            return (Color.black.opacity(0.08), 12, 4)
        case .ember:
            return (Color(hex: "5E2C2C").opacity(0.3), 14, 5)
        case .slate:
            return (Color.black.opacity(0.25), 10, 3)
        case .evergreen:
            return (Color.black.opacity(0.3), 14, 5)
        case .neon:
            return (Color(hex: "FF00FF").opacity(0.3), 20, 8)
        case .midnight:
            return (Color.black.opacity(0.5), 18, 8)
        case .sunset:
            return (Color(hex: "FF6B35").opacity(0.25), 16, 6)
        case .cosmic:
            return (Color(hex: "9D4EDD").opacity(0.4), 22, 8)
        case .retro:
            return (Color(hex: "00FF9F").opacity(0.2), 14, 5)
        }
    }

    static func backgroundGradient(for mode: ThemeMode) -> LinearGradient {
        switch mode {
        case .badvice:
            return LinearGradient(
                colors: [Color(hex: "1A111A"), Color(hex: "121212")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimal:
            return LinearGradient(
                colors: [Color(hex: "F9F9F9"), Color(hex: "F2F2F7")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .ember:
            return LinearGradient(
                colors: [Color(hex: "4A2626"), Color(hex: "2E1A1A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .slate:
            return LinearGradient(
                colors: [Color(hex: "2C3E50"), Color(hex: "34495E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .evergreen:
            return LinearGradient(
                colors: [Color(hex: "1A2F23"), Color(hex: "142119")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neon:
            return LinearGradient(
                colors: [Color(hex: "0A0A0A"), Color(hex: "1A0033")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .midnight:
            return LinearGradient(
                colors: [Color(hex: "000000"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .sunset:
            return LinearGradient(
                colors: [Color(hex: "FF512F"), Color(hex: "DD2476")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cosmic:
            return LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .retro:
            return LinearGradient(
                colors: [Color(hex: "2C1A3D"), Color(hex: "1A1A2E")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func accent(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "E07A5F") // Muted Coral
        case .minimal: return Color(hex: "1C1C1E") // Black
        case .ember: return Color(hex: "D65A31")
        case .slate: return Color(hex: "AAB7B8")
        case .evergreen: return Color(hex: "81C784") // Natural Sage Green
        case .neon: return Color(hex: "FF00FF") // Hot Magenta
        case .midnight: return Color(hex: "5E81AC") // Frost Blue
        case .sunset: return Color(hex: "FFD700") // Gold
        case .cosmic: return Color(hex: "C77DFF") // Purple
        case .retro: return Color(hex: "00FF9F") // Matrix Green
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "3D2C3E").opacity(0.6)
        case .minimal: return Color.white
        case .ember: return Color(hex: "5E3030").opacity(0.4)
        case .slate: return Color(hex: "3E5062").opacity(0.7)
        case .evergreen: return Color(hex: "253D2E").opacity(0.6)
        case .neon: return Color(hex: "1A1A2E").opacity(0.8)
        case .midnight: return Color(hex: "16213E").opacity(0.7)
        case .sunset: return Color(hex: "2D1B4E").opacity(0.5)
        case .cosmic: return Color(hex: "1A1A2E").opacity(0.6)
        case .retro: return Color(hex: "2D1B4E").opacity(0.7)
        }
    }

    static func primaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "FFFAF0") // Brighter White
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FFF5E6") // High contrast white
        case .slate: return Color(hex: "ECF0F1")
        case .evergreen: return Color(hex: "FFFFFF")
        case .neon: return Color(hex: "FFFFFF")
        case .midnight: return Color(hex: "E5E9F0")
        case .sunset: return Color(hex: "FFFFFF")
        case .cosmic: return Color(hex: "F8F9FA")
        case .retro: return Color(hex: "00FF9F")
        }
    }

    static func secondaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "C2B2C2")
        case .minimal: return Color(hex: "8E8E93")
        case .ember: return Color(hex: "D0B0B0")
        case .slate: return Color(hex: "BDC3C7")
        case .evergreen: return Color(hex: "A5D6A7") // Lighter Green-Grey
        case .neon: return Color(hex: "FF00FF").opacity(0.7)
        case .midnight: return Color(hex: "81A1C1")
        case .sunset: return Color(hex: "FFE4E1")
        case .cosmic: return Color(hex: "E0AAFF")
        case .retro: return Color(hex: "00FF9F").opacity(0.7)
        }
    }

    static func buttonText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "2D1B2E")
        case .minimal: return .white
        case .ember: return .white
        case .slate: return Color(hex: "2C3E50")
        case .evergreen: return Color(hex: "142119")
        case .neon: return .black
        case .midnight: return .black
        case .sunset: return .black
        case .cosmic: return .black
        case .retro: return .black
        }
    }

    static func tabBarBackground(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "1A181C")
        case .minimal: return Color(hex: "EEEEF0")
        case .ember: return Color(hex: "261212")
        case .slate: return Color(hex: "233140")
        case .evergreen: return Color(hex: "142119")
        case .neon: return Color(hex: "0A0A0A")
        case .midnight: return Color(hex: "000000")
        case .sunset: return Color(hex: "1A0A2E")
        case .cosmic: return Color(hex: "0F0C29")
        case .retro: return Color(hex: "1A1A2E")
        }
    }

    static func particleColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "E07A5F")
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FF6B6B")
        case .slate: return Color(hex: "ECF0F1")
        case .evergreen: return Color(hex: "66BB6A") // Slightly darker sage for particles
        case .neon: return Color(hex: "00FFFF")
        case .midnight: return Color(hex: "88C0D0")
        case .sunset: return Color(hex: "FFD700")
        case .cosmic: return Color(hex: "9D4EDD")
        case .retro: return Color(hex: "00FF9F")
        }
    }

    static func headerColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .retro: return Color(hex: "00FF9F")
        default: return Color(hex: "1C1C1E") // Iconic Black
        }
    }

    static func headerShadowColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .minimal: return .clear
        case .neon: return Color(hex: "FF00FF").opacity(0.8)
        case .retro: return Color(hex: "00FF9F").opacity(0.8)
        default: return .white.opacity(0.85) // Strong glow for visibility on dark backgrounds
        }
    }
}

struct ThemeBackgroundView: View {
    let mode: ThemeMode
    var budget: RenderBudget = .balanced
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: mode)

            if scenePhase == .active {
                let allowsDynamic = budget != .reduced
                let allowsFullEffects = budget == .full

                if allowsDynamic && mode != .minimal {
                    DynamicChaosView(theme: mode)
                        .opacity(allowsFullEffects ? 0.4 : 0.26)
                        .blendMode(.screen)
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
                }

                if allowsFullEffects && mode == .neon {
                    NeonGridView()
                        .opacity(0.15)
                        .blendMode(.screen)
                }

                if allowsFullEffects && mode == .cosmic {
                    StarFieldView()
                        .opacity(0.6)
                }

                if allowsFullEffects && mode == .retro {
                    ScanlineView()
                        .opacity(0.1)
                        .blendMode(.overlay)
                }
            }

            CinematicVignetteView()
                .opacity(mode == .minimal ? 0.3 : 0.6)
                .allowsHitTesting(false)
        }
    }
}

/// A premium cinematic vignette that adds depth and focus to the UI.
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

/// A slow-moving, atmospheric procedural background that creates a sense of depth and "chaos".
struct DynamicChaosView: View {
    let theme: ThemeMode
    
    @State private var start = Date()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(start)
                let accentColor = Theme.accent(for: theme)
                
                // Draw 3 layers of soft, moving "blobs"
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

    private static func grainPath(size: CGSize) -> Path {
        var path = Path()
        let step: CGFloat = 4
        var x: CGFloat = 0
        while x < size.width {
            var y: CGFloat = 0
            while y < size.height {
                let hash = (x * 374761 + y * 668265).truncatingRemainder(dividingBy: 100)
                if hash < 30 {
                    let dotSize: CGFloat = hash < 10 ? 1.0 : 0.6
                    path.addEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                }
                y += step
            }
            x += step
        }
        return path
    }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let step: CGFloat = 4
            let dotOpacity: Double = 0.04
            
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let hash = (x * 374761 + y * 668265).truncatingRemainder(dividingBy: 100)
                    if hash < 30 {
                        let dotSize: CGFloat = hash < 10 ? 1.0 : 0.6
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

// MARK: - Special Theme Effects

private struct NeonGridView: View {
    @State private var phase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let gridSize: CGFloat = 40
                let lineOpacity = 0.3 + 0.2 * sin(phase)
                
                // Draw vertical lines
                for x in stride(from: 0, to: size.width, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(Color(hex: "FF00FF").opacity(lineOpacity)), lineWidth: 1)
                }
                
                // Draw horizontal lines
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color(hex: "00FFFF").opacity(lineOpacity)), lineWidth: 1)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

private struct StarFieldView: View {
    @State private var start = Date()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
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
    @State private var offset: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
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
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                offset = 6
            }
        }
    }
}
