import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.canvasColor(for: .badvice).ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Theme.copperFoilLight.opacity(0.22),
                        Theme.copperFoilMid.opacity(0.06),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.5, y: 0.46),
                    startRadius: 16,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.66
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.58))
                                .frame(width: 204, height: 204)
                                .shadow(
                                    color: Theme.copperFoilDeep.opacity(0.08),
                                    radius: 24,
                                    x: 0,
                                    y: 12
                                )

                            Circle()
                                .fill(Theme.copperFoilGradient)
                                .frame(width: 136, height: 136)
                                .opacity(0.16)
                                .blur(radius: 22)

                            Image("BadviceMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 126, height: 156)
                                .shadow(
                                    color: Theme.copperFoilDeep.opacity(0.16),
                                    radius: 8,
                                    x: 0,
                                    y: 5
                                )
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 8) {
                            Text("badvice.")
                                .font(.system(.largeTitle, design: .serif, weight: .black))
                                .tracking(-0.5)
                                .foregroundStyle(Theme.primaryText(for: .badvice))

                            Text("BAD IDEAS. GREAT DELIVERY.")
                                .font(.caption2.weight(.black))
                                .tracking(1.8)
                                .foregroundStyle(Theme.accent(for: .badvice))
                        }

                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.accent(for: .badvice))
                                .accessibilityHidden(true)

                            Text("Opening the case file")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText(for: .badvice))
                        }
                        .padding(.top, 10)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.97)

                    Spacer(minLength: 24)

                    Text("THE BADVICE BUREAU")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(Theme.copperFoilDeep.opacity(0.45))
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 28))
                }
                .padding(.horizontal, 28)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Badvice. Bad ideas. Great delivery. Opening the case file.")
        .accessibilityIdentifier("splash.screen")
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { appeared = true }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 650)) }
            catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { isShowing = false }
        }
    }
}
