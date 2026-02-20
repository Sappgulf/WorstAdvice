import StoreKit
import SwiftData
import SwiftUI
import CoreMotion
import Combine

// RenderBudget and related view-performance helpers are defined in Theme.swift.

// MARK: - Tab Bar Visibility Environment

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

// MARK: - Scroll-Aware Tab Bar Helper

extension View {
    func trackScrollForTabBar() -> some View {
        self.modifier(ScrollTrackingModifier())
    }
}

private struct ScrollTrackingModifier: ViewModifier {
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var dragIntent: Bool?
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .local)
                    .onChanged { value in
                        let translationY = value.translation.height
                        let nextVisibility: Bool?
                        if translationY <= -18 {
                            nextVisibility = false
                        } else if translationY >= 14 {
                            nextVisibility = true
                        } else {
                            nextVisibility = nil
                        }

                        guard let nextVisibility else { return }
                        guard dragIntent != nextVisibility else { return }
                        dragIntent = nextVisibility

                        if accessibilityReduceMotion {
                            tabBarVisible.wrappedValue = nextVisibility
                        } else {
                            withAnimation(.easeInOut(duration: Theme.animMedium)) {
                                tabBarVisible.wrappedValue = nextVisibility
                            }
                        }
                    }
                    .onEnded { _ in
                        dragIntent = nil
                    }
            )
    }
}



struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .generate
    @State private var session: AppSessionViewModel?
    @State private var showConfetti = false
    @State private var showSplash = true
    @State private var tabBarVisible = true
    @State private var lastShakeHandledAt: Date = .distantPast
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @StateObject private var shakeDetector = ShakeDetector()
    // Tab bar slide gesture state
    @State private var tabBarWidth: CGFloat = 0
    @State private var tabDragHighlight: AppTab? = nil
    @State private var tabSlideModeActive = false
    @State private var tabSlideLastIndex: Int?
    @State private var tabSlideLastSwitchX: CGFloat = 0
    @State private var tabSlideLastHapticTab: AppTab?
    @State private var tabSlideLastSwitchAt: Date = .distantPast
    @State private var shouldRestartOnNextActive = false
    @State private var deviceCapability = DeviceCapabilityProfile.current()
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("favoritesCountAtLastReview") private var favoritesCountAtLastReview = 0
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true

    var body: some View {
        Group {
            if showSplash {
                SplashView(isShowing: $showSplash)
                    .transition(.opacity)
                    .task {
                        // Pre-warm session during splash so it's ready immediately after
                        if session == nil {
                            session = AppSessionViewModel(context: modelContext)
                        }
                    }
            } else if let session {
                let reduceMotion = session.settings.reduceMotion || accessibilityReduceMotion
                let constrainedMotion = reduceMotion || lowPowerModeEnabled || deviceCapability.prefersReducedEffects
                let effectiveLowPowerMode = lowPowerModeEnabled || deviceCapability.forceLowPowerVisuals
                let renderBudget = budget(for: session, lowPowerModeEnabled: effectiveLowPowerMode)
                let shouldRenderParticles = selectedTab == .generate || selectedTab == .chaosHub
                ZStack {
                    Theme.canvasColor(for: session.settings.theme)
                        .ignoresSafeArea()

                    ThemeBackgroundView(
                        mode: session.settings.theme,
                        budget: renderBudget,
                        lowPowerModeEnabled: effectiveLowPowerMode
                    )
                        .ignoresSafeArea()

                    if shouldRenderParticles {
                        FloatingParticlesView(
                            theme: session.settings.theme,
                            reduceMotion: reduceMotion,
                            isGenerating: session.generate.isGenerating,
                            budget: renderBudget,
                            lowPowerMode: effectiveLowPowerMode
                        )
                        .ignoresSafeArea()
                    }

                    TabView(selection: $selectedTab) {
                        ForEach(session.settings.tabOrder) { tab in
                            tabView(for: tab, session: session)
                                .tag(tab)
                                .toolbar(.hidden, for: .tabBar) // Hide standard bar
                                .environment(\.tabBarVisible, $tabBarVisible)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Extend only the bottom edge so the custom tab bar overlaps the home indicator
                    // region without pushing content under the Dynamic Island / status bar.
                    .ignoresSafeArea(.all, edges: .bottom)
                    // Performance: Disable animation if reduce motion is enabled
                    .animation(constrainedMotion ? nil : .easeInOut(duration: 0.3), value: selectedTab)
                    
                    // Custom Floating Tab Bar — supports tap and instant press-slide
                    GeometryReader { proxy in
                        VStack {
                            Spacer()
                            let tabs = session.settings.tabOrder
                            let tabBarStyle = Theme.tabBarStyle(for: session.settings.theme)
                            let accent = Theme.accent(for: session.settings.theme)
                            let secondaryText = Theme.secondaryText(for: session.settings.theme)
                            HStack(spacing: 0) {
                                ForEach(tabs) { tab in
                                    let isSelected = selectedTab == tab
                                    let isHighlighted = tabDragHighlight == tab
                                    VStack(spacing: 3) {
                                        Image(systemName: tab.systemImage)
                                            .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                                            .symbolVariant(isSelected ? .fill : .none)
                                            .scaleEffect(isHighlighted && !isSelected ? 1.12 : 1.0)
                                        Text(tab.title)
                                            .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                                        Capsule(style: .continuous)
                                            .fill(accent.opacity(isSelected ? 0.9 : 0))
                                            .frame(width: isSelected ? 18 : 8, height: 3)
                                            .opacity(isSelected ? 1 : 0.01)
                                    }
                                    .foregroundStyle(
                                        isSelected
                                            ? accent
                                            : (isHighlighted
                                                ? accent.opacity(0.58)
                                                : secondaryText.opacity(0.74))
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 6)
                                    .padding(.bottom, 4)
                                    .offset(y: isSelected ? -1.5 : 0)
                                    .scaleEffect(isSelected ? tabBarStyle.selectedScale : 1.0)
                                    .background {
                                        if isSelected || isHighlighted {
                                            Capsule(style: .continuous)
                                                .fill(accent.opacity(isSelected ? tabBarStyle.selectedFillOpacity : tabBarStyle.highlightedFillOpacity))
                                                .padding(.horizontal, max(4, tabBarStyle.indicatorInset + 3))
                                                .padding(.vertical, 1)
                                        }
                                    }
                                    .overlay {
                                        if isSelected, let glow = tabBarStyle.glow {
                                            Capsule(style: .continuous)
                                                .stroke(glow.opacity(0.35), lineWidth: 1)
                                                .padding(.horizontal, max(5, tabBarStyle.indicatorInset + 4))
                                                .padding(.vertical, 2)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .accessibilityAddTraits(.isButton)
                                    .onTapGesture {
                                        guard selectedTab != tab else { return }
                                        HapticsManager.playSelection(isEnabled: session.settings.hapticsEnabled)
                                        if constrainedMotion {
                                            selectedTab = tab
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedTab = tab
                                            }
                                        }
                                    }
                                    .accessibilityAction {
                                        if selectedTab != tab {
                                            HapticsManager.playSelection(isEnabled: session.settings.hapticsEnabled)
                                            if constrainedMotion {
                                                selectedTab = tab
                                            } else {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    selectedTab = tab
                                                }
                                            }
                                        }
                                    }
                                    .accessibilityLabel(tab.title)
                                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }
                            .contentShape(Rectangle())
                            .background(
                                GeometryReader { barGeo in
                                    Color.clear.onAppear {
                                        tabBarWidth = barGeo.size.width
                                    }
                                    .onChange(of: barGeo.size.width) { _, w in
                                        tabBarWidth = w
                                    }
                                }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { drag in
                                        let horizontalMovement = abs(drag.translation.width)
                                        let verticalMovement = abs(drag.translation.height)
                                        let shouldActivateSlide = horizontalMovement >= 6 || (horizontalMovement > verticalMovement && horizontalMovement >= 2)
                                        guard shouldActivateSlide else { return }
                                        if !tabSlideModeActive {
                                            beginTabSlide(tabs: tabs, hapticsEnabled: session.settings.hapticsEnabled)
                                        }
                                        updateTabSlide(
                                            locationX: drag.location.x,
                                            tabs: tabs,
                                            hapticsEnabled: session.settings.hapticsEnabled
                                        )
                                    }
                                    .onEnded { _ in
                                        endTabSlide(reduceMotion: constrainedMotion)
                                    }
                            )
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                            .background {
                                ZStack {
                                    if lowPowerModeEnabled {
                                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            .fill(tabBarStyle.backgroundTint.opacity(0.94))
                                            .shadow(color: tabBarStyle.shadow, radius: tabBarStyle.shadowRadius * 0.75, x: 0, y: 6)
                                    } else {
                                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                                    .fill(tabBarStyle.backgroundTint.opacity(tabBarStyle.materialOverlayOpacity))
                                            }
                                            .shadow(color: tabBarStyle.shadow, radius: tabBarStyle.shadowRadius, x: 0, y: 8)
                                    }

                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [tabBarStyle.borderTop, tabBarStyle.borderBottom, tabBarStyle.borderTop.opacity(0.55)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.8
                                        )

                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.22), .white.opacity(0.04), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .blendMode(.screen)

                                    if let glow = tabBarStyle.glow {
                                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            .stroke(glow.opacity(0.25), lineWidth: 1)
                                            .blur(radius: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, max(6, proxy.safeAreaInsets.bottom * 0.2))
                            .offset(y: tabBarVisible ? 0 : 120)
                            .animation(constrainedMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: tabBarVisible)
                        }
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .ignoresSafeArea(.keyboard)
                    
                    // Confetti overlay — fires on streak milestones
                    ConfettiView(isActive: $showConfetti, lowPowerMode: effectiveLowPowerMode)
                }
                .sensoryFeedback(trigger: session.generate.hapticTrigger) { _, _ in
                    let weight = session.generate.hapticWeight
                    if weight > 0.8 { return .impact(weight: .heavy) }
                    if weight > 0.4 { return .impact(weight: .medium) }
                    return .impact(weight: .light)
                }
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenOnboarding },
                    set: { if !$0 { hasSeenOnboarding = true } }
                )) {
                    OnboardingFlow(isPresented: .init(
                        get: { !hasSeenOnboarding },
                        set: { if !$0 { hasSeenOnboarding = true } }
                    ))
                }
                .onChange(of: session.generate.challengeStreakDays) { _, days in
                    if [3, 7, 14, 30].contains(days) {
                        showConfetti = true
                    }
                }
                .onChange(of: session.favorites.favorites.count) { _, newCount in
                    // Ask for review after the 3rd, 10th, and 25th favorite — once per threshold
                    let thresholds = [3, 10, 25]
                    if thresholds.contains(newCount) && newCount > favoritesCountAtLastReview {
                        favoritesCountAtLastReview = newCount
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            requestReview()
                        }
                    }
                }
                // MARK: - Shake to Generate
                .onChange(of: shakeDetector.didShake) { _, didShake in
                    guard didShake, shakeToGenerateEnabled, selectedTab == .generate else { return }
                    guard !session.generate.isGenerating else { return }
                    let now = Date()
                    guard now.timeIntervalSince(lastShakeHandledAt) > 0.9 else { return }
                    lastShakeHandledAt = now
                    HapticsManager.playShakeDetected(isEnabled: session.settings.hapticsEnabled)
                    Task {
                        await session.generate.generate()
                    }
                    session.refreshLists()
                }
                .onChange(of: shakeToGenerateEnabled) { _, enabled in
                    shakeDetector.isEnabled = enabled
                    if enabled, scenePhase == .active {
                        shakeDetector.startMonitoring()
                    } else {
                        shakeDetector.stopMonitoring()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        if shouldRestartOnNextActive {
                            shouldRestartOnNextActive = false
                            restartAppSession()
                            return
                        }
                        if shakeToGenerateEnabled {
                            shakeDetector.startMonitoring()
                        }
                        self.session?.generate.refreshRetentionStateOnAppear()
                    } else {
                        if phase == .background {
                            shouldRestartOnNextActive = true
                        }
                        shakeDetector.stopMonitoring()
                    }
                }
                .onAppear {
                    shakeDetector.isEnabled = shakeToGenerateEnabled
                    lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                    deviceCapability = DeviceCapabilityProfile.current()
                    if shakeToGenerateEnabled {
                        shakeDetector.startMonitoring()
                    }
                    session.generate.refreshRetentionStateOnAppear()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                    lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                    deviceCapability = DeviceCapabilityProfile.current()
                }
                .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                    deviceCapability = DeviceCapabilityProfile.current()
                }
                .onDisappear {
                    shakeDetector.stopMonitoring()
                }
                .onChange(of: session.settings.tabOrder) { _, newOrder in
                    // Keep TabView selection valid if tab ordering changes mid-session.
                    guard !newOrder.isEmpty else { return }
                    if !newOrder.contains(selectedTab), let fallback = newOrder.first {
                        selectedTab = fallback
                    }
                }
            } else {
                ZStack {
                    Color(hex: "F7F2E8").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color(hex: "8F4A22").opacity(0.7))
                        ProgressView()
                            .tint(Color(hex: "8F4A22"))
                        Text("Loading your chaos...")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color(hex: "8F4A22").opacity(0.6))
                    }
                }
                .task {
                    if session == nil {
                        session = AppSessionViewModel(context: modelContext)
                    }
                }
            }
        }
    }

    private func budget(for session: AppSessionViewModel, lowPowerModeEnabled: Bool) -> RenderBudget {
        let baseline: RenderBudget
        if lowPowerModeEnabled || session.settings.performanceMode {
            baseline = selectedTab == .generate && session.generate.isGenerating ? .balanced : .reduced
        } else {
            switch selectedTab {
            case .generate:
                baseline = session.generate.isGenerating ? .full : .balanced
            case .chaosHub:
                baseline = .balanced
            case .quotes, .favorites, .history, .settings:
                baseline = .reduced
            }
        }

        switch deviceCapability.thermalState {
        case .serious, .critical:
            return .reduced
        default:
            break
        }

        switch deviceCapability.tier {
        case .high:
            return baseline
        case .medium:
            return downgradedBudget(baseline, steps: 1)
        case .low:
            return downgradedBudget(baseline, steps: 2)
        }
    }

    private func downgradedBudget(_ budget: RenderBudget, steps: Int) -> RenderBudget {
        var result = budget
        for _ in 0..<max(steps, 0) {
            switch result {
            case .full:
                result = .balanced
            case .balanced:
                result = .reduced
            case .reduced:
                return .reduced
            }
        }
        return result
    }

    private func restartAppSession() {
        selectedTab = .generate
        tabBarVisible = true
        showConfetti = false
        lastShakeHandledAt = .distantPast
        tabDragHighlight = nil
        tabSlideModeActive = false
        tabSlideLastIndex = nil
        tabSlideLastSwitchX = 0
        tabSlideLastHapticTab = nil
        tabSlideLastSwitchAt = .distantPast
        session = AppSessionViewModel(context: modelContext)
    }

    @ViewBuilder
    private func tabView(for tab: AppTab, session: AppSessionViewModel) -> some View {
        switch tab {
        case .generate:
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                onDataChanged: { session.refreshLists() },
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                }
            )
        case .chaosHub:
            ChaosHubTabView(
                generateViewModel: session.generate,
                settings: session.settings,
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                },
                onDataChanged: {
                    session.refreshLists()
                }
            )
        case .quotes:
            QuotesTabView(
                viewModel: session.quotes,
                settings: session.settings,
                onJumpToGenerate: {
                    setSelectedTab(.generate, session: session)
                }
            )
        case .favorites:
            FavoritesTabView(
                viewModel: session.favorites,
                settings: session.settings,
                onJumpToGenerate: {
                    setSelectedTab(.generate, session: session)
                }
            )
        case .history:
            HistoryTabView(
                viewModel: session.history,
                settings: session.settings,
                onUseRecord: { (record: AdviceRecord) in
                    session.generate.current = record
                    setSelectedTab(.generate, session: session)
                },
                onDataChanged: { () -> Void in
                    session.refreshLists()
                },
                onJumpToGenerate: {
                    setSelectedTab(.generate, session: session)
                }
            )
        case .settings:
            SettingsTabView(
                viewModel: session.settings,
                generateViewModel: session.generate,
                quotesViewModel: session.quotes
            )
        }
    }

    private func beginTabSlide(tabs: [AppTab], hapticsEnabled: Bool) {
        guard !tabs.isEmpty else { return }
        guard !tabSlideModeActive else { return }
        tabSlideModeActive = true
        if !tabs.contains(selectedTab), let fallback = tabs.first {
            selectedTab = fallback
        }
        tabDragHighlight = selectedTab
        tabSlideLastIndex = tabs.firstIndex(of: selectedTab) ?? 0
        if tabBarWidth > 0 {
            let tabWidth = tabBarWidth / CGFloat(tabs.count)
            tabSlideLastSwitchX = (CGFloat(tabSlideLastIndex ?? 0) + 0.5) * tabWidth
        } else {
            tabSlideLastSwitchX = 0
        }
        tabSlideLastSwitchAt = Date()
        tabSlideLastHapticTab = selectedTab
        HapticsManager.playSelection(isEnabled: hapticsEnabled)
    }

    private func updateTabSlide(
        locationX: CGFloat,
        tabs: [AppTab],
        hapticsEnabled: Bool
    ) {
        guard tabSlideModeActive, !tabs.isEmpty else { return }
        guard locationX.isFinite, tabBarWidth.isFinite, tabBarWidth > 0 else { return }

        let tabWidth = tabBarWidth / CGFloat(tabs.count)
        guard tabWidth.isFinite, tabWidth > .ulpOfOne else { return }

        let clampedX = min(max(locationX, 0), max(tabBarWidth - 0.001, 0))
        guard clampedX.isFinite else { return }
        let indexValue = clampedX / tabWidth
        guard indexValue.isFinite else { return }

        let rawIndex = Int(indexValue.rounded(.down))
        let hoveredIndex = max(0, min(rawIndex, tabs.count - 1))
        guard tabs.indices.contains(hoveredIndex) else { return }
        let hoveredTab = tabs[hoveredIndex]

        if tabDragHighlight != hoveredTab {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                tabDragHighlight = hoveredTab
            }
        }

        guard let lastIndex = tabSlideLastIndex else {
            tabSlideLastIndex = hoveredIndex
            tabSlideLastSwitchX = clampedX
            return
        }

        guard hoveredIndex != lastIndex else { return }

        let now = Date()
        let canSwitch = now.timeIntervalSince(tabSlideLastSwitchAt) >= 0.03
        guard canSwitch else { return }

        if selectedTab != hoveredTab {
            // During active slide, switch immediately to avoid animation backlogs.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = hoveredTab
            }
        }

        tabSlideLastIndex = hoveredIndex
        tabSlideLastSwitchX = clampedX
        tabSlideLastSwitchAt = now
        if tabSlideLastHapticTab != hoveredTab {
            HapticsManager.playSelection(isEnabled: hapticsEnabled)
            tabSlideLastHapticTab = hoveredTab
        }
    }

    private func endTabSlide(reduceMotion: Bool) {
        if reduceMotion {
            tabDragHighlight = nil
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                tabDragHighlight = nil
            }
        }
        tabSlideModeActive = false
        tabSlideLastIndex = nil
        tabSlideLastHapticTab = nil
        tabSlideLastSwitchX = 0
        tabSlideLastSwitchAt = .distantPast
    }

    private func setSelectedTab(_ tab: AppTab, session: AppSessionViewModel) {
        let reduceMotion = session.settings.reduceMotion || accessibilityReduceMotion || lowPowerModeEnabled
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                AdviceRecord.self,
                AdviceFingerprint.self,
                UserAdviceSuggestion.self,
                UserQuoteSuggestion.self,
                QuoteVoteRecord.self,
                LearningStatRecord.self,
                AppSettingsEntity.self
            ],
            inMemory: true
        )
}
