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

    static func backgroundGradient(for mode: ThemeMode) -> LinearGradient {
        switch mode {
        case .warm:
            return LinearGradient(
                colors: [Color(hex: "FFF4E3"), Color(hex: "F7D8BC"), Color(hex: "EFB38A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(hex: "1C1B24"), Color(hex: "2D2A3A"), Color(hex: "3A334B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neon:
            return LinearGradient(
                colors: [Color(hex: "10172A"), Color(hex: "052F5F"), Color(hex: "005377")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func accent(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "A9491C")
        case .dark: return Color(hex: "F39A5B")
        case .neon: return Color(hex: "00E5FF")
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color.white.opacity(0.85)
        case .dark: return Color.white.opacity(0.13)
        case .neon: return Color.white.opacity(0.14)
        }
    }

    static func primaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "322319")
        case .dark: return Color(hex: "F7EADA")
        case .neon: return Color(hex: "E5F9FF")
        }
    }

    static func secondaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return Color(hex: "5A4231")
        case .dark: return Color(hex: "CFBCA9")
        case .neon: return Color(hex: "A7E8F7")
        }
    }

    static func buttonText(for mode: ThemeMode) -> Color {
        switch mode {
        case .warm: return .white
        case .dark: return Color(hex: "161219")
        case .neon: return Color(hex: "001D29")
        }
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
