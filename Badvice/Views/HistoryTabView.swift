import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    init(scale: CGFloat = 0.95) { self.scale = scale }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: Theme.animFast), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scaled: ScaleButtonStyle { ScaleButtonStyle() }
    static func scaled(_ scale: CGFloat) -> ScaleButtonStyle { ScaleButtonStyle(scale: scale) }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage(AppTab.history.focusModeStorageKey) private var isFocusMode = false
    var onUseRecord: (AdviceRecord) -> Void
    var onDataChanged: () -> Void
    var onJumpToGenerate: (() -> Void)? = nil

    @State private var showingClearConfirmation = false
    @State private var historyListAppeared = false
    @State private var activeToast: ToastMessage? = nil
    @State private var hallOfFameExpanded = false

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }

    private var historyCommandTitle: String {
        if viewModel.history.isEmpty {
            return "Start your chaos archive"
        }
        if viewModel.filteredHistory.isEmpty {
            return "Your search narrowed the archive to zero"
        }
        if viewModel.rankingMode != .recent {
            return "You are ranking for signal, not recency"
        }
        return "Reuse your strongest disasters"
    }

    private var historyCommandDetail: String {
        if viewModel.history.isEmpty {
            return "Every generated card lands here first. Once you have history, this tab becomes your replay and save surface."
        }
        if viewModel.filteredHistory.isEmpty {
            return "Clear the current filters to get the full history back, or jump to Generate and create a fresh one."
        }
        if viewModel.rankingMode != .recent {
            return "Sorted by \(viewModel.rankingMode.title.lowercased()). Use this to surface what actually landed, not just what happened last."
        }
        return "Double-tap to save, swipe to reuse, or sort the archive to find your best recurring mistakes."
    }

    private var historyPrimaryActionTitle: String {
        if viewModel.history.isEmpty {
            return "Generate Advice"
        }
        if viewModel.filteredHistory.isEmpty || viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
            return "Clear Filters"
        }
        return "Open Generate"
    }

    private var historyPrimaryActionIcon: String {
        if viewModel.history.isEmpty {
            return "sparkles"
        }
        if viewModel.filteredHistory.isEmpty || viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
            return "line.3.horizontal.decrease.circle"
        }
        return "arrow.uturn.left.circle.fill"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if viewModel.history.isEmpty {
                    historyEmptyState
                } else {
                    VStack(spacing: 0) {
                        // Search + controls header
                        VStack(spacing: 8) {
                            if !isFocusMode {
                                InlineSearchField(
                                    text: $viewModel.searchText,
                                    prompt: "Search history",
                                    accent: accent,
                                    secondaryText: secondaryText,
                                    surfaceColor: cardColor
                                )

                                HStack(spacing: 10) {
                                    Picker("Sort", selection: $viewModel.rankingMode) {
                                        ForEach(HistoryViewModel.RankingMode.allCases) { mode in
                                            Text(mode.title).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    Menu {
                                        ForEach(AdviceCategory.concrete) { cat in
                                            Button {
                                                viewModel.selectedCategory = viewModel.selectedCategory == cat ? nil : cat
                                            } label: {
                                                Label(cat.title, systemImage: viewModel.selectedCategory == cat ? "checkmark" : cat.icon)
                                            }
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            showingClearConfirmation = true
                                        } label: {
                                            Label("Clear History", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(secondaryText)
                                            .frame(
                                                width: Theme.compactIconButtonSize,
                                                height: Theme.compactIconButtonSize
                                            )
                                            .background(
                                                .ultraThinMaterial,
                                                in: RoundedRectangle(
                                                    cornerRadius: Theme.compactCornerRadius,
                                                    style: .continuous
                                                )
                                            )
                                    }
                                    .accessibilityLabel("History options")
                                }

                                if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                                    historyQuickActions
                                        .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .top)))
                                }

                                historyCategoryChips

                                // Hall of Fame card
                                hallOfFameSection
                                    .padding(.horizontal, 0)

                                // Stats strip
                                let filtersActive = viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty
                                HStack {
                                    Label("\(viewModel.likedCount)", systemImage: "hand.thumbsup.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(accent)
                                    Text("liked")
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                    Spacer()
                                    HStack(spacing: 3) {
                                        if filtersActive {
                                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(accent)
                                                .transition(.opacity.combined(with: .scale(scale: 0.7)))
                                        }
                                        Text("\(viewModel.filteredHistory.count) shown")
                                            .font(.caption.weight(filtersActive ? .semibold : .regular).monospacedDigit())
                                            .foregroundStyle(filtersActive ? accent : secondaryText)
                                    }
                                    .animation(isMotionReduced ? nil : .spring(response: Theme.animFast, dampingFraction: 0.7), value: filtersActive)
                                    Spacer()
                                    Text("disliked")
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                    Label("\(viewModel.dislikedCount)", systemImage: "hand.thumbsdown.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(secondaryText.opacity(0.7))
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .animation(isMotionReduced ? nil : .easeInOut(duration: Theme.animFast), value: viewModel.selectedCategory == nil && viewModel.searchText.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                        historyCommandCard
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        if viewModel.filteredHistory.isEmpty {
                            historyNoResultsState
                        } else {
                            historyList
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { focusModeToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    viewModel.clearHistory()
                    onDataChanged()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all history items.")
            }
            .onAppear {
                Task(priority: .utility) {
                    viewModel.loadIfNeeded()
                }
                HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                tabBarVisible.wrappedValue = true
                animateHistoryListIfNeeded()
            }
            .onChange(of: viewModel.rankingMode) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
        .toast(item: $activeToast, accentColor: accent)
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

    // MARK: - Hall of Fame

    @ViewBuilder
    private var hallOfFameSection: some View {
        let shared = generateViewModel.leaderboardTopShared
        let copied = generateViewModel.leaderboardTopCopied
        let liked  = generateViewModel.leaderboardTopLiked
        let hasData = !shared.isEmpty || !copied.isEmpty || !liked.isEmpty
        if hasData {
            SectionShell(accent: accent, cardColor: cardColor) {
                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        hallOfFameExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(accent.opacity(0.14)).frame(width: 32, height: 32)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        Text("Hall of Fame")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Image(systemName: hallOfFameExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                }
                .buttonStyle(.plain)
            } content: {
                if hallOfFameExpanded {
                    VStack(spacing: 8) {
                        hallOfFameRow(title: "Most Shared", items: shared, icon: "square.and.arrow.up", valueLabel: { "x\($0.shareCountValue)" })
                        hallOfFameRow(title: "Most Copied", items: copied, icon: "doc.on.doc", valueLabel: { "x\($0.copyCountValue)" })
                        hallOfFameRow(title: "Liked", items: liked, icon: "hand.thumbsup.fill", valueLabel: { _ in "Saved" })
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func hallOfFameRow(title: String, items: [AdviceRecord], icon: String, valueLabel: @escaping (AdviceRecord) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { idx, record in
                HStack(spacing: 8) {
                    Text("\(idx + 1)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(secondaryText)
                        .frame(width: 16)
                    Text(record.adviceLine)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(primaryText)
                    Spacer(minLength: 0)
                    Text(valueLabel(record))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor.opacity(0.85), cardColor.opacity(0.52)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredHistory, id: \.id) { record in
                    historyRow(record)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .trackScrollForTabBar()
        .refreshable {
            viewModel.reload()
            HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
        }
        .opacity(historyListAppeared ? 1 : 0)
        .offset(y: historyListAppeared ? 0 : 12)
    }

    private func historyRow(_ record: AdviceRecord) -> some View {
        Button {
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            onUseRecord(record)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent.opacity(0.6))
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.adviceLine)
                        .font(.body.weight(.medium))
                        .foregroundStyle(primaryText)
                        .lineLimit(3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Label(record.category.title, systemImage: record.category.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))

                        Text(record.tone.title)
                            .font(.caption)
                            .foregroundStyle(secondaryText)

                        Spacer(minLength: 0)

                        if record.vote == .like {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption2).foregroundStyle(accent)
                        } else if record.vote == .dislike {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.caption2).foregroundStyle(accent.opacity(0.6))
                        }
                        if record.isFavorite {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        if record.aftermathNote != nil {
                            Image(systemName: "book.pages")
                                .font(.caption2).foregroundStyle(accent.opacity(0.6))
                        }
                    }
                }

                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent.opacity(0.4))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cardColor.opacity(0.84), cardColor.opacity(0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [accent.opacity(0.08), .clear, .black.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(.black.opacity(0.04))
                    .frame(height: 1),
                alignment: .top
            )
            .shadow(
                color: .black.opacity(0.08),
                radius: 7,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                viewModel.saveFromHistory(record)
                onDataChanged()
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                activeToast = ToastMessage(message: "Saved!", style: .success)
            } label: {
                Label("Save", systemImage: "bookmark")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onUseRecord(record) } label: {
                Label("Use", systemImage: "arrow.forward")
            }
            .tint(accent)
        }
        .contextMenu {
            Button { onUseRecord(record) } label: {
                Label("Use", systemImage: "arrow.forward")
            }
            Button {
                viewModel.saveFromHistory(record)
                onDataChanged()
                activeToast = ToastMessage(message: "Saved!", style: .success)
            } label: {
                Label("Save", systemImage: "bookmark")
            }
            Button { UIPasteboard.general.string = record.adviceLine } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .onTapGesture(count: 2) {
            viewModel.saveFromHistory(record)
            onDataChanged()
            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
            activeToast = ToastMessage(message: "Saved!", style: .success)
        }
        .accessibilityAction(named: "Save") {
            viewModel.saveFromHistory(record)
            onDataChanged()
            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
            activeToast = ToastMessage(message: "Saved!", style: .success)
        }
    }

    private var historyCommandCard: some View {
        TabCommandCard(
            eyebrow: "History Command",
            title: historyCommandTitle,
            detail: historyCommandDetail,
            systemImage: "clock.arrow.circlepath",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(
                    title: "History",
                    value: "\(viewModel.history.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
                TabCommandMetric(
                    title: "Shown",
                    value: "\(viewModel.filteredHistory.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
            }
        } actions: {
            VStack(spacing: 10) {
                TabCommandActionButton(
                    title: historyPrimaryActionTitle,
                    systemImage: historyPrimaryActionIcon,
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "history.command.primary"
                ) {
                    if viewModel.history.isEmpty {
                        onJumpToGenerate?()
                    } else if viewModel.filteredHistory.isEmpty || viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                        viewModel.selectedCategory = nil
                        viewModel.searchText = ""
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    } else {
                        onJumpToGenerate?()
                    }
                }
            }
        }
    }

    private var historyEmptyState: some View {
        TabEmptyStatePanel(
            icon: "clock.arrow.circlepath",
            title: "No History Yet",
            message: "No bad decisions on record yet.\nThat's about to change.",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor,
            reduceMotion: isMotionReduced
        ) {
            TabCommandActionButton(
                title: "Generate Advice",
                systemImage: "sparkles",
                accent: accent,
                buttonText: buttonText,
                accessibilityIdentifier: "history.generate"
            ) {
                onJumpToGenerate?()
            }
        }
    }

    private var historyQuickActions: some View {
        HStack(spacing: 10) {
            TabCommandActionButton(
                title: "Clear Filters",
                systemImage: "line.3.horizontal.decrease.circle",
                accent: accent,
                buttonText: buttonText,
                prominent: false
            ) {
                viewModel.selectedCategory = nil
                viewModel.searchText = ""
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
    }

    private var historyCategoryChips: some View {
        AdviceCategoryFilterChips(
            selectedCategory: $viewModel.selectedCategory,
            accent: accent,
            secondaryText: secondaryText,
            hapticsEnabled: settings.hapticsEnabled,
            reduceMotion: isMotionReduced,
            accessibilityPrefix: "history.category"
        )
    }

    private var historyNoResultsState: some View {
        TabEmptyStatePanel(
            icon: "magnifyingglass",
            title: "No matches found",
            message: "Try a different search or category.",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor,
            reduceMotion: isMotionReduced
        ) {
            if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                TabCommandActionButton(
                    title: "Clear Filters",
                    systemImage: "arrow.uturn.backward",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    accessibilityIdentifier: "history.clearFilters"
                ) {
                    viewModel.selectedCategory = nil
                    viewModel.searchText = ""
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
            }
        }
    }

    private func animateHistoryListIfNeeded() {
        guard !historyListAppeared else { return }
        if isMotionReduced {
            historyListAppeared = true
        } else {
            withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                historyListAppeared = true
            }
        }
    }
}
