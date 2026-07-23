import CoreMotion
import StoreKit
import OSLog
import SwiftData
import SwiftUI

// RenderBudget lives in Theme.swift; reusable theme views and helpers live in ThemeViews.swift.

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
//
// Previously this hid/showed the tab bar in response to scroll direction,
// using either a DragGesture (which risked eating taps on buttons inside
// the same ScrollView) or scroll-offset tracking (which shifted the
// ScrollView's own bottom safe-area padding mid-scroll, producing visible
// content jumps). Neither was worth the instability — the tab bar now
// simply stays put, which is also simpler and more predictable to use.
extension View {
    func trackScrollForTabBar() -> some View {
        self
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
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "ui-tests")
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .generate
    @State private var auth: AuthViewModel?
    @State private var session: AppSessionViewModel?
    @State private var pendingDeepLinks: [URL] = []
    @State private var showConfetti = false
    @State private var showSplash = true
    @State private var hasResetUITestData = false
    @State private var tabBarVisible = true
    @State private var authMode: LocalAuthMode = .signIn
    @State private var authEmailDraft = ""
    @State private var authPasswordDraft = ""
    @State private var authConfirmPasswordDraft = ""
    @State private var authDisplayNameDraft = ""
    @State private var showingSettingsRoot = false
    @State private var showingShellMenu = false
    @State private var pendingShellMenuTab: AppTab? = nil
    @State private var shellToast: ToastMessage? = nil
    @State private var appLoadingMessageTick = 0
    @State private var appLoadingMessageTask: Task<Void, Never>?
    @State private var lastShakeHandledAt: Date = .distantPast
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @StateObject private var shakeDetector = ShakeDetector()
    @State private var shouldRestartOnNextActive = false
    @State private var deviceCapability = DeviceCapabilityProfile.current()
    @State private var hasScheduledDebugPolishFixturePreload = false
    @State private var loadedTabs: Set<AppTab> = [.generate]

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("favoritesCountAtLastReview") private var favoritesCountAtLastReview = 0
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true

    private var launchArguments: [String] { ProcessInfo.processInfo.arguments }
    private var isUITesting: Bool { launchArguments.contains("-ui-testing") }
    private var isScreenshotMode: Bool { isUITesting && launchArguments.contains("-screenshot-mode") }
    private var shouldPreloadDebugPolishFixtures: Bool {
        isUITesting && (isScreenshotMode || launchArguments.contains("-debug-preload-polish-fixtures"))
    }
    private var isHostedUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    private var settingsTabAvailable: Bool { auth?.isAuthenticated == true && session != nil }
    private var shouldAutoGenerateAdviceOnOpen: Bool {
        !isUITesting && !shouldPreloadDebugPolishFixtures
    }

    var body: some View {
        appRootView
            .task {
                startBootstrapLoadingMessageRotation()
                await bootstrapAppStateIfNeeded()
                stopBootstrapLoadingMessageRotation()
            }
            .onOpenURL { url in
                if let session {
                    Task { await routeIncomingDeepLink(url, session: session) }
                } else {
                    queueUnsupportedDeepLink(url)
                }
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
            auth: auth,
            session: session,
            reduceMotion: reduceMotion,
            constrainedMotion: constrainedMotion,
            effectiveLowPowerMode: effectiveLowPowerMode,
            renderBudget: renderBudget,
            shouldRenderParticles: shouldRenderParticles
        )
        .preferredColorScheme(Theme.colorScheme(for: session.settings.theme))
        .sensoryFeedback(trigger: session.generate.hapticTrigger) { _, _ in
            let weight = session.generate.hapticWeight
            if weight > 0.8 { return .impact(weight: .heavy) }
            if weight > 0.4 { return .impact(weight: .medium) }
            return .impact(weight: .light)
        }
        .environment(\.font, Theme.bodyFont(for: session.settings.theme))
        .task(id: auth.currentSession?.accountID) {
            await syncAuthContext(auth: auth, social: session.social)
            await handlePendingAppIntent(for: session)
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
                ),
                onStarterSelected: { category, tone in
                    session.generate.updateSelections(
                        category: category,
                        tone: tone,
                        autoGenerate: true
                    )
                    setSelectedTab(.generate, session: session)
                }
            )
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
            ThemeBackgroundView(
                mode: .badvice,
                budget: .reduced,
                lowPowerModeEnabled: lowPowerModeEnabled
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.12), .clear, Color.black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blendMode(.multiply)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "E88D72").opacity(0.24))
                        .frame(width: 96, height: 96)
                        .blur(radius: 14)

                    Circle()
                        .stroke(Color(hex: "E88D72").opacity(0.35), lineWidth: 1)
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color(hex: "E88D72").opacity(0.88))
                }

                Text("Badvice startup")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "E88D72").opacity(0.78))

                Text(GenerationLoadingMessages.phaseTitle(forTick: appLoadingMessageTick))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "E88D72").opacity(0.82))
                    .multilineTextAlignment(.center)

                Text(GenerationLoadingMessages.message(forTick: appLoadingMessageTick))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(hex: "F1D7C2").opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)

                ProgressView(value: min(Double((appLoadingMessageTick % 40) + 1) / 40.0, 1.0))
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "E88D72"))
                    .frame(width: 170)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .stroke(Color(hex: "E88D72").opacity(0.18), lineWidth: 0.9)
                    )
            )
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
            let newSession = AppSessionViewModel(
                context: modelContext,
                accountID: auth.currentSession?.accountID
            )
            session = newSession
            loadedTabs.insert(.chaosHub)
            loadedTabs.insert(.explore)
            applyUITestLaunchOverridesIfNeeded(sessionOverride: newSession)
            newSession.bootstrapExperienceIfNeeded(
                autoGenerateInitialAdvice: shouldAutoGenerateAdviceOnOpen
            )
            if shouldPreloadDebugPolishFixtures {
                let seed = intLaunchArgumentValue(after: "-debug-polish-seed") ?? 424_242
                Self.logger.info("Awaiting debug polish preload")
                await newSession.preloadDebugPolishFixturesIfNeeded(seed: seed)
            }
            applyScreenshotStartTabIfNeeded(session: newSession)
        }
    }

    private func startBootstrapLoadingMessageRotation() {
        appLoadingMessageTask?.cancel()
        appLoadingMessageTick = 0
        appLoadingMessageTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                await MainActor.run {
                    appLoadingMessageTick += 1
                }
            }
        }
    }

    private func stopBootstrapLoadingMessageRotation() {
        appLoadingMessageTask?.cancel()
        appLoadingMessageTask = nil
    }

    private func makeAuthViewModel() -> AuthViewModel {
        let authStore: LocalAccountStore
        if isUITesting {
            authStore = LocalAccountStore(credentialsStore: LocalAccountInMemoryStore())
        } else {
            authStore = LocalAccountStore()
        }
        let authViewModel = AuthViewModel(store: authStore)
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
        showingSettingsRoot = false
        showingShellMenu = false
        shellToast = nil
        tabBarVisible = true
        showConfetti = false
        lastShakeHandledAt = .distantPast
    }

    private func beginAuthenticatedSession(using auth: AuthViewModel) {
        resetSessionPresentationState()
        syncAuthDrafts(with: auth)
        let newSession = AppSessionViewModel(
            context: modelContext,
            accountID: auth.currentSession?.accountID
        )
        session = newSession
        applyUITestLaunchOverridesIfNeeded(sessionOverride: newSession)
        newSession.bootstrapExperienceIfNeeded(
            autoGenerateInitialAdvice: shouldAutoGenerateAdviceOnOpen
        )
        if shouldPreloadDebugPolishFixtures {
            let seed = intLaunchArgumentValue(after: "-debug-polish-seed") ?? 424_242
            Task {
                await newSession.preloadDebugPolishFixturesIfNeeded(seed: seed)
                await MainActor.run {
                    applyScreenshotStartTabIfNeeded(session: newSession)
                }
            }
        } else {
            applyScreenshotStartTabIfNeeded(session: newSession)
        }
    }

    private func signOutCurrentAccount(_ auth: AuthViewModel) {
        auth.signOut()
        resetSessionPresentationState()
        session = nil
        authMode = auth.hasAccounts ? .signIn : .signUp
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
    private func settingsSheetContent(
        auth: AuthViewModel,
        session: AppSessionViewModel
    ) -> some View {
        if auth.isAuthenticated {
            NavigationStack {
                SettingsTabView(
                    viewModel: session.settings,
                    generateViewModel: session.generate,
                    quotesViewModel: session.quotes,
                    social: session.social,
                    auth: auth,
                    achievementsManager: session.achievements,
                    onSignOut: { signOutCurrentAccount(auth) },
                    onDeleteAccount: { password in
                        await deleteCurrentAccount(auth, password: password)
                    }
                )
            }
        } else {
            SettingsUnavailableView {
                selectedTab = .generate
            }
        }
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
        auth: AuthViewModel,
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

            if showingSettingsRoot {
                settingsSheetContent(auth: auth, session: session)
                    .environment(\.tabBarVisible, $tabBarVisible)
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(shellTabs(for: session)) { tab in
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
            }

            FloatingTabBarView(
                selectedTab: $selectedTab,
                showingSettingsRoot: $showingSettingsRoot,
                showingShellMenu: $showingShellMenu,
                tabBarVisible: $tabBarVisible,
                tabs: primaryTabs(for: session),
                overflowTabs: brandMenuTabs(),
                theme: session.settings.theme,
                hapticsEnabled: session.settings.hapticsEnabled,
                reduceMotion: constrainedMotion,
                lowPowerModeEnabled: effectiveLowPowerMode,
                onPrimaryTabSelected: { tab in
                    setSelectedTab(tab, session: session)
                },
                onSettingsSelected: {
                    setSelectedTab(.settings, session: session)
                }
            )

            // Confetti overlay — fires on streak milestones
            ConfettiView(isActive: $showConfetti, lowPowerMode: effectiveLowPowerMode)
        }
        .sheet(isPresented: $showingShellMenu, onDismiss: {
            handleShellMenuDismiss(session: session)
        }) {
            GenerateBrandMenuView(
                social: session.social,
                settings: session.settings,
                quickAccessTabs: brandMenuTabs(),
                isPresented: $showingShellMenu,
                activeToast: $shellToast,
                onSelectQuickAccessTab: { tab in
                    pendingShellMenuTab = tab
                },
                onResetAllLocalAccounts: {
                    await resetAllLocalAccounts(using: auth, session: session)
                }
            )
        }
        .toast(item: $shellToast, accentColor: Theme.accent(for: session.settings.theme))
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
        resetSessionPresentationState()
        let newSession = AppSessionViewModel(
            context: modelContext,
            accountID: auth?.currentSession?.accountID
        )
        session = newSession
        newSession.bootstrapExperienceIfNeeded(
            autoGenerateInitialAdvice: shouldAutoGenerateAdviceOnOpen
        )
    }

    private func applyUITestLaunchOverridesIfNeeded(sessionOverride: AppSessionViewModel? = nil) {
        let activeSession = sessionOverride ?? session
        if ProcessInfo.processInfo.environment["reset_onboarding"] == "true" {
            hasSeenOnboarding = false
        }
        if isUITesting, launchArguments.contains("-ui-testing-reset-data"), !hasResetUITestData {
            activeSession?.repository.purgeCurrentAccountData()
            for tab in AppTab.allCases {
                UserDefaults.standard.removeObject(forKey: tab.focusModeStorageKey)
            }
            hasResetUITestData = true
        }
        if isUITesting, launchArguments.contains("-skip-onboarding") || isScreenshotMode {
            hasSeenOnboarding = true
        }
        if isUITesting, launchArguments.contains("-skip-splash") || isScreenshotMode {
            showSplash = false
        }
        if isUITesting {
            activeSession?.settings.preferredGenerationProvider = .classic
            activeSession?.settings.performanceMode = true
            activeSession?.settings.reduceMotion = true
            activeSession?.settings.hapticsEnabled = false
        }
    }

    private func intLaunchArgumentValue(after flag: String) -> Int? {
        guard let flagIndex = launchArguments.firstIndex(of: flag) else { return nil }
        let valueIndex = launchArguments.index(after: flagIndex)
        guard valueIndex < launchArguments.endIndex else { return nil }
        return Int(launchArguments[valueIndex])
    }

    private func stringLaunchArgumentValue(after flag: String) -> String? {
        guard let flagIndex = launchArguments.firstIndex(of: flag) else { return nil }
        let valueIndex = launchArguments.index(after: flagIndex)
        guard valueIndex < launchArguments.endIndex else { return nil }
        return launchArguments[valueIndex]
    }

    private func applyScreenshotStartTabIfNeeded(session: AppSessionViewModel) {
        guard isScreenshotMode,
              let rawTab = stringLaunchArgumentValue(after: "-screenshot-start-tab"),
              let tab = AppTab(rawValue: rawTab)
        else { return }

        if tab == .settings {
            showingSettingsRoot = true
            tabBarVisible = true
            return
        }

        showingSettingsRoot = false
        loadedTabs.insert(tab)
        selectedTab = tab
        tabBarVisible = true
        session.settings.reduceMotion = true
    }

    private func routeIncomingDeepLink(_ url: URL, session: AppSessionViewModel) async {
        guard url.scheme?.lowercased() == "badvice" else {
            Self.logger.info("Ignoring non-Badvice deep link: \(url.absoluteString, privacy: .public)")
            return
        }

        let host = url.host?.lowercased()
        let pathParts = url.pathComponents
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() }
            .filter { !$0.isEmpty }
        let component = host ?? pathParts.first
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let categoryParam = query.first(where: { $0.name == "category" })?.value
        let toneParam = query.first(where: { $0.name == "tone" })?.value
        let friendParam = query.first(where: { $0.name == "friend" })?.value
            ?? query.first(where: { $0.name == "friendName" })?.value
        let scenarioParam = query.first(where: { $0.name == "scenario" })?.value
            ?? query.first(where: { $0.name == "situation" })?.value
        let shouldGenerate = Bool(query.first(where: { $0.name == "generate" })?.value ?? "true") ?? true
        let normalizedShouldGenerate = shouldGenerate

        if let requestedTab = component.flatMap({ AppTab(rawValue: $0) }) {
            openShellMenuTab(requestedTab, session: session)
            guard requestedTab == .generate else { return }
            applyGenerateIntent(
                tab: requestedTab,
                categoryRaw: categoryParam,
                toneRaw: toneParam,
                friendName: friendParam,
                scenario: scenarioParam,
                shouldGenerate: normalizedShouldGenerate,
                session: session
            )
            return
        }

        if host == "advice" || pathParts.first == "advice" {
            setSelectedTab(.generate, session: session)
            applyGenerateIntent(
                tab: .generate,
                categoryRaw: categoryParam,
                toneRaw: toneParam,
                friendName: friendParam,
                scenario: scenarioParam,
                shouldGenerate: normalizedShouldGenerate,
                session: session
            )
            return
        }

        if host == "chaoshub" || host == "chaos-hub" || pathParts.contains("chaoshub") {
            setSelectedTab(.chaosHub, session: session)
            return
        }

        if host == "quotes" || pathParts.contains("quotes") {
            setSelectedTab(.quotes, session: session)
            return
        }

        if host == "favorites" || pathParts.contains("favorites") {
            setSelectedTab(.favorites, session: session)
            return
        }

        if host == "history" || pathParts.contains("history") {
            setSelectedTab(.history, session: session)
            return
        }

        if host == "explore" || pathParts.contains("explore") {
            setSelectedTab(.explore, session: session)
            return
        }

        if host == "settings" || pathParts.contains("settings") {
            openShellMenuTab(.settings, session: session)
            return
        }

        if host == "groupchallenges" || host == "challenges" || pathParts.contains("groupchallenges") {
            setSelectedTab(.groupChallenges, session: session)
            return
        }

        Self.logger.info("Unsupported deep link shape: \(url.absoluteString, privacy: .public)")
    }

    private func applyGenerateIntent(
        tab: AppTab,
        categoryRaw: String?,
        toneRaw: String?,
        friendName: String?,
        scenario: String?,
        shouldGenerate: Bool,
        session: AppSessionViewModel
    ) {
        var categoryToApply = session.generate.selectedCategory
        var toneToApply = session.generate.selectedTone

        if let categoryRaw,
            let category = AdviceCategory(rawValue: categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        {
            categoryToApply = category
        }

        if let toneRaw,
            let tone = ToneMode(rawValue: toneRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        {
            toneToApply = tone
        }

        if shouldGenerate || categoryRaw != nil || toneRaw != nil {
            session.generate.updateSelections(
                category: categoryToApply,
                tone: toneToApply,
                autoGenerate: false
            )
        }

        if let friendName {
            session.generate.friendName = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if tab == .generate {
            session.generate.friendName = ""
        }

        if let scenario {
            session.generate.scenarioText = scenario.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if tab == .generate {
            session.generate.scenarioText = session.generate.scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if shouldGenerate {
            Task {
                await session.generate.generate()
            }
        }
    }

    private func handlePendingAppIntent(for session: AppSessionViewModel) async {
        guard !isHostedUnitTesting else { return }

        while let payload = BadviceIntentRouter.shared.consume() {
            switch payload.command {
            case .openTab:
                if let tabValue = payload.tab, let tab = AppTab(rawValue: tabValue) {
                    openShellMenuTab(tab, session: session)
                }

            case .generateAdvice:
                setSelectedTab(
                    AppTab(rawValue: payload.tab ?? AppTab.generate.rawValue) ?? .generate,
                    session: session
                )
                applyGenerateIntent(
                    tab: AppTab(rawValue: payload.tab ?? AppTab.generate.rawValue) ?? .generate,
                    categoryRaw: payload.category,
                    toneRaw: payload.tone,
                    friendName: payload.friendName,
                    scenario: payload.scenario,
                    shouldGenerate: payload.shouldGenerate,
                    session: session
                )

            case .openDailyQuote:
                setSelectedTab(.quotes, session: session)
            }
        }

        while let link = pendingDeepLinks.first {
            pendingDeepLinks.removeFirst()
            await routeIncomingDeepLink(link, session: session)
        }
    }

    private func queueUnsupportedDeepLink(_ url: URL) {
        let maxQueueSize = 8
        if pendingDeepLinks.count >= maxQueueSize {
            pendingDeepLinks.removeFirst(pendingDeepLinks.count - maxQueueSize + 1)
        }
        pendingDeepLinks.append(url)
    }

    @ViewBuilder
    private func tabView(for tab: AppTab, session: AppSessionViewModel) -> some View {
        switch tab {
        case .generate:
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                social: session.social,
                onDataChanged: { session.refreshLists() },
                onOpenTab: { tab in
                    openShellMenuTab(tab, session: session)
                },
                isActive: selectedTab == .generate,
                settingsPresented: showingSettingsRoot,
                quickAccessTabs: brandMenuTabs(),
                onResetAllLocalAccounts: {
                    await resetAllLocalAccounts(using: auth, session: session)
                }
            )
        case .chaosHub:
            ChaosHubTabView(
                generateViewModel: session.generate,
                settings: session.settings,
                social: session.social,
                onOpenTab: { tab in
                    openShellMenuTab(tab, session: session)
                },
                onDataChanged: {
                    session.refreshLists()
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
                    openShellMenuTab(tab, session: session)
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
            if let auth {
                settingsSheetContent(auth: auth, session: session)
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
                    session.generate.updateSelections(
                        category: category,
                        tone: tone,
                        autoGenerate: true
                    )
                    setSelectedTab(.generate, session: session)
                }
            )
        case .groupChallenges:
            GroupChallengesTabView(
                social: session.social,
                generateViewModel: session.generate,
                settings: session.settings,
                onOpenTab: { tab in
                    openShellMenuTab(tab, session: session)
                }
            )
        }
    }

    private func setSelectedTab(_ tab: AppTab, session: AppSessionViewModel) {
        if tab == .settings {
            showingSettingsRoot = true
            tabBarVisible = true
            return
        }

        showingSettingsRoot = false
        loadedTabs.insert(tab)
        Self.logger.debug("Selected tab -> \(tab.rawValue, privacy: .public)")
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

    private func openShellMenuTab(_ tab: AppTab, session: AppSessionViewModel) {
        setTabFromMenuSelection(tab, session: session)
    }

    private func handleShellMenuDismiss(session: AppSessionViewModel?) {
        guard let session, let tab = pendingShellMenuTab else {
            return
        }
        pendingShellMenuTab = nil
        DispatchQueue.main.async {
            openShellMenuTab(tab, session: session)
        }
    }

    private func setTabFromMenuSelection(_ tab: AppTab, session: AppSessionViewModel) {
        tabBarVisible = true
        if tab == .settings {
            showingSettingsRoot = true
            return
        }

        showingSettingsRoot = false
        setSelectedTab(tab, session: session)
    }

    private func primaryTabs(for session: AppSessionViewModel) -> [AppTab] {
        let allowedPrimary = Set(AppTab.primaryNavigationTabs)
        var seen = Set<AppTab>()
        let orderedPrimaryTabs = session.settings.tabOrder.filter { tab in
            allowedPrimary.contains(tab) && seen.insert(tab).inserted
        }
        let missingPrimaryTabs = AppTab.primaryNavigationTabs.filter { !seen.contains($0) }
        return orderedPrimaryTabs + missingPrimaryTabs
    }

    private func shellTabs(for session: AppSessionViewModel) -> [AppTab] {
        var tabs = primaryTabs(for: session)
        if !tabs.contains(selectedTab), selectedTab != .settings {
            tabs.append(selectedTab)
        }
        return tabs
    }

    private func brandMenuTabs() -> [AppTab] {
        AppTab.brandMenuTabs.filter {
            $0 != .settings || settingsTabAvailable
        }
    }

    @ViewBuilder
    private func lazyTabContent(for tab: AppTab, session: AppSessionViewModel) -> some View {
        Group {
            if loadedTabs.contains(tab) || selectedTab == tab {
                tabView(for: tab, session: session)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("tab.\(tab.rawValue).container")
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
                AchievementProgressRecord.self,
                AppSettingsEntity.self,
            ],
            inMemory: true
        )
}
