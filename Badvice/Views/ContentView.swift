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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func trackScrollForTabBar() -> some View {
        self.modifier(ScrollTrackingModifier())
    }
}

private struct ScrollTrackingModifier: ViewModifier {
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var lastOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let delta = offset - lastOffset
                
                // Scrolling down (delta < 0) -> hide tab bar
                // Scrolling up (delta > 0) -> show tab bar
                // Only trigger if scroll delta is significant
                if abs(delta) > 5 {
                    let nextVisibility: Bool?
                    if delta < -10 {
                        nextVisibility = false
                    } else if delta > 10 {
                        nextVisibility = true
                    } else {
                        nextVisibility = nil
                    }

                    if let nextVisibility {
                        if accessibilityReduceMotion {
                            tabBarVisible.wrappedValue = nextVisibility
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                tabBarVisible.wrappedValue = nextVisibility
                            }
                        }
                    }
                    lastOffset = offset
                }
            }
    }
}

// MARK: - Shake Detector
class ShakeDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private var lastShakeTime: Date = Date.distantPast
    private let shakeCooldown: TimeInterval = 0.8
    
    @Published var didShake = false
    
    var isEnabled = true
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        stopMonitoring()
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, self.isEnabled, let data = data else { return }
            
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            // Threshold for shake detection (roughly 2.5x gravity)
            if acceleration > 2.5 {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                    self.lastShakeTime = now
                    self.didShake = true
                    
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.didShake = false
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
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
                let constrainedMotion = reduceMotion || lowPowerModeEnabled
                let renderBudget = budget(for: session, lowPowerModeEnabled: lowPowerModeEnabled)
                ZStack {
                    ThemeBackgroundView(
                        mode: session.settings.theme,
                        budget: renderBudget,
                        lowPowerModeEnabled: lowPowerModeEnabled
                    )
                        .ignoresSafeArea()

                    FloatingParticlesView(
                        theme: session.settings.theme,
                        reduceMotion: reduceMotion,
                        isGenerating: session.generate.isGenerating,
                        budget: renderBudget,
                        lowPowerMode: lowPowerModeEnabled
                    )
                    .ignoresSafeArea()

                    TabView(selection: $selectedTab) {
                        ForEach(session.settings.tabOrder) { tab in
                            tabView(for: tab, session: session)
                                .tag(tab)
                                .toolbar(.hidden, for: .tabBar) // Hide standard bar
                                .environment(\.tabBarVisible, $tabBarVisible)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Performance: Disable animation if reduce motion is enabled
                    .animation(constrainedMotion ? nil : .easeInOut(duration: 0.3), value: selectedTab)
                    
                    // Custom Floating Tab Bar — supports tap and hold-slide
                    GeometryReader { proxy in
                        VStack {
                            Spacer()
                            let tabs = session.settings.tabOrder
                            let tabBarStyle = Theme.tabBarStyle(for: session.settings.theme)
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
                                    }
                                    .foregroundStyle(
                                        isSelected
                                            ? Theme.accent(for: session.settings.theme)
                                            : (isHighlighted
                                                ? Theme.accent(for: session.settings.theme).opacity(0.58)
                                                : Theme.secondaryText(for: session.settings.theme).opacity(0.74))
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .scaleEffect(isSelected ? tabBarStyle.selectedScale : 1.0)
                                    .background {
                                        if isSelected || isHighlighted {
                                            RoundedRectangle(cornerRadius: tabBarStyle.indicatorCornerRadius, style: .continuous)
                                                .fill(
                                                    Theme.accent(for: session.settings.theme)
                                                        .opacity(isSelected ? tabBarStyle.selectedFillOpacity : tabBarStyle.highlightedFillOpacity)
                                                )
                                                .padding(.horizontal, tabBarStyle.indicatorInset)
                                                .padding(.vertical, 1)
                                        }
                                    }
                                    .overlay {
                                        if isSelected, let glow = tabBarStyle.glow {
                                            RoundedRectangle(cornerRadius: tabBarStyle.indicatorCornerRadius, style: .continuous)
                                                .stroke(glow.opacity(0.35), lineWidth: 1)
                                                .padding(.horizontal, tabBarStyle.indicatorInset + 1)
                                                .padding(.vertical, 2)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
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
                            .gesture(
                                constrainedMotion ? nil :
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { drag in
                                        if !tabSlideModeActive {
                                            beginTabSlide(tabs: tabs, hapticsEnabled: session.settings.hapticsEnabled)
                                        }
                                        updateTabSlide(
                                            locationX: drag.location.x,
                                            tabs: tabs,
                                            hapticsEnabled: session.settings.hapticsEnabled,
                                            reduceMotion: constrainedMotion
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

                                    if let glow = tabBarStyle.glow {
                                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            .stroke(glow.opacity(0.25), lineWidth: 1)
                                            .blur(radius: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, max(4, proxy.safeAreaInsets.bottom - 10))
                            .offset(y: tabBarVisible ? 0 : 120)
                            .animation(constrainedMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: tabBarVisible)
                        }
                    }
                    .ignoresSafeArea(.keyboard)

                    // Confetti overlay — fires on streak milestones
                    ConfettiView(isActive: $showConfetti, lowPowerMode: lowPowerModeEnabled)
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
                    session.generate.generate()
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
                    guard shakeToGenerateEnabled else {
                        shakeDetector.stopMonitoring()
                        return
                    }
                    if phase == .active {
                        shakeDetector.startMonitoring()
                    } else {
                        shakeDetector.stopMonitoring()
                    }
                }
                .onAppear {
                    shakeDetector.isEnabled = shakeToGenerateEnabled
                    lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                    if shakeToGenerateEnabled {
                        shakeDetector.startMonitoring()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                    lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
                .onDisappear {
                    shakeDetector.stopMonitoring()
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
        if lowPowerModeEnabled || session.settings.performanceMode {
            return selectedTab == .generate && session.generate.isGenerating ? .balanced : .reduced
        }
        switch selectedTab {
        case .generate:
            return session.generate.isGenerating ? .full : .balanced
        case .chaosHub, .quotes, .favorites, .history, .settings:
            return tabBarVisible ? .balanced : .reduced
        }
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
        tabDragHighlight = selectedTab
        tabSlideLastIndex = tabs.firstIndex(of: selectedTab) ?? 0
        if tabBarWidth > 0 {
            let tabWidth = tabBarWidth / CGFloat(tabs.count)
            tabSlideLastSwitchX = (CGFloat(tabSlideLastIndex ?? 0) + 0.5) * tabWidth
        } else {
            tabSlideLastSwitchX = 0
        }
        tabSlideLastHapticTab = selectedTab
        HapticsManager.playSelection(isEnabled: hapticsEnabled)
    }

    private func updateTabSlide(
        locationX: CGFloat,
        tabs: [AppTab],
        hapticsEnabled: Bool,
        reduceMotion: Bool
    ) {
        guard tabSlideModeActive, tabBarWidth > 0, !tabs.isEmpty else { return }
        let tabWidth = tabBarWidth / CGFloat(tabs.count)
        let clampedX = min(max(locationX, 0), max(tabBarWidth - 0.001, 0))
        let hoveredIndex = max(0, min(Int(clampedX / tabWidth), tabs.count - 1))
        let hoveredTab = tabs[hoveredIndex]

        if tabDragHighlight != hoveredTab {
            if reduceMotion {
                tabDragHighlight = hoveredTab
            } else {
                withAnimation(.easeOut(duration: 0.08)) {
                    tabDragHighlight = hoveredTab
                }
            }
        }

        guard let lastIndex = tabSlideLastIndex else {
            tabSlideLastIndex = hoveredIndex
            tabSlideLastSwitchX = clampedX
            return
        }

        guard hoveredIndex != lastIndex else { return }
        let minimumTravel = max(14, tabWidth * 0.32)
        guard abs(clampedX - tabSlideLastSwitchX) >= minimumTravel else { return }

        if selectedTab != hoveredTab {
            if reduceMotion {
                selectedTab = hoveredTab
            } else {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    selectedTab = hoveredTab
                }
            }
        }

        tabSlideLastIndex = hoveredIndex
        tabSlideLastSwitchX = clampedX
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
