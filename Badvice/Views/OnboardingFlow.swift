import SwiftUI

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    let onStarterSelected: (AdviceCategory, ToneMode, String, BadviceIntensity) -> Void
    @State private var category: AdviceCategory = .career

    init(isPresented: Binding<Bool>, onStarterSelected: @escaping (AdviceCategory, ToneMode, String, BadviceIntensity) -> Void = { _, _, _, _ in }) {
        _isPresented = isPresented
        self.onStarterSelected = onStarterSelected
    }

    var body: some View {
        ZStack {
            Theme.canvasColor(for: .badvice).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text("THE ANTI-ADVICE COLUMN")
                            .font(.caption.weight(.black)).tracking(1.3)
                            .foregroundStyle(Theme.accent(for: .badvice))
                        Spacer()
                        Button("Skip") { isPresented = false }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("onboarding.skip")
                    }
                    Text("Don't take\nour advice.")
                        .font(.system(.largeTitle, design: .serif, weight: .black))
                        .foregroundStyle(Theme.primaryText(for: .badvice))
                    Text("Take a laugh instead. Pick a topic, borrow a personality, and get a confidently wrong answer.")
                        .font(.title3).foregroundStyle(Theme.secondaryText(for: .badvice))
                    VStack(alignment: .leading, spacing: 16) {
                        Text("EXHIBIT A")
                            .font(.caption.weight(.black)).tracking(1.3).foregroundStyle(Theme.accent(for: .badvice))
                        Text("“Reply-all with your feelings. Transparency is a lifestyle brand.”")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(Theme.primaryText(for: .badvice))
                        Label("For entertainment. Absolutely not life guidance.", systemImage: "exclamationmark.bubble")
                            .font(.caption).foregroundStyle(Theme.secondaryText(for: .badvice))
                    }
                    .padding(24)
                    .background(Theme.cardColor(for: .badvice), in: RoundedRectangle(cornerRadius: 20))
                    Picker("Your first topic", selection: $category) {
                        ForEach(AdviceCategory.concrete) { Text($0.title).tag($0) }
                    }
                    .tint(Theme.accent(for: .badvice))
                    Button {
                        isPresented = false
                        onStarterSelected(category, .corporateConsultant, "", .bold)
                    } label: {
                        Label("Let's make it worse", systemImage: "arrow.right")
                            .font(.body.weight(.bold)).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(MagazineButtonStyle(theme: .badvice))
                    .accessibilityIdentifier("onboarding.start")
                    Text("Save the best takes. Share the worst. Play a round with friends.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText(for: .badvice))
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.light)
        .accessibilityIdentifier("onboarding.screen")
    }
}
