import Combine
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

private enum LocalAuthMode: String, CaseIterable, Identifiable {
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
    @State private var profileHandleDraft = ""
    @State private var profileDisplayNameDraft = UIDevice.current.name
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

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("favoritesCountAtLastReview") private var favoritesCountAtLastReview = 0
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true

    private var launchArguments: [String] { ProcessInfo.processInfo.arguments }
    private var isUITesting: Bool { launchArguments.contains("-ui-testing") }

    var body: some View {
        appRootView
    }

    @ViewBuilder
    private var appRootView: some View {
        if showSplash {
            SplashView(isShowing: $showSplash)
                .transition(.opacity)
                .task {
                    bootstrapAppStateIfNeeded()
                }
        } else if let auth {
            if auth.isAuthenticated, let session {
                authenticatedSessionView(auth: auth, session: session)
            } else if auth.isAuthenticated {
                loadingView
                    .task {
                        bootstrapAppStateIfNeeded()
                    }
            } else {
                authGateView(auth: auth)
            }
        } else {
            loadingView
                .task {
                    bootstrapAppStateIfNeeded()
                }
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
        .task {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
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
                Task {
                    await self.session?.social.refreshAvailability()
                    await self.session?.social.refreshSocialData()
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
            Task {
                await syncAuthContext(auth: auth, social: session.social)
            }
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
        .onChange(of: auth.currentSession?.accountID) { _, _ in
            Task {
                await syncAuthContext(auth: auth, social: session.social)
            }
        }
        .onChange(of: session.social.currentUser?.recordID.recordName) { _, newRecordName in
            auth.setLinkedSocialProfileRecordName(newRecordName)
        }
        .sheet(
            isPresented: Binding(
                get: {
                    !showSplash
                        && auth.isAuthenticated
                        && hasSeenOnboarding
                        && session.social.shouldShowProfileSetup
                },
                set: { _ in }
            )
        ) {
            socialProfileSetupSheet(session: session)
        }
    }

    private func socialProfileSetupSheet(session: AppSessionViewModel) -> some View {
        let handleBinding = Binding<String>(
            get: { profileHandleDraft },
            set: { profileHandleDraft = sanitizedProfileHandle($0) }
        )
        let displayNameBinding = Binding<String>(
            get: { profileDisplayNameDraft },
            set: { profileDisplayNameDraft = sanitizedProfileDisplayName($0) }
        )
        let normalizedHandle = normalizedProfileHandle(profileHandleDraft)
        let isHandleValid = CloudKitStore.isValidHandle(normalizedHandle)
        let shouldShowValidationError = !normalizedHandle.isEmpty && !isHandleValid

        return NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Set up your Friends profile",
                            systemImage: "person.2.crop.square.stack.fill"
                        )
                        .font(.headline)
                        Text(
                            "Your handle is how friends find you for shares, collabs, and Chaos leaderboard runs."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("social.profile.intro")
                }
                Section("Create Profile") {
                    TextField("@handle", text: handleBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .submitLabel(.next)
                        .accessibilityIdentifier("social.profile.handle")
                    TextField(
                        "Display name (optional)",
                        text: displayNameBinding
                    )
                    .textInputAutocapitalization(.words)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .accessibilityIdentifier("social.profile.displayName")
                    Text("Pick a public handle once. Type with or without the @ symbol.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Handle preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(normalizedHandle.isEmpty ? "@your_handle" : "@\(normalizedHandle)")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                isHandleValid || normalizedHandle.isEmpty
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    HStack {
                        Text("Handle length")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(normalizedHandle.count)/16")
                            .font(.caption.monospaced())
                            .foregroundStyle(
                                isHandleValid || normalizedHandle.isEmpty
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    if session.social.isSubmittingAction {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Creating profile...")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Section("What unlocks next") {
                    Label(
                        "Share advice and quotes straight to Friends",
                        systemImage: "square.and.arrow.up.fill"
                    )
                    .font(.caption)
                    Label(
                        "Start collaboration drafts with your crew",
                        systemImage: "person.2.badge.plus"
                    )
                    .font(.caption)
                    Label(
                        "Compete on the Chaos leaderboard",
                        systemImage: "trophy.fill"
                    )
                    .font(.caption)
                }
                if shouldShowValidationError {
                    Section("Fix Handle") {
                        Text(
                            "Use 3–16 characters with lowercase letters, numbers, or underscore."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                if let status = session.social.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.lowercased().contains("created") ? .green : .red
                            )
                            .accessibilityIdentifier("social.profile.status")
                    }
                }
                Section("Rules") {
                    Text(
                        "Handle must be 3–16 characters and can only use lowercase letters, numbers, or underscore. You can type with or without @."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Friends Setup")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(session.social.isSubmittingAction ? "Creating..." : "Finish Setup") {
                        Task {
                            await session.social.createProfile(
                                handle: normalizedHandle,
                                displayName: profileDisplayNameDraft
                            )
                        }
                    }
                    .disabled(
                        normalizedHandle.isEmpty || !isHandleValid
                            || session.social.isSubmittingAction
                    )
                    .accessibilityIdentifier("social.profile.save")
                }
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                ProgressView()
                    .tint(.primary)
                Text("Loading your chaos...")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
            }
        }
    }

    private func bootstrapAppStateIfNeeded() {
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
        }
        syncProfileDrafts(with: auth)
        Task {
            await syncAuthContext(auth: auth, social: session?.social)
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

    private func syncProfileDrafts(with auth: AuthViewModel) {
        profileDisplayNameDraft = sanitizedProfileDisplayName(auth.displayName)
    }

    private func resetSessionPresentationState() {
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
    }

    private func beginAuthenticatedSession(using auth: AuthViewModel) {
        resetSessionPresentationState()
        syncAuthDrafts(with: auth)
        syncProfileDrafts(with: auth)
        session = AppSessionViewModel(context: modelContext, accountID: auth.currentSession?.accountID)
        applyUITestLaunchOverridesIfNeeded()
        Task {
            await syncAuthContext(auth: auth, social: session?.social)
        }
    }

    private func signOutCurrentAccount(_ auth: AuthViewModel) {
        auth.signOut()
        session = nil
        resetSessionPresentationState()
        profileHandleDraft = ""
        profileDisplayNameDraft = UIDevice.current.name
        authMode = .signIn
        syncAuthDrafts(with: auth)
    }

    private func deleteCurrentAccount(_ auth: AuthViewModel, password: String) async {
        let didDelete = await auth.deleteCurrentAccount(password: password)
        guard didDelete else { return }
        session?.repository.purgeCurrentAccountData()
        session = nil
        resetSessionPresentationState()
        profileHandleDraft = ""
        profileDisplayNameDraft = UIDevice.current.name
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
        let normalizedEmail = LocalAccountValidation.normalizedEmail(authEmailDraft)
        let trimmedDisplayName = authDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSubmitSignIn =
            LocalAccountValidation.isValidEmail(normalizedEmail) && !authPasswordDraft.isEmpty
        let canSubmitSignUp =
            LocalAccountValidation.isValidEmail(normalizedEmail)
            && LocalAccountValidation.isStrongPassword(authPasswordDraft)
            && authPasswordDraft == authConfirmPasswordDraft
        let accent = Color(hex: "8F4A22")

        ZStack {
            LinearGradient(
                colors: [Color(hex: "F7F2E8"), Color(hex: "EBDAC8"), Color(hex: "F8F4EE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FloatingParticlesView(theme: .minimal, reduceMotion: true, isGenerating: false)
                .opacity(0.2)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 92, height: 92)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        Text("Local account required")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.headerColor(for: .minimal))

                        Text("Create a Badvice account on this device, or sign back in to keep your chaos behind a real password.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.primary.opacity(0.68))
                            .padding(.horizontal, 12)
                    }

                    VStack(spacing: 18) {
                        Picker("Authentication", selection: $authMode) {
                            ForEach(LocalAuthMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("auth.mode")

                        VStack(spacing: 14) {
                            if authMode == .signUp {
                                TextField("Display name (optional)", text: $authDisplayNameDraft)
                                    .textInputAutocapitalization(.words)
                                    .textContentType(.name)
                                    .accessibilityIdentifier("auth.displayName")
                            }

                            TextField("Email", text: $authEmailDraft)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("auth.email")

                            SecureField(
                                authMode == .signUp ? "Create password" : "Password",
                                text: $authPasswordDraft
                            )
                            .textContentType(authMode == .signUp ? .newPassword : .password)
                            .accessibilityIdentifier("auth.password")

                            if authMode == .signUp {
                                SecureField("Confirm password", text: $authConfirmPasswordDraft)
                                    .textContentType(.newPassword)
                                    .accessibilityIdentifier("auth.confirmPassword")
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(authMode == .signUp ? "Passwords need at least 8 characters, plus a letter and a number." : "Accounts are stored only on this device.")
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(0.58))
                            if authMode == .signUp, !trimmedDisplayName.isEmpty,
                                !LocalAccountValidation.isValidDisplayName(trimmedDisplayName)
                            {
                                Text("Display name must be 2-40 characters.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let status = auth.statusMessage, !status.isEmpty {
                            Text(status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(status.lowercased().contains("signed") || status.lowercased().contains("created") ? accent : .red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("auth.status")
                        }

                        Button {
                            Task {
                                let didAuthenticate: Bool
                                switch authMode {
                                case .signIn:
                                    didAuthenticate = await auth.signIn(
                                        email: normalizedEmail,
                                        password: authPasswordDraft
                                    )
                                case .signUp:
                                    didAuthenticate = await auth.signUp(
                                        email: normalizedEmail,
                                        displayName: trimmedDisplayName,
                                        password: authPasswordDraft,
                                        confirmPassword: authConfirmPasswordDraft
                                    )
                                }

                                if didAuthenticate {
                                    beginAuthenticatedSession(using: auth)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if auth.isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(authMode == .signUp ? "Create Account" : "Sign In")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(accent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            auth.isSubmitting
                                || (authMode == .signIn ? !canSubmitSignIn : !canSubmitSignUp)
                        )
                        .opacity(
                            auth.isSubmitting
                                || (authMode == .signIn ? !canSubmitSignIn : !canSubmitSignUp)
                                ? 0.6 : 1
                        )
                        .accessibilityIdentifier("auth.primary")

                        if auth.hasAccounts {
                            Button(authMode == .signIn ? "Need a new local account?" : "Use an existing account instead") {
                                authMode = authMode == .signIn ? .signUp : .signIn
                                auth.statusMessage = nil
                                authPasswordDraft = ""
                                authConfirmPasswordDraft = ""
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .accessibilityIdentifier("auth.switchMode")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(accent.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 36)
            }
        }
        .onAppear {
            if !auth.hasAccounts {
                authMode = .signUp
            }
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
                    tabView(for: tab, session: session)
                        .tag(tab)
                        .toolbar(.hidden, for: .tabBar)  // Hide standard bar
                        .environment(\.tabBarVisible, $tabBarVisible)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Extend only the bottom edge so the custom tab bar overlaps the home indicator
            // region without pushing content under the Dynamic Island / status bar.
            .ignoresSafeArea(.all, edges: .bottom)
            // Performance: Disable animation if reduce motion is enabled
            .animation(
                constrainedMotion ? nil : .easeInOut(duration: 0.3), value: selectedTab)

            // Custom Floating Tab Bar — supports tap and instant press-slide
            GeometryReader { proxy in
                VStack {
                    Spacer()
                    let tabs = session.settings.tabOrder
                    let tabBarStyle = Theme.tabBarStyle(for: session.settings.theme)
                    let accent = Theme.accent(for: session.settings.theme)
                    let secondaryText = Theme.secondaryText(for: session.settings.theme)
                    let friendsBadgeCount = session.social.incomingRequests.count
                    HStack(spacing: 0) {
                        ForEach(tabs) { tab in
                            let isSelected = selectedTab == tab
                            let isHighlighted = tabDragHighlight == tab
                            let badgeCount = tab == .friends ? friendsBadgeCount : 0
                            let tabAccessibilityID = "tab.\(tab.rawValue)"
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
                                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule(style: .continuous).fill(.red))
                                            .offset(x: 10, y: -7)
                                            .accessibilityIdentifier("tab.friends.badge")
                                    }
                                }
                                Text(tab.title)
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
                            .contentShape(Rectangle())
                            .accessibilityAddTraits(.isButton)
                            .onTapGesture {
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
                            }
                            .accessibilityAction {
                                if selectedTab != tab {
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
                                }
                            }
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

    private func normalizedProfileHandle(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefixAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return SocialViewModel.normalizedHandle(withoutPrefixAt)
    }

    private func sanitizedProfileHandle(_ input: String) -> String {
        let normalized = normalizedProfileHandle(input)
        let allowedScalars = normalized.unicodeScalars.filter { scalar in
            let value = scalar.value
            let isLowercaseASCII = (97...122).contains(value)
            let isDigitASCII = (48...57).contains(value)
            let isUnderscore = value == 95
            return isLowercaseASCII || isDigitASCII || isUnderscore
        }
        let filtered = String(String.UnicodeScalarView(allowedScalars))
        return String(filtered.prefix(16))
    }

    private func sanitizedProfileDisplayName(_ input: String) -> String {
        String(input.prefix(40))
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
                    setSelectedTab(tab, session: session)
                }
            )
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
            if let auth {
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
                AppSettingsEntity.self,
            ],
            inMemory: true
        )
}
