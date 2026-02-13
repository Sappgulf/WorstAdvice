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
            VStack(spacing: 12) {
                Picker("Layout", selection: $layout) {
                    Text("List").tag(FavoritesLayout.list)
                    Text("Grid").tag(FavoritesLayout.grid)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 12)

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
            .safeAreaInset(edge: .top) {
                categoryFilterStrip
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 8)
            }
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

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "All", category: nil)
                ForEach(AdviceCategory.allCases) { category in
                    categoryChip(label: category.title, category: category)
                }
            }
        }
    }

    private func categoryChip(label: String, category: AdviceCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button(label) {
            viewModel.selectedCategory = category
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(isSelected ? Theme.buttonText(for: settings.theme) : Theme.primaryText(for: settings.theme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Theme.accent(for: settings.theme) : Theme.cardColor(for: settings.theme))
        )
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
