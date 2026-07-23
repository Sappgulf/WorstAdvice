import SwiftUI

struct ExploreTabView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void

    @State private var trendingAdvice: [TrendingAdvice] = Self.demoTrendingAdvice
    @State private var searchText = ""
    @State private var selectedCategory: AdviceCategory?
    @State private var selectedTone: ToneMode?
    @AppStorage(AppTab.explore.focusModeStorageKey) private var isFocusMode = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardFill: Color { Theme.cardColor(for: settings.theme).opacity(0.84) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isFilterActive: Bool {
        selectedCategory != nil
            || selectedTone != nil
            || !normalizedSearchText.isEmpty
    }
    private var isMotionReduced: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    var filteredTrending: [TrendingAdvice] {
        var result = trendingAdvice
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if let tone = selectedTone {
            result = result.filter { $0.tone == tone }
        }
        if !normalizedSearchText.isEmpty {
            result = result.filter { $0.adviceLine.localizedCaseInsensitiveContains(normalizedSearchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient(for: settings.theme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroSection

                        exploreCommandCard

                        if !isFocusMode {
                            filterSection
                        }

                        if filteredTrending.isEmpty {
                            emptyStateView
                        } else {
                            starterIdeasSection
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
                }
                .trackScrollForTabBar()
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { exploreToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search starter ideas")
            .onAppear {
                tabBarVisible.wrappedValue = true
            }
            .task { await loadTrending() }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.largeCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.48)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Explore Ideas")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                    Text("Browse starter combinations, tune the filters, then send the best setup straight into Advice.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }

            HStack(spacing: 10) {
                metricPill(value: "\(filteredTrending.count)", label: "Results")
                metricPill(
                    value: selectedCategory?.title ?? "All",
                    label: "Category"
                )
                metricPill(
                    value: selectedTone?.title ?? "Any",
                    label: "Tone"
                )
            }
        }
        .padding(18)
        .background(heroCardShell)
    }

    private var exploreCommandCard: some View {
        TabCommandCard(
            eyebrow: "Explore Command",
            title: exploreCommandTitle,
            detail: exploreCommandDetail,
            systemImage: "safari.fill",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: Theme.cardColor(for: settings.theme)
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(
                    title: "Ideas",
                    value: "\(filteredTrending.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
                TabCommandMetric(
                    title: "Category",
                    value: selectedCategory?.title ?? "All",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
                TabCommandMetric(
                    title: "Tone",
                    value: selectedTone?.title ?? "Any",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
            }
        } actions: {
            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: explorePrimaryActionTitle,
                    systemImage: isFilterActive && filteredTrending.isEmpty ? "xmark.circle.fill" : "sparkles",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "explore.command.primary"
                ) {
                    if isFilterActive && filteredTrending.isEmpty {
                        clearFilters()
                    } else {
                        openFirstVisibleIdea()
                    }
                }

                TabCommandActionButton(
                    title: "Reset",
                    systemImage: "arrow.counterclockwise",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    isDisabled: !isFilterActive,
                    accessibilityIdentifier: "explore.command.reset"
                ) {
                    clearFilters()
                }
            }
        }
        .accessibilityIdentifier("explore.command.card")
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            filterRow(
                title: "Categories",
                resetTitle: "All Categories",
                resetIdentifier: "explore.filter.categories.reset",
                isResetSelected: selectedCategory == nil
            ) {
                resetCategoryFilter()
            } chips: {
                ForEach(Array(AdviceCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    FilterChip(
                        title: category.title,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        accent: accent,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        accessibilityIdentifier: "explore.filter.categories.chip.\(index)",
                        buttonText: buttonText
                    ) {
                        selectCategory(category)
                    }
                }
            }

            filterRow(
                title: "Tones",
                resetTitle: "All Tones",
                resetIdentifier: "explore.filter.tones.reset",
                isResetSelected: selectedTone == nil
            ) {
                resetToneFilter()
            } chips: {
                ForEach(Array(ToneMode.allCases.enumerated()), id: \.element.id) { index, tone in
                    FilterChip(
                        title: tone.title,
                        icon: tone.isPremium ? "sparkles" : nil,
                        isSelected: selectedTone == tone,
                        accent: accent,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        accessibilityIdentifier: "explore.filter.tones.chip.\(index)",
                        buttonText: buttonText
                    ) {
                        selectTone(tone)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        TabEmptyStatePanel(
            icon: "magnifyingglass",
            title: "No starter ideas found",
            message: "Try adjusting your filters or search terms.",
                accent: accent,
                primaryText: primaryText,
                secondaryText: secondaryText,
                cardColor: cardFill,
                reduceMotion: isMotionReduced
                ) {
            if isFilterActive {
                TabCommandActionButton(
                    title: "Clear filters",
                    systemImage: "xmark.circle.fill",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "explore.clearFilters"
                ) {
                    clearFilters()
                }
            } else {
                TabCommandActionButton(
                    title: "Generate fresh advice",
                    systemImage: "sparkles",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "explore.generateFresh"
                ) {
                    onJumpToGenerate(.random, .random)
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                }
            }
        }
        .accessibilityIdentifier("explore.emptyState")
    }

    private var starterIdeasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Starter Ideas", systemImage: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(primaryText)

                LazyVStack(spacing: 16) {
                    ForEach(filteredTrending) { advice in
                        TrendingAdviceCard(
                        advice: advice,
                        analyticsId: "explore.trending.\(advice.id)",
                        accent: accent,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        cardFill: cardFill
                    ) {
                        openTrendingAdvice(advice)
                    }
                }
            }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Community", systemImage: "globe")
                        .font(.headline)
                        .foregroundStyle(primaryText)

                GlobalCommunityFeedView(
                    social: social,
                    settings: settings,
                    onJumpToGenerate: onJumpToGenerate
                )
                .frame(minHeight: 320)
                .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                        .fill(cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent.opacity(0.1), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.screen)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                                .stroke(accent.opacity(0.14), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                                .fill(accent.opacity(0.08))
                                .frame(height: 2),
                            alignment: .top
                        )
                )
            }
        }
    }

    private var exploreCommandTitle: String {
        if filteredTrending.isEmpty {
            return "Reset the idea board"
        }
        if isFilterActive {
            return "Turn this filter into a generation setup"
        }
        return "Pick a starter and jump into Advice"
    }

    private var exploreCommandDetail: String {
        if filteredTrending.isEmpty {
            return "No seeded ideas match the current search and filters. Reset the board or loosen one filter."
        }
        if isFilterActive {
            return "The board is narrowed to \(filteredTrending.count) idea\(filteredTrending.count == 1 ? "" : "s"). Open one to carry its category and tone into Advice."
        }
        return "Explore is a launchpad, not a passive feed. Each idea opens Advice with the matching category and tone."
    }

    private var explorePrimaryActionTitle: String {
        if filteredTrending.isEmpty && isFilterActive {
            return "Clear Filters"
        }
        return "Use First Idea"
    }

    @ToolbarContentBuilder
    private var exploreToolbar: some ToolbarContent {
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

    private func loadTrending() async {
        guard trendingAdvice.isEmpty else { return }
        trendingAdvice = Self.demoTrendingAdvice
    }

    private func resetCategoryFilter() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        selectedCategory = nil
    }

    private func resetToneFilter() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        selectedTone = nil
    }

    private func selectCategory(_ category: AdviceCategory) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        selectedCategory = category
    }

    private func selectTone(_ tone: ToneMode) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        selectedTone = tone
    }

    private func clearFilters() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        selectedCategory = nil
        selectedTone = nil
        searchText = ""
    }

    private func openFirstVisibleIdea() {
        guard let advice = filteredTrending.first else {
            clearFilters()
            return
        }
        openTrendingAdvice(advice)
    }

    private func openTrendingAdvice(_ advice: TrendingAdvice) {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onJumpToGenerate(advice.category, advice.tone)
    }

    private func filterRow(
        title: String,
        resetTitle: String,
        resetIdentifier: String,
        isResetSelected: Bool,
        resetAction: @escaping () -> Void,
        @ViewBuilder chips: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(primaryText)
                Spacer()
                TabCommandActionButton(
                    title: resetTitle,
                    systemImage: isResetSelected ? "line.3.horizontal.decrease.circle" : "xmark.circle.fill",
                    accent: isResetSelected ? accent : secondaryText,
                    buttonText: isResetSelected ? buttonText : secondaryText,
                    prominent: false,
                    isDisabled: isResetSelected,
                    minHeight: 32,
                    action: resetAction
                )
                .accessibilityIdentifier(resetIdentifier)
                .frame(width: 126)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chips()
                }
                .padding(.trailing, 4)
            }
        }
        .padding(16)
        .background(cardShell)
    }

    private var heroCardShell: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(cardFill.opacity(1))
            .overlay(
                LinearGradient(
                    colors: [accent.opacity(0.16), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.heroCornerRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.16), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1.8),
                alignment: .top
            )
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var cardShell: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.14), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(accent.opacity(0.16), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(accent.opacity(0.07))
                    .frame(height: 1.4),
                alignment: .top
            )
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accent.opacity(0.18))
                .frame(height: 1)
        }
    }

    private static var demoTrendingAdvice: [TrendingAdvice] {
        [
            TrendingAdvice(
                id: UUID(),
                adviceLine: "Just skip the meeting and call it 'executive delegation.'",
                category: .career,
                tone: .corporateConsultant,
                likeCount: 142,
                shareCount: 38,
                generatedAt: Date()
            ),
            TrendingAdvice(
                id: UUID(),
                adviceLine: "If they haven't texted back in 3 hours, they've already found someone else.",
                category: .dating,
                tone: .toxicBestFriend,
                likeCount: 256,
                shareCount: 89,
                generatedAt: Date()
            ),
            TrendingAdvice(
                id: UUID(),
                adviceLine: "The universe will provide if you visualize hard enough.",
                category: .spirituality,
                tone: .wizard,
                likeCount: 98,
                shareCount: 45,
                generatedAt: Date()
            )
        ]
    }
}

    struct FilterChip: View {
        let title: String
        var icon: String? = nil
        let isSelected: Bool
        var accent: Color = .accentColor
        var primaryText: Color = .primary
        var secondaryText: Color = .secondary
        let accessibilityIdentifier: String
        let buttonText: Color
        let action: () -> Void

        var body: some View {
        TabCommandActionButton(
            title: title,
            systemImage: icon,
            accent: accent,
            buttonText: buttonText,
            prominent: isSelected,
            minHeight: 34
        ) {
            action()
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TrendingAdviceCard: View {
    let advice: TrendingAdvice
    let analyticsId: String
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SectionShell(accent: accent, cardColor: cardFill.opacity(0.96)) {
                HStack {
                    Label(advice.category.title, systemImage: advice.category.icon)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Label(advice.tone.title, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(advice.adviceLine)
                        .font(.body)
                        .foregroundStyle(primaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Label("\(advice.likeCount)", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Label("\(advice.shareCount)", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.shellSectionCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(analyticsId)
    }
}
