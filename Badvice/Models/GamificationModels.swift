import Foundation

enum AchievementType: String, CaseIterable, Codable, Identifiable, Sendable {
    case firstAdvice = "first_advice"
    case tenAdvice = "ten_advice"
    case hundredAdvice = "hundred_advice"
    case firstSave = "first_save"
    case collector = "collector"
    case hoarder = "hoarder"
    case sharer = "sharer"
    case viral = "viral"
    case dailyStreak3 = "streak_3"
    case dailyStreak7 = "streak_7"
    case dailyStreak14 = "streak_14"
    case dailyStreak30 = "streak_30"
    case toneExplorer = "tone_explorer"
    case categoryMaster = "category_master"
    case nightOwl = "night_owl"
    case earlyBird = "early_bird"
    case shakeItOff = "shake_it_off"
    case suggestionAccepted = "suggestion_accepted"
    case bugHunter = "bug_hunter"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .firstAdvice: return "First Mistake"
        case .tenAdvice: return "Serial Offender"
        case .hundredAdvice: return "Chaos Connoisseur"
        case .firstSave: return "Bookmarked Badness"
        case .collector: return "Curator of Catastrophe"
        case .hoarder: return "Advice Archivist"
        case .sharer: return "Spread the Badness"
        case .viral: return "Going Viral"
        case .dailyStreak3: return "3-Day Bender"
        case .dailyStreak7: return "Weekly Chaos"
        case .dailyStreak14: return "Two Weeks of Trouble"
        case .dailyStreak30: return "Monthly Madness"
        case .toneExplorer: return "Voice Actor"
        case .categoryMaster: return "Jack of All Trades"
        case .nightOwl: return "Midnight Badvice"
        case .earlyBird: return "Early Bird Gets the Burn"
        case .shakeItOff: return "Shake It Off"
        case .suggestionAccepted: return "Community Contributor"
        case .bugHunter: return "Bug Hunter"
        }
    }
    
    var description: String {
        switch self {
        case .firstAdvice: return "Generate your first bad advice"
        case .tenAdvice: return "Generate 10 pieces of bad advice"
        case .hundredAdvice: return "Generate 100 pieces of bad advice"
        case .firstSave: return "Save your first bad advice"
        case .collector: return "Save 10 pieces of bad advice"
        case .hoarder: return "Save 50 pieces of bad advice"
        case .sharer: return "Share bad advice 5 times"
        case .viral: return "Share bad advice 25 times"
        case .dailyStreak3: return "Use Badvice for 3 days in a row"
        case .dailyStreak7: return "Use Badvice for 7 days in a row"
        case .dailyStreak14: return "Use Badvice for 14 days in a row"
        case .dailyStreak30: return "Use Badvice for 30 days in a row"
        case .toneExplorer: return "Try every concrete tone mode"
        case .categoryMaster: return "Generate advice in every concrete category"
        case .nightOwl: return "Generate advice after midnight"
        case .earlyBird: return "Generate advice before 6 AM"
        case .shakeItOff: return "Use shake to generate advice"
        case .suggestionAccepted: return "Submit a community suggestion"
        case .bugHunter: return "Generate advice with a technical glitch"
        }
    }
    
    var icon: String {
        switch self {
        case .firstAdvice: return "sparkles"
        case .tenAdvice: return "10.circle.fill"
        case .hundredAdvice: return "100.circle.fill"
        case .firstSave: return "bookmark.fill"
        case .collector: return "folder.fill"
        case .hoarder: return "archivebox.fill"
        case .sharer: return "square.and.arrow.up.fill"
        case .viral: return "flame.fill"
        case .dailyStreak3: return "3.circle.fill"
        case .dailyStreak7: return "7.circle.fill"
        case .dailyStreak14: return "14.circle.fill"
        case .dailyStreak30: return "30.circle.fill"
        case .toneExplorer: return "theatermasks.fill"
        case .categoryMaster: return "checkmark.circle.fill"
        case .nightOwl: return "moon.fill"
        case .earlyBird: return "sunrise.fill"
        case .shakeItOff: return "iphone.gen3.radiowaves.left.and.right"
        case .suggestionAccepted: return "person.2.fill"
        case .bugHunter: return "ant.fill"
        }
    }
    
    var unlocksTheme: ThemeMode? {
        switch self {
        case .dailyStreak7: return .neon
        case .hundredAdvice: return .midnight
        case .categoryMaster: return .sunset
        case .bugHunter: return .cybernetic
        default: return nil
        }
    }
    
    var isSecret: Bool {
        // Secret achievements that aren't revealed until unlocked
        self == .nightOwl || self == .earlyBird
    }
}

struct Achievement: Identifiable, Codable, Sendable {
    let type: AchievementType
    var unlockedAt: Date?
    var progress: Int
    let target: Int
    
    var id: String { type.rawValue }
    var isUnlocked: Bool { unlockedAt != nil }
    var progressPercent: Double {
        Double(progress) / Double(target)
    }
}

struct DailyChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let category: AdviceCategory
    let tone: ToneMode
    let title: String
    let description: String
    let expiresAt: Date
    let bonusPoints: Int
    
    var isExpired: Bool { Date() > expiresAt }
    
    static func generateForToday() -> DailyChallenge {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        
        let category = categories[dayOfYear % categories.count]
        let tone = tones[dayOfYear % tones.count]
        
        let titles = [
            "Wizard Wednesday", "Toxic Tuesday", "Alpha Friday",
            "Boomer Monday", "Crypto Chaos", "Wizard Wisdom"
        ]
        let title = titles[dayOfYear % titles.count]
        
        return DailyChallenge(
            id: UUID(),
            category: category,
            tone: tone,
            title: title,
            description: "Get bad \(category.title) advice in \(tone.title) tone",
            expiresAt: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
            bonusPoints: 50
        )
    }
}

struct GroupChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let category: AdviceCategory
    let tone: ToneMode
    let creatorID: String
    let participantIDs: [String]
    let startedAt: Date
    let endsAt: Date
    let leaderboard: [ChallengeEntry]
    
    var isActive: Bool { Date() < endsAt }
}

struct ChallengeEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let userID: String
    let userName: String
    let adviceCount: Int
    let totalLikes: Int
    
    var score: Int { adviceCount * 10 + totalLikes * 5 }
}











enum ShareFormat: String, Codable, Sendable {
    case image
    case video
    case text
    case instagramStory
    case sticker
    
    var exportAction: String {
        switch self {
        case .image: return "Export as image"
        case .video: return "Export as video"
        case .text: return "Copy as text"
        case .instagramStory: return "Share to Stories"
        case .sticker: return "Create sticker"
        }
    }
}

struct ShareOptions: Codable, Sendable {
    var format: ShareFormat
    var includeWatermark: Bool
    var watermarkText: String
    var includeCategory: Bool
    var includeTone: Bool
    var backgroundColor: String
    var textColor: String
    
    static let `default` = ShareOptions(
        format: .image,
        includeWatermark: true,
        watermarkText: "Badvice",
        includeCategory: true,
        includeTone: true,
        backgroundColor: "#000000",
        textColor: "#FFFFFF"
    )
}








extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// Party rounds support both pass-the-phone play and Game Center turn-based play.
struct PartyAdviceTake: Codable, Equatable, Sendable {
    let advice: String
    let source: AdviceGenerationProvider
    let notice: String?
}

struct PartyRound: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Identifiable, Sendable {
        let id: Int
        let player: String
        let advice: String
        let generationSource: AdviceGenerationProvider?
        let generationNotice: String?

        init(
            id: Int,
            player: String,
            advice: String,
            generationSource: AdviceGenerationProvider? = nil,
            generationNotice: String? = nil
        ) {
            self.id = id
            self.player = player
            self.advice = advice
            self.generationSource = generationSource
            self.generationNotice = generationNotice
        }
    }

    let entries: [Entry]
    let category: AdviceCategory
    private(set) var votes: [Int: Int] = [:]

    var voterIndex: Int { votes.count }
    var isComplete: Bool { votes.count == entries.count }
    var isValid: Bool {
        (2...8).contains(entries.count)
            && entries.enumerated().allSatisfy { $0.offset == $0.element.id && !$0.element.player.isEmpty && !$0.element.advice.isEmpty }
            && votes.keys.sorted() == Array(0..<votes.count)
            && votes.allSatisfy { entries.indices.contains($0.key) && entries.indices.contains($0.value) && $0.key != $0.value }
    }
    var leaders: [Entry] {
        guard isComplete else { return [] }
        let counts = Dictionary(grouping: votes.values, by: { $0 }).mapValues(\.count)
        let highest = counts.values.max() ?? 0
        return entries.filter { counts[$0.id, default: 0] == highest }
    }
    func voteCount(for entry: Entry) -> Int { votes.values.filter { $0 == entry.id }.count }

    var generationSummary: String {
        let appleCount = entries.filter { $0.generationSource == .appleOnDevice }.count
        let localCount = entries.filter { $0.generationSource == .classic }.count

        switch (appleCount, localCount) {
        case (0, _):
            return "Bureau Engine • local"
        case (_, 0):
            return "Apple Intelligence • on device"
        default:
            return "Apple Intelligence + local fallback"
        }
    }

    var generationNotice: String? {
        var seen = Set<String>()
        let notices = entries.compactMap(\.generationNotice).filter { seen.insert($0).inserted }
        return notices.isEmpty ? nil : notices.prefix(2).joined(separator: " ")
    }

    @discardableResult
    mutating func castVote(for entryID: Int) -> Bool {
        guard isValid, !isComplete, entries.indices.contains(entryID), entryID != voterIndex else { return false }
        votes[voterIndex] = entryID
        return true
    }

    static func playerNames(from input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func validatedPlayerNames(from input: String) -> [String]? {
        validatedPlayerNames(playerNames(from: input))
    }

    static func validatedPlayerNames(_ players: [String]) -> [String]? {
        let normalized = players.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard (2...8).contains(normalized.count),
              normalized.allSatisfy({ !$0.isEmpty && $0.count <= 24 }),
              Set(normalized.map { $0.lowercased() }).count == normalized.count
        else { return nil }
        return normalized
    }

    static func make(players: [String], category: AdviceCategory, seed: Int) -> PartyRound? {
        guard let players = validatedPlayerNames(players) else { return nil }
        let engine = BureauAdviceEngine()
        let takes = players.enumerated().map { index, _ in
            let take = engine.generate(
                category: category, tone: ToneMode.concrete[index % ToneMode.concrete.count],
                includeRationale: false, revision: .oneSentence, seed: seed &+ index &* 131
            )
            return PartyAdviceTake(advice: take.adviceLine, source: .classic, notice: nil)
        }
        return make(players: players, category: category, takes: takes)
    }

    static func make(
        players: [String],
        category: AdviceCategory,
        takes: [PartyAdviceTake]
    ) -> PartyRound? {
        guard let players = validatedPlayerNames(players),
              takes.count == players.count,
              takes.allSatisfy({
                  !$0.advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              })
        else { return nil }

        let entries = zip(players, takes).enumerated().map { index, values in
            Entry(
                id: index,
                player: values.0,
                advice: values.1.advice,
                generationSource: values.1.source,
                generationNotice: values.1.notice
            )
        }
        return PartyRound(entries: entries, category: category)
    }

    static func restoring(entries: [Entry], category: AdviceCategory, votes: [Int: Int]) -> PartyRound? {
        let round = PartyRound(entries: entries, category: category, votes: votes)
        return round.isValid ? round : nil
    }
}

/// Codable turn state shared through Game Center between each player's move.
struct OnlinePartyRoundState: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case writing
        case voting
        case complete
    }

    struct Take: Codable, Equatable, Sendable {
        let participantIndex: Int
        let advice: String
        let source: AdviceGenerationProvider
        let notice: String?
    }

    static let currentVersion = 1
    private(set) var version = currentVersion
    let participantCount: Int
    let category: AdviceCategory
    private(set) var phase = Phase.writing
    private(set) var takes: [Take?]
    private(set) var votes: [Int: Int] = [:]

    init?(participantCount: Int, category: AdviceCategory) {
        guard (2...8).contains(participantCount) else { return nil }
        self.participantCount = participantCount
        self.category = category
        self.takes = Array(repeating: nil, count: participantCount)
    }

    var nextActorIndex: Int? {
        switch phase {
        case .writing:
            takes.firstIndex(where: { $0 == nil })
        case .voting:
            (0..<participantCount).first(where: { votes[$0] == nil })
        case .complete:
            nil
        }
    }

    var completedTakeCount: Int { takes.compactMap { $0 }.count }

    var isValid: Bool {
        let moderation = ContentModeration()
        guard version == Self.currentVersion,
              (2...8).contains(participantCount),
              takes.count == participantCount,
              takes.enumerated().allSatisfy({ index, take in
                  guard let take else { return true }
                  return take.participantIndex == index
                      && !take.advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && take.advice.count <= 1_000
                      && moderation.isSafe(text: take.advice)
                      && (take.notice?.count ?? 0) <= 500
                      && moderation.isSafe(text: take.notice ?? "")
              }),
              votes.keys.sorted() == Array(0..<votes.count),
              votes.allSatisfy({ voter, target in
                  (0..<participantCount).contains(voter)
                      && (0..<participantCount).contains(target)
                      && voter != target
              })
        else { return false }

        switch phase {
        case .writing:
            return votes.isEmpty && completedTakeCount < participantCount
                && takes.drop(while: { $0 != nil }).allSatisfy({ $0 == nil })
        case .voting:
            return completedTakeCount == participantCount && votes.count < participantCount
        case .complete:
            return completedTakeCount == participantCount && votes.count == participantCount
        }
    }

    func round(participantNames: [String]) -> PartyRound? {
        guard participantNames.count == participantCount,
              takes.allSatisfy({ $0 != nil })
        else { return nil }

        let entries = takes.enumerated().compactMap { index, take -> PartyRound.Entry? in
            guard let take else { return nil }
            let displayName = participantNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return PartyRound.Entry(
                id: index,
                player: displayName.isEmpty ? "Player \(index + 1)" : String(displayName.prefix(40)),
                advice: take.advice,
                generationSource: take.source,
                generationNotice: take.notice
            )
        }
        return PartyRound.restoring(entries: entries, category: category, votes: votes)
    }

    @discardableResult
    mutating func submit(_ take: PartyAdviceTake, for participantIndex: Int) -> Bool {
        guard isValid, phase == .writing, nextActorIndex == participantIndex,
              takes.indices.contains(participantIndex),
              !take.advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              take.advice.count <= 1_000,
              ContentModeration().isSafe(text: take.advice),
              (take.notice?.count ?? 0) <= 500,
              ContentModeration().isSafe(text: take.notice ?? "")
        else { return false }

        takes[participantIndex] = Take(
            participantIndex: participantIndex,
            advice: take.advice,
            source: take.source,
            notice: take.notice
        )
        if completedTakeCount == participantCount { phase = .voting }
        return isValid
    }

    @discardableResult
    mutating func castVote(for entryIndex: Int, by participantIndex: Int) -> Bool {
        guard isValid, phase == .voting, nextActorIndex == participantIndex,
              (0..<participantCount).contains(entryIndex),
              participantIndex != entryIndex
        else { return false }

        votes[participantIndex] = entryIndex
        if votes.count == participantCount { phase = .complete }
        return isValid
    }
}
