import SwiftUI

struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onDataChanged: () -> Void
    var onOpenTab: ((AppTab) -> Void)? = nil
    var quickAccessTabs: [AppTab] = []
    var onResetAllLocalAccounts: (() async -> ToastMessage)? = nil
    var onRefreshSocialAvailability: (() async -> ToastMessage)? = nil
    #if DEBUG
        var onReseedCloudKitSchema: (() async -> ToastMessage)? = nil
    #endif

    @State var shareItems: [Any] = []
    @State var showingShareSheet = false
    @State var showingAdvanced = false
    @State var showingBrandMenu = false
    @State var showingResetAccountsConfirmation = false
    @State var runningBrandAction = false
    @State private var generateButtonPulsing = false
    @State var activeToast: ToastMessage? = nil
    @State private var headerPulseScale: CGFloat = 1.0
    @State private var headerRotation: Double = 0
    @State private var headerOrbitOpacity: Double = 0
    @State var unlockedSurpriseLine: String? = nil
    @State var surpriseClearTask: Task<Void, Never>? = nil
    @State var quoteTapStreak = 0
    @State var quoteTapResetTask: Task<Void, Never>? = nil
    @State var loadingCompletionHapticArmed = false
    @State var lastGeneratedAdviceIDForHaptics: UUID? = nil
    @AppStorage("hasDismissedWhatsNewCard_2026_02c") private var hasDismissedWhatsNewCard = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var isMotionReduced: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    // Hoist per-theme lookups so each is a single switch instead of many repeated calls per body
    var accent: Color { Theme.accent(for: settings.theme) }
    var cardColor: Color { Theme.cardColor(for: settings.theme) }
    var primaryText: Color { Theme.primaryText(for: settings.theme) }
    var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    var buttonText: Color { Theme.buttonText(for: settings.theme) }
    var socialEntryPrompt: String {
        social.availability.isAvailable
            ? "Finish your Friends profile in Friends to share posts and start collabs."
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
        let headerColor = Theme.headerColor(for: settings.theme)
        let glow = Theme.glowColor(for: settings.theme)
        return Button {
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            showingBrandMenu = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: headerIconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.35), radius: 6, x: 0, y: 2)

                HStack(spacing: 0) {
                    Text("Bad")
                        .font(Theme.headlineFont(for: settings.theme).weight(.black))
                    Text("vice")
                        .font(Theme.headlineFont(for: settings.theme).weight(.semibold))
                }
                .foregroundStyle(headerColor)

                Spacer(minLength: 0)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryText.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(headerBadgeGradient.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(headerBadgeGradient.opacity(0.35), lineWidth: 1)
                )
        )
        .overlay {
            if let glow, !isMotionReduced {
                Circle()
                    .fill(glow.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .blur(radius: 10)
                    .offset(x: 18, y: -10)
            }
            if !isMotionReduced {
                Circle()
                    .stroke(headerBadgeGradient.opacity(headerOrbitOpacity), lineWidth: 2)
                    .scaleEffect(1.0 + CGFloat(headerOrbitOpacity * 0.55))
                    .blur(radius: 0.7)
            }
        }
        .shadow(color: Theme.headerShadowColor(for: settings.theme), radius: 8, x: 0, y: 4)
        .scaleEffect(headerReactiveScale)
        .rotationEffect(.degrees(isMotionReduced ? 0 : headerRotation))
        .hueRotation(.degrees(isMotionReduced ? 0 : Double(viewModel.hapticTrigger % 4) * 12))
        .animation(
            isMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.6),
            value: viewModel.hapticTrigger
        )
        .animation(
            isMotionReduced ? nil : .spring(response: 0.24, dampingFraction: 0.56),
            value: headerPulseScale
        )
        .animation(
            isMotionReduced ? nil : .spring(response: 0.26, dampingFraction: 0.58),
            value: headerRotation
        )
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.9) {
            triggerHeaderLongPressSurprise()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Badvice")
        .accessibilityHint("Opens the Badvice menu")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                headerView
                if let unlockedSurpriseLine {
                    surpriseBanner(unlockedSurpriseLine)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                selectorRow
                dailyQuoteBanner
                weeklyRecapSection
                scenarioComposer
                friendRoastComposer
                scenarioSuggestionsRow
                adaptiveHintCard
                if !hasDismissedWhatsNewCard {
                    whatsNewCard
                }

                Group {
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
                                : .asymmetric(
                                    insertion: .scale.combined(with: .opacity), removal: .opacity)
                        )
                        .scaleEffect(generateButtonPulsing ? 0.98 : 1.0)
                        .animation(
                            isMotionReduced ? nil : .spring(response: 0.2, dampingFraction: 0.5),
                            value: viewModel.hapticTrigger
                        )
                        .contextMenu {
                            Button(
                                "Save",
                                systemImage: viewModel.isCurrentFavorite
                                    ? "bookmark.fill" : "bookmark"
                            ) {
                                let wasFavorite = viewModel.isCurrentFavorite
                                viewModel.toggleFavorite()
                                onDataChanged()
                                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                                activeToast = ToastMessage(
                                    message: wasFavorite ? "Removed from Favorites" : "Saved!",
                                    style: wasFavorite ? .deleted : .success
                                )
                            }

                            Button("Copy", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = viewModel.currentShareText
                                viewModel.trackCopy()
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                                activeToast = ToastMessage(message: "Copied!", style: .success)
                            }

                            Button("Share", systemImage: "square.and.arrow.up") {
                                guard let payload = viewModel.currentSharePayload else { return }
                                let image = ShareCardRenderer.render(content: payload)
                                shareItems = [image, viewModel.currentShareText]
                                viewModel.trackShare(
                                    template: payload.template, ratio: payload.aspectRatio)
                                showingShareSheet = true
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            }

                            Button("Collaborate", systemImage: "person.2.badge.plus") {
                                guard social.socialFeaturesEnabled else {
                                    activeToast = ToastMessage(
                                        message: socialEntryPrompt,
                                        style: .error
                                    )
                                    return
                                }
                                guard let record = viewModel.current else { return }
                                social.queueCollabDraft(type: .advice, content: record.adviceLine)
                                openTab(.friends)
                                activeToast = ToastMessage(
                                    message: "Draft sent to Friends > Collab.",
                                    style: .info
                                )
                            }
                            .disabled(!social.socialFeaturesEnabled)
                        }
                        .onTapGesture(count: 2) {
                            let wasFavorite = viewModel.isCurrentFavorite
                            viewModel.toggleFavorite()
                            onDataChanged()
                            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                            activeToast = ToastMessage(
                                message: wasFavorite ? "Removed from Favorites" : "Saved!",
                                style: wasFavorite ? .deleted : .success
                            )
                        }
                    } else if !viewModel.isGenerating {
                        emptyState
                            .transition(isMotionReduced ? .identity : .opacity)
                    }
                }
                .overlay {
                    if viewModel.isGenerating {
                        LoadingAdviceView(theme: settings.theme, reduceMotion: isMotionReduced)
                    }
                }
                .animation(
                    isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.86),
                    value: viewModel.current?.id
                )
                .animation(
                    isMotionReduced ? nil : .easeInOut(duration: 0.2), value: viewModel.isGenerating
                )

                votingRow
                primaryActionButtons
                if let notice = viewModel.generationNotice, !notice.isEmpty {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                advancedSection
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, tabBarVisible.wrappedValue ? 124 : 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .coordinateSpace(name: "scroll")
        .trackScrollForTabBar()
        .safeAreaPadding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
        .refreshable {
            // Pull to generate new advice
            await viewModel.generate()
            onDataChanged()
        }
        .toast(item: $activeToast, accentColor: accent)

        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingBrandMenu) {
            brandMenuSheet
        }
        .onAppear {
            AppPerformanceInstrumentation.markAdviceTabFirstRenderIfNeeded()
            lastGeneratedAdviceIDForHaptics = viewModel.current?.id
            tabBarVisible.wrappedValue = true
        }
        .onChange(of: viewModel.isGenerating) { _, isGenerating in
            handleGeneratingStateChange(isGenerating)
        }
    }

    private var dailyQuoteBanner: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bad Quote of the Day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                Text("\u{201C}\(viewModel.dailyBadQuote.text)\u{201D}")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(primaryText)
                    .lineLimit(3)
                Text("— \(viewModel.dailyBadQuote.source)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bad quote of the day")
        .accessibilityValue(viewModel.dailyBadQuote.text)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerQuoteTapEasterEgg()
        }
    }

    private var selectorRow: some View {
        HStack(spacing: 10) {
            categoryMenu
            toneMenu
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $viewModel.selectedCategory) {
                ForEach(AdviceCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
        } label: {
            selectionLabel(title: "Category", value: viewModel.selectedCategory.title)
        }
        .accessibilityLabel("Category")
        .accessibilityValue(viewModel.selectedCategory.title)
    }

    private var toneMenu: some View {
        Menu {
            Picker("Tone", selection: $viewModel.selectedTone) {
                ForEach(ToneMode.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }
        } label: {
            selectionLabel(title: "Tone", value: viewModel.selectedTone.title)
        }
        .accessibilityLabel("Tone mode")
        .accessibilityValue(viewModel.selectedTone.title)
    }

    private func selectionLabel(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(Theme.bodyFont(for: settings.theme).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
    }

    func statChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
    }

    private var scenarioComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Situation (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                Spacer()
                if !viewModel.scenarioText.isEmpty {
                    Button("Clear") {
                        viewModel.scenarioText = ""
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                    .transition(
                        isMotionReduced ? .identity : .opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(
                isMotionReduced ? nil : .easeInOut(duration: Theme.animFast),
                value: viewModel.scenarioText.isEmpty)

            TextField("Example: awkward first date", text: $viewModel.scenarioText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont(for: settings.theme))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                    Button("Shuffle") {
                        if let pick = suggestions.randomElement() {
                            applyScenarioSuggestion(pick)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                applyScenarioSuggestion(suggestion)
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            }
                            .buttonStyle(.bordered)
                            .tint(accent)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adaptiveHintCard: some View {
        if viewModel.selectedCategory == .random || viewModel.selectedTone == .random {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("Adaptive Mix")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(accent)

                Text("We’ll use your recent likes to steer tone + category while staying fresh.")
                    .font(.footnote)
                    .foregroundStyle(primaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accent.opacity(0.16), lineWidth: 1)
                    )
            )
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
                Text("Friend Name (for roast mode)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)

                TextField("Example: Alex", text: $viewModel.friendName)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyFont(for: settings.theme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardColor)
                    )
                    .foregroundStyle(primaryText)
            }
        }
    }

    var challengeCard: some View {
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

    var whyThisFailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Why this is terrible")
                .font(.caption.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(viewModel.lastWhyTerrible)
                .font(.footnote)
                .foregroundStyle(primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
    }

    private var primaryActionButtons: some View {
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
            .buttonStyle(.borderedProminent)
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
                .buttonStyle(.bordered)
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
                .buttonStyle(.bordered)
                .accessibilityIdentifier("generate.dailyDrop")
                .accessibilityHint("Generates the Daily Drop advice")
                .disabled(viewModel.isGenerating)
            }
            .tint(accent)

            // Save / Copy / Share rail
            HStack(spacing: 14) {
                railButton(
                    title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                    systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    let wasFavorite = viewModel.isCurrentFavorite
                    viewModel.toggleFavorite()
                    onDataChanged()
                    HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                    activeToast = ToastMessage(
                        message: wasFavorite ? "Removed from Favorites" : "Saved!",
                        style: wasFavorite ? .deleted : .success
                    )
                }

                railButton(
                    title: "Copy",
                    systemImage: "doc.on.doc",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    UIPasteboard.general.string = viewModel.currentShareText
                    viewModel.trackCopy()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    activeToast = ToastMessage(message: "Copied!", style: .success)
                }

                railButton(
                    title: "Share to Friends",
                    systemImage: "person.2.fill",
                    isEnabled: hasCurrent && !viewModel.isGenerating && social.socialFeaturesEnabled
                ) {
                    guard let record = viewModel.current else { return }
                    Task {
                        await social.shareAdviceToFriends(text: record.adviceLine)
                        if let message = social.statusMessage {
                            activeToast = ToastMessage(
                                message: message,
                                style: message.lowercased().contains("shared")
                                    ? .success : .error
                            )
                        }
                    }
                }
                .accessibilityIdentifier("generate.shareToFriends")

                railButton(
                    title: "Remix",
                    systemImage: "bolt.fill",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    viewModel.remixCurrentAdvice()
                    activeToast = ToastMessage(message: "Remixed!", style: .success)
                }
            }
            .frame(maxWidth: .infinity)

            if !social.availability.isAvailable {
                Text(social.availability.message)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if social.currentUser == nil {
                Text("Finish Friends setup to share from Generate and spin up collabs.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            }

            Text(
                "New: Chaos Hub combines daily missions, community pulse, and your wins. ML Remix now sharpens tone and category variety."
            )
            .font(.footnote)
            .foregroundStyle(secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    hasDismissedWhatsNewCard = true
                } label: {
                    Text("Got it")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(buttonText)
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
    }

}
