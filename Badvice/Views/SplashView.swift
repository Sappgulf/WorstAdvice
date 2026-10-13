import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.canvasColor(for: .badvice).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("badvice.")
                    .font(.system(.largeTitle, design: .serif, weight: .black))
                    .foregroundStyle(Theme.primaryText(for: .badvice))
                Text("GOOD INTENTIONS. TERRIBLE ADVICE.")
                    .font(.caption.weight(.black)).tracking(1.2)
                    .foregroundStyle(Theme.accent(for: .badvice))
                ProgressView().tint(Theme.accent(for: .badvice))
            }
            .opacity(appeared ? 1 : 0)
        }
        .accessibilityIdentifier("splash.screen")
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { appeared = true }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450)) }
            catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { isShowing = false }
        }
    }
}
