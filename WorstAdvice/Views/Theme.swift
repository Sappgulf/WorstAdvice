import SwiftUI

enum Theme {
    static let cardCornerRadius: CGFloat = 28
    static let cardPadding: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
    static let largeTapTargetHeight: CGFloat = 52

    static let headlineFont: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    static let cardFont: Font = .system(.title2, design: .rounded, weight: .semibold)
    static let bodyFont: Font = .system(.body, design: .rounded, weight: .regular)
    static let chipFont: Font = .system(.subheadline, design: .rounded, weight: .medium)

    static func cardShadow(for theme: ThemeMode) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch theme {
        case .neon:
            return (Color.cyan.opacity(0.4), 18, 4)
        case .dark:
            return (Color.purple.opacity(0.3), 14, 3)
        case .warm:
            return (Color.orange.opacity(0.2), 10, 3)
        case .sepia:
            return (Color.brown.opacity(0.15), 8, 2)
        case .evergreen:
            return (Color.green.opacity(0.2), 10, 3)
        case .sunrise:
            return (Color.pink.opacity(0.25), 12, 3)
        }
    }

    static func backgroundGradient(for mode: ThemeMode) -> LinearGradient {
        switch mode {
        case .warm:
            return LinearGradient(
                colors: [Color(hex: "F7F2E8"), Color(hex: "F2EBDD"), Color(hex: "ECE2D1")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: [Color(hex: "1C1B24"), Color(hex: "2D2A3A"), Color(hex: "3A334B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neon:
            return LinearGradient(
                colors: [Color(hex: "0A1422"), Color(hex: "0C2A45"), Color(hex: "0F4158")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sepia:
            return LinearGradient(
                colors: [Color(hex: "F3EBDC"), Color(hex: "E8DDC7"), Color(hex: "DCCDAD")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .evergreen:
            return LinearGradient(
                colors: [Color(hex: "E8F1EB"), Color(hex: "D9E7DE"), Color(hex: "C6D7CB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunrise:
            return LinearGradient(
                colors: [Color(hex: "F8EEE8"), Color(hex: "F2E0D9"), Color(hex: "E9CCC1")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func accent(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "8F4A22")
        case .dark: return Color(hex: "F39A5B")
        case .neon: return Color(hex: "00BCD4")
        case .sepia: return Color(hex: "7A5B3A")
        case .evergreen: return Color(hex: "2F684D")
        case .sunrise: return Color(hex: "A3543D")
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "FBF7EE")
        case .dark: return Color.white.opacity(0.13)
        case .neon: return Color(hex: "0E2637").opacity(0.92)
        case .sepia: return Color(hex: "F8F1E4")
        case .evergreen: return Color(hex: "F2F8F4")
        case .sunrise: return Color(hex: "FBF2EE")
        }
    }

    static func primaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "2F281F")
        case .dark: return Color(hex: "F7EADA")
        case .neon: return Color(hex: "D3E9F4")
        case .sepia: return Color(hex: "352A1E")
        case .evergreen: return Color(hex: "203229")
        case .sunrise: return Color(hex: "372823")
        }
    }

    static func secondaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "665746")
        case .dark: return Color(hex: "CFBCA9")
        case .neon: return Color(hex: "96B7C7")
        case .sepia: return Color(hex: "6A5A47")
        case .evergreen: return Color(hex: "4D6258")
        case .sunrise: return Color(hex: "6A544F")
        }
    }

    static func buttonText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return .white
        case .dark: return Color(hex: "161219")
        case .neon: return Color(hex: "062333")
        case .sepia: return .white
        case .evergreen: return .white
        case .sunrise: return .white
        }
    }

    static func tabBarBackground(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "F2E9D9")
        case .dark: return Color(hex: "252230")
        case .neon: return Color(hex: "083145")
        case .sepia: return Color(hex: "EBDDCA")
        case .evergreen: return Color(hex: "D4E1D7")
        case .sunrise: return Color(hex: "F0DDD4")
        }
    }

    static func particleColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "FFE7D1")
        case .dark: return Color(hex: "FFD1A9")
        case .neon: return Color(hex: "38F0FF")
        case .sepia: return Color(hex: "C6A87C")
        case .evergreen: return Color(hex: "6BA98A")
        case .sunrise: return Color(hex: "E8A58E")
        }
    }
}

struct ThemeBackgroundView: View {
    let mode: ThemeMode

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: mode)
            if mode == .warm || mode == .sepia {
                LinearGradient(
                    colors: [Color.white.opacity(0.26), Color.clear, Color(hex: "D5C3A8").opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)

                PaperGrainView()
                    .blendMode(.multiply)
                    .opacity(mode == .warm ? 0.35 : 0.28)
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
