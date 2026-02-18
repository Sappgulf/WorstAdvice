import Foundation

struct LearningStatSnapshot: Sendable {
    let shownCount: Double
    let likeCount: Double
    let dislikeCount: Double
    let favoriteCount: Double
    let copyCount: Double
    let shareCount: Double
    let regenCount: Double

    static let empty = LearningStatSnapshot(
        shownCount: 0,
        likeCount: 0,
        dislikeCount: 0,
        favoriteCount: 0,
        copyCount: 0,
        shareCount: 0,
        regenCount: 0
    )

    /// Engagement ratio: positive signals over total interactions, in [0, 1].
    var engagementRatio: Double {
        let positive = likeCount + favoriteCount * 1.3 + copyCount * 0.8 + shareCount * 1.1
        let negative = dislikeCount * 1.5 + regenCount * 0.6
        let total = positive + negative
        guard total > 0 else { return 0.5 }
        return min(max(positive / total, 0.0), 1.0)
    }

    /// Signal richness: how much feedback exists in [0, 1], saturates at ~30 interactions.
    var signalRichness: Double {
        let interactions = likeCount + dislikeCount + favoriteCount + copyCount + shareCount + regenCount
        return min(interactions / 30.0, 1.0)
    }
}

struct AdaptiveRanker: Sendable {
    let profile: LearningWeightProfile

    init(profile: LearningWeightProfile = .balanced) {
        self.profile = profile
    }

    func adviceScore(
        semanticRelevance: Double,
        stats: LearningStatSnapshot?,
        noveltyPenalty: Double,
        seed: Int,
        candidateIndex: Int
    ) -> Double {
        score(
            semanticRelevance: semanticRelevance,
            stats: stats,
            noveltyPenalty: noveltyPenalty,
            seed: seed,
            candidateIndex: candidateIndex,
            channelBias: 0.0
        )
    }

    func quoteScore(
        semanticRelevance: Double,
        stats: LearningStatSnapshot?,
        noveltyPenalty: Double,
        seed: Int,
        candidateIndex: Int
    ) -> Double {
        score(
            semanticRelevance: semanticRelevance,
            stats: stats,
            noveltyPenalty: noveltyPenalty,
            seed: seed,
            candidateIndex: candidateIndex,
            channelBias: 0.02
        )
    }

    private func score(
        semanticRelevance: Double,
        stats: LearningStatSnapshot?,
        noveltyPenalty: Double,
        seed: Int,
        candidateIndex: Int,
        channelBias: Double
    ) -> Double {
        let stat = stats ?? .empty
        let shown = max(stat.shownCount, 0)

        // Bayesian-smoothed explicit preference score.
        let weightedLikes = stat.likeCount + (stat.favoriteCount * profile.favoriteBonusWeight)
        let weightedDislikes = stat.dislikeCount * profile.dislikePenaltyWeight
        let explicitPrior = (weightedLikes + 1.0) / (weightedLikes + weightedDislikes + 2.0)

        // Light implicit signals; capped to avoid overpowering explicit actions.
        let implicitRaw = (
            (stat.copyCount * profile.copyBonusWeight)
                + (stat.shareCount * profile.shareBonusWeight)
                - (stat.regenCount * profile.regenPenaltyWeight)
        ) / (shown + 5.0)
        let implicitPrior = min(max(implicitRaw + 0.5, 0.0), 1.0)

        let exploration = 1.0 / sqrt(shown + 1.0)
        let semantic = min(max(semanticRelevance, 0.0), 1.0)
        let novelty = min(max(noveltyPenalty, 0.0), 1.0)

        // Adaptive weight blending: as signal richness grows, trust explicit signals more
        // and exploration less. This lets the system bootstrap with exploration then converge.
        let richness = stat.signalRichness
        let effectiveExplicitWeight = profile.explicitWeight * (1.0 + richness * 0.4)
        let effectiveExplorationWeight = profile.explorationWeight * (1.0 - richness * 0.5)
        let effectiveSemanticWeight = profile.semanticWeight * (1.0 - richness * 0.15)

        // Engagement momentum: reward items with positive engagement trajectory
        let engagementBonus = richness > 0.15 ? stat.engagementRatio * 0.06 : 0.0

        let base =
            (semantic * effectiveSemanticWeight)
            + (explicitPrior * effectiveExplicitWeight)
            + (implicitPrior * profile.implicitWeight)
            + (exploration * effectiveExplorationWeight)
            - (novelty * profile.noveltyWeight)
            + engagementBonus
            + channelBias

        return base + deterministicTieBreaker(seed: seed, index: candidateIndex)
    }

    private func deterministicTieBreaker(seed: Int, index: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value = value &+ UInt64(truncatingIfNeeded: index &* 7919)
        value ^= value >> 33
        value &*= 0xff51afd7ed558ccd
        value ^= value >> 33
        value &*= 0xc4ceb9fe1a85ec53
        value ^= value >> 33
        let fraction = Double(value % 10_000) / 10_000.0
        return fraction * 0.0001
    }
}
