import SwiftUI

enum RenderBudget {
    case full
    case balanced
    case reduced
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    @State private var loaded = false
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: some View {
        if loaded {
            build()
        } else {
            Color.clear
                .onAppear {
                    loaded = true
                }
        }
    }
}


enum Theme {
    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 14
    static let cardInnerSpacing: CGFloat = 10
    static let compactCornerRadius: CGFloat = 12
    static let mediumCornerRadius: CGFloat = 14
    static let largeCornerRadius: CGFloat = 18
    static let minimumTapTarget: CGFloat = 44
    static let compactIconButtonSize: CGFloat = 44
    static let chipMinHeight: CGFloat = 26
    static let chipHorizontalPadding: CGFloat = 9
    static let chipVerticalPadding: CGFloat = 4
    static let largeTapTargetHeight: CGFloat = 52

    // MARK: - Animation durations (standardized)
    /// Fast: micro-interactions, icon changes — 0.18–0.22s
    static let animFast: Double = 0.20
    /// Medium: panel transitions, entry/exit — 0.28–0.35s
    static let animMedium: Double = 0.32
    /// Slow: page-level transitions — 0.45s
    static let animSlow: Double = 0.45

    // MARK: - Spring Animations (Organic)
    
    static var springSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.1)
    }

    static var springBouncy: Animation {
        .spring(response: 0.45, dampingFraction: 0.55, blendDuration: 0.2)
    }
    
    static var springSmooth: Animation {
        .spring(response: 0.55, dampingFraction: 0.8, blendDuration: 0.3)
    }

    static let headlineFont: Font = headlineFont(for: .badvice)
    static let cardFont: Font = cardFont(for: .badvice)
    static let bodyFont: Font = bodyFont(for: .badvice)
    static let chipFont: Font = chipFont(for: .badvice)

    static func headlineFont(for mode: ThemeMode) -> Font {
        switch mode {
        case .fallout, .retro, .cybernetic:
            return .system(.largeTitle, design: .monospaced, weight: .bold)
        case .minimal, .slate, .evergreen:
            return .system(.largeTitle, design: .rounded, weight: .bold)
        default:
            return .system(.largeTitle, design: .serif, weight: .bold)
        }
    }

    static func cardFont(for mode: ThemeMode) -> Font {
        switch mode {
        case .fallout, .retro, .cybernetic:
            return .system(.title3, design: .monospaced, weight: .semibold)
        case .minimal, .slate:
            return .system(.title3, design: .rounded, weight: .semibold)
        case .sunset, .cosmic, .ember:
            return .system(.title3, design: .serif, weight: .semibold)
        default:
            return .system(.title3, design: .default, weight: .semibold)
        }
    }

    static func bodyFont(for mode: ThemeMode) -> Font {
        switch mode {
        case .fallout, .retro, .cybernetic:
            return .system(.body, design: .monospaced, weight: .regular)
        case .minimal, .slate, .evergreen:
            return .system(.body, design: .rounded, weight: .regular)
        default:
            return .system(.body, design: .default, weight: .regular)
        }
    }

    static func chipFont(for mode: ThemeMode) -> Font {
        switch mode {
        case .fallout, .retro, .cybernetic:
            return .system(.subheadline, design: .monospaced, weight: .semibold)
        default:
            return .system(.subheadline, design: .rounded, weight: .medium)
        }
    }
    
    // MARK: - Performance: Gradient Cache
    
    private static var gradientCache: [ThemeMode: LinearGradient] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.worstadvice.theme.cache", qos: .userInitiated)

    static func cardShadow(for theme: ThemeMode) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch theme {
        case .badvice:
            return (Color.black.opacity(0.45), 18, 7)
        case .minimal:
            return (Color.black.opacity(0.06), 8, 3)
        case .ember:
            return (Color(hex: "5E2C2C").opacity(0.5), 16, 6)
        case .slate:
            return (Color.black.opacity(0.35), 12, 4)
        case .evergreen:
            return (Color(hex: "0A1A10").opacity(0.4), 16, 6)
        case .fallout:
            return (Color(hex: "63FF74").opacity(0.32), 18, 6)
        case .neon:
            return (Color(hex: "FF00FF").opacity(0.4), 24, 10)
        case .midnight:
            return (Color.black.opacity(0.6), 20, 9)
        case .sunset:
            return (Color(hex: "DD2476").opacity(0.35), 18, 7)
        case .cosmic:
            return (Color(hex: "9D4EDD").opacity(0.5), 24, 9)
        case .retro:
            return (Color(hex: "00FF9F").opacity(0.3), 16, 6)
        case .cybernetic:
            return (Color(hex: "00F3FF").opacity(0.45), 22, 8)
        }
    }
    
    /// Returns a secondary shadow for enhanced depth (used for layered shadow effects)
    static func cardSecondaryShadow(for theme: ThemeMode) -> (color: Color, radius: CGFloat, y: CGFloat)? {
        switch theme {
        case .neon:
            return (Color(hex: "00FFFF").opacity(0.2), 12, 5)
        case .cosmic:
            return (Color(hex: "C77DFF").opacity(0.3), 12, 4)
        case .sunset:
            return (Color(hex: "FFD700").opacity(0.2), 10, 3)
        case .retro:
            return (Color(hex: "FF1493").opacity(0.2), 10, 3)
        default:
            return nil
        }
    }

    static func backgroundGradient(for mode: ThemeMode) -> LinearGradient {
        cacheQueue.sync {
            if let cached = gradientCache[mode] {
                return cached
            }

            let gradient: LinearGradient
            switch mode {
            case .badvice:
                gradient = LinearGradient(
                    colors: [Color(hex: "20121D"), Color(hex: "151116"), Color(hex: "0E0A0F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .minimal:
                gradient = LinearGradient(
                    colors: [Color(hex: "FBFBFC"), Color(hex: "F4F5F8"), Color(hex: "EDEEF2")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .ember:
                gradient = LinearGradient(
                    colors: [Color(hex: "5B2A24"), Color(hex: "341816"), Color(hex: "1B0D0D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .slate:
                gradient = LinearGradient(
                    colors: [Color(hex: "233347"), Color(hex: "2B3C52"), Color(hex: "3A5068")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .evergreen:
                gradient = LinearGradient(
                    colors: [Color(hex: "203628"), Color(hex: "15271C"), Color(hex: "0C140E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .fallout:
                gradient = LinearGradient(
                    colors: [Color(hex: "071006"), Color(hex: "0D1B0A"), Color(hex: "132611")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .neon:
                gradient = LinearGradient(
                    colors: [Color(hex: "060608"), Color(hex: "160029"), Color(hex: "33004D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .midnight:
                gradient = LinearGradient(
                    colors: [Color(hex: "020308"), Color(hex: "0A1321"), Color(hex: "111C36")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sunset:
                gradient = LinearGradient(
                    colors: [Color(hex: "FF6A3D"), Color(hex: "DD2476"), Color(hex: "6A2C70")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .cosmic:
                gradient = LinearGradient(
                    colors: [Color(hex: "0B0B18"), Color(hex: "171A3A"), Color(hex: "332A6B"), Color(hex: "24123A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .retro:
                gradient = LinearGradient(
                    colors: [Color(hex: "1E1A39"), Color(hex: "2D1741"), Color(hex: "121827")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .cybernetic:
                gradient = LinearGradient(
                    colors: [Color(hex: "050A0E"), Color(hex: "081826"), Color(hex: "0B3140"), Color(hex: "0E5163")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            gradientCache[mode] = gradient
            return gradient
        }
    }

    static func canvasColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "0F0D11")
        case .minimal: return Color(hex: "F4F4F6")
        case .ember: return Color(hex: "1B100F")
        case .slate: return Color(hex: "1A2430")
        case .evergreen: return Color(hex: "0E1712")
        case .fallout: return Color(hex: "060D05")
        case .neon: return Color(hex: "08080C")
        case .midnight: return Color(hex: "05070B")
        case .sunset: return Color(hex: "1A0F23")
        case .cosmic: return Color(hex: "090913")
        case .retro: return Color(hex: "0D111A")
        case .cybernetic: return Color(hex: "050A0E")
        }
    }

    static func accent(for mode: ThemeMode, customColor: Color? = nil) -> Color {
        if let custom = customColor {
            return custom
        }
        switch mode {
        case .badvice: return Color(hex: "E88D72") // Brighter Coral with more saturation
        case .minimal: return Color(hex: "1C1C1E") // Black
        case .ember: return Color(hex: "FF6B47") // Vibrant Ember Orange
        case .slate: return Color(hex: "8EC5FC") // Cool Blue accent for better contrast
        case .evergreen: return Color(hex: "66BB6A") // Vibrant Sage Green
        case .fallout: return Color(hex: "8CFF7A") // Pip-Boy phosphor green
        case .neon: return Color(hex: "FF00FF") // Hot Magenta
        case .midnight: return Color(hex: "88C0D0") // Brighter Frost Blue
        case .sunset: return Color(hex: "FFD700") // Gold
        case .cosmic: return Color(hex: "C77DFF") // Purple
        case .retro: return Color(hex: "00FF9F") // Matrix Green
        case .cybernetic: return Color(hex: "00F3FF") // Cyan
        }
    }
    
    /// Returns a secondary accent color for enhanced visual interest
    static func secondaryAccent(for mode: ThemeMode) -> Color? {
        switch mode {
        case .sunset:
            return Color(hex: "FF6B35") // Coral complement to gold
        case .cosmic:
            return Color(hex: "9D4EDD") // Deeper purple
        case .neon:
            return Color(hex: "00FFFF") // Cyan complement
        case .retro:
            return Color(hex: "FF1493") // Hot Pink complement
        case .cybernetic:
            return Color(hex: "FF00FF") // Magenta complement
        case .evergreen:
            return Color(hex: "4CAF50") // Forest complement
        case .fallout:
            return Color(hex: "E1C95C") // Vault-Tec amber highlight
        default:
            return nil
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "342336").opacity(0.84)
        case .minimal: return Color.white
        case .ember: return Color(hex: "4F2728").opacity(0.84)
        case .slate: return Color(hex: "314355").opacity(0.84)
        case .evergreen: return Color(hex: "1E3426").opacity(0.86)
        case .fallout: return Color(hex: "0D160A").opacity(0.9)
        case .neon: return Color(hex: "101125").opacity(0.9)
        case .midnight: return Color(hex: "101B34").opacity(0.88)
        case .sunset: return Color(hex: "281732").opacity(0.84)
        case .cosmic: return Color(hex: "131426").opacity(0.86)
        case .retro: return Color(hex: "1E1731").opacity(0.86)
        case .cybernetic: return Color(hex: "08111C").opacity(0.9)
        }
    }
    
    /// Returns the glassmorphism intensity for themes that support it
    static func glassMorphismOpacity(for mode: ThemeMode) -> Double {
        switch mode {
        case .minimal:
            return 0.0 // No glass effect for minimal
        case .neon, .cosmic, .midnight:
            return 0.6 // Strong glass effect for vibrant themes
        case .sunset, .retro:
            return 0.55
        case .cybernetic:
            return 0.65 // Stronger glass for cyber theme
        case .fallout:
            return 0.42
        default:
            return 0.5 // Default glass effect
        }
    }

    static func primaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "FFFCF7") // Warm bright white
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FFFAF0") // Warm white with better contrast
        case .slate: return Color(hex: "F0F4F8") // Cooler white
        case .evergreen: return Color(hex: "F5FFF7") // Slight green tint white
        case .fallout: return Color(hex: "D8FFCC")
        case .neon: return Color(hex: "FFFFFF")
        case .midnight: return Color(hex: "ECEFF4") // Nord Snow Storm
        case .sunset: return Color(hex: "FFF8F0") // Warm white
        case .cosmic: return Color(hex: "FFFFFF")
        case .retro: return Color(hex: "E0FFE0") // Slight green tint for CRT effect
        case .cybernetic: return Color(hex: "DCF9FF") // Electrified blue-white
        }
    }

    static func secondaryText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "D0C0D0") // Lighter, better contrast
        case .minimal: return Color(hex: "8E8E93")
        case .ember: return Color(hex: "FFCAB0") // Warmer, more visible
        case .slate: return Color(hex: "CBD5E1") // Cooler, higher contrast
        case .evergreen: return Color(hex: "A5D6A7") // Lighter Green-Grey
        case .fallout: return Color(hex: "9BD889")
        case .neon: return Color(hex: "FF00FF").opacity(0.8) // More opaque
        case .midnight: return Color(hex: "88C0D0") // Nord Frost
        case .sunset: return Color(hex: "FFE4CC") // Warmer
        case .cosmic: return Color(hex: "E0AAFF") // Lighter purple
        case .retro: return Color(hex: "66FFB2") // Brighter for visibility
        case .cybernetic: return Color(hex: "00F3FF").opacity(0.85)
        }
    }

    static func buttonText(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "2D1B2E")
        case .minimal: return .white
        case .ember: return .white
        case .slate: return Color(hex: "2C3E50")
        case .evergreen: return Color(hex: "142119")
        case .fallout: return Color(hex: "0B1008")
        case .neon: return .black
        case .midnight: return .black
        case .sunset: return .black
        case .cosmic: return .black
        case .retro: return .black
        case .cybernetic: return .black
        }
    }

    /// Returns the preferred color scheme for a theme, so system-rendered elements
    /// (nav title, search bar, etc.) use the correct foreground color.
    static func colorScheme(for mode: ThemeMode) -> ColorScheme {
        switch mode {
        case .minimal: return .light
        default:       return .dark
        }
    }

    static func tabBarBackground(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "1A181C")
        case .minimal: return Color(hex: "EEEEF0")
        case .ember: return Color(hex: "261212")
        case .slate: return Color(hex: "233140")
        case .evergreen: return Color(hex: "142119")
        case .fallout: return Color(hex: "0B1409")
        case .neon: return Color(hex: "0A0A0A")
        case .midnight: return Color(hex: "000000")
        case .sunset: return Color(hex: "1A0A2E")
        case .cosmic: return Color(hex: "0F0C29")
        case .retro: return Color(hex: "1A1A2E")
        case .cybernetic: return Color(hex: "080B12")
        }
    }

    static func particleColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "E88D72")
        case .minimal: return Color(hex: "1C1C1E")
        case .ember: return Color(hex: "FF6B47")
        case .slate: return Color(hex: "8EC5FC")
        case .evergreen: return Color(hex: "66BB6A")
        case .fallout: return Color(hex: "8CFF7A")
        case .neon: return Color(hex: "00FFFF")
        case .midnight: return Color(hex: "88C0D0")
        case .sunset: return Color(hex: "FFD700")
        case .cosmic: return Color(hex: "9D4EDD")
        case .retro: return Color(hex: "00FF9F")
        case .cybernetic: return Color(hex: "00F3FF")
        }
    }
    
    /// Secondary particle color for multi-color effects
    static func secondaryParticleColor(for mode: ThemeMode) -> Color? {
        switch mode {
        case .neon:
            return Color(hex: "FF00FF") // Alternate between cyan and magenta
        case .cosmic:
            return Color(hex: "C77DFF") // Lighter purple
        case .sunset:
            return Color(hex: "FF6B35") // Coral orange
        case .retro:
            return Color(hex: "FF1493") // Hot pink
        case .cybernetic:
            return Color(hex: "7000FF") // Deep purple
        case .fallout:
            return Color(hex: "CCFF99")
        default:
            return nil
        }
    }
    
    /// Returns whether a theme should use glow effects
    static func shouldUseGlow(for mode: ThemeMode) -> Bool {
        switch mode {
        case .neon, .cosmic, .retro, .midnight, .cybernetic, .fallout:
            return true
        default:
            return false
        }
    }
    
    /// Returns the glow color for themes that support it
    static func glowColor(for mode: ThemeMode) -> Color? {
        guard shouldUseGlow(for: mode) else { return nil }
        switch mode {
        case .neon:
            return Color(hex: "FF00FF")
        case .cosmic:
            return Color(hex: "9D4EDD")
        case .retro:
            return Color(hex: "00FF9F")
        case .midnight:
            return Color(hex: "88C0D0")
        case .cybernetic:
            return Color(hex: "00F3FF")
        case .fallout:
            return Color(hex: "8CFF7A")
        default:
            return nil
        }
    }

    static func headerColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .retro: return Color(hex: "00FF9F")
        case .neon: return Color(hex: "FF00FF")
        case .cosmic: return Color(hex: "C77DFF")
        case .sunset: return Color(hex: "FFD700")
        case .ember: return Color(hex: "FF6B47")
        case .evergreen: return Color(hex: "66BB6A")
        case .fallout: return Color(hex: "8CFF7A")
        case .midnight: return Color(hex: "88C0D0")
        case .cybernetic: return Color(hex: "00F3FF")
        default: return Color(hex: "1C1C1E") // Iconic Black
        }
    }

    static func headerShadowColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .minimal: return .clear
        case .neon: return Color(hex: "FF00FF").opacity(0.9)
        case .retro: return Color(hex: "00FF9F").opacity(0.9)
        case .cosmic: return Color(hex: "C77DFF").opacity(0.8)
        case .sunset: return Color(hex: "FFD700").opacity(0.7)
        case .ember: return Color(hex: "FF6B47").opacity(0.7)
        case .evergreen: return Color(hex: "66BB6A").opacity(0.6)
        case .fallout: return Color(hex: "8CFF7A").opacity(0.72)
        case .midnight: return Color(hex: "88C0D0").opacity(0.8)
        case .cybernetic: return Color(hex: "00F3FF").opacity(0.9)
        default: return .white.opacity(0.9) // Strong glow for visibility on dark backgrounds
        }
    }
    
    /// Returns whether the header should have an animated glow effect
    static func headerShouldGlow(for mode: ThemeMode) -> Bool {
        switch mode {
        case .neon, .cosmic, .retro, .midnight, .cybernetic, .fallout:
            return true
        default:
            return false
        }
    }

    static func personality(for mode: ThemeMode) -> ThemePersonality {
        switch mode {
        case .badvice:
            return ThemePersonality(
                descriptor: "Editorial mischief with warm grain",
                surfaceMood: "Velvet Paper",
                bestFor: "Best for the core Badvice vibe",
                effectIntensity: 0.62,
                indicatorCornerRadius: 16,
                indicatorInset: 2
            )
        case .minimal:
            return ThemePersonality(
                descriptor: "Clean clarity, low visual noise",
                surfaceMood: "Studio Flat",
                bestFor: "Best for focus and readability",
                effectIntensity: 0.12,
                indicatorCornerRadius: 10,
                indicatorInset: 3
            )
        case .ember:
            return ThemePersonality(
                descriptor: "Heat-haze depth with molten contrast",
                surfaceMood: "Kiln Glow",
                bestFor: "Best for warm, dramatic contrast",
                effectIntensity: 0.58,
                indicatorCornerRadius: 14,
                indicatorInset: 2
            )
        case .slate:
            return ThemePersonality(
                descriptor: "Cool executive glass with crisp edges",
                surfaceMood: "Steel Glass",
                bestFor: "Best for calm dashboards",
                effectIntensity: 0.4,
                indicatorCornerRadius: 12,
                indicatorInset: 2
            )
        case .evergreen:
            return ThemePersonality(
                descriptor: "Forest calm with layered texture",
                surfaceMood: "Canopy Grain",
                bestFor: "Best for longer sessions",
                effectIntensity: 0.55,
                indicatorCornerRadius: 15,
                indicatorInset: 2
            )
        case .fallout:
            return ThemePersonality(
                descriptor: "Vault terminal glow with phosphor depth",
                surfaceMood: "Pip-Boy Phosphor",
                bestFor: "Best for terminal-flavored UI",
                effectIntensity: 0.7,
                indicatorCornerRadius: 10,
                indicatorInset: 2
            )
        case .neon:
            return ThemePersonality(
                descriptor: "Arcade glow and electric lane markers",
                surfaceMood: "Arcade Grid",
                bestFor: "Best for high-energy browsing",
                effectIntensity: 0.9,
                indicatorCornerRadius: 8,
                indicatorInset: 1
            )
        case .midnight:
            return ThemePersonality(
                descriptor: "Deep-focus dark with cool bloom",
                surfaceMood: "Nocturne Film",
                bestFor: "Best for late-night sessions",
                effectIntensity: 0.68,
                indicatorCornerRadius: 18,
                indicatorInset: 2
            )
        case .sunset:
            return ThemePersonality(
                descriptor: "Golden-hour gradient with soft drama",
                surfaceMood: "Amber Bloom",
                bestFor: "Best for rich gradients",
                effectIntensity: 0.64,
                indicatorCornerRadius: 20,
                indicatorInset: 3
            )
        case .cosmic:
            return ThemePersonality(
                descriptor: "Nebula depth and stellar sparkle",
                surfaceMood: "Starfield Mist",
                bestFor: "Best for dramatic depth",
                effectIntensity: 0.84,
                indicatorCornerRadius: 6,
                indicatorInset: 1
            )
        case .retro:
            return ThemePersonality(
                descriptor: "CRT attitude with scanline pulse",
                surfaceMood: "Synth Scan",
                bestFor: "Best for playful nostalgia",
                effectIntensity: 0.78,
                indicatorCornerRadius: 4,
                indicatorInset: 1
            )
        case .cybernetic:
            return ThemePersonality(
                descriptor: "Metal-optimized glitch with neon precision",
                surfaceMood: "Liquid Wired",
                bestFor: "Best for sharp tech contrast",
                effectIntensity: 0.88,
                indicatorCornerRadius: 2,
                indicatorInset: 1
            )
        }
    }

    static func themeSummary(for mode: ThemeMode) -> String {
        let personality = personality(for: mode)
        return "\(personality.surfaceMood) - \(personality.bestFor)"
    }

    static func tabBarStyle(for mode: ThemeMode) -> ThemeTabBarStyle {
        let personality = personality(for: mode)
        let glow = glowColor(for: mode) ?? accent(for: mode)
        let glassStrength = glassMorphismOpacity(for: mode)
        return ThemeTabBarStyle(
            backgroundTint: tabBarBackground(for: mode).opacity(0.72),
            materialOverlayOpacity: min(max(glassStrength, 0.15), 0.72),
            borderTop: accent(for: mode).opacity(0.34 + personality.effectIntensity * 0.18),
            borderBottom: .white.opacity(0.08 + personality.effectIntensity * 0.08),
            shadow: cardShadow(for: mode).color.opacity(0.45),
            shadowRadius: CGFloat(12 + personality.effectIntensity * 10),
            selectedFillOpacity: 0.14 + personality.effectIntensity * 0.12,
            highlightedFillOpacity: 0.07 + personality.effectIntensity * 0.08,
            indicatorCornerRadius: personality.indicatorCornerRadius,
            indicatorInset: personality.indicatorInset,
            selectedScale: CGFloat(1.04 + personality.effectIntensity * 0.03),
            glow: shouldUseGlow(for: mode) ? glow.opacity(0.45) : nil
        )
    }
}

struct ThemePersonality: Sendable {
    let descriptor: String
    let surfaceMood: String
    let bestFor: String
    let effectIntensity: Double
    let indicatorCornerRadius: CGFloat
    let indicatorInset: CGFloat
}

struct ThemeTabBarStyle: Sendable {
    let backgroundTint: Color
    let materialOverlayOpacity: Double
    let borderTop: Color
    let borderBottom: Color
    let shadow: Color
    let shadowRadius: CGFloat
    let selectedFillOpacity: Double
    let highlightedFillOpacity: Double
    let indicatorCornerRadius: CGFloat
    let indicatorInset: CGFloat
    let selectedScale: CGFloat
    let glow: Color?
}
// Theme view helpers live in ThemeViews.swift.
