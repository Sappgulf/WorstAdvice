import Charts
import SwiftUI
import UIKit
import UserNotifications

struct SettingsTabView: View {
    private enum AuthSheet: Identifiable {
        case changePassword
        case deleteAccount

        var id: String {
            switch self {
            case .changePassword: "changePassword"
            case .deleteAccount: "deleteAccount"
            }
        }
    }

    @Bindable var viewModel: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var quotesViewModel: QuotesViewModel
    @Bindable var social: SocialViewModel
    @Bindable var auth: AuthViewModel
    var achievementsManager: AchievementsManager
    var onSignOut: () -> Void
    var onDeleteAccount: (_ password: String) async -> Void
    @AppStorage(AppTab.settings.focusModeStorageKey) private var isFocusMode = false

    @State private var sectionsAppeared = false
    @State private var gearWobble = false
    @State private var gearSpinDegrees: Double = 0
    @State private var gearIsSpinning = false
    @State private var gearSettleScale: CGFloat = 1.0

    @State private var shockwaveTheme: ThemeMode?
    @State private var shockwaveScale: CGFloat = 0.1
    @State private var shockwaveOpacity: Double = 0
    @State private var activeAuthSheet: AuthSheet?

    @State private var appearanceTask: Task<Void, Never>?
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var shockwaveTask: Task<Void, Never>?
    @State private var socialLoadTask: Task<Void, Never>?
    @State private var notificationsTask: Task<Void, Never>?
    @State private var gearResetTask: Task<Void, Never>?
    @State private var didLoadInitialDiagnostics = false
    @State private var showingSocialDiagnostics = false
    @State private var currentPasswordDraft = ""
    @State private var newPasswordDraft = ""
    @State private var confirmPasswordDraft = ""
    @State private var deletePasswordDraft = ""

    private let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @AppStorage("shakeToGenerateEnabled") private var shakeToGenerateEnabled = true
    @State private var notificationPermissionGranted: Bool? = nil
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentR") private var customAccentR: Double = 1.0
    @AppStorage("customAccentG") private var customAccentG: Double = 0.3
    @AppStorage("customAccentB") private var customAccentB: Double = 0.3
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private static let hour12Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // Cache version string — Bundle lookup is expensive inside body
    private static let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "Badvice v\(v) (\(b))"
    }()

    private var isMotionReduced: Bool {
        viewModel.reduceMotion || viewModel.performanceMode || accessibilityReduceMotion
    }

    private var accent: Color {
        if useCustomAccent {
            return Theme.accent(for: viewModel.theme, customColor: Color(red: customAccentR, green: customAccentG, blue: customAccentB))
        }
        return Theme.accent(for: viewModel.theme)
    }
    private var primaryText: Color { Theme.primaryText(for: viewModel.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: viewModel.theme) }
    private var cardColor: Color { Theme.cardColor(for: viewModel.theme) }
    private var buttonText: Color { Theme.buttonText(for: viewModel.theme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                settingsHeroCard
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 18)
                    .animation(
                        isMotionReduced
                            ? nil
                            : .spring(response: 0.5, dampingFraction: 0.78),
                        value: sectionsAppeared
                    )

                Group {
                    if isFocusMode {
                        accountSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75),
                                value: sectionsAppeared
                            )
                        themeSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.05),
                                value: sectionsAppeared
                            )
                        experienceSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.10),
                                value: sectionsAppeared
                            )
                    } else {
                        socialHealthSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75),
                                value: sectionsAppeared
                            )
                        accountSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.05),
                                value: sectionsAppeared
                            )
                        communityLabsSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.10),
                                value: sectionsAppeared
                            )
                        themeSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.15),
                                value: sectionsAppeared
                            )
                        experienceSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.20),
                                value: sectionsAppeared
                            )
                        notificationSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.225),
                                value: sectionsAppeared
                            )
                        sharingSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.25),
                                value: sectionsAppeared
                            )
                        discoverSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.30),
                                value: sectionsAppeared
                            )
                        dataSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.35),
                                value: sectionsAppeared
                            )
                        aboutSection
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 24)
                            .scaleEffect(sectionsAppeared ? 1 : 0.96)
                            .animation(
                                isMotionReduced
                                    ? nil
                                    : .spring(response: 0.5, dampingFraction: 0.75).delay(0.40),
                                value: sectionsAppeared
                            )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, Theme.tabContentBottomInset)
        }
        .coordinateSpace(name: "scroll")
        .trackScrollForTabBar()
        .background(Color.clear)
        .preferredColorScheme(Theme.colorScheme(for: viewModel.theme))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sectionsAppeared = false
            gearWobble = false
            tabBarVisible.wrappedValue = true
            if !didLoadInitialDiagnostics {
                didLoadInitialDiagnostics = true
                dataLoadTask?.cancel()
                dataLoadTask = Task(priority: .utility) {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                }
                socialLoadTask?.cancel()
                socialLoadTask = Task(priority: .background) {
                    quotesViewModel.loadIfNeeded()
                    await social.loadBackendDisplayNameIfNeeded()
                    guard !Task.isCancelled else { return }
                    await social.refreshAvailability()
                }
                notificationsTask?.cancel()
                notificationsTask = Task(priority: .background) {
                    guard !Task.isCancelled else { return }
                    await loadNotificationPermissionStatus()
                }
            }
            appearanceTask?.cancel()
            appearanceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                sectionsAppeared = true
                if !isMotionReduced { gearWobble = true }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshAppleOnDeviceModelAvailability()
            }
        }
        .onDisappear {
            appearanceTask?.cancel()
            dataLoadTask?.cancel()
            shockwaveTask?.cancel()
            socialLoadTask?.cancel()
            notificationsTask?.cancel()
            gearResetTask?.cancel()
            gearResetTask = nil
            sectionsAppeared = false
            gearWobble = false
            gearSpinDegrees = 0
            gearIsSpinning = false
            gearSettleScale = 1.0
            shockwaveTheme = nil
        }
        .overlay {
            if let st = shockwaveTheme {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent(for: st).opacity(0.4), .clear],
                            center: .center, startRadius: 0, endRadius: 200)
                    )
                    .scaleEffect(shockwaveScale)
                    .opacity(shockwaveOpacity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .sheet(item: $activeAuthSheet) { sheet in
            switch sheet {
            case .changePassword:
                changePasswordSheet
            case .deleteAccount:
                deleteAccountSheet
            }
        }
        .navigationDestination(isPresented: $showingSocialDiagnostics) {
            SocialHealthDiagnosticsView(social: social, settings: viewModel)
        }
        .toolbar { focusModeToolbar }
    }

    @ToolbarContentBuilder
    private var focusModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            TabFocusModeToggle(
                isEnabled: isFocusMode,
                accent: accent
            ) {
                HapticsManager.playSelection(isEnabled: viewModel.hapticsEnabled)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocusMode.toggle()
                }
            }
        }
    }

    private var settingsHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    gearIsSpinning = true
                    if isMotionReduced {
                        gearSpinDegrees += 45
                    } else {
                        gearSpinDegrees += 720
                    }
                    gearResetTask?.cancel()
                    gearResetTask = Task { @MainActor in
                        if !isMotionReduced {
                            withAnimation(.easeIn(duration: 0.18)) { gearSettleScale = 0.88 }
                            try? await Task.sleep(for: .seconds(0.22))
                            guard !Task.isCancelled else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) {
                                gearSettleScale = 1.0
                            }
                        }
                        try? await Task.sleep(for: .seconds(1.1))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            gearIsSpinning = false
                        }
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: accent.opacity(0.25), radius: 10, y: 5)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                        .scaleEffect(
                            (sectionsAppeared
                                ? (isMotionReduced
                                    ? 1
                                    : (gearIsSpinning ? 1.06 : (gearWobble ? 1.025 : 0.98)))
                                : 0.5) * gearSettleScale
                        )
                        .animation(
                            isMotionReduced
                                ? nil
                                : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                            value: gearWobble
                        )
                        .animation(
                            isMotionReduced
                                ? .easeOut(duration: 0.25)
                                : .interpolatingSpring(stiffness: 80, damping: 10),
                            value: gearSpinDegrees
                        )
                        .rotationEffect(
                            .degrees(
                                sectionsAppeared
                                    ? (gearSpinDegrees + (isMotionReduced ? 0 : (gearWobble ? 3 : -3)))
                                    : -180
                            ))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Settings")
                .accessibilityHint("Double-tap to spin")
                .accessibilityIdentifier("settings.menuButton")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Personalize Badvice")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(primaryText)
                        .opacity(sectionsAppeared ? 1 : 0)

                    Text(
                        "Tune how Badvice looks, sounds, and behaves without leaving the app shell."
                    )
                    .font(.footnote)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                settingsHeroChip(
                    title: "Theme",
                    value: viewModel.theme.title,
                    systemImage: "paintpalette"
                )
                settingsHeroChip(
                    title: "Motion",
                    value: isMotionReduced ? "Reduced" : "Full",
                    systemImage: "sparkles"
                )
                settingsHeroChip(
                    title: "Haptics",
                    value: viewModel.hapticsEnabled ? "On" : "Off",
                    systemImage: "waveform"
                )
            }
        }
        .padding(Theme.sectionSpacing)
        .background(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor.opacity(0.96), cardColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                .fill(accent.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func settingsHeroChip(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(value)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.14), accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.2), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
                .blendMode(.screen),
            alignment: .top
        )
    }

    // MARK: - Section Cards

    private var accountSection: some View {
        settingsCard(title: "Account", icon: "person.crop.circle.badge.checkmark") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .accessibilityIdentifier("settings.auth.displayName")
                        Text(auth.signedInEmail ?? "Signed in")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .accessibilityIdentifier("settings.auth.email")
                    }

                    Spacer()
                }

                settingsDivider

                TabCommandActionButton(
                    title: "Change Password",
                    systemImage: "key.fill",
                    accent: accent,
                    buttonText: buttonText
                ) {
                    currentPasswordDraft = ""
                    newPasswordDraft = ""
                    confirmPasswordDraft = ""
                    activeAuthSheet = .changePassword
                }
                .accessibilityIdentifier("settings.auth.changePassword")

                TabCommandActionButton(
                    title: "Delete Local Account",
                    systemImage: "trash.fill",
                    accent: .red,
                    buttonText: buttonText,
                    prominent: false
                ) {
                    deletePasswordDraft = ""
                    activeAuthSheet = .deleteAccount
                }
                .accessibilityIdentifier("settings.auth.deleteAccount")

                TabCommandActionButton(
                    title: "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false
                ) {
                    onSignOut()
                }
                .accessibilityIdentifier("settings.auth.signOut")
            }
        }
    }

    private var changePasswordSheet: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    SecureField("Current password", text: $currentPasswordDraft)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.auth.currentPassword")
                    SecureField("New password", text: $newPasswordDraft)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("settings.auth.newPassword")
                    SecureField("Confirm new password", text: $confirmPasswordDraft)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("settings.auth.confirmNewPassword")
                    Text("Use at least 8 characters, including a letter and a number.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let status = auth.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.localizedCaseInsensitiveContains("updated") ? .green : .red
                            )
                            .accessibilityIdentifier("settings.auth.passwordStatus")
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeAuthSheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auth.isSubmitting ? "Saving..." : "Save") {
                        Task {
                            let didUpdate = await auth.changePassword(
                                currentPassword: currentPasswordDraft,
                                newPassword: newPasswordDraft,
                                confirmPassword: confirmPasswordDraft
                            )
                            if didUpdate {
                                activeAuthSheet = nil
                            }
                        }
                    }
                    .disabled(
                        auth.isSubmitting
                            || currentPasswordDraft.isEmpty
                            || newPasswordDraft.isEmpty
                            || confirmPasswordDraft.isEmpty
                    )
                    .accessibilityIdentifier("settings.auth.passwordSave")
                }
            }
        }
    }

    private var deleteAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Delete local account") {
                    Text("This removes the local Badvice account on this device and clears local app data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Current password", text: $deletePasswordDraft)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.auth.deletePassword")
                }

                if let status = auth.statusMessage, !status.isEmpty {
                    Section("Status") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(
                                status.localizedCaseInsensitiveContains("deleted") ? .green : .red
                            )
                            .accessibilityIdentifier("settings.auth.deleteStatus")
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeAuthSheet = nil
                        deletePasswordDraft = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auth.isSubmitting ? "Deleting..." : "Delete", role: .destructive) {
                        Task {
                            await onDeleteAccount(deletePasswordDraft)
                            if !auth.isAuthenticated {
                                activeAuthSheet = nil
                            }
                        }
                    }
                    .disabled(auth.isSubmitting || deletePasswordDraft.isEmpty)
                    .accessibilityIdentifier("settings.auth.deleteConfirm")
                }
            }
        }
    }

    private var communityLabsSection: some View {
        settingsCard(title: "Community & Labs", icon: "person.2.badge.gearshape") {
            VStack(spacing: 12) {
                NavigationLink {
                    SuggestionLabView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Advice Suggestion Lab",
                        systemImage: "plus.bubble",
                        badge: generateViewModel.communitySuggestionCount > 0
                            ? "\(generateViewModel.communitySuggestionCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    AchievementsView(manager: achievementsManager, theme: viewModel.theme)
                } label: {
                    settingsNavRow(
                        "Achievements",
                        systemImage: "trophy.fill",
                        badge: achievementsManager.unlockedAchievementCount > 0
                            ? "\(achievementsManager.unlockedAchievementCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    QuoteSuggestionLabView(viewModel: quotesViewModel, settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Quote Suggestion Lab",
                        systemImage: "quote.bubble.fill",
                        badge: quotesViewModel.quoteSuggestionCount > 0
                            ? "\(quotesViewModel.quoteSuggestionCount)" : nil
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    CommunityPulseView(viewModel: generateViewModel, settings: viewModel)
                } label: {
                    settingsNavRow("Community Pulse", systemImage: "chart.bar.xaxis", badge: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var socialHealthSection: some View {
        settingsCard(title: "Social System", icon: "stethoscope") {
            VStack(spacing: 12) {
                Button {
                    showingSocialDiagnostics = true
                } label: {
                    settingsNavRow(
                        "Social Diagnostics",
                        systemImage: "waveform.path.ecg",
                        badge: social.queuedActionCount > 0 ? "\(social.queuedActionCount)" : nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.socialHealth.open")

                settingsDivider

                Button {
                    UIPasteboard.general.string = socialHealthReportText()
                } label: {
                    Label("Copy Diagnostics Summary", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("settings.socialHealth.copyReport")

                settingsDivider

                socialStatRow("Backend", value: social.backendDisplayName)
                socialStatRow(
                    "Availability",
                    value: social.availability.isAvailable ? "Available" : "Unavailable"
                )
                socialStatRow(
                    "Profile",
                    value: social.currentUser.map { "@\($0.handle)" } ?? "Not created"
                )
                socialStatRow("Incoming Requests", value: "\(social.incomingRequests.count)")
                socialStatRow("Queue Depth", value: "\(social.queuedActionCount)")

                settingsDivider

                Button {
                    Task {
                        await social.refreshAvailability()
                        await social.refreshSocialData()
                    }
                } label: {
                    Label("Refresh Social Status", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("settings.socialHealth.refresh")
            }
        }
    }

    private var themeSection: some View {
        settingsCard(title: "Theme", icon: "paintpalette") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10
            ) {
                ForEach(ThemeMode.allCases) { mode in
                    let isTileSelected = viewModel.theme == mode
                    let personality = Theme.personality(for: mode)
                    let secondaryAccent = Theme.secondaryAccent(for: mode) ?? Theme.accent(for: mode)
                    let glow = Theme.glowColor(for: mode)
                    let mood = personality.surfaceMood
                    let bestFor = personality.bestFor
                    Button {
                        HapticsManager.playSelection(isEnabled: viewModel.hapticsEnabled)
                        if isMotionReduced {
                            viewModel.theme = mode
                        } else if viewModel.theme != mode {
                            shockwaveTheme = mode
                            shockwaveScale = 0.5
                            shockwaveOpacity = 1.0

                            withAnimation(.easeOut(duration: 0.6)) {
                                shockwaveScale = 6.0
                                shockwaveOpacity = 0.0
                            }

                            withAnimation(.easeInOut(duration: 0.35)) {
                                viewModel.theme = mode
                            }

                            shockwaveTask?.cancel()
                            shockwaveTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(600))
                                guard !Task.isCancelled else { return }
                                shockwaveTheme = nil
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.backgroundGradient(for: mode))
                                    .frame(height: 52)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Theme.accent(for: mode).opacity(0.28),
                                                secondaryAccent.opacity(0.10),
                                                .clear,
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 52)

                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.cardColor(for: mode))
                                    .frame(width: 32, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(
                                                Theme.accent(for: mode).opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .overlay(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(secondaryAccent.opacity(0.75))
                                    .frame(width: 4, height: 24)
                                    .padding(.leading, 5)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isTileSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.accent(for: mode))
                                        .background(Circle().fill(.white).padding(2))
                                        .padding(6)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }

                            VStack(spacing: 2) {
                                Text(mode.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isTileSelected ? accent : secondaryText)

                                Text(mood)
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .foregroundStyle(secondaryText.opacity(isTileSelected ? 0.95 : 0.72))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)

                                Text(bestFor)
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .foregroundStyle(secondaryText.opacity(isTileSelected ? 0.9 : 0.65))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                if isTileSelected {
                                    Text(personality.descriptor)
                                        .font(.system(size: 9, weight: .regular, design: .rounded))
                                        .foregroundStyle(secondaryText.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .transition(
                                            .opacity.combined(
                                                with: .scale(scale: 0.9, anchor: .top)))
                                }
                            }
                            .animation(.easeInOut(duration: Theme.animFast), value: viewModel.theme)
                        }
                    }
                    .accessibilityIdentifier("settings.theme.\(mode.rawValue)")
                    .accessibilityLabel(mode.title)
                    .accessibilityValue(
                        isTileSelected
                            ? "Selected. \(Theme.themeSummary(for: mode))"
                            : Theme.themeSummary(for: mode)
                    )
                    .accessibilityHint("Double-tap to apply this theme to your account.")
                    .overlay {
                        if isTileSelected, let glow {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(glow.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isTileSelected ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 0.22, dampingFraction: 0.58), value: isTileSelected)
                }
            }
            Divider().opacity(0.5)
            Text("Themes are stored separately for each signed-in account.")
                .font(.caption2)
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.theme.accountScope")
            Toggle("Custom Accent Color", isOn: $useCustomAccent)
                .tint(accent)
            if useCustomAccent {
                ColorPicker(
                    "Accent Color",
                    selection: Binding<Color>(
                        get: {
                            Color(red: customAccentR, green: customAccentG, blue: customAccentB)
                        },
                        set: { newColor in
                            let ui = UIColor(newColor)
                            var r: CGFloat = 0
                            var g: CGFloat = 0
                            var b: CGFloat = 0
                            var a: CGFloat = 0
                            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                            customAccentR = r
                            customAccentG = g
                            customAccentB = b
                        }
                    ),
                    supportsOpacity: false
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var experienceSection: some View {
        settingsCard(title: "Experience", icon: "sparkles") {
            VStack(spacing: 12) {
                Toggle("Haptic Feedback", isOn: $viewModel.hapticsEnabled)
                Divider().opacity(0.5)
                Toggle("Reduce Motion", isOn: $viewModel.reduceMotion)
                Divider().opacity(0.5)
                Toggle("Performance Mode", isOn: $viewModel.performanceMode)
                Divider().opacity(0.5)
                Toggle("Shake to Generate", isOn: $shakeToGenerateEnabled)
                if isLowPowerModeEnabled {
                    Divider().opacity(0.5)
                    Label("Low Power Mode is on", systemImage: "battery.25")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .tint(accent)
        }
    }

    private func socialHealthReportText() -> String {
        let diagnostics = social.availability.diagnostics
        return [
            diagnostics.text(includeDebugDetails: false),
            "",
            "Backend: \(social.backendDisplayName)",
            "Profile: \(social.currentUser.map { "@\($0.handle)" } ?? "None")",
            "Queue Depth: \(social.queuedActionCount)",
            "Queued Reports: \(social.queuedModerationReportCount)",
            "Incoming Requests: \(social.incomingRequests.count)",
            "Friends: \(social.friends.count)",
            "Collab Docs: \(social.collabDocs.count)",
            "Last Queue Drain: \(reportDateString(social.lastQueueDrainAt))",
        ]
        .joined(separator: "\n")
    }

    private func reportDateString(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return Self.reportDateFormatter.string(from: date)
    }

    private static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var notificationSection: some View {
        settingsCard(title: "Notifications", icon: "bell") {
            VStack(spacing: 12) {
                // Permission status indicator
                HStack(spacing: 8) {
                    Image(systemName: notificationPermissionGranted == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(notificationPermissionGranted == true ? .green : .orange)
                    Text(notificationPermissionGranted == true ? "Notifications allowed" : "Notifications not enabled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    if notificationPermissionGranted == false {
                        TabCommandActionButton(
                            title: "Enable",
                            systemImage: "bell.badge",
                            accent: accent,
                            buttonText: buttonText,
                            prominent: false,
                            minHeight: 34
                        ) {
                            openAppSettings()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                settingsDivider

                Toggle("Daily Reminder", isOn: Binding(
                    get: { viewModel.dailyNotificationsEnabled },
                    set: { viewModel.dailyNotificationsEnabled = $0 }
                ))
                .disabled(notificationPermissionGranted == false)

                settingsDivider

                Toggle("Streak Risk Alerts", isOn: Binding(
                    get: { viewModel.streakNotificationsEnabled },
                    set: { viewModel.streakNotificationsEnabled = $0 }
                ))
                .disabled(notificationPermissionGranted == false || !viewModel.dailyNotificationsEnabled)

                settingsDivider

                settingsPicker(
                    "Daily Reminder Time",
                    systemImage: "clock",
                    selection: Binding(
                        get: { viewModel.dailyNotificationHour },
                        set: { viewModel.dailyNotificationHour = $0 }
                    )
                ) {
                    ForEach(6..<23, id: \.self) { hour in
                        let formatted = Calendar.current.date(from: DateComponents(hour: hour, minute: 0))
                            .map { Self.hour12Formatter.string(from: $0) } ?? "\(hour):00"
                        Text(formatted).tag(hour)
                    }
                }
                .disabled(notificationPermissionGranted == false || !viewModel.dailyNotificationsEnabled)
            }
            .tint(accent)
        }
    }

    private var sharingSection: some View {
        settingsCard(title: "Sharing", icon: "square.and.arrow.up") {
            VStack(spacing: 12) {
                Toggle("Include Disclaimer", isOn: $viewModel.includeDisclaimerOnShare)
                settingsDivider
                settingsPicker(
                    "Template",
                    systemImage: "photo",
                    selection: Binding(
                        get: { viewModel.preferredTemplate },
                        set: { viewModel.preferredTemplate = $0 })
                ) {
                    ForEach(ShareCardTemplate.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Aspect Ratio",
                    systemImage: "aspectratio",
                    selection: Binding(
                        get: { viewModel.preferredAspect }, set: { viewModel.preferredAspect = $0 })
                ) {
                    ForEach(ShareAspectRatio.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                settingsDivider
                settingsPicker(
                    "Caption Style",
                    systemImage: "text.quote",
                    selection: Binding(
                        get: { viewModel.preferredSharePreset },
                        set: { viewModel.preferredSharePreset = $0 })
                ) {
                    ForEach(ShareCaptionPreset.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }
        }
    }

    // MARK: - Discover & Upgrades

    private var discoverSection: some View {
        settingsCard(title: "Discover & Upgrades", icon: "star.circle") {
            VStack(spacing: 12) {
                NavigationLink {
                    UpgradeStoreView(settings: viewModel)
                } label: {
                    settingsNavRow(
                        "Upgrade & Store",
                        systemImage: "star.fill",
                        badge: nil,
                        accessibilityIdentifier: "settings.upgradeStore"
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    InviteFriendsView(social: social, settings: viewModel)
                } label: {
                    settingsNavRow("Invite Friends", systemImage: "person.badge.plus", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    ActivityFeedView(social: social, settings: viewModel)
                } label: {
                    settingsNavRow("Friend Activity", systemImage: "bell.fill", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    OfflinePacksView(settings: viewModel)
                } label: {
                    settingsNavRow("Offline Packs", systemImage: "arrow.down.circle.fill", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    SuggestionPipelineView(settings: viewModel)
                } label: {
                    settingsNavRow("Suggestion Pipeline", systemImage: "arrow.triangle.2.circlepath.circle.fill", badge: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data & Generation", icon: "server.rack") {
            VStack(alignment: .leading, spacing: 10) {
                generationEngineSection

                settingsDivider

                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Local Model")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .accessibilityIdentifier("settings.appleModel.title")

                    appleOnDeviceModelStatusCard
                        .accessibilityIdentifier("settings.appleModel.section")
                }
            }
        }
    }

    private var generationEngineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Generation Engine")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(generationEngineStateText)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.generationEngine.state")
                }
            }

            settingsDivider

            settingsPicker(
                "Provider",
                systemImage: "cpu",
                selection: Binding(
                    get: { viewModel.preferredGenerationProvider },
                    set: { viewModel.preferredGenerationProvider = $0 }
                ),
                pickerAccessibilityIdentifier: "settings.generationEngine.provider"
            ) {
                ForEach(AdviceGenerationProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }

            settingsDivider

            settingsPicker(
                "Content Pack",
                systemImage: viewModel.preferredContentPack.icon,
                selection: Binding(
                    get: { viewModel.preferredContentPack },
                    set: { viewModel.preferredContentPack = $0 }
                ),
                pickerAccessibilityIdentifier: "settings.generationEngine.contentPack"
            ) {
                ForEach(ContentPack.allCases) { pack in
                    Text(pack.title).tag(pack)
                }
            }

            settingsDivider

            Toggle("Include Fake Rationale", isOn: $viewModel.includeRationale)
                .tint(accent)
                .accessibilityIdentifier("settings.generationEngine.rationale")

            settingsDivider

            Toggle("Strict No-Repeats", isOn: $viewModel.strictNoRepeats)
                .tint(accent)
                .accessibilityIdentifier("settings.generationEngine.strictNoRepeats")

            settingsDivider

            Toggle("Community-Only Mode", isOn: $viewModel.communityOnlyMode)
                .tint(accent)
                .accessibilityIdentifier("settings.generationEngine.communityOnly")

            if viewModel.communityOnlyMode {
                Text("Community-only generation uses the local suggestion queue. Add suggestions in the Advice Suggestion Lab if the pool is empty.")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private var generationEngineStateText: String {
        let provider = viewModel.preferredGenerationProvider.title
        let pack = viewModel.preferredContentPack.title
        let rationale = viewModel.includeRationale ? "rationale on" : "rationale off"
        let repeatMode = viewModel.strictNoRepeats ? "strict repeats blocked" : "standard repeat guard"
        let community = viewModel.communityOnlyMode ? "community queue only" : "built-in engine enabled"
        return "\(provider) provider, \(pack) pack, \(rationale), \(repeatMode), \(community)."
    }

    private var personalizationSnapshot: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Personalization Snapshot", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("On-device")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
            }

            HStack(spacing: 8) {
                snapshotPill(title: "Generated", value: "\(generateViewModel.totalGeneratedCount)")
                snapshotPill(title: "Saved", value: "\(generateViewModel.favoriteCount)")
                snapshotPill(
                    title: "Suggestions", value: "\(generateViewModel.communitySuggestionCount)")
            }
        }
    }

    private func socialStatRow(_ title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func snapshotPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var appleOnDeviceModelStatusCard: some View {
        let models = viewModel.appleLocalModels
        return (
            VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Apple Local Model", systemImage: "cpu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                if viewModel.isPreparingAppleOnDeviceModel {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accent)
                } else {
                    Text(viewModel.appleOnDeviceModelStatusBadgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            viewModel.appleOnDeviceModelStatusKey == "ready"
                                ? accent : secondaryText
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    (viewModel.appleOnDeviceModelStatusKey == "ready"
                                        ? accent : secondaryText
                                    ).opacity(0.12))
                        )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: appleModelStatusSymbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(appleModelStatusTint)
                    .padding(.top, 2)
                Text(viewModel.appleOnDeviceModelStatusText)
                    .font(.caption)
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.appleModel.status")
            }

            Text(viewModel.appleOnDeviceModelSetupHintText)
                .font(.caption2)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if models.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No on-device models available yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .accessibilityIdentifier("settings.appleModel.empty")
                    Text(
                        "Use Install to trigger Apple’s system model preparation on supported devices, or add bundled/downloaded CoreML models and tap Recheck."
                    )
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            Task { await viewModel.prepareAppleOnDeviceModel() }
                        } label: {
                            Label("Install", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("settings.appleModel.prepare")

                        Button {
                            viewModel.refreshAppleOnDeviceModelAvailability()
                        } label: {
                            Label("Recheck", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("settings.appleModel.recheckInline")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(secondaryText.opacity(0.12), lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(models) { model in
                        appleLocalModelRow(model)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(cardColor)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(secondaryText.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPreparingAppleOnDeviceModel)
                .opacity(viewModel.isPreparingAppleOnDeviceModel ? 0.7 : 1)
                .accessibilityIdentifier("settings.appleModel.recheckFooter")

                if viewModel.shouldShowOpenAppSettingsShortcut {
                    Button {
                        openAppSettings()
                    } label: {
                        Label("App Settings", systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(cardColor)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(secondaryText.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.appleModel.appSettings")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardColor.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(appleModelStatusTint.opacity(0.2), lineWidth: 1)
            )
        )
    }

    private var appleModelStatusTint: Color {
        switch viewModel.appleOnDeviceModelStatusKey {
        case "ready":
            return accent
        case "installing", "model_not_ready", "installed_not_warmed":
            return .orange
        case "disabled":
            return .yellow
        case "device_policy_blocked", "error":
            return .orange
        case "no_models", "not_installed":
            return secondaryText
        default:
            return secondaryText
        }
    }

    private var appleModelStatusSymbolName: String {
        switch viewModel.appleOnDeviceModelStatusKey {
        case "ready":
            return "checkmark.circle.fill"
        case "installing", "model_not_ready":
            return "arrow.down.circle.fill"
        case "disabled":
            return "exclamationmark.triangle.fill"
        case "installed_not_warmed":
            return "clock.badge.checkmark"
        case "device_policy_blocked":
            return "thermometer.medium"
        case "error":
            return "xmark.octagon.fill"
        case "no_models":
            return "tray"
        case "not_installed":
            return "list.bullet"
        default:
            return "info.circle.fill"
        }
    }

    private func appleLocalModelRow(_ model: LocalModelDescriptor) -> some View {
        let isSelected = viewModel.selectedAppleLocalModelID == model.id
        let state = viewModel.appleLocalModelInstallState(for: model.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.selectAppleLocalModel(id: model.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? accent : secondaryText.opacity(0.5))
                        .font(.caption.weight(.bold))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(model.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Text(model.source.badgeLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(secondaryText.opacity(0.12))
                                )
                            Spacer()
                            Text(localModelStatusLabel(for: model, state: state))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(localModelStateTint(for: state))
                        }
                        if let sizeBytes = model.sizeBytes {
                            Text(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if case .installing(let progress) = state {
                if let progress {
                    ProgressView(value: progress)
                        .tint(accent)
                } else {
                    ProgressView()
                        .tint(accent)
                }
            } else if case .error(let message) = state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if !model.isInstalled {
                    TabCommandActionButton(
                        title: "Install",
                        systemImage: "arrow.down.circle",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false
                    ) {
                        viewModel.selectAppleLocalModel(id: model.id)
                        Task { await viewModel.installAppleLocalModel(id: model.id) }
                    }
                } else {
                    TabCommandActionButton(
                        title: "Warm Up",
                        systemImage: "bolt.fill",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false
                    ) {
                        viewModel.selectAppleLocalModel(id: model.id)
                        Task { await viewModel.warmUpAppleLocalModel(id: model.id) }
                    }
                }

                if model.source == .downloaded {
                    TabCommandActionButton(
                        title: "Remove",
                        systemImage: "trash",
                        accent: .red,
                        buttonText: buttonText,
                        prominent: false
                    ) {
                        Task { await viewModel.removeAppleLocalModel(id: model.id) }
                    }
                }

                TabCommandActionButton(
                    title: "Recheck",
                    systemImage: "arrow.clockwise",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false
                ) {
                    viewModel.refreshAppleOnDeviceModelAvailability()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    (isSelected ? accent : secondaryText).opacity(isSelected ? 0.22 : 0.10),
                    lineWidth: 1
                )
        )
    }

    private func localModelStatusLabel(
        for model: LocalModelDescriptor,
        state: LocalModelInstallState
    ) -> String {
        switch state {
        case .ready:
            return "Ready"
        case .installed:
            return "Installed"
        case .installing:
            return "Installing"
        case .error:
            return "Error"
        case .idle:
            return model.isInstalled ? "Installed" : "Not Installed"
        }
    }

    private func localModelStateTint(for state: LocalModelInstallState) -> Color {
        switch state {
        case .ready:
            return accent
        case .installed:
            return .orange
        case .installing:
            return .orange
        case .error:
            return .orange
        case .idle:
            return secondaryText
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var aboutSection: some View {
        settingsCard(title: "App & Layout", icon: "square.3.layers.3d") {
            VStack(spacing: 12) {
                Text("Advice, Social, Missions, and Library stay in the main bar.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                Text("Saved, History, Explore, Challenges, and Settings live behind More.")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(Array(viewModel.reorderableTabs.enumerated()), id: \.element.id) {
                    index, tab in
                    if index > 0 { settingsDivider }
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .font(.body.weight(.medium))
                            .foregroundStyle(accent)
                            .frame(width: 24)
                        Text(tab.title)
                            .font(Theme.bodyFont(for: viewModel.theme))
                            .foregroundStyle(primaryText)
                        Spacer()
                        HStack(spacing: 4) {
                            Button {
                                viewModel.moveReorderableTabUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(secondaryText.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .opacity(index == 0 ? 0.35 : 1)
                            .accessibilityLabel("Move \(tab.title) up")
                            .accessibilityHint("Reorders the tab bar")

                            Button {
                                viewModel.moveReorderableTabDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(secondaryText.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == viewModel.reorderableTabs.count - 1)
                            .opacity(index == viewModel.reorderableTabs.count - 1 ? 0.35 : 1)
                            .accessibilityLabel("Move \(tab.title) down")
                            .accessibilityHint("Reorders the tab bar")
                        }
                    }
                    .padding(.vertical, 6)
                }

                settingsDivider
                Button {
                    viewModel.resetTabOrder()
                } label: {
                    Text("Reset Order")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Restores the default tab arrangement")

                settingsDivider
                VStack(alignment: .leading, spacing: 8) {
                    Label("Advice & Privacy", systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)

                    Text("Advice is for informational purposes and not professional counseling.")
                        .font(.caption)
                        .foregroundStyle(primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        "Preferences and history are stored on-device and may sync with your iCloud account via CloudKit. The app does not use ad-tracking SDKs."
                    )
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .fill(cardColor.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)

                settingsDivider

                Button {
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id6742776285?action=write-review") {
                        openURL(url)
                    }
                } label: {
                    settingsNavRow("Rate Badvice", systemImage: "star", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    if let url = URL(string: "mailto:badvice.app@gmail.com?subject=Badvice%20Feedback") {
                        openURL(url)
                    }
                } label: {
                    settingsNavRow("Send Feedback", systemImage: "envelope", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                        openURL(url)
                    }
                } label: {
                    settingsNavRow("Privacy Policy", systemImage: "hand.raised", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                } label: {
                    settingsNavRow("Terms of Service", systemImage: "doc.text", badge: nil)
                }
                .buttonStyle(.plain)

                settingsDivider
                Text(Self.appVersion)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }

    private func loadNotificationPermissionStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationPermissionGranted =
            status == .authorized || status == .provisional || status == .ephemeral
    }

    // MARK: - Reusable rows

    @ViewBuilder
    private var settingsDivider: some View {
        Rectangle()
            .fill(secondaryText.opacity(0.12))
            .frame(height: 1)
    }

    private func settingsToggle(_ label: String, systemImage: String, isOn: Binding<Bool>)
        -> some View
    {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont(for: viewModel.theme))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.vertical, 4)
    }

    private func settingsMenuRow(_ label: String, systemImage: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyFont(for: viewModel.theme))
                    .foregroundStyle(primaryText)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private func settingsPicker<V: Hashable, Content: View>(
        _ label: String,
        systemImage: String,
        selection: Binding<V>,
        pickerAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            if let pickerAccessibilityIdentifier {
                Picker(label, selection: selection) {
                    content()
                }
                .pickerStyle(.menu)
                .tint(primaryText)
                .font(Theme.bodyFont(for: viewModel.theme))
                .accessibilityIdentifier(pickerAccessibilityIdentifier)
            } else {
                Picker(label, selection: selection) {
                    content()
                }
                .pickerStyle(.menu)
                .tint(primaryText)
                .font(Theme.bodyFont(for: viewModel.theme))
            }
        }
        .padding(.vertical, 4)
    }

    private func settingsNavRow(
        _ label: String,
        systemImage: String,
        badge: String?,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(label)
                .font(Theme.bodyFont(for: viewModel.theme))
                .foregroundStyle(primaryText)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: badge)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText.opacity(0.5))
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityIdentifier ?? settingsRowAccessibilityID(for: label))
    }

    private func settingsRowAccessibilityID(for label: String) -> String {
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: ".")
        return "settings.row.\(normalized)"
    }

    // MARK: - Card container

    private func settingsCard<Content: View>(
        title: String, icon: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(secondaryText)
                .textCase(.uppercase)
                .tracking(1.2)

            content()
                .padding(Theme.sectionSpacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [cardColor, cardColor.opacity(0.85), cardColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                                .fill(accent.opacity(0.06))
                                .frame(height: 1),
                            alignment: .top
                        )
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [accent.opacity(0.4), accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}
