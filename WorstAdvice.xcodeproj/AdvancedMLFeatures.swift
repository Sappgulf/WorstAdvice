import Foundation
import CoreML
import NaturalLanguage

// MARK: - Advanced ML Features

@available(iOS 17.0, *)
class AdvancedMLEngine {
    static let shared = AdvancedMLEngine()
    
    private let sentimentAnalyzer = NLModel(mlModel: try! NLModel.modelForSentimentAnalysis())
    private let languageRecognizer = NLLanguageRecognizer()
    
    private init() {}
    
    // MARK: - Sentiment Analysis
    
    func analyzeSentiment(_ text: String) -> SentimentScore {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let scoreString = sentiment?.rawValue, let score = Double(scoreString) {
            return SentimentScore(
                score: score,
                category: categorize(score: score),
                confidence: abs(score)
            )
        }
        
        return SentimentScore(score: 0, category: .neutral, confidence: 0)
    }
    
    private func categorize(score: Double) -> SentimentCategory {
        if score > 0.3 { return .positive }
        if score < -0.3 { return .negative }
        return .neutral
    }
    
    // MARK: - Topic Extraction
    
    func extractTopics(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var topics: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let topic = String(text[range])
                if !topic.isEmpty && topic.count > 2 {
                    topics.append(topic)
                }
            }
            return true
        }
        
        return Array(Set(topics)).prefix(5).map { String($0) }
    }
    
    // MARK: - Keyword Extraction
    
    func extractKeywords(from text: String, limit: Int = 10) -> [Keyword] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var keywords: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun || tag == .verb || tag == .adjective {
                let word = String(text[range]).lowercased()
                if word.count > 3 {
                    keywords[word, default: 0] += 1
                }
            }
            return true
        }
        
        return keywords
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { Keyword(word: $0.key, frequency: $0.value) }
    }
    
    // MARK: - Language Detection
    
    func detectLanguage(in text: String) -> NLLanguage? {
        languageRecognizer.processString(text)
        return languageRecognizer.dominantLanguage
    }
    
    // MARK: - Text Similarity
    
    func calculateSimilarity(between text1: String, and text2: String) -> Double {
        let embedding1 = createEmbedding(for: text1)
        let embedding2 = createEmbedding(for: text2)
        
        return cosineSimilarity(embedding1, embedding2)
    }
    
    private func createEmbedding(for text: String) -> [Double] {
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var vectors: [[Double]] = []
        
        for word in words {
            if let vector = embedding?.vector(for: word) {
                vectors.append(vector)
            }
        }
        
        guard !vectors.isEmpty else { return [] }
        
        // Average pooling
        let dimensions = vectors[0].count
        var avgVector = [Double](repeating: 0, count: dimensions)
        
        for vector in vectors {
            for (i, value) in vector.enumerated() {
                avgVector[i] += value
            }
        }
        
        return avgVector.map { $0 / Double(vectors.count) }
    }
    
    private func cosineSimilarity(_ vec1: [Double], _ vec2: [Double]) -> Double {
        guard vec1.count == vec2.count else { return 0 }
        
        let dotProduct = zip(vec1, vec2).reduce(0) { $0 + $1.0 * $1.1 }
        let magnitude1 = sqrt(vec1.reduce(0) { $0 + $1 * $1 })
        let magnitude2 = sqrt(vec2.reduce(0) { $0 + $1 * $1 })
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    // MARK: - Readability Analysis
    
    func analyzeReadability(_ text: String) -> ReadabilityMetrics {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }
        
        let wordCount = words.count
        let sentenceCount = max(sentences.count, 1)
        let syllableCount = words.reduce(0) { $0 + countSyllables(in: $1) }
        
        // Flesch Reading Ease
        let avgWordsPerSentence = Double(wordCount) / Double(sentenceCount)
        let avgSyllablesPerWord = Double(syllableCount) / Double(wordCount)
        
        let fleschScore = 206.835 - 1.015 * avgWordsPerSentence - 84.6 * avgSyllablesPerWord
        
        return ReadabilityMetrics(
            wordCount: wordCount,
            sentenceCount: sentenceCount,
            avgWordsPerSentence: avgWordsPerSentence,
            fleschReadingEase: fleschScore,
            readingLevel: getReadingLevel(flesch: fleschScore)
        )
    }
    
    private func countSyllables(in word: String) -> Int {
        let vowels = CharacterSet(charactersIn: "aeiouyAEIOUY")
        var count = 0
        var previousWasVowel = false
        
        for char in word.unicodeScalars {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel {
                count += 1
            }
            previousWasVowel = isVowel
        }
        
        return max(count, 1)
    }
    
    private func getReadingLevel(flesch: Double) -> String {
        switch flesch {
        case 90...100: return "Very Easy (5th grade)"
        case 80..<90: return "Easy (6th grade)"
        case 70..<80: return "Fairly Easy (7th grade)"
        case 60..<70: return "Standard (8th-9th grade)"
        case 50..<60: return "Fairly Difficult (10th-12th grade)"
        case 30..<50: return "Difficult (College)"
        default: return "Very Difficult (College Graduate)"
        }
    }
}

// MARK: - Models

struct SentimentScore {
    let score: Double // -1.0 to 1.0
    let category: SentimentCategory
    let confidence: Double
}

enum SentimentCategory {
    case positive
    case neutral
    case negative
}

struct Keyword {
    let word: String
    let frequency: Int
}

struct ReadabilityMetrics {
    let wordCount: Int
    let sentenceCount: Int
    let avgWordsPerSentence: Double
    let fleschReadingEase: Double
    let readingLevel: String
}

// MARK: - ML-Powered Advice Ranking

@available(iOS 17.0, *)
class MLAdviceRanker {
    static let shared = MLAdviceRanker()
    
    private init() {}
    
    func rankAdvice(_ records: [AdviceRecord]) -> [RankedAdvice] {
        var ranked: [RankedAdvice] = []
        
        for record in records {
            let sentiment = AdvancedMLEngine.shared.analyzeSentiment(record.adviceLine)
            let readability = AdvancedMLEngine.shared.analyzeReadability(record.adviceLine)
            let keywords = AdvancedMLEngine.shared.extractKeywords(from: record.adviceLine)
            
            // Calculate composite score
            let sentimentScore = abs(sentiment.score) * 10 // 0-10
            let readabilityScore = min(readability.fleschReadingEase / 10, 10) // 0-10
            let keywordScore = Double(keywords.count) // 0-10
            
            let totalScore = (sentimentScore + readabilityScore + keywordScore) / 3
            
            ranked.append(RankedAdvice(
                record: record,
                score: totalScore,
                sentiment: sentiment,
                readability: readability,
                keywords: keywords
            ))
        }
        
        return ranked.sorted { $0.score > $1.score }
    }
}

struct RankedAdvice {
    let record: AdviceRecord
    let score: Double
    let sentiment: SentimentScore
    let readability: ReadabilityMetrics
    let keywords: [Keyword]
}

// MARK: - Smart Suggestions Engine

@available(iOS 17.0, *)
class SmartSuggestionsEngine {
    static let shared = SmartSuggestionsEngine()
    
    private init() {}
    
    func generateSmartSuggestions(
        basedOn history: [AdviceRecord],
        currentContext: String?
    ) -> [SmartSuggestion] {
        // Analyze user preferences from history
        let categoryFrequency = analyzeCategoryFrequency(history)
        let toneFrequency = analyzeToneFrequency(history)
        let timeOfDay = getTimeOfDay()
        
        var suggestions: [SmartSuggestion] = []
        
        // Context-aware suggestions
        if let context = currentContext, !context.isEmpty {
            let keywords = AdvancedMLEngine.shared.extractKeywords(from: context, limit: 3)
            let sentiment = AdvancedMLEngine.shared.analyzeSentiment(context)
            
            // Suggest based on context sentiment
            if sentiment.category == .negative {
                suggestions.append(SmartSuggestion(
                    type: .contextBased,
                    category: .social,
                    tone: .toxicBestFriend,
                    reason: "Detected challenging situation - humor might help!",
                    confidence: 0.8
                ))
            }
        }
        
        // Time-based suggestions
        switch timeOfDay {
        case .morning:
            suggestions.append(SmartSuggestion(
                type: .timeBased,
                category: .productivity,
                tone: .corporateConsultant,
                reason: "Start your day with productivity 'wisdom'",
                confidence: 0.9
            ))
        case .afternoon:
            suggestions.append(SmartSuggestion(
                type: .timeBased,
                category: .career,
                tone: .alphaPodcast,
                reason: "Mid-day career advice",
                confidence: 0.7
            ))
        case .evening:
            suggestions.append(SmartSuggestion(
                type: .timeBased,
                category: .social,
                tone: .influencer,
                reason: "Evening social inspiration",
                confidence: 0.8
            ))
        case .night:
            suggestions.append(SmartSuggestion(
                type: .timeBased,
                category: .dating,
                tone: .wizard,
                reason: "Late night relationship wisdom",
                confidence: 0.6
            ))
        }
        
        // Pattern-based suggestions
        if let topCategory = categoryFrequency.first {
            suggestions.append(SmartSuggestion(
                type: .patternBased,
                category: topCategory.key,
                tone: toneFrequency.first?.key ?? .corporateConsultant,
                reason: "Your favorite category",
                confidence: 0.95
            ))
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func analyzeCategoryFrequency(_ records: [AdviceRecord]) -> [(key: AdviceCategory, value: Int)] {
        var frequency: [AdviceCategory: Int] = [:]
        for record in records {
            frequency[record.category, default: 0] += 1
        }
        return frequency.sorted { $0.value > $1.value }
    }
    
    private func analyzeToneFrequency(_ records: [AdviceRecord]) -> [(key: ToneMode, value: Int)] {
        var frequency: [ToneMode: Int] = [:]
        for record in records {
            frequency[record.tone, default: 0] += 1
        }
        return frequency.sorted { $0.value > $1.value }
    }
    
    private func getTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
    
    enum TimeOfDay {
        case morning, afternoon, evening, night
    }
}

struct SmartSuggestion {
    enum SuggestionType {
        case contextBased
        case timeBased
        case patternBased
        case trending
    }
    
    let type: SuggestionType
    let category: AdviceCategory
    let tone: ToneMode
    let reason: String
    let confidence: Double
}
