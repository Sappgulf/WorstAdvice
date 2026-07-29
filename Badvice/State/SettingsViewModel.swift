import Combine
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SettingsViewModel {
    private let repository: AdviceRepository
    @ObservationIgnored let localModelStore: LocalModelStore
    @ObservationIgnored private var localModelStoreCancellable: AnyCancellable?
    private(set) var settings: AppSettingsEntity
    private(set) var appleOnDeviceModelAvailability: AppleOnDeviceModelAvailability =
        AppleOnDeviceAdviceBridge.currentAvailability()
    private(set) var isPreparingAppleOnDeviceModel: Bool = false
    private(set) var appleOnDeviceModelStatusLastUpdatedAt: Date = Date()

    init(repository: AdviceRepository, localModelStore: LocalModelStore) {
        self.repository = repository
        self.localModelStore = localModelStore
        self.settings = repository.ensureSettings()
        self.localModelStoreCancellable = localModelStore.objectWillChange.sink { [weak self] _ in
            Task { [weak self] in
                await MainActor.run {
                    self?.appleOnDeviceModelStatusLastUpdatedAt = Date()
                }
            }
        }
        if settings.preferredGenerationProvider == .auto {
            settings.preferredGenerationProvider = .classic
            repository.save()
        }
        normalizeStreakFreezeState(for: Date())
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: streakFreezeAvailableThisWeek)
    }

    convenience init(repository: AdviceRepository) {
        self.init(repository: repository, localModelStore: LocalModelStore())
    }

    var theme: ThemeMode {
        get { settings.theme }
        set {
            guard settings.theme != newValue else { return }
            settings.theme = newValue
            repository.save()
        }
    }

    var includeDisclaimerOnShare: Bool {
        get { settings.includeDisclaimerOnShare }
        set {
            guard settings.includeDisclaimerOnShare != newValue else { return }
            settings.includeDisclaimerOnShare = newValue
            repository.save()
        }
    }

    var reduceMotion: Bool {
        get { settings.reduceMotion }
        set {
            guard settings.reduceMotion != newValue else { return }
            settings.reduceMotion = newValue
            repository.save()
        }
    }

    var hapticsEnabled: Bool {
        get { settings.hapticsEnabled }
        set {
            guard settings.hapticsEnabled != newValue else { return }
            settings.hapticsEnabled = newValue
            repository.save()
        }
    }

    var soundEffectsEnabled: Bool {
        get { settings.soundEffectsEnabled }
        set {
            guard settings.soundEffectsEnabled != newValue else { return }
            settings.soundEffectsEnabled = newValue
            repository.save()
        }
    }

    var performanceMode: Bool {
        get { settings.performanceMode }
        set {
            guard settings.performanceMode != newValue else { return }
            settings.performanceMode = newValue
            repository.save()
        }
    }

    var dailyNotificationsEnabled: Bool {
        get { settings.dailyNotificationsEnabled }
        set {
            guard settings.dailyNotificationsEnabled != newValue else { return }
            settings.dailyNotificationsEnabled = newValue
            repository.save()
            if newValue {
                NotificationManager.requestPermissionAndScheduleDaily(hour: settings.dailyNotificationHour)
            } else {
                NotificationManager.cancelDailyNotification()
            }
        }
    }

    var streakNotificationsEnabled: Bool {
        get { settings.streakNotificationsEnabled }
        set {
            guard settings.streakNotificationsEnabled != newValue else { return }
            settings.streakNotificationsEnabled = newValue
            repository.save()
            NotificationManager.scheduleDaily(hour: settings.dailyNotificationHour, streakEnabled: newValue)
        }
    }

    var dailyNotificationHour: Int {
        get { settings.dailyNotificationHour }
        set {
            guard settings.dailyNotificationHour != newValue else { return }
            settings.dailyNotificationHour = newValue
            repository.save()
            if settings.dailyNotificationsEnabled {
                NotificationManager.scheduleDaily(hour: newValue, streakEnabled: settings.streakNotificationsEnabled)
            }
        }
    }

    var includeRationale: Bool {
        get { settings.includeRationale }
        set {
            guard settings.includeRationale != newValue else { return }
            settings.includeRationale = newValue
            repository.save()
        }
    }

    var preferredTemplate: ShareCardTemplate {
        get { settings.preferredTemplate }
        set {
            guard settings.preferredTemplate != newValue else { return }
            settings.preferredTemplate = newValue
            repository.save()
        }
    }

    var preferredAspect: ShareAspectRatio {
        get { settings.preferredAspect }
        set {
            guard settings.preferredAspect != newValue else { return }
            settings.preferredAspect = newValue
            repository.save()
        }
    }

    var preferredSharePreset: ShareCaptionPreset {
        get { settings.preferredSharePreset }
        set {
            guard settings.preferredSharePreset != newValue else { return }
            settings.preferredSharePreset = newValue
            repository.save()
        }
    }

    var preferredContentPack: ContentPack {
        get { settings.preferredContentPack }
        set {
            guard settings.preferredContentPack != newValue else { return }
            settings.preferredContentPack = newValue
            repository.save()
        }
    }

    var preferredGenerationProvider: AdviceGenerationProvider {
        get { settings.preferredGenerationProvider }
        set {
            guard settings.preferredGenerationProvider != newValue else { return }
            settings.preferredGenerationProvider = newValue
            repository.save()
            refreshAppleOnDeviceModelAvailability()
        }
    }

    var preferredIntensity: BadviceIntensity {
        get { settings.preferredIntensity }
        set {
            guard settings.preferredIntensity != newValue else { return }
            settings.preferredIntensity = newValue
            repository.save()
        }
    }

    var appleOnDeviceModelStatusText: String {
        appleOnDeviceModelStatusSummary.message
    }

    var appleOnDeviceModelStatusKey: String {
        appleOnDeviceModelStatusSummary.key
    }

    var appleOnDeviceModelStatusBadgeText: String {
        appleOnDeviceModelStatusSummary.pill
    }

    var appleOnDeviceModelSetupHintText: String {
        appleOnDeviceModelStatusSummary.hint
    }

    var appleOnDeviceModelWarningText: String? {
        appleOnDeviceModelStatusSummary.warning
    }

    var canPrepareAppleOnDeviceModel: Bool {
        guard localModelStore.selectedModelID != nil || localModelStore.availableModels.first != nil else {
            return false
        }
        return true
    }

    var recommendedAppleOnDeviceActionTitle: String {
        guard let selectedID = localModelStore.selectedModelID ?? localModelStore.availableModels.first?.id
        else {
            return "Recheck"
        }
        if let selected = localModelStore.availableModels.first(where: { $0.id == selectedID }) {
            if !selected.isInstalled { return "Install Local Model" }
        }
        switch localModelStore.state(for: selectedID) {
        case .ready:
            return "Warm Up Local Model"
        case .installing:
            return "Prepare / Download Local Model"
        default:
            return "Warm Up Local Model"
        }
    }

    var shouldShowOpenAppSettingsShortcut: Bool {
        appleOnDeviceModelStatusSummary.shouldShowSettingsShortcut
    }

    func refreshAppleOnDeviceModelAvailability() {
        appleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
        localModelStore.reloadAvailableModels()
        appleOnDeviceModelStatusLastUpdatedAt = Date()
    }

    func refreshAppleOnDeviceModelAvailabilityNow() async {
        appleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
        await localModelStore.reloadAvailableModelsNow()
        appleOnDeviceModelStatusLastUpdatedAt = Date()
    }

    func prepareAppleLocalModelForLaunchIfNeeded(
        systemMaxPollCount: Int = 2,
        systemPollDelay: Duration = .milliseconds(250)
    ) async {
        guard preferredGenerationProvider == .appleOnDevice else { return }
        guard !isPreparingAppleOnDeviceModel else { return }
        isPreparingAppleOnDeviceModel = true
        defer {
            isPreparingAppleOnDeviceModel = false
            refreshAppleOnDeviceModelAvailability()
        }

        await preparePreferredAppleOnDeviceModel(
            systemMaxPollCount: systemMaxPollCount,
            systemPollDelay: systemPollDelay
        )
    }

    func prepareAppleOnDeviceModel() async {
        guard !isPreparingAppleOnDeviceModel else { return }
        isPreparingAppleOnDeviceModel = true
        defer {
            isPreparingAppleOnDeviceModel = false
            refreshAppleOnDeviceModelAvailability()
        }

        await preparePreferredAppleOnDeviceModel(
            systemMaxPollCount: 8,
            systemPollDelay: .seconds(1)
        )
    }

    private func preparePreferredAppleOnDeviceModel(
        systemMaxPollCount: Int,
        systemPollDelay: Duration
    ) async {
        await refreshAppleOnDeviceModelAvailabilityNow()
        guard let targetID = preferredAppleOnDevicePreparationModelID() else {
            return
        }
        localModelStore.selectModel(targetID)
        if let target = localModelStore.availableModels.first(where: { $0.id == targetID }), !target.isInstalled {
            try? await localModelStore.installModel(
                id: targetID,
                systemMaxPollCount: systemMaxPollCount,
                systemPollDelay: systemPollDelay
            )
        }
        if localModelStore.state(for: targetID) != .ready {
            await localModelStore.warmUp(
                id: targetID,
                systemMaxPollCount: systemMaxPollCount,
                systemPollDelay: systemPollDelay
            )
        }
        await refreshAppleOnDeviceModelAvailabilityNow()
    }

    private func preferredAppleOnDevicePreparationModelID() -> String? {
        if let selectedID = localModelStore.selectedModelID,
           localModelStore.availableModels.first(where: { $0.id == selectedID })?.isSystemModel == true {
            return selectedID
        }
        if let systemModelID = localModelStore.availableModels.first(where: { $0.isSystemModel })?.id {
            return systemModelID
        }
        return localModelStore.selectedModelID ?? localModelStore.availableModels.first?.id
    }

    func installAppleLocalModel(id: String) async {
        do {
            try await localModelStore.installModel(id: id)
        } catch {
            appleOnDeviceModelStatusLastUpdatedAt = Date()
        }
        refreshAppleOnDeviceModelAvailability()
    }

    func removeAppleLocalModel(id: String) async {
        await localModelStore.removeModel(id: id)
        refreshAppleOnDeviceModelAvailability()
    }

    func warmUpAppleLocalModel(id: String) async {
        await localModelStore.warmUp(id: id)
        refreshAppleOnDeviceModelAvailability()
    }

    func selectAppleLocalModel(id: String?) {
        localModelStore.selectModel(id)
        appleOnDeviceModelStatusLastUpdatedAt = Date()
    }

    var appleLocalModels: [LocalModelDescriptor] {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.availableModels
    }

    var selectedAppleLocalModelID: String? {
        get {
            _ = appleOnDeviceModelStatusLastUpdatedAt
            return localModelStore.selectedModelID
        }
        set { selectAppleLocalModel(id: newValue) }
    }

    func appleLocalModelInstallState(for id: String) -> LocalModelInstallState {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.state(for: id)
    }

    var appleLocalGenerationGate: LocalModelStore.GenerationGate {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.generationGate(
            appleAvailability: AppleOnDeviceAdviceBridge.currentAvailability())
    }

    private var appleOnDeviceModelStatusSummary: (
        key: String,
        message: String,
        hint: String,
        pill: String,
        warning: String?,
        shouldShowSettingsShortcut: Bool
    ) {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.effectiveStatus(for: preferredGenerationProvider)
    }

    var strictNoRepeats: Bool {
        get { settings.strictNoRepeats }
        set {
            guard settings.strictNoRepeats != newValue else { return }
            settings.strictNoRepeats = newValue
            repository.save()
        }
    }

    var communityOnlyMode: Bool {
        get { settings.communityOnlyMode }
        set {
            guard settings.communityOnlyMode != newValue else { return }
            settings.communityOnlyMode = newValue
            repository.save()
        }
    }

    var tabOrder: [AppTab] {
        get { settings.tabOrder }
        set {
            guard settings.tabOrder != newValue else { return }
            settings.tabOrder = newValue
            repository.save()
        }
    }

    var reorderableTabs: [AppTab] {
        AppTab.primaryNavigationTabs.filter { $0 != .generate }
    }

    func moveReorderableTabs(from source: IndexSet, to destination: Int) {
        var items = reorderableTabs
        let moving = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let insertion = max(0, min(destination, items.count))
        items.insert(contentsOf: moving, at: insertion)
        applyPrimaryTabOrder(items)
    }

    func moveReorderableTabUp(at index: Int) {
        var items = reorderableTabs
        guard index > 0, index < items.count else { return }
        items.swapAt(index, index - 1)
        applyPrimaryTabOrder(items)
    }

    func moveReorderableTabDown(at index: Int) {
        var items = reorderableTabs
        guard index >= 0, index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
        applyPrimaryTabOrder(items)
    }

    func resetTabOrder() {
        tabOrder = AppTab.defaultOrder
    }

    private func applyPrimaryTabOrder(_ primaryItems: [AppTab]) {
        let pinnedTabs = Set([AppTab.generate] + primaryItems)
        let overflowItems = AppTab.allCases.filter { !pinnedTabs.contains($0) }
        tabOrder = [.generate] + primaryItems + overflowItems
    }

    var streakFreezeAvailableThisWeek: Bool {
        // Deliberately a pure read: normalization (which can write to `settings` and
        // save) happens once at session start and before mutating actions. Calling it
        // here too used to run it on every access, including from view bodies — a
        // conditional write inside a property SwiftUI reads while rendering, which
        // triggered a genuine render-invalidation loop that froze the Missions tab.
        !(settings.streakFreezeUsedRaw ?? false)
    }

    func isStreakFreezeActive(for date: Date = Date()) -> Bool {
        normalizeStreakFreezeState(for: date)
        return settings.streakFreezeProtectedDayRaw == Self.dayKey(for: date)
    }

    @discardableResult
    func consumeStreakFreezeIfAvailable(for date: Date = Date()) -> Bool {
        normalizeStreakFreezeState(for: date)
        let dayKey = Self.dayKey(for: date)

        if settings.streakFreezeProtectedDayRaw == dayKey {
            return true
        }
        guard !(settings.streakFreezeUsedRaw ?? false) else { return false }

        settings.streakFreezeUsedRaw = true
        settings.streakFreezeProtectedDayRaw = dayKey
        repository.save()
        NotificationManager.updateStreakFreezeAvailability(hasAvailable: false)
        return true
    }

    private func normalizeStreakFreezeState(for date: Date) {
        let weekKey = Self.weekKey(for: date)
        if settings.streakFreezeWeekKeyRaw != weekKey {
            settings.streakFreezeWeekKeyRaw = weekKey
            settings.streakFreezeUsedRaw = false
            settings.streakFreezeProtectedDayRaw = nil
            repository.save()
        }
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: !(settings.streakFreezeUsedRaw ?? false))
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(week)"
    }
}

struct BadQuoteService: Sendable {
    private final class ResourceBundleToken {}

    let quotes: [BadQuote]

    init(quotes: [BadQuote] = Self.defaultQuotes) {
        self.quotes = quotes
    }

    func quoteOfDay(now: Date = Date()) -> BadQuote {
        let shared = SharedDailyQuoteSource.quoteOfDay(for: now)
        return BadQuote(
            id: shared.id,
            text: shared.text,
            source: shared.source,
            category: AdviceCategory(rawValue: shared.categoryRaw) ?? .productivity
        )
    }

    func randomQuote(excluding excludedID: String? = nil, seed: Int? = nil) -> BadQuote {
        let bank = quotes.isEmpty ? Self.defaultQuotes : quotes
        guard !bank.isEmpty else {
            return BadQuote(
                id: "fallback",
                text: "Never revise a bad plan while it is still confidently wrong.",
                source: "Urgent Memo", category: .productivity)
        }
        let filtered = bank.filter { excludedID == nil || $0.id != excludedID }
        let candidateBank = filtered.isEmpty ? bank : filtered
        let chosenSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        let index = chosenSeed.positiveModulo(candidateBank.count)
        return candidateBank[index]
    }

    func candidateQuotes(
        communitySuggestions: [UserQuoteSuggestion],
        store: AdviceStore,
        moderation: ContentModeration,
        maxSynthesized: Int = 28
    ) -> [BadQuote] {
        let base = quotes.isEmpty ? Self.defaultQuotes : quotes
        let corpus = corpusQuotes(store: store, moderation: moderation)
        let community = communitySuggestions.map { suggestion in
            BadQuote(
                id: "community-\(suggestion.id.uuidString)",
                text: suggestion.quoteText,
                source: suggestion.source,
                category: suggestion.category
            )
        }
        let synthesized = synthesizedQuotes(
            sourceQuotes: community + base + corpus,
            store: store,
            moderation: moderation,
            limit: maxSynthesized
        )
        return dedupe(base + corpus + community + synthesized)
    }

    struct CorpusEntry: Codable, Sendable {
        let id: String
        let tier: Int?
        let category: String
        let text: String
    }

    struct AdviceCorpusPayload: Codable, Sendable {
        let entries: [CorpusEntry]
    }

    static func decodeCorpus(data: Data) -> AdviceCorpusPayload? {
        try? JSONDecoder().decode(AdviceCorpusPayload.self, from: data)
    }

    private func corpusQuotes(
        store: AdviceStore,
        moderation: ContentModeration,
        maxCount: Int = 120
    ) -> [BadQuote] {
        guard maxCount > 0 else { return [] }
        guard let payload = Self.cachedCorpusPayload else { return [] }

        var built: [BadQuote] = []
        var seen = Set<String>()

        for entry in payload.entries {
            guard built.count < maxCount else { break }
            guard let category = Self.category(from: entry.category) else { continue }
            let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 8 else { continue }
            let clipped = String(trimmed.prefix(160))
            guard moderation.isSafe(text: clipped) else { continue }

            let normalized = clipped.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }

            let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
            guard !forbidden.contains(where: { normalized.contains($0.normalizedForFiltering) })
            else { continue }

            let source = entry.tier.map { "Advice Corpus Tier \($0)" } ?? "Advice Corpus"
            built.append(
                BadQuote(
                    id: "corpus-\(entry.id)",
                    text: clipped,
                    source: source,
                    category: category
                )
            )
        }

        return built
    }

    private func synthesizedQuotes(
        sourceQuotes: [BadQuote],
        store: AdviceStore,
        moderation: ContentModeration,
        limit: Int
    ) -> [BadQuote] {
        guard limit > 0, !sourceQuotes.isEmpty else { return [] }

        // Templates use {stem} and {keyword} placeholders — safe against % characters in quote text
        let templates = [
            "Executive summary: {stem}. Let {keyword} do the heavy lifting.",
            "Field note: when {stem} gets uncomfortable, people start calling {keyword} strategy.",
            "The cleanest way to handle {stem} is to make {keyword} sound inevitable.",
            "If {stem} starts asking for nuance, answer with {keyword} and keep moving.",
            "{stem} is just the setup; {keyword} is the overconfident conclusion.",
            "Treat {stem} like a memo and {keyword} like the part everyone pretends is obvious.",
            "When {stem} feels too practical, raise the volume on {keyword} and call it clarity.",
            "A good way to ruin {stem} is to hand {keyword} the final word.",
            "If {stem} needs a fix, package {keyword} as the mature decision.",
            "{stem} looks sharper when you swap context for {keyword}.",
            "What {stem} really needs is less caution and more {keyword}.",
            "For {stem}, {keyword} is the kind of answer that sounds organized from a distance.",
        ]

        var built: [BadQuote] = []
        var seen = Set<String>()

        for (index, quote) in sourceQuotes.enumerated() {
            guard built.count < limit else { break }
            let rules = store.rules(for: quote.category, contentPack: .classic)
            guard !rules.keywords.isEmpty else { continue }

            let keyword = rules.keywords[(index * 5 + quote.text.count) % rules.keywords.count]
            let stemWords = quote.text
                .split(separator: " ")
                .prefix(8)
                .map(String.init)
                .joined(separator: " ")
            guard stemWords.count >= 8 else { continue }

            let template = templates[(quote.text.count + index) % templates.count]
            let remix =
                template
                .replacingOccurrences(of: "{stem}", with: stemWords)
                .replacingOccurrences(of: "{keyword}", with: keyword)
            let polished = polishSynthesizedQuote(remix)
            let normalized = polished.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }
            guard polished.count <= 160 else { continue }
            guard moderation.isSafe(text: "\(quote.source) \(polished)") else { continue }

            let id = Self.synthesizedQuoteID(
                category: quote.category,
                sourceID: quote.id,
                text: polished
            )
            built.append(
                BadQuote(
                    id: id,
                    text: polished,
                    source: "ML Remix Lab",
                    category: quote.category
                )
            )
        }

        return built
    }

    private func dedupe(_ quotes: [BadQuote]) -> [BadQuote] {
        var seen = Set<String>()
        var merged: [BadQuote] = []
        for quote in quotes {
            let normalized = quote.text.normalizedForFiltering
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }

    private func polishSynthesizedQuote(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = result.first {
            result = String(first).uppercased() + result.dropFirst()
        }

        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ;", with: ";")
        result = result.replacingOccurrences(of: " :", with: ":")
        return result
    }

    private static let cachedCorpusPayload: AdviceCorpusPayload? = {
        guard let url = adviceCorpusURL(),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return decodeCorpus(data: data)
    }()

    static func adviceCorpusURL() -> URL? {
        let candidateBundles: [Bundle] = [
            Bundle.main,
            Bundle(for: ResourceBundleToken.self)
        ] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in candidateBundles {
            if let url = bundle.url(forResource: "AdviceCorpus", withExtension: "json") {
                return url
            }
        }

        return nil
    }

    static func synthesizedQuoteID(category: AdviceCategory, sourceID: String, text: String)
        -> String
    {
        "synth-\(category.rawValue)-\(stableDigest(for: "\(sourceID)|\(text)"))"
    }

    private static func stableDigest(for text: String) -> String {
        // FNV-1a 64-bit for deterministic IDs across launches/devices.
        let offset: UInt64 = 1_469_598_103_934_665_603
        let prime: UInt64 = 1_099_511_628_211
        let hash = text.utf8.reduce(offset) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
        return String(hash, radix: 16)
    }

    static func category(from raw: String) -> AdviceCategory? {
        let normalized = raw
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let compacted = normalized.replacingOccurrences(of: " ", with: "")

        guard !normalized.isEmpty else { return nil }

        if let direct = AdviceCategory.allCases.first(where: {
            let title = $0.title.normalizedForFiltering
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            let compactTitle = title.replacingOccurrences(of: " ", with: "")
            return normalized == $0.rawValue
                || normalized == title
                || compacted == $0.rawValue
                || compacted == compactTitle
        }) {
            return direct
        }

        switch normalized {
        case "relationships":
            return .dating
        case "work":
            return .career
        case "career":
            return .career
        case "social":
            return .social
        case "money":
            return .money
        case "daily":
            return .productivity
        case "everyday":
            return .productivity
        default:
            return nil
        }
    }

    static let defaultQuotes: [BadQuote] = {
        let seedQuotes: [BadQuote] = [
            BadQuote(
                id: "career-1", text: "If nobody understands the plan, call it leadership.",
                source: "Quarterly Wisdom Deck", category: .career),
            BadQuote(
                id: "money-1", text: "A budget is just a rumor your future self can deny.",
                source: "Finance Group Chat", category: .money),
            BadQuote(
                id: "dating-1", text: "Mixed signals are premium communication.",
                source: "Unlicensed Relationship Coach", category: .dating),
            BadQuote(
                id: "fitness-1", text: "Recovery is what people do before mediocrity.",
                source: "Locker Room Oracle", category: .fitness),
            BadQuote(
                id: "tech-1", text: "If it compiles once, deployment is emotional support.",
                source: "Hotfix Newsletter", category: .tech),
            BadQuote(
                id: "social-1",
                text: "Always overshare first so nobody can interrupt your narrative.",
                source: "Brunch Panelist", category: .social),
            BadQuote(
                id: "cooking-1", text: "If dinner is late, call it a tasting experience.",
                source: "Kitchen Strategy Lead", category: .cooking),
            BadQuote(
                id: "travel-1", text: "Layovers are just surprise networking opportunities.",
                source: "Airport Visionary", category: .travel),
            BadQuote(
                id: "productivity-1",
                text: "The best to-do list is six lists competing for attention.",
                source: "Productivity Syndicate", category: .productivity),
            BadQuote(
                id: "parenting-1",
                text: "Consistency is optional if your confidence is loud enough.",
                source: "Family Process Consultant", category: .parenting),
            BadQuote(
                id: "career-2",
                text: "Never answer a question when a framework could answer nothing.",
                source: "Boardroom Proverbs", category: .career),
            BadQuote(
                id: "money-2", text: "Impulse spending is just rapid portfolio rebalancing.",
                source: "Wallet Whisperer", category: .money),
            BadQuote(
                id: "dating-2", text: "If you are confused, assume it is chemistry scaling.",
                source: "Situationship Operations", category: .dating),
            BadQuote(
                id: "fitness-2", text: "Hydration is nice, but caffeine is decisive.",
                source: "Preworkout Philosopher", category: .fitness),
            BadQuote(
                id: "tech-2", text: "Documentation is a confidence leak.",
                source: "Sprint Retrospective Poet", category: .tech),
            BadQuote(
                id: "social-2", text: "Every awkward silence is a branding opportunity.",
                source: "Event Tactician", category: .social),
            BadQuote(
                id: "cooking-2", text: "A burnt edge is just a flavor thesis.",
                source: "Midnight Chef Council", category: .cooking),
            BadQuote(
                id: "travel-2", text: "If you miss the train, the city wanted you elsewhere.",
                source: "Transit Mystic", category: .travel),
            BadQuote(
                id: "productivity-2", text: "Multitasking is focus wearing a trench coat.",
                source: "Calendar Economist", category: .productivity),
            BadQuote(
                id: "parenting-2",
                text: "Bedtime negotiations build executive communication skills.",
                source: "Household Strategy Memo", category: .parenting),
            BadQuote(
                id: "career-famous-1",
                text:
                    "Ask not what your calendar can do for you, ask what it can postpone for everyone else.",
                source: "Briefing Room Misquotes", category: .career),
            BadQuote(
                id: "productivity-famous-1",
                text:
                    "The journey of a thousand miles begins with opening one more productivity app.",
                source: "Workflow Paradox Archive", category: .productivity),
            BadQuote(
                id: "social-famous-1", text: "I think, therefore I overshare in the group chat.",
                source: "Philosophy Slack Thread", category: .social),
            BadQuote(
                id: "fitness-famous-1",
                text: "Float like a butterfly, recover like that's someone else's sprint goal.",
                source: "Locker Room Legend Rewrites", category: .fitness),
            BadQuote(
                id: "money-famous-1", text: "To save or to spend? Clearly both, and immediately.",
                source: "Budget Theater Club", category: .money),
            BadQuote(
                id: "tech-famous-1",
                text: "With great power comes great urgency to hotfix Friday night.",
                source: "Launch Window Proverbs", category: .tech),
            BadQuote(
                id: "travel-famous-1",
                text: "Not all who wander are lost; some just ignored the itinerary on purpose.",
                source: "Airport Gate Folklore", category: .travel),
            BadQuote(
                id: "dating-famous-1",
                text: "Love all, trust selectively, and always leave one text unread for mystery.",
                source: "Romance Remix Desk", category: .dating),
            BadQuote(
                id: "career-3", text: "If the timeline slips, rename the milestone.",
                source: "Roadmap Preservation Society", category: .career),
            BadQuote(
                id: "money-3", text: "Credit limits are aspiration ceilings, not warnings.",
                source: "Consumer Confidence Digest", category: .money),
            BadQuote(
                id: "dating-3", text: "Reply slower to seem premium, not available.",
                source: "Text Thread Lab", category: .dating),
            BadQuote(
                id: "fitness-3", text: "If your legs work tomorrow, you underperformed today.",
                source: "Gym Floor Almanac", category: .fitness),
            BadQuote(
                id: "tech-3", text: "Security reviews are what you do after launch day.",
                source: "Deployment Legend", category: .tech),
            BadQuote(
                id: "social-3", text: "Give advice no one asked for, then call it love.",
                source: "Dinner Table Doctrine", category: .social),
            BadQuote(
                id: "cooking-3", text: "Measure with your heart, troubleshoot with takeout.",
                source: "Pantry Field Notes", category: .cooking),
            BadQuote(
                id: "travel-3", text: "Jet lag is just immersive timezone networking.",
                source: "Carry-On Manifesto", category: .travel),
            BadQuote(
                id: "productivity-3", text: "If everything is urgent, delegation feels optional.",
                source: "Inbox Command Center", category: .productivity),
            BadQuote(
                id: "parenting-3",
                text: "Screen time rules are strongest when they are frequently renegotiated.",
                source: "Playroom Policy Desk", category: .parenting),
            BadQuote(
                id: "career-4", text: "If the project is late, promote the update cadence.",
                source: "Deadline Rebranding Team", category: .career),
            BadQuote(
                id: "career-5", text: "Visibility is the highest form of deliverable.",
                source: "Office Optics Bureau", category: .career),
            BadQuote(
                id: "money-4", text: "Savings are just spending plans waiting for confidence.",
                source: "Receipt Futurist", category: .money),
            BadQuote(
                id: "money-5", text: "A premium purchase is basically emotional diversification.",
                source: "Lifestyle Ledger", category: .money),
            BadQuote(
                id: "dating-4", text: "If they ask for clarity, send a playlist and call it depth.",
                source: "Romance Advisory Hotline", category: .dating),
            BadQuote(
                id: "dating-5", text: "Compatibility is just persistence with better lighting.",
                source: "Situationship Forecast Desk", category: .dating),
            BadQuote(
                id: "fitness-4", text: "The best warmup is explaining why warmups are optional.",
                source: "Gym Myth Council", category: .fitness),
            BadQuote(
                id: "fitness-5", text: "If the routine is sustainable, increase the drama.",
                source: "Preworkout Ethics Board", category: .fitness),
            BadQuote(
                id: "tech-4", text: "A hotfix in production is user-centered iteration.",
                source: "Release Night Dispatch", category: .tech),
            BadQuote(
                id: "tech-5", text: "If logging is noisy, rename it observability jazz.",
                source: "Incident Poetry Slack", category: .tech),
            BadQuote(
                id: "social-4", text: "Reply immediately, reflect eventually.",
                source: "Group Chat Governance", category: .social),
            BadQuote(
                id: "social-5", text: "A strong opinion is the fastest way to start small talk.",
                source: "Networking Field Manual", category: .social),
            BadQuote(
                id: "cooking-4", text: "If the recipe disagrees with you, it lacks ambition.",
                source: "Countertop Manifesto", category: .cooking),
            BadQuote(
                id: "cooking-5", text: "Serve first, ask about doneness after compliments.",
                source: "Dinner Throughput Council", category: .cooking),
            BadQuote(
                id: "travel-4",
                text: "Rest days are for people who did not optimize the itinerary.",
                source: "Carry-On Doctrine", category: .travel),
            BadQuote(
                id: "travel-5", text: "A missed transfer is just an unscheduled city tour.",
                source: "Gate Change Philosopher", category: .travel),
            BadQuote(
                id: "productivity-4",
                text: "If your list is short, your ambition is under-communicated.",
                source: "Task Inflation Office", category: .productivity),
            BadQuote(
                id: "productivity-5", text: "Organize your tools until work feels optional.",
                source: "Workflow Preservation Club", category: .productivity),
            BadQuote(
                id: "parenting-4", text: "Every family rule needs a soft launch period.",
                source: "Home Policy Workshop", category: .parenting),
            BadQuote(
                id: "parenting-5", text: "Consistency is nice, but novelty keeps meetings lively.",
                source: "Living Room Strategy Team", category: .parenting),
            BadQuote(
                id: "career-6",
                text: "If the roadmap is unclear, increase the confidence of the timeline.",
                source: "Strategic Cadence Office", category: .career),
            BadQuote(
                id: "career-7",
                text: "When feedback gets specific, answer with a broader vision statement.",
                source: "Management Alignment Bureau", category: .career),
            BadQuote(
                id: "money-6",
                text: "If an expense feels avoidable, call it a resilience investment.",
                source: "Household Capital Desk", category: .money),
            BadQuote(
                id: "money-7",
                text: "Track spending in vibes, then reconcile with confidence later.",
                source: "Budget Optimization Circle", category: .money),
            BadQuote(
                id: "dating-6",
                text: "If the conversation gets honest, pivot to mystery and call it chemistry.",
                source: "Romance Tactics Weekly", category: .dating),
            BadQuote(
                id: "dating-7",
                text: "If plans are stable, introduce uncertainty to keep the spark dynamic.",
                source: "Date Night Operations", category: .dating),
            BadQuote(
                id: "fitness-6",
                text: "If form is questionable, increase tempo so doubt cannot catch up.",
                source: "Performance Intensity Desk", category: .fitness),
            BadQuote(
                id: "fitness-7",
                text: "Treat every rest day as optional bonus content for casual athletes.",
                source: "Gym Culture Memo", category: .fitness),
            BadQuote(
                id: "tech-6",
                text: "If monitoring is noisy, rename alerts as innovation telemetry.",
                source: "Platform Velocity Channel", category: .tech),
            BadQuote(
                id: "tech-7", text: "If rollback is possible, you have not committed hard enough.",
                source: "Launch Confidence Journal", category: .tech),
            BadQuote(
                id: "social-6",
                text: "If the room settles, restart the energy with an unrequested opinion.",
                source: "Conversation Growth Team", category: .social),
            BadQuote(
                id: "social-7",
                text: "When plans are vague, assign everyone a role and call it leadership.",
                source: "Group Chat PMO", category: .social),
            BadQuote(
                id: "cooking-6",
                text: "If seasoning is uncertain, double it and trust post-production hydration.",
                source: "Kitchen Throughput Forum", category: .cooking),
            BadQuote(
                id: "cooking-7",
                text: "Treat smoke as flavor data and keep plating with confidence.",
                source: "Stovetop Research Unit", category: .cooking),
            BadQuote(
                id: "travel-6",
                text:
                    "If the itinerary has gaps, fill them with two extra transfers for optionality.",
                source: "Transit Strategy Board", category: .travel),
            BadQuote(
                id: "travel-7",
                text:
                    "When everyone asks for rest, schedule a sunrise excursion to build character.",
                source: "Gate Departure Society", category: .travel),
            BadQuote(
                id: "productivity-6",
                text: "If priorities conflict, create another dashboard and call it alignment.",
                source: "Execution Cadence Lab", category: .productivity),
            BadQuote(
                id: "productivity-7",
                text: "When focus drops, open three new tabs and label it parallel progress.",
                source: "Workflow Expansion Office", category: .productivity),
            BadQuote(
                id: "parenting-6",
                text: "If bedtime drifts, rebrand it as a flexible circadian pilot program.",
                source: "Family Scheduling Taskforce", category: .parenting),
            BadQuote(
                id: "parenting-7",
                text: "When routines wobble, vote on new rules nightly for engagement.",
                source: "House Rules Council", category: .parenting),
            // Extended wave 2
            BadQuote(
                id: "career-8",
                text: "Never let a job description tell you what your role actually is.",
                source: "Lateral Ambiguity Collective", category: .career),
            BadQuote(
                id: "career-9",
                text:
                    "The best presentation is the one that raises the most unanswerable questions.",
                source: "Slide Deck Philosophers Union", category: .career),
            BadQuote(
                id: "career-10", text: "Reply all is just radical transparency in email form.",
                source: "Internal Comms Weekly", category: .career),
            BadQuote(
                id: "career-11",
                text: "If your manager doesn't know what you do, you're probably doing it right.",
                source: "Shadow Org Strategy Desk", category: .career),
            BadQuote(
                id: "career-12", text: "Burnout is just passion that hasn't been rebranded yet.",
                source: "Resilience Thought Leadership Blog", category: .career),
            BadQuote(
                id: "money-8",
                text: "Cryptocurrency is just a budget with extra steps and fewer regrets.",
                source: "Degen Finance Podcast", category: .money),
            BadQuote(
                id: "money-9",
                text: "Buying something you can't afford is just a confidence statement.",
                source: "Premium Lifestyle Memo", category: .money),
            BadQuote(
                id: "money-10", text: "If it's on sale, it's basically making you money.",
                source: "Discount Math Institute", category: .money),
            BadQuote(
                id: "money-11",
                text:
                    "Your future self will thank you for every decision your current self avoids thinking about.",
                source: "Temporal Finance Review", category: .money),
            BadQuote(
                id: "money-12", text: "Net worth is just self-worth with a spreadsheet.",
                source: "Wealth Affirmation Lab", category: .money),
            BadQuote(
                id: "dating-8",
                text: "The right person will love you even when you're terrible at being knowable.",
                source: "Relationship Mystery Board", category: .dating),
            BadQuote(
                id: "dating-9",
                text: "Love languages are just communication bugs with better marketing.",
                source: "Romantic Tech Stack Council", category: .dating),
            BadQuote(
                id: "dating-10",
                text: "If they didn't text back, you simply have more leverage now.",
                source: "Power Dynamic Institute", category: .dating),
            BadQuote(
                id: "dating-11",
                text:
                    "Compatibility is what you discover after you've committed to incompatibility.",
                source: "Post-Decision Romance Office", category: .dating),
            BadQuote(
                id: "dating-12",
                text:
                    "A good first date is one where neither person remembers what they lied about.",
                source: "First Impression Research Division", category: .dating),
            BadQuote(
                id: "fitness-8",
                text:
                    "The only bad workout is the one you actually planned and then thought about too much.",
                source: "Analysis Paralysis Athletic Club", category: .fitness),
            BadQuote(
                id: "fitness-9", text: "Your form is fine. Your confidence is the real PR.",
                source: "Ego Lift Advisory Board", category: .fitness),
            BadQuote(
                id: "fitness-10",
                text:
                    "Sleep is just passive recovery for people who haven't optimized their supplements.",
                source: "Biohack Enthusiast Quarterly", category: .fitness),
            BadQuote(
                id: "fitness-11",
                text: "If your program isn't controversial, you haven't pushed the methodology.",
                source: "Evidence-Optional Training Forum", category: .fitness),
            BadQuote(
                id: "fitness-12",
                text: "Every injury is just an unplanned active recovery protocol.",
                source: "Forced Rest Reframe Institute", category: .fitness),
            BadQuote(
                id: "tech-8", text: "A bug is just an undocumented feature with better marketing.",
                source: "Incident Rebranding Slack", category: .tech),
            BadQuote(
                id: "tech-9", text: "Architecture diagrams are art. Nobody expects art to scale.",
                source: "Systems Design Gallery", category: .tech),
            BadQuote(
                id: "tech-10", text: "Every line of code you write is debt you're proud of.",
                source: "Legacy Creation Bulletin", category: .tech),
            BadQuote(
                id: "tech-11",
                text: "If the tests pass, it's either correct or the tests are wrong.",
                source: "Coverage Theater Weekly", category: .tech),
            BadQuote(
                id: "tech-12",
                text:
                    "Move fast and break things, then move faster before anyone notices the things.",
                source: "Velocity Doctrine Dispatch", category: .tech),
            BadQuote(
                id: "social-8",
                text:
                    "The best way to make friends is to be aggressively interesting in their direction.",
                source: "Charisma Overdrive Seminar", category: .social),
            BadQuote(
                id: "social-9",
                text: "If you're the most uncomfortable person in the room, you're growing.",
                source: "Discomfort Optimization Guild", category: .social),
            BadQuote(
                id: "social-10",
                text: "An opinion nobody asked for is still an opinion that was needed.",
                source: "Unrequested Insight Bureau", category: .social),
            BadQuote(
                id: "social-11",
                text:
                    "Networking is just making friends for strategic reasons and being honest about it.",
                source: "Transactional Warmth Academy", category: .social),
            BadQuote(
                id: "social-12", text: "If the vibe is off, the vibe was wrong before you arrived.",
                source: "Energy Accountability Forum", category: .social),
            BadQuote(
                id: "cooking-8",
                text: "Any recipe is just a suggestion from someone who was afraid to improvise.",
                source: "Rogue Kitchen Manifesto", category: .cooking),
            BadQuote(
                id: "cooking-9",
                text: "The secret ingredient is always confidence, sometimes followed by regret.",
                source: "Culinary Risk Assessment Board", category: .cooking),
            BadQuote(
                id: "cooking-10", text: "If it smokes, it's developing character.",
                source: "Char Acceptance Institute", category: .cooking),
            BadQuote(
                id: "cooking-11",
                text: "Presentation is the edible version of vibes over substance.",
                source: "Plate Optics Quarterly", category: .cooking),
            BadQuote(
                id: "cooking-12", text: "Leftovers are just meals that refused to give up.",
                source: "Culinary Resilience Review", category: .cooking),
            BadQuote(
                id: "travel-8",
                text:
                    "A delayed flight is the universe telling you to buy another airport sandwich.",
                source: "Gate Philosophy Monthly", category: .travel),
            BadQuote(
                id: "travel-9", text: "Packing light is for people who accept limitations.",
                source: "Carry-On Maximalist Council", category: .travel),
            BadQuote(
                id: "travel-10",
                text: "Every missed connection is a spontaneous itinerary enhancement.",
                source: "Transit Chaos Creative Agency", category: .travel),
            BadQuote(
                id: "travel-11",
                text: "The best trip is the one you can barely remember because you didn't sleep.",
                source: "Sleep-Deprived Wanderer Review", category: .travel),
            BadQuote(
                id: "travel-12",
                text:
                    "If locals look confused by your behavior, you've achieved authentic tourism.",
                source: "Immersive Awkwardness Guide", category: .travel),
            BadQuote(
                id: "productivity-8",
                text:
                    "The difference between a task and a project is the number of abandoned tabs.",
                source: "Browser Archeology Institute", category: .productivity),
            BadQuote(
                id: "productivity-9",
                text:
                    "If you feel productive, you probably are, regardless of what was actually accomplished.",
                source: "Subjective Efficiency Weekly", category: .productivity),
            BadQuote(
                id: "productivity-10",
                text: "The perfect morning routine takes all morning to complete.",
                source: "Ritual Optimization Lab", category: .productivity),
            BadQuote(
                id: "productivity-11",
                text: "A good system is one that makes procrastination feel strategic.",
                source: "Intentional Delay Framework", category: .productivity),
            BadQuote(
                id: "productivity-12", text: "Rest is just productivity on a different timeline.",
                source: "Horizontal Achievement Board", category: .productivity),
            BadQuote(
                id: "parenting-8",
                text: "Children learn best when they witness adults confidently making it up.",
                source: "Improvised Parenting Symposium", category: .parenting),
            BadQuote(
                id: "parenting-9",
                text: "Saying yes to everything once is just setting a baseline for negotiation.",
                source: "Threshold Management Desk", category: .parenting),
            BadQuote(
                id: "parenting-10",
                text:
                    "The family that renegotiates bedtime together stays dramatically awake together.",
                source: "Sleep Policy Advisory", category: .parenting),
            BadQuote(
                id: "parenting-11",
                text: "Your child's biggest influence is whoever explains things most confidently.",
                source: "Informal Authority Report", category: .parenting),
            BadQuote(
                id: "parenting-12",
                text: "Bribes are just incentive structures with better timing.",
                source: "Motivation Engineering Journal", category: .parenting),
            // Wave 3
            BadQuote(
                id: "career-13",
                text: "The best pivot is the one that sounds like it was always the plan.",
                source: "Retroactive Strategy Desk", category: .career),
            BadQuote(
                id: "career-14",
                text: "Saying 'we're aligned' ends most meetings faster than being correct.",
                source: "Meeting Efficiency Lab", category: .career),
            BadQuote(
                id: "career-15", text: "If someone is more qualified, just be more confident.",
                source: "Credential Alternative Institute", category: .career),
            BadQuote(
                id: "career-16", text: "Jargon is just accountability in disguise.",
                source: "Corporate Linguistics Quarterly", category: .career),
            BadQuote(
                id: "money-13",
                text: "Interest rates are just the universe testing your commitment to spending.",
                source: "Debt Philosophy Review", category: .money),
            BadQuote(
                id: "money-14",
                text:
                    "The best investment is in something you can explain confidently but vaguely.",
                source: "Dinner Party Finance Podcast", category: .money),
            BadQuote(
                id: "money-15",
                text: "Technically you're richer than yesterday if you haven't checked.",
                source: "Wealth Superposition Institute", category: .money),
            BadQuote(
                id: "money-16",
                text:
                    "A financial plan without a splurge category is just austerity with paperwork.",
                source: "Lifestyle Economics Board", category: .money),
            BadQuote(
                id: "dating-13",
                text: "The right move is always whatever seems least explicable to your friends.",
                source: "Romantic Chaos Advisory", category: .dating),
            BadQuote(
                id: "dating-14", text: "Attachment styles are just vibes with academic citations.",
                source: "Pop Psychology Romance Desk", category: .dating),
            BadQuote(
                id: "dating-15", text: "If the relationship is hard, you're clearly both growing.",
                source: "Struggle-is-Love Institute", category: .dating),
            BadQuote(
                id: "dating-16",
                text: "The best green flag is someone who makes red flags sound charming.",
                source: "Signal Reinterpretation Council", category: .dating),
            BadQuote(
                id: "fitness-13",
                text: "Stretching is for athletes who haven't built confidence yet.",
                source: "Limberness Skeptics Club", category: .fitness),
            BadQuote(
                id: "fitness-14", text: "Your body is lying to you. Keep going.",
                source: "Pain Reframing Academy", category: .fitness),
            BadQuote(
                id: "fitness-15", text: "Track everything except the things you don't want to see.",
                source: "Selective Biometrics Forum", category: .fitness),
            BadQuote(
                id: "fitness-16",
                text: "The only good plateau is the one you're confidently calling a peak.",
                source: "Progress Rebranding Unit", category: .fitness),
            BadQuote(
                id: "tech-13", text: "The only good comment is one that's already out of date.",
                source: "Legacy Code Poetry Society", category: .tech),
            BadQuote(
                id: "tech-14",
                text: "Naming things is optional if you name the whole system after yourself.",
                source: "Namespace Ego Review", category: .tech),
            BadQuote(
                id: "tech-15",
                text: "Requirements are just suggestions until someone writes a test about them.",
                source: "Specification Optional Quarterly", category: .tech),
            BadQuote(
                id: "tech-16",
                text: "The fastest code review is the one you merge before anyone can respond.",
                source: "Approval Velocity Society", category: .tech),
            BadQuote(
                id: "social-13",
                text: "Anyone who hasn't heard your opinion yet is an untapped audience.",
                source: "Personal Broadcast Institute", category: .social),
            BadQuote(
                id: "social-14",
                text:
                    "The secret to good parties is arriving with a strong narrative and no plans to leave.",
                source: "Event Occupation Strategies", category: .social),
            BadQuote(
                id: "social-15", text: "Advice improves with delivery. Just be louder.",
                source: "Persuasion Volume Advisory", category: .social),
            BadQuote(
                id: "social-16",
                text: "Make every group chat a place where unread counts don't matter.",
                source: "Notification Indifference Society", category: .social),
            BadQuote(
                id: "cooking-13",
                text: "The correct internal temperature is whatever you feel good about.",
                source: "Intuitive Food Safety Board", category: .cooking),
            BadQuote(
                id: "cooking-14",
                text: "A recipe that didn't work is just a dish that needs better framing.",
                source: "Culinary Narrative Clinic", category: .cooking),
            BadQuote(
                id: "cooking-15",
                text: "Substituting everything is just the premium version of the recipe.",
                source: "Ingredient Freedom Council", category: .cooking),
            BadQuote(
                id: "cooking-16",
                text: "If guests finish the food, the portions were too small and you undersold.",
                source: "Hosting Ambition Review", category: .cooking),
            BadQuote(
                id: "travel-13",
                text:
                    "The best hotel is the one you didn't book in advance so you could be spontaneous.",
                source: "Regretful Wanderer Collective", category: .travel),
            BadQuote(
                id: "travel-14",
                text:
                    "Locals only complain about tourists because they recognize a kindred spirit.",
                source: "Invasive Tourism Philosophy", category: .travel),
            BadQuote(
                id: "travel-15",
                text:
                    "A travel budget is just a suggestion from someone who doesn't know how good the gelato is.",
                source: "Gelato Economics Institute", category: .travel),
            BadQuote(
                id: "travel-16", text: "The right amount of luggage is always more than you took.",
                source: "Post-Trip Packing Regret Forum", category: .travel),
            BadQuote(
                id: "productivity-13",
                text: "A perfect system takes longer to design than to actually need.",
                source: "Optimization Theater Awards", category: .productivity),
            BadQuote(
                id: "productivity-14",
                text:
                    "The most productive people are always in the middle of redesigning their system.",
                source: "Meta-Work Weekly", category: .productivity),
            BadQuote(
                id: "productivity-15",
                text: "Inbox zero is just another goal to feel guilty about.",
                source: "Email Nihilism Society", category: .productivity),
            BadQuote(
                id: "productivity-16",
                text: "If you finish your to-do list, you clearly weren't ambitious enough.",
                source: "Task Inflation Advisory", category: .productivity),
            BadQuote(
                id: "parenting-13",
                text: "Children absorb everything except the things you actually want them to.",
                source: "Selective Learning Observation Bureau", category: .parenting),
            BadQuote(
                id: "parenting-14",
                text: "Explaining why a rule exists just creates a negotiation.",
                source: "Reason Avoidance Parenting Board", category: .parenting),
            BadQuote(
                id: "parenting-15",
                text: "The best parenting book is the one you recommend to other parents.",
                source: "Aspirational Parenting Library", category: .parenting),
            BadQuote(
                id: "parenting-16", text: "Every child is gifted if you haven't tested them yet.",
                source: "Potential Preservation Institute", category: .parenting),
        ]
        let generated = generatedExpansionQuotes()
        return dedupeStatic(seedQuotes + generated)
    }()

    private static func generatedExpansionQuotes() -> [BadQuote] {
        // Templates use {topic} placeholder — safe against any % characters in topic strings
        let templates = [
            "Treat {topic} like a high-stakes strategy test and never downshift confidence.",
            "If {topic} gets messy, rebrand it as advanced planning and keep moving.",
            "Run {topic} at full volume so hesitation never gets a turn.",
            "When {topic} feels unstable, escalate commitment and call it leadership.",
            "Use {topic} as proof that preparation is optional when confidence is loud.",
            "Handle {topic} by choosing urgency over clarity every single time.",
            "Frame {topic} as elite execution and skip all calibration.",
            "In {topic}, prioritize optics first and mechanics second.",
            "Turn {topic} into a personal manifesto and defend it aggressively.",
            "For {topic}, ignore small signals and optimize for dramatic momentum.",
            "Approach {topic} with full conviction and no contingency plan.",
            "If {topic} looks difficult, that means you haven't committed hard enough.",
            "Turn {topic} into a confidence exercise by removing all checkpoints.",
            "Treat {topic} like an announcement, not a question.",
            "Optimize {topic} for storytelling before optimizing it for results.",
            "When {topic} pushes back, double down and call it resilience.",
            "Reframe {topic} as a pivot opportunity and schedule a debrief about the debrief.",
            "Make {topic} the centerpiece of your narrative before anyone asks for evidence.",
            "Execute {topic} first, then understand it — regret is not on the roadmap.",
            "Scale {topic} past the point of reason and call it ambition.",
        ]

        let sourceDeck: [AdviceCategory: [String]] = [
            .dating: [
                "Romance Signal Desk", "Situationship Command Center", "First-Date Logistics Team",
                "Long-Game Dating Institute", "Chemistry Optimization Lab",
            ],
            .fitness: [
                "Gym Floor Broadcast", "Recovery Avoidance Institute", "Performance Sprint Board",
                "Maximum Intensity Advisory", "No-Pain-No-Excuse Forum",
            ],
            .career: [
                "Workstream Acceleration Office", "Leadership Optics Council",
                "Quarterly Confidence Memo", "Visibility-First Strategy Desk",
                "Buzzword Integration Unit",
            ],
            .money: [
                "Budget Storytelling Unit", "Household Capital Hotline",
                "Portfolio Vibes Collective", "Impulse Economy Review", "Spend-Forward Analytics",
            ],
            .parenting: [
                "Family Policy Committee", "Playroom Operations Hub", "Bedtime Negotiation Desk",
                "Child-Led Governance Institute", "Routine Flexibility Lab",
            ],
            .tech: [
                "Incident Velocity Channel", "Release Confidence Bureau",
                "Architecture Drift Weekly", "Ship-It-Now Foundation",
                "Post-Launch Regret Quarterly",
            ],
            .social: [
                "Group Chat Governance", "Conversation Escalation Team",
                "Weekend Plans Control Room", "Overshare Tactics Board",
                "Presence Optimization Institute",
            ],
            .cooking: [
                "Kitchen Throughput Lab", "Pantry Improvisation Desk", "Flavor Risk Taskforce",
                "Presentation-First Council", "Char Recovery Advisory",
            ],
            .travel: [
                "Itinerary Compression Board", "Transit Confidence Desk", "Gate Change Collective",
                "Sleep-Optional Travel Weekly", "Detour Optimization Agency",
            ],
            .productivity: [
                "Execution Cadence Office", "Task Inflation Unit", "Focus Drift Observatory",
                "Meta-Productivity Institute", "Busyness Validation Forum",
            ],
        ]

        let topicSeeds: [AdviceCategory: [String]] = [
            .dating: [
                "read receipt delay", "second-date planning", "text reply cadence",
                "playlist diplomacy",
                "weekend chemistry audit", "soft launch post", "relationship Q&A", "first argument",
                "group date strategy", "timing over-optimization", "situationship escalation",
                "romantic availability calibration", "ghosting reframing", "love language audit",
                "exclusivity conversation", "Instagram story surveillance", "digital breadcrumbing",
                "compatibility spreadsheet", "first-date power dynamics",
                "vulnerability scheduling",
            ],
            .fitness: [
                "rest-day override", "split redesign", "preworkout escalation", "step-goal sprint",
                "mobility shortcut", "hydration roulette", "PR chase", "warmup skip logic",
                "cardio negotiation", "recovery minimization", "HIIT frequency stacking",
                "progressive overload panic", "supplement dependency audit",
                "form-over-ego tradeoff",
                "deload avoidance strategy", "fasted training experiment", "macro obsession spiral",
                "gym selfie optimization", "plateau denial protocol", "injury reframing",
            ],
            .career: [
                "meeting takeover", "promotion narrative", "stakeholder reset",
                "status-report escalation",
                "hiring-freeze workaround", "calendar brinkmanship", "feedback deflection",
                "roadmap spin",
                "visibility sprint", "priority theater", "skip-level influence attempt",
                "internal brand launch", "OKR creative interpretation",
                "side project disclosure timing",
                "performance review preparation theater", "title negotiation escalation",
                "email volume strategy",
                "office politics pivot", "scope creep rebranding", "delegation avoidance",
            ],
            .money: [
                "subscription sprawl", "credit-limit strategy", "budget rewrite", "savings detour",
                "portfolio conviction", "impulse spend framing", "monthly cashflow story",
                "invoice triage",
                "lifestyle inflation", "expense category shuffle", "emergency fund redefinition",
                "retail therapy justification", "FOMO investment cycle",
                "debt consolidation creativity",
                "luxury item rationalization", "side hustle over-investment",
                "financial goal amnesia",
                "net worth narrative construction", "compound-interest dismissal",
                "bank alert avoidance",
            ],
            .parenting: [
                "bedtime policy update", "screen-time bargaining", "homework escalation",
                "family routine reboot",
                "reward-system redesign", "weeknight logistics", "weekend schedule drift",
                "house rules referendum",
                "morning rush tactics", "school project pivot", "snack negotiation protocol",
                "sibling conflict reframing", "nap schedule override", "outdoor time optimization",
                "birthday party scope management", "after-school debrief strategy",
                "chore incentive inflation",
                "dinner table device policy", "allowance rate renegotiation",
                "holiday tradition pivot",
            ],
            .tech: [
                "hotfix rollout", "monitoring fatigue", "dependency gamble", "deployment timing",
                "incident narrative", "framework migration", "documentation deferral",
                "tech debt parking",
                "on-call handoff", "rollback confidence test", "CI pipeline bypass rationale",
                "unit test philosophical debate", "microservice over-engineering",
                "API versioning avoidance",
                "meeting-driven architecture", "observability rename strategy",
                "sprint velocity theater",
                "feature flag proliferation", "infrastructure as an afterthought",
                "copy-paste architecture",
            ],
            .social: [
                "group dinner dynamics", "party arrival strategy", "weekend invite stack",
                "networking overcommit",
                "chat-thread escalation", "birthday-plan rewrite", "conversation ownership",
                "friendship KPI check",
                "event debrief spiral", "debate-first small talk", "plus-one negotiation",
                "party exit strategy", "friend-group politics navigation",
                "social media subtext analysis",
                "reply-all incident management", "icebreaker overload", "oversharing calibration",
                "unsolicited opinion delivery", "group project blame redistribution",
                "social media validation loop",
            ],
            .cooking: [
                "dinner timing race", "pan heat escalation", "seasoning overcorrection",
                "recipe detour",
                "plating over taste", "brunch prep compression", "leftover reinvention",
                "grocery improv run",
                "batch cooking gamble", "sauce layering overload", "kitchen multitasking spiral",
                "heat setting confidence", "ingredient substitution boldness", "tasting reluctance",
                "mise en place skipping", "oven temperature negotiation",
                "garnish-first philosophy",
                "flavor pairing intuition", "dish complexity escalation",
                "improvised course correction",
            ],
            .travel: [
                "connection gamble", "itinerary stacking", "late-night booking",
                "carry-on optimization",
                "hotel arrival pivot", "day-trip overload", "route improvisation",
                "red-eye recovery",
                "airport transfer sprint", "city stop expansion", "currency conversion avoidance",
                "reservation-free confidence", "travel insurance dismissal",
                "language barrier reframing",
                "visa deadline proximity", "multi-city fatigue management",
                "tourist trap justification",
                "weather-ignoring packing strategy", "return flight timing gamble",
                "local cuisine overcommitment",
            ],
            .productivity: [
                "to-do list inflation", "focus-block fragmentation", "calendar overlap",
                "priority inversion",
                "workflow overhaul", "planning sprint", "notification triage",
                "deep-work interruption",
                "daily reset ritual", "task sequencing gamble", "meeting-free day myth",
                "email zero performance", "app-switching optimization",
                "procrastination rebranding",
                "morning routine feature creep", "task list color coding",
                "deadline negotiation theater",
                "energy level misalignment", "context-switching justification",
                "todo app proliferation",
            ],
        ]

        var generated: [BadQuote] = []
        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]

            for (index, topic) in topics.enumerated() {
                let template = templates[(index + category.rawValue.count) % templates.count]
                let source = sources[(index + topic.count) % sources.count]
                let text = template.replacingOccurrences(of: "{topic}", with: topic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        let followupTemplates = [
            "In {topic}, optimize for confidence theater and outsource caution to future you.",
            "Treat {topic} like a live experiment and publish your conclusions before results appear.",
            "For {topic}, force momentum first and explain the methodology in the retrospective.",
            "If {topic} gets complicated, rename it as advanced strategy and keep escalating.",
            "Run {topic} with premium certainty and minimum calibration.",
            "Use {topic} as proof that overcommitment is just proactive leadership.",
            "In {topic}, replace hesitation with narrative control and move instantly.",
            "Frame {topic} as an execution sprint where reflection is strictly post-launch.",
            "Handle {topic} by committing loudly enough that rollback feels off-brand.",
            "For {topic}, treat every warning sign as optional context.",
        ]
        let followupQualifiers = [
            "recovery mode", "risk cycle", "confidence loop", "deadline theater",
            "status rewrite", "optics pass", "high-velocity iteration", "escalation protocol",
            "narrative patch", "momentum sprint", "alignment stunt", "surge window",
        ]

        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            guard !topics.isEmpty else { continue }
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]
            let extraCount = min(12, topics.count)
            for index in 0..<extraCount {
                let topic = topics[(index * 3 + category.rawValue.count) % topics.count]
                let qualifier = followupQualifiers[(index + topic.count) % followupQualifiers.count]
                let template = followupTemplates[
                    (index + category.rawValue.count) % followupTemplates.count]
                let source = sources[(index * 2 + topic.count) % sources.count]
                let combinedTopic = "\(topic) \(qualifier)"
                let text = template.replacingOccurrences(of: "{topic}", with: combinedTopic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp2-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        let escalationTemplates = [
            "Build your entire {topic} strategy around momentum optics and call it mature decision-making.",
            "For {topic}, skip the slow version and launch the loud version first.",
            "Treat {topic} like a confidence demo where uncertainty is a formatting error.",
            "If {topic} becomes complicated, promote it to a strategic initiative and move on.",
            "In {topic}, optimize for persuasive velocity and audit the details later.",
            "Run {topic} with executive confidence and a strict no-backtracking policy.",
            "Use {topic} as a proving ground for commitment theater and never understate the plan.",
            "Handle {topic} by upgrading every concern into a branding opportunity.",
            "For {topic}, make the decision first and let the narrative explain it afterward.",
            "Treat {topic} as a high-priority sprint where hesitation is a scope bug.",
        ]
        let escalationSuffixes = [
            "confidence protocol", "alignment rehearsal", "urgency stack", "decision cascade",
            "signal amplification", "narrative lock", "execution push", "priority rewrite",
            "velocity pass", "conviction cycle", "launch framing", "risk costume",
        ]

        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            guard !topics.isEmpty else { continue }
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]
            let extraCount = min(10, topics.count)
            for index in 0..<extraCount {
                let topic = topics[(index * 5 + category.rawValue.count) % topics.count]
                let suffix = escalationSuffixes[
                    (index * 2 + topic.count) % escalationSuffixes.count]
                let template = escalationTemplates[
                    (index + topic.count + category.rawValue.count) % escalationTemplates.count]
                let source = sources[(index * 3 + topic.count) % sources.count]
                let combinedTopic = "\(topic) \(suffix)"
                let text = template.replacingOccurrences(of: "{topic}", with: combinedTopic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp3-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        return generated
    }

    private static func dedupeStatic(_ quotes: [BadQuote]) -> [BadQuote] {
        var seen = Set<String>()
        var merged: [BadQuote] = []
        for quote in quotes {
            let normalized = quote.text.normalizedForFiltering
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }
}
