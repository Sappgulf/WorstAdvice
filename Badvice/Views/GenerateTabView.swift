import Foundation
import Observation
import SwiftUI

/// The primary Badvice workspace.
///
/// The engine and persistence layer are intentionally injected from the
/// existing session. This view owns only presentation state, which keeps the
/// interaction fast and makes the visual system easy to evolve independently
/// from generation rules.
struct GenerateTabView: View {
    @Bindable var viewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel

    let onDataChanged: () -> Void
    var onOpenTab: ((AppTab) -> Void)? = nil
    var isActive: Bool = false
    var settingsPresented: Bool = false
    var quickAccessTabs: [AppTab] = []
    var onResetAllLocalAccounts: (() async -> ToastMessage)? = nil

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.tabBarVisible) private var tabBarVisible

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingBrandMenu = false
    @State private var showingBracket = false
    @State private var showingDetails = false
    @State private var showingCustomization = false
    @State private var showingPlayTools = false
    @ScaledMetric(relativeTo: .largeTitle) private var mastheadSize: CGFloat = 54
    @State private var activeToast: ToastMessage?
    @State private var pendingBrandMenuTab: AppTab?
    @State private var lastGeneratedAdviceID: UUID?
    @State private var loadingHapticArmed = false
    @State private var revealsRealityCheck = false
    private enum ComposerField: Hashable { case situation, friendName }
    @FocusState private var composerField: ComposerField?

    private var reduceMotion: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var secondaryAccent: Color { Theme.secondaryAccent(for: settings.theme) ?? accent }
    private var canvas: Color { Theme.canvasColor(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var selectedVoice: AdviceVoice { viewModel.selectedTone.voice }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                canvas
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Color.clear
                                .frame(height: 1)
                                .id("generate.top")

                            header

                            workspace
                            if let notice = viewModel.generationNotice, !notice.isEmpty {
                                statusBanner(notice)
                            }
                            if viewModel.current == nil && !viewModel.isGenerating {
                                emptyState
                            } else {
                                resultSection
                                    .id("generate.result")
                            }

                            footerTools
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 22)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    .safeAreaPadding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 26)
                    .refreshable {
                        await viewModel.generate()
                        onDataChanged()
                    }
                    .onAppear {
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                    .onChange(of: isActive) { _, active in
                        guard active else { return }
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                    .onChange(of: settingsPresented) { _, _ in
                        proxy.scrollTo("generate.top", anchor: .top)
                    }
                    .onChange(of: viewModel.current?.id) { _, adviceID in
                        guard adviceID != nil else { return }
                        revealsRealityCheck = false
                        if reduceMotion {
                            proxy.scrollTo("generate.result", anchor: .top)
                        } else {
                            withAnimation(.easeOut(duration: Theme.animFast)) {
                                proxy.scrollTo("generate.result", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .toast(item: $activeToast, accentColor: accent)
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingBrandMenu, onDismiss: handleBrandMenuDismiss) {
            GenerateBrandMenuView(
                social: social,
                settings: settings,
                quickAccessTabs: quickAccessTabs,
                isPresented: $showingBrandMenu,
                activeToast: $activeToast,
                onSelectQuickAccessTab: { pendingBrandMenuTab = $0 },
                onResetAllLocalAccounts: onResetAllLocalAccounts
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { composerField = nil }.accessibilityIdentifier("keyboard.done")
            }
        }
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: viewModel)
        }
        .onAppear(perform: prepareScreen)
        .onChange(of: viewModel.selectedTone) { _, tone in
            if tone == .friendRoast { showingCustomization = true }
        }
        .onChange(of: viewModel.isGenerating) { _, generating in
            handleGeneratingStateChange(generating)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("BAD IDEAS. GREAT DELIVERY.")
                    .font(.caption2.weight(.black))
                    .tracking(1.8)
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                Button(action: openBrandMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.body.weight(.bold))
                        .foregroundStyle(primaryText)
                        .frame(width: 44, height: 44)
                        .background(cardColor, in: Circle())
                        .overlay { Circle().stroke(secondaryText.opacity(0.18), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Badvice menu")
                .accessibilityHint("Opens history, ideas, party mode, and settings")
                .accessibilityIdentifier("generate.brandMenu")
            }

            HStack(alignment: .center, spacing: 8) {
                Text("badvice.")
                    .font(.system(size: mastheadSize, weight: .black, design: .serif))
                    .tracking(-2.5)
                    .foregroundStyle(primaryText)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text("100%")
                        .font(.system(.title3, design: .serif, weight: .black))
                    Text("QUESTIONABLE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.8)
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
                .foregroundStyle(accent)
                .padding(12)
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(accent, lineWidth: 2) }
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Good intentions. Terrible advice.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 4)
                if viewModel.challengeStreakDays > 0 {
                    Label("\(viewModel.challengeStreakDays)d", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .accessibilityLabel("\(viewModel.challengeStreakDays) day streak")
                }
            }
            Rectangle().fill(primaryText).frame(height: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.header")
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(AdviceCategory.allCases) { category in
                        Button(category.title) {
                            viewModel.updateCategory(category, autoGenerate: false)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        }
                    }
                } label: {
                    briefSelection("TOPIC", value: viewModel.selectedCategory.title, icon: viewModel.selectedCategory.icon)
                }
                .accessibilityIdentifier("generate.category.menu")

                Menu {
                    ForEach(ToneMode.allCases) { tone in
                        Button(tone.voice.name) {
                            viewModel.updateTone(tone, autoGenerate: false)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        }
                    }
                } label: {
                    briefSelection("VOICE", value: selectedVoice.name, icon: selectedVoice.systemImage)
                }
                .accessibilityIdentifier("generate.tone.menu")
            }
            .buttonStyle(.plain)

            TextField("Your situation", text: $viewModel.scenarioText, prompt: Text("Your situation (optional)").foregroundColor(secondaryText), axis: .vertical)
                .font(.body)
                .foregroundStyle(primaryText)
                .lineLimit(1...3)
                .padding(14)
                .background(canvas, in: RoundedRectangle(cornerRadius: 12))
                .focused($composerField, equals: .situation)
                .accessibilityLabel("Your situation, optional")
                .accessibilityIdentifier("generate.situation")

            primaryActions

            Button {
                showingCustomization.toggle()
            } label: {
                HStack {
                    Label("Tune the chaos", systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: showingCustomization ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(secondaryText)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showingCustomization ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("generate.customize")
            if showingCustomization {
                VStack(alignment: .leading, spacing: 0) {
                    laneSelector
                    voiceSelector
                    if viewModel.selectedTone == .friendRoast {
                        TextField("Friend's name (optional)", text: $viewModel.friendName)
                            .textFieldStyle(.roundedBorder)
                            .focused($composerField, equals: .friendName)
                            .accessibilityIdentifier("generate.friendName")
                    }
                    intensityDial
                }
            }
        }
        .padding(18)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(secondaryText.opacity(0.16), lineWidth: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.commandCard")
    }

    private func briefSelection(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(secondaryText)
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(accent)
                Text(value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(primaryText)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var laneSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectorHeader(
                title: "Topic",
                selectedValue: viewModel.selectedCategory.title,
                identifier: "generate.category"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(AdviceCategory.allCases.enumerated()), id: \.element.id) { index, category in
                        selectorChip(
                            title: category.title,
                            icon: category.icon,
                            isSelected: viewModel.selectedCategory == category,
                            identifier: "generate.category.chip.\(index)"
                        ) {
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            viewModel.updateCategory(category, autoGenerate: false)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 6)
            }
        }
        .padding(.bottom, 16)
    }

    private var voiceSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectorHeader(
                title: "Voice",
                selectedValue: selectedVoice.name,
                identifier: "generate.tone"
            )

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: selectedVoice.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(accent.opacity(0.12)))

                Text(selectedVoice.descriptor)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 2)

                intensityDots(level: selectedVoice.intensity)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(ToneMode.allCases.enumerated()), id: \.element.id) { index, tone in
                        selectorChip(
                            title: tone.voice.name,
                            icon: tone.voice.systemImage,
                            isSelected: viewModel.selectedTone == tone,
                            identifier: "generate.tone.chip.\(index)"
                        ) {
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            viewModel.updateTone(tone, autoGenerate: false)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 6)
            }
        }
        .padding(.vertical, 16)
    }

    private var intensityDial: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BADVICE DIAL")
                        .font(.caption2.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(secondaryText)
                    Text(viewModel.selectedIntensity.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                }

                Spacer(minLength: 8)

                Text("\(viewModel.selectedIntensity.rawValue)/5")
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(Theme.espressoInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.copperEmbossGradient, in: Capsule(style: .continuous))
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.selectedIntensity.rawValue) },
                    set: { rawValue in
                        let step = Int(rawValue.rounded())
                        guard let intensity = BadviceIntensity(rawValue: step),
                              intensity != viewModel.selectedIntensity
                        else { return }
                        viewModel.selectedIntensity = intensity
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                ),
                in: 1...5,
                step: 1
            ) {
                Text("Badvice intensity")
            } minimumValueLabel: {
                Image(systemName: "drop")
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "flame.fill")
                    .accessibilityHidden(true)
            }
            .tint(accent)
            .accessibilityIdentifier("generate.intensity")
            .accessibilityValue(viewModel.selectedIntensity.title)
            .accessibilityHint("Adjusts the comedic exaggeration of your advice")

            Text(viewModel.selectedIntensity.detail)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
            Button(action: generateAdvice) {
                HStack(spacing: 9) {
                    Image(systemName: viewModel.isGenerating ? "hourglass" : "sparkles")
                        .font(.body.weight(.bold))
                    Text(viewModel.isGenerating ? "Cooking up bad advice…" : "Give me bad advice")
                        .font(.body.weight(.bold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.black))
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, 18)
            }
            .buttonStyle(MagazineButtonStyle(theme: settings.theme, reduceMotion: reduceMotion))
            .disabled(viewModel.isGenerating)
            .accessibilityIdentifier("generate.primary")
            .accessibilityHint("Generates a new advice card using the selected topic and voice")

            HStack(spacing: 10) {
                compactAction(
                    title: "Surprise",
                    systemImage: "dice.fill",
                    identifier: "generate.surprise",
                    isDisabled: viewModel.isGenerating,
                    action: surpriseAndGenerate
                )
                compactAction(
                    title: "Daily drop",
                    systemImage: "calendar.badge.clock",
                    identifier: "generate.dailyDrop",
                    isDisabled: viewModel.isGenerating,
                    action: generateDailyDrop
                )
            }
        }
        .padding(.top, 2)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.isGenerating ? "THE BUREAU IS DRAFTING" : "THE RESULT")
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Rectangle()
                    .fill(secondaryText.opacity(0.18))
                    .frame(height: 1)
                if !viewModel.isGenerating {
                    Text(viewModel.isCurrentFavorite ? "SAVED" : "UNSAVED")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(viewModel.isCurrentFavorite ? accent : secondaryText)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.large)

            if let source = viewModel.generationSourceBadgeText, !viewModel.isGenerating {
                Label(source, systemImage: source.hasPrefix("Apple") ? "apple.intelligence" : "bolt.shield")
                    .font(.caption.weight(.semibold)).foregroundStyle(secondaryText)
                    .accessibilityIdentifier("generate.source")
            }

            ZStack {
                if let record = viewModel.current, !viewModel.isGenerating {
                    AdviceCardView(
                        record: record,
                        theme: settings.theme,
                        reduceMotion: reduceMotion,
                        showsRealityCheck: false
                    )
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.isGenerating {
                    GenerationStateView(theme: settings.theme, reduceMotion: reduceMotion)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : Theme.smugSettle, value: viewModel.current?.id)
            .animation(reduceMotion ? nil : .easeInOut(duration: Theme.animFast), value: viewModel.isGenerating)

            if !viewModel.isGenerating {
                resultActions
                realityCheck
                Button {
                    showingPlayTools.toggle()
                } label: {
                    HStack {
                        Label("Again, but make it…", systemImage: "wand.and.stars")
                        Spacer()
                        Image(systemName: showingPlayTools ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(showingPlayTools ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("generate.playTools")
                if showingPlayTools {
                    revisionControls
                    votingRow
                }
            }
        }
    }

    private var resultActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.isCurrentFavorite ? "Keep the keeper" : "What happens next?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Spacer(minLength: 0)
                Text(viewModel.todayGeneratedCount == 1 ? "1 take today" : "\(viewModel.todayGeneratedCount) takes today")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("generate.actionRailHeader")

            HStack(spacing: 8) {
                resultActionButton(
                    title: viewModel.isCurrentFavorite ? "Saved" : "Save",
                    systemImage: viewModel.isCurrentFavorite ? "bookmark.fill" : "bookmark",
                    identifier: "generate.save",
                    isProminent: viewModel.isCurrentFavorite,
                    action: toggleFavorite
                )
                resultActionButton(title: "Copy", systemImage: "doc.on.doc", identifier: "generate.copy", action: copyAdvice)
                resultActionButton(title: "Share", systemImage: "square.and.arrow.up", identifier: "generate.share", action: shareAdvice)
                resultActionButton(title: "Another", systemImage: "arrow.clockwise", identifier: "generate.remix", action: generateAdvice)
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardColor.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(secondaryText.opacity(0.12), lineWidth: 1)
        }
    }

    private var revisionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Again, but…")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("Same bad idea. A fresh delivery.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(AdviceRevisionStyle.allCases) { revision in
                        Button {
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            viewModel.reviseCurrentAdvice(revision)
                            onDataChanged()
                        } label: {
                            Label(revision.title, systemImage: revision.systemImage)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .foregroundStyle(primaryText)
                                .background(
                                    secondaryText.opacity(0.07),
                                    in: Capsule(style: .continuous)
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(secondaryText.opacity(0.12), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isGenerating)
                        .accessibilityIdentifier("generate.revision.\(revision.rawValue)")
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardColor.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(secondaryText.opacity(0.12), lineWidth: 1)
        }
    }

    private var realityCheck: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: Theme.animFast)) {
                    revealsRealityCheck.toggle()
                }
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lifepreserver.fill")
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reality check")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text("The sensible answer, if you insist")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                        .rotationEffect(.degrees(revealsRealityCheck ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("generate.realityCheck")
            .accessibilityValue(revealsRealityCheck ? "Expanded" : "Collapsed")

            if revealsRealityCheck, let text = viewModel.currentRealityCheck {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("generate.realityCheck.text")
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardColor.opacity(0.66))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        }
    }

    private var votingRow: some View {
        HStack(spacing: 10) {
            Text("Was this bad enough?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText)

            Spacer(minLength: 0)

            voteButton(
                title: viewModel.currentVote == .like ? "Approved" : "Like",
                systemImage: viewModel.currentVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup",
                isSelected: viewModel.currentVote == .like
            ) {
                viewModel.toggleVote(.like)
                onDataChanged()
            }
            voteButton(
                title: viewModel.currentVote == .dislike ? "Noted" : "Dislike",
                systemImage: viewModel.currentVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                isSelected: viewModel.currentVote == .dislike
            ) {
                viewModel.toggleVote(.dislike)
                onDataChanged()
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "scroll.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your next bad idea starts here.")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(primaryText)
                    Text("Pick a topic, borrow a personality, and let us make it worse.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }

            HStack(spacing: 8) {
                emptyStep("01", "Pick")
                emptyStep("02", "Stamp")
                emptyStep("03", "Save")
                emptyStep("04", "Share")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.emptyState")
    }

    private var footerTools: some View {
        DisclosureGroup(
            isExpanded: $showingDetails.animation(reduceMotion ? nil : .easeInOut(duration: Theme.animMedium))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    footerMetric(title: "Today", value: "\(viewModel.todayGeneratedCount)")
                    footerMetric(title: "Total", value: "\(viewModel.totalGeneratedCount)")
                    footerMetric(title: "Saved", value: "\(viewModel.favoriteCount)")
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.challengeTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text(viewModel.challengeProgressText)
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                if viewModel.current != nil {
                    Text(viewModel.lastWhyTerrible)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.localTasteSummary.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text(viewModel.localTasteSummary.detail)
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("generate.tasteProfile")

                Button {
                    showingBracket = true
                } label: {
                    Label("Open advice battles", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "ellipsis.rectangle")
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your mischief so far")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text("Streaks, saved takes, and your taste in terrible ideas")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .tint(accent)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardColor.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(secondaryText.opacity(0.11), lineWidth: 1)
        }
    }

    private func selectorHeader(title: String, selectedValue: String, identifier: String) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.0)
                .foregroundStyle(secondaryText)
            Spacer(minLength: 0)
            Text(selectedValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityIdentifier(identifier)
    }

    private func selectorChip(
        title: String,
        icon: String?,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
            }
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(isSelected ? buttonText : primaryText)
        .padding(.horizontal, 12)
        .frame(minHeight: 35)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? accent : secondaryText.opacity(0.09))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.22) : secondaryText.opacity(0.13), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.76), value: isSelected)
    }

    private func intensityDots(level: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { value in
                Capsule(style: .continuous)
                    .fill(value <= level ? accent : secondaryText.opacity(0.17))
                    .frame(width: 4, height: value <= level ? 16 : 10)
            }
        }
        .frame(height: 18, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice intensity \(level) out of 5")
    }

    private func compactAction(
        title: String,
        systemImage: String,
        identifier: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? secondaryText.opacity(0.42) : primaryText)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(secondaryText.opacity(isDisabled ? 0.04 : 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(secondaryText.opacity(isDisabled ? 0.06 : 0.13), lineWidth: 1)
        }
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }

    private func resultActionButton(
        title: String,
        systemImage: String,
        identifier: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isProminent ? accent : primaryText)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isProminent ? accent.opacity(0.14) : secondaryText.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isProminent ? accent.opacity(0.28) : secondaryText.opacity(0.1), lineWidth: 1)
        }
        .accessibilityIdentifier(identifier)
    }

    private func voteButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? buttonText : secondaryText)
        .background {
            Capsule(style: .continuous)
                .fill(isSelected ? accent : secondaryText.opacity(0.08))
        }
    }

    private func footerMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.7)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private func emptyStep(_ number: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.caption2.weight(.black).monospacedDigit())
                .foregroundStyle(accent)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: viewModel.generationNoticeStyle.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(viewModel.generationNoticeStyle.tintColor(accent: accent))
            Text(message)
                .font(.caption)
                .foregroundStyle(primaryText)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardColor.opacity(0.66))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func prepareScreen() {
        AppPerformanceInstrumentation.markAdviceTabFirstRenderIfNeeded()
        lastGeneratedAdviceID = viewModel.current?.id
        tabBarVisible.wrappedValue = true

        if viewModel.current == nil {
            viewModel.bootstrapAdviceExperienceIfNeeded(
                autoGenerateInitialAdvice:
                    !ProcessInfo.processInfo.arguments.contains("-ui-testing")
                    && !ProcessInfo.processInfo.arguments.contains("-debug-preload-polish-fixtures")
            )
        }
    }

    private func handleGeneratingStateChange(_ generating: Bool) {
        if generating {
            loadingHapticArmed = true
            HapticsManager.play(style: .light, isEnabled: settings.hapticsEnabled)
            return
        }

        guard loadingHapticArmed else { return }
        loadingHapticArmed = false
        guard let currentID = viewModel.current?.id, currentID != lastGeneratedAdviceID else { return }
        lastGeneratedAdviceID = currentID
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        SoundFeedback.playGenerate(isEnabled: settings.soundEffectsEnabled)
    }

    private func generateAdvice() {
        composerField = nil
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Task {
            await viewModel.generate()
            onDataChanged()
        }
    }

    private func surpriseAndGenerate() {
        composerField = nil
        viewModel.surpriseMeAndGenerate()
        onDataChanged()
    }

    private func generateDailyDrop() {
        composerField = nil
        viewModel.generateDailyDrop()
        onDataChanged()
    }

    private func toggleFavorite() {
        let wasFavorite = viewModel.isCurrentFavorite
        viewModel.toggleFavorite()
        onDataChanged()
        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: wasFavorite ? "Removed from Saved" : "Saved to your library", style: wasFavorite ? .deleted : .success)
    }

    private func copyAdvice() {
        UIPasteboard.general.string = viewModel.currentShareText
        viewModel.trackCopy()
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: "Copied to clipboard", style: .success)
    }

    private func shareAdvice() {
        guard let payload = viewModel.currentSharePayload else { return }
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Task {
            let image = await ShareCardRenderer.renderAsync(content: payload)
            shareItems = [image, viewModel.currentShareText]
            viewModel.trackShare(template: payload.template, ratio: payload.aspectRatio)
            showingShareSheet = true
            activeToast = ToastMessage(message: "Share card ready", style: .success)
        }
    }

    private func remixAdvice() {
        viewModel.remixCurrentAdvice()
        activeToast = ToastMessage(message: "Remixed", style: .success)
    }

    private func openBrandMenu() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        showingBrandMenu = true
    }

    private func handleBrandMenuDismiss() {
        guard let tab = pendingBrandMenuTab else { return }
        pendingBrandMenuTab = nil
        DispatchQueue.main.async {
            onOpenTab?(tab)
        }
    }
}

private struct GenerationStateView: View {
    let theme: ThemeMode
    let reduceMotion: Bool

    @State private var tick = 0
    @State private var task: Task<Void, Never>?

    private let messages = [
        "Finding the least defensible angle…",
        "Replacing nuance with confidence…",
        "Consulting the committee of one…",
        "Polishing the red flags…",
    ]

    private var accent: Color { Theme.accent(for: theme) }
    private var primaryText: Color { Theme.primaryText(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }
    private var cardColor: Color { Theme.cardColor(for: theme) }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.16), lineWidth: 5)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0.08, to: 0.76)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(reduceMotion ? 0 : 360))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: tick)
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
            }

            Text("GENERATING ADVICE")
                .font(.caption2.weight(.black))
                .tracking(1.4)
                .foregroundStyle(accent)

            Text(messages[tick % messages.count])
                .font(.system(.headline, design: .serif, weight: .bold))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: tick)

            ChaosMeterBar(
                progress: min(0.2 + Double(tick % 5) * 0.15, 0.9),
                accent: accent,
                track: secondaryText.opacity(0.12),
                height: 6,
                reduceMotion: reduceMotion
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 230)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("generate.loading")
        .accessibilityLabel("Generating advice — \(messages[tick % messages.count])")
        .onAppear {
            guard !reduceMotion else { return }
            task?.cancel()
            task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(900))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { tick += 1 }
                }
            }
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }
}
