import SwiftUI

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    let onUseRecord: (AdviceRecord) -> Void
    let onDataChanged: () -> Void

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        rankingPicker
                            .padding(.horizontal, Theme.horizontalPadding)

                        if viewModel.filteredHistory.isEmpty {
                            noResultsState
                        } else {
                            historyList
                        }
                    }
                }
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search history")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(viewModel.history.isEmpty)
                }
            }
            .onAppear { viewModel.reload() }
            .confirmationDialog(
                "Clear History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All \(viewModel.history.count) Items", role: .destructive) {
                    viewModel.clearHistory()
                    onDataChanged()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your entire advice history. This can\u{2019}t be undone.")
            }
        }
    }

    private var rankingPicker: some View {
        Picker("Ranking", selection: $viewModel.rankingMode) {
            ForEach(HistoryViewModel.RankingMode.allCases) { mode in
                Text(label(for: mode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("History ranking mode")
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.filteredHistory, id: \.id) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.adviceLine)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.primaryText(for: settings.theme))
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

                        if record.vote == .like {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent(for: settings.theme))
                        } else if record.vote == .dislike {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            onUseRecord(record)
                        } label: {
                            Label("Use Again", systemImage: "arrow.counterclockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent(for: settings.theme))

                        Button {
                            viewModel.saveFromHistory(record)
                            onDataChanged()
                        } label: {
                            Label(record.isFavorite ? "Saved" : "Save", systemImage: record.isFavorite ? "bookmark.fill" : "bookmark")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent(for: settings.theme))
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 6)
                .listRowBackground(Theme.cardColor(for: settings.theme))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Theme.accent(for: settings.theme))
            }
            VStack(spacing: 6) {
                Text("A clean slate.")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))
                Text("Your past bad decisions will appear here.\nGo generate some.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 40)
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
            Text(noResultsMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func label(for mode: HistoryViewModel.RankingMode) -> String {
        switch mode {
        case .recent:
            return mode.title
        case .topLiked:
            return "Liked \(viewModel.likedCount)"
        case .topDisliked:
            return "Disliked \(viewModel.dislikedCount)"
        }
    }

    private var noResultsMessage: String {
        switch viewModel.rankingMode {
        case .recent:
            return "Try a different search or category."
        case .topLiked:
            return "No liked entries match your filters yet."
        case .topDisliked:
            return "No disliked entries match your filters yet."
        }
    }
}
