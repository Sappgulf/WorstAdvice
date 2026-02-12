import Foundation
import SwiftUI

// MARK: - AppState

@Observable
final class AppState {

    // MARK: Persistence batching

    private var isBatchUpdating = false
    private var needsSaveAfterBatch = false

    // MARK: Persisted properties

    var askCount: Int {
        didSet { markDirty() }
    }

    var lastAskDate: Date? {
        didSet { markDirty() }
    }

    var lastTier: AdviceTier {
        didSet { markDirty() }
    }

    var recentIDs: [String] {
        didSet { markDirty() }
    }

    // Stats
    var totalLifetimeAsks: Int {
        didSet { markDirty() }
    }

    var highestTierReached: AdviceTier {
        didSet { markDirty() }
    }

    var categoryHits: [String: Int] {
        didSet { markDirty() }
    }

    var firstAskDate: Date? {
        didSet { markDirty() }
    }

    var favoriteIDs: [String] {
        didSet { markDirty() }
    }

    var selectedCategory: AdviceCategory? {
        didSet { markDirty() }
    }

    var streakCount: Int {
        didSet { markDirty() }
    }

    var lastActiveDate: Date? {
        didSet { markDirty() }
    }

    // MARK: Transient (not persisted)

    var currentAdvice: AdviceEntry?
    var isFirstLaunch: Bool
    var showOnboarding: Bool

    // MARK: - Init

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(StateSnapshot.self, from: data) {
            self.askCount = snapshot.askCount
            self.lastAskDate = snapshot.lastAskDate
            self.lastTier = snapshot.lastTier
            self.recentIDs = snapshot.recentIDs
            self.totalLifetimeAsks = snapshot.totalLifetimeAsks ?? 0
            self.highestTierReached = snapshot.highestTierReached ?? .tier1
            self.categoryHits = snapshot.categoryHits ?? [:]
            self.firstAskDate = snapshot.firstAskDate
            self.favoriteIDs = snapshot.favoriteIDs ?? []
            self.selectedCategory = snapshot.selectedCategory
            self.streakCount = snapshot.streakCount ?? 0
            self.lastActiveDate = snapshot.lastActiveDate
            self.isFirstLaunch = false
            self.showOnboarding = false
        } else {
            self.askCount = 0
            self.lastAskDate = nil
            self.lastTier = .tier1
            self.recentIDs = []
            self.totalLifetimeAsks = 0
            self.highestTierReached = .tier1
            self.categoryHits = [:]
            self.firstAskDate = nil
            self.favoriteIDs = []
            self.selectedCategory = nil
            self.streakCount = 0
            self.lastActiveDate = nil
            self.isFirstLaunch = true
            self.showOnboarding = true
        }
    }

    init(askCount: Int, lastAskDate: Date?, lastTier: AdviceTier, recentIDs: [String]) {
        self.askCount = askCount
        self.lastAskDate = lastAskDate
        self.lastTier = lastTier
        self.recentIDs = recentIDs
        self.totalLifetimeAsks = 0
        self.highestTierReached = .tier1
        self.categoryHits = [:]
        self.firstAskDate = nil
        self.favoriteIDs = []
        self.selectedCategory = nil
        self.streakCount = 0
        self.lastActiveDate = nil
        self.isFirstLaunch = false
        self.showOnboarding = false
    }

    // MARK: - Stat helpers

    func recordAsk(tier: AdviceTier, category: AdviceCategory?) {
        performBatchUpdate {
            totalLifetimeAsks += 1
            if tier > highestTierReached {
                highestTierReached = tier
            }
            if let cat = category {
                categoryHits[cat.rawValue, default: 0] += 1
            }
            if firstAskDate == nil {
                firstAskDate = Date()
            }
        }
    }

    func registerGeneratedAdvice(_ entry: AdviceEntry, tier: AdviceTier, at now: Date) {
        performBatchUpdate {
            askCount += 1
            currentAdvice = entry
            lastTier = tier
            appendRecentID(entry.id)
            lastAskDate = now
            updateStreak(at: now)
            recordAsk(tier: tier, category: entry.category)
        }
    }

    func registerMoreLikeThis(_ entry: AdviceEntry, tier: AdviceTier, at now: Date = Date()) {
        performBatchUpdate {
            currentAdvice = entry
            appendRecentID(entry.id)
            updateStreak(at: now)
            recordAsk(tier: tier, category: entry.category)
        }
    }

    func presentSavedAdvice(_ entry: AdviceEntry) {
        performBatchUpdate {
            currentAdvice = entry
            lastTier = entry.tier
            appendRecentID(entry.id)
        }
    }

    func toggleFavorite(id: String) {
        performBatchUpdate {
            if let index = favoriteIDs.firstIndex(of: id) {
                favoriteIDs.remove(at: index)
            } else {
                favoriteIDs.insert(id, at: 0)
                if favoriteIDs.count > 200 {
                    favoriteIDs.removeLast(favoriteIDs.count - 200)
                }
            }
        }
    }

    func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    var topCategory: AdviceCategory? {
        guard let top = categoryHits.max(by: { $0.value < $1.value }) else { return nil }
        return AdviceCategory(rawValue: top.key)
    }

    // MARK: - Persistence

    private static let storageKey = "com.worstadvice.appstate"

    private func markDirty() {
        if isBatchUpdating {
            needsSaveAfterBatch = true
            return
        }
        save()
    }

    private func performBatchUpdate(_ updates: () -> Void) {
        let wasBatching = isBatchUpdating
        isBatchUpdating = true
        updates()
        isBatchUpdating = wasBatching

        guard !isBatchUpdating, needsSaveAfterBatch else { return }
        needsSaveAfterBatch = false
        save()
    }

    private func appendRecentID(_ id: String) {
        recentIDs.append(id)
        let overflow = recentIDs.count - 64
        if overflow > 0 {
            recentIDs.removeFirst(overflow)
        }
    }

    private func updateStreak(at now: Date) {
        let calendar = Calendar.current
        guard let last = lastActiveDate else {
            streakCount = 1
            lastActiveDate = now
            return
        }

        if calendar.isDate(last, inSameDayAs: now) {
            lastActiveDate = now
            return
        }

        let lastStart = calendar.startOfDay(for: last)
        let nowStart = calendar.startOfDay(for: now)
        let dayDiff = calendar.dateComponents([.day], from: lastStart, to: nowStart).day ?? 0

        if dayDiff == 1 {
            streakCount += 1
        } else {
            streakCount = 1
        }
        lastActiveDate = now
    }

    private func save() {
        let snapshot = StateSnapshot(
            askCount: askCount,
            lastAskDate: lastAskDate,
            lastTier: lastTier,
            recentIDs: recentIDs,
            totalLifetimeAsks: totalLifetimeAsks,
            highestTierReached: highestTierReached,
            categoryHits: categoryHits,
            firstAskDate: firstAskDate,
            favoriteIDs: favoriteIDs,
            selectedCategory: selectedCategory,
            streakCount: streakCount,
            lastActiveDate: lastActiveDate
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func reset() {
        performBatchUpdate {
            askCount = 0
            lastAskDate = nil
            lastTier = .tier1
            recentIDs = []
            totalLifetimeAsks = 0
            highestTierReached = .tier1
            categoryHits = [:]
            firstAskDate = nil
            favoriteIDs = []
            selectedCategory = nil
            streakCount = 0
            lastActiveDate = nil
            currentAdvice = nil
            isFirstLaunch = false
        }
    }
}

// MARK: - Codable snapshot

private struct StateSnapshot: Codable {
    let askCount: Int
    let lastAskDate: Date?
    let lastTier: AdviceTier
    let recentIDs: [String]
    let totalLifetimeAsks: Int?
    let highestTierReached: AdviceTier?
    let categoryHits: [String: Int]?
    let firstAskDate: Date?
    let favoriteIDs: [String]?
    let selectedCategory: AdviceCategory?
    let streakCount: Int?
    let lastActiveDate: Date?
}
