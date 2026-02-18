import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool
    var lowPowerMode: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    private var count: Int { lowPowerMode ? 40 : 72 }
    
    // Performance: Cache colors to avoid recreation
    private let confettiColors: [Color] = [
        Color(hex: "E85D3A"), Color(hex: "F5A623"),
        Color(hex: "4CAF50"), Color(hex: "3B9EE8"),
        Color(hex: "9C5FC2"), Color(hex: "F06292"),
        Color(hex: "FFD740"), Color(hex: "26C6DA")
    ]

    var body: some View {
        if isActive && scenePhase == .active {
            TimelineView(.animation(minimumInterval: lowPowerMode ? 1.0 / 28.0 : 1.0 / 60.0, paused: false)) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    for i in 0..<count {
                        let seed = Double(i + 1)
                        // Each particle has a phase offset so they don't all start together
                        let phaseOffset = seed * 0.14
                        let lifePhase = fmod(t * 1.1 + phaseOffset, 3.2)

                        // Burst from random points near center-top
                        let spawnX = size.width * (0.15 + Double(i % 7) * 0.12)
                        let spreadX = sin(seed * 1.7 + t * seed * 0.08) * 90 * lifePhase
                        let x = spawnX + spreadX

                        // Fall with easing
                        let y = -40 + lifePhase * size.height * 0.52 + lifePhase * lifePhase * 28

                        // Fade out near end of life
                        let fadeStart = 2.2
                        let alpha = lifePhase < fadeStart
                            ? min(1.0, lifePhase * 4)
                            : max(0, 1 - (lifePhase - fadeStart) / (3.2 - fadeStart))

                        guard alpha > 0 else { continue }

                        let color = confettiColors[i % confettiColors.count].opacity(alpha)
                        let particleSize = CGFloat(5 + (i % 5) * 2)
                        let rotation = Angle.degrees(t * (seed * 55) + seed * 30)

                        if i % 4 == 0 {
                            // Circle
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: particleSize, height: particleSize * 0.8)),
                                with: .color(color)
                            )
                        } else {
                            // Rotating rectangle
                            var transform = CGAffineTransform(translationX: x + particleSize / 2, y: y + particleSize / 4)
                            transform = transform.rotated(by: CGFloat(rotation.radians))
                            let rectPath = Path(CGRect(x: -particleSize / 2, y: -particleSize / 4, width: particleSize, height: particleSize / 2))
                            context.fill(rectPath.applying(transform), with: .color(color))
                        }
                    }
                }
            }
            .conditionalDrawingGroup(!lowPowerMode) // Metal acceleration
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .transition(.opacity.animation(.easeOut(duration: 0.3)))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        isActive = false
                    }
                }
            }
        }
    }
}
