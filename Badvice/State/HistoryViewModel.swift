import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class HistoryViewModel {
    enum RankingMode: String, CaseIterable, Identifiable {
        case recent
        case topLiked
        case topDisliked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return "Recent"
            case .topLiked: return "Top Liked"
            case .topDisliked: return "Top Disliked"
            }
        }
    }

    private let repository: AdviceRepository
    private let analyticsTracker: AnalyticsTracking
    var history: [AdviceRecord] = []
    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { refreshFilteredHistory() }
    }
    var rankingMode: RankingMode = .recent {
        didSet { refreshFilteredHistory() }
    }
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var historySearchIndexByID: [UUID: String] = [:]
    private var cachedFilteredHistory: [AdviceRecord] = []
    private var cachedLikedCount = 0
    private var cachedDislikedCount = 0
    @ObservationIgnored private var hasLoadedInitialData = false

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker())
    {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        self.debouncedSearchText = searchText
        loadIfNeeded()
    }

    func reload() {
        hasLoadedInitialData = true
        history = repository.fetchHistory(limit: 50)
        rebuildHistoryCaches()
        refreshFilteredHistory()
    }

    func loadIfNeeded() {
        guard !hasLoadedInitialData else { return }
        reload()
    }

    func saveFromHistory(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: true)
        analyticsTracker.track("history_save", properties: [:])
        reload()
    }

    func clearHistory() {
        repository.purgeAllHistory()
        analyticsTracker.track("history_clear", properties: [:])
        reload()
    }

    var filteredHistory: [AdviceRecord] {
        cachedFilteredHistory
    }

    var likedCount: Int {
        cachedLikedCount
    }

    var dislikedCount: Int {
        cachedDislikedCount
    }

    private func rebuildHistoryCaches() {
        var index: [UUID: String] = [:]
        index.reserveCapacity(history.count)
        var likes = 0
        var dislikes = 0
        for record in history {
            index[record.id] =
                "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                .normalizedForFiltering
            if record.vote == .like {
                likes += 1
            } else if record.vote == .dislike {
                dislikes += 1
            }
        }
        historySearchIndexByID = index
        cachedLikedCount = likes
        cachedDislikedCount = dislikes
    }

    private func refreshFilteredHistory() {
        let search = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        if normalizedSearch.isEmpty, selectedCategory == nil, rankingMode == .recent {
            cachedFilteredHistory = history
            return
        }

        if normalizedSearch.isEmpty, let selectedCategory, rankingMode == .recent {
            cachedFilteredHistory = history.filter { $0.category == selectedCategory }
            return
        }

        let filtered = history.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack =
                    historySearchIndexByID[record.id]
                    ?? "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }

        switch rankingMode {
        case .recent:
            cachedFilteredHistory = filtered
        case .topLiked:
            cachedFilteredHistory = filtered.filter { $0.vote == .like }
        case .topDisliked:
            cachedFilteredHistory = filtered.filter { $0.vote == .dislike }
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.refreshFilteredHistory()
            }
        }
    }
}
