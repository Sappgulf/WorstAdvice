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

        // Confidence gating: keep low-sample scopes near neutral until enough interactions accrue.
        let confidence = shown / (shown + 6.0)
        let explicitSignal = 0.5 + ((explicitPrior - 0.5) * confidence)

        // Light implicit signals with separate confidence curve; capped to avoid overpowering explicit actions.
        let implicitRaw = (
            (stat.copyCount * profile.copyBonusWeight)
                + (stat.shareCount * profile.shareBonusWeight)
                - (stat.regenCount * profile.regenPenaltyWeight)
        ) / (shown + 5.0)
        let implicitPrior = min(max(implicitRaw + 0.5, 0.0), 1.0)
        let implicitConfidence = min(1.0, shown / 10.0)
        let implicitSignal = 0.5 + ((implicitPrior - 0.5) * implicitConfidence)

        // Strong dislike patterns get an extra guardrail to avoid repeatedly surfacing low-quality scopes.
        let dislikeRate = stat.dislikeCount / (shown + 1.0)
        let likeRate = stat.likeCount / (shown + 1.0)
        let dislikeGuardrail: Double
        if shown >= 3.0 && dislikeRate > likeRate + 0.25 {
            dislikeGuardrail = min(0.18, (dislikeRate - likeRate) * 0.25)
        } else {
            dislikeGuardrail = 0.0
        }

        let exploration = 1.0 / sqrt(shown + 1.0)
        let semantic = min(max(semanticRelevance, 0.0), 1.0)
        let novelty = min(max(noveltyPenalty, 0.0), 1.0)

        let base =
            (semantic * profile.semanticWeight)
            + (explicitSignal * profile.explicitWeight)
            + (implicitSignal * profile.implicitWeight)
            + (exploration * profile.explorationWeight)
            - (novelty * profile.noveltyWeight)
            + channelBias
            - dislikeGuardrail

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
