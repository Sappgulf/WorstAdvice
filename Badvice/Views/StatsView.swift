import SwiftUI

struct FavoritesTabView: View {
    @Bindable var viewModel: FavoritesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var layout: FavoritesLayout = .list
    @State private var listContentAppeared = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool {
        settings.reduceMotion || accessibilityReduceMotion
    }

    enum FavoritesLayout: String, CaseIterable, Identifiable {
        case list
        case grid

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favorites.isEmpty {
                    emptyState
                } else if viewModel.filteredFavorites.isEmpty {
                    noResultsState
                } else if layout == .list {
                    listView
                } else {
                    gridView
                }
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search saved advice")
            .toolbar { toolbarContent }
            .onAppear { 
                viewModel.reload()
                // Initial load haptic for satisfying entry
                HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                // Show tab bar in list views
                tabBarVisible.wrappedValue = true
                animateListContentIfNeeded()
            }
            .onChange(of: layout) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
    }

    private var listView: some View {
        List {
            Section {
                favoritesSummaryRow
            }
            .listRowBackground(Theme.cardColor(for: settings.theme))

            let items = viewModel.filteredFavorites
            ForEach(items, id: \.id) { record in
                NavigationLink {
                    FavoriteDetailView(record: record, settings: settings)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.adviceLine)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                            .lineLimit(3)
                            .lineSpacing(2)

                        HStack(spacing: 6) {
                            Label(record.category.title, systemImage: record.category.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent(for: settings.theme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Theme.accent(for: settings.theme).opacity(0.12))
                                )

                            Text(record.tone.title)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))

                            if let collection = viewModel.collection(for: record) {
                                Text(collection.rawValue)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent(for: settings.theme))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.accent(for: settings.theme).opacity(0.14)))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Theme.cardColor(for: settings.theme))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.delete(record)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        viewModel.remove(record)
                    } label: {
                        Label("Unsave", systemImage: "bookmark.slash")
                    }
                    .tint(.orange)

                    Menu("Collection") {
                        Button("None") { viewModel.assign(nil, to: record) }
                        ForEach(FavoritesViewModel.Collection.allCases) { collection in
                            Button(collection.rawValue) { viewModel.assign(collection, to: record) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .opacity(listContentAppeared ? 1 : 0)
        .offset(y: listContentAppeared ? 0 : 12)
    }

    private var gridView: some View {
        ScrollView {
            VStack(spacing: 12) {
                favoritesSummaryRow
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.filteredFavorites, id: \.id) { record in
                        NavigationLink {
                            FavoriteDetailView(record: record, settings: settings)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                // Category chip
                                Label(record.category.title, systemImage: record.category.icon)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent(for: settings.theme))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Theme.accent(for: settings.theme).opacity(0.12))
                                    )

                                Spacer(minLength: 8)

                                Text(record.adviceLine)
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(5)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                                    .lineSpacing(2)

                                Spacer(minLength: 10)

                                Text(record.tone.title)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.cardColor(for: settings.theme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Theme.accent(for: settings.theme).opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Unsave") { viewModel.remove(record) }
                            Button("Delete", role: .destructive) { viewModel.delete(record) }
                            Divider()
                            Button("No Collection") { viewModel.assign(nil, to: record) }
                            ForEach(FavoritesViewModel.Collection.allCases) { collection in
                                Button(collection.rawValue) { viewModel.assign(collection, to: record) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 18)
        }
        .opacity(listContentAppeared ? 1 : 0)
        .offset(y: listContentAppeared ? 0 : 12)
    }

    private var favoritesSummaryRow: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.filteredFavorites.count) shown", systemImage: "bookmark")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 8)
            Text("of \(viewModel.favorites.count) saved")
                .font(.caption)
            if viewModel.selectedCategory != nil {
                Text("Filtered")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.accent(for: settings.theme).opacity(0.14))
                    )
            }
        }
        .foregroundStyle(Theme.secondaryText(for: settings.theme))
        .padding(.vertical, 4)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    layout = .list
                } label: {
                    if layout == .list {
                        Label("List", systemImage: "checkmark")
                    } else {
                        Text("List")
                    }
                }
                Button {
                    layout = .grid
                } label: {
                    if layout == .grid {
                        Label("Grid", systemImage: "checkmark")
                    } else {
                        Text("Grid")
                    }
                }
            } label: {
                Image(systemName: "rectangle.grid.1x2")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.selectedCollection = nil
                } label: {
                    Label("All collections", systemImage: viewModel.selectedCollection == nil ? "checkmark" : "tray")
                }

                ForEach(FavoritesViewModel.Collection.allCases) { collection in
                    Button {
                        viewModel.selectedCollection = collection
                    } label: {
                        Label(collection.rawValue, systemImage: viewModel.selectedCollection == collection ? "checkmark" : "folder")
                    }
                }
            } label: {
                Image(systemName: "folder")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.selectedCategory = nil
                } label: {
                    if viewModel.selectedCategory == nil {
                        Label("All categories", systemImage: "checkmark")
                    } else {
                        Text("All categories")
                    }
                }
                ForEach(AdviceCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        if viewModel.selectedCategory == category {
                            Label(category.title, systemImage: "checkmark")
                        } else {
                            Text(category.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func animateListContentIfNeeded() {
        guard !listContentAppeared else { return }
        if isMotionReduced {
            listContentAppeared = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                listContentAppeared = true
            }
        }
    }

    @State private var emptyStateAppeared = false
    @State private var floatingOffset: CGFloat = 0

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated background circles
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(emptyStateAppeared ? 1.0 : 0.8)
                    .opacity(emptyStateAppeared ? 1.0 : 0)
                
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.12))
                    .frame(width: 96, height: 96)
                    .offset(y: floatingOffset)
                
                Image(systemName: "bookmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Theme.accent(for: settings.theme))
                    .offset(y: floatingOffset)
                    .symbolEffect(.bounce, options: .repeating, value: emptyStateAppeared)
            }
            .onAppear {
                if !isMotionReduced {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        floatingOffset = -8
                    }
                }
            }
            
            VStack(spacing: 6) {
                Text("Nothing saved yet.")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                    .offset(y: emptyStateAppeared ? 0 : 20)
                    .opacity(emptyStateAppeared ? 1 : 0)
                
                Text("Bold of you. Save a piece of advice\nand pretend you'll follow it.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    .lineSpacing(3)
                    .offset(y: emptyStateAppeared ? 0 : 15)
                    .opacity(emptyStateAppeared ? 1 : 0)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isMotionReduced {
                emptyStateAppeared = true
                floatingOffset = 0
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    emptyStateAppeared = true
                }
            }
        }
        .onDisappear {
            emptyStateAppeared = false
        }
    }

    @State private var noResultsAppeared = false

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .scaleEffect(noResultsAppeared ? 1.0 : 0.5)
                .rotationEffect(.degrees(noResultsAppeared ? 0 : -30))
            
            Text("No matches")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .opacity(noResultsAppeared ? 1 : 0)
                .offset(y: noResultsAppeared ? 0 : 10)
            
            Text("Try a different search or category.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .opacity(noResultsAppeared ? 1 : 0)
                .offset(y: noResultsAppeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isMotionReduced {
                noResultsAppeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    noResultsAppeared = true
                }
            }
        }
        .onDisappear {
            noResultsAppeared = false
        }
    }
}

struct QuotesTabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var isMotionReduced: Bool {
        settings.reduceMotion || accessibilityReduceMotion
    }

    var body: some View {
        NavigationStack {
            List {
                // Hero daily quote — full-bleed card
                Section {
                    dailyQuoteHero
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Sort + stats controls
                Section {
                    Picker("Sort", selection: $viewModel.rankingMode) {
                        ForEach(QuoteRankingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Theme.cardColor(for: settings.theme))

                    HStack {
                        Label("\(viewModel.likedCount) liked", systemImage: "hand.thumbsup")
                        Spacer()
                        Label("\(viewModel.dislikedCount) disliked", systemImage: "hand.thumbsdown")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    .listRowBackground(Theme.cardColor(for: settings.theme))
                } header: {
                    Text("Quote Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText(for: settings.theme))
                        .textCase(nil)
                }

                // Quote rows
                if viewModel.filteredQuotes.isEmpty {
                    Section {
                        QuotesEmptyState(theme: settings.theme, reduceMotion: isMotionReduced)
                    }
                } else {
                    Section {
                        ForEach(viewModel.filteredQuotes) { quote in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\u{201C}\(quote.text)\u{201D}")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)

                                HStack(spacing: 6) {
                                    Label(quote.category.title, systemImage: quote.category.icon)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent(for: settings.theme))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Theme.accent(for: settings.theme).opacity(0.12))
                                        )

                                    Text("•")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.secondaryText(for: settings.theme).opacity(0.7))

                                    Text(quote.source)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }

                                HStack(spacing: 10) {
                                    voteButtons(for: quote)
                                    Spacer(minLength: 8)
                                    quoteActionsMenu(for: quote)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Theme.cardColor(for: settings.theme))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("Quotes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search bad quotes")
            .safeAreaPadding(.bottom, tabBarVisible.wrappedValue ? 118 : 22)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.selectedCategory = nil
                        } label: {
                            if viewModel.selectedCategory == nil {
                                Label("All categories", systemImage: "checkmark")
                            } else {
                                Text("All categories")
                            }
                        }
                        ForEach(AdviceCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                if viewModel.selectedCategory == category {
                                    Label(category.title, systemImage: "checkmark")
                                } else {
                                    Text(category.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .onAppear {
            // Show tab bar in list views
            tabBarVisible.wrappedValue = true
        }
        .onChange(of: viewModel.rankingMode) { _, _ in
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        }
    }

    private var dailyQuoteHero: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent(for: settings.theme),
                            Theme.accent(for: settings.theme).opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative large quote mark
            Text("\u{201C}")
                .font(.system(size: 96, weight: .heavy, design: .serif))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: 16, y: -8)
                .allowsHitTesting(false)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text("Bad Quote of the Day")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 10)

                Text("\u{201C}\(viewModel.dailyQuote.text)\u{201D}")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(viewModel.dailyQuote.source)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    // Like/dislike with white tint
                    HStack(spacing: 8) {
                        Button {
                            viewModel.toggleVote(.like, for: viewModel.dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: viewModel.vote(for: viewModel.dailyQuote) == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent(for: settings.theme))

                        Button {
                            viewModel.toggleVote(.dislike, for: viewModel.dailyQuote)
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Image(systemName: viewModel.vote(for: viewModel.dailyQuote) == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent(for: settings.theme))
                    }

                    Spacer()

                    Button {
                        copyQuote(viewModel.dailyQuote, isDaily: true)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button {
                        shareQuote(viewModel.dailyQuote, isDaily: true)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.25))
                }
                .padding(.top, 16)
            }
            .padding(22)
        }
        .overlay(alignment: .topTrailing) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.18), in: Capsule(style: .continuous))
                .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bad quote of the day: \(viewModel.dailyQuote.text) by \(viewModel.dailyQuote.source)")
    }

    private func copyQuote(_ quote: BadQuote, isDaily: Bool) {
        UIPasteboard.general.string = viewModel.quoteShareText(quote)
        viewModel.trackCopy(quote, isDaily: isDaily)
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
    }

    private func shareQuote(_ quote: BadQuote, isDaily: Bool) {
        shareItems = [viewModel.quoteShareText(quote)]
        viewModel.trackShare(quote, isDaily: isDaily)
        showingShareSheet = true
    }

    private func voteButtons(for quote: BadQuote) -> some View {
        let accent = Theme.accent(for: settings.theme)
        let neutralFill = accent.opacity(0.14)
        let activeFill = accent.opacity(0.26)
        let likeSelected = viewModel.vote(for: quote) == .like
        let dislikeSelected = viewModel.vote(for: quote) == .dislike

        return HStack(spacing: 8) {
            Button {
                viewModel.toggleVote(.like, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: viewModel.vote(for: quote) == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(likeSelected ? activeFill : neutralFill)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Like quote")

            Button {
                viewModel.toggleVote(.dislike, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: viewModel.vote(for: quote) == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(dislikeSelected ? activeFill : neutralFill)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dislike quote")
        }
    }

    private func quoteActionsMenu(for quote: BadQuote) -> some View {
        Menu {
            Button {
                copyQuote(quote, isDaily: false)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                shareQuote(quote, isDaily: false)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("Quote actions")
        .accessibilityHint("Copy or share this quote")
    }
}

private struct FavoriteDetailView: View {
    let record: AdviceRecord
    @Bindable var settings: SettingsViewModel

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AdviceCardView(
                    record: record,
                    theme: settings.theme,
                    reduceMotion: settings.reduceMotion
                )
                    .padding(.horizontal, Theme.horizontalPadding)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = record.adviceLine
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Text", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? Theme.accent(for: settings.theme) : nil)

                    Button {
                        let content = ShareCardContent(
                            category: record.category,
                            tone: record.tone,
                            adviceLine: record.adviceLine,
                            rationaleLine: record.rationaleLine,
                            includeDisclaimer: settings.includeDisclaimerOnShare,
                            template: settings.preferredTemplate,
                            aspectRatio: settings.preferredAspect
                        )
                        let image = ShareCardRenderer.render(content: content)
                        shareItems = [image, record.adviceLine]
                        showingShareSheet = true
                    } label: {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent(for: settings.theme))
                }
                .padding(.horizontal, Theme.horizontalPadding)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
        .navigationTitle(record.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
    }
}

// MARK: - Empty State Views

// MARK: - Performance-Optimized Button Styles

struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scaled: ScaleButtonStyle {
        ScaleButtonStyle()
    }
    
    static func scaled(_ scale: CGFloat) -> ScaleButtonStyle {
        ScaleButtonStyle(scale: scale)
    }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    var onUseRecord: (AdviceRecord) -> Void
    var onDataChanged: () -> Void
    
    @State private var showingClearConfirmation = false
    @State private var historyListAppeared = false

    private var isMotionReduced: Bool {
        settings.reduceMotion || accessibilityReduceMotion
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    historyEmptyState
                } else if viewModel.filteredHistory.isEmpty {
                    noResultsState
                } else {
                    historyList
                }
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search history")
            .toolbar { toolbarContent }
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
                viewModel.reload()
                HapticsManager.play(style: .soft, isEnabled: settings.hapticsEnabled)
                // Show tab bar in list views
                tabBarVisible.wrappedValue = true
                animateHistoryListIfNeeded()
            }
            .onChange(of: viewModel.rankingMode) { _, _ in
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            }
        }
    }
    
    private var historyList: some View {
        List {
            // Stats Section
            Section {
                HStack {
                    Label("\(viewModel.likedCount) liked", systemImage: "hand.thumbsup")
                    Spacer()
                    Text("\(viewModel.filteredHistory.count) shown")
                        .font(.caption2.monospacedDigit())
                    Spacer()
                    Label("\(viewModel.dislikedCount) disliked", systemImage: "hand.thumbsdown")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                
                Picker("Sort", selection: $viewModel.rankingMode) {
                    ForEach(HistoryViewModel.RankingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Timeline", selection: $viewModel.timeFilter) {
                    ForEach(HistoryViewModel.TimeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("History Stats")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                    .textCase(nil)
            }
            .listRowBackground(Theme.cardColor(for: settings.theme))
            
            // History Items
            Section {
                let items = viewModel.filteredHistory
                ForEach(items, id: \.id) { record in
                    Button {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        onUseRecord(record)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.adviceLine)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.primaryText(for: settings.theme))
                                .lineLimit(3)
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                            
                            HStack(spacing: 6) {
                                Label(record.category.title, systemImage: record.category.icon)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent(for: settings.theme))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Theme.accent(for: settings.theme).opacity(0.12))
                                    )
                                
                                Text(record.tone.title)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                                
                                Spacer()
                                
                                // Vote indicator
                                if record.vote == .like {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent(for: settings.theme))
                                } else if record.vote == .dislike {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent(for: settings.theme).opacity(0.72))
                                }
                                
                                // Favorite indicator
                                if record.isFavorite {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Theme.cardColor(for: settings.theme))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            viewModel.saveFromHistory(record)
                            onDataChanged()
                            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        } label: {
                            Label("Save", systemImage: "bookmark")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            onUseRecord(record)
                        } label: {
                            Label("Use", systemImage: "arrow.forward")
                        }
                        .tint(Theme.accent(for: settings.theme))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .opacity(historyListAppeared ? 1 : 0)
        .offset(y: historyListAppeared ? 0 : 12)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(AdviceCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                    } label: {
                        Label(
                            category.title,
                            systemImage: viewModel.selectedCategory == category ? "checkmark" : category.icon
                        )
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
                    .foregroundStyle(Theme.accent(for: settings.theme))
            }
        }
    }
    
    private var historyEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.accent(for: settings.theme).opacity(0.7))
            }
            
            VStack(spacing: 8) {
                Text("No History Yet")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                
                Text("Generate some advice to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @State private var noResultsAppeared = false
    
    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Theme.accent(for: settings.theme).opacity(0.6))
                .opacity(noResultsAppeared ? 1 : 0)
                .offset(y: noResultsAppeared ? 0 : 10)
            
            Text("No matches found")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
                .opacity(noResultsAppeared ? 1 : 0)
                .offset(y: noResultsAppeared ? 0 : 10)
            
            Text("Try a different search or category.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .opacity(noResultsAppeared ? 1 : 0)
                .offset(y: noResultsAppeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isMotionReduced {
                noResultsAppeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    noResultsAppeared = true
                }
            }
        }
        .onDisappear {
            noResultsAppeared = false
        }
    }

    private func animateHistoryListIfNeeded() {
        guard !historyListAppeared else { return }
        if isMotionReduced {
            historyListAppeared = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                historyListAppeared = true
            }
        }
    }
}

// MARK: - Empty States

private struct QuotesEmptyState: View {
    let theme: ThemeMode
    var reduceMotion: Bool = false
    
    @State private var appeared = false
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(Theme.accent(for: theme).opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(appeared ? 1.0 : 0.8)
                    .opacity(appeared ? 1.0 : 0.0)
                
                Image(systemName: "quote.bubble")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.accent(for: theme).opacity(0.7))
                    .offset(y: floatOffset)
            }
            
            Text("No quotes in this category.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText(for: theme))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .onAppear {
            if reduceMotion {
                appeared = true
                floatOffset = 0
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    floatOffset = -6
                }
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}
