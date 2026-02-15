import SwiftUI

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    let onUseRecord: (AdviceRecord) -> Void
    let onDataChanged: () -> Void

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
                    Button("Clear") {
                        viewModel.clearHistory()
                        onDataChanged()
                    }
                    .disabled(viewModel.history.isEmpty)
                }
            }
            .onAppear { viewModel.reload() }
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
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text("History is empty")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text("Generated advice appears here (last 50 items).")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .padding(.horizontal, 20)
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
