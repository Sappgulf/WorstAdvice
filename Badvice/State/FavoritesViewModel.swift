import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class FavoritesViewModel {
    private let repository: AdviceRepository
    private let analyticsTracker: AnalyticsTracking
    var favorites: [AdviceRecord] = []
    var loadFailed = false
    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { refreshFilteredFavorites() }
    }
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var favoritesSearchIndexByID: [UUID: String] = [:]
    private var cachedFilteredFavorites: [AdviceRecord] = []
    @ObservationIgnored private var hasLoadedInitialData = false

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker())
    {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        self.debouncedSearchText = searchText
    }

    func reload() {
        hasLoadedInitialData = true
        favorites = repository.fetchFavorites()
        loadFailed = repository.lastHistoryFetchFailed
        rebuildFavoritesSearchIndex()
        refreshFilteredFavorites()
    }

    func loadIfNeeded() {
        guard !hasLoadedInitialData else { return }
        reload()
    }

    func remove(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: false)
        analyticsTracker.track("favorite_remove", properties: [:])
        reload()
    }

    func delete(_ record: AdviceRecord) {
        repository.delete(record)
        analyticsTracker.track("favorite_delete", properties: [:])
        reload()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        repository.toggleFavorite(record)
        analyticsTracker.track("favorite_toggle", properties: [:])
        reload()
    }

    func setAftermathNote(_ record: AdviceRecord, note: String) {
        repository.setAftermathNote(record, note: note)
    }

    var filteredFavorites: [AdviceRecord] {
        cachedFilteredFavorites
    }

    private func rebuildFavoritesSearchIndex() {
        var index: [UUID: String] = [:]
        index.reserveCapacity(favorites.count)
        for record in favorites {
            index[record.id] =
                "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                .normalizedForFiltering
        }
        favoritesSearchIndexByID = index
    }

    private func refreshFilteredFavorites() {
        let search = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        if normalizedSearch.isEmpty, selectedCategory == nil {
            cachedFilteredFavorites = favorites
            return
        }

        if normalizedSearch.isEmpty, let selectedCategory {
            cachedFilteredFavorites = favorites.filter { $0.category == selectedCategory }
            return
        }

        cachedFilteredFavorites = favorites.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack =
                    favoritesSearchIndexByID[record.id]
                    ?? "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.refreshFilteredFavorites()
            }
        }
    }
}
