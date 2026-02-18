import SwiftUI

struct FloatingParticlesView: View {
    let theme: ThemeMode
    let reduceMotion: Bool
    var isGenerating: Bool = false
    var budget: RenderBudget = .balanced
    var lowPowerMode: Bool = false

    // Performance optimization: Cache particle count based on screen size
    private static var cachedScreenArea: CGFloat?
    private static var cachedParticleCount: Int?
    
    private var baseCount: Int {
        let screenArea = UIScreen.main.bounds.width * UIScreen.main.bounds.height
        
        // Use cached value if screen size hasn't changed
        if let cached = Self.cachedScreenArea, cached == screenArea,
           let cachedCount = Self.cachedParticleCount {
            return cachedCount
        }
        
        let raw = Int(screenArea / 25_000)
        let result = max(8, min(20, raw))
        
        // Cache for future use
        Self.cachedScreenArea = screenArea
        Self.cachedParticleCount = result
        
        return result
    }

    private var count: Int {
        let multiplier: Double
        if lowPowerMode {
            switch budget {
            case .full:
                multiplier = 0.55
            case .balanced:
                multiplier = 0.4
            case .reduced:
                multiplier = 0.28
            }
        } else {
            switch budget {
            case .full:
                multiplier = 1.0
            case .balanced:
                multiplier = 0.72
            case .reduced:
                multiplier = 0.45
            }
        }
        let minimum = isGenerating ? 6 : 4
        return max(minimum, Int(Double(baseCount) * multiplier))
    }

    private var particleOpacity: Double {
        switch theme {
        case .badvice: return 0.25
        case .minimal: return 0.08
        case .ember: return 0.15
        case .slate: return 0.12
        case .evergreen: return 0.14
        case .neon: return 0.3
        case .midnight: return 0.2
        case .sunset: return 0.18
        case .cosmic: return 0.35
        case .retro: return 0.25
        case .cybernetic: return 0.3
        }
    }
    
    private var generationParticleCount: Int {
        if lowPowerMode {
            return max(6, Int(Double(count) * 1.25))
        }
        switch budget {
        case .full:
            return count * 3
        case .balanced:
            return count * 2
        case .reduced:
            return max(8, count)
        }
    }

    private var idleInterval: TimeInterval {
        if lowPowerMode {
            return isGenerating ? 1.0 / 20.0 : 1.0 / 10.0
        }
        switch budget {
        case .full:
            return 1.0 / 30.0
        case .balanced:
            return 1.0 / 22.0
        case .reduced:
            return 1.0 / 12.0
        }
    }

    private var generationInterval: TimeInterval {
        if lowPowerMode {
            return 1.0 / 20.0
        }
        switch budget {
        case .full:
            return 1.0 / 60.0
        case .balanced:
            return 1.0 / 42.0
        case .reduced:
            return 1.0 / 24.0
        }
    }

    var body: some View {
        let activeInterval: TimeInterval = reduceMotion ? 5 : (isGenerating ? generationInterval : idleInterval)
        let shouldRasterize = budget != .reduced && !lowPowerMode
        
        TimelineView(.animation(minimumInterval: activeInterval, paused: reduceMotion && !isGenerating)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                drawParticles(context: context, size: size, date: timeline.date)
                if isGenerating {
                    drawChaosParticles(context: context, size: size, date: timeline.date)
                }
            }
        }
        .conditionalDrawingGroup(shouldRasterize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, date: Date) {
        let speedMultiplier: Double = isGenerating ? 2.5 : 1.0
        let t: Double = date.timeIntervalSinceReferenceDate * speedMultiplier
        let baseColor: Color = Theme.particleColor(for: theme)
        let baseOpacity: Double = isGenerating ? particleOpacity * 1.5 : particleOpacity
        let useDepthBlur = !lowPowerMode && budget == .full && !reduceMotion

        for index in 0..<count {
            let seed: Double = Double(index + 1)
            let modX: Double = seed.truncatingRemainder(dividingBy: 3)
            let modY: Double = seed.truncatingRemainder(dividingBy: 5)
            let modZ: Double = seed.truncatingRemainder(dividingBy: 7) // Depth seed

            let xNorm: Double = sin(t * 0.3 * modX + seed) * 0.5 + 0.5
            let yNorm: Double = cos(t * 0.2 * modY + seed * 1.3) * 0.5 + 0.5
            let depth: Double = sin(t * 0.1 * modZ + seed * 0.5) * 0.5 + 0.5 // 0.0 to 1.0 (far to near)

            let x: CGFloat = CGFloat(xNorm) * size.width
            let y: CGFloat = CGFloat(yNorm) * size.height

            let modR: Double = seed.truncatingRemainder(dividingBy: 4)
            let radius: CGFloat = CGFloat(1.5 + modR + (depth * 3.0)) // Closer particles are larger

            let alphaWave: Double = 0.5 + 0.5 * sin(t * 0.5 + seed * 2)
            let alpha: Double = baseOpacity * alphaWave * (0.3 + depth * 0.7) // Nearer are more opaque

            let color: Color = baseColor.opacity(alpha)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            
            if useDepthBlur {
                // Blur is visually rich but expensive; keep it only for full-budget rendering.
                let blurRadius: CGFloat = CGFloat((1.0 - depth) * 2.5)
                context.drawLayer { ctx in
                    ctx.addFilter(.blur(radius: blurRadius))
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
    
    private func drawChaosParticles(context: GraphicsContext, size: CGSize, date: Date) {
        let t: Double = date.timeIntervalSinceReferenceDate * 4.0
        let chaosColor: Color = Theme.accent(for: theme)
        
        for index in 0..<generationParticleCount {
            let seed: Double = Double(index + 1)
            let phase: Double = seed * 0.5
            
            // Chaotic spiral movement
            let angle: Double = t * 0.5 + phase * 2.0
            let radiusNorm: Double = 0.1 + 0.4 * abs(sin(t * 0.3 + phase))
            
            let centerX: CGFloat = size.width * 0.5
            let centerY: CGFloat = size.height * 0.5
            
            let x: CGFloat = centerX + CGFloat(radiusNorm * cos(angle) * size.width * 0.4)
            let y: CGFloat = centerY + CGFloat(radiusNorm * sin(angle) * size.height * 0.4)
            
            // Varying particle sizes with pulse
            let sizePulse: Double = 0.5 + 0.5 * sin(t * 2.0 + phase * 3.0)
            let radius: CGFloat = CGFloat(1.0 + 3.0 * sizePulse)
            
            // Fade in/out based on distance from center
            let distFromCenter: Double = sqrt(pow((x - centerX) / size.width * 2, 2) + pow((y - centerY) / size.height * 2, 2))
            let alpha: Double = max(0, 1.0 - distFromCenter) * 0.4 * sizePulse
            
            let color: Color = chaosColor.opacity(alpha)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            
            // Draw glow
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                with: .color(chaosColor.opacity(alpha * 0.3))
            )
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}
