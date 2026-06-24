import Foundation
import SwiftUI

struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onDataChanged: () -> Void
    var onOpenTab: ((AppTab) -> Void)? = nil
    var isActive: Bool = false
    var settingsPresented: Bool = false
    var quickAccessTabs: [AppTab] = []
    var onResetAllLocalAccounts: (() async -> ToastMessage)? = nil
    var onRefreshSocialAvailability: (() async -> ToastMessage)? = nil
    #if DEBUG
        var onReseedCloudKitSchema: (() async -> ToastMessage)? = nil
    #endif

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingAdvanced = false
    @State private var showingPromptAssist = false
    @State private var showingStudioExtras = false
    @State private var showingTuneNextRun = false
    @State private var showingBrandMenu = false
    @State private var pendingBrandMenuTab: AppTab? = nil
    @State private var showingBracket = false        // #2 Advice Battles entry point
    @State private var showingCollabAdvice = false   // #7 Collab Advice
    @State private var gifExportInProgress = false
    @State private var generateButtonPulsing = false
    @State private var activeToast: ToastMessage? = nil
    @State private var headerPulseScale: CGFloat = 1.0
    @State private var headerRotation: Double = 0
    @State private var headerOrbitOpacity: Double = 0
    @State private var unlockedSurpriseLine: String? = nil
    @State private var surpriseClearTask: Task<Void, Never>? = nil
    @State private var quoteTapStreak = 0
    @State private var quoteTapResetTask: Task<Void, Never>? = nil
    @State private var loadingCompletionHapticArmed = false
    @State private var lastGeneratedAdviceIDForHaptics: UUID? = nil
    @State private var lastKnownStreakDays: Int = 0
    @AppStorage(AppTab.generate.focusModeStorageKey) private var isFocusMode = false
    @AppStorage("hasDismissedWhatsNewCard_2026_02c") private var hasDismissedWhatsNewCard = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }
    private var isScreenshotMode: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-ui-testing") && arguments.contains("-screenshot-mode")
    }
    private var usesCompactScreenshotLayout: Bool {
        isScreenshotMode && UIScreen.main.bounds.height <= 700
    }

    // Hoist per-theme lookups so each is a single switch instead of many repeated calls per body
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var headerSubtitle: String {
        if viewModel.isGenerating {
            return "Generating now."
        }
        if viewModel.current == nil {
            return "Ready for the first run."
        }
        if viewModel.challengeStreakDays > 0 {
            return "\(viewModel.challengeStreakDays)-day streak active."
        }
        return "Generate, save, copy, share, or remix."
    }
    private var socialEntryPrompt: String {
        social.availability.isAccountAvailable
            ? "Finish your Friends profile in Friends, then return here to share posts and start collabs."
            : social.availability.message
    }
    private var headerReactiveScale: CGFloat {
        guard !isMotionReduced else { return 1.0 }
        let cadenceScale: CGFloat = viewModel.hapticTrigger % 2 == 0 ? 1.0 : 1.02
        return cadenceScale * headerPulseScale
    }

    private var headerIconName: String {
        switch settings.theme {
        case .badvice: return "sparkles"
        case .minimal: return "circle"
        case .ember: return "flame.fill"
        case .slate: return "hexagon.fill"
        case .evergreen: return "leaf.fill"
        case .fallout: return "radiation"
        case .neon: return "bolt.fill"
        case .midnight: return "moon.stars.fill"
        case .sunset: return "sun.horizon.fill"
        case .cosmic: return "sparkles"
        case .retro: return "waveform.path.ecg"
        case .cybernetic: return "cpu"
        }
    }

    private var headerBadgeGradient: LinearGradient {
        let secondary = Theme.secondaryAccent(for: settings.theme) ?? accent
        return LinearGradient(
            colors: [accent.opacity(0.9), secondary.opacity(0.7), accent.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerView: some View {
        return Button {
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            showingBrandMenu = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.95),
                                    accent.opacity(0.6),
                                    cardColor.opacity(0.9),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: headerIconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(buttonText)
                }
                .frame(width: 44, height: 44)
                .shadow(color: accent.opacity(0.18), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Advice Studio")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }

                Spacer(minLength: 0)

                if viewModel.challengeStreakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("\(viewModel.challengeStreakDays)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                    )
                    .accessibilityLabel("\(viewModel.challengeStreakDays) day streak")
                }

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryText.opacity(0.75))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(secondaryText.opacity(0.08))
                    )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(
            color: Theme.cardShadow(for: settings.theme).color.opacity(0.14),
            radius: Theme.cardShadow(for: settings.theme).radius * 0.55,
            x: 0,
            y: Theme.cardShadow(for: settings.theme).y * 0.35
        )
        .animation(
            isMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.6),
            value: viewModel.hapticTrigger
        )
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.9) {
            triggerHeaderLongPressSurprise()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Badvice")
        .accessibilityHint("Opens the Badvice menu")
        .accessibilityIdentifier("generate.brandMenu")
    }

    @ViewBuilder
    private var promptAssistSection: some View {
        DisclosureGroup(
            isExpanded: $showingPromptAssist.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                scenarioSuggestionsRow
                adaptiveHintCard
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prompt assist")
                        .font(.subheadline.weight(.semibold))
                    Text("Roasts, starter prompts, and guidance when you want help")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }
            .foregroundStyle(primaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var studioExtrasSection: some View {
        DisclosureGroup(
            isExpanded: $showingStudioExtras.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                dailyQuoteBanner
                weeklyRecapSection
                if !hasDismissedWhatsNewCard {
                    whatsNewCard
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio extras")
                        .font(.subheadline.weight(.semibold))
                    Text("Daily quote, weekly recap, and release notes")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }
            .foregroundStyle(primaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
    }

    @ToolbarContentBuilder
    private var focusModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            TabFocusModeToggle(
                isEnabled: isFocusMode,
                accent: accent
            ) {
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocusMode.toggle()
                }
            }
        }
    }

    private var generateToolsSection: some View {
        DisclosureGroup(
            isExpanded: $showingAdvanced.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.selectedTone == .friendRoast {
                    friendRoastComposer
                }
                promptAssistSection
                studioActionButtons
                if viewModel.current != nil {
                    shareExtrasSection
                }
                if viewModel.current != nil || viewModel.todayGeneratedCount > 0 {
                    statStrip
                    challengeCard
                }
                if viewModel.current != nil {
                    whyThisFailsCard
                }
                studioExtrasSection
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("More tools")
                        .font(.subheadline.weight(.semibold))
                    Text("Prompt assist, missions, sharing extras, and labs")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }
            .foregroundStyle(primaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private var studioActionButtons: some View {
        HStack(spacing: 10) {
            Button { showingBracket = true } label: {
                Label("Battles", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .tint(accent)

            Button { showingCollabAdvice = true } label: {
                Label("Collab", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
    }

    private var shareExtrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share extras")
                .font(.caption.weight(.bold))
                .foregroundStyle(secondaryText)

            HStack(spacing: 10) {
                Button {
                    guard let record = viewModel.current else { return }
                    guard canShareToFriends() else {
                        showFriendsUnavailable()
                        return
                    }
                    Task {
                        await social.shareAdviceToFriends(text: record.adviceLine)
                        if let message = social.statusMessage {
                            activeToast = ToastMessage(
                                message: message,
                                style: message.lowercased().contains("shared") ? .success : .error
                            )
                        }
                    }
                } label: {
                    Label("Friends", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("generate.shareToFriends")

                Button {
                    exportCurrentAdviceGIF()
                } label: {
                    Label(gifExportInProgress ? "Exporting..." : "GIF", systemImage: "square.and.arrow.up.on.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .disabled(gifExportInProgress)
                .accessibilityIdentifier("generate.gif")
            }

            if !social.availability.isAvailable {
                Text(social.availability.message)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if social.currentUser == nil {
                Text("Friends is optional. Set it up when you want shared drafts and collabs.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        Color.clear
                            .frame(height: 0)
                            .id("generate.top")

                        if let unlockedSurpriseLine {
                            surpriseBanner(unlockedSurpriseLine)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if !usesCompactScreenshotLayout {
                            headerView
                        }
                        generationCommandCard
                        if !isFocusMode && (viewModel.current != nil || viewModel.todayGeneratedCount > 0) {
                            dailyProgressCard
                        }
                        if !isFocusMode,
                           let notice = viewModel.generationNotice,
                           !notice.isEmpty
                        {
                            Text(notice)
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }
                        if !isFocusMode {
                            generateToolsSection
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .coordinateSpace(name: "scroll")
                .trackScrollForTabBar()
                .toolbar { focusModeToolbar }
                .safeAreaPadding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
                .refreshable {
                    // Pull to generate new advice
                    await viewModel.generate()
                    onDataChanged()
                }
                .toast(item: $activeToast, accentColor: accent)
                .onAppear {
                    Task { @MainActor in
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                }
                .onChange(of: isActive) { _, active in
                    guard active else { return }
                    Task { @MainActor in
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                }
                .onChange(of: settingsPresented) { _, _ in
                    Task { @MainActor in
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                }
            }

            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-debug-preload-polish-fixtures"),
                    viewModel.debugPolishFixturesStatus != "idle"
                {
                    Text(viewModel.debugPolishFixturesStatus)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.25))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("debug.polishFixtures.status")
                        .padding(.top, 8)
                        .padding(.leading, 12)
                }
            #endif
        }
        .overlay {
            if gifExportInProgress {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Exporting GIF…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
                .transition(.opacity)
                .animation(
                    isMotionReduced ? nil : .easeInOut(duration: 0.2), value: gifExportInProgress)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingBrandMenu, onDismiss: {
            handleBrandMenuDismiss()
        }) {
            #if DEBUG
                GenerateBrandMenuView(
                    social: social,
                    settings: settings,
                    quickAccessTabs: quickAccessTabs,
                    isPresented: $showingBrandMenu,
                    activeToast: $activeToast,
                    onSelectQuickAccessTab: { pendingBrandMenuTab = $0 },
                    onResetAllLocalAccounts: onResetAllLocalAccounts,
                    onRefreshSocialAvailability: onRefreshSocialAvailability,
                    onReseedCloudKitSchema: onReseedCloudKitSchema
                )
            #else
                GenerateBrandMenuView(
                    social: social,
                    settings: settings,
                    quickAccessTabs: quickAccessTabs,
                    isPresented: $showingBrandMenu,
                    activeToast: $activeToast,
                    onSelectQuickAccessTab: { pendingBrandMenuTab = $0 },
                    onResetAllLocalAccounts: onResetAllLocalAccounts,
                    onRefreshSocialAvailability: onRefreshSocialAvailability
                )
            #endif
        }
        // #2 Advice Battles
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: viewModel)
        }
        // #7 Collab Advice
        .sheet(isPresented: $showingCollabAdvice) {
            CollabAdviceView(settings: settings, generateViewModel: viewModel, social: social)
        }
        .onAppear {
            AppPerformanceInstrumentation.markAdviceTabFirstRenderIfNeeded()
            lastGeneratedAdviceIDForHaptics = viewModel.current?.id
            lastKnownStreakDays = viewModel.challengeStreakDays
            tabBarVisible.wrappedValue = true

            if viewModel.current == nil {
                viewModel.bootstrapAdviceExperienceIfNeeded(
                    autoGenerateInitialAdvice:
                        !ProcessInfo.processInfo.arguments.contains("-ui-testing")
                        && !ProcessInfo.processInfo.arguments.contains("-debug-preload-polish-fixtures")
                )
            }
        }
        .onChange(of: viewModel.isGenerating) { _, isGenerating in
            handleGeneratingStateChange(isGenerating)
        }
        .onChange(of: viewModel.challengeStreakDays) { oldValue, newValue in
            guard lastKnownStreakDays > 0 else {
                lastKnownStreakDays = newValue
                return
            }
            if newValue == 0 && oldValue > 0 {
                HapticsManager.play(style: .medium, isEnabled: settings.hapticsEnabled)
                activeToast = ToastMessage(
                    message: "Streak ended at \(oldValue) \(oldValue == 1 ? "day" : "days"). Start a new one!",
                    style: .error
                )
            }
            lastKnownStreakDays = newValue
        }
    }

    private var dailyQuoteBanner: some View {
        let quote = viewModel.dailyBadQuote
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Daily line", systemImage: "quote.bubble")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Spacer(minLength: 0)
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
            }

            Text("“\(quote.text)”")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(quote.source)")
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bad quote of the day: \(quote.text)")
        .contentShape(Rectangle())
        .onTapGesture {
            triggerQuoteTapEasterEgg()
        }
    }

    private var generationCommandCard: some View {
        SectionShell(accent: accent, cardColor: cardColor) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.shellBannerCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.95),
                                    (Theme.secondaryAccent(for: settings.theme) ?? accent).opacity(0.62),
                                    cardColor.opacity(0.88),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(buttonText)
                }
                .frame(width: 52, height: 52)
                .shadow(color: accent.opacity(0.22), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(commandCardTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(commandCardSubtitle)
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                generationHeroMetrics
                if viewModel.current == nil || viewModel.isGenerating {
                    if !usesCompactScreenshotLayout {
                        selectorRow
                    }
                    scenarioComposerFields
                    primaryActionButtons
                    unifiedAdviceStage
                } else {
                    unifiedAdviceStage
                    primaryActionButtons
                    tuneNextRunDisclosure
                }
            }
        }
        .shadow(
            color: Theme.cardShadow(for: settings.theme).color.opacity(0.16),
            radius: Theme.cardShadow(for: settings.theme).radius * 0.55,
            x: 0,
            y: Theme.cardShadow(for: settings.theme).y * 0.35
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.commandCard")
    }

    private var tuneNextRunDisclosure: some View {
        DisclosureGroup(
            isExpanded: $showingTuneNextRun.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if !usesCompactScreenshotLayout {
                    selectorRow
                }
                scenarioComposerFields
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tune next run")
                        .font(.caption.weight(.bold))
                    Text("Adjust lane, tone, or detail after this result.")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(primaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(secondaryText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityIdentifier("generate.tuneNextRun")
    }

    @ViewBuilder
    private var unifiedAdviceStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.current != nil {
                resultNextStepCard
                    .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .top)))
            }

            ZStack {
                if let record = viewModel.current {
                    AdviceCardView(
                        record: record,
                        theme: settings.theme,
                        reduceMotion: isMotionReduced,
                        sourceBadgeText: viewModel.generationSourceBadgeText
                    )
                    .accessibilityIdentifier("advice.card")
                    .transition(
                        isMotionReduced
                            ? .identity
                            : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity)
                    )
                    .scaleEffect(generateButtonPulsing ? 0.98 : 1.0)
                    .animation(
                        isMotionReduced ? nil : .spring(response: 0.2, dampingFraction: 0.5),
                        value: viewModel.hapticTrigger
                    )
                    .contextMenu {
                        Button(
                            "Save",
                            systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark"
                        ) {
                            toggleCurrentFavorite()
                        }

                        Button("Copy", systemImage: "doc.on.doc") {
                            copyCurrentAdvice()
                        }

                        Button("Share", systemImage: "square.and.arrow.up") {
                            shareCurrentAdvice()
                        }

                        Button("Collaborate", systemImage: "person.2.badge.plus") {
                            guard canShareToFriends() else {
                                showFriendsUnavailable()
                                return
                            }
                            social.queueCollabDraft(type: .advice, content: record.adviceLine)
                            openTab(.friends)
                            activeToast = ToastMessage(
                                message: "Draft sent to Friends > Collab.",
                                style: .info
                            )
                        }
                    }
                    .onTapGesture(count: 2) {
                        toggleCurrentFavorite()
                    }
                } else {
                    emptyState
                        .transition(isMotionReduced ? .identity : .opacity)
                }

                if viewModel.isGenerating {
                    LoadingAdviceView(theme: settings.theme, reduceMotion: isMotionReduced)
                        .transition(isMotionReduced ? .identity : .opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(
                isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.86),
                value: viewModel.current?.id
            )
            .animation(
                isMotionReduced ? nil : .easeInOut(duration: 0.2),
                value: viewModel.isGenerating
            )

            votingRow
        }
        .padding(.top, 2)
    }

    private var commandCardTitle: String {
        if viewModel.isGenerating { return "Writing the bad idea" }
        if viewModel.current == nil { return "Build one bad idea" }
        if viewModel.isCurrentFavorite { return "Saved. Now send it." }
        return "Tune the next take"
    }

    private var commandCardSubtitle: String {
        if viewModel.isGenerating {
            return "Category, tone, and your one detail are locked in for this run."
        }
        if viewModel.current == nil {
            return "Choose a lane, set the voice, add one detail, then generate."
        }
        if viewModel.isCurrentFavorite {
            return "Share the keeper or remix only when the tone needs a sharper edge."
        }
        return "Save the line if it works, or adjust the prompt before the next run."
    }

    private var generationHeroMetrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            generationHeroChip(
                title: "Lane",
                value: viewModel.selectedCategory.title,
                systemImage: "square.grid.2x2"
            )
            generationHeroChip(
                title: "Tone",
                value: viewModel.selectedTone.title,
                systemImage: "message.fill"
            )
        }
    }

    private func generationHeroChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(accent.opacity(0.07))
        )
    }

    private var dailyProgressCard: some View {
        HStack(spacing: 10) {
            progressStep(
                title: "Generate",
                systemImage: viewModel.current == nil ? "sparkles" : "checkmark.circle.fill",
                isComplete: viewModel.current != nil
            )
            progressStep(
                title: "Save",
                systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                isComplete: viewModel.isCurrentFavorite
            )
            progressStep(
                title: "Share",
                systemImage: "square.and.arrow.up",
                isComplete: viewModel.todayGeneratedCount > 0
            )
            progressStep(
                title: "Return",
                systemImage: viewModel.challengeStreakDays > 0 ? "flame.fill" : "calendar",
                isComplete: viewModel.challengeStreakDays > 0
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily progress")
    }

    private var resultNextStepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: resultNextStepIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(resultNextStepTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                        .accessibilityIdentifier("generate.resultNextStep.title")
                    Text(resultNextStepDetail)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                compactResultButton(
                    title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                    systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                    accessibilityID: "generate.resultNextStep.save"
                ) {
                    toggleCurrentFavorite()
                }
                compactResultButton(
                    title: "Share",
                    systemImage: "square.and.arrow.up",
                    accessibilityID: "generate.resultNextStep.share"
                ) {
                    shareCurrentAdvice()
                }
                compactResultButton(
                    title: "Remix",
                    systemImage: "bolt.fill",
                    accessibilityID: "generate.resultNextStep.remix"
                ) {
                    remixCurrentAdvice()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityIdentifier("generate.resultNextStep")
    }

    private var resultNextStepIcon: String {
        if !viewModel.isCurrentFavorite { return "bookmark" }
        if canShareToFriends() { return "person.2.fill" }
        if viewModel.todayGeneratedCount <= 1 { return "square.and.arrow.up" }
        return "bolt.fill"
    }

    private var resultNextStepTitle: String {
        if !viewModel.isCurrentFavorite { return "Keep the keeper" }
        if canShareToFriends() { return "Ready for Friends" }
        if viewModel.todayGeneratedCount <= 1 { return "Send it or remix it" }
        return "Tune the punchline"
    }

    private var resultNextStepDetail: String {
        if !viewModel.isCurrentFavorite {
            return "Save the useful line first so it lands in Favorites and your weekly recap."
        }
        if canShareToFriends() {
            return "Share it to Friends when you want reactions, or start a collab from the extras below."
        }
        if viewModel.todayGeneratedCount <= 1 {
            return "Share the first hit, then remix only if the tone needs a sharper edge."
        }
        return "You have a few runs today. Remix selectively so the result still feels intentional."
    }

    private func compactResultButton(
        title: String,
        systemImage: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        TabCommandActionButton(
            title: title,
            systemImage: systemImage,
            accent: accent,
            buttonText: buttonText,
            prominent: false,
            isDisabled: viewModel.isGenerating,
            minHeight: 36
        ) {
            action()
        }
        .accessibilityIdentifier(accessibilityID)
    }

    private func progressStep(title: String, systemImage: String, isComplete: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(isComplete ? accent : secondaryText)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isComplete ? accent.opacity(0.14) : secondaryText.opacity(0.08))
                )
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isComplete ? primaryText : secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Prompt controls", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 0)
                Text("Keep it tight.")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                categorySelector
                toneSelector
            }
        }
    }

    private var categorySelector: some View {
        chipSelector(
            title: "Category",
            accessibilityPrefix: "generate.category",
            selectedSummary: viewModel.selectedCategory.title
        ) {
            ForEach(Array(AdviceCategory.allCases.enumerated()), id: \.element.id) { index, category in
                selectorChip(
                    label: category.title,
                    icon: category.icon,
                    isPremium: category.isPremium,
                    isSelected: viewModel.selectedCategory == category,
                    accessibilityID: "generate.category.chip.\(index)"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    viewModel.updateCategory(category)
                }
            }
        }
    }

    private var toneSelector: some View {
        chipSelector(
            title: "Tone",
            accessibilityPrefix: "generate.tone",
            selectedSummary: viewModel.selectedTone.title
        ) {
            ForEach(Array(ToneMode.allCases.enumerated()), id: \.element.id) { index, tone in
                selectorChip(
                    label: tone.title,
                    icon: tone.isPremium ? "sparkles" : nil,
                    isPremium: tone.isPremium,
                    isSelected: viewModel.selectedTone == tone,
                    accessibilityID: "generate.tone.chip.\(index)"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    viewModel.updateTone(tone)
                }
            }
        }
    }

    private func chipSelector<Content: View>(
        title: String,
        accessibilityPrefix: String,
        selectedSummary: String,
        @ViewBuilder chips: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 0)
                Text(selectedSummary)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
            }
            .accessibilityIdentifier(accessibilityPrefix)

            if isScreenshotMode {
                HStack {
                    selectedScreenshotChip(selectedSummary)
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chips()
                    }
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func selectedScreenshotChip(_ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(buttonText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.2))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func selectorChip(
        label: String,
        icon: String?,
        isPremium: Bool,
        isSelected: Bool,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? buttonText : accent.opacity(0.85))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? accent.opacity(0.18) : secondaryText.opacity(0.12))
            )
            .foregroundStyle(isSelected ? buttonText : primaryText)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(
                isMotionReduced ? nil : .spring(response: 0.24, dampingFraction: 0.72),
                value: isSelected
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected
                            ? accent.opacity(0.35)
                            : secondaryText.opacity(0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private var scenarioComposerFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Situation", systemImage: "text.alignleft")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 0)
                if !viewModel.scenarioText.isEmpty {
                    TabCommandActionButton(
                        title: "Clear",
                        systemImage: "xmark.circle.fill",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        minHeight: 30
                    ) {
                        viewModel.scenarioText = ""
                    }
                    .transition(
                        isMotionReduced ? .identity : .opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(
                isMotionReduced ? nil : .easeInOut(duration: Theme.animFast),
                value: viewModel.scenarioText.isEmpty)

            Text("One real detail is enough. Keep it short and let the generator do the rest.")
                .font(.caption)
                .foregroundStyle(secondaryText)

            TextField("Example: awkward first date", text: $viewModel.scenarioText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont(for: settings.theme))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius + 2, style: .continuous)
                        .fill(cardColor)
                )
                .foregroundStyle(primaryText)
        }
    }

    @ViewBuilder
    private var scenarioSuggestionsRow: some View {
        let suggestions = viewModel.keywordSuggestions
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Smart prompts", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    TabCommandActionButton(
                        title: "Shuffle",
                        systemImage: "shuffle",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        minHeight: 30
                    ) {
                        if let pick = suggestions.randomElement() {
                            applyScenarioSuggestion(pick)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            TabCommandActionButton(
                                title: suggestion,
                                systemImage: "sparkles",
                                accent: accent,
                                buttonText: buttonText,
                                prominent: false,
                                minHeight: 30
                            ) {
                                applyScenarioSuggestion(suggestion)
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adaptiveHintCard: some View {
        if viewModel.selectedCategory == .random || viewModel.selectedTone == .random {
            SectionShell(accent: accent, cardColor: cardColor) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("Adaptive mix")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(accent)
            } content: {
                Text("We’ll use your recent likes to steer tone and category while keeping the result fresh.")
                    .font(.footnote)
                    .foregroundStyle(primaryText)
            }
        }
    }

    private func applyScenarioSuggestion(_ suggestion: String) {
        let trimmed = viewModel.scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            viewModel.scenarioText = suggestion
            return
        }
        if trimmed.localizedCaseInsensitiveContains(suggestion) {
            return
        }
        let separator = trimmed.hasSuffix(".") ? " " : ", "
        viewModel.scenarioText = trimmed + separator + suggestion
    }

    @ViewBuilder
    private var friendRoastComposer: some View {
        if viewModel.selectedTone == .friendRoast {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("Friend name", systemImage: "person.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                    Spacer(minLength: 0)
                    Text("Roast mode")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                }
                Text("Keep it short. This is just for the punchline.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)

                TextField("Example: Alex", text: $viewModel.friendName)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyFont(for: settings.theme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius + 2, style: .continuous)
                            .fill(cardColor)
                    )
                    .foregroundStyle(primaryText)
                    .accessibilityIdentifier("generate.friendName")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.challengeTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText)
            Text(viewModel.challengeProgressText)
                .font(.footnote)
                .foregroundStyle(secondaryText)

            GeometryReader { geometry in
                let denominator = max(viewModel.challengeGoalDays, 1)
                let progress = min(CGFloat(viewModel.challengeStreakDays) / CGFloat(denominator), 1)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(secondaryText.opacity(0.18))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(accent)
                            .frame(width: geometry.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
    }

    private var whyThisFailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this is terrible")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                    Text("The joke lands better when the bad logic is obvious.")
                        .font(.caption2)
                        .foregroundStyle(secondaryText.opacity(0.82))
                }
            }
            Text(viewModel.lastWhyTerrible)
                .font(.footnote.weight(.medium))
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var primaryActionButtons: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    primaryActionButtonsContent
                }
            } else {
                primaryActionButtonsContent
            }
        }
    }

    private var primaryActionButtonsContent: some View {
        let hasCurrent = viewModel.current != nil
        return VStack(spacing: 10) {
            // Primary generate button — pulses when idle (no advice yet)
            Button {
                generateButtonPulsing = false
                Task {
                    await viewModel.generate()
                    onDataChanged()
                }
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: "sparkles")
                    .font(Theme.bodyFont(for: settings.theme).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            }
            .adaptiveGlassButtonStyle(prominent: true)
            .accessibilityIdentifier("generate.primary")
            .accessibilityHint("Generates a new advice card using the selected category and tone")
            .tint(accent)
            .foregroundStyle(buttonText)
            .disabled(viewModel.isGenerating)
            .scaleEffect(generateButtonPulsing && !isMotionReduced ? 1.03 : 1.0)
            .animation(
                isMotionReduced
                    ? .easeOut(duration: 0.2)
                    : (
                        generateButtonPulsing
                            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.2)
                    ),
                value: generateButtonPulsing
            )
            .onAppear {
                if viewModel.current == nil && !isMotionReduced {
                    generateButtonPulsing = true
                } else {
                    generateButtonPulsing = false
                }
            }
            .onChange(of: viewModel.current == nil) { _, isNil in
                generateButtonPulsing = isNil && !isMotionReduced
            }
            .onChange(of: isMotionReduced) { _, reduced in
                if reduced {
                    generateButtonPulsing = false
                } else if viewModel.current == nil {
                    generateButtonPulsing = true
                }
            }

            // Quick-fire secondary row — always visible
            HStack(spacing: 10) {
                Button {
                    viewModel.surpriseMeAndGenerate()
                    onDataChanged()
                } label: {
                    Label("Surprise Me", systemImage: "dice")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .adaptiveGlassButtonStyle()
                .accessibilityIdentifier("generate.surprise")
                .accessibilityHint("Randomizes category and tone, then generates advice")
                .disabled(viewModel.isGenerating)

                Button {
                    viewModel.generateDailyDrop()
                    onDataChanged()
                } label: {
                    Label("Daily Drop", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .adaptiveGlassButtonStyle()
                .accessibilityIdentifier("generate.dailyDrop")
                .accessibilityHint("Generates the Daily Drop advice")
                .disabled(viewModel.isGenerating)
            }
            .tint(accent)

            // #10 Category/tone compatibility warning
            let compatLabel = CategoryToneCompatibility.compatibilityLabel(
                category: viewModel.selectedCategory,
                tone: viewModel.selectedTone
            )
            if let label = compatLabel {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }

            if hasCurrent {
                let railColumns = [
                    GridItem(.adaptive(minimum: 64, maximum: 96), spacing: 10, alignment: .top)
                ]
                HStack(spacing: 8) {
                    Label("Keep or send it", systemImage: "square.and.arrow.up.on.square")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                    Spacer(minLength: 0)
                    Text(viewModel.isCurrentFavorite ? "Saved" : "Ready")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(viewModel.isCurrentFavorite ? accent : secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill((viewModel.isCurrentFavorite ? accent : secondaryText).opacity(0.12))
                        )
                }
                .accessibilityIdentifier("generate.actionRailHeader")

                // Save / Copy / Share rail
                LazyVGrid(columns: railColumns, spacing: 10) {
                    actionRailButton(
                        title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                        systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                        isEnabled: !viewModel.isGenerating
                    ) {
                        toggleCurrentFavorite()
                    }
                    .accessibilityIdentifier("generate.save")

                    actionRailButton(
                        title: "Copy",
                        systemImage: "doc.on.doc",
                        isEnabled: !viewModel.isGenerating
                    ) {
                        copyCurrentAdvice()
                    }
                    .accessibilityIdentifier("generate.copy")

                    actionRailButton(
                        title: "Share",
                        systemImage: "square.and.arrow.up",
                        isEnabled: !viewModel.isGenerating
                    ) {
                        shareCurrentAdvice()
                    }
                    .accessibilityIdentifier("generate.share")

                    actionRailButton(
                        title: "Remix",
                        systemImage: "bolt.fill",
                        isEnabled: !viewModel.isGenerating
                    ) {
                        remixCurrentAdvice()
                    }
                    .accessibilityIdentifier("generate.remix")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .tint(accent)
        .foregroundStyle(primaryText)
    }

    private var whatsNewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("What's New", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button {
                    hasDismissedWhatsNewCard = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss what's new")
                .accessibilityIdentifier("generate.whatsNew.dismiss")
            }

            Text(
                "New: Missions combines daily progress, community pulse, and your wins. ML Remix now sharpens tone and category variety."
            )
            .font(.footnote)
            .foregroundStyle(secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: "Got it",
                    systemImage: nil,
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    minHeight: 36
                ) {
                    hasDismissedWhatsNewCard = true
                }
                .accessibilityIdentifier("generate.whatsNew.gotIt")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.whatsNew.card")
    }

    // MARK: - Weekly Recap

    @ViewBuilder
    private var weeklyRecapSection: some View {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isSaturday = weekday == 7
        let recapItems = viewModel.weeklyRecapFavorites
        if isSaturday && !recapItems.isEmpty {
            SectionShell(accent: accent, cardColor: cardColor) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Worst of My Week")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text("🔁")
                }
            } content: {
                ForEach(Array(recapItems.enumerated()), id: \.offset) { idx, record in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(secondaryText)
                        Text(record.adviceLine)
                            .font(.caption)
                            .lineLimit(3)
                            .foregroundStyle(primaryText)
                    }
                }
                TabCommandActionButton(
                    title: "Share Recap",
                    systemImage: "square.and.arrow.up",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "generate.shareRecap"
                ) {
                    let lines = recapItems.enumerated().map {
                        "\($0.offset + 1). \($0.element.adviceLine)"
                    }.joined(separator: "\n")
                    let shareText = "My Worst Advice of the Week 🏆\n\n\(lines)\n\n— via Badvice"
                    shareItems = [shareText]
                    showingShareSheet = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
            }
        }
    }

    private func openTab(_ tab: AppTab) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab?(tab)
    }

    private func handleBrandMenuDismiss() {
        guard let tab = pendingBrandMenuTab else { return }
        pendingBrandMenuTab = nil
        DispatchQueue.main.async {
            onOpenTab?(tab)
        }
    }

    private func showFriendsUnavailable() {
        activeToast = ToastMessage(message: socialEntryPrompt, style: .info)
    }

    private func shareCurrentAdvice() {
        guard let payload = viewModel.currentSharePayload else { return }
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Task {
            let image = await ShareCardRenderer.renderAsync(content: payload)
            shareItems = [image, viewModel.currentShareText]
            viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
            showingShareSheet = true
            activeToast = ToastMessage(message: "Share card ready.", style: .success)
        }
    }

    private func toggleCurrentFavorite() {
        let wasFavorite = viewModel.isCurrentFavorite
        viewModel.toggleFavorite()
        onDataChanged()
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(
            message: wasFavorite ? "Removed from Favorites" : "Saved!",
            style: wasFavorite ? .deleted : .success
        )
    }

    private func copyCurrentAdvice() {
        UIPasteboard.general.string = viewModel.currentShareText
        viewModel.trackCopy()
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: "Copied!", style: .success)
    }

    private func remixCurrentAdvice() {
        viewModel.remixCurrentAdvice()
        activeToast = ToastMessage(message: "Remixed!", style: .success)
    }

    private func exportCurrentAdviceGIF() {
        guard let record = viewModel.current else { return }
        gifExportInProgress = true
        Task {
            let config = AnimatedShareExporter.Config(
                advice: record.adviceLine,
                category: record.category,
                tone: record.tone,
                theme: settings.theme
            )
            if let data = await AnimatedShareExporter.exportGIF(config: config) {
                AnimatedShareExporter.shareGIF(data)
                activeToast = ToastMessage(message: "GIF ready.", style: .success)
            } else {
                activeToast = ToastMessage(message: "GIF export is unavailable right now.", style: .error)
            }
            gifExportInProgress = false
        }
    }

    private func canShareToFriends() -> Bool {
        guard social.availability.isAvailable else { return false }
        guard social.currentUser != nil else { return false }
        return true
    }

    private func handleGeneratingStateChange(_ isGenerating: Bool) {
        if isGenerating {
            loadingCompletionHapticArmed = true
            HapticsManager.play(style: .light, isEnabled: settings.hapticsEnabled)
            return
        }

        guard loadingCompletionHapticArmed else { return }
        loadingCompletionHapticArmed = false

        guard let currentID = viewModel.current?.id, currentID != lastGeneratedAdviceIDForHaptics else {
            return
        }

        lastGeneratedAdviceIDForHaptics = currentID
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        SoundFeedback.playGenerate(isEnabled: settings.soundEffectsEnabled)
    }

    private func triggerHeaderLongPressSurprise() {
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let longPressToasts = [
            "Hidden mode: Roast Protocol armed.",
            "Long press detected. Friend Roast mode: activated.",
            "Patience unlocked the roast. Someone's about to have a day.",
        ]
        if let msg = longPressToasts.randomElement() {
            activeToast = ToastMessage(message: msg, style: .info)
        }
        revealSurprise("Long-press unlock: Friend Roast tone primed for your next run.")
        viewModel.updateTone(.friendRoast, autoGenerate: false)
    }

    private func triggerQuoteTapEasterEgg() {
        quoteTapStreak += 1
        quoteTapResetTask?.cancel()
        quoteTapResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            quoteTapStreak = 0
        }

        guard quoteTapStreak >= 4 else { return }
        quoteTapStreak = 0

        let mutatedQuotePool = [
            "Ask not what your calendar can do for you; ask what it can postpone.",
            "I think, therefore I overcommit.",
            "Float like a butterfly, invoice like a consultant.",
            "The only thing we have to fear is a meeting without snacks.",
            "To be yourself in a world of opinions, ship before feedback arrives.",
            "The journey of a thousand miles starts with opening five tabs.",
            "Be the change you wish to expense-report.",
            "With great power comes great ambiguity in the chain of command.",
            "Live, laugh, loop back after the standup.",
            "Work smarter, not harder, and definitely not at 9 a.m.",
            "Two roads diverged in a wood, and I took the one with fewer stakeholders.",
            "To infinity and beyond the scope of this quarter.",
            "It is what it is, but have you considered rebranding it?",
            "That which does not kill my deadline makes my Gantt chart stronger.",
            "You miss 100% of the shots you don't put in the roadmap.",
            "The best time to set realistic expectations was last sprint. The second best time is now.",
            "Speak softly and carry a well-formatted slide deck.",
            "We are all just one pivot away from a TED Talk.",
        ]
        let unlocked = mutatedQuotePool.randomElement() ?? mutatedQuotePool.first ?? "Be the change you wish to expense-report."
        UIPasteboard.general.string = unlocked
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let quoteCopyToasts = [
            "Secret quote copied.",
            "Hidden wisdom extracted and clipped.",
            "Contraband quote secured to clipboard.",
            "Rare drop obtained. No one will believe you found it.",
        ]
        if let msg = quoteCopyToasts.randomElement() {
            activeToast = ToastMessage(message: msg, style: .success)
        }
        revealSurprise("Hidden quote: \"\(unlocked)\"")
    }

    private func revealSurprise(_ message: String) {
        withAnimation(
            isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8)
        ) {
            unlockedSurpriseLine = message
        }
        surpriseClearTask?.cancel()
        surpriseClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Theme.animFast)) {
                unlockedSurpriseLine = nil
            }
        }
    }

    private func surpriseBanner(_ line: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(line)
                .font(.footnote.weight(.medium))
                .foregroundStyle(primaryText)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func actionRailButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        TabCommandActionButton(
            title: title,
            systemImage: systemImage,
            accent: accent,
            buttonText: buttonText,
            isDisabled: !isEnabled,
            minHeight: 66
        ) {
            action()
        }
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var votingRow: some View {
        if viewModel.current != nil {
            HStack(spacing: 12) {
                Text("Rate this advice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(secondaryText)

                Spacer()

                TabCommandActionButton(
                    title: viewModel.currentVote == .like ? "Liked" : "Like",
                    systemImage: viewModel.currentVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: viewModel.currentVote == .like,
                    minHeight: 36
                ) {
                    viewModel.toggleVote(.like)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
                .animation(
                    isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7),
                    value: viewModel.currentVote)

                TabCommandActionButton(
                    title: viewModel.currentVote == .dislike ? "Noted" : "Dislike",
                    systemImage: viewModel.currentVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: viewModel.currentVote == .dislike,
                    minHeight: 36
                ) {
                    viewModel.toggleVote(.dislike)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
                .animation(
                    isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7),
                    value: viewModel.currentVote)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardColor)
            )
        }
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            statChip(title: "Today", value: "\(viewModel.todayGeneratedCount)")
            statChip(title: "Total", value: "\(viewModel.totalGeneratedCount)")
            statChip(title: "Saved", value: "\(viewModel.favoriteCount)")
        }
    }

    private var keywordSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.keywordSuggestions, id: \.self) { suggestion in
                    TabCommandActionButton(
                        title: suggestion,
                        systemImage: "sparkle",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        minHeight: 32
                    ) {
                        viewModel.applySuggestion(suggestion)
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        TabEmptyStatePanel(
            icon: "sparkles",
            title: "Start with one bad idea.",
            message: "Pick a category and tone, add one optional detail, then generate, save, copy, share, or remix.",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor,
            reduceMotion: isMotionReduced
        ) {
            HStack(spacing: 8) {
                emptyStateStep("1", "Pick")
                emptyStateStep("2", "Generate")
                emptyStateStep("3", "Save")
                emptyStateStep("4", "Share")
            }
            .padding(.horizontal, 8)
        }
        .accessibilityIdentifier("generate.emptyState")
    }

    private func emptyStateStep(_ number: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(buttonText)
                .frame(width: 22, height: 22)
                .background(Circle().fill(accent))
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Advice View

private struct LoadingAdviceView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    private var accessibilityReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    private var effectiveReduceMotion: Bool {
        reduceMotion || accessibilityReduceMotionEnabled
    }
    private var accentColor: Color { Theme.accent(for: theme) }
    private var cardColor: Color { Theme.cardColor(for: theme) }
    private var primaryTextColor: Color { Theme.primaryText(for: theme) }
    private var secondaryTextColor: Color { Theme.secondaryText(for: theme) }

    @State private var ringRotation: Double = 0
    @State private var ringPulse = false
    @State private var messageTick = 0
    @State private var messageRotationTask: Task<Void, Never>?
    @State private var progressTask: Task<Void, Never>?
    @State private var loadingProgress: Double = 0.04

    var body: some View {
        let currentMessage = GenerationLoadingMessages.message(forTick: messageTick)
        let phaseTitle = GenerationLoadingMessages.phaseTitle(forTick: messageTick)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor.opacity(0.98))
                .overlay {
                    LinearGradient(
                        colors: [accentColor.opacity(0.08), .clear, .black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                }

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.18), lineWidth: 4)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0.12, to: 0.82)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.9), accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(effectiveReduceMotion ? 0 : ringRotation))
                        .animation(
                            effectiveReduceMotion
                                ? nil
                                : .linear(duration: 0.85).repeatForever(autoreverses: false),
                            value: ringRotation
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .scaleEffect(ringPulse ? 1.0 : 0.92)
                    .animation(
                        effectiveReduceMotion
                                ? nil
                                : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: ringPulse
                    )
                }

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(accentColor)
                    .padding(.bottom, 2)

                Text(phaseTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryTextColor.opacity(0.88))

                Text(currentMessage)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.2), value: messageTick)

                ProgressView(value: loadingProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .scaleEffect(y: 0.7)
                    .padding(.top, -2)
                    .padding(.horizontal, 16)

                Text("Generating advice")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(secondaryTextColor.opacity(0.8))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generating advice")
        .accessibilityIdentifier("generate.loading")
        .accessibilityValue(currentMessage)
        .onAppear {
            ringPulse = true
            messageTick = 0
            loadingProgress = 0.08
            guard !effectiveReduceMotion else { return }
            ringRotation = 360
            messageRotationTask?.cancel()
            messageRotationTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.1))
                    await MainActor.run {
                        messageTick += 1
                    }
                }
            }
            progressTask?.cancel()
            progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(700))
                    await MainActor.run {
                        loadingProgress = min(loadingProgress + 0.018, 0.98)
                    }
                }
            }
        }
        .onDisappear {
            messageRotationTask?.cancel()
            messageRotationTask = nil
            progressTask?.cancel()
            progressTask = nil
            ringRotation = 0
            ringPulse = false
        }
        .onChange(of: effectiveReduceMotion) { _, reduced in
            if reduced {
                messageRotationTask?.cancel()
                messageRotationTask = nil
                progressTask?.cancel()
                progressTask = nil
                loadingProgress = 0.25
            } else {
                messageTick = 0
                messageRotationTask?.cancel()
                messageRotationTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1.1))
                        await MainActor.run {
                            messageTick += 1
                        }
                    }
                }
                loadingProgress = 0.25
                progressTask?.cancel()
                progressTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(700))
                        await MainActor.run {
                            loadingProgress = min(loadingProgress + 0.018, 0.98)
                        }
                    }
                }
            }
        }
    }
}
