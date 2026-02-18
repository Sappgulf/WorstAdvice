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
        // Performance: Check cache first
        if let cached = gradientCache[mode] {
            return cached
        }
        
        let gradient: LinearGradient
        switch mode {
        case .badvice:
            gradient = LinearGradient(
                colors: [Color(hex: "1A111A"), Color(hex: "121212")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimal:
            gradient = LinearGradient(
                colors: [Color(hex: "F9F9F9"), Color(hex: "F2F2F7")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .ember:
            gradient = LinearGradient(
                colors: [Color(hex: "4A2626"), Color(hex: "2E1A1A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .slate:
            gradient = LinearGradient(
                colors: [Color(hex: "2C3E50"), Color(hex: "34495E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .evergreen:
            gradient = LinearGradient(
                colors: [Color(hex: "1A2F23"), Color(hex: "142119")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .fallout:
            gradient = LinearGradient(
                colors: [Color(hex: "081107"), Color(hex: "0D1B0A"), Color(hex: "12210D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neon:
            gradient = LinearGradient(
                colors: [Color(hex: "0A0A0A"), Color(hex: "1A0033")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .midnight:
            gradient = LinearGradient(
                colors: [Color(hex: "000000"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .sunset:
            gradient = LinearGradient(
                colors: [Color(hex: "FF512F"), Color(hex: "DD2476")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cosmic:
            gradient = LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .retro:
            gradient = LinearGradient(
                colors: [Color(hex: "2C1A3D"), Color(hex: "1A1A2E")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cybernetic:
            gradient = LinearGradient(
                colors: [Color(hex: "050B16"), Color(hex: "0A1F2E"), Color(hex: "0B3140")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Cache the result
        gradientCache[mode] = gradient
        return gradient
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

    static func accent(for mode: ThemeMode) -> Color {
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
        case .badvice: return Color(hex: "3D2C3E").opacity(0.65)
        case .minimal: return Color.white
        case .ember: return Color(hex: "5E3030").opacity(0.5)
        case .slate: return Color(hex: "3E5062").opacity(0.75)
        case .evergreen: return Color(hex: "253D2E").opacity(0.7)
        case .fallout: return Color(hex: "14220F").opacity(0.82)
        case .neon: return Color(hex: "1A1A2E").opacity(0.85)
        case .midnight: return Color(hex: "16213E").opacity(0.75)
        case .sunset: return Color(hex: "3D2847").opacity(0.6)
        case .cosmic: return Color(hex: "1A1A2E").opacity(0.7)
        case .retro: return Color(hex: "2D1B4E").opacity(0.75)
        case .cybernetic: return Color(hex: "0D121F").opacity(0.8)
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
                effectIntensity: 0.62,
                indicatorCornerRadius: 16,
                indicatorInset: 2
            )
        case .minimal:
            return ThemePersonality(
                descriptor: "Clean clarity, low visual noise",
                surfaceMood: "Studio Flat",
                effectIntensity: 0.12,
                indicatorCornerRadius: 10,
                indicatorInset: 3
            )
        case .ember:
            return ThemePersonality(
                descriptor: "Heat-haze depth with warm contrast",
                surfaceMood: "Molten Film",
                effectIntensity: 0.58,
                indicatorCornerRadius: 14,
                indicatorInset: 2
            )
        case .slate:
            return ThemePersonality(
                descriptor: "Cool executive glass and crisp edges",
                surfaceMood: "Steel Glass",
                effectIntensity: 0.4,
                indicatorCornerRadius: 12,
                indicatorInset: 2
            )
        case .evergreen:
            return ThemePersonality(
                descriptor: "Forest calm with textured atmosphere",
                surfaceMood: "Canopy Grain",
                effectIntensity: 0.55,
                indicatorCornerRadius: 15,
                indicatorInset: 2
            )
        case .fallout:
            return ThemePersonality(
                descriptor: "Vault terminal glow with rugged CRT depth",
                surfaceMood: "Pip-Boy Phosphor",
                effectIntensity: 0.7,
                indicatorCornerRadius: 10,
                indicatorInset: 2
            )
        case .neon:
            return ThemePersonality(
                descriptor: "Arcade glow and electric lane markers",
                surfaceMood: "Arcade Grid",
                effectIntensity: 0.9,
                indicatorCornerRadius: 8,
                indicatorInset: 1
            )
        case .midnight:
            return ThemePersonality(
                descriptor: "Deep-focus dark with cool bloom",
                surfaceMood: "Nocturne Film",
                effectIntensity: 0.68,
                indicatorCornerRadius: 18,
                indicatorInset: 2
            )
        case .sunset:
            return ThemePersonality(
                descriptor: "Golden-hour gradient with soft drama",
                surfaceMood: "Amber Bloom",
                effectIntensity: 0.64,
                indicatorCornerRadius: 20,
                indicatorInset: 3
            )
        case .cosmic:
            return ThemePersonality(
                descriptor: "Nebula depth and stellar sparkle",
                surfaceMood: "Starfield Mist",
                effectIntensity: 0.84,
                indicatorCornerRadius: 6,
                indicatorInset: 1
            )
        case .retro:
            return ThemePersonality(
                descriptor: "CRT attitude with scanline pulse",
                surfaceMood: "Synth Scan",
                effectIntensity: 0.78,
                indicatorCornerRadius: 4,
                indicatorInset: 1
            )
        case .cybernetic:
            return ThemePersonality(
                descriptor: "Metal-optimized glitch with neon precision",
                surfaceMood: "Liquid Wired",
                effectIntensity: 0.88,
                indicatorCornerRadius: 2,
                indicatorInset: 1
            )
        }
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

struct ThemeBackgroundView: View {
    let mode: ThemeMode
    var budget: RenderBudget = .balanced
    var lowPowerModeEnabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Performance: Only update when necessary
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
                        .drawingGroup(opaque: false) // Performance: Metal acceleration
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
                        .drawingGroup() // Performance: Rasterize complex texture
                }

                if allowsFullEffects && mode == .neon {
                    NeonGridView(budget: budget)
                        .opacity(0.15)
                        .blendMode(.screen)
                        .drawingGroup() // Performance: Cache grid rendering
                }

                if allowsFullEffects && mode == .cosmic {
                    StarFieldView(budget: budget)
                        .opacity(0.6)
                        .drawingGroup() // Performance: Cache star rendering
                }

                if allowsFullEffects && (mode == .retro || mode == .fallout) {
                    ScanlineView(budget: budget)
                        .opacity(mode == .fallout ? 0.16 : 0.1)
                        .blendMode(.overlay)
                        .drawingGroup() // Performance: Cache scanline rendering
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
            // Performance: Pause effects when backgrounded
            shouldRenderEffects = newPhase == .active
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
    let budget: RenderBudget
    
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
    
    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
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
            let step: CGFloat = 12 // Increased step for performance
            let dotOpacity: Double = 0.03
            
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let hash = (x * 374761 + y * 668265).truncatingRemainder(dividingBy: 100)
                    if hash < 20 { // Reduced density
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

// MARK: - Theme Transition Helper

struct ThemeTransition: ViewModifier {
    let theme: ThemeMode
    
    func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.35), value: theme)
    }
}

extension View {
    /// Apply smooth theme transitions to any view
    func themeTransition(_ theme: ThemeMode) -> some View {
        modifier(ThemeTransition(theme: theme))
    }

    /// Applies a drawing group only when the caller enables it.
    @ViewBuilder
    func conditionalDrawingGroup(_ enabled: Bool) -> some View {
        if enabled {
            drawingGroup()
        } else {
            self
        }
    }
}

// MARK: - Special Theme Effects

private struct NeonGridView: View {
    let budget: RenderBudget

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

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = sin(time * 1.35)
                let gridSize: CGFloat = 40
                let lineOpacity = 0.24 + 0.14 * phase
                
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
    }
}

private struct StarFieldView: View {
    let budget: RenderBudget
    @State private var start = Date()

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
    
    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
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
    
    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
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
            // High-precision grid lines
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
            
            // Atmospheric depth
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
                
                // Only glitch occasionally for impact
                if hash % 5 == 0 {
                    let glitchCount = budget == .full ? 10 : 5
                    for _ in 0..<glitchCount {
                        let w = CGFloat.random(in: 40...size.width * 0.6)
                        let h = CGFloat.random(in: 1...12)
                        let x = CGFloat.random(in: 0...size.width - w)
                        let y = CGFloat.random(in: 0...size.height - h)
                        
                        let rect = CGRect(x: x, y: y, width: w, height: h)
                        let color = [Color(hex: "00F3FF"), Color(hex: "FF00FF"), Color(hex: "7000FF")].randomElement()!
                        
                        context.fill(Path(rect), with: .color(color.opacity(0.35)))
                        
                        // Chromatic aberration / displacement lookalike
                        if Bool.random() {
                            context.fill(Path(rect.offsetBy(dx: 4, dy: 0)), with: .color(Color(hex: "FF00FF").opacity(0.2)))
                        }
                    }
                }
                
                // Subtle scanline pulse
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
