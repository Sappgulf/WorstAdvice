import Foundation
import OSLog
import SwiftData

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
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var toneRaw: String
    var adviceLine: String
    var rationaleLine: String?
    var isFavorite: Bool
    var voteRaw: Int?
    var aftermathNote: String?  // User's personal journal entry: what happened when they followed this advice
    var shareCount: Int?  // Optional so CloudKit can do a lightweight migration; use shareCountValue accessor
    var copyCount: Int?  // Optional so CloudKit can do a lightweight migration; use copyCountValue accessor

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date,
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        isFavorite: Bool = false,
        vote: AdviceVoteState = .none,
        shareCount: Int = 0,
        copyCount: Int = 0
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.isFavorite = isFavorite
        self.voteRaw = vote.rawValue
        self.shareCount = shareCount
        self.copyCount = copyCount
    }

    /// Non-optional convenience accessors — use these instead of the raw optional properties
    var shareCountValue: Int {
        get { shareCount ?? 0 }
        set { shareCount = newValue }
    }
    var copyCountValue: Int {
        get { copyCount ?? 0 }
        set { copyCount = newValue }
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
    var ownerAccountID: String?
    var createdAt: Date

    init(normalizedText: String, ownerAccountID: String? = nil, createdAt: Date = Date()) {
        self.normalizedText = normalizedText
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
    }
}

@Model
final class UserAdviceSuggestion {
    @Attribute(.unique) var id: UUID
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var topic: String
    var adviceLine: String

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date = Date(),
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
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
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var source: String
    var quoteText: String

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date = Date(),
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
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
    var ownerAccountID: String?
    var voteRaw: Int
    var updatedAt: Date

    init(
        quoteID: String,
        ownerAccountID: String? = nil,
        vote: AdviceVoteState = .none,
        updatedAt: Date = Date()
    ) {
        self.quoteID = quoteID
        self.ownerAccountID = ownerAccountID
        self.voteRaw = vote.rawValue
        self.updatedAt = updatedAt
    }

    var vote: AdviceVoteState {
        get { AdviceVoteState(rawValue: voteRaw) ?? .none }
        set { voteRaw = newValue.rawValue }
    }
}

@Model
final class LearningStatRecord {
    @Attribute(.unique) var scopeKey: String
    var ownerAccountID: String?
    var shownCount: Double
    var likeCount: Double
    var dislikeCount: Double
    var favoriteCount: Double
    var copyCount: Double
    var shareCount: Double
    var regenCount: Double
    var updatedAt: Date

    init(
        scopeKey: String,
        ownerAccountID: String? = nil,
        shownCount: Double = 0,
        likeCount: Double = 0,
        dislikeCount: Double = 0,
        favoriteCount: Double = 0,
        copyCount: Double = 0,
        shareCount: Double = 0,
        regenCount: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.scopeKey = scopeKey
        self.ownerAccountID = ownerAccountID
        self.shownCount = shownCount
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.favoriteCount = favoriteCount
        self.copyCount = copyCount
        self.shareCount = shareCount
        self.regenCount = regenCount
        self.updatedAt = updatedAt
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
            lastUpdatedAt: updatedAt
        )
    }
}

@Model
final class MissionProgressRecord {
    @Attribute(.unique) var missionKey: String
    var ownerAccountID: String?
    var periodRaw: String
    var categoryRaw: String
    var toneRaw: String
    var targetCount: Int
    var progressCount: Int
    var rewardClaimed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        missionKey: String,
        ownerAccountID: String? = nil,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int,
        progressCount: Int = 0,
        rewardClaimed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.missionKey = missionKey
        self.ownerAccountID = ownerAccountID
        self.periodRaw = periodRaw
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.targetCount = targetCount
        self.progressCount = progressCount
        self.rewardClaimed = rewardClaimed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    var ownerAccountID: String?
    var themeRaw: String
    var includeDisclaimerOnShare: Bool
    var reduceMotion: Bool
    var hapticsEnabled: Bool
    var soundEffectsEnabledRaw: Bool?
    var includeRationale: Bool
    var preferredTemplateRaw: String
    var preferredAspectRaw: String
    var preferredSharePresetRaw: String?
    var preferredContentPackRaw: String?
    var preferredGenerationProviderRaw: String?
    var strictNoRepeatsRaw: Bool?
    var communityOnlyModeRaw: Bool?
    var performanceModeRaw: Bool?
    var streakFreezeWeekKeyRaw: String?
    var streakFreezeUsedRaw: Bool?
    var streakFreezeProtectedDayRaw: String?
    var tabOrderRaw: String?
    var dailyNotificationsEnabledRaw: Bool?
    var streakNotificationsEnabledRaw: Bool?
    var dailyNotificationHourRaw: Int?
    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        theme: ThemeMode = .badvice,
        includeDisclaimerOnShare: Bool = true,
        reduceMotion: Bool = false,
        hapticsEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        includeRationale: Bool = true,
        preferredTemplate: ShareCardTemplate = .minimal,
        preferredAspect: ShareAspectRatio = .square,
        preferredSharePreset: ShareCaptionPreset = .deadpan,
        preferredContentPack: ContentPack = .classic,
        preferredGenerationProvider: AdviceGenerationProvider = .auto,
        strictNoRepeats: Bool = true,
        communityOnlyMode: Bool = false,
        performanceMode: Bool = false,
        tabOrder: [AppTab] = AppTab.defaultOrder
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.themeRaw = theme.rawValue
        self.includeDisclaimerOnShare = includeDisclaimerOnShare
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
        self.soundEffectsEnabledRaw = soundEffectsEnabled
        self.includeRationale = includeRationale
        self.preferredTemplateRaw = preferredTemplate.rawValue
        self.preferredAspectRaw = preferredAspect.rawValue
        self.preferredSharePresetRaw = preferredSharePreset.rawValue
        self.preferredContentPackRaw = preferredContentPack.rawValue
        self.preferredGenerationProviderRaw = preferredGenerationProvider.rawValue
        self.strictNoRepeatsRaw = strictNoRepeats
        self.communityOnlyModeRaw = communityOnlyMode
        self.performanceModeRaw = performanceMode
        self.streakFreezeWeekKeyRaw = nil
        self.streakFreezeUsedRaw = false
        self.streakFreezeProtectedDayRaw = nil
        self.tabOrderRaw = tabOrder.map(\.rawValue).joined(separator: ",")
    }

    var theme: ThemeMode {
        get { ThemeMode(rawValue: themeRaw) ?? .badvice }
        set { themeRaw = newValue.rawValue }
    }

    var soundEffectsEnabled: Bool {
        get { soundEffectsEnabledRaw ?? true }
        set { soundEffectsEnabledRaw = newValue }
    }

    var preferredTemplate: ShareCardTemplate {
        get { ShareCardTemplate(rawValue: preferredTemplateRaw) ?? .minimal }
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

    var preferredGenerationProvider: AdviceGenerationProvider {
        get { AdviceGenerationProvider(rawValue: preferredGenerationProviderRaw ?? "") ?? .auto }
        set { preferredGenerationProviderRaw = newValue.rawValue }
    }

    var strictNoRepeats: Bool {
        get { strictNoRepeatsRaw ?? true }
        set { strictNoRepeatsRaw = newValue }
    }

    var communityOnlyMode: Bool {
        get { communityOnlyModeRaw ?? false }
        set { communityOnlyModeRaw = newValue }
    }

    var performanceMode: Bool {
        get { performanceModeRaw ?? false }
        set { performanceModeRaw = newValue }
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

    var dailyNotificationsEnabled: Bool {
        get { dailyNotificationsEnabledRaw ?? true }
        set { dailyNotificationsEnabledRaw = newValue }
    }

    var streakNotificationsEnabled: Bool {
        get { streakNotificationsEnabledRaw ?? true }
        set { streakNotificationsEnabledRaw = newValue }
    }

    var dailyNotificationHour: Int {
        get { dailyNotificationHourRaw ?? 9 }
        set { dailyNotificationHourRaw = newValue }
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

