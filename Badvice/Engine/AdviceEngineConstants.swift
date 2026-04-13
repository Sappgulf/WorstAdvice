import Foundation

/// Centralizes tunable constants for the advice generation pipeline.
/// Change values here instead of hunting across AdviceEngine.swift.
enum AdviceEngineConstants {

    // MARK: - Input sanitization

    /// Maximum character length of a user-provided situation string.
    static let situationMaxLength: Int = 72

    // MARK: - Natural Language extraction

    /// Minimum character count for a noun token to be considered a salient topic.
    static let topicTokenMinLength: Int = 3
    /// Maximum number of meaningful words to preserve when lifting a short phrase from the situation.
    static let topicPhraseMaxWords: Int = 2
    /// Maximum character length for a lifted topic phrase.
    static let topicPhraseMaxLength: Int = 28

    // MARK: - Template bias

    /// Minimum combined template bias (clamps toward neutral templates).
    static let templateBiasMin: Double = 0.05
    /// Maximum combined template bias (clamps toward intense templates).
    static let templateBiasMax: Double = 0.95

    // MARK: - Candidate generation

    /// Multiplier applied to requested count to produce the initial candidate pool.
    /// A value of 5 means 5× candidates are generated before deduplication.
    static let candidatePoolMultiplier: Int = 5
    /// Minimum extra candidates generated beyond the requested count.
    static let candidatePoolMinExtra: Int = 8
    /// Prime used to stride seeds across candidates to avoid collisions.
    static let candidateSeedStride: Int = 7919

    // MARK: - Quality scoring

    /// Penalty applied when advice text exceeds this character count.
    static let adviceLengthPenaltyThreshold: Int = 225
    /// Ideal minimum length (chars) for a punchy advice line.
    static let adviceIdealMinLength: Int = 50
    /// Ideal maximum length (chars) for a punchy advice line.
    static let adviceIdealMaxLength: Int = 180
    /// Number of repeated words (length > 3) that triggers a repetition penalty.
    static let adviceRepetitionPenaltyThreshold: Int = 2

    // MARK: - Output trimming

    /// Hard cap on advice text after polishing.
    static let adviceOutputMaxLength: Int = 240
}
