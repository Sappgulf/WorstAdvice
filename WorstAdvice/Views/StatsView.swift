import SwiftUI

struct FavoritesTabView: View {
    @Bindable var viewModel: FavoritesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var layout: FavoritesLayout = .list

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
            .background(Theme.backgroundGradient(for: settings.theme).ignoresSafeArea())
            .navigationTitle("Favorites")
            .searchable(text: $viewModel.searchText, prompt: "Search saved advice")
            .toolbar { toolbarContent }
            .onAppear { viewModel.reload() }
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.filteredFavorites, id: \.id) { record in
                NavigationLink {
                    FavoriteDetailView(record: record, settings: settings)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.adviceLine)
                            .font(.body)
                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                            .lineLimit(3)

                        Text("\(record.category.title) • \(record.tone.title)")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    }
                    .padding(.vertical, 6)
                }
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
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.filteredFavorites, id: \.id) { record in
                    NavigationLink {
                        FavoriteDetailView(record: record, settings: settings)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.adviceLine)
                                .font(.footnote)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(Theme.primaryText(for: settings.theme))

                            Spacer(minLength: 4)

                            Text(record.category.title)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.cardColor(for: settings.theme))
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Unsave") { viewModel.remove(record) }
                        Button("Delete", role: .destructive) { viewModel.delete(record) }
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 18)
        }
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text("No favorites yet")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text("Save advice from Generate or History to pin it here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text("No matches")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text("Try a different search or category.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuotesTabView: View {
    @Bindable var viewModel: QuotesViewModel
    @Bindable var settings: SettingsViewModel

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Browse") {
                    Picker("Sort", selection: $viewModel.rankingMode) {
                        ForEach(QuoteRankingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Liked: \(viewModel.likedCount)")
                        Spacer()
                        Text("Disliked: \(viewModel.dislikedCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                }

                Section("Daily Bad Quote") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("“\(viewModel.dailyQuote.text)”")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(viewModel.dailyQuote.source)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))

                        HStack(spacing: 10) {
                            voteButtons(for: viewModel.dailyQuote)

                            Spacer(minLength: 8)

                            Button {
                                copyQuote(viewModel.dailyQuote, isDaily: true)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Copy daily quote")

                            Button {
                                shareQuote(viewModel.dailyQuote, isDaily: true)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent(for: settings.theme))
                            .accessibilityLabel("Share daily quote")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Quote Library") {
                    if viewModel.filteredQuotes.isEmpty {
                        Text("No quotes match your filters.")
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    } else {
                        ForEach(viewModel.filteredQuotes) { quote in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("“\(quote.text)”")
                                            .font(.body)
                                            .foregroundStyle(Theme.primaryText(for: settings.theme))
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text("\(quote.source) • \(quote.category.title)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                                    }
                                }
                                HStack(spacing: 10) {
                                    voteButtons(for: quote)
                                    Spacer(minLength: 8)
                                    quoteActionsMenu(for: quote)
                                }
                                .padding(.top, 6)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient(for: settings.theme).ignoresSafeArea())
            .navigationTitle("Quotes")
            .searchable(text: $viewModel.searchText, prompt: "Search bad quotes")
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
        HStack(spacing: 8) {
            Button {
                viewModel.toggleVote(.like, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: viewModel.vote(for: quote) == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Like quote")

            Button {
                viewModel.toggleVote(.dislike, for: quote)
                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            } label: {
                Image(systemName: viewModel.vote(for: quote) == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
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

    var body: some View {
        ScrollView {
            AdviceCardView(record: record, theme: settings.theme)
                .padding(Theme.horizontalPadding)

            Button("Share Card") {
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
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(for: settings.theme))
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 8)
        }
        .background(Theme.backgroundGradient(for: settings.theme).ignoresSafeArea())
        .navigationTitle("Favorite")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
    }
}
