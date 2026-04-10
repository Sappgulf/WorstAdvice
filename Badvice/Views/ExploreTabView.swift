import SwiftUI

struct ExploreTabView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void
    
    @State private var trendingAdvice: [TrendingAdvice] = Self.demoTrendingAdvice
    @State private var searchText = ""
    @State private var selectedCategory: AdviceCategory?
    @State private var selectedTone: ToneMode?

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardFill: Color { Theme.cardColor(for: settings.theme).opacity(0.84) }
    private var isFilterActive: Bool {
        selectedCategory != nil
            || selectedTone != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var filteredTrending: [TrendingAdvice] {
        var result = trendingAdvice
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if let tone = selectedTone {
            result = result.filter { $0.tone == tone }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.adviceLine.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    
                    filterSection
                    
                    if filteredTrending.isEmpty {
                        emptyStateView
                    } else {
                        trendingSection
                    }
                }
                .padding()
            }
            .navigationTitle("Explore")
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search trending advice")
            .task { await loadTrending() }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    Text("Trending Now")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                    Text("Browse what the crowd is actually reading, voting, and remixing.")
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
                ForEach(Array(AdviceCategory.concrete.prefix(6).enumerated()), id: \.element.id) { index, category in
                    FilterChip(
                        title: category.title,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        accessibilityIdentifier: "explore.filter.categories.chip.\(index)"
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
                ForEach(Array(ToneMode.concrete.prefix(7).enumerated()), id: \.element.id) { index, tone in
                    FilterChip(
                        title: tone.title,
                        icon: tone.isPremium ? "sparkles" : nil,
                        isSelected: selectedTone == tone,
                        accessibilityIdentifier: "explore.filter.tones.chip.\(index)"
                    ) {
                        selectTone(tone)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(accent)
            Text("No trending advice found")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("Try adjusting your filters or search terms.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            if isFilterActive {
                Button {
                    clearFilters()
                } label: {
                    Label("Clear filters", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(.white)
                .accessibilityIdentifier("explore.clearFilters")
            } else {
                Button {
                    onJumpToGenerate(.random, .random)
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    Label("Generate fresh advice", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(.white)
                .accessibilityIdentifier("explore.generateFresh")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardShell)
        .accessibilityIdentifier("explore.emptyState")
    }
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                .background(cardShell)
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
                Button(resetTitle, action: resetAction)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isResetSelected ? accent : secondaryText)
                    .accessibilityIdentifier(resetIdentifier)
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
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(cardFill)
            .overlay(
                LinearGradient(
                    colors: [accent.opacity(0.16), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.opacity(0.11), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var cardShell: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(accent.opacity(0.08), lineWidth: 1)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill.opacity(0.84))
        )
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
    let accessibilityIdentifier: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(advice.category.title, systemImage: advice.category.icon)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Label(advice.tone.title, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                
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
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        LinearGradient(
                            colors: [accent.opacity(0.14), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(accent.opacity(0.09), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(analyticsId)
    }
}
