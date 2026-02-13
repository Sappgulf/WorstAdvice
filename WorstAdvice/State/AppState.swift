import Foundation
import Observation
import SwiftData
import UIKit

@Model
final class AdviceRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var categoryRaw: String
    var toneRaw: String
    var adviceLine: String
    var rationaleLine: String?
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date,
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.isFavorite = isFavorite
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }

    var tone: ToneMode {
        ToneMode(rawValue: toneRaw) ?? .corporateConsultant
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

    init(
        id: UUID = UUID(),
        theme: ThemeMode = .warm,
        includeDisclaimerOnShare: Bool = true,
        reduceMotion: Bool = false,
        hapticsEnabled: Bool = true,
        includeRationale: Bool = true,
        preferredTemplate: ShareCardTemplate = .ember,
        preferredAspect: ShareAspectRatio = .square
    ) {
        self.id = id
        self.themeRaw = theme.rawValue
        self.includeDisclaimerOnShare = includeDisclaimerOnShare
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
        self.includeRationale = includeRationale
        self.preferredTemplateRaw = preferredTemplate.rawValue
        self.preferredAspectRaw = preferredAspect.rawValue
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
}

@MainActor
final class AdviceRepository {
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
}

@MainActor
@Observable
final class GenerateViewModel {
    private let repository: AdviceRepository
    private let settingsViewModel: SettingsViewModel
    private let store: AdviceStore
    private let engine: AdviceEngine

    var selectedCategory: AdviceCategory = .dating
    var selectedTone: ToneMode = .corporateConsultant
    var scenarioText: String = ""
    var current: AdviceRecord?
    var lastWhyTerrible: String = "Why this is awful: confidence is replacing good judgment."

    private var recentAdviceFingerprints: [String] = []

    init(
        repository: AdviceRepository,
        settingsViewModel: SettingsViewModel,
        store: AdviceStore = AdviceStore(),
        moderation: ContentModeration = ContentModeration()
    ) {
        self.repository = repository
        self.settingsViewModel = settingsViewModel
        self.store = store
        self.engine = AdviceEngine(store: store, moderation: moderation)
        self.current = repository.fetchHistory(limit: 1).first
    }

    func generate(seed: Int? = nil) {
        let baseSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        var picked: GeneratedAdvice?

        for attempt in 0..<8 {
            let candidate = engine.generate(
                category: selectedCategory,
                tone: selectedTone,
                includeRationale: settingsViewModel.includeRationale,
                situation: scenarioText,
                seed: baseSeed + (attempt * 7919)
            )

            picked = candidate
            if !recentAdviceFingerprints.contains(fingerprint(for: candidate)) {
                break
            }
        }

        guard let output = picked else { return }
        rememberFingerprint(for: output)
        lastWhyTerrible = "Why this is awful: \(store.rules(for: output.category).badPrinciples.randomElement() ?? "certainty without evidence")."
        current = repository.insert(output)
        playHaptic()
    }

    func reroll() {
        generate()
    }

    func surpriseMeAndGenerate() {
        selectedCategory = AdviceCategory.allCases.randomElement() ?? .dating
        selectedTone = ToneMode.allCases.randomElement() ?? .corporateConsultant
        generate()
    }

    func generateDailyDrop() {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let categories = AdviceCategory.allCases
        let tones = ToneMode.allCases
        selectedCategory = categories[day % categories.count]
        selectedTone = tones[(day * 3) % tones.count]
        generate(seed: day * 1013)
    }

    func applySuggestion(_ suggestion: String) {
        scenarioText = suggestion
    }

    func toggleFavorite() {
        guard let current else { return }
        repository.toggleFavorite(current)
        playHaptic(style: .light)
    }

    func markFavorite() {
        guard let current else { return }
        repository.setFavorite(current, isFavorite: true)
        playHaptic(style: .light)
    }

    var isCurrentFavorite: Bool {
        current?.isFavorite ?? false
    }

    var currentShareText: String {
        guard let current else { return "" }
        if let rationale = current.rationaleLine, !rationale.isEmpty {
            return "\(current.adviceLine)\n\n\(rationale)\n\nThe Worst Advice"
        }
        return "\(current.adviceLine)\n\nThe Worst Advice"
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
        Array(store.rules(for: selectedCategory).keywords.prefix(4))
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

    private func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        HapticsManager.play(style: style, isEnabled: settingsViewModel.hapticsEnabled)
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
}

@MainActor
@Observable
final class FavoritesViewModel {
    private let repository: AdviceRepository
    var favorites: [AdviceRecord] = []
    var searchText: String = ""
    var selectedCategory: AdviceCategory?

    init(repository: AdviceRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        favorites = repository.fetchFavorites()
    }

    func remove(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: false)
        reload()
    }

    func delete(_ record: AdviceRecord) {
        repository.delete(record)
        reload()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        repository.toggleFavorite(record)
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
    private let repository: AdviceRepository
    var history: [AdviceRecord] = []
    var searchText: String = ""
    var selectedCategory: AdviceCategory?

    init(repository: AdviceRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        history = repository.fetchHistory(limit: 50)
    }

    func saveFromHistory(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: true)
        reload()
    }

    func clearHistory() {
        repository.purgeAllHistory()
        reload()
    }

    var filteredHistory: [AdviceRecord] {
        history.filter { record in
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
final class AppSessionViewModel {
    let repository: AdviceRepository
    let settings: SettingsViewModel
    let generate: GenerateViewModel
    let favorites: FavoritesViewModel
    let history: HistoryViewModel

    init(context: ModelContext) {
        self.repository = AdviceRepository(context: context)
        self.settings = SettingsViewModel(repository: repository)
        self.generate = GenerateViewModel(repository: repository, settingsViewModel: settings)
        self.favorites = FavoritesViewModel(repository: repository)
        self.history = HistoryViewModel(repository: repository)
    }

    func refreshLists() {
        favorites.reload()
        history.reload()
    }
}
