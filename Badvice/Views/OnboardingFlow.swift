import SwiftUI

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    let onStarterSelected: (AdviceCategory, ToneMode) -> Void

    @State private var currentPage = 0
    @State private var selectedCategory: AdviceCategory = .career
    @State private var selectedTone: ToneMode = .corporateConsultant
    @State private var cinematicPulse = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    init(
        isPresented: Binding<Bool>,
        onStarterSelected: @escaping (AdviceCategory, ToneMode) -> Void = { _, _ in }
    ) {
        self._isPresented = isPresented
        self.onStarterSelected = onStarterSelected
    }

    private struct Page {
        let icon: String
        let title: String
        let subtitle: String
        let kicker: String
        let previewAdvice: String
        let accent: Color
        let background: LinearGradient
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: "Start in\nAdvice.",
            subtitle: "Pick a category, type a scenario, and get one polished bad idea at a time.",
            kicker: "Start fast. Improve as you go.",
            previewAdvice: "\"Need a way to ask for extra tasks without sounding needy?\"",
            accent: Color(hex: "8F4A22"),
            background: LinearGradient(colors: [Color(hex: "F7F2E8"), Color(hex: "F1E4D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "quote.bubble.fill",
            title: "Keep the\nbest ones.",
            subtitle: "History remembers every run. Favorites keeps the best ideas ready for the next moment.",
            kicker: "Save instantly, share later.",
            previewAdvice: "\"I’m all about clarity, so let me turn this into one sharp line.\"",
            accent: Color(hex: "7E4B7A"),
            background: LinearGradient(colors: [Color(hex: "F3EAF6"), Color(hex: "E6D7F0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "square.and.arrow.up",
            title: "Library makes it\ndaily.",
            subtitle: "Open Library for your daily line, ratings, and share-ready moments.",
            kicker: "One clean loop, no clutter.",
            previewAdvice: "\"No idea has to stay hidden once it’s helped two friends already.\"",
            accent: Color(hex: "2E6F64"),
            background: LinearGradient(colors: [Color(hex: "EAF6F3"), Color(hex: "D8EFE8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "flame.fill",
            title: "Missions track\nmomentum.",
            subtitle: "Missions show your daily challenge, weekly push, and momentum.",
            kicker: "Tiny habits, loud consistency.",
            previewAdvice: "\"Beat my own score today and turn that embarrassment into progress.\"",
            accent: Color(hex: "B84A14"),
            background: LinearGradient(colors: [Color(hex: "FDF3EC"), Color(hex: "F7E0CC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "person.2.fill",
            title: "Social opens\nwhen you are ready.",
            subtitle: "Profile first, then friend, first share, and first collab. No noise, only real connection.",
            kicker: "Social grows when advice is already flowing.",
            previewAdvice: "\"I’m not here to brag; I’m here to help our team sound cooler, faster.\"",
            accent: Color(hex: "2B5CA8"),
            background: LinearGradient(colors: [Color(hex: "EBF2FE"), Color(hex: "D6E6FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "map.fill",
            title: "One loop to\nremember.",
            subtitle: "Advice → Save → Missions → Quote. That is the rhythm, not a to-do.",
            kicker: "Three taps to keep moving.",
            previewAdvice: "\"Looping wins, even on chaotic Thursdays.\"",
            accent: Color(hex: "3C4E7A"),
            background: LinearGradient(colors: [Color(hex: "EAF0FB"), Color(hex: "DDE6F6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private let starterCategories: [AdviceCategory] = [
        .career, .social, .money, .productivity
    ]
    private let starterTones: [ToneMode] = [
        .corporateConsultant, .toxicBestFriend, .wizard, .influencer
    ]

    private var isMotionReduced: Bool {
        accessibilityReduceMotion
    }

    var body: some View {
        ZStack {
            pages[currentPage].background
                .ignoresSafeArea()
                .animation(isMotionReduced ? nil : .easeInOut(duration: 0.6), value: currentPage)

            FloatingParticlesView(
                theme: .minimal,
                reduceMotion: isMotionReduced,
                isGenerating: false,
                budget: .reduced,
                lowPowerMode: isMotionReduced
            )
                .opacity(0.32)

            CinematicVignetteView()
                .opacity(0.18)
                .blendMode(.multiply)

            LinearGradient(
                colors: [
                    pages[currentPage].accent.opacity(0.2),
                    .clear,
                    pages[currentPage].accent.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .allowsHitTesting(false)

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(
                        icon: page.icon,
                        title: page.title,
                        subtitle: page.subtitle,
                        kicker: page.kicker,
                        accent: page.accent,
                        reduceMotion: isMotionReduced
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, _ in
                HapticsManager.playSelection(isEnabled: true)
            }
        }
        .safeAreaInset(edge: .bottom) {
            onboardingControlDock
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .onAppear {
            if !isMotionReduced {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    cinematicPulse.toggle()
                }
            }
        }
    }

    private var onboardingControlDock: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Badvice loop")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(pages[currentPage].accent.opacity(0.72))
                Text("Step \(currentPage + 1) of \(pages.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentPage < pages.count - 1 ? "Swipe or tap Next" : "Start in Advice")
                    .font(.caption)
                    .foregroundStyle(pages[currentPage].accent.opacity(0.7))
            }

            HStack(spacing: 10) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(i == currentPage ? pages[currentPage].accent : pages[currentPage].accent.opacity(0.2))
                        .frame(width: i == currentPage ? 28 : 9, height: 8)
                        .animation(isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topLeading) {
                ProgressView(value: Double(currentPage + 1), total: Double(pages.count))
                    .progressViewStyle(.linear)
                    .tint(pages[currentPage].accent.opacity(0.9))
                    .scaleEffect(y: 0.55)
                    .opacity(0.85)
            }

            if currentPage == pages.count - 1 {
                starterChoicePanel
                    .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }

        previewCard(
            accent: pages[currentPage].accent,
            text: pages[currentPage].previewAdvice,
            isVisible: currentPage == 0 || currentPage == 2 || currentPage == pages.count - 1
        )

            Button {
                advanceOnboarding()
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                            .fill(pages[currentPage].accent)
                            .shadow(color: pages[currentPage].accent.opacity(0.3), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.next")
            .accessibilityLabel(currentPage < pages.count - 1 ? "Next" : "Get Started")
            .accessibilityHint(currentPage < pages.count - 1 ? "Advance onboarding" : "Open Badvice")

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    dismissOnboarding()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(pages[currentPage].accent.opacity(0.75))
                .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [pages[currentPage].accent.opacity(0.16), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: pages[currentPage].accent.opacity(0.16), radius: 12, y: 6)
        )
    }

    private var starterChoicePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Starter setup")
                .font(.caption.weight(.bold))
                .foregroundStyle(pages[currentPage].accent.opacity(0.9))
            chipRow(
                title: "Category",
                selectedTitle: selectedCategory.title,
                items: starterCategories.map { category in
                    StarterChoice(
                        id: category.rawValue,
                        title: category.title,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            )
            chipRow(
                title: "Tone",
                selectedTitle: selectedTone.title,
                items: starterTones.map { tone in
                    StarterChoice(
                        id: tone.rawValue,
                        title: tone.title,
                        icon: "dial.medium",
                        isSelected: selectedTone == tone
                    ) {
                        selectedTone = tone
                    }
                }
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(pages[currentPage].accent.opacity(0.08))
        )
    }

    private func chipRow(title: String, selectedTitle: String, items: [StarterChoice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(selectedTitle)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(pages[currentPage].accent.opacity(0.78))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button(action: item.action) {
                            Label(item.title, systemImage: item.icon)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .foregroundStyle(item.isSelected ? .white : pages[currentPage].accent)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(item.isSelected ? pages[currentPage].accent : pages[currentPage].accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.starter.\(item.id)")
                    }
                }
            }
        }
    }

    private func previewCard(accent: Color, text: String, isVisible: Bool) -> some View {
        Group {
            if isVisible {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent.opacity(0.8))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview move")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent.opacity(0.76))
                        Text(text)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accent.opacity(0.26), lineWidth: 1)
                        )
                )
                .scaleEffect(1.0 + (cinematicPulse ? 0.01 : 0.0))
                .animation(isMotionReduced ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: cinematicPulse)
                .shadow(color: accent.opacity(0.16), radius: 10, y: 6)
                .padding(.horizontal, 2)
            }
        }
    }

    private func advanceOnboarding() {
        if currentPage < pages.count - 1 {
            if isMotionReduced {
                currentPage += 1
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentPage += 1
                }
            }
            return
        }

        HapticsManager.playSuccess(isEnabled: true)
        onStarterSelected(selectedCategory, selectedTone)
        Task {
            try? await Task.sleep(for: .milliseconds(isMotionReduced ? 100 : 700))
            dismissOnboarding(playSelectionHaptic: false)
        }
    }

    private func dismissOnboarding(playSelectionHaptic: Bool = true) {
        if playSelectionHaptic {
            HapticsManager.playSelection(isEnabled: true)
        }
        if isMotionReduced {
            isPresented = false
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                isPresented = false
            }
        }
    }
}

private struct StarterChoice: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
}

private struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String
    let kicker: String
    let accent: Color
    var reduceMotion: Bool = false

    @State private var appeared = true
    @State private var floatAnim = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon bubble
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(floatAnim ? 1.05 : 0.95)

                Circle()
                    .fill(accent.opacity(0.07))
                    .frame(width: 110, height: 110)
                    .scaleEffect(floatAnim ? 0.9 : 1.1)

                if reduceMotion {
                    Image(systemName: icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(accent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolEffect(.bounce.up.byLayer, value: appeared)
                        .offset(y: floatAnim ? -5 : 5)
                }
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.68).delay(0.08), value: appeared)
            .animation(reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true), value: floatAnim)
            .onAppear {
                appeared = true
                floatAnim = !reduceMotion
            }

            Spacer().frame(height: 52)

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.headerColor(for: .minimal))
                .lineSpacing(2)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.18), value: appeared)

            Spacer().frame(height: 12)

            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(accent.opacity(0.6))
                .lineSpacing(4)
                .padding(.horizontal, 34)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.28), value: appeared)

            Text(kicker)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent.opacity(0.78))
                .textCase(.uppercase)
                .tracking(1.1)
                .padding(.top, 10)
                .opacity(0.9)
                .padding(.bottom, 20)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 0.9 : 0.0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.34), value: appeared)

            Spacer()
        }
        .onAppear {
            appeared = true
        }
    }
}
