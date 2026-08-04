import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.worstadvice.app", category: "state")

@MainActor
final class AdviceRepository {
    private static let defaultAccountKey = "__default__"
    private static let poolFingerprintPrefix = "pool::"
    private static let maxLearningScopes = 800
    private static let maxAdviceFingerprints = 1200

    let context: ModelContext
    let accountKey: String
    /// Set when the last `fetchAllHistory()` call failed and fell back to an
    /// empty result, so callers can tell a genuine load failure apart from a
    /// legitimately empty account.
    private(set) var lastHistoryFetchFailed = false
    private var cachedHistoryRecords: [AdviceRecord]?
    private var cachedSeenCount: Int?
    private var cachedFingerprintSet: Set<String>?
    private var cachedLearningStatsByKey: [String: LearningStatRecord]?

    init(context: ModelContext, accountKey: String = "__default__") {
        self.context = context
        self.accountKey = accountKey
        logger.debug("AdviceRepository initialized")
    }

    @discardableResult
    func insert(_ generated: GeneratedAdvice) -> AdviceRecord {
        let record = AdviceRecord(
            id: generated.id,
            ownerAccountID: accountKey,
            createdAt: generated.createdAt,
            category: generated.category,
            tone: generated.tone,
            adviceLine: generated.adviceLine,
            rationaleLine: generated.rationaleLine
        )
        context.insert(record)
        rememberAdviceFingerprint(
            generated.adviceLine.normalizedForFiltering,
            createdAt: generated.createdAt,
            saveChanges: false
        )
        rememberAdviceFingerprintInPool(
            generated.adviceLine.normalizedForFiltering,
            category: generated.category,
            tone: generated.tone,
            createdAt: generated.createdAt,
            saveChanges: false
        )
        save()
        invalidateHistoryCache()
        cachedSeenCount = nil
        pruneHistory(maxCount: 50)
        logger.debug(
            "Inserted advice id=\(generated.id) category=\(generated.category.rawValue) tone=\(generated.tone.rawValue)"
        )
        return record
    }

    func fetchHistory(limit: Int = 50) -> [AdviceRecord] {
        Array(fetchAllHistory().prefix(limit))
    }

    func fetchAllHistory() -> [AdviceRecord] {
        if let cachedHistoryRecords {
            return cachedHistoryRecords
        }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AdviceRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AdviceRecord>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        do {
            let history = try context.fetch(descriptor)
            lastHistoryFetchFailed = false
            cachedHistoryRecords = history
            return history
        } catch {
            logger.error("Failed to fetch history: \(error.localizedDescription, privacy: .public)")
            lastHistoryFetchFailed = true
            return []
        }
    }

    func fetchFavorites() -> [AdviceRecord] {
        fetchAllHistory().filter(\.isFavorite)
    }

    func thisWeekFavorites() -> [AdviceRecord] {
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        let all = fetchFavorites()
        return Array(
            all.filter { $0.createdAt >= cutoff }
                .sorted { ($0.voteRaw ?? 0) > ($1.voteRaw ?? 0) }
                .prefix(3))
    }

    func historyCount() -> Int {
        fetchAllHistory().count
    }

    /// Counts matching case files using the repository's account-scoped cache.
    /// Optional bounds make this useful for both all-time collections and
    /// calendar-bound contracts without adding more SwiftData predicates.
    func historyCount(
        category: AdviceCategory,
        tone: ToneMode? = nil,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) -> Int {
        let categoryRaw = category.rawValue
        let toneRaw = tone?.rawValue
        return fetchAllHistory().reduce(into: 0) { count, record in
            guard record.categoryRaw == categoryRaw else { return }
            if let toneRaw, record.toneRaw != toneRaw { return }
            if let startDate, record.createdAt < startDate { return }
            if let endDate, record.createdAt >= endDate { return }
            count += 1
        }
    }

    // MARK: - Leaderboard helpers

    func incrementShareCount(for id: UUID) {
        guard let record = fetchRecord(id: id) else { return }
        record.shareCountValue += 1
        save()
    }

    func incrementCopyCount(for id: UUID) {
        guard let record = fetchRecord(id: id) else { return }
        record.copyCountValue += 1
        save()
    }

    private func fetchRecord(id: UUID) -> AdviceRecord? {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let predicate = #Predicate<AdviceRecord> {
            $0.id == id &&
            ($0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount))
        }
        var descriptor = FetchDescriptor<AdviceRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func topByShares(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { $0.shareCountValue > 0 }.sorted { $0.shareCountValue > $1.shareCountValue }
                .prefix(limit))
    }

    func topByCopies(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { $0.copyCountValue > 0 }.sorted { $0.copyCountValue > $1.copyCountValue }
                .prefix(limit))
    }

    func topByLikes(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { ($0.voteRaw ?? 0) > 0 }.sorted { ($0.voteRaw ?? 0) > ($1.voteRaw ?? 0) }
                .prefix(limit))
    }

    func favoriteCount() -> Int {
        fetchFavorites().count
    }

    func todayHistoryCount(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        return fetchAllHistory().reduce(into: 0) { count, record in
            if record.createdAt >= startOfDay, record.createdAt < endOfDay {
                count += 1
            }
        }
    }

    func todayHistoryCount(
        category: AdviceCategory,
        tone: ToneMode,
        referenceDate: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let categoryRaw = category.rawValue
        let toneRaw = tone.rawValue

        // Avoid SwiftData predicates on computed enum accessors (`category`/`tone`).
        // Filtering on persisted raw fields keeps this resilient across device stores.
        return fetchAllHistory().reduce(into: 0) { count, record in
            guard record.createdAt >= startOfDay, record.createdAt < endOfDay else { return }
            if record.categoryRaw == categoryRaw && record.toneRaw == toneRaw {
                count += 1
            }
        }
    }

    func setFavorite(_ record: AdviceRecord, isFavorite: Bool) {
        record.isFavorite = isFavorite
        save()
        if isFavorite {
            SpotlightManager.index(record)
        } else {
            SpotlightManager.remove(id: record.id)
        }
    }

    func setVote(_ record: AdviceRecord, vote: AdviceVoteState) {
        record.vote = vote
        save()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        record.isFavorite.toggle()
        save()
        // #18 Spotlight Search — index when saving, remove when un-saving
        if record.isFavorite {
            SpotlightManager.index(record)
        } else {
            SpotlightManager.remove(id: record.id)
        }
    }

    func setAftermathNote(_ record: AdviceRecord, note: String) {
        record.aftermathNote = note.isEmpty ? nil : note
        save()
    }

    func delete(_ record: AdviceRecord) {
        // #18 Remove from Spotlight when deleting
        SpotlightManager.remove(id: record.id)
        context.delete(record)
        invalidateHistoryCache()
        save()
    }

    func purgeAllHistory() {
        fetchAllHistory().forEach { context.delete($0) }
        fetchAdviceFingerprints().forEach { context.delete($0) }
        invalidateHistoryCache()
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        save()
    }

    func ensureSettings() -> AppSettingsEntity {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AppSettingsEntity> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AppSettingsEntity>(predicate: accountScope)
        if let existing = (try? context.fetch(descriptor))?.first(where: {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && accountKey == Self.defaultAccountKey)
        }) {
            return existing
        }
        let created = AppSettingsEntity(ownerAccountID: accountKey)
        context.insert(created)
        save()
        return created
    }

    func missionProgress(for missionKey: String) -> MissionProgressRecord? {
        let scopedMissionKey = scopedMissionKey(missionKey)
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let predicate = #Predicate<MissionProgressRecord> {
            $0.missionKey == scopedMissionKey &&
            ($0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount))
        }
        var descriptor = FetchDescriptor<MissionProgressRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\MissionProgressRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func ensureMissionProgress(
        missionKey: String,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int
    ) -> MissionProgressRecord {
        if let existing = missionProgress(for: missionKey) {
            var didChange = false
            if existing.category != category {
                existing.categoryRaw = category.rawValue
                didChange = true
            }
            if existing.tone != tone {
                existing.toneRaw = tone.rawValue
                didChange = true
            }
            if existing.targetCount != targetCount {
                existing.targetCount = targetCount
                existing.progressCount = min(existing.progressCount, targetCount)
                didChange = true
            }
            if existing.periodRaw != periodRaw {
                existing.periodRaw = periodRaw
                didChange = true
            }
            if didChange {
                existing.updatedAt = Date()
                save()
            }
            return existing
        }

        let created = MissionProgressRecord(
            missionKey: scopedMissionKey(missionKey),
            ownerAccountID: accountKey,
            periodRaw: periodRaw,
            category: category,
            tone: tone,
            targetCount: targetCount
        )
        context.insert(created)
        save()
        return created
    }

    @discardableResult
    func incrementMissionProgress(
        missionKey: String,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int,
        by delta: Int = 1
    ) -> MissionProgressRecord {
        let record = ensureMissionProgress(
            missionKey: missionKey,
            periodRaw: periodRaw,
            category: category,
            tone: tone,
            targetCount: targetCount
        )
        guard delta > 0 else { return record }
        let nextValue = min(record.targetCount, record.progressCount + delta)
        guard nextValue != record.progressCount else { return record }
        record.progressCount = nextValue
        record.updatedAt = Date()
        save()
        return record
    }

    func markMissionRewardClaimed(missionKey: String) {
        guard let record = missionProgress(for: missionKey) else { return }
        guard !record.rewardClaimed else { return }
        record.rewardClaimed = true
        record.updatedAt = Date()
        save()
    }

    func achievementProgress(for type: AchievementType) -> AchievementProgressRecord? {
        let scopedKey = scopedAchievementKey(type.rawValue)
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let predicate = #Predicate<AchievementProgressRecord> {
            $0.achievementKey == scopedKey &&
            ($0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount))
        }
        var descriptor = FetchDescriptor<AchievementProgressRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\AchievementProgressRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func ensureAchievementProgress(
        for type: AchievementType,
        target: Int
    ) -> AchievementProgressRecord {
        if let existing = achievementProgress(for: type) {
            if existing.target != target {
                existing.target = target
                existing.progress = min(existing.progress, target)
                existing.updatedAt = Date()
                save()
            }
            return existing
        }

        let created = AchievementProgressRecord(
            achievementKey: scopedAchievementKey(type.rawValue),
            ownerAccountID: accountKey,
            type: type,
            target: target
        )
        context.insert(created)
        save()
        return created
    }

    @discardableResult
    func setAchievementProgress(
        for type: AchievementType,
        progress: Int,
        target: Int,
        unlockedAt: Date? = nil
    ) -> AchievementProgressRecord {
        let record = ensureAchievementProgress(for: type, target: target)
        let clampedProgress = min(max(progress, 0), target)
        let nextUnlockedAt = unlockedAt ?? (clampedProgress >= target ? record.unlockedAt ?? Date() : record.unlockedAt)
        guard record.progress != clampedProgress || record.target != target || record.unlockedAt != nextUnlockedAt else {
            return record
        }
        record.progress = clampedProgress
        record.target = target
        record.unlockedAt = nextUnlockedAt
        record.updatedAt = Date()
        save()
        return record
    }

    func setAchievementObservedValues(
        for type: AchievementType,
        values: Set<String>,
        target: Int
    ) {
        let record = ensureAchievementProgress(for: type, target: target)
        let normalized = Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        guard record.observedValues != normalized else { return }
        record.observedValues = normalized
        record.updatedAt = Date()
        save()
    }

    func achievementObservedValues(for type: AchievementType, target: Int) -> Set<String> {
        ensureAchievementProgress(for: type, target: target).observedValues
    }

    func hasSeenAdvice(_ normalizedAdviceLine: String) -> Bool {
        let normalized = scopedFingerprintKey(normalizedAdviceLine.normalizedForFiltering)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        ensureFingerprintCache()
        return cachedFingerprintSet?.contains(normalized) ?? false
    }

    func rememberAdviceFingerprint(
        _ normalizedAdviceLine: String,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        let normalized = scopedFingerprintKey(normalizedAdviceLine.normalizedForFiltering)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        ensureFingerprintCache()
        guard !(cachedFingerprintSet?.contains(normalized) ?? false) else { return }
        context.insert(
            AdviceFingerprint(normalizedText: normalized, ownerAccountID: accountKey, createdAt: createdAt)
        )
        cachedFingerprintSet?.insert(normalized)
        cachedSeenCount = nil
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        if saveChanges {
            save()
        }
    }

    func hasSeenAdviceInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> Bool {
        let normalized = poolFingerprint(
            for: normalizedAdviceLine,
            category: category,
            tone: tone
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        ensureFingerprintCache()
        return cachedFingerprintSet?.contains(normalized) ?? false
    }

    func rememberAdviceFingerprintInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        let normalized = poolFingerprint(
            for: normalizedAdviceLine,
            category: category,
            tone: tone
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        ensureFingerprintCache()
        guard !(cachedFingerprintSet?.contains(normalized) ?? false) else { return }
        context.insert(
            AdviceFingerprint(normalizedText: normalized, ownerAccountID: accountKey, createdAt: createdAt)
        )
        cachedFingerprintSet?.insert(normalized)
        cachedSeenCount = nil
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        if saveChanges {
            save()
        }
    }

    func seenAdviceCount() -> Int {
        if let cached = cachedSeenCount { return cached }
        ensureFingerprintCache()
        let count = (cachedFingerprintSet ?? [])
            .filter { !$0.contains("::\(Self.poolFingerprintPrefix)") }
            .count
        cachedSeenCount = count
        return count
    }

    func seedAdviceMemoryFromHistoryIfNeeded() {
        guard seenAdviceCount() == 0 else { return }
        let history = fetchAllHistory()
        guard !history.isEmpty else { return }
        var seenGlobal = Set<String>()
        var seenPool = Set<String>()
        for record in history {
            let normalizedGlobal = record.adviceLine.normalizedForFiltering
            if seenGlobal.insert(normalizedGlobal).inserted {
                context.insert(
                    AdviceFingerprint(
                        normalizedText: scopedFingerprintKey(normalizedGlobal),
                        ownerAccountID: accountKey,
                        createdAt: record.createdAt
                    )
                )
            }
            let normalizedPool = poolFingerprint(
                for: record.adviceLine.normalizedForFiltering,
                category: record.category,
                tone: record.tone
            )
            if seenPool.insert(normalizedPool).inserted {
                context.insert(
                    AdviceFingerprint(
                        normalizedText: normalizedPool,
                        ownerAccountID: accountKey,
                        createdAt: record.createdAt
                    ))
            }
        }
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        save()
        cachedFingerprintSet = nil
        cachedSeenCount = nil
    }

    @discardableResult
    func addSuggestion(
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) -> UserAdviceSuggestion {
        let suggestion = UserAdviceSuggestion(
            ownerAccountID: accountKey,
            category: category,
            topic: topic,
            adviceLine: adviceLine
        )
        context.insert(suggestion)
        save()
        pruneSuggestions(maxCount: 250)
        return suggestion
    }

    @discardableResult
    func addQuoteSuggestion(
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) -> UserQuoteSuggestion {
        let suggestion = UserQuoteSuggestion(
            ownerAccountID: accountKey,
            category: category,
            source: source,
            quoteText: quoteText
        )
        context.insert(suggestion)
        save()
        pruneQuoteSuggestions(maxCount: 250)
        return suggestion
    }

    func fetchSuggestions(limit: Int = 40) -> [UserAdviceSuggestion] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserAdviceSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        return Array(((try? context.fetch(descriptor)) ?? []).prefix(limit))
    }

    func fetchQuoteSuggestions(limit: Int = 60) -> [UserQuoteSuggestion] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserQuoteSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        return Array(((try? context.fetch(descriptor)) ?? []).prefix(limit))
    }

    func suggestionCount() -> Int {
        fetchSuggestions(limit: Int.max).count
    }

    func quoteSuggestionCount() -> Int {
        fetchQuoteSuggestions(limit: Int.max).count
    }

    func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        context.delete(suggestion)
        save()
    }

    func deleteQuoteSuggestion(_ suggestion: UserQuoteSuggestion) {
        context.delete(suggestion)
        save()
    }

    func setQuoteVote(quoteID: String, vote: AdviceVoteState) {
        let existing = quoteVoteRecord(for: quoteID)
        if vote == .none {
            if let existing {
                context.delete(existing)
                save()
            }
            return
        }
        if let existing {
            existing.vote = vote
            existing.updatedAt = Date()
        } else {
            context.insert(
                QuoteVoteRecord(
                    quoteID: scopedQuoteID(quoteID),
                    ownerAccountID: accountKey,
                    vote: vote,
                    updatedAt: Date()
                )
            )
        }
        save()
    }

    func quoteVote(for quoteID: String) -> AdviceVoteState {
        quoteVoteRecord(for: quoteID)?.vote ?? .none
    }

    func quoteVoteMap() -> [String: AdviceVoteState] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<QuoteVoteRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? [])
        return Dictionary(uniqueKeysWithValues: all.map { (unscopedQuoteID($0.quoteID), $0.vote) })
    }

    func recordLearningSignal(scopeKey: String, type: LearningSignalType, weight: Double = 1.0) {
        let normalizedKey = scopedLearningScope(scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines))
        let delta = max(weight, 0)
        guard !normalizedKey.isEmpty, delta > 0 else { return }

        ensureLearningCache()
        let record: LearningStatRecord
        if let existing = cachedLearningStatsByKey?[normalizedKey] {
            record = existing
        } else {
            record = LearningStatRecord(scopeKey: normalizedKey, ownerAccountID: accountKey)
            context.insert(record)
            cachedLearningStatsByKey?[normalizedKey] = record
        }

        switch type {
        case .shown:
            record.shownCount += delta
        case .like:
            record.likeCount += delta
        case .dislike:
            record.dislikeCount += delta
        case .favorite:
            record.favoriteCount += delta
        case .copy:
            record.copyCount += delta
        case .share:
            record.shareCount += delta
        case .regen:
            record.regenCount += delta
        }
        record.updatedAt = Date()

        pruneLearningStats(maxCount: Self.maxLearningScopes)
        save()
    }

    func learningStat(for scopeKey: String) -> LearningStatRecord? {
        let normalizedKey = scopedLearningScope(scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines))
        guard !normalizedKey.isEmpty else { return nil }
        ensureLearningCache()
        return cachedLearningStatsByKey?[normalizedKey]
    }

    func learningSnapshot(for scopeKey: String) -> LearningStatSnapshot {
        learningStat(for: scopeKey)?.snapshot ?? .empty
    }

    func learningStats(prefix: String) -> [LearningStatRecord] {
        let normalizedPrefix = prefix
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let scopedPrefix = scopedLearningScope(normalizedPrefix)
        ensureLearningCache()
        return (cachedLearningStatsByKey ?? [:])
            .values
            .filter { normalizedPrefix.isEmpty || $0.scopeKey.hasPrefix(scopedPrefix) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Total explicit interaction signals across all scopes. Used for adaptive profile selection.
    func totalLearningSignalCount() -> Int {
        ensureLearningCache()
        return (cachedLearningStatsByKey ?? [:]).values.reduce(0) { sum, stat in
            sum
                + Int(
                    stat.likeCount + stat.dislikeCount + stat.favoriteCount
                        + stat.copyCount + stat.shareCount + stat.regenCount)
        }
    }

    func pruneSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserAdviceSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? [])
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneQuoteSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserQuoteSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? [])
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneHistory(maxCount: Int) {
        guard maxCount > 0 else { return }
        let all = fetchAllHistory()
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        invalidateHistoryCache()
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription)")
        }
    }

    private func poolFingerprint(
        for normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> String {
        let normalized = normalizedAdviceLine.normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return scopedFingerprintKey(
            "\(Self.poolFingerprintPrefix)\(category.rawValue)|\(tone.rawValue)|\(normalized)"
        )
    }

    private func ensureFingerprintCache() {
        guard cachedFingerprintSet == nil else { return }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AdviceFingerprint> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        var descriptor = FetchDescriptor<AdviceFingerprint>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maxAdviceFingerprints
        let all = ((try? context.fetch(descriptor)) ?? [])
        cachedFingerprintSet = Set(all.map(\.normalizedText))
    }

    private func ensureLearningCache() {
        guard cachedLearningStatsByKey == nil else { return }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<LearningStatRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<LearningStatRecord>(predicate: accountScope)
        let all = ((try? context.fetch(descriptor)) ?? [])
        cachedLearningStatsByKey = Dictionary(uniqueKeysWithValues: all.map { ($0.scopeKey, $0) })
    }

    func pruneAdviceFingerprints(maxCount: Int) {
        guard maxCount > 0 else { return }
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AdviceFingerprint> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AdviceFingerprint>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? [])
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        cachedFingerprintSet = nil
        cachedSeenCount = nil
    }

    private func pruneLearningStats(maxCount: Int) {
        guard maxCount > 0 else { return }
        ensureLearningCache()
        guard let current = cachedLearningStatsByKey, current.count > maxCount else { return }
        let ordered = current.values.sorted { $0.updatedAt > $1.updatedAt }
        for stale in ordered.suffix(from: maxCount) {
            context.delete(stale)
            cachedLearningStatsByKey?.removeValue(forKey: stale.scopeKey)
        }
    }

    private func quoteVoteRecord(for quoteID: String) -> QuoteVoteRecord? {
        let scopedQuoteID = scopedQuoteID(quoteID)
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let predicate = #Predicate<QuoteVoteRecord> {
            $0.quoteID == scopedQuoteID &&
            ($0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount))
        }
        var descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func purgeCurrentAccountData() {
        fetchAllHistory().forEach { context.delete($0) }
        fetchAdviceFingerprints().forEach { context.delete($0) }
        fetchAdviceSuggestions().forEach { context.delete($0) }
        fetchQuoteSuggestionsAll().forEach { context.delete($0) }
        fetchQuoteVoteRecords().forEach { context.delete($0) }
        fetchLearningStatRecords().forEach { context.delete($0) }
        fetchMissionProgressRecords().forEach { context.delete($0) }
        fetchAchievementProgressRecords().forEach { context.delete($0) }
        if let settings = currentSettingsEntity() {
            context.delete(settings)
        }
        invalidateHistoryCache()
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        cachedLearningStatsByKey = nil
        save()
    }

    func purgeAllLocalData() {
        deleteAll(AdviceRecord.self)
        deleteAll(AdviceFingerprint.self)
        deleteAll(UserAdviceSuggestion.self)
        deleteAll(UserQuoteSuggestion.self)
        deleteAll(QuoteVoteRecord.self)
        deleteAll(LearningStatRecord.self)
        deleteAll(MissionProgressRecord.self)
        deleteAll(AchievementProgressRecord.self)
        deleteAll(AppSettingsEntity.self)
        invalidateHistoryCache()
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        cachedLearningStatsByKey = nil
        save()
    }

    private func currentSettingsEntity() -> AppSettingsEntity? {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AppSettingsEntity> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AppSettingsEntity>(predicate: accountScope)
        return (try? context.fetch(descriptor))?.first
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        ((try? context.fetch(descriptor)) ?? []).forEach { context.delete($0) }
        if T.self == AdviceRecord.self {
            invalidateHistoryCache()
        }
    }

    private func fetchAdviceFingerprints() -> [AdviceFingerprint] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AdviceFingerprint> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AdviceFingerprint>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func invalidateHistoryCache() {
        cachedHistoryRecords = nil
    }

    private func fetchAdviceSuggestions() -> [UserAdviceSuggestion] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserAdviceSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func fetchQuoteSuggestionsAll() -> [UserQuoteSuggestion] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<UserQuoteSuggestion> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func fetchQuoteVoteRecords() -> [QuoteVoteRecord] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<QuoteVoteRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func fetchLearningStatRecords() -> [LearningStatRecord] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<LearningStatRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<LearningStatRecord>(predicate: accountScope)
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func fetchMissionProgressRecords() -> [MissionProgressRecord] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<MissionProgressRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<MissionProgressRecord>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\MissionProgressRecord.updatedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func fetchAchievementProgressRecords() -> [AchievementProgressRecord] {
        let isDefaultAccount = accountKey == Self.defaultAccountKey
        let accountScope = #Predicate<AchievementProgressRecord> {
            $0.ownerAccountID == accountKey || ($0.ownerAccountID == nil && isDefaultAccount)
        }
        let descriptor = FetchDescriptor<AchievementProgressRecord>(
            predicate: accountScope,
            sortBy: [SortDescriptor(\AchievementProgressRecord.updatedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    private func scopedFingerprintKey(_ value: String) -> String {
        "\(accountKey)::\(value)"
    }

    private func scopedLearningScope(_ value: String) -> String {
        "\(accountKey)::\(value)"
    }

    private func scopedMissionKey(_ missionKey: String) -> String {
        "\(accountKey)::\(missionKey)"
    }

    private func scopedAchievementKey(_ achievementKey: String) -> String {
        "\(accountKey)::\(achievementKey)"
    }

    private func scopedQuoteID(_ quoteID: String) -> String {
        "\(accountKey)::\(quoteID)"
    }

    private func unscopedQuoteID(_ quoteID: String) -> String {
        if let range = quoteID.range(of: "::") {
            return String(quoteID[range.upperBound...])
        }
        return quoteID
    }
}
