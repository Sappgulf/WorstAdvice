import CoreMotion
import StoreKit
import SwiftData
import SwiftUI

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

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    func body(content: Content) -> some View {
        if isUITesting {
            content
        } else {
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
}

enum LocalAuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            return "Sign In"
        case .signUp:
            return "Create Account"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .generate
    @State private var auth: AuthViewModel?
    @State private var session: AppSessionViewModel?
    @State private var showConfetti = false
    @State private var showSplash = true
    @State private var tabBarVisible = true
    @State private var authMode: LocalAuthMode = .signIn
    @State private var authEmailDraft = ""
    @State private var authPasswordDraft = ""
    @State private var authConfirmPasswordDraft = ""
    @State private var authDisplayNameDraft = ""
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
    @State private var hasScheduledDebugPolishFixturePreload = false
    @State private var loadedTabs: Set<AppTab> = [.generate]

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("favoritesCountAtLastReview") private var favoritesCountAtLastReview = 0
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true

    private var launchArguments: [String] { ProcessInfo.processInfo.arguments }
    private var isUITesting: Bool { launchArguments.contains("-ui-testing") }
    private var settingsTabAvailable: Bool { auth?.isAuthenticated == true && session != nil }

    var body: some View {
        appRootView
            .preferredColorScheme(.dark)
            .task {
                await bootstrapAppStateIfNeeded()
            }
    }

    @ViewBuilder
    private var appRootView: some View {
        if showSplash {
            SplashView(isShowing: $showSplash)
                .transition(.opacity)
        } else if let auth {
            if auth.isAuthenticated, let session {
                authenticatedSessionView(auth: auth, session: session)
            } else if auth.isAuthenticated {
                loadingView
            } else {
                authGateView(auth: auth)
            }
        } else {
            loadingView
        }
    }

    private func authenticatedSessionView(auth: AuthViewModel, session: AppSessionViewModel)
        -> some View
    {
        let reduceMotion =
            session.settings.reduceMotion
            || session.settings.performanceMode
            || accessibilityReduceMotion
        let constrainedMotion =
            reduceMotion || lowPowerModeEnabled || deviceCapability.prefersReducedEffects
        let effectiveLowPowerMode =
            lowPowerModeEnabled || deviceCapability.forceLowPowerVisuals
        let renderBudget = budget(for: session, lowPowerModeEnabled: effectiveLowPowerMode)
        let shouldRenderParticles =
            (selectedTab == .generate || selectedTab == .chaosHub) && !isUITesting

        return sessionMainContent(
            session: session,
            reduceMotion: reduceMotion,
            constrainedMotion: constrainedMotion,
            effectiveLowPowerMode: effectiveLowPowerMode,
            renderBudget: renderBudget,
            shouldRenderParticles: shouldRenderParticles
        )
        .sensoryFeedback(trigger: session.generate.hapticTrigger) { _, _ in
            let weight = session.generate.hapticWeight
            if weight > 0.8 { return .impact(weight: .heavy) }
            if weight > 0.4 { return .impact(weight: .medium) }
            return .impact(weight: .light)
        }
        .environment(\.font, Theme.bodyFont(for: session.settings.theme))
        .task(id: auth.currentSession?.accountID) {
            await syncAuthContext(auth: auth, social: session.social)
        }
        .fullScreenCover(
            isPresented: .init(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            )
        ) {
            OnboardingFlow(
                isPresented: .init(
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
            let thresholds = [3, 10, 25]
            if thresholds.contains(newCount) && newCount > favoritesCountAtLastReview {
                favoritesCountAtLastReview = newCount
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    requestReview()
                }
            }
        }
        .onChange(of: shakeDetector.didShake) { _, didShake in
            guard didShake, shakeToGenerateEnabled, selectedTab == .generate else { return }
            guard !session.generate.isGenerating else { return }
            let now = Date()
            guard now.timeIntervalSince(lastShakeHandledAt) > 0.9 else { return }
            lastShakeHandledAt = now
            HapticsManager.playShakeDetected(isEnabled: session.settings.hapticsEnabled)
            Task {
                await session.generate.generate()
                session.refreshLists()
            }
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
                // Only retry if not already loaded — prevents "Checking CloudKit" flash on every foreground
                switch self.session?.social.friendsLoadState {
                case .idle, .failed, .none:
                    Task { await self.session?.social.retryFriendsLoad() }
                default:
                    break
                }
            } else {
                if phase == .background {
                    shouldRestartOnNextActive = true
                }
                shakeDetector.stopMonitoring()
            }
        }
        .onAppear {
            applyUITestLaunchOverridesIfNeeded()
            shakeDetector.isEnabled = shakeToGenerateEnabled
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            deviceCapability = DeviceCapabilityProfile.current()
            if shakeToGenerateEnabled {
                shakeDetector.startMonitoring()
            }
            session.generate.refreshRetentionStateOnAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) {
            _ in
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            deviceCapability = DeviceCapabilityProfile.current()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
        ) { _ in
            deviceCapability = DeviceCapabilityProfile.current()
        }
        .onDisappear {
            shakeDetector.stopMonitoring()
        }
        .onChange(of: session.settings.tabOrder) { _, newOrder in
            guard !newOrder.isEmpty else { return }
            if !newOrder.contains(selectedTab), let fallback = newOrder.first {
                selectedTab = fallback
            }
        }
        .onChange(of: session.social.currentUser?.recordID.recordName) { _, newRecordName in
            auth.setLinkedSocialProfileRecordName(newRecordName)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .cloudKitSchemaSeederDidSeedDevelopmentSchema
            )
        ) { _ in
            Task {
                await session.social.retryFriendsLoad()
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(hex: "0F0D11").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color(hex: "E88D72").opacity(0.6))
                ProgressView()
                    .tint(Color(hex: "E88D72"))
                Text("Loading your chaos...")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(hex: "E88D72").opacity(0.5))
            }
        }
    }

    private func bootstrapAppStateIfNeeded() async {
        await Task.yield()
        if isUITesting, launchArguments.contains("-skip-splash") {
            showSplash = false
        }
        if auth == nil {
            let authViewModel = makeAuthViewModel()
            auth = authViewModel
            syncAuthDrafts(with: authViewModel)
        }

        applyUITestLaunchOverridesIfNeeded()

        guard let auth else { return }
        guard auth.isAuthenticated else { return }

        if session == nil {
            session = AppSessionViewModel(context: modelContext, accountID: auth.currentSession?.accountID)
            loadedTabs.insert(.chaosHub)
            loadedTabs.insert(.explore)
        }
    }

    private func makeAuthViewModel() -> AuthViewModel {
        let authViewModel = AuthViewModel()
        if isUITesting, launchArguments.contains("-ui-testing-auth-reset") {
            authViewModel.resetForUITesting()
        }
        if isUITesting, launchArguments.contains("-ui-testing-auth-skip") {
            authViewModel.seedUITestSessionIfNeeded()
        }
        authMode = authViewModel.hasAccounts ? .signIn : .signUp
        return authViewModel
    }

    private func syncAuthDrafts(with auth: AuthViewModel) {
        if let email = auth.signedInEmail {
            authEmailDraft = email
        } else if authEmailDraft.isEmpty, !auth.hasAccounts {
            authEmailDraft = ""
        }
        authPasswordDraft = ""
        authConfirmPasswordDraft = ""
        if authDisplayNameDraft.isEmpty {
            authDisplayNameDraft = auth.displayName
        }
    }

    private func resetSessionPresentationState() {
        selectedTab = .generate
        loadedTabs = [.generate]
        tabBarVisible = true
        showConfetti = false
        lastShakeHandledAt = .distantPast
        tabDragHighlight = nil
        tabSlideModeActive = false
        tabSlideLastIndex = nil
        tabSlideLastSwitchX = 0
        tabSlideLastHapticTab = nil
        tabSlideLastSwitchAt = .distantPast
    }

    private func beginAuthenticatedSession(using auth: AuthViewModel) {
        resetSessionPresentationState()
        syncAuthDrafts(with: auth)
        session = AppSessionViewModel(context: modelContext, accountID: auth.currentSession?.accountID)
        applyUITestLaunchOverridesIfNeeded()
    }

    private func signOutCurrentAccount(_ auth: AuthViewModel) {
        auth.signOut()
        session = nil
        resetSessionPresentationState()
        authMode = .signIn
        syncAuthDrafts(with: auth)
    }

    private func deleteCurrentAccount(_ auth: AuthViewModel, password: String) async {
        let didDelete = await auth.deleteCurrentAccount(password: password)
        guard didDelete else { return }
        session?.repository.purgeCurrentAccountData()
        session = nil
        resetSessionPresentationState()
        authMode = auth.hasAccounts ? .signIn : .signUp
        syncAuthDrafts(with: auth)
    }

    private func syncAuthContext(auth: AuthViewModel, social: SocialViewModel?) async {
        await social?.applyAuthContext(
            email: auth.signedInEmail,
            linkedSocialRecordName: auth.linkedSocialProfileRecordName
        )
    }

    @ViewBuilder
    private func authGateView(auth: AuthViewModel) -> some View {
        LocalAuthGateView(
            auth: auth,
            isUITesting: isUITesting,
            authMode: $authMode,
            authEmailDraft: $authEmailDraft,
            authPasswordDraft: $authPasswordDraft,
            authConfirmPasswordDraft: $authConfirmPasswordDraft,
            authDisplayNameDraft: $authDisplayNameDraft,
            onAuthenticated: {
                beginAuthenticatedSession(using: auth)
            }
        )
        .onAppear {
            syncAuthDrafts(with: auth)
        }
    }

    @ViewBuilder
    private func sessionMainContent(
        session: AppSessionViewModel,
        reduceMotion: Bool,
        constrainedMotion: Bool,
        effectiveLowPowerMode: Bool,
        renderBudget: RenderBudget,
        shouldRenderParticles: Bool
    ) -> some View {
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
                    lazyTabContent(for: tab, session: session)
                        .tag(tab)
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .toolbar(.hidden, for: .tabBar)  // Hide standard bar
                        .environment(\.tabBarVisible, $tabBarVisible)
                }
            }
            // Extend only the bottom edge so the custom tab bar overlaps the home indicator
            // region without pushing content under the Dynamic Island / status bar.
            .ignoresSafeArea(.all, edges: .bottom)
            // Performance: Disable animation if reduce motion is enabled
            .animation(
                constrainedMotion ? nil : .easeInOut(duration: 0.3), value: selectedTab)
            .onChange(of: selectedTab) { _, newTab in
                loadedTabs.insert(newTab)
            }

            // Custom Floating Tab Bar — supports tap and instant press-slide
            GeometryReader { proxy in
                VStack {
                    Spacer()
                    let tabs = primaryTabs(for: session)
                    let tabBarStyle = Theme.tabBarStyle(for: session.settings.theme)
                    let accent = Theme.accent(for: session.settings.theme)
                    let secondaryText = Theme.secondaryText(for: session.settings.theme)
                    let friendsBadgeCount = session.social.incomingRequests.count
                    let chaosBadgeCount = session.generate.dailyMissionState.isComplete ? 0 : 1
                    HStack(spacing: 0) {
                        ForEach(tabs) { tab in
                            let isSelected = selectedTab == tab
                            let isHighlighted = tabDragHighlight == tab
                            let badgeCount = tab == .friends ? friendsBadgeCount : (tab == .chaosHub ? chaosBadgeCount : 0)
                            let tabAccessibilityID = "tab.\(tab.rawValue)"
                            Button {
                                guard selectedTab != tab else { return }
                                HapticsManager.playSelection(
                                    isEnabled: session.settings.hapticsEnabled)
                                if constrainedMotion {
                                    selectedTab = tab
                                } else {
                                    withAnimation(
                                        .spring(response: 0.3, dampingFraction: 0.7)
                                    ) {
                                        selectedTab = tab
                                    }
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: tab.systemImage)
                                            .font(
                                                .system(
                                                    size: 20,
                                                    weight: isSelected ? .semibold : .medium)
                                            )
                                            .symbolVariant(isSelected ? .fill : .none)
                                            .scaleEffect(isHighlighted && !isSelected ? 1.12 : 1.0)
                                        if badgeCount > 0 {
                                            let badgeAccessibilityID = "tab.\(tab.rawValue).badge"
                                            Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Capsule(style: .continuous).fill(.red))
                                                .offset(x: 10, y: -7)
                                                .accessibilityIdentifier(badgeAccessibilityID)
                                        }
                                    }
                                    Text(tab.compactTitle)
                                        .font(
                                            .system(
                                                size: 9,
                                                weight: isSelected ? .semibold : .regular))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
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
                                .frame(minHeight: Theme.minimumTapTarget)
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                                .offset(y: isSelected ? -1.5 : 0)
                                .scaleEffect(isSelected ? tabBarStyle.selectedScale : 1.0)
                                .background {
                                    if isSelected || isHighlighted {
                                        Capsule(style: .continuous)
                                            .fill(
                                                accent.opacity(
                                                    isSelected
                                                        ? tabBarStyle.selectedFillOpacity
                                                        : tabBarStyle.highlightedFillOpacity)
                                            )
                                            .padding(
                                                .horizontal,
                                                max(4, tabBarStyle.indicatorInset + 3)
                                            )
                                            .padding(.vertical, 1)
                                    }
                                }
                                .overlay {
                                    if isSelected, let glow = tabBarStyle.glow {
                                        Capsule(style: .continuous)
                                            .stroke(glow.opacity(0.35), lineWidth: 1)
                                            .padding(
                                                .horizontal,
                                                max(5, tabBarStyle.indicatorInset + 4)
                                            )
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tab.title)
                            .accessibilityIdentifier(tabAccessibilityID)
                            .accessibilityValue(
                                "\(isSelected ? "Selected" : "Not selected")\(badgeCount > 0 ? ", \(badgeCount) pending requests" : "")"
                            )
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
                                let shouldActivateSlide =
                                    horizontalMovement >= 6
                                    || (horizontalMovement > verticalMovement
                                        && horizontalMovement >= 2)
                                guard shouldActivateSlide else { return }
                                if !tabSlideModeActive {
                                    beginTabSlide(
                                        tabs: tabs,
                                        hapticsEnabled: session.settings.hapticsEnabled)
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
                                    .shadow(
                                        color: tabBarStyle.shadow,
                                        radius: tabBarStyle.shadowRadius * 0.75, x: 0, y: 6)
                            } else {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(
                                            cornerRadius: 28, style: .continuous
                                        )
                                        .fill(
                                            tabBarStyle.backgroundTint.opacity(
                                                tabBarStyle.materialOverlayOpacity))
                                    }
                                    .shadow(
                                        color: tabBarStyle.shadow,
                                        radius: tabBarStyle.shadowRadius, x: 0, y: 8)
                            }

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            tabBarStyle.borderTop, tabBarStyle.borderBottom,
                                            tabBarStyle.borderTop.opacity(0.55),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.22), .white.opacity(0.04),
                                            .clear,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blendMode(.screen)

                            if let glow = tabBarStyle.glow, !constrainedMotion, !lowPowerModeEnabled {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(glow.opacity(0.25), lineWidth: 1)
                                    .blur(radius: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(6, proxy.safeAreaInsets.bottom * 0.2))
                    .offset(y: tabBarVisible ? 0 : 120)
                    .animation(
                        constrainedMotion
                            ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                        value: tabBarVisible)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)

            // Confetti overlay — fires on streak milestones
            ConfettiView(isActive: $showConfetti, lowPowerMode: effectiveLowPowerMode)
        }
    }

    private func budget(for session: AppSessionViewModel, lowPowerModeEnabled: Bool) -> RenderBudget
    {
        let baseline: RenderBudget
        if lowPowerModeEnabled || session.settings.performanceMode {
            baseline =
                selectedTab == .generate && session.generate.isGenerating ? .balanced : .reduced
        } else {
            switch selectedTab {
            case .generate:
                baseline = session.generate.isGenerating ? .full : .balanced
            case .chaosHub, .explore, .groupChallenges:
                baseline = .balanced
            case .friends, .quotes, .favorites, .history, .settings:
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
        resetSessionPresentationState()
        session = AppSessionViewModel(context: modelContext, accountID: auth?.currentSession?.accountID)
    }

    private func applyUITestLaunchOverridesIfNeeded() {
        if isUITesting, launchArguments.contains("-skip-onboarding") {
            hasSeenOnboarding = true
        }
        if isUITesting, launchArguments.contains("-skip-splash") {
            showSplash = false
        }
        if isUITesting {
            session?.settings.preferredGenerationProvider = .classic
            session?.settings.performanceMode = true
            session?.settings.reduceMotion = true
            session?.settings.hapticsEnabled = false
        }
        if !hasScheduledDebugPolishFixturePreload,
            launchArguments.contains("-debug-preload-polish-fixtures"),
            let session
        {
            hasScheduledDebugPolishFixturePreload = true
            let seed = intLaunchArgumentValue(after: "-debug-polish-seed") ?? 424_242
            Task {
                await session.preloadDebugPolishFixturesIfNeeded(seed: seed)
            }
        }
    }

    private func intLaunchArgumentValue(after flag: String) -> Int? {
        guard let flagIndex = launchArguments.firstIndex(of: flag) else { return nil }
        let valueIndex = launchArguments.index(after: flagIndex)
        guard valueIndex < launchArguments.endIndex else { return nil }
        return Int(launchArguments[valueIndex])
    }

    @ViewBuilder
    private func tabView(for tab: AppTab, session: AppSessionViewModel) -> some View {
        switch tab {
        case .generate:
            #if DEBUG
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                social: session.social,
                onDataChanged: { session.refreshLists() },
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                },
                quickAccessTabs: brandMenuTabs(for: session),
                onResetAllLocalAccounts: {
                    await resetAllLocalAccounts(using: auth, session: session)
                },
                onRefreshSocialAvailability: {
                    await refreshSocialAvailabilityToast(session: session)
                },
                onReseedCloudKitSchema: {
                    await reseedCloudKitSchemaToast(session: session)
                }
            )
            #else
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                social: session.social,
                onDataChanged: { session.refreshLists() },
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                },
                quickAccessTabs: brandMenuTabs(for: session),
                onResetAllLocalAccounts: {
                    await resetAllLocalAccounts(using: auth, session: session)
                },
                onRefreshSocialAvailability: {
                    await refreshSocialAvailabilityToast(session: session)
                }
            )
            #endif
        case .chaosHub:
            ChaosHubTabView(
                generateViewModel: session.generate,
                settings: session.settings,
                social: session.social,
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                },
                onDataChanged: {
                    session.refreshLists()
                }
            )
        case .friends:
            FriendsTabView(
                social: session.social,
                settings: session.settings,
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                }
            )
        case .quotes:
            QuotesTabView(
                viewModel: session.quotes,
                settings: session.settings,
                social: session.social,
                onJumpToGenerate: {
                    setSelectedTab(.generate, session: session)
                },
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
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
                generateViewModel: session.generate,
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
            if let auth, auth.isAuthenticated {
                SettingsTabView(
                    viewModel: session.settings,
                    generateViewModel: session.generate,
                    quotesViewModel: session.quotes,
                    social: session.social,
                    auth: auth,
                    achievementsManager: session.achievements,
                    onSignOut: {
                        signOutCurrentAccount(auth)
                    },
                    onDeleteAccount: { password in
                        await deleteCurrentAccount(auth, password: password)
                    }
                )
            } else {
                SettingsUnavailableView {
                    selectedTab = .generate
                }
            }
        case .explore:
            ExploreTabView(
                social: session.social,
                settings: session.settings,
                onJumpToGenerate: { category, tone in
                    session.generate.selectedCategory = category
                    session.generate.selectedTone = tone
                    setSelectedTab(.generate, session: session)
                }
            )
        case .groupChallenges:
            GroupChallengesTabView(
                social: session.social,
                generateViewModel: session.generate,
                settings: session.settings,
                onOpenTab: { tab in
                    setSelectedTab(tab, session: session)
                }
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
        guard tab != .settings || (auth?.isAuthenticated == true && self.session != nil) else {
            selectedTab = .generate
            return
        }
        loadedTabs.insert(tab)
        #if DEBUG
            NSLog("Selected tab -> %@", tab.rawValue)
        #endif
        let reduceMotion =
            session.settings.reduceMotion || accessibilityReduceMotion || lowPowerModeEnabled
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }
    }

    private func primaryTabs(for session: AppSessionViewModel) -> [AppTab] {
        let overflow = Set(brandMenuTabs(for: session))
        var tabs = AppTab.primaryNavigationTabs.filter { !overflow.contains($0) }
        if settingsTabAvailable, session.settings.tabOrder.contains(.settings), !tabs.contains(.settings) {
            tabs.append(.settings)
        }
        return tabs
    }

    private func brandMenuTabs(for session: AppSessionViewModel) -> [AppTab] {
        let availableTabs = Set(session.settings.tabOrder)
        return AppTab.brandMenuTabs.filter {
            availableTabs.contains($0) && ($0 != .settings || settingsTabAvailable)
        }
    }

    @ViewBuilder
    private func lazyTabContent(for tab: AppTab, session: AppSessionViewModel) -> some View {
        if loadedTabs.contains(tab) || selectedTab == tab {
            tabView(for: tab, session: session)
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }

    private func resetAllLocalAccounts(
        using auth: AuthViewModel?,
        session: AppSessionViewModel
    ) async -> ToastMessage {
        await session.social.applyAuthContext(email: nil, linkedSocialRecordName: nil)
        auth?.resetAllAccounts()
        session.repository.purgeAllLocalData()
        self.session = nil
        resetSessionPresentationState()
        authMode = .signUp
        if let auth {
            syncAuthDrafts(with: auth)
        } else {
            authEmailDraft = ""
            authPasswordDraft = ""
            authConfirmPasswordDraft = ""
            authDisplayNameDraft = ""
        }
        return ToastMessage(
            message: "All local Badvice accounts and on-device data were cleared.",
            style: .success
        )
    }

    private func refreshSocialAvailabilityToast(session: AppSessionViewModel) async -> ToastMessage {
        await session.social.retryFriendsLoad()
        if session.social.availability.isAccountAvailable {
            let message =
                session.social.needsProfileSetup
                    ? "CloudKit account is available. Finish your Friends profile to continue."
                    : "CloudKit account is available."
            return ToastMessage(message: message, style: .success)
        }
        return ToastMessage(message: session.social.availability.message, style: .error)
    }

    #if DEBUG
        private func reseedCloudKitSchemaToast(session: AppSessionViewModel) async -> ToastMessage {
            let status = await CloudKitSchemaSeeder.forceReseed()
            await session.social.retryFriendsLoad()
            return ToastMessage(
                message: status.toastMessage,
                style: status.isError ? .error : .success
            )
        }
    #endif
}

private struct SettingsUnavailableView: View {
    let onGoBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Settings is temporarily unavailable")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Return to Advice and sign in again to continue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Back to Advice", action: onGoBack)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
                MissionProgressRecord.self,
                AppSettingsEntity.self,
            ],
            inMemory: true
        )
}
