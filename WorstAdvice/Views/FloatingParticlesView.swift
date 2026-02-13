import SwiftUI
import UIKit

struct FloatingParticlesView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    private var count: Int {
        let screenArea: CGFloat = UIScreen.main.bounds.width * UIScreen.main.bounds.height
        let raw: Int = Int(screenArea / 25_000)
        return max(8, min(20, raw))
    }

    private var particleOpacity: Double {
        switch theme {
        case .neon: return 0.25
        case .dark: return 0.15
        case .warm: return 0.13
        case .sepia: return 0.10
        case .evergreen: return 0.12
        case .sunrise: return 0.13
        }
    }

    var body: some View {
        let interval: TimeInterval = reduceMotion ? 5 : (1.0 / 24.0)
        TimelineView(.animation(minimumInterval: interval)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                drawParticles(context: context, size: size, date: timeline.date)
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, date: Date) {
        let t: Double = date.timeIntervalSinceReferenceDate
        let baseColor: Color = Theme.particleColor(for: theme)
        let baseOpacity: Double = particleOpacity

        for index in 0..<count {
            let seed: Double = Double(index + 1)
            let modX: Double = seed.truncatingRemainder(dividingBy: 3)
            let modY: Double = seed.truncatingRemainder(dividingBy: 5)

            let xNorm: Double = sin(t * 0.3 * modX + seed) * 0.5 + 0.5
            let yNorm: Double = cos(t * 0.2 * modY + seed * 1.3) * 0.5 + 0.5

            let x: CGFloat = CGFloat(xNorm) * size.width
            let y: CGFloat = CGFloat(yNorm) * size.height

            let modR: Double = seed.truncatingRemainder(dividingBy: 4)
            let radius: CGFloat = CGFloat(2.0 + modR)

            let alphaWave: Double = 0.5 + 0.5 * sin(t * 0.5 + seed * 2)
            let alpha: Double = baseOpacity * alphaWave

            let color: Color = baseColor.opacity(alpha)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}
