import SwiftUI

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    let onStarterSelected: (AdviceCategory, ToneMode) -> Void

    @State private var currentPage = 0
    @State private var selectedCategory: AdviceCategory = .career
    @State private var selectedTone: ToneMode = .corporateConsultant
    @State private var showCompletionConfetti = false
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
        let accent: Color
        let background: LinearGradient
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: "Start in\nAdvice.",
            subtitle: "Pick a category, type a scenario, and get one polished bad idea at a time. Save, copy, or share the keepers.",
            accent: Color(hex: "8F4A22"),
            background: LinearGradient(colors: [Color(hex: "F7F2E8"), Color(hex: "F1E4D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "quote.bubble.fill",
            title: "Keep the\nbest ones.",
            subtitle: "History remembers every run. Favorites keeps the all-timers close so the best advice does not disappear after one tap.",
            accent: Color(hex: "7E4B7A"),
            background: LinearGradient(colors: [Color(hex: "F3EAF6"), Color(hex: "E6D7F0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "square.and.arrow.up",
            title: "Library makes it\ndaily.",
            subtitle: "Open Library for the daily line, rate it, and share it when something lands. That is the easiest return habit in the app.",
            accent: Color(hex: "2E6F64"),
            background: LinearGradient(colors: [Color(hex: "EAF6F3"), Color(hex: "D8EFE8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "flame.fill",
            title: "Missions track\nmomentum.",
            subtitle: "Daily mission, weekly push, season status, and the next recommended action all live in one progression surface.",
            accent: Color(hex: "B84A14"),
            background: LinearGradient(colors: [Color(hex: "FDF3EC"), Color(hex: "F7E0CC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "person.2.fill",
            title: "Social opens\nwhen you are ready.",
            subtitle: "Profile first, then your first friend, first share, and first collab. The tab now walks that sequence instead of dumping every feature up front.",
            accent: Color(hex: "2B5CA8"),
            background: LinearGradient(colors: [Color(hex: "EBF2FE"), Color(hex: "D6E6FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "map.fill",
            title: "One loop to\nremember.",
            subtitle: "Open Advice for something sharp, keep the best one, check Missions, then come back for the daily quote. That is the real Badvice rhythm.",
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

            ConfettiView(isActive: $showCompletionConfetti, lowPowerMode: isMotionReduced)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            FloatingParticlesView(
                theme: .minimal,
                reduceMotion: isMotionReduced,
                isGenerating: false,
                budget: .reduced,
                lowPowerMode: isMotionReduced
            )
                .opacity(0.4)
            
            CinematicVignetteView()
                .opacity(0.2)
                .blendMode(.multiply)

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(
                        icon: page.icon,
                        title: page.title,
                        subtitle: page.subtitle,
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
    }

    private var onboardingControlDock: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Step \(currentPage + 1) of \(pages.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pages[currentPage].accent.opacity(0.9))
                Spacer()
                Text(currentPage < pages.count - 1 ? "Swipe or tap Next" : "Start in Advice")
                    .font(.caption)
                    .foregroundStyle(pages[currentPage].accent.opacity(0.7))
            }

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(pages[currentPage].accent.opacity(i == currentPage ? 1 : 0.22))
                        .frame(width: i == currentPage ? 28 : 8, height: 8)
                        .animation(isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if currentPage == pages.count - 1 {
                starterChoicePanel
                    .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }

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
            }
            .buttonStyle(.plain)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    dismissOnboarding()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(pages[currentPage].accent.opacity(0.75))
                .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(pages[currentPage].accent.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: pages[currentPage].accent.opacity(0.14), radius: 12, y: 6)
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
        showCompletionConfetti = true
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

            Spacer().frame(height: 18)

            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(accent.opacity(0.6))
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.28), value: appeared)

            Spacer()
            Spacer()
        }
        .onAppear {
            appeared = true
        }
    }
}
