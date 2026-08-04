import Combine
import Foundation
import Observation
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.worstadvice.app", category: "state")

private enum AppleOnDeviceGenerationError: Error, Equatable {
    case timedOut
}

@MainActor
@Observable
final class GenerateViewModel {
    struct LocalTasteSummary: Sendable {
        let signalCount: Int
        let favoriteCategory: AdviceCategory?
        let favoriteTone: ToneMode?

        var title: String {
            guard signalCount >= 5 else { return "Taste profile warming up" }
            return "Your bureau is learning"
        }

        var detail: String {
            guard signalCount >= 5 else {
                return "Saves, votes, shares, skips, and rerolls tune local ranking on this device."
            }
            let category = favoriteCategory?.title ?? "mixed lanes"
            let tone = favoriteTone?.voice.name ?? "mixed voices"
            return "Currently leaning toward \(category) with \(tone). \(signalCount) private signals, zero account upload."
        }
    }

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

    struct ChaosMissionState: Sendable {
        let key: String
        let category: AdviceCategory
        let tone: ToneMode
        let targetCount: Int
        let currentCount: Int
        let title: String
        let subtitle: String

        var isComplete: Bool {
            currentCount >= targetCount
        }

        var progressFraction: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    struct WeeklyMissionState: Sendable {
        let key: String
        let category: AdviceCategory
        let tone: ToneMode
        let targetCount: Int
        let currentCount: Int
        let title: String
        let subtitle: String
        let rewardClaimed: Bool

        var isComplete: Bool {
            currentCount >= targetCount
        }

        var progressFraction: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    struct ContractMissionState: Sendable {
        let key: String
        let contractID: String
        let currentCount: Int
        let targetCount: Int
        let isActive: Bool
        let rewardClaimed: Bool

        var isComplete: Bool {
            currentCount >= targetCount
        }

        var progressFraction: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    private let repository: AdviceRepository
    private let settingsViewModel: SettingsViewModel
    private let store: AdviceStore
    private let engine: AdviceEngine
    private let bureauEngine: BureauAdviceEngine
    private let appleOnDeviceBridge: AppleOnDeviceAdviceBridge
    private let badQuoteService: BadQuoteService
    private let moderation: ContentModeration
    private let analyticsTracker: AnalyticsTracking
    private let achievementsManager: AchievementsManager
    private let liveActivityManager: LiveActivityManager

    var selectedCategory: AdviceCategory = .career
    var selectedTone: ToneMode = .corporateConsultant
    var scenarioText: String = ""
    var friendName: String = ""
    var current: AdviceRecord?
    var lastWhyTerrible: String = "Why this is awful: confidence is replacing good judgment."
    var generationNotice: String?
    var generationNoticeStyle: ToastStyle = .info
    var generationSourceBadgeText: String?
    var primaryActionTitle: String = "Advise Me"
    var hapticTrigger: Int = 0
    var hapticWeight: Double = 0.5  // 0.0 to 1.0 mapping to intensity
    var isGenerating: Bool = false
    var debugPolishFixturesStatus: String = "idle"
    /// Most recent take produced by a look-ahead `generate(isPrefetch: true)` call.
    /// The Wire reads this to append to its buffer; it is deliberately separate
    /// from `current`, which always tracks what a person is actually looking at.
    private(set) var lastPrefetchedRecord: AdviceRecord?

    var selectedIntensity: BadviceIntensity {
        get { settingsViewModel.preferredIntensity }
        set { settingsViewModel.preferredIntensity = newValue }
    }

    private var recentAdviceFingerprints: [String] = []
    private var recentAdviceFingerprintsByPool: [String: [String]] = [:]
    private var suggestionsVersion: Int = 0
    private var leaderboardVersion: Int = 0
    private var successfulGenerationCount: Int = 0
    @ObservationIgnored private var hasLoadedRecentSuggestions = false
    @ObservationIgnored private var hasBootstrappedAdviceExperience = false
    @ObservationIgnored private var automaticBootstrapSuppressedForStarter = false
    @ObservationIgnored private var adviceBootstrapTask: Task<Void, Never>?
    @ObservationIgnored private var autoGenerateSelectionTask: Task<Void, Never>?
    @ObservationIgnored private var cachedLocalTasteSummary: LocalTasteSummary?
    @ObservationIgnored private var lastCommittedImpressionID: UUID?
    private static let chaosMissionCompletionStorageKey = "chaosHubMissionCompletionKey"
    private static let activeChaosContractStorageKey = "activeChaosContractID"
    private static let chaosContractPeriod = "contract"
    private static let bootstrapGenerationNotice = "Warming up the advice engine..."
    private static let randomCompatibilityFloor = 0.75
    private struct RetentionSnapshot {
        let history: [AdviceRecord]
        let streakDays: Int
        let streakFreezeBonus: Int
    }
    private var retentionSnapshot: RetentionSnapshot?
    private var cachedDailyMissionState: ChaosMissionState?
    private var cachedWeeklyMissionState: WeeklyMissionState?
    private var cachedContractMissionStates: [String: ContractMissionState] = [:]

    /// Dynamically picks the ML weight profile based on accumulated signal richness.
    private var adaptiveRanker: AdaptiveRanker {
        let totalSignals = repository.totalLearningSignalCount()
        if totalSignals > 200 {
            return AdaptiveRanker(profile: .converged)
        } else if totalSignals < 20 {
            return AdaptiveRanker(profile: .explorer)
        }
        return AdaptiveRanker(profile: .balanced)
    }

    init(
        repository: AdviceRepository,
        settingsViewModel: SettingsViewModel,
        store: AdviceStore = AdviceStore(),
        badQuoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker(),
        achievementsManager: AchievementsManager,
        liveActivityManager: LiveActivityManager? = nil
    ) {
        self.repository = repository
        self.settingsViewModel = settingsViewModel
        self.store = store
        self.badQuoteService = badQuoteService
        self.moderation = moderation
        self.appleOnDeviceBridge = AppleOnDeviceAdviceBridge(moderation: moderation)
        self.engine = AdviceEngine(store: store, moderation: moderation)
        self.bureauEngine = BureauAdviceEngine(store: store, moderation: moderation)
        self.analyticsTracker = analyticsTracker
        self.achievementsManager = achievementsManager
        self.liveActivityManager = liveActivityManager ?? LiveActivityManager()
        repository.seedAdviceMemoryFromHistoryIfNeeded()
        self.current = repository.fetchHistory(limit: 1).first
        self.primaryActionTitle = Self.primaryActionTitles.first ?? "Advise Me"
        syncLiveActivityState()
    }

    @discardableResult
    func bootstrapAdviceExperienceIfNeeded(autoGenerateInitialAdvice: Bool) -> Bool {
        guard !hasBootstrappedAdviceExperience || current == nil else { return false }
        hasBootstrappedAdviceExperience = true

        let currentCategory = selectedCategory
        let currentTone = selectedTone
        let shouldAutoGenerate = autoGenerateInitialAdvice
            && current == nil
            && !isGenerating
            && !automaticBootstrapSuppressedForStarter
        let bootSeed = Int(Date().timeIntervalSince1970 * 1_000)
        let preferredContentPack = settingsViewModel.preferredContentPack
        let preferredGenerationProvider = settingsViewModel.preferredGenerationProvider
        let shouldPrewarmScorer = preferredGenerationProvider == .appleOnDevice

        _ = store.rules(for: currentCategory, contentPack: preferredContentPack)
        _ = store.profile(for: currentTone)
        _ = store.toneDirectiveVocabulary(for: currentTone)
        _ = store.categoryDirectiveVocabulary(for: currentCategory)

        adviceBootstrapTask?.cancel()
        if shouldAutoGenerate {
            isGenerating = true
            generationNotice = Self.bootstrapGenerationNotice
            generationNoticeStyle = .info
        }
        // The initial take is visible, user-facing launch work. Keeping this task at
        // utility priority allowed it to be starved by model warmups and other
        // background work during busy launches.
        adviceBootstrapTask = Task(priority: .userInitiated) { [weak self] in
            async let scorerWarmup: Void = shouldPrewarmScorer
            ? SemanticTextScorer.shared.prewarm()
            : ()

            guard let self else {
                _ = await scorerWarmup
                return
            }

            let modelWarmupTask: Task<Void, Never>? =
                preferredGenerationProvider == .appleOnDevice
                ? Task(priority: .utility) { [weak self] in
                    await self?.prepareLocalModelForBootstrap()
                }
                : nil

            if Task.isCancelled {
                self.clearBootstrapGenerationState()
                _ = await scorerWarmup
                if let modelWarmupTask {
                    await modelWarmupTask.value
                }
                return
            }

            if shouldAutoGenerate, self.current == nil {
                await self.generate(seed: bootSeed, isBootstrap: true)
            } else if shouldAutoGenerate {
                self.clearBootstrapGenerationState()
            }

            _ = await scorerWarmup
            if let modelWarmupTask {
                await modelWarmupTask.value
            }
        }
        return shouldAutoGenerate
    }

    func updateCategory(_ category: AdviceCategory, autoGenerate: Bool = true) {
        updateSelections(category: category, tone: selectedTone, autoGenerate: autoGenerate)
    }

    func updateTone(_ tone: ToneMode, autoGenerate: Bool = true) {
        updateSelections(category: selectedCategory, tone: tone, autoGenerate: autoGenerate)
    }

    func updateSelections(category: AdviceCategory, tone: ToneMode, autoGenerate: Bool = true) {
        let didChange = selectedCategory != category || selectedTone != tone
        guard didChange else { return }

        selectedCategory = category
        selectedTone = tone
        guard autoGenerate else { return }
        requestAutoGenerateAfterSelectionChange()
    }

    /// Starts a new, visible brief from another part of the app.
    ///
    /// The previous result remains persisted in history/favorites, but it is
    /// removed from the active workspace so the destination cannot look like
    /// the handoff failed. The user lands on the selected lane, voice, and
    /// context with an explicit next step instead of a stale result card.
    func prepareStarter(
        category: AdviceCategory,
        tone: ToneMode,
        prompt: String = "",
        source: String = "Starter"
    ) {
        adviceBootstrapTask?.cancel()
        autoGenerateSelectionTask?.cancel()
        automaticBootstrapSuppressedForStarter = true
        selectedCategory = category
        selectedTone = tone
        scenarioText = prompt
        current = nil
        generationSourceBadgeText = nil
        generationNotice = "\(source) loaded. Generate when ready."
        generationNoticeStyle = .success
        analyticsTracker.track(
            "prepare_starter",
            properties: [
                "source": source,
                "category": category.rawValue,
                "tone": tone.rawValue,
                "has_prompt": prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "false" : "true",
            ])
    }

    func requestAutoGenerateAfterSelectionChange(delayMilliseconds: UInt64 = 220) {
        autoGenerateSelectionTask?.cancel()
        let requestedCategory = selectedCategory
        let requestedTone = selectedTone

        autoGenerateSelectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(delayMilliseconds))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            guard self.selectedCategory == requestedCategory, self.selectedTone == requestedTone else {
                return
            }

            if self.isGenerating {
                await MainActor.run {
                    self.requestAutoGenerateAfterSelectionChange(delayMilliseconds: 300)
                }
                return
            }

            await self.generate()
        }
    }

    private func clearBootstrapGenerationState() {
        isGenerating = false
        if generationNotice == Self.bootstrapGenerationNotice {
            generationNotice = nil
        }
    }

    private func prepareLocalModelForBootstrap() async {
        await settingsViewModel.prepareAppleLocalModelForLaunchIfNeeded(
            systemMaxPollCount: 2,
            systemPollDelay: .milliseconds(250)
        )
    }

    func bootstrapCurrentAdviceIfNeeded(seed: Int) async {
        guard current == nil, !isGenerating else { return }
        await generate(seed: seed, isBootstrap: true)
    }

    /// Generates a take.
    ///
    /// - Parameter isPrefetch: Set when the result is being produced ahead of
    ///   time for The Wire's look-ahead buffer. Prefetched takes are persisted
    ///   like any other, but every side effect that means "a person saw this"
    ///   — learning signals, achievements, missions, haptics, analytics — is
    ///   deferred until ``commitImpression(for:)`` fires as the card scrolls
    ///   into view. Without this split, a two-ahead buffer would award progress
    ///   for advice nobody ever read.
    func generate(
        seed: Int? = nil,
        isBootstrap: Bool = false,
        revision: AdviceRevisionStyle? = nil,
        forceBureau: Bool = false,
        isPrefetch: Bool = false
    ) async {
        let generationPerfToken = AppPerformanceInstrumentation.beginAdviceGenerationInterval()
        defer { AppPerformanceInstrumentation.endAdviceGenerationInterval(generationPerfToken) }
        isGenerating = true
        defer { isGenerating = false }
        generationNotice = nil
        generationNoticeStyle = .info
        generationSourceBadgeText = nil
        let baseSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        if let current, !isPrefetch {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .regen
            )
        }

        let situation = preparedSituationText()
        let normalizedSituation = situation?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let blockingNotice = generationBlockingNotice(for: normalizedSituation) {
            generationNotice = blockingNotice
            generationNoticeStyle = .error
            return
        }
        let shouldEnforceGlobalUniqueness = settingsViewModel.strictNoRepeats
        let communityOnlyMode = forceBureau ? false : settingsViewModel.communityOnlyMode
        let selectedPack = settingsViewModel.preferredContentPack
        let requestedGenerationProvider = settingsViewModel.preferredGenerationProvider
        // `.auto` is retained for persisted backwards compatibility, but now resolves to
        // the deterministic local engine. A language model is used only after the person
        // explicitly selects Apple Intelligence in Settings.
        let generationProvider: AdviceGenerationProvider =
            !forceBureau && requestedGenerationProvider == .appleOnDevice ? .appleOnDevice : .classic
        if generationProvider != .classic {
            let availability = AppleOnDeviceAdviceBridge.currentAvailability()
            analyticsTracker.track(
                "apple_model_availability",
                properties: [
                    "requested_provider": requestedGenerationProvider.rawValue,
                    "effective_provider": generationProvider.rawValue,
                    "status": availability.analyticsKey,
                ])
        }
        let learningContext = adviceLearningContext()
        let resolvedCategory = resolveCategory(
            seed: baseSeed, context: learningContext, situation: situation ?? "",
            contentPack: selectedPack,
            preferredTone: selectedTone == .random ? nil : selectedTone
        )
        let resolvedTone = resolveTone(
            seed: baseSeed,
            context: learningContext,
            category: resolvedCategory
        )
        logger.debug(
            "Generate started: category=\(self.selectedCategory.rawValue) resolved=\(resolvedCategory.rawValue) tone=\(self.selectedTone.rawValue) resolvedTone=\(resolvedTone.rawValue) seed=\(baseSeed)"
        )
        if communityOnlyMode,
           (await suggestionCandidates(for: resolvedCategory, situation: situation)).isEmpty {
            generationNotice =
                "Community-only mode is on. Add suggestions in Settings > Suggestion Lab."
            generationNoticeStyle = .error
            analyticsTracker.track(
                "generate_blocked",
                properties: [
                    "reason": "no_community_suggestions",
                    "category": resolvedCategory.rawValue,
                    "selected_category": selectedCategory.rawValue,
                ])
            return
        }

        if !communityOnlyMode, isBootstrap, generationProvider != .appleOnDevice {
            let output = bureauEngine.generate(
                category: resolvedCategory,
                tone: resolvedTone,
                includeRationale: settingsViewModel.includeRationale,
                contentPack: selectedPack,
                situation: situation,
                intensity: selectedIntensity,
                revision: revision,
                seed: baseSeed,
                now: Date()
            )
            rememberFingerprint(for: output)
            rememberPoolFingerprint(for: output)
            generationSourceBadgeText = generationSourceBadgeLabel(for: "bureau")
            lastWhyTerrible = whyTerribleLine(for: output.category, contentPack: selectedPack)
            current = repository.insert(output)
            invalidateRetentionSnapshot()
            NotificationManager.updateGenerationActivity(date: output.createdAt)
            NotificationManager.scheduleDaily()
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: output.category, tone: output.tone),
                type: .shown
            )
            cachedLocalTasteSummary = nil
            leaderboardVersion += 1
            return
        }

        let suggestionPool = await suggestionCandidates(for: resolvedCategory, situation: situation)
        let normalizedSituationForRanking = normalizedSituation
        let hasSituationContext = (normalizedSituationForRanking?.isEmpty == false)

        let semanticScorer = SemanticTextScorer.shared
        let preparedQuery =
            hasSituationContext && generationProvider == .appleOnDevice
            ? await semanticScorer.preparedQuery(from: normalizedSituationForRanking ?? "")
            : nil

        var candidatePool: [(candidate: GeneratedAdvice, source: String)] = []
        var generationProviderNotice: String?
        if !communityOnlyMode {
            var appleCandidates: [GeneratedAdvice] = []
            if generationProvider != .classic {
                let appleBatch = await appleOnDeviceCandidateBatch(
                    category: resolvedCategory,
                    tone: resolvedTone,
                    situation: situation,
                    includeRationale: settingsViewModel.includeRationale,
                    baseSeed: baseSeed,
                    maxCount: generationProvider == .appleOnDevice ? 2 : 1,
                    requestedProvider: generationProvider
                )
                appleCandidates = appleBatch.candidates
                generationProviderNotice = appleBatch.notice
                if let fallbackReason = appleBatch.fallbackReason {
                    analyticsTracker.track(
                        "apple_model_fallback",
                        properties: [
                            "requested_provider": generationProvider.rawValue,
                            "reason": fallbackReason,
                            "category": resolvedCategory.rawValue,
                            "tone": resolvedTone.rawValue,
                        ])
                }
                candidatePool.append(contentsOf: appleCandidates.map { ($0, "apple_on_device") })
            }

            let shouldUseClassicEngines =
                generationProvider != .appleOnDevice || appleCandidates.isEmpty
            if shouldUseClassicEngines {
                let bureauCandidates = bureauEngine.generateCandidates(
                    category: resolvedCategory,
                    tone: resolvedTone,
                    includeRationale: settingsViewModel.includeRationale,
                    contentPack: selectedPack,
                    situation: situation,
                    intensity: selectedIntensity,
                    revision: revision,
                    seed: baseSeed,
                    count: shouldEnforceGlobalUniqueness
                        ? (hasSituationContext ? 9 : 7)
                        : (hasSituationContext ? 7 : 5)
                )
                candidatePool.append(contentsOf: bureauCandidates.map { ($0, "bureau") })
            }
        }

        let communityCandidates = communityCandidates(
            from: suggestionPool,
            tone: resolvedTone,
            baseSeed: baseSeed,
            maxCount: shouldEnforceGlobalUniqueness
                ? (hasSituationContext ? 8 : 6)
                : (hasSituationContext ? 5 : 4)
        )
        candidatePool.append(contentsOf: communityCandidates.map { ($0, "community") })

        guard !candidatePool.isEmpty else {
            generationNotice = "Community suggestions were filtered by safety checks."
            generationNoticeStyle = .error
            analyticsTracker.track(
                "generate_blocked",
                properties: [
                    "reason": "community_candidates_filtered",
                    "category": resolvedCategory.rawValue,
                    "selected_category": selectedCategory.rawValue,
                ])
            return
        }

        let recentFingerprintSet = Set(recentAdviceFingerprints)
        let recentPoolFingerprintSets = recentAdviceFingerprintsByPool.mapValues(Set.init)
        let semanticScoresByCandidate: [Double]?
        if let preparedQuery {
            semanticScoresByCandidate = await semanticScorer.similarityScores(
                for: candidatePool.map { $0.candidate.adviceLine },
                to: preparedQuery
            )
        } else {
            semanticScoresByCandidate = nil
        }
        var ranked:
            [(
                candidate: GeneratedAdvice, source: String, score: Double, fingerprint: String,
                poolKey: String, seenHistorically: Bool
            )] = []
        var learningCacheByScope: [String: LearningStatSnapshot] = [:]
        // The profile is derived from the repository's aggregate learning cache. Resolve it
        // once per generation pass instead of once for every candidate in the ranking loop.
        let ranker = adaptiveRanker
        for (index, item) in candidatePool.enumerated() {
            let fingerprint = fingerprint(for: item.candidate)
            let candidatePoolKey = poolKey(
                category: item.candidate.category, tone: item.candidate.tone)
            let seenRecently =
                recentFingerprintSet.contains(fingerprint)
                || (recentPoolFingerprintSets[candidatePoolKey] ?? []).contains(fingerprint)
            let seenHistorically: Bool
            if shouldEnforceGlobalUniqueness {
                seenHistorically =
                    repository.hasSeenAdvice(fingerprint)
                    || repository.hasSeenAdviceInPool(
                        fingerprint,
                        category: item.candidate.category,
                        tone: item.candidate.tone
                    )
            } else {
                seenHistorically = false
            }
            let noveltyPenalty = (seenRecently || seenHistorically) ? 1.0 : 0.0

            let semanticRelevance: Double
            if let semanticScoresByCandidate, semanticScoresByCandidate.indices.contains(index) {
                semanticRelevance = semanticScoresByCandidate[index]
            } else {
                semanticRelevance = 0.5
            }
            let safetyScore = moderation.safetyScore(
                for: item.candidate.adviceLine + " " + (item.candidate.rationaleLine ?? ""))
            let safetyAdjustedRelevance = semanticRelevance * (0.85 + (safetyScore * 0.15))

            let adviceScope = adviceScopeKey(
                category: item.candidate.category, tone: item.candidate.tone)
            let learning: LearningStatSnapshot
            if let cached = learningCacheByScope[adviceScope] {
                learning = cached
            } else {
                let snapshot = repository.learningSnapshot(for: adviceScope)
                learningCacheByScope[adviceScope] = snapshot
                learning = snapshot
            }
            let blendedLearning = blendedAdviceLearningSnapshot(
                exact: learning,
                category: item.candidate.category,
                tone: item.candidate.tone,
                context: learningContext
            )
            let sourceBias = sourcePreferenceBias(
                source: item.source,
                contentPack: selectedPack,
                requestedProvider: generationProvider
            )
            let score = ranker.adviceScore(
                semanticRelevance: safetyAdjustedRelevance,
                stats: blendedLearning,
                noveltyPenalty: noveltyPenalty,
                seed: baseSeed,
                candidateIndex: index
            ) + sourceBias
            ranked.append(
                (
                    item.candidate, item.source, score, fingerprint, candidatePoolKey,
                    seenHistorically
                ))
        }

        ranked.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.adviceLine.localizedCaseInsensitiveCompare(
                    rhs.candidate.adviceLine) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        var chosen: (candidate: GeneratedAdvice, source: String, seenHistorically: Bool)?
        for rankedCandidate in ranked {
            let alreadySeen =
                recentFingerprintSet.contains(rankedCandidate.fingerprint)
                || (recentPoolFingerprintSets[rankedCandidate.poolKey] ?? []).contains(
                    rankedCandidate.fingerprint)
                || (shouldEnforceGlobalUniqueness && rankedCandidate.seenHistorically)
            if !alreadySeen || !shouldEnforceGlobalUniqueness {
                chosen = (
                    rankedCandidate.candidate, rankedCandidate.source,
                    rankedCandidate.seenHistorically
                )
                break
            }
        }

        guard var output = chosen?.candidate ?? ranked.first?.candidate else {
            generationNotice = "Unable to rank candidates right now."
            generationNoticeStyle = .error
            return
        }
        let source = chosen?.source ?? ranked.first?.source ?? "engine"
        generationSourceBadgeText = generationSourceBadgeLabel(for: source)
        let outputSeenHistorically =
            chosen?.seenHistorically ?? ranked.first?.seenHistorically ?? false
        if shouldEnforceGlobalUniqueness, outputSeenHistorically {
            output = forceUniqueVariant(from: output)
        }

        rememberFingerprint(for: output)
        rememberPoolFingerprint(for: output)
        let inserted = repository.insert(output)
        invalidateRetentionSnapshot()
        if isPrefetch {
            lastPrefetchedRecord = inserted
        } else {
            lastWhyTerrible = whyTerribleLine(for: output.category, contentPack: selectedPack)
            current = inserted
            NotificationManager.updateGenerationActivity(date: output.createdAt)
            NotificationManager.scheduleDaily()
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: output.category, tone: output.tone),
                type: .shown
            )
        }
        cachedLocalTasteSummary = nil
        leaderboardVersion += 1

        if !isBootstrap, !isPrefetch {
            // Achievement Tracking
            let total = repository.historyCount()
            achievementsManager.trackAdviceGenerated(
                tone: output.tone, category: output.category, totalCount: total)
            achievementsManager.trackStreak(days: challengeStreakDays)

            analyticsTracker.track(
                "generate",
                properties: [
                    "category": output.category.rawValue,
                    "selected_category": selectedCategory.rawValue,
                    "resolved_category": resolvedCategory.rawValue,
                    "tone": output.tone.rawValue,
                    "selected_tone": selectedTone.rawValue,
                    "content_pack": selectedPack.rawValue,
                    "generation_provider": generationProvider.rawValue,
                    "source": source,
                    "intensity": "\(selectedIntensity.rawValue)",
                    "revision": revision?.rawValue ?? "original",
                    "has_situation": situation == nil ? "false" : "true",
                    "strict_no_repeats": shouldEnforceGlobalUniqueness ? "true" : "false",
                    "community_only": communityOnlyMode ? "true" : "false",
                ])

            // Nuanced Haptics: Alpha Podcast/Crypto/Toxic get heavy kicks. Minimal/Monk get light taps.
            if let profile = self.store.toneProfiles[output.tone] {
                let intensity = profile.rhetoricalTick.count
                hapticWeight = Double(min(max(intensity, 1), 6)) / 6.0
            }
            hapticTrigger += 1
            trackMissionCompletionIfNeeded()
            trackWeeklyMissionProgressIfNeeded(category: output.category, tone: output.tone)
            trackActiveChaosContractProgressIfNeeded(category: output.category, tone: output.tone)
            rotatePrimaryActionTitleIfNeeded()
        }
        if let generationProviderNotice {
            appendGenerationNotice(generationProviderNotice)
        }
        syncLiveActivityState()
    }

    private func appleOnDeviceCandidateBatch(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        includeRationale: Bool,
        baseSeed: Int,
        maxCount: Int,
        requestedProvider: AdviceGenerationProvider
    ) async -> (candidates: [GeneratedAdvice], notice: String?, fallbackReason: String?) {
        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let requestedExplicitly = requestedProvider == .appleOnDevice
        switch settingsViewModel.appleLocalGenerationGate {
        case .ready(let modelID):
            if requestedProvider != .classic {
                analyticsTracker.track(
                    "apple_local_model_selected",
                    properties: [
                        "requested_provider": requestedProvider.rawValue,
                        "selected_model_id": modelID,
                    ])
            }
        case .unavailable(let reasonKey, let message, _, _):
            return (
                [],
                requestedExplicitly ? "\(message) Using classic generator." : nil,
                "selection_\(reasonKey)"
            )
        }
        guard availability.isReady else {
            return (
                [], requestedExplicitly ? availability.statusText : nil,
                "availability_\(availability.analyticsKey)"
            )
        }

        var candidates: [GeneratedAdvice] = []
        var seenFingerprints = Set<String>()
        let desiredCount = max(1, maxCount)

        for index in 0..<desiredCount {
            do {
                let candidate = try await appleOnDeviceCandidate(
                    category: category,
                    tone: tone,
                    situation: situation,
                    includeRationale: includeRationale,
                    seed: baseSeed + (index * 4_099),
                    now: Date(),
                    timeout: requestedExplicitly ? .seconds(8) : .seconds(4)
                )
                guard engine.validateOutput(candidate, for: category) else { continue }
                let fingerprint = candidate.adviceLine.normalizedForFiltering
                if seenFingerprints.insert(fingerprint).inserted {
                    candidates.append(candidate)
                }
            } catch {
                logger.error(
                    "Apple on-device generation failed: \(String(describing: error), privacy: .public)"
                )
                if requestedExplicitly, candidates.isEmpty {
                    let didTimeOut = (error as? AppleOnDeviceGenerationError) == .timedOut
                    return (
                        [],
                        didTimeOut
                            ? "Apple on-device generation took too long. Using classic generator."
                            : "Apple on-device generation failed. Using classic generator.",
                        didTimeOut ? "generation_timeout" : "generation_failed"
                    )
                }
                break
            }
        }

        if requestedExplicitly, candidates.isEmpty {
            return (
                [],
                "Apple on-device model is available, but no valid output was produced. Using classic generator.",
                "no_valid_output"
            )
        }

        if !requestedExplicitly, candidates.isEmpty {
            return ([], nil, "no_candidate_auto")
        }

        return (candidates, nil, nil)
    }

    private func appleOnDeviceCandidate(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        includeRationale: Bool,
        seed: Int,
        now: Date,
        timeout: Duration
    ) async throws -> GeneratedAdvice {
        try await withThrowingTaskGroup(of: GeneratedAdvice.self) { group in
            group.addTask { [appleOnDeviceBridge] in
                try await appleOnDeviceBridge.generateCandidate(
                    category: category,
                    tone: tone,
                    situation: situation,
                    includeRationale: includeRationale,
                    seed: seed,
                    now: now
                )
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AppleOnDeviceGenerationError.timedOut
            }

            guard let candidate = try await group.next() else {
                throw AppleOnDeviceGenerationError.timedOut
            }
            group.cancelAll()
            return candidate
        }
    }

    private func generationSourceBadgeLabel(for source: String) -> String? {
        // Default engine path is silent chrome — only non-default sources earn a badge.
        switch source {
        case "apple_on_device":
            return "On-Device"
        case "bureau", "engine":
            return nil
        case "ml_remix":
            return "Remix"
        case "community":
            return "Community"
        default:
            return source.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func sourcePreferenceBias(
        source: String,
        contentPack: ContentPack,
        requestedProvider: AdviceGenerationProvider
    ) -> Double {
        switch source {
        case "bureau":
            return contentPack == .classic ? 0.16 : 0.12
        case "engine":
            return contentPack == .classic ? 0.08 : 0.04
        case "ml_remix":
            return contentPack == .classic ? -0.05 : -0.01
        case "apple_on_device":
            return requestedProvider == .appleOnDevice ? 0.06 : 0.02
        case "community":
            return 0.01
        default:
            return 0
        }
    }

    func surpriseMeAndGenerate() {
        selectedCategory = AdviceCategory.allCases.randomElement() ?? .dating
        selectedTone = ToneMode.allCases.randomElement() ?? .corporateConsultant
        analyticsTracker.track(
            "surprise_me",
            properties: [
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
                "content_pack": settingsViewModel.preferredContentPack.rawValue,
            ])
        Task {
            await generate()
        }
    }

    /// Re-generates advice with the same category, tone, and scenario but a fresh seed —
    /// only the wording/framing changes.
    func remixCurrentAdvice() {
        guard current != nil, !isGenerating else { return }
        analyticsTracker.track(
            "remix_advice",
            properties: [
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
            ])
        Task {
            await generate(
                seed: Int(Date().timeIntervalSince1970 * 1_000) &+ Int.random(in: 1...9999))
        }
    }

    /// Applies a single local rewrite direction while preserving the current lane,
    /// voice, context, and persisted intensity. This intentionally bypasses the
    /// optional model provider so the control is instant and available offline.
    func reviseCurrentAdvice(_ revision: AdviceRevisionStyle) {
        guard current != nil, !isGenerating else { return }
        analyticsTracker.track(
            "revise_advice",
            properties: [
                "revision": revision.rawValue,
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
                "intensity": "\(selectedIntensity.rawValue)",
            ])
        Task {
            await generate(
                seed: Int(Date().timeIntervalSince1970 * 1_000) &+ stableSeed(for: revision.rawValue),
                revision: revision,
                forceBureau: true
            )
        }
    }

    func generateDailyDrop() {
        guard !isGenerating else { return }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let categories = AdviceCategory.concrete
        let tones = ToneMode.allCases
        selectedCategory = categories[day % categories.count]
        selectedTone = tones[(day * 3) % tones.count]
        analyticsTracker.track(
            "daily_drop",
            properties: [
                "day_of_year": "\(day)",
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
                "content_pack": settingsViewModel.preferredContentPack.rawValue,
            ])
        Task {
            await generate(seed: day * 1013)
        }
    }

    func runDailyMissionGeneration() {
        guard !isGenerating else { return }
        let mission = dailyMissionState
        selectedCategory = mission.category
        selectedTone = mission.tone
        scenarioText = ""
        Task {
            await generate(seed: stableSeed(for: mission.key))
        }
    }

    var activeChaosContractID: String? {
        UserDefaults.standard.string(forKey: Self.activeChaosContractStorageKey)
    }

    func contractMissionState(for contract: ChaosContract) -> ContractMissionState {
        if let cached = cachedContractMissionStates[contract.id] {
            return cached
        }
        let key = contractMissionKey(for: contract)
        let record = repository.ensureMissionProgress(
            missionKey: key,
            periodRaw: Self.chaosContractPeriod,
            category: contract.category ?? .random,
            tone: contract.tone ?? .random,
            targetCount: 1
        )
        let state = ContractMissionState(
            key: key,
            contractID: contract.id,
            currentCount: record.progressCount,
            targetCount: record.targetCount,
            isActive: activeChaosContractID == contract.id && !record.rewardClaimed,
            rewardClaimed: record.rewardClaimed
        )
        cachedContractMissionStates[contract.id] = state
        return state
    }

    func acceptChaosContract(_ contract: ChaosContract) {
        if let category = contract.category {
            selectedCategory = category
        }
        if let tone = contract.tone {
            selectedTone = tone
        }
        if let pack = contract.contentPack {
            settingsViewModel.preferredContentPack = pack
        }
        scenarioText = contract.description
        _ = repository.ensureMissionProgress(
            missionKey: contractMissionKey(for: contract),
            periodRaw: Self.chaosContractPeriod,
            category: contract.category ?? .random,
            tone: contract.tone ?? .random,
            targetCount: 1
        )
        UserDefaults.standard.set(contract.id, forKey: Self.activeChaosContractStorageKey)
        cachedContractMissionStates.removeValue(forKey: contract.id)
        generationNotice = "Contract accepted: \(contract.title). Generate once to claim \(contract.reward)."
        generationNoticeStyle = .success
        analyticsTracker.track(
            "chaos_contract_accept",
            properties: [
                "contract_id": contract.id,
                "category": (contract.category ?? .random).rawValue,
                "tone": (contract.tone ?? .random).rawValue,
            ])
    }

    func trackChaosHubOpened() {
        let mission = dailyMissionState
        analyticsTracker.track(
            "chaos_hub_open",
            properties: [
                "mission_key": mission.key,
                "mission_complete": mission.isComplete ? "true" : "false",
                "streak_days": "\(challengeStreakDays)",
            ])
    }

    func trackChaosHubAction(_ action: String) {
        analyticsTracker.track(
            "chaos_hub_action",
            properties: [
                "action": action,
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
            ])
    }

    func applySuggestion(_ suggestion: String) {
        scenarioText = suggestion
    }

    private func whyTerribleLine(for category: AdviceCategory, contentPack: ContentPack) -> String {
        let principle = store.rules(for: category, contentPack: contentPack)
            .badPrinciples.randomElement() ?? "certainty without evidence"
        return "Why this is awful: \(principle)."
    }

    /// Records that a person actually laid eyes on `record`.
    ///
    /// The Wire generates ahead of the scroll position, so the side effects that
    /// represent an impression are split out of `generate` and fired here as each
    /// card lands. Calling this twice for the same record is a no-op, which keeps
    /// scroll-position jitter from double-counting progress.
    func commitImpression(for record: AdviceRecord) {
        guard lastCommittedImpressionID != record.id else { return }
        lastCommittedImpressionID = record.id

        current = record
        lastWhyTerrible = whyTerribleLine(
            for: record.category,
            contentPack: settingsViewModel.preferredContentPack
        )
        NotificationManager.updateGenerationActivity(date: record.createdAt)
        NotificationManager.scheduleDaily()
        repository.recordLearningSignal(
            scopeKey: adviceScopeKey(category: record.category, tone: record.tone),
            type: .shown
        )
        cachedLocalTasteSummary = nil

        achievementsManager.trackAdviceGenerated(
            tone: record.tone,
            category: record.category,
            totalCount: repository.historyCount()
        )
        achievementsManager.trackStreak(days: challengeStreakDays)

        analyticsTracker.track(
            "generate",
            properties: [
                "category": record.category.rawValue,
                "tone": record.tone.rawValue,
                "surface": "wire",
                "intensity": "\(selectedIntensity.rawValue)",
            ])

        if let profile = store.toneProfiles[record.tone] {
            hapticWeight = Double(min(max(profile.rhetoricalTick.count, 1), 6)) / 6.0
        }
        hapticTrigger += 1
        trackMissionCompletionIfNeeded()
        trackWeeklyMissionProgressIfNeeded(category: record.category, tone: record.tone)
        trackActiveChaosContractProgressIfNeeded(category: record.category, tone: record.tone)
        rotatePrimaryActionTitleIfNeeded()
        syncLiveActivityState()
    }

    func toggleFavorite() {
        guard let current else { return }
        let newValue = !current.isFavorite
        repository.toggleFavorite(current)
        if newValue {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .favorite
            )
            achievementsManager.trackAdviceSaved(totalSaved: repository.favoriteCount())
        }
        cachedLocalTasteSummary = nil
        analyticsTracker.track(
            "toggle_favorite",
            properties: [
                "is_favorite": newValue ? "true" : "false"
            ])
        playHaptic(style: .light)
    }

    func toggleVote(_ vote: AdviceVoteState) {
        guard let current else { return }
        let next: AdviceVoteState = current.vote == vote ? .none : vote
        repository.setVote(current, vote: next)
        switch next {
        case .like:
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .like
            )
        case .dislike:
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .dislike
            )
        case .none:
            break
        }
        cachedLocalTasteSummary = nil
        leaderboardVersion += 1
        analyticsTracker.track(
            "advice_vote",
            properties: [
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
        guard !forbidden.contains(where: { normalizedCombined.contains($0.normalizedForFiltering) })
        else {
            return "Suggestion conflicts with safety constraints for this category."
        }

        _ = repository.addSuggestion(
            category: category,
            topic: String(trimmedTopic.prefix(72)),
            adviceLine: String(trimmedAdvice.prefix(220))
        )
        hasLoadedRecentSuggestions = true
        cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track(
            "suggestion_submit",
            properties: [
                "category": category.rawValue
            ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        repository.deleteSuggestion(suggestion)
        hasLoadedRecentSuggestions = true
        cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track("suggestion_delete", properties: [:])
    }

    func markFavorite() {
        guard let current else { return }
        let wasFavorite = current.isFavorite
        repository.setFavorite(current, isFavorite: true)
        if !wasFavorite {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .favorite
            )
            achievementsManager.trackAdviceSaved(totalSaved: repository.favoriteCount())
        }
        cachedLocalTasteSummary = nil
        analyticsTracker.track("save_from_generate", properties: [:])
        playHaptic(style: .light)
    }

    var isCurrentFavorite: Bool {
        current?.isFavorite ?? false
    }

    var currentVote: AdviceVoteState {
        current?.vote ?? .none
    }

    var currentRealityCheck: String? {
        guard let current else { return nil }
        return bureauEngine.realityCheck(
            category: current.category,
            situation: preparedSituationText(),
            seed: stableSeed(for: current.id.uuidString)
        )
    }

    var localTasteSummary: LocalTasteSummary {
        if let cachedLocalTasteSummary {
            return cachedLocalTasteSummary
        }

        let context = adviceLearningContext()
        let signalCount = repository.totalLearningSignalCount()
        let category = context.byCategory.max {
            preferenceWeight(for: $0.value) < preferenceWeight(for: $1.value)
        }?.key
        let tone = context.byTone.max {
            preferenceWeight(for: $0.value) < preferenceWeight(for: $1.value)
        }?.key
        let summary = LocalTasteSummary(
            signalCount: signalCount,
            favoriteCategory: category,
            favoriteTone: tone
        )
        cachedLocalTasteSummary = summary
        return summary
    }

    private var cachedRecentSuggestions: [UserAdviceSuggestion] = []

    var recentSuggestions: [UserAdviceSuggestion] {
        _ = hasLoadedRecentSuggestions
        _ = suggestionsVersion
        return cachedRecentSuggestions
    }

    func loadRecentSuggestionsIfNeeded() {
        guard !hasLoadedRecentSuggestions else { return }
        hasLoadedRecentSuggestions = true
        cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
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
        return
            grouped
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
            let summarySource = "\(current.adviceLine) \(rationale)"
            if let summary = summarize(text: summarySource, maxSentences: 2, maxCharacters: 180),
                summary.count < summarySource.count
            {
                return
                    "\(caption)\n\n\(current.adviceLine)\n\n\(rationale)\n\nTL;DR \(summary)\n\nBadvice"
            }
            return "\(caption)\n\n\(current.adviceLine)\n\n\(rationale)\n\nBadvice"
        }
        return "\(caption)\n\n\(current.adviceLine)\n\nBadvice"
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
            aspectRatio: settingsViewModel.preferredAspect,
            caseNumber: current.caseNumber
        )
    }

    var keywordSuggestions: [String] {
        let category: AdviceCategory
        if selectedCategory == .random {
            if let current {
                category = current.category
            } else {
                let seed = stableSeed(for: "\(scenarioText)|\(friendName)")
                category = selectedCategory.resolved(seed: seed)
            }
        } else {
            category = selectedCategory
        }
        return Array(
            store.rules(for: category, contentPack: settingsViewModel.preferredContentPack).keywords
                .prefix(4))
    }

    var dailyBadQuote: BadQuote {
        badQuoteService.quoteOfDay()
    }

    var dailyMissionState: ChaosMissionState {
        if let cachedDailyMissionState {
            return cachedDailyMissionState
        }
        let now = Date()
        let spec = DailyMissionSpec.current(for: now)
        let matchingCount = repository.todayHistoryCount(
            category: spec.category, tone: spec.tone, referenceDate: now)
        let title = "Daily Mission: \(spec.targetCount)x \(spec.tone.title)"
        let subtitle = "Run \(spec.category.title) chaos builds before midnight."
        let state = ChaosMissionState(
            key: spec.key,
            category: spec.category,
            tone: spec.tone,
            targetCount: spec.targetCount,
            currentCount: matchingCount,
            title: title,
            subtitle: subtitle
        )
        cachedDailyMissionState = state
        return state
    }

    var weeklyMissionState: WeeklyMissionState {
        if let cachedWeeklyMissionState {
            return cachedWeeklyMissionState
        }
        let state = weeklyMissionState(for: Date())
        cachedWeeklyMissionState = state
        return state
    }

    func weeklyMissionState(for referenceDate: Date) -> WeeklyMissionState {
        let calendar = Calendar.current
        let now = referenceDate
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        let missionCategory = categories[(week * 3) % categories.count]
        let missionTone = tones[(week * 7) % tones.count]
        let targetCount = 6 + (week % 4)
        let missionKey =
            "weekly-\(year)-\(week)-\(missionCategory.rawValue)-\(missionTone.rawValue)-\(targetCount)"
        let persisted = repository.ensureMissionProgress(
            missionKey: missionKey,
            periodRaw: "weekly",
            category: missionCategory,
            tone: missionTone,
            targetCount: targetCount
        )

        return WeeklyMissionState(
            key: missionKey,
            category: missionCategory,
            tone: missionTone,
            targetCount: targetCount,
            currentCount: persisted.progressCount,
            title: "Weekly Mission: \(targetCount)x \(missionTone.title)",
            subtitle: "Complete \(missionCategory.title) chaos runs before week reset.",
            rewardClaimed: persisted.rewardClaimed
        )
    }

    var weeklyMissionCompleted: Bool {
        weeklyMissionState.isComplete
    }

    func refreshRetentionStateOnAppear(referenceDate: Date = Date()) {
        invalidateRetentionSnapshot()
        applyStreakFreezeIfNeeded(referenceDate: referenceDate)
        invalidateRetentionSnapshot()
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: settingsViewModel.streakFreezeAvailableThisWeek)
        NotificationManager.scheduleDaily()
        syncLiveActivityState()
    }

    var dailyMissionTitle: String {
        dailyMissionState.title
    }

    var dailyMissionTargetCount: Int {
        dailyMissionState.targetCount
    }

    var dailyMissionCurrentCount: Int {
        dailyMissionState.currentCount
    }

    var dailyMissionCompleted: Bool {
        dailyMissionState.isComplete
    }

    var dailyMissionProgressFraction: Double {
        dailyMissionState.progressFraction
    }

    var chaosHubSummaryLine: String {
        let mission = dailyMissionState
        let weekly = weeklyMissionState
        let completed =
            mission.isComplete ? "complete" : "\(mission.currentCount)/\(mission.targetCount)"
        let weeklyCompleted =
            weekly.isComplete ? "done" : "\(weekly.currentCount)/\(weekly.targetCount)"
        return
            "Mission \(completed) • Weekly \(weeklyCompleted) • \(challengeStreakDays)-day streak • \(favoriteCount) saved"
    }

    var todayGeneratedCount: Int {
        repository.todayHistoryCount()
    }

    var totalGeneratedCount: Int {
        repository.historyCount()
    }

    var favoriteCount: Int {
        repository.favoriteCount()
    }

    /// A compact identity snapshot for the profile/recap surfaces. It is
    /// derived from the same local history that powers adaptive ranking, so it
    /// never invents a separate progression source or uploads private taste.
    var bureauIdentitySnapshot: BureauIdentitySnapshot {
        let history = repository.fetchAllHistory()
        let favoriteCategory = mostFrequentCategory(in: history)
        let favoriteTone = mostFrequentTone(in: history)
        return BureauIdentitySnapshot(
            archetype: BureauArchetype.resolve(category: favoriteCategory, tone: favoriteTone),
            favoriteCategory: favoriteCategory,
            favoriteTone: favoriteTone,
            currentRank: achievementsManager.bureauRank,
            bureauXP: achievementsManager.bureauXP,
            streakDays: challengeStreakDays,
            generatedCount: history.count,
            equippedCosmetic: achievementsManager.equippedBureauCosmetic
        )
    }

    var weeklyRecapSnapshot: WeeklyRecapSnapshot {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: calendar.startOfDay(for: Date()), duration: 7 * 86_400)
        let history = repository.fetchAllHistory().filter {
            $0.createdAt >= interval.start && $0.createdAt < interval.end
        }
        let sharedCount = history.reduce(into: 0) { result, record in
            result += record.shareCountValue
        }
        let highlight = history.max { lhs, rhs in
            if lhs.shareCountValue != rhs.shareCountValue {
                return lhs.shareCountValue < rhs.shareCountValue
            }
            return lhs.createdAt < rhs.createdAt
        }
        return WeeklyRecapSnapshot(
            weekStart: interval.start,
            generatedCount: history.count,
            savedCount: history.filter(\.isFavorite).count,
            sharedCount: sharedCount,
            streakDays: challengeStreakDays,
            topCategory: mostFrequentCategory(in: history),
            topTone: mostFrequentTone(in: history),
            highlightLine: highlight?.adviceLine
        )
    }

    /// Explore should feel alive for returning users without pretending that
    /// a local starter catalog is a live global trend feed.
    var exploreStarterIdeas: [TrendingAdvice] {
        repository.fetchAllHistory().prefix(20).map { record in
            TrendingAdvice(
                id: record.id,
                adviceLine: record.adviceLine,
                category: record.category,
                tone: record.tone,
                likeCount: record.vote == .like ? 1 : 0,
                shareCount: record.shareCountValue,
                generatedAt: record.createdAt
            )
        }
    }

    var challengeStreakDays: Int {
        let snapshot = currentRetentionSnapshot()
        return snapshot.streakDays + snapshot.streakFreezeBonus
    }

    private func mostFrequentCategory(in history: [AdviceRecord]) -> AdviceCategory? {
        Dictionary(grouping: history, by: \.category)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }

    private func mostFrequentTone(in history: [AdviceRecord]) -> ToneMode? {
        Dictionary(grouping: history, by: \.tone)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
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
        return
            "No-repeat mode: \(mode) • Global + category/tone pools • Pack: \(pack) • \(repository.seenAdviceCount()) unique lines served"
    }

    func trackShare(template: ShareCardTemplate, ratio: ShareAspectRatio) {
        if let current {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .share
            )
            repository.incrementShareCount(for: current.id)
            let totalShares = repository.fetchAllHistory().reduce(into: 0) { count, record in
                count += record.shareCountValue
            }
            achievementsManager.trackShare(totalShares: totalShares)
        }
        analyticsTracker.track(
            "share_card",
            properties: [
                "template": template.rawValue,
                "ratio": ratio.rawValue,
                "caption_preset": settingsViewModel.preferredSharePreset.rawValue,
            ])
    }

    func trackCopy() {
        if let current {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .copy
            )
            repository.incrementCopyCount(for: current.id)
        }
        analyticsTracker.track("copy_text", properties: [:])
    }

    // MARK: - Leaderboard

    var leaderboardTopShared: [AdviceRecord] { repository.topByShares(limit: 5) }
    var leaderboardTopCopied: [AdviceRecord] { repository.topByCopies(limit: 5) }
    var leaderboardTopLiked: [AdviceRecord] { repository.topByLikes(limit: 5) }
    var weeklyRecapFavorites: [AdviceRecord] { repository.thisWeekFavorites() }

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

    private func generationBlockingNotice(for normalizedSituation: String?) -> String? {
        if selectedTone == .friendRoast {
            let trimmedFriend = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedFriend.isEmpty {
                return "Friend roast needs a friend name to generate."
            }
        }

        let hasSituation = (normalizedSituation?.isEmpty == false)
        if hasSituation, let situation = normalizedSituation, situation.count > 1_200 {
            return "Please shorten the situation before generating."
        }

        if scenarioText.count > 3_000 {
            return "Please shorten the prompt before generating."
        }

        if selectedCategory == .random || selectedTone == .random {
            return nil
        }

        return nil
    }

    private func trackMissionCompletionIfNeeded() {
        let mission = dailyMissionState
        guard mission.isComplete else { return }
        let storageKey = Self.chaosMissionCompletionStorageKey
        if UserDefaults.standard.string(forKey: storageKey) == mission.key {
            return
        }
        UserDefaults.standard.set(mission.key, forKey: storageKey)
        analyticsTracker.track(
            "chaos_mission_complete",
            properties: [
                "mission_key": mission.key,
                "target": "\(mission.targetCount)",
                "category": mission.category.rawValue,
                "tone": mission.tone.rawValue,
            ])
    }

    private func trackWeeklyMissionProgressIfNeeded(category: AdviceCategory, tone: ToneMode) {
        let mission = weeklyMissionState
        guard category == mission.category, tone == mission.tone else { return }

        let before = repository.ensureMissionProgress(
            missionKey: mission.key,
            periodRaw: "weekly",
            category: mission.category,
            tone: mission.tone,
            targetCount: mission.targetCount
        )
        let previousCount = before.progressCount
        let updated = repository.incrementMissionProgress(
            missionKey: mission.key,
            periodRaw: "weekly",
            category: mission.category,
            tone: mission.tone,
            targetCount: mission.targetCount,
            by: 1
        )
        cachedWeeklyMissionState = nil

        guard previousCount < mission.targetCount, updated.progressCount >= mission.targetCount
        else { return }
        guard !updated.rewardClaimed else { return }

        repository.markMissionRewardClaimed(missionKey: mission.key)
        generationNotice = "Weekly mission complete. Reward unlocked: \(ThemeMode.cosmic.title)."
        generationNoticeStyle = .success
        if settingsViewModel.theme != .cosmic {
            settingsViewModel.theme = .cosmic
        }
        analyticsTracker.track(
            "weekly_mission_complete",
            properties: [
                "mission_key": mission.key,
                "category": mission.category.rawValue,
                "tone": mission.tone.rawValue,
                "target": "\(mission.targetCount)",
            ])
    }

    private func trackActiveChaosContractProgressIfNeeded(category: AdviceCategory, tone: ToneMode) {
        guard let activeID = activeChaosContractID else { return }
        guard let contract = ChaosContract.catalog.first(where: { $0.id == activeID }) else {
            UserDefaults.standard.removeObject(forKey: Self.activeChaosContractStorageKey)
            return
        }
        if let required = contract.category, category != required {
            return
        }
        if let required = contract.tone, tone != required {
            return
        }

        let key = contractMissionKey(for: contract)
        let before = repository.ensureMissionProgress(
            missionKey: key,
            periodRaw: Self.chaosContractPeriod,
            category: contract.category ?? category,
            tone: contract.tone ?? tone,
            targetCount: 1
        )
        guard before.progressCount < before.targetCount else {
            UserDefaults.standard.removeObject(forKey: Self.activeChaosContractStorageKey)
            return
        }

        let updated = repository.incrementMissionProgress(
            missionKey: key,
            periodRaw: Self.chaosContractPeriod,
            category: contract.category ?? category,
            tone: contract.tone ?? tone,
            targetCount: 1
        )
        guard updated.progressCount >= updated.targetCount else { return }

        repository.markMissionRewardClaimed(missionKey: key)
        UserDefaults.standard.removeObject(forKey: Self.activeChaosContractStorageKey)
        appendGenerationNotice("Contract complete. Reward unlocked: \(contract.reward).")
        analyticsTracker.track(
            "chaos_contract_complete",
            properties: [
                "contract_id": contract.id,
                "category": category.rawValue,
                "tone": tone.rawValue,
                "reward": contract.reward,
            ])
    }

    private func contractMissionKey(for contract: ChaosContract) -> String {
        "chaos-contract-\(contract.id)"
    }

    private func appendGenerationNotice(_ message: String) {
        guard !message.isEmpty else { return }
        if let existing = generationNotice, !existing.isEmpty {
            generationNotice = "\(existing) \(message)"
        } else {
            generationNotice = message
        }
        generationNoticeStyle = .info
    }

    private func applyStreakFreezeIfNeeded(referenceDate: Date) {
        let calendar = Calendar.current
        let history = repository.fetchAllHistory()
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let hasToday = days.contains(today)
        let hasYesterday = days.contains(yesterday)
        guard !hasToday, hasYesterday else { return }

        if settingsViewModel.isStreakFreezeActive(for: today) {
            return
        }
        guard settingsViewModel.consumeStreakFreezeIfAvailable(for: today) else { return }

        generationNotice = "Streak Freeze activated. Your streak is protected for today."
        generationNoticeStyle = .success
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: settingsViewModel.streakFreezeAvailableThisWeek)
        analyticsTracker.track(
            "streak_freeze_used",
            properties: [
                "day": "\(today.timeIntervalSince1970)"
            ])
    }

    private func stableSeed(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 16_777_619) ^ Int(scalar.value)
        }
    }

    func invalidateRetentionSnapshot() {
        retentionSnapshot = nil
        cachedDailyMissionState = nil
        cachedWeeklyMissionState = nil
        cachedContractMissionStates.removeAll()
    }

    private func syncLiveActivityState() {
        let mission = dailyMissionState
        let streakDays = challengeStreakDays

        if streakDays <= 0 && mission.currentCount <= 0 {
            liveActivityManager.endStreakActivity()
            return
        }

        if liveActivityManager.isActivityActive {
            liveActivityManager.updateStreakActivity(
                streakDays: streakDays,
                challengeTitle: mission.title,
                current: mission.currentCount,
                target: mission.targetCount,
                isComplete: mission.isComplete
            )
        } else {
            liveActivityManager.startStreakActivity(
                streakDays: streakDays,
                challengeTitle: mission.title,
                current: mission.currentCount,
                target: mission.targetCount
            )
        }
    }

    private func currentRetentionSnapshot() -> RetentionSnapshot {
        if let retentionSnapshot {
            return retentionSnapshot
        }
        let snapshot = computeRetentionSnapshot()
        retentionSnapshot = snapshot
        return snapshot
    }

    private func computeRetentionSnapshot() -> RetentionSnapshot {
        let history = repository.fetchAllHistory()
        return RetentionSnapshot(
            history: history,
            streakDays: streakDays(history: history),
            streakFreezeBonus: streakFreezeBonus(history: history)
        )
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
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            if days.contains(previousDay) {
                streak += 1
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }

    private func streakFreezeBonus(history: [AdviceRecord], referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard settingsViewModel.isStreakFreezeActive(for: today) else { return 0 }
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.contains(today) else { return 0 }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return days.contains(yesterday) ? 1 : 0
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
        let recentSet = Set(recentAdviceFingerprints)
        let key = poolKey(category: base.category, tone: base.tone)
        let recentPoolSet = Set(recentAdviceFingerprintsByPool[key] ?? [])
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
            if !recentSet.contains(updatedFingerprint)
                && !recentPoolSet.contains(updatedFingerprint)
                && !repository.hasSeenAdvice(updatedFingerprint)
                && !repository.hasSeenAdviceInPool(
                    updatedFingerprint,
                    category: updated.category,
                    tone: updated.tone
                )
            {
                return updated
            }
            serial += 1
        }
    }

    private struct AdviceLearningContext {
        let byCategory: [AdviceCategory: LearningStatSnapshot]
        let byTone: [ToneMode: LearningStatSnapshot]
        let global: LearningStatSnapshot
    }

    private struct LearningAccumulator {
        var shownCount: Double = 0
        var likeCount: Double = 0
        var dislikeCount: Double = 0
        var favoriteCount: Double = 0
        var copyCount: Double = 0
        var shareCount: Double = 0
        var regenCount: Double = 0
        var lastUpdatedAt: Date?

        mutating func include(_ snapshot: LearningStatSnapshot) {
            shownCount += snapshot.shownCount
            likeCount += snapshot.likeCount
            dislikeCount += snapshot.dislikeCount
            favoriteCount += snapshot.favoriteCount
            copyCount += snapshot.copyCount
            shareCount += snapshot.shareCount
            regenCount += snapshot.regenCount
            if let timestamp = snapshot.lastUpdatedAt {
                if let current = lastUpdatedAt {
                    if timestamp > current {
                        lastUpdatedAt = timestamp
                    }
                } else {
                    lastUpdatedAt = timestamp
                }
            }
        }

        var snapshot: LearningStatSnapshot {
            LearningStatSnapshot(
                shownCount: shownCount,
                likeCount: likeCount,
                dislikeCount: dislikeCount,
                favoriteCount: favoriteCount,
                copyCount: copyCount,
                shareCount: shareCount,
                regenCount: regenCount,
                lastUpdatedAt: lastUpdatedAt
            )
        }
    }

    private func adviceLearningContext() -> AdviceLearningContext {
        let stats = repository.learningStats(prefix: "advice|")
        var categoryAccumulators: [AdviceCategory: LearningAccumulator] = [:]
        var toneAccumulators: [ToneMode: LearningAccumulator] = [:]
        var globalAccumulator = LearningAccumulator()

        for stat in stats {
            let parts = stat.scopeKey.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 3, parts[0] == "advice" else { continue }
            let snapshot = stat.snapshot
            globalAccumulator.include(snapshot)

            if let category = AdviceCategory(rawValue: String(parts[1])) {
                var categoryAccumulator = categoryAccumulators[category] ?? LearningAccumulator()
                categoryAccumulator.include(snapshot)
                categoryAccumulators[category] = categoryAccumulator
            }
            if let tone = ToneMode(rawValue: String(parts[2])) {
                var toneAccumulator = toneAccumulators[tone] ?? LearningAccumulator()
                toneAccumulator.include(snapshot)
                toneAccumulators[tone] = toneAccumulator
            }
        }

        return AdviceLearningContext(
            byCategory: categoryAccumulators.mapValues(\.snapshot),
            byTone: toneAccumulators.mapValues(\.snapshot),
            global: globalAccumulator.snapshot
        )
    }

    private func resolveCategory(
        seed: Int,
        context: AdviceLearningContext,
        situation: String,
        contentPack: ContentPack,
        preferredTone: ToneMode?
    ) -> AdviceCategory {
        guard selectedCategory == .random else { return selectedCategory }
        let compatiblePool: [AdviceCategory]
        if let preferredTone {
            compatiblePool = AdviceCategory.concrete.filter {
                CategoryToneCompatibility.score(category: $0, tone: preferredTone)
                    >= Self.randomCompatibilityFloor
            }
        } else {
            compatiblePool = AdviceCategory.concrete
        }
        let pool = compatiblePool.isEmpty ? AdviceCategory.concrete : compatiblePool
        let normalizedSituation = situation.normalizedForFiltering
        let weights = pool.map { category in
            let learningWeight = preferenceWeight(for: context.byCategory[category] ?? .empty)
            let contextWeight = contextualCategoryWeight(
                category: category,
                normalizedSituation: normalizedSituation,
                contentPack: contentPack
            )
            return learningWeight * contextWeight
        }
        return weightedChoice(items: pool, weights: weights, seed: seed, salt: 41)
            ?? pool[seed.positiveModulo(pool.count)]
    }

    private func resolveTone(seed: Int, context: AdviceLearningContext, category: AdviceCategory) -> ToneMode {
        guard selectedTone == .random else { return selectedTone }
        let compatiblePool = ToneMode.concrete.filter {
            CategoryToneCompatibility.score(category: category, tone: $0)
                >= Self.randomCompatibilityFloor
        }
        let pool = compatiblePool.isEmpty ? ToneMode.concrete : compatiblePool
        let weights = pool.map { preferenceWeight(for: context.byTone[$0] ?? .empty) }
        return weightedChoice(items: pool, weights: weights, seed: seed, salt: 97)
            ?? pool[seed.positiveModulo(pool.count)]
    }

    private func preferenceWeight(for snapshot: LearningStatSnapshot) -> Double {
        let positive =
            snapshot.likeCount
            + (snapshot.favoriteCount * 1.25)
            + (snapshot.shareCount * 1.05)
            + (snapshot.copyCount * 0.9)
            + (snapshot.regenCount * 0.6)
        let negative = snapshot.dislikeCount * 1.2
        let exposure = max(snapshot.shownCount, 3)
        let netScore = (positive - negative) / exposure
        let freshnessBias = 0.6 + (snapshot.freshnessScore * 0.4)
        let clamped = max(-0.45, min(0.85, netScore * freshnessBias))
        return max(0.2, 1.0 + clamped)
    }

    private func templateBias(
        for category: AdviceCategory,
        tone: ToneMode,
        context: AdviceLearningContext
    ) -> Double {
        let toneSnapshot = context.byTone[tone] ?? .empty
        let categorySnapshot = context.byCategory[category] ?? .empty
        let recency = max(toneSnapshot.freshnessScore, categorySnapshot.freshnessScore)
        let engagement = (toneSnapshot.engagementRatio + categorySnapshot.engagementRatio) / 2
        let richness = min((toneSnapshot.signalRichness + categorySnapshot.signalRichness) / 2, 1.0)
        let base = 0.35 + (recency * 0.35) + (engagement * 0.25) + (richness * 0.15)
        return min(max(base, 0.15), 0.95)
    }

    private func contextualCategoryWeight(
        category: AdviceCategory,
        normalizedSituation: String,
        contentPack: ContentPack
    ) -> Double {
        guard !normalizedSituation.isEmpty else { return 1.0 }
        let keywords = store.rules(for: category, contentPack: contentPack).keywords
        guard !keywords.isEmpty else { return 1.0 }
        var matches = 0
        for keyword in keywords {
            let normalizedKeyword = keyword.normalizedForFiltering
            guard !normalizedKeyword.isEmpty else { continue }
            if normalizedSituation.contains(normalizedKeyword) {
                matches += 1
            }
        }
        guard matches > 0 else { return 1.0 }
        let capped = min(matches, 6)
        return 1.0 + (Double(capped) * 0.35)
    }

    private func weightedChoice<T>(items: [T], weights: [Double], seed: Int, salt: Int) -> T? {
        guard items.count == weights.count, !items.isEmpty else {
            assertionFailure(
                "weightedChoice: mismatched or empty inputs (items:\(items.count) weights:\(weights.count))"
            )
            logger.error(
                "weightedChoice: mismatched or empty inputs — falling back to seed-based pick"
            )
            return nil
        }
        let first = items[0]
        let total = weights.reduce(0, +)
        guard total > 0 else {
            let index = seed.positiveModulo(items.count)
            return items[index]
        }
        let target = unitRandom(seed: seed, salt: salt) * total
        var cumulative: Double = 0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if target <= cumulative {
                return items[index]
            }
        }
        return first
    }

    private func unitRandom(seed: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value ^= UInt64(bitPattern: Int64(salt &* 7919))
        value = value &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        let bucket = value % 10_000
        return Double(bucket) / 10_000.0
    }

    private func summarize(text: String, maxSentences: Int, maxCharacters: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return nil }
        let sentences = trimmed.split(whereSeparator: { ".!?".contains($0) })
        guard !sentences.isEmpty else { return nil }
        let selection = sentences.prefix(maxSentences).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var summary = selection.joined(separator: ". ")
        if !summary.isEmpty, !summary.hasSuffix(".") {
            summary.append(".")
        }
        if summary.count > maxCharacters {
            let prefix = String(summary.prefix(maxCharacters))
            if let lastSpace = prefix.lastIndex(of: " ") {
                summary = String(prefix[..<lastSpace])
            } else {
                summary = prefix
            }
        }
        return summary
    }

    private func blendedAdviceLearningSnapshot(
        exact: LearningStatSnapshot,
        category: AdviceCategory,
        tone: ToneMode,
        context: AdviceLearningContext
    ) -> LearningStatSnapshot {
        var blended = exact
        let richness = exact.signalRichness

        let categoryWeight = max(0.10, 0.34 - (richness * 0.16))
        let toneWeight = max(0.07, 0.20 - (richness * 0.08))
        let globalWeight = max(0.04, 0.13 - (richness * 0.06))

        let categoryPrior = softenedLearningPrior(
            context.byCategory[category] ?? .empty,
            shownCap: 12,
            signalCap: 10
        )
        let tonePrior = softenedLearningPrior(
            context.byTone[tone] ?? .empty,
            shownCap: 9,
            signalCap: 7
        )
        let globalPrior = softenedLearningPrior(
            context.global,
            shownCap: 6,
            signalCap: 5
        )

        blended = mergeLearningSnapshots(
            blended, scaledLearningSnapshot(categoryPrior, by: categoryWeight))
        blended = mergeLearningSnapshots(blended, scaledLearningSnapshot(tonePrior, by: toneWeight))
        blended = mergeLearningSnapshots(
            blended, scaledLearningSnapshot(globalPrior, by: globalWeight))
        return blended
    }

    private func softenedLearningPrior(
        _ snapshot: LearningStatSnapshot,
        shownCap: Double,
        signalCap: Double
    ) -> LearningStatSnapshot {
        let shownScale = snapshot.shownCount > 0 ? min(1.0, shownCap / snapshot.shownCount) : 1.0
        let signals =
            snapshot.likeCount + snapshot.dislikeCount + snapshot.favoriteCount
            + snapshot.copyCount + snapshot.shareCount + snapshot.regenCount
        let signalScale = signals > 0 ? min(1.0, signalCap / signals) : 1.0
        return scaledLearningSnapshot(snapshot, by: min(shownScale, signalScale))
    }

    private func scaledLearningSnapshot(_ snapshot: LearningStatSnapshot, by factor: Double)
        -> LearningStatSnapshot
    {
        let safeFactor = max(factor, 0)
        return LearningStatSnapshot(
            shownCount: snapshot.shownCount * safeFactor,
            likeCount: snapshot.likeCount * safeFactor,
            dislikeCount: snapshot.dislikeCount * safeFactor,
            favoriteCount: snapshot.favoriteCount * safeFactor,
            copyCount: snapshot.copyCount * safeFactor,
            shareCount: snapshot.shareCount * safeFactor,
            regenCount: snapshot.regenCount * safeFactor,
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private func mergeLearningSnapshots(
        _ lhs: LearningStatSnapshot,
        _ rhs: LearningStatSnapshot
    ) -> LearningStatSnapshot {
        let mergedUpdatedAt: Date?
        switch (lhs.lastUpdatedAt, rhs.lastUpdatedAt) {
        case (.some(let l), .some(let r)):
            mergedUpdatedAt = max(l, r)
        case (.some(let l), .none):
            mergedUpdatedAt = l
        case (.none, .some(let r)):
            mergedUpdatedAt = r
        case (.none, .none):
            mergedUpdatedAt = nil
        }

        return LearningStatSnapshot(
            shownCount: lhs.shownCount + rhs.shownCount,
            likeCount: lhs.likeCount + rhs.likeCount,
            dislikeCount: lhs.dislikeCount + rhs.dislikeCount,
            favoriteCount: lhs.favoriteCount + rhs.favoriteCount,
            copyCount: lhs.copyCount + rhs.copyCount,
            shareCount: lhs.shareCount + rhs.shareCount,
            regenCount: lhs.regenCount + rhs.regenCount,
            lastUpdatedAt: mergedUpdatedAt
        )
    }

    private func voteLeaderboard(for state: AdviceVoteState) -> [AdviceLeaderboardItem] {
        _ = leaderboardVersion
        let records = repository.fetchHistory(limit: 50).filter { $0.vote == state }
        var grouped:
            [String: (category: AdviceCategory, tone: ToneMode, adviceLine: String, count: Int)] =
                [:]
        for record in records {
            let normalizedAdvice = record.adviceLine.normalizedForFiltering
            if var existing = grouped[normalizedAdvice] {
                existing.count += 1
                grouped[normalizedAdvice] = existing
            } else {
                grouped[normalizedAdvice] = (record.category, record.tone, record.adviceLine, 1)
            }
        }
        return
            grouped
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
                    return $0.adviceLine.localizedCaseInsensitiveCompare($1.adviceLine)
                        == .orderedAscending
                }
                return $0.votes > $1.votes
            }
            .prefix(8)
            .map { $0 }
    }

    private func poolKey(category: AdviceCategory, tone: ToneMode) -> String {
        "\(category.rawValue)|\(tone.rawValue)"
    }

    private func adviceScopeKey(category: AdviceCategory, tone: ToneMode) -> String {
        "advice|\(category.rawValue)|\(tone.rawValue)"
    }

    private func rotatePrimaryActionTitleIfNeeded() {
        successfulGenerationCount += 1
        guard successfulGenerationCount % 3 == 0 else { return }
        let choices = Self.primaryActionTitles.filter { $0 != primaryActionTitle }
        primaryActionTitle =
            choices.randomElement() ?? Self.primaryActionTitles.first ?? "Advise Me"
    }

    private func uniqueSuffix(for serial: Int) -> String {
        let adjectives = [
            "chaos", "executive", "moonshot", "unhinged", "legacy", "side-quest", "founder",
            "main-character",
        ]
        let nouns = [
            "protocol", "playbook", "framework", "operating system", "ritual", "policy", "method",
            "blueprint",
        ]
        let adjective = adjectives[serial % adjectives.count]
        let nounIndex = (serial / adjectives.count) % nouns.count
        let noun = nouns[nounIndex]
        let token = String(serial, radix: 36).uppercased()
        return "Call this the \(adjective) \(noun) \(token)."
    }

    private func suggestionCandidates(for category: AdviceCategory, situation: String?) async
        -> [UserAdviceSuggestion]
    {
        let all = repository.fetchSuggestions(limit: 120).filter {
            $0.category == category
                && !$0.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.adviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let normalizedSituation = situation?.normalizedForFiltering ?? ""
        guard !normalizedSituation.isEmpty else { return all }
        let scorer = SemanticTextScorer.shared
        let preparedQuery = await scorer.preparedQuery(from: normalizedSituation)

        var ranked: [(suggestion: UserAdviceSuggestion, score: Double, lexicalMatch: Bool)] = []
        ranked.reserveCapacity(all.count)
        for suggestion in all {
            let topic = suggestion.topic.normalizedForFiltering
            let lexicalMatch =
                !topic.isEmpty
                && (normalizedSituation.contains(topic) || topic.contains(normalizedSituation))
            let semanticScore =
                if let preparedQuery {
                    await scorer.similarity(
                        "\(suggestion.topic) \(suggestion.adviceLine)", to: preparedQuery)
                } else {
                    0.0
                }
            ranked.append((suggestion, semanticScore, lexicalMatch))
        }

        ranked.sort { lhs, rhs in
            if lhs.lexicalMatch != rhs.lexicalMatch {
                return lhs.lexicalMatch && !rhs.lexicalMatch
            }
            if lhs.score == rhs.score {
                return lhs.suggestion.topic.localizedCaseInsensitiveCompare(rhs.suggestion.topic)
                    == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        let prioritized = ranked.filter { $0.lexicalMatch || $0.score >= 0.18 }
        return (prioritized.isEmpty ? ranked : prioritized).map(\.suggestion)
    }

    /// ML Remix Lab for advice: synthesizes new candidates by blending patterns from the
    /// user's liked advice history with fresh engine-generated lines using remix templates.
    private func synthesizedAdviceCandidates(
        category: AdviceCategory,
        tone: ToneMode,
        seed: Int,
        includeRationale: Bool,
        contentPack: ContentPack,
        limit: Int = 3
    ) async -> [GeneratedAdvice] {

        // Only remix when we have enough liked history to learn from
        let likedHistory = repository.fetchHistory(limit: 80)
            .filter { $0.vote == .like && $0.category == category }
        guard likedHistory.count >= 2 else { return [] }

        // Templates use {stem} and {keyword} — safe against any % characters in advice text
        let remixTemplates = [
            "Build on this: {stem}. Now reframe it for {keyword}.",
            "Take the energy of: {stem}. Apply it to {keyword}.",
            "The real lesson of {stem} is that {keyword} deserves the same commitment.",
            "Escalate the logic of {stem}. That same move works for {keyword}.",
            "If {stem} was the answer, {keyword} is the next question — commit anyway.",
            "What worked in {stem} applies directly: {keyword}, with more confidence.",
            "Channel the spirit of {stem}. Your play for {keyword}: all in, no caveats.",
            "Treat {stem} as the baseline. Push {keyword} twice as hard and call it consistency.",
            "The momentum behind {stem} should define your next move on {keyword}.",
            "Use {stem} as precedent and execute {keyword} without recalibration.",
            "Frame {keyword} as phase two of {stem}, then skip the risk review.",
            "Repackage the confidence from {stem} into a full-send strategy for {keyword}.",
            "If {stem} worked once, scale the same logic across {keyword} immediately.",
        ]

        let rules = store.rules(for: category, contentPack: contentPack)
        let voice = store.profile(
            for: tone == .random ? (ToneMode.concrete[seed.positiveModulo(ToneMode.concrete.count)]) : tone)

        var built: [GeneratedAdvice] = []
        var seen = Set<String>()

        for (index, record) in likedHistory.prefix(limit * 3).enumerated() {
            guard built.count < limit else { break }

            let stemWords = record.adviceLine
                .split(separator: " ")
                .prefix(7)
                .map(String.init)
                .joined(separator: " ")
            guard stemWords.count >= 10 else { continue }

            let keyword = rules.keywords[
                (index * 7 + record.adviceLine.count) % max(rules.keywords.count, 1)]
            let template = remixTemplates[(record.adviceLine.count + index) % remixTemplates.count]
            let remixed =
                template
                .replacingOccurrences(of: "{stem}", with: stemWords)
                .replacingOccurrences(of: "{keyword}", with: keyword)

            guard remixed.count <= 200 else { continue }
            guard moderation.isSafe(text: remixed) else { continue }

            let opener = voice.opener[(seed + index) % voice.opener.count]
            let confidence = voice.confidenceTag[(seed + index * 3) % voice.confidenceTag.count]
            let ending = voice.ending[(seed + index * 5) % voice.ending.count]

            let adviceLine = "\(opener), \(remixed) \(confidence) \(ending)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = adviceLine.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }
            guard moderation.isSafe(text: adviceLine) else { continue }

            let rationale: String? =
                includeRationale
                ? "ML Remix: pattern from your liked advice blended with \(category.title) principles."
                : nil

            let resolvedTone =
                tone == .random
                ? ToneMode.concrete[(seed + index).positiveModulo(ToneMode.concrete.count)]
                : tone

            built.append(
                GeneratedAdvice(
                    category: category,
                    tone: resolvedTone,
                    adviceLine: String(adviceLine.prefix(220)),
                    rationaleLine: rationale
                ))
        }

        return built
    }

    private func communityCandidates(
        from pool: [UserAdviceSuggestion],
        tone: ToneMode,
        baseSeed: Int,
        maxCount: Int
    ) -> [GeneratedAdvice] {
        guard !pool.isEmpty, maxCount > 0 else { return [] }
        var results: [GeneratedAdvice] = []
        var seen = Set<String>()

        for attempt in 0..<(min(maxCount, pool.count)) {
            let index = (baseSeed + (attempt * 37)).positiveModulo(pool.count)
            let suggestion = pool[index]
            guard moderation.isSafe(text: "\(suggestion.topic) \(suggestion.adviceLine)") else {
                continue
            }

            let normalizedAdvice = suggestion.adviceLine.normalizedForFiltering
            guard seen.insert(normalizedAdvice).inserted else { continue }

            let rationale: String?
            if settingsViewModel.includeRationale {
                rationale =
                    "Community bad idea: for \(suggestion.topic), confidence was preferred over caution."
            } else {
                rationale = nil
            }

            results.append(
                GeneratedAdvice(
                    category: suggestion.category,
                    tone: tone,
                    adviceLine: suggestion.adviceLine,
                    rationaleLine: rationale
                )
            )
        }

        return results
    }

    private static let primaryActionTitles = [
        "Advise Me",
        "Need Bad Advice",
        "Make It Worse",
        "Hit Me With Chaos",
        "Give Me A Terrible Plan",
        "Destroy My Judgment",
        "Consult The Oracle",
        "What Could Go Wrong?",
        "Ruin My Week",
        "Show Me The Chaos",
        "Deploy Bad Wisdom",
    ]
}
