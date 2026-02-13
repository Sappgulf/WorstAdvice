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
