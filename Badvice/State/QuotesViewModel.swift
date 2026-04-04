import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.worstadvice.app", category: "state")

@MainActor
@Observable
final class QuotesViewModel {
    private let repository: AdviceRepository
    private let quoteService: BadQuoteService
    private let moderation: ContentModeration
    private let store: AdviceStore
    private let analyticsTracker: AnalyticsTracking
    private let localModelStore: LocalModelStore
    private let appleOnDeviceBridge: AppleOnDeviceAdviceBridge
    private let adaptiveRanker = AdaptiveRanker()

    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { scheduleFilteredQuotesRefresh() }
    }
    var rankingMode: QuoteRankingMode = .recent {
        didSet { scheduleFilteredQuotesRefresh() }
    }
    private var quoteSuggestions: [UserQuoteSuggestion] = []
    private var votesByQuoteID: [String: AdviceVoteState] = [:]
    private var cachedAllQuotes: [BadQuote] = []
    private var cachedFilteredQuotes: [BadQuote] = []
    private var quoteSearchIndex: [String: String] = [:]
    private var quoteScopeKeyByID: [String: String] = [:]
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private var modelQuoteTask: Task<Void, Never>?
    private var refreshGeneration: Int = 0
    private var cachedModelGeneratedQuotes: [BadQuote] = []
    private var lastModelQuoteOverlayKey: String?
    @ObservationIgnored private var hasLoadedInitialData = false
    #if DEBUG
        var debugSourceFilter: QuoteSourceDebugFilter = .all {
            didSet { scheduleFilteredQuotesRefresh() }
        }
    #endif

    init(
        repository: AdviceRepository,
        quoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        store: AdviceStore = AdviceStore(),
        localModelStore: LocalModelStore,
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.repository = repository
        self.quoteService = quoteService
        self.moderation = moderation
        self.store = store
        self.analyticsTracker = analyticsTracker
        self.localModelStore = localModelStore
        self.appleOnDeviceBridge = AppleOnDeviceAdviceBridge(moderation: moderation)
        self.debouncedSearchText = searchText
        reloadCachedData()
    }

    convenience init(
        repository: AdviceRepository,
        quoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        store: AdviceStore = AdviceStore(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.init(
            repository: repository,
            quoteService: quoteService,
            moderation: moderation,
            store: store,
            localModelStore: LocalModelStore(),
            analyticsTracker: analyticsTracker
        )
    }

    var dailyQuote: BadQuote {
        quoteService.quoteOfDay()
    }

    var allQuotes: [BadQuote] {
        cachedAllQuotes
    }

    var filteredQuotes: [BadQuote] {
        cachedFilteredQuotes
    }

    var recentQuoteSuggestions: [UserQuoteSuggestion] {
        quoteSuggestions
    }

    var quoteSuggestionCount: Int {
        quoteSuggestions.count
    }

    var quoteVoteMap: [String: AdviceVoteState] {
        votesByQuoteID
    }

    var likedCount: Int {
        quoteVoteMap.values.filter { $0 == .like }.count
    }

    var dislikedCount: Int {
        quoteVoteMap.values.filter { $0 == .dislike }.count
    }

    func vote(for quote: BadQuote) -> AdviceVoteState {
        quoteVoteMap[quote.id] ?? .none
    }

    func toggleVote(_ vote: AdviceVoteState, for quote: BadQuote) {
        let currentVote = votesByQuoteID[quote.id] ?? .none
        let nextVote: AdviceVoteState = currentVote == vote ? .none : vote
        repository.setQuoteVote(quoteID: quote.id, vote: nextVote)
        switch nextVote {
        case .like:
            repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .like)
        case .dislike:
            repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .dislike)
        case .none:
            break
        }
        if nextVote == .none {
            votesByQuoteID.removeValue(forKey: quote.id)
        } else {
            votesByQuoteID[quote.id] = nextVote
        }
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_vote",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "vote": "\(nextVote.rawValue)",
            ])
    }

    func submitSuggestion(
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) -> String? {
        let trimmedText = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeSource =
            trimmedSource.isEmpty ? "Community Submission" : String(trimmedSource.prefix(44))

        guard trimmedText.count >= 8 else { return "Quote text is too short." }
        guard trimmedText.count <= 160 else { return "Quote text is too long." }

        let combined = "\(safeSource) \(trimmedText)"
        guard moderation.isSafe(text: combined) else {
            return "Quote suggestion blocked by safety checks."
        }

        let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
        let normalized = trimmedText.normalizedForFiltering
        guard !forbidden.contains(where: { normalized.contains($0.normalizedForFiltering) }) else {
            return "Quote suggestion conflicts with category safety constraints."
        }

        _ = repository.addQuoteSuggestion(
            category: category,
            source: safeSource,
            quoteText: String(trimmedText.prefix(160))
        )
        reloadCachedData()
        analyticsTracker.track(
            "quote_suggestion_submit",
            properties: [
                "category": category.rawValue
            ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserQuoteSuggestion) {
        repository.deleteQuoteSuggestion(suggestion)
        reloadCachedData()
        analyticsTracker.track(
            "quote_suggestion_delete",
            properties: [
                "category": suggestion.category.rawValue
            ])
    }

    func trackCopy(_ quote: BadQuote, isDaily: Bool) {
        repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .copy)
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_copy",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "daily": isDaily ? "true" : "false",
            ])
    }

    func trackShare(_ quote: BadQuote, isDaily: Bool) {
        repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .share)
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_share",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "daily": isDaily ? "true" : "false",
            ])
    }

    func quoteShareText(_ quote: BadQuote) -> String {
        "\"\(quote.text)\"\n— \(quote.source)\n\nBadvice"
    }

    func quoteSpotlightInsight(for quote: BadQuote) -> String {
        let rules = store.rules(for: quote.category, contentPack: .classic)
        guard !rules.badPrinciples.isEmpty, !rules.keywords.isEmpty else {
            return "It turns \(quote.category.title.lowercased()) into a cleaner-sounding mistake than it really is."
        }
        let seed = stableSeed(for: "\(quote.id)|\(quote.category.rawValue)|spotlight")
        let principle = rules.badPrinciples[seed.positiveModulo(rules.badPrinciples.count)]
        let keywordSeed = seed &+ 17
        let keyword = rules.keywords[keywordSeed.positiveModulo(rules.keywords.count)]
        let sourceTone = quote.source.normalizedForFiltering
        if sourceTone.contains("memo") || sourceTone.contains("brief") {
            return "It reads like a memo that mistook \(keyword) for the responsible conclusion."
        }
        if sourceTone.contains("oracle") || sourceTone.contains("wisdom") {
            return "It gives \(principle.lowercased()) the confidence of a rule and lets \(keyword) sound inevitable."
        }
        return "It frames \(principle.lowercased()) as good judgment and makes \(keyword) feel like the polished answer."
    }

    func loadIfNeeded() {
        guard !hasLoadedInitialData else { return }
        reloadCachedData()
    }

    private func reloadCachedData() {
        hasLoadedInitialData = true
        quoteSuggestions = repository.fetchQuoteSuggestions(limit: 30)
        votesByQuoteID = repository.quoteVoteMap()
        rebuildQuoteCache()
        scheduleFilteredQuotesRefresh()
        scheduleModelQuoteOverlayRefreshIfNeeded()
    }

    private func rebuildQuoteCache() {
        let base = quoteService.candidateQuotes(
            communitySuggestions: quoteSuggestions,
            store: store,
            moderation: moderation
        )
        let combinedBase = base + cachedModelGeneratedQuotes
        var seen = Set<String>()
        var merged: [BadQuote] = []
        var index: [String: String] = [:]
        var scopeIndex: [String: String] = [:]

        for quote in combinedBase {
            let normalizedText = quote.text.normalizedForFiltering
            if seen.insert(normalizedText).inserted {
                merged.append(quote)
                index[quote.id] =
                    "\(quote.text) \(quote.source) \(quote.category.title)".normalizedForFiltering
                scopeIndex[quote.id] = quoteScopeKey(for: quote)
            }
        }

        cachedAllQuotes = merged
        quoteSearchIndex = index
        quoteScopeKeyByID = scopeIndex
    }

    private func quoteScopeKey(for quote: BadQuote) -> String {
        if let cached = quoteScopeKeyByID[quote.id] {
            return cached
        }
        let sourceBucket = quote.source
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSource = sourceBucket.isEmpty ? "community submission" : sourceBucket
        return "quote|\(quote.category.rawValue)|\(normalizedSource)"
    }

    private func stableSeed(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 16_777_619) ^ Int(scalar.value)
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.scheduleFilteredQuotesRefresh()
            }
        }
    }

    private func scheduleFilteredQuotesRefresh() {
        let modeFiltered = modeFilteredQuotes(for: debouncedSearchText)
        cachedFilteredQuotes = modeFiltered
        filterTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        let searchSnapshot = debouncedSearchText
        filterTask = Task { [weak self, modeFiltered, searchSnapshot] in
            await self?.refreshFilteredQuotes(
                generation: generation,
                modeFiltered: modeFiltered,
                searchText: searchSnapshot
            )
        }
    }

    private func refreshFilteredQuotes(
        generation: Int,
        modeFiltered: [BadQuote],
        searchText: String
    ) async {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        guard modeFiltered.count > 1 else {
            guard !Task.isCancelled, generation == refreshGeneration else { return }
            cachedFilteredQuotes = modeFiltered
            return
        }

        let scorer = SemanticTextScorer.shared
        let preparedQuery =
            normalizedSearch.isEmpty ? nil : await scorer.preparedQuery(from: normalizedSearch)

        var scored: [(BadQuote, Double)] = []
        scored.reserveCapacity(modeFiltered.count)
        var learningCacheByScope: [String: LearningStatSnapshot] = [:]
        for (index, quote) in modeFiltered.enumerated() {
            if Task.isCancelled || generation != refreshGeneration {
                return
            }
            let scopeKey = quoteScopeKey(for: quote)
            let stat: LearningStatSnapshot
            if let cached = learningCacheByScope[scopeKey] {
                stat = cached
            } else {
                let snapshot = repository.learningSnapshot(for: scopeKey)
                learningCacheByScope[scopeKey] = snapshot
                stat = snapshot
            }
            let semantic: Double
            if let preparedQuery {
                semantic = await scorer.similarity(
                    "\(quote.text) \(quote.source)", to: preparedQuery)
            } else {
                semantic = 0.45
            }
            let noveltyPenalty = min(stat.shownCount / 24.0, 1.0)
            let score = adaptiveRanker.quoteScore(
                semanticRelevance: semantic,
                stats: stat,
                noveltyPenalty: noveltyPenalty,
                seed: stableSeed(for: "\(quote.id)|\(normalizedSearch)"),
                candidateIndex: index
            )
            scored.append((quote, score))
        }

        guard !Task.isCancelled, generation == refreshGeneration else { return }
        cachedFilteredQuotes =
            scored
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.text.localizedCaseInsensitiveCompare($1.0.text) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private func modeFilteredQuotes(for searchText: String) -> [BadQuote] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        let sourceFilteredBase = cachedAllQuotes.filter { quoteMatchesDebugSourceFilter($0) }

        if normalizedSearch.isEmpty, selectedCategory == nil {
            switch rankingMode {
            case .recent:
                return sourceFilteredBase
            case .topLiked:
                return sourceFilteredBase.filter { votesByQuoteID[$0.id] == .like }
            case .topDisliked:
                return sourceFilteredBase.filter { votesByQuoteID[$0.id] == .dislike }
            }
        }

        let filtered = sourceFilteredBase.filter { quote in
            let categoryMatch = selectedCategory == nil || quote.category == selectedCategory
            if normalizedSearch.isEmpty {
                return categoryMatch
            }
            let haystack = quoteSearchIndex[quote.id] ?? ""
            return categoryMatch && haystack.contains(normalizedSearch)
        }

        switch rankingMode {
        case .recent:
            return filtered
        case .topLiked:
            return filtered.filter { votesByQuoteID[$0.id] == .like }
        case .topDisliked:
            return filtered.filter { votesByQuoteID[$0.id] == .dislike }
        }
    }

    private func quoteMatchesDebugSourceFilter(_ quote: BadQuote) -> Bool {
        #if DEBUG
            switch debugSourceFilter {
            case .all:
                return true
            case .appleModel:
                return quote.id.hasPrefix("apple-quote-")
                    || quote.source.normalizedForFiltering.contains("apple on-device")
            case .remixLab:
                return quote.source.normalizedForFiltering.contains("ml remix")
            case .community:
                return quote.id.hasPrefix("community-")
            case .curated:
                let isApple =
                    quote.id.hasPrefix("apple-quote-")
                    || quote.source.normalizedForFiltering.contains("apple on-device")
                let isRemix = quote.source.normalizedForFiltering.contains("ml remix")
                let isCommunity = quote.id.hasPrefix("community-")
                return !(isApple || isRemix || isCommunity)
            }
        #else
            return true
        #endif
    }

    private func scheduleModelQuoteOverlayRefreshIfNeeded() {
        let provider = repository.ensureSettings().preferredGenerationProvider
        let overlayKey = modelQuoteOverlayKey(provider: provider)

        if provider == .classic {
            modelQuoteTask?.cancel()
            lastModelQuoteOverlayKey = overlayKey
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        if lastModelQuoteOverlayKey == overlayKey {
            return
        }
        lastModelQuoteOverlayKey = overlayKey
        modelQuoteTask?.cancel()

        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let localGate = localModelStore.generationGate(appleAvailability: availability)
        analyticsTracker.track(
            "apple_model_availability",
            properties: [
                "requested_provider": provider.rawValue,
                "status": availability.analyticsKey,
                "surface": "quotes",
            ])

        if case .unavailable(let reasonKey, _, _, _) = localGate {
            if provider == .appleOnDevice {
                analyticsTracker.track(
                    "apple_model_fallback",
                    properties: [
                        "requested_provider": provider.rawValue,
                        "reason": "selection_\(reasonKey)",
                        "surface": "quotes",
                    ])
            }
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        guard availability.isReady else {
            if provider == .appleOnDevice {
                analyticsTracker.track(
                    "apple_model_fallback",
                    properties: [
                        "requested_provider": provider.rawValue,
                        "reason": "availability_\(availability.analyticsKey)",
                        "surface": "quotes",
                    ])
            }
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        modelQuoteTask = Task { [weak self] in
            await self?.refreshModelQuoteOverlay(provider: provider)
        }
    }

    private func modelQuoteOverlayKey(provider: AdviceGenerationProvider, now: Date = Date())
        -> String
    {
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        return "\(provider.rawValue)|\(Int(day))"
    }

    private func refreshModelQuoteOverlay(provider: AdviceGenerationProvider) async {
        let categories = rotatingQuoteOverlayCategories()
        let tones = ToneMode.concrete
        let seedBase = stableSeed(
            for: "quote-overlay|\(Date().formatted(date: .numeric, time: .omitted))")
        var built: [BadQuote] = []
        var seen = Set<String>()

        for index in 0..<min(4, max(2, categories.count)) {
            if Task.isCancelled { return }
            let category = categories[index % categories.count]
            let tone = tones[(seedBase + index * 13).positiveModulo(tones.count)]
            do {
                let candidate = try await appleOnDeviceBridge.generateQuoteCandidate(
                    category: category,
                    tone: tone,
                    seed: seedBase + (index * 7_919)
                )
                guard isValidModelQuote(candidate) else { continue }
                let fingerprint = candidate.text.normalizedForFiltering
                if seen.insert(fingerprint).inserted {
                    built.append(candidate)
                }
            } catch {
                logger.error(
                    "Apple on-device quote generation failed: \(String(describing: error), privacy: .public)"
                )
                if provider == .appleOnDevice {
                    analyticsTracker.track(
                        "apple_model_fallback",
                        properties: [
                            "requested_provider": provider.rawValue,
                            "reason": "generation_failed",
                            "surface": "quotes",
                        ])
                }
                break
            }
        }

        if provider == .appleOnDevice, built.isEmpty {
            analyticsTracker.track(
                "apple_model_fallback",
                properties: [
                    "requested_provider": provider.rawValue,
                    "reason": "no_valid_output",
                    "surface": "quotes",
                ])
        }

        guard !Task.isCancelled else { return }
        cachedModelGeneratedQuotes = built
        rebuildQuoteCache()
        scheduleFilteredQuotesRefresh()
    }

    private func rotatingQuoteOverlayCategories(now: Date = Date()) -> [AdviceCategory] {
        let categories = AdviceCategory.concrete
        guard !categories.isEmpty else { return [.productivity] }
        let seed = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let start = (seed / 86_400).positiveModulo(categories.count)
        return (0..<categories.count).map { categories[(start + $0) % categories.count] }
    }

    private func isValidModelQuote(_ quote: BadQuote) -> Bool {
        let text = quote.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8, text.count <= 160 else { return false }
        guard moderation.isSafe(text: "\(quote.source) \(text)") else { return false }
        let forbidden = store.rules(for: quote.category, contentPack: .classic).forbiddenPatterns
        let normalized = text.normalizedForFiltering
        return !forbidden.contains { normalized.contains($0.normalizedForFiltering) }
    }
}
