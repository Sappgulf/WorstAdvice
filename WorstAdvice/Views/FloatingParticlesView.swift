import SwiftUI

// MARK: - FloatingParticlesView

/// Lightweight ambient particles rendered in a Canvas.
/// Deterministic motion avoids recursive timers and reduces view churn.
struct FloatingParticlesView: View {

    let tier: AdviceTier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var particleCount: Int {
        switch tier {
        case .tier1: return 10
        case .tier2: return 16
        case .tier3: return 22
        case .tier4: return 30
        }
    }

    private var seeds: [ParticleSeed] {
        (0..<particleCount).map { ParticleSeed(index: $0, tier: tier) }
    }

    var body: some View {
        GeometryReader { _ in
            if reduceMotion {
                Canvas(rendersAsynchronously: true) { context, size in
                    drawParticles(
                        in: &context,
                        size: size,
                        time: 0,
                        animate: false
                    )
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    Canvas(rendersAsynchronously: true) { context, size in
                        drawParticles(
                            in: &context,
                            size: size,
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            animate: true
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        animate: Bool
    ) {
        guard size.width > 0, size.height > 0 else { return }

        for seed in seeds {
            let point = seed.position(at: time, in: size, animate: animate)
            let rect = CGRect(
                x: point.x - (seed.size / 2),
                y: point.y - (seed.size / 2),
                width: seed.size,
                height: seed.size
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Theme.tierAccent(tier).opacity(seed.opacity))
            )
        }
    }
}

// MARK: - ParticleSeed

private struct ParticleSeed {
    let originX: Double
    let originY: Double
    let amplitudeX: Double
    let amplitudeY: Double
    let speed: Double
    let phase: Double
    let size: CGFloat
    let opacity: Double

    init(index: Int, tier: AdviceTier) {
        let basis = Double(index + 1) * 12.9898 + Double(tier.rawValue) * 78.233

        func unit(_ offset: Double) -> Double {
            let raw = sin(basis + offset) * 43758.5453
            return raw - floor(raw)
        }

        originX = unit(0)
        originY = unit(1)
        amplitudeX = 0.05 + (unit(2) * 0.16)
        amplitudeY = 0.05 + (unit(3) * 0.16)
        speed = 0.10 + (unit(4) * 0.34)
        phase = unit(5) * .pi * 2
        size = CGFloat(1.8 + (unit(6) * 3.4))
        opacity = 0.10 + (unit(7) * 0.25)
    }

    func position(at time: TimeInterval, in size: CGSize, animate: Bool) -> CGPoint {
        guard animate else {
            return CGPoint(x: originX * size.width, y: originY * size.height)
        }

        let driftX = sin((time * speed) + phase) * amplitudeX
        let driftY = cos((time * speed * 0.82) + (phase * 1.3)) * amplitudeY

        let x = wrapped(originX + driftX) * size.width
        let y = wrapped(originY + driftY) * size.height
        return CGPoint(x: x, y: y)
    }

    private func wrapped(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 1)
        return mod >= 0 ? mod : mod + 1
    }
}
