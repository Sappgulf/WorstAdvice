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
    @State private var activeToast: ToastMessage?
    @State private var pendingBrandMenuTab: AppTab?
    @State private var lastGeneratedAdviceID: UUID?
    @State private var loadingHapticArmed = false
    @State private var revealsRealityCheck = false
    @FocusState private var isComposerFocused: Bool

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

                            if viewModel.current == nil && !viewModel.isGenerating {
                                workspace
                                if let notice = viewModel.generationNotice, !notice.isEmpty {
                                    statusBanner(notice)
                                }
                                emptyState
                            } else {
                                resultSection
                                    .id("generate.result")
                                if let notice = viewModel.generationNotice, !notice.isEmpty {
                                    statusBanner(notice)
                                }
                                workspace
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
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: viewModel)
        }
        .onAppear(perform: prepareScreen)
        .onChange(of: viewModel.isGenerating) { _, generating in
            handleGeneratingStateChange(generating)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            Image("BureauDeskHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [.clear, Theme.espressoInk.opacity(0.38), Theme.espressoInk.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image("BadviceMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)

                        Text("THE BADVICE BUREAU")
                            .font(.caption2.weight(.black))
                            .tracking(1.7)
                            .foregroundStyle(Theme.copperFoilLight)
                    }

                    Text("Make one confident mistake.")
                        .font(.system(size: 25, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.parchmentWarm)
                        .lineLimit(2)

                    Text("Private, instant, and drafted on this device.")
                        .font(.caption)
                        .foregroundStyle(Theme.parchmentWarm.opacity(0.76))
                }

                Spacer(minLength: 4)

                if viewModel.challengeStreakDays > 0 {
                    Label("\(viewModel.challengeStreakDays)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.parchmentWarm)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.3), in: Capsule(style: .continuous))
                        .accessibilityLabel("\(viewModel.challengeStreakDays) day streak")
                }
            }
            .padding(16)

            VStack {
                HStack {
                    Spacer()

                    Button(action: openBrandMenu) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.parchmentWarm)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.34), in: Circle())
                            .overlay {
                                Circle().stroke(Theme.parchmentWarm.opacity(0.22), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Badvice menu")
                    .accessibilityHint("Opens casebook, dares, dispatches, and settings")
                    .accessibilityIdentifier("generate.brandMenu")
                }

                Spacer()
            }
            .padding(12)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: Theme.espressoInk.opacity(0.22), radius: 18, y: 9)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceHeader
            laneSelector
            Divider().overlay(secondaryText.opacity(0.12))
            voiceSelector
            Divider().overlay(secondaryText.opacity(0.12))
            contextComposer
            Divider().overlay(secondaryText.opacity(0.12))
            intensityDial
            primaryActions
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(cardColor.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.14), .clear, Color.black.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.44), accent.opacity(0.12), secondaryAccent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Theme.cardShadow(for: settings.theme).color.opacity(0.24), radius: 18, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generate.commandCard")
    }

    private var workspaceHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isGenerating ? "BUILDING THE TAKE" : "COMMISSION A TAKE")
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Text(viewModel.current == nil ? "Set the brief" : "Tune the next dispatch")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(primaryText)
                Text(viewModel.isGenerating ? "The local bureau is arranging its worst instincts." : "A little context makes the wrong answer feel personal.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Theme.copperEmbossGradient)
                    .frame(width: 45, height: 45)
                    .shadow(color: Theme.copperFoilDeep.opacity(0.3), radius: 8, y: 4)
                Image(systemName: viewModel.isGenerating ? "hourglass" : selectedVoice.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.espressoInk)
            }
            .accessibilityHidden(true)
        }
        .padding(.bottom, 18)
    }

    private var laneSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectorHeader(
                title: "Lane",
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

    private var contextComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Context")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("OPTIONAL")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(secondaryText.opacity(0.7))

                Spacer(minLength: 0)

                if !viewModel.scenarioText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        viewModel.scenarioText = ""
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
                }
            }

            Text("One real detail lets the bureau aim its bad judgment.")
                .font(.caption)
                .foregroundStyle(secondaryText)

            TextField("e.g. awkward first date, new manager, group chat", text: $viewModel.scenarioText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont(for: settings.theme))
                .foregroundStyle(primaryText)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(canvas.opacity(0.78))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(secondaryText.opacity(0.14), lineWidth: 1)
                }
                .accessibilityIdentifier("generate.situation")
                .focused($isComposerFocused)

            if viewModel.selectedTone == .friendRoast {
                TextField("Friend's name (optional)", text: $viewModel.friendName)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyFont(for: settings.theme))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canvas.opacity(0.78))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(accent.opacity(0.22), lineWidth: 1)
                    }
                    .accessibilityIdentifier("generate.friendName")
                    .focused($isComposerFocused)
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
            .accessibilityHint("Adjusts how dramatically wrong the local Bureau Engine should be")

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
                    Text(viewModel.isGenerating ? "Building the take…" : viewModel.primaryActionTitle)
                        .font(.body.weight(.bold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.black))
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, 18)
            }
            .buttonStyle(CopperPillButtonStyle(isEnabled: !viewModel.isGenerating, reduceMotion: reduceMotion))
            .disabled(viewModel.isGenerating)
            .accessibilityIdentifier("generate.primary")
            .accessibilityHint("Generates a new advice card using the selected lane and voice")

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

            ZStack {
                if let record = viewModel.current, !viewModel.isGenerating {
                    AdviceCardView(
                        record: record,
                        theme: settings.theme,
                        reduceMotion: reduceMotion,
                        sourceBadgeText: viewModel.generationSourceBadgeText
                    )
                    .accessibilityIdentifier("advice.card")
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
                revisionControls
                realityCheck
                votingRow
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
                resultActionButton(title: "Remix", systemImage: "arrow.triangle.2.circlepath", identifier: "generate.remix", action: remixAdvice)
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
                    Text("Instant local rewrites—no model required.")
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
                        Text("Reveal the useful local counterpoint")
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
                    Text("Nothing sealed yet.")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(primaryText)
                    Text("Your first questionable decision is one tap away.")
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
                    Text("Studio details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text("Progress, the failure note, and battles")
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
        isComposerFocused = false
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        Task {
            await viewModel.generate()
            onDataChanged()
        }
    }

    private func surpriseAndGenerate() {
        isComposerFocused = false
        viewModel.surpriseMeAndGenerate()
        onDataChanged()
    }

    private func generateDailyDrop() {
        isComposerFocused = false
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
