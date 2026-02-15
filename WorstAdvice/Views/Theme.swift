import SwiftUI

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
        }
    }

    static func accent(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "E07A5F") // Muted Coral
        case .minimal: return Color(hex: "1C1C1E") // Black
        case .ember: return Color(hex: "D65A31")
        case .slate: return Color(hex: "AAB7B8")
        case .evergreen: return Color(hex: "81C784") // Natural Sage Green
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "3D2C3E").opacity(0.6)
        case .minimal: return Color.white
        case .ember: return Color(hex: "5E3030").opacity(0.4)
        case .slate: return Color(hex: "3E5062").opacity(0.7)
        case .evergreen: return Color(hex: "253D2E").opacity(0.6)
        }
    }

    static func primaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "FFFAF0") // Brighter White
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FFF5E6") // High contrast white
        case .slate: return Color(hex: "ECF0F1")
        case .evergreen: return Color(hex: "FFFFFF") // Pure White for max contrast
        }
    }

    static func secondaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "C2B2C2")
        case .minimal: return Color(hex: "8E8E93")
        case .ember: return Color(hex: "D0B0B0")
        case .slate: return Color(hex: "BDC3C7")
        case .evergreen: return Color(hex: "A5D6A7") // Lighter Green-Grey
        }
    }

    static func buttonText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "2D1B2E")
        case .minimal: return .white
        case .ember: return .white
        case .slate: return Color(hex: "2C3E50")
        case .evergreen: return Color(hex: "142119")
        }
    }

    static func tabBarBackground(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "1A181C")
        case .minimal: return Color(hex: "EEEEF0")
        case .ember: return Color(hex: "261212")
        case .slate: return Color(hex: "233140")
        case .evergreen: return Color(hex: "142119")
        }
    }

    static func particleColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "E07A5F")
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FF6B6B")
        case .slate: return Color(hex: "ECF0F1")
        case .evergreen: return Color(hex: "66BB6A") // Slightly darker sage for particles
        }
    }

    static func headerColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .minimal: return Color(hex: "1C1C1E")
        default: return Color(hex: "FFFAF0") // High contrast off-white for all dark themes
        }
    }
}

struct ThemeBackgroundView: View {
    let mode: ThemeMode

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: mode)
            if mode == .badvice || mode == .ember || mode == .evergreen {
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
            let path = Self.grainPath(size: size)
            context.fill(path, with: .color(.primary.opacity(0.04)))
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
