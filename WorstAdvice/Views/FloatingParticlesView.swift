import SwiftUI

struct FloatingParticlesView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    private let count = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 5 : 1.0 / 24.0)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<count {
                    let seed = Double(index + 1)
                    let x = (sin(t * (0.08 + seed * 0.001) + seed) * 0.4 + 0.5) * size.width
                    let y = (cos(t * (0.06 + seed * 0.0015) + seed * 1.7) * 0.35 + 0.5) * size.height
                    let radius = CGFloat(14 + (index % 5) * 6)
                    let rect = CGRect(x: x - Double(radius), y: y - Double(radius), width: Double(radius * 2), height: Double(radius * 2))
                    context.fill(Path(ellipseIn: rect), with: .color(particleColor.opacity(0.13)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var particleColor: Color {
        switch theme {
        case .warm: return Color(hex: "FFE7D1")
        case .dark: return Color(hex: "FFD1A9")
        case .neon: return Color(hex: "38F0FF")
        }
    }
}
