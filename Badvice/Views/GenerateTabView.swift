import SwiftUI

struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    var onDataChanged: () -> Void
    var onOpenTab: ((AppTab) -> Void)? = nil

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingAdvanced = false
    @State private var generateButtonPulsing = false
    @State private var activeToast: ToastMessage? = nil
    @State private var headerTapStreak = 0
    @State private var headerPulseScale: CGFloat = 1.0
    @State private var headerRotation: Double = 0
    @State private var headerOrbitOpacity: Double = 0
    @State private var unlockedSurpriseLine: String? = nil
    @State private var surpriseClearTask: Task<Void, Never>? = nil
    @State private var quoteTapStreak = 0
    @State private var quoteTapResetTask: Task<Void, Never>? = nil
    @State private var loadingCompletionHapticArmed = false
    @State private var lastGeneratedAdviceIDForHaptics: UUID? = nil
    @AppStorage("hasDismissedWhatsNewCard_2026_02c") private var hasDismissedWhatsNewCard = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    // Hoist per-theme lookups so each is a single switch instead of many repeated calls per body
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var headerReactiveScale: CGFloat {
        guard !isMotionReduced else { return 1.0 }
        let cadenceScale: CGFloat = viewModel.hapticTrigger % 2 == 0 ? 1.0 : 1.02
        return cadenceScale * headerPulseScale
    }
    private var headerReactiveRotationAmplitude: Double {
        2.0 + Theme.personality(for: settings.theme).effectIntensity * 8.0
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
        return HStack(spacing: 8) {
            Image(systemName: headerIconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.35), radius: 6, x: 0, y: 2)

            HStack(spacing: 0) {
                Text("Bad")
                    .font(Theme.headlineFont.weight(.black))
                Text("vice")
                    .font(Theme.headlineFont.weight(.semibold))
            }
            .foregroundStyle(headerColor)
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
        .onTapGesture {
            triggerHeaderEasterEggTap()
        }
        .onLongPressGesture(minimumDuration: 0.9) {
            triggerHeaderLongPressSurprise()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Badvice")
        .accessibilityHint("Tap for theme-reactive animation and hidden surprises")
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
                            reduceMotion: settings.reduceMotion,
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
                    .font(Theme.bodyFont.weight(.semibold))
                    .lineLimit(1)
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

    private func statChip(title: String, value: String) -> some View {
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
                .font(Theme.bodyFont)
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
                    .font(Theme.bodyFont)
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
                    .font(Theme.bodyFont.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTargetHeight)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("generate.primary")
            .accessibilityHint("Generates a new advice card using the selected category and tone")
            .tint(accent)
            .foregroundStyle(buttonText)
            .disabled(viewModel.isGenerating)
            .scaleEffect(generateButtonPulsing ? 1.03 : 1.0)
            .animation(
                generateButtonPulsing
                    ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: generateButtonPulsing
            )
            .onAppear {
                if viewModel.current == nil {
                    generateButtonPulsing = true
                }
            }
            .onChange(of: viewModel.current == nil) { _, isNil in
                generateButtonPulsing = isNil
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
                    title: "Share",
                    systemImage: "square.and.arrow.up",
                    isEnabled: hasCurrent && !viewModel.isGenerating
                ) {
                    guard let payload = viewModel.currentSharePayload else { return }
                    let image = ShareCardRenderer.render(content: payload)
                    shareItems = [image, viewModel.currentShareText]
                    viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
                    showingShareSheet = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }

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
                    openTab(.chaosHub)
                    hasDismissedWhatsNewCard = true
                } label: {
                    Label("Open Chaos Hub", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(accent)

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

    // MARK: - Weekly Recap

    @ViewBuilder
    private var weeklyRecapSection: some View {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isSaturday = weekday == 7
        let recapItems = viewModel.weeklyRecapFavorites
        if isSaturday && !recapItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
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
                Button {
                    let lines = recapItems.enumerated().map {
                        "\($0.offset + 1). \($0.element.adviceLine)"
                    }.joined(separator: "\n")
                    let shareText = "My Worst Advice of the Week 🏆\n\n\(lines)\n\n— via Badvice"
                    shareItems = [shareText]
                    showingShareSheet = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Share Recap", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(accent.opacity(0.15)))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(
                            accent.opacity(0.14), lineWidth: 1))
            )
        }
    }

    private func openTab(_ tab: AppTab) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab?(tab)
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
    }

    private func triggerHeaderEasterEggTap() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        headerTapStreak += 1

        if !isMotionReduced {
            let direction: Double = headerTapStreak.isMultiple(of: 2) ? 1 : -1
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                headerPulseScale =
                    1.04 + CGFloat(Theme.personality(for: settings.theme).effectIntensity * 0.04)
                headerRotation = direction * headerReactiveRotationAmplitude
                headerOrbitOpacity = 0.92
            }
            withAnimation(.easeOut(duration: 0.46)) {
                headerPulseScale = 1.0
                headerRotation = 0
                headerOrbitOpacity = 0
            }
        }

        switch headerTapStreak {
        case 3:
            let toasts3 = [
                "Header unlocked: confidence mode engaged.",
                "Triple tap detected. Questionable decisions incoming.",
                "You found the secret handshake. Chaos nods in approval.",
            ]
            activeToast = ToastMessage(message: toasts3.randomElement()!, style: .info)
            revealSurprise("Mini surprise: the badge wakes up with your theme mood.")
        case 5:
            let toasts5 = [
                "Secret combo hit: Surprise Me launched.",
                "Five taps? That's commitment. Here's random chaos.",
                "Combo unlocked. The algorithm is now terrified of you.",
            ]
            activeToast = ToastMessage(message: toasts5.randomElement()!, style: .success)
            revealSurprise("Chaos code: rolling a random tone + category.")
            viewModel.surpriseMeAndGenerate()
            onDataChanged()
        case 8:
            let toasts8 = [
                "Ultra combo: Daily Drop triggered from the logo.",
                "Eight taps. You are now legally a chaos engineer.",
                "Logo boss defeated. Daily Drop deployed as reward.",
            ]
            activeToast = ToastMessage(message: toasts8.randomElement()!, style: .success)
            revealSurprise("You found the 8-tap easter egg. Daily Drop injected.")
            viewModel.generateDailyDrop()
            onDataChanged()
            headerTapStreak = 0
        default:
            break
        }
    }

    private func triggerHeaderLongPressSurprise() {
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let longPressToasts = [
            "Hidden mode: Roast Protocol armed.",
            "Long press detected. Friend Roast mode: activated.",
            "Patience unlocked the roast. Someone's about to have a day.",
        ]
        activeToast = ToastMessage(message: longPressToasts.randomElement()!, style: .info)
        revealSurprise("Long-press unlock: Friend Roast tone primed for your next run.")
        viewModel.selectedTone = .friendRoast
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
        let unlocked = mutatedQuotePool.randomElement() ?? mutatedQuotePool[0]
        UIPasteboard.general.string = unlocked
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        let quoteCopyToasts = [
            "Secret quote copied.",
            "Hidden wisdom extracted and clipped.",
            "Contraband quote secured to clipboard.",
            "Rare drop obtained. No one will believe you found it.",
        ]
        activeToast = ToastMessage(message: quoteCopyToasts.randomElement()!, style: .success)
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

    private func railButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(cardColor)
                    )
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
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

                Button {
                    viewModel.toggleVote(.like)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(
                            systemName: viewModel.currentVote == .like
                                ? "hand.thumbsup.fill" : "hand.thumbsup")
                        if viewModel.currentVote == .like {
                            Text("Liked")
                                .font(.caption.weight(.semibold))
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .like ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .like ? accent : secondaryText)
                .animation(
                    isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7),
                    value: viewModel.currentVote)

                Button {
                    viewModel.toggleVote(.dislike)
                    onDataChanged()
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    HStack(spacing: 5) {
                        Image(
                            systemName: viewModel.currentVote == .dislike
                                ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        if viewModel.currentVote == .dislike {
                            Text("Noted")
                                .font(.caption.weight(.semibold))
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, viewModel.currentVote == .dislike ? 12 : 0)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentVote == .dislike ? accent.opacity(0.8) : secondaryText)
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

    private var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $showingAdvanced.animation(
                isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.82))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.uniquenessStatusText)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                statStrip
                challengeCard
                keywordSuggestionsRow
                if viewModel.current != nil {
                    whyThisFailsCard
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                Text("Stats & Tools")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Streaks, keywords, and more")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            .foregroundStyle(primaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardColor)
        )
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
                    Button(suggestion) {
                        viewModel.applySuggestion(suggestion)
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.3), radius: 10)
            }

            VStack(spacing: 12) {
                Text("Your first bad idea is just a tap away.")
                    .font(Theme.cardFont)
                    .foregroundStyle(primaryText)

                Text("Pick a category and let chaos reign.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(secondaryText)
                    .opacity(0.8)
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(minHeight: 320)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Advice View

private struct LoadingAdviceView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    private var effectiveReduceMotion: Bool {
        reduceMotion || UIAccessibility.isReduceMotionEnabled
    }
    private var accentColor: Color { Theme.accent(for: theme) }
    private var secondaryAccentColor: Color {
        Theme.secondaryAccent(for: theme) ?? Theme.accent(for: theme)
    }
    private var cardColor: Color { Theme.cardColor(for: theme) }
    private var primaryTextColor: Color { Theme.primaryText(for: theme) }
    private var glowColor: Color? { Theme.glowColor(for: theme) }

    @State private var ringRotation: Double = 0
    @State private var counterRingRotation: Double = 0
    @State private var orbitRotation: Double = 0
    @State private var dotBouncePhase = false
    @State private var shimmerTravel: CGFloat = -220
    @State private var textShimmerTravel: CGFloat = -140
    @State private var glowScale: CGFloat = 0.94
    @State private var glowOpacity: Double = 0.16
    @State private var sigilScale: CGFloat = 0.95
    @State private var glyphRotation: Double = -6
    @State private var beaconPulse = false
    @State private var phrasePulse = false
    @State private var loadingPhrase: String = LoadingAdviceView.loadingPhrases[0]

    private static let loadingPhrases = [
        "Consulting the chaos...",
        "Summoning bad judgment...",
        "Asking the universe badly...",
        "Calibrating your downfall...",
        "Fabricating confidence...",
        "Running the disaster protocol...",
        "Polling experts in bad decisions...",
        "Loading questionable wisdom...",
    ]

    var body: some View {
        ZStack {
            cardColor
                .opacity(0.95)
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(effectiveReduceMotion ? 0.02 : 0.06),
                            .clear,
                            accentColor.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accentColor.opacity(0.08), lineWidth: 1)
                }

            VStack(spacing: 18) {
                skeletonCardPlaceholder

                if effectiveReduceMotion {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(accentColor)
                            .controlSize(.regular)
                        Text(loadingPhrase)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                    }
                } else {
                    microMotionLoader
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .transition(
            effectiveReduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 1.05))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generating advice")
        .onAppear {
            loadingPhrase = Self.loadingPhrases.randomElement() ?? Self.loadingPhrases[0]
            guard !effectiveReduceMotion else { return }
            ringRotation = 360
            counterRingRotation = -360
            orbitRotation = 360
            dotBouncePhase = true
            shimmerTravel = 220
            textShimmerTravel = 140
            glowScale = 1.06
            glowOpacity = 0.28
            sigilScale = 1.03
            glyphRotation = 7
            beaconPulse = true
            phrasePulse = true
        }
        .onDisappear {
            ringRotation = 0
            counterRingRotation = 0
            orbitRotation = 0
            dotBouncePhase = false
            shimmerTravel = -220
            textShimmerTravel = -140
            glowScale = 0.94
            glowOpacity = 0.16
            sigilScale = 0.95
            glyphRotation = -6
            beaconPulse = false
            phrasePulse = false
        }
        .task {
            guard !effectiveReduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                if Task.isCancelled { break }
                let next = Self.loadingPhrases
                    .filter { $0 != loadingPhrase }
                    .randomElement() ?? Self.loadingPhrases[0]
                await MainActor.run {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        loadingPhrase = next
                    }
                }
            }
        }
    }

    private var microMotionLoader: some View {
        VStack(spacing: 12) {
            chaosSigil

            ZStack {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? secondaryAccentColor : accentColor)
                            .frame(width: 6, height: 6)
                            .offset(y: dotBouncePhase ? -3 : 2)
                            .opacity(dotBouncePhase ? 1.0 : 0.45)
                            .animation(
                                .easeInOut(duration: 0.95)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.12),
                                value: dotBouncePhase
                            )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(cardColor.opacity(0.82))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accentColor.opacity(0.14), lineWidth: 1)
                )

                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index % 3 == 1 ? secondaryAccentColor : accentColor.opacity(0.9))
                            .frame(
                                width: 4,
                                height: dotBouncePhase
                                    ? [8, 12, 18, 10, 16, 9, 13][index]
                                    : [13, 9, 14, 7, 12, 8, 11][index]
                            )
                            .opacity(dotBouncePhase ? 0.95 : 0.55)
                            .animation(
                                .easeInOut(duration: 0.72)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.05),
                                value: dotBouncePhase
                            )
                    }
                }
                .frame(height: 20)
                .accessibilityHidden(true)
            }

            VStack(spacing: 6) {
                Text(loadingPhrase)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryTextColor.opacity(0.84))
                    .scaleEffect(phrasePulse ? 1.0 : 0.985)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: phrasePulse)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.semibold))
                    Text("Assembling confidence theater")
                        .font(.caption2.weight(.semibold))
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(secondaryAccentColor.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(cardColor.opacity(0.75))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(secondaryAccentColor.opacity(0.12), lineWidth: 1)
                )
            }
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.9), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 120, height: 22)
                    .offset(x: textShimmerTravel, y: -12)
                    .blendMode(.screen)
                    .mask(alignment: .top) {
                        Text(loadingPhrase)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .padding(.bottom, 24)
                    }
                    .animation(
                        .linear(duration: 1.2).repeatForever(autoreverses: false),
                        value: textShimmerTravel
                    )
            }
        }
    }

    private var chaosSigil: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardColor.opacity(0.92),
                            accentColor.opacity(0.05),
                            secondaryAccentColor.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 156, height: 102)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accentColor.opacity(0.14), lineWidth: 1)
                )

            if let glow = glowColor {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(glow.opacity(glowOpacity))
                    .frame(width: 120, height: 66)
                    .blur(radius: 14)
                    .scaleEffect(glowScale)
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: glowScale
                    )
            }

            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.12), lineWidth: 2)
                    .frame(width: 74, height: 74)

                Circle()
                    .trim(from: 0.06, to: 0.58)
                    .stroke(
                        AngularGradient(
                            colors: [accentColor.opacity(0.15), accentColor, secondaryAccentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                    )
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(ringRotation))
                    .animation(
                        .linear(duration: 1.2).repeatForever(autoreverses: false),
                        value: ringRotation
                    )

                Circle()
                    .trim(from: 0.63, to: 0.96)
                    .stroke(
                        LinearGradient(
                            colors: [secondaryAccentColor.opacity(0.22), secondaryAccentColor, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(counterRingRotation))
                    .animation(
                        .linear(duration: 1.7).repeatForever(autoreverses: false),
                        value: counterRingRotation
                    )

                ForEach(0..<8, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index.isMultiple(of: 2) ? accentColor.opacity(0.55) : secondaryAccentColor.opacity(0.5))
                        .frame(width: 3, height: index.isMultiple(of: 2) ? 10 : 6)
                        .offset(y: -42)
                        .rotationEffect(.degrees(Double(index) * 45))
                        .opacity(dotBouncePhase ? 1 : 0.45)
                        .scaleEffect(dotBouncePhase ? 1.0 : 0.88)
                        .animation(
                            .easeInOut(duration: 0.9)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                            value: dotBouncePhase
                        )
                }

                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 1 ? .white.opacity(0.95) : secondaryAccentColor)
                        .frame(width: index == 1 ? 6 : 5, height: index == 1 ? 6 : 5)
                        .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                        .offset(y: -31)
                        .rotationEffect(.degrees(Double(index) * 120 + orbitRotation))
                        .animation(
                            .linear(duration: 2.4).repeatForever(autoreverses: false),
                            value: orbitRotation
                        )
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.24), cardColor.opacity(0.95)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 22
                            )
                        )
                        .frame(width: 40, height: 40)
                    Circle()
                        .stroke(secondaryAccentColor.opacity(0.2), lineWidth: 1)
                        .frame(width: 40, height: 40)

                    Text("“")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.95), accentColor, secondaryAccentColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(glyphRotation))
                        .offset(x: 1, y: 2)
                        .scaleEffect(sigilScale)
                        .animation(
                            .spring(response: 1.0, dampingFraction: 0.6).repeatForever(autoreverses: true),
                            value: glyphRotation
                        )
                        .animation(
                            .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                            value: sigilScale
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(secondaryAccentColor)
                    .frame(width: 8, height: 8)
                    .blur(radius: beaconPulse ? 0.2 : 0)
                    .opacity(beaconPulse ? 1.0 : 0.35)
                    .shadow(color: secondaryAccentColor.opacity(0.6), radius: 6, x: 0, y: 0)
                    .offset(x: 30, y: -26)
                    .animation(
                        .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                        value: beaconPulse
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private var skeletonCardPlaceholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            skeletonLine(width: 0.46, height: 14)
            skeletonLine(width: 0.92, height: 22)
            skeletonLine(width: 0.78, height: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardColor.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                )
        )
        .overlay {
            if !effectiveReduceMotion {
                shimmerBand
                    .mask {
                        VStack(alignment: .leading, spacing: 14) {
                            skeletonLine(width: 0.46, height: 14)
                            skeletonLine(width: 0.92, height: 22)
                            skeletonLine(width: 0.78, height: 16)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
            }
        }
    }

    private var shimmerBand: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.08),
                        .white.opacity(0.30),
                        .white.opacity(0.08),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 170)
            .rotationEffect(.degrees(14))
            .offset(x: shimmerTravel)
            .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: shimmerTravel)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.45, style: .continuous)
            .fill(accentColor.opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: height * 0.45, style: .continuous)
                    .fill(primaryTextColor.opacity(0.07))
            }
            .frame(width: max(84, 280 * width), height: height)
            .accessibilityHidden(true)
    }
}
