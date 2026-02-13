import Foundation
import Observation
import OSLog
import SwiftData
import UIKit

protocol AnalyticsTracking {
    func track(_ event: String, properties: [String: String])
}

struct AppAnalyticsTracker: AnalyticsTracking {
    private let logger = Logger(subsystem: "com.worstadvice.app", category: "analytics")

    func track(_ event: String, properties: [String: String] = [:]) {
        let payload = properties.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
        if payload.isEmpty {
            logger.info("event=\(event, privacy: .public)")
        } else {
            logger.info("event=\(event, privacy: .public) props=\(payload, privacy: .public)")
        }
    }
}

@Model
final class AdviceRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var categoryRaw: String
    var toneRaw: String
    var adviceLine: String
    var rationaleLine: String?
    var isFavorite: Bool
    var voteRaw: Int?

    init(
        id: UUID = UUID(),
        createdAt: Date,
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        isFavorite: Bool = false,
        vote: AdviceVoteState = .none
    ) {
        self.id = id
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.isFavorite = isFavorite
        self.voteRaw = vote.rawValue
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }

    var tone: ToneMode {
        ToneMode(rawValue: toneRaw) ?? .corporateConsultant
    }

    var vote: AdviceVoteState {
        get { AdviceVoteState(rawValue: voteRaw ?? 0) ?? .none }
        set { voteRaw = newValue.rawValue }
    }
}

@Model
final class AdviceFingerprint {
    @Attribute(.unique) var normalizedText: String
    var createdAt: Date

    init(normalizedText: String, createdAt: Date = Date()) {
        self.normalizedText = normalizedText
        self.createdAt = createdAt
    }
}

@Model
final class UserAdviceSuggestion {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var categoryRaw: String
    var topic: String
    var adviceLine: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.topic = topic
        self.adviceLine = adviceLine
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }
}

@Model
final class UserQuoteSuggestion {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var categoryRaw: String
    var source: String
    var quoteText: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.source = source
        self.quoteText = quoteText
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }
}

@Model
final class QuoteVoteRecord {
    @Attribute(.unique) var quoteID: String
    var voteRaw: Int
    var updatedAt: Date

    init(
        quoteID: String,
        vote: AdviceVoteState = .none,
        updatedAt: Date = Date()
    ) {
        self.quoteID = quoteID
        self.voteRaw = vote.rawValue
        self.updatedAt = updatedAt
    }

    var vote: AdviceVoteState {
        get { AdviceVoteState(rawValue: voteRaw) ?? .none }
        set { voteRaw = newValue.rawValue }
    }
}

@Model
final class AppSettingsEntity {
    @Attribute(.unique) var id: UUID
    var themeRaw: String
    var includeDisclaimerOnShare: Bool
    var reduceMotion: Bool
    var hapticsEnabled: Bool
    var includeRationale: Bool
    var preferredTemplateRaw: String
    var preferredAspectRaw: String
    var preferredSharePresetRaw: String?
    var preferredContentPackRaw: String?
    var strictNoRepeatsRaw: Bool?
    var communityOnlyModeRaw: Bool?
    var tabOrderRaw: String?

    init(
        id: UUID = UUID(),
        theme: ThemeMode = .warm,
        includeDisclaimerOnShare: Bool = true,
        reduceMotion: Bool = false,
        hapticsEnabled: Bool = true,
        includeRationale: Bool = true,
        preferredTemplate: ShareCardTemplate = .ember,
        preferredAspect: ShareAspectRatio = .square,
        preferredSharePreset: ShareCaptionPreset = .deadpan,
        preferredContentPack: ContentPack = .classic,
        strictNoRepeats: Bool = true,
        communityOnlyMode: Bool = false,
        tabOrder: [AppTab] = AppTab.defaultOrder
    ) {
        self.id = id
        self.themeRaw = theme.rawValue
        self.includeDisclaimerOnShare = includeDisclaimerOnShare
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
        self.includeRationale = includeRationale
        self.preferredTemplateRaw = preferredTemplate.rawValue
        self.preferredAspectRaw = preferredAspect.rawValue
        self.preferredSharePresetRaw = preferredSharePreset.rawValue
        self.preferredContentPackRaw = preferredContentPack.rawValue
        self.strictNoRepeatsRaw = strictNoRepeats
        self.communityOnlyModeRaw = communityOnlyMode
        self.tabOrderRaw = tabOrder.map(\.rawValue).joined(separator: ",")
    }

    var theme: ThemeMode {
        get { ThemeMode(rawValue: themeRaw) ?? .warm }
        set { themeRaw = newValue.rawValue }
    }

    var preferredTemplate: ShareCardTemplate {
        get { ShareCardTemplate(rawValue: preferredTemplateRaw) ?? .ember }
        set { preferredTemplateRaw = newValue.rawValue }
    }

    var preferredAspect: ShareAspectRatio {
        get { ShareAspectRatio(rawValue: preferredAspectRaw) ?? .square }
        set { preferredAspectRaw = newValue.rawValue }
    }

    var preferredSharePreset: ShareCaptionPreset {
        get { ShareCaptionPreset(rawValue: preferredSharePresetRaw ?? "") ?? .deadpan }
        set { preferredSharePresetRaw = newValue.rawValue }
    }

    var preferredContentPack: ContentPack {
        get { ContentPack(rawValue: preferredContentPackRaw ?? "") ?? .classic }
        set { preferredContentPackRaw = newValue.rawValue }
    }

    var strictNoRepeats: Bool {
        get { strictNoRepeatsRaw ?? true }
        set { strictNoRepeatsRaw = newValue }
    }

    var communityOnlyMode: Bool {
        get { communityOnlyModeRaw ?? false }
        set { communityOnlyModeRaw = newValue }
    }

    var tabOrder: [AppTab] {
        get {
            let parts = (tabOrderRaw ?? "")
                .split(separator: ",")
                .compactMap { AppTab(rawValue: String($0)) }
            return Self.sanitizedTabOrder(parts)
        }
        set {
            tabOrderRaw = Self.sanitizedTabOrder(newValue).map(\.rawValue).joined(separator: ",")
        }
    }

    private static func sanitizedTabOrder(_ candidate: [AppTab]) -> [AppTab] {
        var ordered: [AppTab] = []
        var seen = Set<AppTab>()
        for tab in candidate where seen.insert(tab).inserted {
            ordered.append(tab)
        }
        for tab in AppTab.defaultOrder where seen.insert(tab).inserted {
            ordered.append(tab)
        }
        let middle = ordered.filter { $0 != .generate && $0 != .settings }
        return [.generate] + middle + [.settings]
    }
}

@MainActor
final class AdviceRepository {
    private static let poolFingerprintPrefix = "pool::"

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func insert(_ generated: GeneratedAdvice) -> AdviceRecord {
        let record = AdviceRecord(
            id: generated.id,
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
        pruneHistory(maxCount: 50)
        return record
    }

    func fetchHistory(limit: Int = 50) -> [AdviceRecord] {
        var descriptor = FetchDescriptor<AdviceRecord>(
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchAllHistory() -> [AdviceRecord] {
        let descriptor = FetchDescriptor<AdviceRecord>(
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchFavorites() -> [AdviceRecord] {
        let predicate = #Predicate<AdviceRecord> { $0.isFavorite }
        let descriptor = FetchDescriptor<AdviceRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func setFavorite(_ record: AdviceRecord, isFavorite: Bool) {
        record.isFavorite = isFavorite
        save()
    }

    func setVote(_ record: AdviceRecord, vote: AdviceVoteState) {
        record.vote = vote
        save()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        record.isFavorite.toggle()
        save()
    }

    func delete(_ record: AdviceRecord) {
        context.delete(record)
        save()
    }

    func purgeAllHistory() {
        fetchAllHistory().forEach { context.delete($0) }
        save()
    }

    func ensureSettings() -> AppSettingsEntity {
        let descriptor = FetchDescriptor<AppSettingsEntity>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppSettingsEntity()
        context.insert(created)
        save()
        return created
    }

    func hasSeenAdvice(_ normalizedAdviceLine: String) -> Bool {
        let normalized = normalizedAdviceLine.normalizedForFiltering
        let predicate = #Predicate<AdviceFingerprint> { $0.normalizedText == normalized }
        var descriptor = FetchDescriptor<AdviceFingerprint>(
            predicate: predicate,
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor)) ?? []).isEmpty == false
    }

    func rememberAdviceFingerprint(
        _ normalizedAdviceLine: String,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        let normalized = normalizedAdviceLine.normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !hasSeenAdvice(normalized) else { return }
        context.insert(AdviceFingerprint(normalizedText: normalized, createdAt: createdAt))
        if saveChanges {
            save()
        }
    }

    func hasSeenAdviceInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> Bool {
        hasSeenAdvice(poolFingerprint(for: normalizedAdviceLine, category: category, tone: tone))
    }

    func rememberAdviceFingerprintInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        rememberAdviceFingerprint(
            poolFingerprint(for: normalizedAdviceLine, category: category, tone: tone),
            createdAt: createdAt,
            saveChanges: saveChanges
        )
    }

    func seenAdviceCount() -> Int {
        let descriptor = FetchDescriptor<AdviceFingerprint>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { !$0.normalizedText.hasPrefix(Self.poolFingerprintPrefix) }.count
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
                context.insert(AdviceFingerprint(normalizedText: normalizedGlobal, createdAt: record.createdAt))
            }
            let normalizedPool = poolFingerprint(
                for: record.adviceLine.normalizedForFiltering,
                category: record.category,
                tone: record.tone
            )
            if seenPool.insert(normalizedPool).inserted {
                context.insert(AdviceFingerprint(normalizedText: normalizedPool, createdAt: record.createdAt))
            }
        }
        save()
    }

    @discardableResult
    func addSuggestion(
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) -> UserAdviceSuggestion {
        let suggestion = UserAdviceSuggestion(
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
        var descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchQuoteSuggestions(limit: Int = 60) -> [UserQuoteSuggestion] {
        var descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func suggestionCount() -> Int {
        let descriptor = FetchDescriptor<UserAdviceSuggestion>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func quoteSuggestionCount() -> Int {
        let descriptor = FetchDescriptor<UserQuoteSuggestion>()
        return (try? context.fetchCount(descriptor)) ?? 0
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
            context.insert(QuoteVoteRecord(quoteID: quoteID, vote: vote, updatedAt: Date()))
        }
        save()
    }

    func quoteVote(for quoteID: String) -> AdviceVoteState {
        quoteVoteRecord(for: quoteID)?.vote ?? .none
    }

    func quoteVoteMap() -> [String: AdviceVoteState] {
        let descriptor = FetchDescriptor<QuoteVoteRecord>(
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: all.map { ($0.quoteID, $0.vote) })
    }

    func pruneSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneQuoteSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneHistory(maxCount: Int) {
        guard maxCount > 0 else { return }
        let all = fetchAllHistory()
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func save() {
        try? context.save()
    }

    private func poolFingerprint(
        for normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> String {
        let normalized = normalizedAdviceLine.normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(Self.poolFingerprintPrefix)\(category.rawValue)|\(tone.rawValue)|\(normalized)"
    }

    private func quoteVoteRecord(for quoteID: String) -> QuoteVoteRecord? {
        let predicate = #Predicate<QuoteVoteRecord> { $0.quoteID == quoteID }
        var descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private let repository: AdviceRepository
    private(set) var settings: AppSettingsEntity

    init(repository: AdviceRepository) {
        self.repository = repository
        self.settings = repository.ensureSettings()
    }

    var theme: ThemeMode {
        get { settings.theme }
        set {
            settings.theme = newValue
            repository.save()
        }
    }

    var includeDisclaimerOnShare: Bool {
        get { settings.includeDisclaimerOnShare }
        set {
            settings.includeDisclaimerOnShare = newValue
            repository.save()
        }
    }

    var reduceMotion: Bool {
        get { settings.reduceMotion }
        set {
            settings.reduceMotion = newValue
            repository.save()
        }
    }

    var hapticsEnabled: Bool {
        get { settings.hapticsEnabled }
        set {
            settings.hapticsEnabled = newValue
            repository.save()
        }
    }

    var includeRationale: Bool {
        get { settings.includeRationale }
        set {
            settings.includeRationale = newValue
            repository.save()
        }
    }

    var preferredTemplate: ShareCardTemplate {
        get { settings.preferredTemplate }
        set {
            settings.preferredTemplate = newValue
            repository.save()
        }
    }

    var preferredAspect: ShareAspectRatio {
        get { settings.preferredAspect }
        set {
            settings.preferredAspect = newValue
            repository.save()
        }
    }

    var preferredSharePreset: ShareCaptionPreset {
        get { settings.preferredSharePreset }
        set {
            settings.preferredSharePreset = newValue
            repository.save()
        }
    }

    var preferredContentPack: ContentPack {
        get { settings.preferredContentPack }
        set {
            settings.preferredContentPack = newValue
            repository.save()
        }
    }

    var strictNoRepeats: Bool {
        get { settings.strictNoRepeats }
        set {
            settings.strictNoRepeats = newValue
            repository.save()
        }
    }

    var communityOnlyMode: Bool {
        get { settings.communityOnlyMode }
        set {
            settings.communityOnlyMode = newValue
            repository.save()
        }
    }

    var tabOrder: [AppTab] {
        get { settings.tabOrder }
        set {
            settings.tabOrder = newValue
            repository.save()
        }
    }

    var reorderableTabs: [AppTab] {
        tabOrder.filter { $0 != .generate && $0 != .settings }
    }

    func moveReorderableTabs(from source: IndexSet, to destination: Int) {
        var items = reorderableTabs
        let moving = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let insertion = max(0, min(destination, items.count))
        items.insert(contentsOf: moving, at: insertion)
        tabOrder = [.generate] + items + [.settings]
    }

    func moveReorderableTabUp(at index: Int) {
        var items = reorderableTabs
        guard index > 0, index < items.count else { return }
        items.swapAt(index, index - 1)
        tabOrder = [.generate] + items + [.settings]
    }

    func moveReorderableTabDown(at index: Int) {
        var items = reorderableTabs
        guard index >= 0, index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
        tabOrder = [.generate] + items + [.settings]
    }

    func resetTabOrder() {
        tabOrder = AppTab.defaultOrder
    }
}

struct BadQuoteService: Sendable {
    let quotes: [BadQuote]

    init(quotes: [BadQuote] = Self.defaultQuotes) {
        self.quotes = quotes
    }

    func quoteOfDay(now: Date = Date()) -> BadQuote {
        let bank = quotes.isEmpty ? Self.defaultQuotes : quotes
        let day = Int(floor(now.timeIntervalSince1970 / 86_400))
        let index = ((day % bank.count) + bank.count) % bank.count
        return bank[index]
    }

    func randomQuote(excluding excludedID: String? = nil, seed: Int? = nil) -> BadQuote {
        let bank = quotes.isEmpty ? Self.defaultQuotes : quotes
        guard !bank.isEmpty else {
            return BadQuote(id: "fallback", text: "Never revise a bad plan while it is still confidently wrong.", source: "Urgent Memo", category: .productivity)
        }
        let filtered = bank.filter { excludedID == nil || $0.id != excludedID }
        let candidateBank = filtered.isEmpty ? bank : filtered
        let chosenSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        let index = abs(chosenSeed) % candidateBank.count
        return candidateBank[index]
    }

    static let defaultQuotes: [BadQuote] = [
        BadQuote(id: "career-1", text: "If nobody understands the plan, call it leadership.", source: "Quarterly Wisdom Deck", category: .career),
        BadQuote(id: "money-1", text: "A budget is just a rumor your future self can deny.", source: "Finance Group Chat", category: .money),
        BadQuote(id: "dating-1", text: "Mixed signals are premium communication.", source: "Unlicensed Relationship Coach", category: .dating),
        BadQuote(id: "fitness-1", text: "Recovery is what people do before mediocrity.", source: "Locker Room Oracle", category: .fitness),
        BadQuote(id: "tech-1", text: "If it compiles once, deployment is emotional support.", source: "Hotfix Newsletter", category: .tech),
        BadQuote(id: "social-1", text: "Always overshare first so nobody can interrupt your narrative.", source: "Brunch Panelist", category: .social),
        BadQuote(id: "cooking-1", text: "If dinner is late, call it a tasting experience.", source: "Kitchen Strategy Lead", category: .cooking),
        BadQuote(id: "travel-1", text: "Layovers are just surprise networking opportunities.", source: "Airport Visionary", category: .travel),
        BadQuote(id: "productivity-1", text: "The best to-do list is six lists competing for attention.", source: "Productivity Syndicate", category: .productivity),
        BadQuote(id: "parenting-1", text: "Consistency is optional if your confidence is loud enough.", source: "Family Process Consultant", category: .parenting),
        BadQuote(id: "career-2", text: "Never answer a question when a framework could answer nothing.", source: "Boardroom Proverbs", category: .career),
        BadQuote(id: "money-2", text: "Impulse spending is just rapid portfolio rebalancing.", source: "Wallet Whisperer", category: .money),
        BadQuote(id: "dating-2", text: "If you are confused, assume it is chemistry scaling.", source: "Situationship Operations", category: .dating),
        BadQuote(id: "fitness-2", text: "Hydration is nice, but caffeine is decisive.", source: "Preworkout Philosopher", category: .fitness),
        BadQuote(id: "tech-2", text: "Documentation is a confidence leak.", source: "Sprint Retrospective Poet", category: .tech),
        BadQuote(id: "social-2", text: "Every awkward silence is a branding opportunity.", source: "Event Tactician", category: .social),
        BadQuote(id: "cooking-2", text: "A burnt edge is just a flavor thesis.", source: "Midnight Chef Council", category: .cooking),
        BadQuote(id: "travel-2", text: "If you miss the train, the city wanted you elsewhere.", source: "Transit Mystic", category: .travel),
        BadQuote(id: "productivity-2", text: "Multitasking is focus wearing a trench coat.", source: "Calendar Economist", category: .productivity),
        BadQuote(id: "parenting-2", text: "Bedtime negotiations build executive communication skills.", source: "Household Strategy Memo", category: .parenting),
        BadQuote(id: "career-3", text: "If the timeline slips, rename the milestone.", source: "Roadmap Preservation Society", category: .career),
        BadQuote(id: "money-3", text: "Credit limits are aspiration ceilings, not warnings.", source: "Consumer Confidence Digest", category: .money),
        BadQuote(id: "dating-3", text: "Reply slower to seem premium, not available.", source: "Text Thread Lab", category: .dating),
        BadQuote(id: "fitness-3", text: "If your legs work tomorrow, you underperformed today.", source: "Gym Floor Almanac", category: .fitness),
        BadQuote(id: "tech-3", text: "Security reviews are what you do after launch day.", source: "Deployment Legend", category: .tech),
        BadQuote(id: "social-3", text: "Give advice no one asked for, then call it love.", source: "Dinner Table Doctrine", category: .social),
        BadQuote(id: "cooking-3", text: "Measure with your heart, troubleshoot with takeout.", source: "Pantry Field Notes", category: .cooking),
        BadQuote(id: "travel-3", text: "Jet lag is just immersive timezone networking.", source: "Carry-On Manifesto", category: .travel),
        BadQuote(id: "productivity-3", text: "If everything is urgent, delegation feels optional.", source: "Inbox Command Center", category: .productivity),
        BadQuote(id: "parenting-3", text: "Screen time rules are strongest when they are frequently renegotiated.", source: "Playroom Policy Desk", category: .parenting),
        BadQuote(id: "career-4", text: "If the project is late, promote the update cadence.", source: "Deadline Rebranding Team", category: .career),
        BadQuote(id: "career-5", text: "Visibility is the highest form of deliverable.", source: "Office Optics Bureau", category: .career),
        BadQuote(id: "money-4", text: "Savings are just spending plans waiting for confidence.", source: "Receipt Futurist", category: .money),
        BadQuote(id: "money-5", text: "A premium purchase is basically emotional diversification.", source: "Lifestyle Ledger", category: .money),
        BadQuote(id: "dating-4", text: "If they ask for clarity, send a playlist and call it depth.", source: "Romance Advisory Hotline", category: .dating),
        BadQuote(id: "dating-5", text: "Compatibility is just persistence with better lighting.", source: "Situationship Forecast Desk", category: .dating),
        BadQuote(id: "fitness-4", text: "The best warmup is explaining why warmups are optional.", source: "Gym Myth Council", category: .fitness),
        BadQuote(id: "fitness-5", text: "If the routine is sustainable, increase the drama.", source: "Preworkout Ethics Board", category: .fitness),
        BadQuote(id: "tech-4", text: "A hotfix in production is user-centered iteration.", source: "Release Night Dispatch", category: .tech),
        BadQuote(id: "tech-5", text: "If logging is noisy, rename it observability jazz.", source: "Incident Poetry Slack", category: .tech),
        BadQuote(id: "social-4", text: "Reply immediately, reflect eventually.", source: "Group Chat Governance", category: .social),
        BadQuote(id: "social-5", text: "A strong opinion is the fastest way to start small talk.", source: "Networking Field Manual", category: .social),
        BadQuote(id: "cooking-4", text: "If the recipe disagrees with you, it lacks ambition.", source: "Countertop Manifesto", category: .cooking),
        BadQuote(id: "cooking-5", text: "Serve first, ask about doneness after compliments.", source: "Dinner Throughput Council", category: .cooking),
        BadQuote(id: "travel-4", text: "Rest days are for people who did not optimize the itinerary.", source: "Carry-On Doctrine", category: .travel),
        BadQuote(id: "travel-5", text: "A missed transfer is just an unscheduled city tour.", source: "Gate Change Philosopher", category: .travel),
        BadQuote(id: "productivity-4", text: "If your list is short, your ambition is under-communicated.", source: "Task Inflation Office", category: .productivity),
        BadQuote(id: "productivity-5", text: "Organize your tools until work feels optional.", source: "Workflow Preservation Club", category: .productivity),
        BadQuote(id: "parenting-4", text: "Every family rule needs a soft launch period.", source: "Home Policy Workshop", category: .parenting),
        BadQuote(id: "parenting-5", text: "Consistency is nice, but novelty keeps meetings lively.", source: "Living Room Strategy Team", category: .parenting)
    ]
}

@MainActor
@Observable
final class GenerateViewModel {
    struct TopicLeaderboardItem: Identifiable {
        let id: String
        let category: AdviceCategory
        let topic: String
        let submissions: Int
    }

    struct AdviceLeaderboardItem: Identifiable {
        let id: String
        let category: AdviceCategory
        let tone: ToneMode
        let adviceLine: String
        let votes: Int
    }

    private let repository: AdviceRepository
    private let settingsViewModel: SettingsViewModel
    private let store: AdviceStore
    private let engine: AdviceEngine
    private let badQuoteService: BadQuoteService
    private let moderation: ContentModeration
    private let analyticsTracker: AnalyticsTracking

    var selectedCategory: AdviceCategory = .dating
    var selectedTone: ToneMode = .corporateConsultant
    var scenarioText: String = ""
    var friendName: String = ""
    var current: AdviceRecord?
    var lastWhyTerrible: String = "Why this is awful: confidence is replacing good judgment."
    var generationNotice: String?
    var primaryActionTitle: String = "Advise Me"

    private var recentAdviceFingerprints: [String] = []
    private var recentAdviceFingerprintsByPool: [String: [String]] = [:]
    private var suggestionsVersion: Int = 0
    private var leaderboardVersion: Int = 0
    private var successfulGenerationCount: Int = 0

    init(
        repository: AdviceRepository,
        settingsViewModel: SettingsViewModel,
        store: AdviceStore = AdviceStore(),
        badQuoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.repository = repository
        self.settingsViewModel = settingsViewModel
        self.store = store
        self.badQuoteService = badQuoteService
        self.moderation = moderation
        self.engine = AdviceEngine(store: store, moderation: moderation)
        self.analyticsTracker = analyticsTracker
        repository.seedAdviceMemoryFromHistoryIfNeeded()
        self.current = repository.fetchHistory(limit: 1).first
        self.primaryActionTitle = Self.primaryActionTitles.first ?? "Advise Me"
    }

    func generate(seed: Int? = nil) {
        generationNotice = nil
        let baseSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        var picked: GeneratedAdvice?
        var source: String = "engine"
        let situation = preparedSituationText()
        let shouldEnforceGlobalUniqueness = settingsViewModel.strictNoRepeats
        let communityOnlyMode = settingsViewModel.communityOnlyMode
        let selectedPack = settingsViewModel.preferredContentPack
        let suggestionPool = suggestionCandidates(for: selectedCategory, situation: situation)
        var triedFingerprints = Set<String>()

        if communityOnlyMode, suggestionPool.isEmpty {
            generationNotice = "Community-only mode is on. Add suggestions in Settings > Suggestion Lab."
            analyticsTracker.track("generate_blocked", properties: [
                "reason": "no_community_suggestions",
                "category": selectedCategory.rawValue
            ])
            return
        }

        for attempt in 0..<(shouldEnforceGlobalUniqueness ? 96 : 12) {
            let candidate: GeneratedAdvice
            if let suggested = communityCandidate(
                from: suggestionPool,
                attempt: attempt,
                baseSeed: baseSeed,
                forceCommunity: communityOnlyMode
            ) {
                candidate = suggested
                source = "community"
            } else if communityOnlyMode {
                continue
            } else {
                candidate = engine.generate(
                    category: selectedCategory,
                    tone: selectedTone,
                    includeRationale: settingsViewModel.includeRationale,
                    contentPack: selectedPack,
                    situation: situation,
                    seed: baseSeed + (attempt * 7919)
                )
                source = "engine"
            }

            picked = candidate
            let candidateFingerprint = fingerprint(for: candidate)
            let candidatePoolKey = poolKey(category: candidate.category, tone: candidate.tone)
            let alreadySeen = recentAdviceFingerprints.contains(candidateFingerprint)
                || (recentAdviceFingerprintsByPool[candidatePoolKey] ?? []).contains(candidateFingerprint)
                || triedFingerprints.contains(candidateFingerprint)
                || (shouldEnforceGlobalUniqueness && repository.hasSeenAdvice(candidateFingerprint))
                || (shouldEnforceGlobalUniqueness && repository.hasSeenAdviceInPool(
                    candidateFingerprint,
                    category: candidate.category,
                    tone: candidate.tone
                ))
            triedFingerprints.insert(candidateFingerprint)
            if !alreadySeen {
                break
            }
        }

        guard var output = picked else {
            generationNotice = "Community suggestions were filtered by safety checks."
            analyticsTracker.track("generate_blocked", properties: [
                "reason": "community_candidates_filtered",
                "category": selectedCategory.rawValue
            ])
            return
        }
        if shouldEnforceGlobalUniqueness, repository.hasSeenAdvice(fingerprint(for: output)) {
            output = forceUniqueVariant(from: output)
        }

        rememberFingerprint(for: output)
        rememberPoolFingerprint(for: output)
        lastWhyTerrible = "Why this is awful: \(store.rules(for: output.category, contentPack: selectedPack).badPrinciples.randomElement() ?? "certainty without evidence")."
        current = repository.insert(output)
        leaderboardVersion += 1
        analyticsTracker.track("generate", properties: [
            "category": output.category.rawValue,
            "tone": output.tone.rawValue,
            "content_pack": selectedPack.rawValue,
            "source": source,
            "has_situation": situation == nil ? "false" : "true",
            "strict_no_repeats": shouldEnforceGlobalUniqueness ? "true" : "false",
            "community_only": communityOnlyMode ? "true" : "false"
        ])
        rotatePrimaryActionTitleIfNeeded()
        playHaptic()
    }

    func surpriseMeAndGenerate() {
        selectedCategory = AdviceCategory.allCases.randomElement() ?? .dating
        selectedTone = ToneMode.allCases.randomElement() ?? .corporateConsultant
        analyticsTracker.track("surprise_me", properties: [
            "category": selectedCategory.rawValue,
            "tone": selectedTone.rawValue,
            "content_pack": settingsViewModel.preferredContentPack.rawValue
        ])
        generate()
    }

    func generateDailyDrop() {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let categories = AdviceCategory.allCases
        let tones = ToneMode.allCases
        selectedCategory = categories[day % categories.count]
        selectedTone = tones[(day * 3) % tones.count]
        analyticsTracker.track("daily_drop", properties: [
            "day_of_year": "\(day)",
            "category": selectedCategory.rawValue,
            "tone": selectedTone.rawValue,
            "content_pack": settingsViewModel.preferredContentPack.rawValue
        ])
        generate(seed: day * 1013)
    }

    func applySuggestion(_ suggestion: String) {
        scenarioText = suggestion
    }

    func toggleFavorite() {
        guard let current else { return }
        let newValue = !current.isFavorite
        repository.toggleFavorite(current)
        analyticsTracker.track("toggle_favorite", properties: [
            "is_favorite": newValue ? "true" : "false"
        ])
        playHaptic(style: .light)
    }

    func toggleVote(_ vote: AdviceVoteState) {
        guard let current else { return }
        let next: AdviceVoteState = current.vote == vote ? .none : vote
        repository.setVote(current, vote: next)
        leaderboardVersion += 1
        analyticsTracker.track("advice_vote", properties: [
            "vote": "\(next.rawValue)"
        ])
        playHaptic(style: .light)
    }

    func submitSuggestion(
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) -> String? {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdvice = adviceLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTopic.count >= 3 else {
            return "Add a clearer topic (at least 3 characters)."
        }
        guard trimmedAdvice.count >= 12 else {
            return "Advice text is too short."
        }
        guard trimmedAdvice.count <= 220 else {
            return "Advice text is too long."
        }

        let combined = "\(trimmedTopic) \(trimmedAdvice)"
        guard moderation.isSafe(text: combined) else {
            return "Suggestion blocked by safety checks."
        }

        let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
        let normalizedCombined = combined.normalizedForFiltering
        guard !forbidden.contains(where: { normalizedCombined.contains($0.normalizedForFiltering) }) else {
            return "Suggestion conflicts with safety constraints for this category."
        }

        _ = repository.addSuggestion(
            category: category,
            topic: String(trimmedTopic.prefix(72)),
            adviceLine: String(trimmedAdvice.prefix(220))
        )
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track("suggestion_submit", properties: [
            "category": category.rawValue
        ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        repository.deleteSuggestion(suggestion)
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track("suggestion_delete", properties: [:])
    }

    func markFavorite() {
        guard let current else { return }
        repository.setFavorite(current, isFavorite: true)
        analyticsTracker.track("save_from_generate", properties: [:])
        playHaptic(style: .light)
    }

    var isCurrentFavorite: Bool {
        current?.isFavorite ?? false
    }

    var currentVote: AdviceVoteState {
        current?.vote ?? .none
    }

    var recentSuggestions: [UserAdviceSuggestion] {
        _ = suggestionsVersion
        return repository.fetchSuggestions(limit: 20)
    }

    var communitySuggestionCount: Int {
        _ = suggestionsVersion
        return repository.suggestionCount()
    }

    var topCommunityTopics: [TopicLeaderboardItem] {
        _ = leaderboardVersion
        let suggestions = repository.fetchSuggestions(limit: 250)
        var grouped: [String: (category: AdviceCategory, topic: String, count: Int)] = [:]
        for suggestion in suggestions {
            let normalizedTopic = suggestion.topic.normalizedForFiltering
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTopic.isEmpty else { continue }
            let key = "\(suggestion.category.rawValue)|\(normalizedTopic)"
            if var existing = grouped[key] {
                existing.count += 1
                grouped[key] = existing
            } else {
                grouped[key] = (suggestion.category, suggestion.topic, 1)
            }
        }
        return grouped
            .map { key, value in
                TopicLeaderboardItem(
                    id: key,
                    category: value.category,
                    topic: value.topic,
                    submissions: value.count
                )
            }
            .sorted {
                if $0.submissions == $1.submissions {
                    return $0.topic.localizedCaseInsensitiveCompare($1.topic) == .orderedAscending
                }
                return $0.submissions > $1.submissions
            }
            .prefix(8)
            .map { $0 }
    }

    var topLikedAdvice: [AdviceLeaderboardItem] {
        voteLeaderboard(for: .like)
    }

    var topDislikedAdvice: [AdviceLeaderboardItem] {
        voteLeaderboard(for: .dislike)
    }

    var currentShareText: String {
        guard let current else { return "" }
        let caption = shareCaption(for: current)
        if let rationale = current.rationaleLine, !rationale.isEmpty {
            return "\(caption)\n\n\(current.adviceLine)\n\n\(rationale)\n\nWorst Advice"
        }
        return "\(caption)\n\n\(current.adviceLine)\n\nWorst Advice"
    }

    var currentSharePayload: ShareCardContent? {
        guard let current else { return nil }
        return ShareCardContent(
            category: current.category,
            tone: current.tone,
            adviceLine: current.adviceLine,
            rationaleLine: current.rationaleLine,
            includeDisclaimer: settingsViewModel.includeDisclaimerOnShare,
            template: settingsViewModel.preferredTemplate,
            aspectRatio: settingsViewModel.preferredAspect
        )
    }

    var keywordSuggestions: [String] {
        Array(store.rules(for: selectedCategory, contentPack: settingsViewModel.preferredContentPack).keywords.prefix(4))
    }

    var dailyBadQuote: BadQuote {
        badQuoteService.quoteOfDay()
    }

    var todayGeneratedCount: Int {
        let calendar = Calendar.current
        return repository.fetchHistory(limit: 50).filter { calendar.isDateInToday($0.createdAt) }.count
    }

    var totalGeneratedCount: Int {
        repository.fetchAllHistory().count
    }

    var favoriteCount: Int {
        repository.fetchFavorites().count
    }

    var challengeStreakDays: Int {
        streakDays(history: repository.fetchAllHistory())
    }

    var challengeGoalDays: Int {
        switch challengeStreakDays {
        case 0..<3: return 3
        case 3..<7: return 7
        case 7..<14: return 14
        default: return 30
        }
    }

    var challengeProgressText: String {
        "\(min(challengeStreakDays, challengeGoalDays))/\(challengeGoalDays) day streak"
    }

    var challengeTitle: String {
        if challengeStreakDays >= challengeGoalDays {
            return "Challenge complete. Escalate."
        }
        return "Current challenge: \(challengeGoalDays)-day streak"
    }

    var uniquenessStatusText: String {
        let mode = settingsViewModel.strictNoRepeats ? "On" : "Off"
        let pack = settingsViewModel.preferredContentPack.title
        return "No-repeat mode: \(mode) • Global + category/tone pools • Pack: \(pack) • \(repository.seenAdviceCount()) unique lines served"
    }

    func trackShare(template: ShareCardTemplate, ratio: ShareAspectRatio) {
        analyticsTracker.track("share_card", properties: [
            "template": template.rawValue,
            "ratio": ratio.rawValue,
            "caption_preset": settingsViewModel.preferredSharePreset.rawValue
        ])
    }

    func trackCopy() {
        analyticsTracker.track("copy_text", properties: [:])
    }

    private func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        HapticsManager.play(style: style, isEnabled: settingsViewModel.hapticsEnabled)
    }

    private func shareCaption(for record: AdviceRecord) -> String {
        switch settingsViewModel.preferredSharePreset {
        case .deadpan:
            return "Daily wisdom drop: objectively terrible, emotionally convincing."
        case .chaotic:
            return "This app should be illegal but the vibe is immaculate."
        case .fauxExpert:
            return "Consulting note: this strategy has 0% evidence and 100% confidence."
        }
    }

    private func preparedSituationText() -> String? {
        let trimmedFriend = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedTone == .friendRoast, !trimmedFriend.isEmpty {
            let base = scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
            if base.isEmpty {
                return "friend \(trimmedFriend)"
            }
            return "\(base) for friend \(trimmedFriend)"
        }
        return scenarioText
    }

    private func streakDays(history: [AdviceRecord]) -> Int {
        guard !history.isEmpty else { return 0 }
        let calendar = Calendar.current
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = days.sorted(by: >)
        guard let mostRecent = sortedDays.first else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard mostRecent == today || mostRecent == yesterday else { return 0 }

        var streak = 1
        var currentDay = mostRecent
        while true {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            if days.contains(previousDay) {
                streak += 1
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }

    private func fingerprint(for generated: GeneratedAdvice) -> String {
        generated.adviceLine.normalizedForFiltering
    }

    private func rememberFingerprint(for generated: GeneratedAdvice) {
        recentAdviceFingerprints.append(fingerprint(for: generated))
        let overflow = recentAdviceFingerprints.count - 24
        if overflow > 0 {
            recentAdviceFingerprints.removeFirst(overflow)
        }
    }

    private func rememberPoolFingerprint(for generated: GeneratedAdvice) {
        let key = poolKey(category: generated.category, tone: generated.tone)
        var fingerprints = recentAdviceFingerprintsByPool[key] ?? []
        fingerprints.append(fingerprint(for: generated))
        let overflow = fingerprints.count - 24
        if overflow > 0 {
            fingerprints.removeFirst(overflow)
        }
        recentAdviceFingerprintsByPool[key] = fingerprints
    }

    private func forceUniqueVariant(from base: GeneratedAdvice) -> GeneratedAdvice {
        var serial = max(repository.seenAdviceCount() + 1, 1)
        while true {
            let suffix = uniqueSuffix(for: serial)
            let updated = GeneratedAdvice(
                id: base.id,
                category: base.category,
                tone: base.tone,
                adviceLine: "\(base.adviceLine) \(suffix)",
                rationaleLine: base.rationaleLine,
                createdAt: base.createdAt
            )
            let updatedFingerprint = fingerprint(for: updated)
            let key = poolKey(category: updated.category, tone: updated.tone)
            if !recentAdviceFingerprints.contains(updatedFingerprint)
                && !(recentAdviceFingerprintsByPool[key] ?? []).contains(updatedFingerprint)
                && !repository.hasSeenAdvice(updatedFingerprint)
                && !repository.hasSeenAdviceInPool(
                    updatedFingerprint,
                    category: updated.category,
                    tone: updated.tone
                ) {
                return updated
            }
            serial += 1
        }
    }

    private func voteLeaderboard(for state: AdviceVoteState) -> [AdviceLeaderboardItem] {
        _ = leaderboardVersion
        let records = repository.fetchHistory(limit: 50).filter { $0.vote == state }
        var grouped: [String: (category: AdviceCategory, tone: ToneMode, adviceLine: String, count: Int)] = [:]
        for record in records {
            let normalizedAdvice = record.adviceLine.normalizedForFiltering
            if var existing = grouped[normalizedAdvice] {
                existing.count += 1
                grouped[normalizedAdvice] = existing
            } else {
                grouped[normalizedAdvice] = (record.category, record.tone, record.adviceLine, 1)
            }
        }
        return grouped
            .map { key, value in
                AdviceLeaderboardItem(
                    id: key,
                    category: value.category,
                    tone: value.tone,
                    adviceLine: value.adviceLine,
                    votes: value.count
                )
            }
            .sorted {
                if $0.votes == $1.votes {
                    return $0.adviceLine.localizedCaseInsensitiveCompare($1.adviceLine) == .orderedAscending
                }
                return $0.votes > $1.votes
            }
            .prefix(8)
            .map { $0 }
    }

    private func poolKey(category: AdviceCategory, tone: ToneMode) -> String {
        "\(category.rawValue)|\(tone.rawValue)"
    }

    private func rotatePrimaryActionTitleIfNeeded() {
        successfulGenerationCount += 1
        guard successfulGenerationCount % 3 == 0 else { return }
        let choices = Self.primaryActionTitles.filter { $0 != primaryActionTitle }
        primaryActionTitle = choices.randomElement() ?? Self.primaryActionTitles.first ?? "Advise Me"
    }

    private func uniqueSuffix(for serial: Int) -> String {
        let adjectives = ["chaos", "executive", "moonshot", "unhinged", "legacy", "side-quest", "founder", "main-character"]
        let nouns = ["protocol", "playbook", "framework", "operating system", "ritual", "policy", "method", "blueprint"]
        let adjective = adjectives[serial % adjectives.count]
        let nounIndex = (serial / adjectives.count) % nouns.count
        let noun = nouns[nounIndex]
        let token = String(serial, radix: 36).uppercased()
        return "Call this the \(adjective) \(noun) \(token)."
    }

    private func suggestionCandidates(for category: AdviceCategory, situation: String?) -> [UserAdviceSuggestion] {
        let all = repository.fetchSuggestions(limit: 120).filter { $0.category == category }
        let normalizedSituation = situation?.normalizedForFiltering ?? ""
        let matched = all.filter { suggestion in
            let topic = suggestion.topic.normalizedForFiltering
            return !normalizedSituation.isEmpty && (normalizedSituation.contains(topic) || topic.contains(normalizedSituation))
        }
        return matched.isEmpty ? all : matched
    }

    private func communityCandidate(
        from pool: [UserAdviceSuggestion],
        attempt: Int,
        baseSeed: Int,
        forceCommunity: Bool
    ) -> GeneratedAdvice? {
        guard !pool.isEmpty else { return nil }
        // Bias toward custom suggestions on early attempts without replacing core generation.
        if !forceCommunity, attempt % 4 != 0 {
            return nil
        }
        let index = abs(baseSeed + (attempt * 37)) % pool.count
        let suggestion = pool[index]
        guard moderation.isSafe(text: "\(suggestion.topic) \(suggestion.adviceLine)") else { return nil }

        let rationale: String?
        if settingsViewModel.includeRationale {
            rationale = "Community bad idea: for \(suggestion.topic), confidence was preferred over caution."
        } else {
            rationale = nil
        }

        return GeneratedAdvice(
            category: suggestion.category,
            tone: selectedTone,
            adviceLine: suggestion.adviceLine,
            rationaleLine: rationale
        )
    }

    private static let primaryActionTitles = [
        "Advise Me",
        "Need Bad Advice",
        "Make It Worse",
        "Hit Me With Chaos",
        "Give Me A Terrible Plan"
    ]
}

@MainActor
@Observable
final class QuotesViewModel {
    private let repository: AdviceRepository
    private let quoteService: BadQuoteService
    private let moderation: ContentModeration
    private let store: AdviceStore
    private let analyticsTracker: AnalyticsTracking

    var searchText: String = ""
    var selectedCategory: AdviceCategory?
    var rankingMode: QuoteRankingMode = .recent
    private var quoteSuggestions: [UserQuoteSuggestion] = []
    private var votesByQuoteID: [String: AdviceVoteState] = [:]

    init(
        repository: AdviceRepository,
        quoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        store: AdviceStore = AdviceStore(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.repository = repository
        self.quoteService = quoteService
        self.moderation = moderation
        self.store = store
        self.analyticsTracker = analyticsTracker
        reloadCachedData()
    }

    var dailyQuote: BadQuote {
        quoteService.quoteOfDay()
    }

    var allQuotes: [BadQuote] {
        let base = quoteService.quotes
        let fromCommunity = quoteSuggestions.map { suggestion in
            BadQuote(
                id: "community-\(suggestion.id.uuidString)",
                text: suggestion.quoteText,
                source: suggestion.source,
                category: suggestion.category
            )
        }
        var seen = Set<String>()
        var merged: [BadQuote] = []
        for quote in base + fromCommunity {
            let normalized = quote.text.normalizedForFiltering
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }

    var filteredQuotes: [BadQuote] {
        let filtered = allQuotes.filter { quote in
            let categoryMatch = selectedCategory == nil || quote.category == selectedCategory
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if search.isEmpty {
                return categoryMatch
            }
            let haystack = "\(quote.text) \(quote.source) \(quote.category.title)".normalizedForFiltering
            return categoryMatch && haystack.contains(search.normalizedForFiltering)
        }
        let votes = quoteVoteMap
        switch rankingMode {
        case .recent:
            return filtered
        case .topLiked:
            return filtered.filter { votes[$0.id] == .like }
        case .topDisliked:
            return filtered.filter { votes[$0.id] == .dislike }
        }
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
        reloadCachedData()
        analyticsTracker.track("quote_vote", properties: [
            "id": quote.id,
            "category": quote.category.rawValue,
            "vote": "\(nextVote.rawValue)"
        ])
    }

    func submitSuggestion(
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) -> String? {
        let trimmedText = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeSource = trimmedSource.isEmpty ? "Community Submission" : String(trimmedSource.prefix(44))

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
        analyticsTracker.track("quote_suggestion_submit", properties: [
            "category": category.rawValue
        ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserQuoteSuggestion) {
        repository.deleteQuoteSuggestion(suggestion)
        reloadCachedData()
        analyticsTracker.track("quote_suggestion_delete", properties: [
            "category": suggestion.category.rawValue
        ])
    }

    func trackCopy(_ quote: BadQuote, isDaily: Bool) {
        analyticsTracker.track("quote_copy", properties: [
            "id": quote.id,
            "category": quote.category.rawValue,
            "daily": isDaily ? "true" : "false"
        ])
    }

    func trackShare(_ quote: BadQuote, isDaily: Bool) {
        analyticsTracker.track("quote_share", properties: [
            "id": quote.id,
            "category": quote.category.rawValue,
            "daily": isDaily ? "true" : "false"
        ])
    }

    func quoteShareText(_ quote: BadQuote) -> String {
        "\"\(quote.text)\"\n— \(quote.source)\n\nWorst Advice"
    }

    private func reloadCachedData() {
        quoteSuggestions = repository.fetchQuoteSuggestions(limit: 30)
        votesByQuoteID = repository.quoteVoteMap()
    }
}

@MainActor
@Observable
final class FavoritesViewModel {
    private let repository: AdviceRepository
    private let analyticsTracker: AnalyticsTracking
    var favorites: [AdviceRecord] = []
    var searchText: String = ""
    var selectedCategory: AdviceCategory?

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()) {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        reload()
    }

    func reload() {
        favorites = repository.fetchFavorites()
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

    var filteredFavorites: [AdviceRecord] {
        favorites.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let haystack = "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)".normalizedForFiltering
                matchesSearch = haystack.contains(searchText.normalizedForFiltering)
            }
            return matchesCategory && matchesSearch
        }
    }
}

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
    var searchText: String = ""
    var selectedCategory: AdviceCategory?
    var rankingMode: RankingMode = .recent

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()) {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        reload()
    }

    func reload() {
        history = repository.fetchHistory(limit: 50)
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
        let filtered = history.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let haystack = "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)".normalizedForFiltering
                matchesSearch = haystack.contains(searchText.normalizedForFiltering)
            }
            return matchesCategory && matchesSearch
        }

        switch rankingMode {
        case .recent:
            return filtered
        case .topLiked:
            return filtered.filter { $0.vote == .like }
        case .topDisliked:
            return filtered.filter { $0.vote == .dislike }
        }
    }

    var likedCount: Int {
        history.filter { $0.vote == .like }.count
    }

    var dislikedCount: Int {
        history.filter { $0.vote == .dislike }.count
    }
}

@MainActor
@Observable
final class AppSessionViewModel {
    let repository: AdviceRepository
    let settings: SettingsViewModel
    let generate: GenerateViewModel
    let favorites: FavoritesViewModel
    let history: HistoryViewModel
    let quotes: QuotesViewModel
    private let analyticsTracker: AnalyticsTracking

    init(context: ModelContext) {
        self.analyticsTracker = AppAnalyticsTracker()
        self.repository = AdviceRepository(context: context)
        self.settings = SettingsViewModel(repository: repository)
        self.generate = GenerateViewModel(repository: repository, settingsViewModel: settings, analyticsTracker: analyticsTracker)
        self.favorites = FavoritesViewModel(repository: repository, analyticsTracker: analyticsTracker)
        self.history = HistoryViewModel(repository: repository, analyticsTracker: analyticsTracker)
        self.quotes = QuotesViewModel(repository: repository, analyticsTracker: analyticsTracker)
    }

    func refreshLists() {
        favorites.reload()
        history.reload()
    }
}
