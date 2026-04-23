import SwiftUI

struct QuotesTabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onJumpToGenerate: (() -> Void)? = nil
    var onOpenTab: ((AppTab) -> Void)? = nil

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var activeToast: ToastMessage? = nil
    @State private var showQuoteSpotlight = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }
    private var quotesCommandTitle: String {
        if viewModel.filteredQuotes.isEmpty {
            return "Rebuild your quote stream"
        }
        if social.currentUser == nil {
            return "Set up sharing for quotes"
        }
        if social.friends.isEmpty {
            return "Add someone to share with"
        }
        if !showQuoteSpotlight {
            return "Open today's spotlight"
        }
        if social.feedPosts.isEmpty {
            return "Share today's quote"
        }
        return "Keep the quote ritual moving"
    }
    private var quotesCommandDetail: String {
        if viewModel.filteredQuotes.isEmpty {
            return "Your current filters are too narrow or the library needs fresh material. Clear the filters or jump back to Generate."
        }
        if social.currentUser == nil {
            return "Today's quote is ready. Finish your Friends profile to share it, post it, and turn this tab into a daily ritual instead of a dead end."
        }
        if social.friends.isEmpty {
            return "Your profile exists, but you still need at least one friend before quote sharing becomes useful."
        }
        if !showQuoteSpotlight {
            return "The daily quote is strongest when you stop and unpack it. Open the spotlight, react, then share it or spin it into a collab."
        }
        if social.feedPosts.isEmpty {
            return "Spotlight is active. Ship this quote into Friends to wake up the feed and make the tab feel connected to the rest of the app."
        }
        return "You have today's quote in focus. Rate it, share it, or send it into Friends while the ritual is active."
    }
    private var quotesPrimaryActionTitle: String {
        if viewModel.filteredQuotes.isEmpty {
            return viewModel.selectedCategory == nil ? "Generate Advice" : "Clear Filters"
        }
        if !social.availability.isAccountAvailable || social.currentUser == nil {
            return "Open Friends"
        }
        if social.friends.isEmpty {
            return "Open Friends"
        }
        if !showQuoteSpotlight {
            return "Open Spotlight"
        }
        return "Share to Friends"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        quotesCommandCard
                            .padding(.horizontal, 16)

                        quoteHeaderCard
                            .padding(.horizontal, 16)

                        dailyQuoteHero
                            .padding(.horizontal, 16)

                        dailyRitualCard
                            .padding(.horizontal, 16)

                        quoteSpotlightCard
                            .padding(.horizontal, 16)

                        if !social.availability.isAvailable {
                            QuotesInlineBanner(
                                text: social.availability.message,
                                accent: accent,
                                secondaryText: secondaryText,
                                cardColor: cardColor
                            )
                            .padding(.horizontal, 16)
                        } else if social.currentUser == nil {
                            QuotesInlineBanner(
                                text: "Finish your Friends profile to share quotes and start collabs from here.",
                                accent: accent,
                                secondaryText: secondaryText,
                                cardColor: cardColor
                            )
                            .padding(.horizontal, 16)
                        }

                        // Sort + search row
                        VStack(spacing: 10) {
                            InlineSearchField(
                                text: $viewModel.searchText,
                                prompt: "Search quotes",
                                accent: accent,
                                secondaryText: secondaryText,
                                surfaceColor: cardColor
                            )

                            HStack(spacing: 10) {
                                Picker("Sort", selection: $viewModel.rankingMode) {
                                    ForEach(QuoteRankingMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Menu {
                                    Button {
                                        viewModel.selectedCategory = nil
                                    } label: {
                                        if viewModel.selectedCategory == nil {
                                            Label("All", systemImage: "checkmark")
                                        } else { Text("All") }
                                    }
                                    ForEach(AdviceCategory.concrete) { cat in
                                        Button { viewModel.selectedCategory = cat } label: {
                                            if viewModel.selectedCategory == cat {
                                                Label(cat.title, systemImage: "checkmark")
                                            } else { Text(cat.title) }
                                        }
                                    }
                                } label: {
                                    Image(systemName: viewModel.selectedCategory == nil
                                          ? "line.3.horizontal.decrease.circle"
                                          : "line.3.horizontal.decrease.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(viewModel.selectedCategory == nil ? secondaryText : accent)
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
                                .accessibilityLabel("Filter quotes by category")
                            }

                            // Category quick filters
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(AdviceCategory.concrete) { category in
                                        let isSelected = viewModel.selectedCategory == category
                                        Button(category.title) {
                                            viewModel.selectedCategory = isSelected ? nil : category
                                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(isSelected ? accent.opacity(0.2) : secondaryText.opacity(0.12))
                                        )
                                        .foregroundStyle(isSelected ? accent : secondaryText)
                                        .scaleEffect(isSelected ? 1.06 : 1.0)
                                        .animation(.spring(response: 0.22, dampingFraction: 0.58), value: isSelected)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

#if DEBUG
                            HStack(spacing: 10) {
                                Label("Source", systemImage: "ladybug")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryText)
                                Picker("Quote Source", selection: $viewModel.debugSourceFilter) {
                                    ForEach(QuoteSourceDebugFilter.allCases) { filter in
                                        Text(filter.title).tag(filter)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(accent)

                                Spacer()

                                Text(viewModel.debugSourceFilter.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(accent.opacity(0.14))
                                    )
                            }
                            .padding(.horizontal, 2)
#endif

                            // Stats strip
                            HStack {
                                Label("\(viewModel.likedCount)", systemImage: "hand.thumbsup.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accent)
                                Text("liked")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
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
                        .padding(.horizontal, 16)

                        // Quote rows
                        let quotes = viewModel.filteredQuotes
                        if quotes.isEmpty {
                            QuotesEmptyState(theme: settings.theme, reduceMotion: isMotionReduced)
                                .padding(.horizontal, 16)
                            if viewModel.selectedCategory != nil {
                                Button {
                                    viewModel.selectedCategory = nil
                                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                                } label: {
                                    Label("Show All Categories", systemImage: "line.3.horizontal.decrease.circle")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .tint(accent)
                                .padding(.horizontal, 16)
                                .accessibilityIdentifier("quotes.showAllCategories")
                            }
                            Button { onJumpToGenerate?() } label: {
                                Label("Generate Advice", systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("quotes.generate")
                        } else {
                            ForEach(quotes) { quote in
                                quoteRow(quote)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .trackScrollForTabBar()
            }
            .navigationTitle("Quotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                Task(priority: .utility) {
                    viewModel.loadIfNeeded()
                }
                tabBarVisible.wrappedValue = true
            }
            .onChange(of: viewModel.rankingMode) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    private var quotesCommandCard: some View {
        let dailyQuote = viewModel.dailyQuote
        return TabCommandCard(
            eyebrow: "Quote Command",
            title: quotesCommandTitle,
            detail: quotesCommandDetail,
            systemImage: "quote.bubble.fill",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(title: "Visible", value: "\(viewModel.filteredQuotes.count)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: "Library", value: "\(viewModel.allQuotes.count)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: "Today", value: viewModel.vote(for: dailyQuote) == .none ? "Fresh" : "Rated", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
            }
        } actions: {
            VStack(spacing: 10) {
                Button(quotesPrimaryActionTitle) {
                    performPrimaryQuotesAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(buttonText)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .accessibilityIdentifier("quotes.command.primary")

                HStack(spacing: 10) {
                    Button("Daily Quote") {
                        showQuoteSpotlight = true
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .accessibilityIdentifier("quotes.command.daily")

                    Button("Generate") {
                        onJumpToGenerate?()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .accessibilityIdentifier("quotes.command.generate")
                }
            }
        }
    }

    private var quoteHeaderCard: some View {
        let filteredCount = viewModel.filteredQuotes.count
        let libraryCount = viewModel.allQuotes.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quote Desk")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("A cleaner read on the daily line, the strongest signals, and the best material in the bank.")
                        .font(.footnote)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.12))
                    )
            }

            HStack(spacing: 10) {
                quoteMetricPill(title: "Visible", value: "\(filteredCount)")
                quoteMetricPill(title: "Library", value: "\(libraryCount)")
                quoteMetricPill(title: "Votes", value: "\(viewModel.likedCount + viewModel.dislikedCount)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func quoteMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private func quoteRow(_ quote: BadQuote) -> some View {
        let spotlight = viewModel.quoteSpotlightInsight(for: quote)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\u{201C}")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(accent.opacity(0.3))
                    .offset(y: -2)

                Text(quote.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Label(quote.category.title, systemImage: quote.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))

                Text("•")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(secondaryText.opacity(0.65))

                Text(quote.source)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }

            Text(spotlight)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .lineLimit(2)

            HStack(spacing: 10) {
                voteButtons(for: quote)
                Spacer(minLength: 8)
                quoteActionsMenu(for: quote)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.09), lineWidth: 1)
        )
        .contextMenu {
            Button { copyQuote(quote, isDaily: false) } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { shareQuote(quote, isDaily: false) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .onTapGesture(count: 2) {
            viewModel.toggleVote(.like, for: quote)
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        }
    }

    private var dailyQuoteHero: some View {
        let dailyQuote = viewModel.dailyQuote
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.18),
                            cardColor,
                            cardColor.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                )

            Text("\u{201C}")
                .font(.system(size: 92, weight: .heavy, design: .serif))
                .foregroundStyle(accent.opacity(0.18))
                .offset(x: 14, y: -10)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Daily pick")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                    Spacer()
                }
                .padding(.bottom, 12)

                Text(dailyQuote.text)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(dailyQuote.source)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(secondaryText)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        let heroVote = viewModel.vote(for: dailyQuote)
                        Button {
                            viewModel.toggleVote(.like, for: dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: heroVote == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .accessibilityLabel("Like quote")

                        Button {
                            viewModel.toggleVote(.dislike, for: dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: heroVote == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .accessibilityLabel("Dislike quote")
                    }
                    Spacer()
                    Button {
                        showQuoteSpotlight = true
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .accessibilityLabel("Open quote spotlight")

                    Button { copyQuote(dailyQuote, isDaily: true) } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .accessibilityLabel("Copy quote")

                    Button { shareQuote(dailyQuote, isDaily: true) } label: {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .accessibilityLabel("Share quote")
                }
                .padding(.top, 16)
            }
            .padding(22)
        }
        .overlay(alignment: .topTrailing) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accent.opacity(0.12), in: Capsule(style: .continuous))
                .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quotes.dailyHero")
        .accessibilityLabel("Bad quote of the day: \(dailyQuote.text) by \(dailyQuote.source)")
        .onTapGesture(count: 2) {
            showQuoteSpotlight = true
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        }
    }

    private var quoteSpotlightCard: some View {
        let quote = viewModel.dailyQuote
        return SectionShell(accent: accent, cardColor: cardColor) {
            HStack {
                Label("Quote Spotlight", systemImage: "sparkle.magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button(showQuoteSpotlight ? "Hide" : "Show") {
                    withAnimation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8)) {
                        showQuoteSpotlight.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("quotes.spotlight.toggle")
            }
        } content: {
            if showQuoteSpotlight {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Theme")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(quote.category.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)

                    Text("Why it hits")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .padding(.top, 6)
                    Text(viewModel.quoteSpotlightInsight(for: quote))
                        .font(.footnote)
                        .foregroundStyle(primaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                        .fill(cardColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                                .stroke(accent.opacity(0.09), lineWidth: 1)
                        )
                )
            } else {
                Text("Tap Show for a quick breakdown of today’s quote.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var dailyRitualCard: some View {
        let dailyQuote = viewModel.dailyQuote
        let hasRated = viewModel.vote(for: dailyQuote) != .none
        let shareStatus = quoteShareStatus
        let shareButtonTitle = quoteShareButtonTitle
        return SectionShell(accent: accent, cardColor: cardColor) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Ritual")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Text("Read it, rate it, then either share it or move it into Friends so the tab becomes a habit instead of a static archive.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } content: {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ritualPill(title: "Read", value: showQuoteSpotlight ? "Open" : "Pending")
                    ritualPill(title: "Rate", value: hasRated ? "Done" : "Pending")
                    ritualPill(title: "Share", value: shareStatus)
                }

                HStack(spacing: 10) {
                    Button(showQuoteSpotlight ? "Close Spotlight" : "Open Spotlight") {
                        withAnimation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8)) {
                            showQuoteSpotlight.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)

                    Button(shareButtonTitle) {
                        if !social.availability.isAccountAvailable || social.currentUser == nil || social.friends.isEmpty {
                            onOpenTab?(.friends)
                        } else {
                            shareQuoteToFriends(dailyQuote)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .foregroundStyle(buttonText)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
    }

    private func ritualPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private var quoteShareStatus: String {
        if !social.availability.isAccountAvailable {
            return "Offline"
        }
        if social.currentUser == nil {
            return "Setup"
        }
        if social.friends.isEmpty {
            return "Find"
        }
        return "Ready"
    }

    private var quoteShareButtonTitle: String {
        quoteShareStatus == "Ready" ? "Share to Friends" : "Open Friends"
    }

    private func copyQuote(_ quote: BadQuote, isDaily: Bool) {
        UIPasteboard.general.string = viewModel.quoteShareText(quote)
        viewModel.trackCopy(quote, isDaily: isDaily)
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        activeToast = ToastMessage(message: "Copied!", style: .success)
    }

    private func shareQuote(_ quote: BadQuote, isDaily: Bool) {
        shareItems = [viewModel.quoteShareText(quote)]
        viewModel.trackShare(quote, isDaily: isDaily)
        showingShareSheet = true
    }

    private func shareQuoteToFriends(_ quote: BadQuote) {
        guard social.socialFeaturesEnabled else {
            activeToast = ToastMessage(
                message: social.availability.isAvailable
                    ? "Finish your Friends profile in Friends to share quotes."
                    : social.availability.message,
                style: .error
            )
            return
        }
        Task {
            await social.shareQuoteToFriends(text: quote.text)
            if let message = social.statusMessage {
                activeToast = ToastMessage(
                    message: message,
                    style: message.lowercased().contains("shared") ? .success : .error
                )
            }
        }
    }

    private func collaborateOnQuote(_ quote: BadQuote) {
        guard social.socialFeaturesEnabled else {
            activeToast = ToastMessage(
                message: social.availability.isAvailable
                    ? "Finish your Friends profile in Friends to start a collab."
                    : social.availability.message,
                style: .error
            )
            return
        }
        social.queueCollabDraft(type: .quote, content: quote.text)
        onOpenTab?(.friends)
        activeToast = ToastMessage(message: "Draft sent to Friends > Collab.", style: .info)
    }

    private func performPrimaryQuotesAction() {
        if viewModel.filteredQuotes.isEmpty {
            if viewModel.selectedCategory != nil {
                viewModel.selectedCategory = nil
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } else {
                onJumpToGenerate?()
            }
            return
        }
        if !social.availability.isAccountAvailable || social.currentUser == nil || social.friends.isEmpty {
            onOpenTab?(.friends)
            return
        }
        if !showQuoteSpotlight {
            showQuoteSpotlight = true
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            return
        }
        shareQuoteToFriends(viewModel.dailyQuote)
    }

    private func voteButtons(for quote: BadQuote) -> some View {
        let neutralFill = accent.opacity(0.14)
        let activeFill = accent.opacity(0.28)
        let voteState = viewModel.vote(for: quote)

        return HStack(spacing: 8) {
            Button {
                viewModel.toggleVote(.like, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: voteState == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(voteState == .like ? activeFill : neutralFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Like quote")

            Button {
                viewModel.toggleVote(.dislike, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: voteState == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(voteState == .dislike ? activeFill : neutralFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dislike quote")
        }
    }

    private func quoteActionsMenu(for quote: BadQuote) -> some View {
        Menu {
            Button { copyQuote(quote, isDaily: false) } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { shareQuote(quote, isDaily: false) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button { shareQuoteToFriends(quote) } label: {
                Label("Share to Friends", systemImage: "person.2.fill")
            }
            .disabled(!social.socialFeaturesEnabled)
            Button { collaborateOnQuote(quote) } label: {
                Label("Collaborate", systemImage: "person.2.badge.plus")
            }
            .disabled(!social.socialFeaturesEnabled)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(secondaryText)
                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
        }
        .accessibilityLabel("Quote actions")
    }
}

struct QuotesInlineBanner: View {
    let text: String
    let accent: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        InlineStatusBanner(
            text: text,
            systemImage: "icloud.slash",
            tint: accent,
            primaryText: secondaryText,
            cardColor: cardColor
        )
    }
}

// MARK: - Friends Tab

enum FriendsSection: String, CaseIterable, Identifiable {
    case friends = "Friends"
    case feed = "Feed"
    case collab = "Collab"

    var id: String { rawValue }
}

enum FriendSearchRelationshipState: Equatable {
    case currentUser
    case existingFriend
    case incomingRequest
    case outgoingRequest
    case blocked
    case addable

    var buttonTitle: String {
        switch self {
        case .currentUser:
            return "This is you"
        case .existingFriend:
            return "Already friends"
        case .incomingRequest:
            return "Check requests"
        case .outgoingRequest:
            return "Pending"
        case .blocked:
            return "Blocked"
        case .addable:
            return "Add friend"
        }
    }

    var detailText: String {
        switch self {
        case .currentUser:
            return "Search for another handle to add someone new."
        case .existingFriend:
            return "You are already connected."
        case .incomingRequest:
            return "They already sent you a request. Accept it below."
        case .outgoingRequest:
            return "Your request is already on the way."
        case .blocked:
            return "Unblock this handle before sending a request."
        case .addable:
            return "Send a request to unlock feed posts and collab drafts."
        }
    }

    var isActionEnabled: Bool {
        self == .addable
    }
}



// MARK: - Quotes Empty State

private struct QuotesEmptyState: View {
    let theme: ThemeMode
    var reduceMotion: Bool = false

    @State private var appeared = false
    @State private var floatOffset: CGFloat = 0

    private var accent: Color { Theme.accent(for: theme) }
    private var primaryText: Color { Theme.primaryText(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.0 : 0.7)
                    .opacity(appeared ? 1 : 0)
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 100, height: 100)
                    .offset(y: floatOffset)
                if reduceMotion {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                } else {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accent)
                        .offset(y: floatOffset)
                        .symbolEffect(.bounce, options: .repeating, value: appeared)
                }
            }

            VStack(spacing: 8) {
                Text("All quiet here.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryText)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)

                Text("No quotes in this category yet.\nPick another or generate more advice.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { appeared = true }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { floatOffset = -9 }
            }
        }
        .onDisappear {
            appeared = false
            floatOffset = 0
        }
    }
}
