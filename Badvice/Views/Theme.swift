import SwiftUI

enum RenderBudget {
    case full
    case balanced
    case reduced
}

enum Theme {
    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 14
    static let cardInnerSpacing: CGFloat = 10
    static let compactCornerRadius: CGFloat = 12
    static let mediumCornerRadius: CGFloat = 14
    static let tileCornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 18
    static let heroCornerRadius: CGFloat = 28
    static let shellPadding: CGFloat = 16
    static let shellSpacing: CGFloat = 12
    static let shellMetricCornerRadius: CGFloat = 10
    static let shellSectionCornerRadius: CGFloat = 16
    static let shellInnerCornerRadius: CGFloat = 14
    static let shellBannerCornerRadius: CGFloat = 18
    static let floatingTabBarCornerRadius: CGFloat = 22
    static let floatingTabBarInnerPadding: CGFloat = 4
    static let floatingTabBarHorizontalPadding: CGFloat = 14
    static let floatingTabBarReservedHeight: CGFloat = 72
    static let floatingTabItemMinHeight: CGFloat = 50
    static let tabContentBottomInset: CGFloat = 124
    static let floatingToastBottomInset: CGFloat = 124
    static let minimumTapTarget: CGFloat = 44
    static let compactIconButtonSize: CGFloat = 44
    static let commandActionMinHeight: CGFloat = 42
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

    // MARK: - Signature motion language (Infernal Editorial)
    /// Primary CTA / new take lands with a confident bounce.
    static var badBounce: Animation {
        .spring(response: 0.38, dampingFraction: 0.58, blendDuration: 0.12)
    }
    /// Card content locks in after generation.
    static var smugSettle: Animation {
        .spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.22)
    }
    /// Dislike / “wrong again” micro-reaction (pair with reduce-motion checks).
    static var pettyShake: Animation {
        .spring(response: 0.22, dampingFraction: 0.32, blendDuration: 0.05)
    }

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

    // MARK: - Infernal copper foil (brand metal)

    static let copperFoilLight = Color(hex: "F0C4A0")
    static let copperFoilMid = Color(hex: "E88D72")
    static let copperFoilDeep = Color(hex: "8F4A22")
    static let espressoInk = Color(hex: "1C130A")
    static let parchmentWarm = Color(hex: "FFF8F0")

    static var copperFoilGradient: LinearGradient {
        LinearGradient(
            colors: [copperFoilLight, copperFoilMid, copperFoilDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var copperEmbossGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.35),
                copperFoilLight.opacity(0.9),
                copperFoilMid,
                copperFoilDeep.opacity(0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        case .badvice, .ember, .sunset:
            return .system(.largeTitle, design: .serif, weight: .bold)
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
        case .badvice, .sunset, .cosmic, .ember:
            // Editorial serif for the take — the product poster typeface.
            return .system(.title3, design: .serif, weight: .semibold)
        default:
            return .system(.title3, design: .default, weight: .semibold)
        }
    }

    /// Tone-linked micro type for advice body (lighter skin over theme).
    static func editorialCardFont(for mode: ThemeMode, tone: ToneMode) -> Font {
        switch tone {
        case .corporateConsultant, .linkedInInfluencer:
            return .system(.title3, design: .default, weight: .semibold)
        case .wizard, .minimalistMonk, .lifeCoach, .oldMoney:
            return .system(.title3, design: .serif, weight: .semibold)
        case .cryptoBro, .genZ, .redditCommenter, .influencer:
            return .system(.title3, design: .rounded, weight: .bold)
        case .conspiracyTheorist, .alphaPodcast:
            return .system(.title3, design: .monospaced, weight: .semibold)
        default:
            return cardFont(for: mode)
        }
    }

    static func bodyFont(for mode: ThemeMode) -> Font {
        switch mode {
        case .fallout, .retro, .cybernetic:
            return .system(.body, design: .monospaced, weight: .regular)
        case .minimal, .slate, .evergreen:
            return .system(.body, design: .rounded, weight: .regular)
        case .badvice:
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

    /// Whether default/editorial surfaces should show paper grain.
    static func usesPaperGrain(for mode: ThemeMode) -> Bool {
        switch mode {
        case .badvice, .ember, .evergreen, .midnight:
            return true
        default:
            return false
        }
    }

    /// Intensity rail width from a 0…100 chaos/wrongness score.
    static func intensityRailWidth(score: Int) -> CGFloat {
        let clamped = min(100, max(0, score))
        return 2.5 + CGFloat(clamped) / 100.0 * 4.5
    }
    
    // MARK: - Performance: Gradient Cache
    
    private static var gradientCache: [ThemeMode: LinearGradient] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.worstadvice.theme.cache", qos: .userInitiated)

    static func cardShadow(for theme: ThemeMode) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch theme {
        case .badvice:
            return (Color.black.opacity(0.52), 22, 10)
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
        case .badvice:
            // Copper foil bloom under the poster card
            return (Color(hex: "E88D72").opacity(0.18), 14, 4)
        case .neon:
            return (Color(hex: "00FFFF").opacity(0.2), 12, 5)
        case .cosmic:
            return (Color(hex: "C77DFF").opacity(0.3), 12, 4)
        case .sunset:
            return (Color(hex: "FFD700").opacity(0.2), 10, 3)
        case .retro:
            return (Color(hex: "FF1493").opacity(0.2), 10, 3)
        case .ember:
            return (Color(hex: "FF6B47").opacity(0.16), 12, 4)
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
                // Deeper vignette espresso with warm copper lift at the top
                gradient = LinearGradient(
                    colors: [
                        Color(hex: "2A1816"),
                        Color(hex: "1A1218"),
                        Color(hex: "120E12"),
                        Color(hex: "0A080B"),
                    ],
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
        case .badvice: return Color(hex: "0C0A0E")
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
        case .badvice: return copperFoilMid // Brand copper
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
        case .badvice:
            return copperFoilLight // Foil highlight
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
        case .ember:
            return Color(hex: "FFB088")
        default:
            return nil
        }
    }

    static func cardColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .badvice: return Color(hex: "2C1C28").opacity(0.92)
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
        case .minimal: return Color(hex: "636366")
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
        case .ember: return Color(hex: "24110E")
        case .slate: return Color(hex: "2C3E50")
        case .evergreen: return Color(hex: "142119")
        case .fallout: return Color(hex: "0B1008")
        case .neon: return .black
        case .midnight: return .black
        case .sunset: return .black
        case .cosmic: return Color(hex: "170C22")
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
        case .neon, .cosmic, .retro, .midnight, .cybernetic, .fallout, .badvice:
            return true
        default:
            return false
        }
    }
    
    /// Returns the glow color for themes that support it
    static func glowColor(for mode: ThemeMode) -> Color? {
        guard shouldUseGlow(for: mode) else { return nil }
        switch mode {
        case .badvice:
            return copperFoilMid
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
        case .badvice: return copperFoilMid
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
        case .badvice: return copperFoilMid.opacity(0.55)
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
                descriptor: "Infernal editorial — copper foil on espresso paper",
                surfaceMood: "Velvet Parchment",
                bestFor: "Best for the core Badvice vibe",
                effectIntensity: 0.68,
                indicatorInset: 2
            )
        case .minimal:
            return ThemePersonality(
                descriptor: "Clean clarity, low visual noise",
                surfaceMood: "Studio Flat",
                bestFor: "Best for focus and readability",
                effectIntensity: 0.12,
                indicatorInset: 3
            )
        case .ember:
            return ThemePersonality(
                descriptor: "Heat-haze depth with molten contrast",
                surfaceMood: "Kiln Glow",
                bestFor: "Best for warm, dramatic contrast",
                effectIntensity: 0.58,
                indicatorInset: 2
            )
        case .slate:
            return ThemePersonality(
                descriptor: "Cool executive glass with crisp edges",
                surfaceMood: "Steel Glass",
                bestFor: "Best for calm dashboards",
                effectIntensity: 0.4,
                indicatorInset: 2
            )
        case .evergreen:
            return ThemePersonality(
                descriptor: "Forest calm with layered texture",
                surfaceMood: "Canopy Grain",
                bestFor: "Best for longer sessions",
                effectIntensity: 0.55,
                indicatorInset: 2
            )
        case .fallout:
            return ThemePersonality(
                descriptor: "Vault terminal glow with phosphor depth",
                surfaceMood: "Pip-Boy Phosphor",
                bestFor: "Best for terminal-flavored UI",
                effectIntensity: 0.7,
                indicatorInset: 2
            )
        case .neon:
            return ThemePersonality(
                descriptor: "Arcade glow and electric lane markers",
                surfaceMood: "Arcade Grid",
                bestFor: "Best for high-energy browsing",
                effectIntensity: 0.9,
                indicatorInset: 1
            )
        case .midnight:
            return ThemePersonality(
                descriptor: "Deep-focus dark with cool bloom",
                surfaceMood: "Nocturne Film",
                bestFor: "Best for late-night sessions",
                effectIntensity: 0.68,
                indicatorInset: 2
            )
        case .sunset:
            return ThemePersonality(
                descriptor: "Golden-hour gradient with soft drama",
                surfaceMood: "Amber Bloom",
                bestFor: "Best for rich gradients",
                effectIntensity: 0.64,
                indicatorInset: 3
            )
        case .cosmic:
            return ThemePersonality(
                descriptor: "Nebula depth and stellar sparkle",
                surfaceMood: "Starfield Mist",
                bestFor: "Best for dramatic depth",
                effectIntensity: 0.84,
                indicatorInset: 1
            )
        case .retro:
            return ThemePersonality(
                descriptor: "CRT attitude with scanline pulse",
                surfaceMood: "Synth Scan",
                bestFor: "Best for playful nostalgia",
                effectIntensity: 0.78,
                indicatorInset: 1
            )
        case .cybernetic:
            return ThemePersonality(
                descriptor: "Metal-optimized glitch with neon precision",
                surfaceMood: "Liquid Wired",
                bestFor: "Best for sharp tech contrast",
                effectIntensity: 0.88,
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
        let glassStrength = glassMorphismOpacity(for: mode)
        let glow: Color? = {
            switch mode {
            case .badvice: return copperFoilMid.opacity(0.35)
            case .neon, .cosmic, .cybernetic, .fallout: return accent(for: mode).opacity(0.28)
            default: return nil
            }
        }()
        return ThemeTabBarStyle(
            backgroundTint: tabBarBackground(for: mode).opacity(mode == .badvice ? 0.78 : 0.66),
            materialOverlayOpacity: min(max(glassStrength, 0.12), 0.52),
            borderTop: accent(for: mode).opacity(0.18 + personality.effectIntensity * 0.08),
            borderBottom: .white.opacity(0.06 + personality.effectIntensity * 0.04),
            shadow: cardShadow(for: mode).color.opacity(0.28),
            shadowRadius: CGFloat(8 + personality.effectIntensity * 5),
            indicatorInset: personality.indicatorInset,
            selectedScale: CGFloat(1.02 + personality.effectIntensity * 0.015),
            glow: glow
        )
    }
}

struct ThemePersonality: Sendable {
    let descriptor: String
    let surfaceMood: String
    let bestFor: String
    let effectIntensity: Double
    let indicatorInset: CGFloat
}

struct ThemeTabBarStyle: Sendable {
    let backgroundTint: Color
    let materialOverlayOpacity: Double
    let borderTop: Color
    let borderBottom: Color
    let shadow: Color
    let shadowRadius: CGFloat
    let indicatorInset: CGFloat
    let selectedScale: CGFloat
    let glow: Color?
}
// Theme view helpers live in ThemeViews.swift.
