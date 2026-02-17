import Foundation
import FoundationModels

// MARK: - ML-Enhanced Advice Generator

@available(iOS 18.0, *)
@MainActor
class MLAdviceGenerator: ObservableObject {
    private let model = SystemLanguageModel.default
    private var currentSession: LanguageModelSession?
    
    @Published var isModelAvailable = false
    @Published var modelStatus: String = "Checking..."
    
    init() {
        checkModelAvailability()
    }
    
    func checkModelAvailability() {
        switch model.availability {
        case .available:
            isModelAvailable = true
            modelStatus = "Apple Intelligence Ready"
        case .unavailable(.deviceNotEligible):
            modelStatus = "Device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            modelStatus = "Enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady):
            modelStatus = "Model downloading..."
        case .unavailable(let other):
            modelStatus = "Unavailable: \(other)"
        }
    }
    
    // MARK: - Enhanced Bad Advice Generation
    
    func generateEnhancedAdvice(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        includeRationale: Bool
    ) async throws -> EnhancedAdvice {
        guard isModelAvailable else {
            throw MLError.modelUnavailable
        }
        
        // Create instructions for bad advice generation
        let instructions = createInstructions(category: category, tone: tone)
        let session = LanguageModelSession(instructions: instructions)
        currentSession = session
        
        // Generate bad advice
        let prompt = createPrompt(category: category, situation: situation)
        
        let response = try await session.respond(
            to: prompt,
            generating: BadAdviceResponse.self
        )
        
        return EnhancedAdvice(
            adviceLine: response.content.advice,
            rationaleLine: includeRationale ? response.content.rationale : nil,
            confidence: response.content.confidence,
            chaosLevel: response.content.chaosLevel,
            category: category,
            tone: tone
        )
    }
    
    // MARK: - Situational Enhancement
    
    func enhanceSituation(_ situation: String) async throws -> EnhancedSituation {
        guard isModelAvailable else {
            throw MLError.modelUnavailable
        }
        
        let instructions = """
        You are analyzing a user's situation to provide better context for bad advice generation.
        Extract key themes, emotions, and relevant keywords.
        Identify what makes this situation ripe for confidently terrible guidance.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let response = try await session.respond(
            to: "Analyze this situation: \(situation)",
            generating: SituationAnalysis.self
        )
        
        return EnhancedSituation(
            originalText: situation,
            themes: response.content.themes,
            emotionalState: response.content.emotionalState,
            keywords: response.content.keywords,
            complexity: response.content.complexity
        )
    }
    
    // MARK: - Streaming Generation
    
    func streamEnhancedAdvice(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?
    ) -> AsyncThrowingStream<PartialAdvice, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isModelAvailable else {
                        throw MLError.modelUnavailable
                    }
                    
                    let instructions = createInstructions(category: category, tone: tone)
                    let session = LanguageModelSession(instructions: instructions)
                    
                    let prompt = createPrompt(category: category, situation: situation)
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: BadAdviceResponse.self
                    )
                    
                    for try await partial in stream {
                        let partialAdvice = PartialAdvice(
                            advice: partial.advice,
                            rationale: partial.rationale,
                            confidence: partial.confidence,
                            chaosLevel: partial.chaosLevel
                        )
                        continuation.yield(partialAdvice)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Advice Variation Generation
    
    func generateVariations(
        of advice: String,
        count: Int = 3
    ) async throws -> [String] {
        guard isModelAvailable else {
            throw MLError.modelUnavailable
        }
        
        let instructions = """
        You are creating variations of existing bad advice.
        Maintain the same terrible spirit but rephrase creatively.
        Keep the confidence and wrongness, change the delivery.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let response = try await session.respond(
            to: "Create \(count) variations of this advice: \(advice)",
            generating: AdviceVariations.self
        )
        
        return response.content.variations
    }
    
    // MARK: - Humor Score Analysis
    
    func analyzeHumor(_ advice: String) async throws -> HumorAnalysis {
        guard isModelAvailable else {
            throw MLError.modelUnavailable
        }
        
        let instructions = """
        Analyze the humor level of this bad advice.
        Rate absurdity, irony, and potential for misinterpretation.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let response = try await session.respond(
            to: "Analyze: \(advice)",
            generating: HumorAnalysis.self
        )
        
        return response.content
    }
    
    // MARK: - Private Helper Methods
    
    private func createInstructions(category: AdviceCategory, tone: ToneMode) -> String {
        let categoryContext = getCategoryContext(category)
        let tonePersona = getTonePersona(tone)
        
        return """
        You are a generator of confidently terrible advice.
        
        PERSONA: \(tonePersona)
        
        CATEGORY: \(category.title) - \(categoryContext)
        
        RULES:
        1. Give advice that sounds authoritative but is actually terrible
        2. Be creative, unexpected, and absurdly confident
        3. The advice should be obviously bad to any reasonable person
        4. Use the persona's voice and speech patterns
        5. Keep advice concise (under 120 characters for the main line)
        6. Optional rationale explains WHY it's terrible (under 80 characters)
        
        OUTPUT FORMAT: Generate ONE piece of bad advice with these components:
        - advice: The main terrible advice (confident and wrong)
        - rationale: Why this is a bad idea (optional, educational)
        - confidence: Number 1-10 (how confident the advice sounds)
        - chaosLevel: Number 1-10 (how disastrous following it could be)
        
        Remember: This is satirical - the goal is humor through obviously terrible suggestions.
        """
    }
    
    private func createPrompt(category: AdviceCategory, situation: String?) -> String {
        if let situation = situation, !situation.isEmpty {
            return "Generate hilariously bad advice for this \(category.title) situation: \(situation)"
        } else {
            return "Generate hilariously bad \(category.title) advice"
        }
    }
    
    private func getCategoryContext(_ category: AdviceCategory) -> String {
        switch category {
        case .dating: return "relationships, romance, and interpersonal connections"
        case .fitness: return "exercise, health, and physical wellness"
        case .career: return "work, professional development, and office life"
        case .money: return "finances, spending, and investment decisions"
        case .parenting: return "raising children and family dynamics"
        case .tech: return "technology, software, and digital life"
        case .social: return "friendships, networking, and social situations"
        case .cooking: return "food preparation, recipes, and kitchen adventures"
        case .travel: return "trips, vacations, and exploring new places"
        case .productivity: return "time management, organization, and getting things done"
        }
    }
    
    private func getTonePersona(_ tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant:
            return "A buzzword-loving consultant who speaks in frameworks and synergies"
        case .alphaPodcast:
            return "An ultra-confident podcast bro who thinks hustle solves everything"
        case .wizard:
            return "A mystical wizard who sees magical solutions to mundane problems"
        case .influencer:
            return "A social media influencer obsessed with aesthetics and going viral"
        case .toxicBestFriend:
            return "A chaotic friend who gives dramatically bad relationship advice"
        case .boomer:
            return "An out-of-touch boomer with strong opinions about 'kids these days'"
        case .cryptoBro:
            return "A crypto enthusiast who sees blockchain as the answer to everything"
        case .minimalistMonk:
            return "An extreme minimalist who thinks less is always more"
        case .friendRoast:
            return "A playful roaster who gives advice through loving mockery"
        case .lifeCoach:
            return "An overly enthusiastic life coach with questionable credentials"
        case .conspiracyTheorist:
            return "Someone who sees hidden agendas in everyday situations"
        }
    }
    
    enum MLError: Error {
        case modelUnavailable
        case generationFailed
        case invalidResponse
    }
}

// MARK: - Structured Output Models

@available(iOS 18.0, *)
@Generable(description: "A piece of confidently terrible advice")
struct BadAdviceResponse {
    @Guide(description: "The main terrible advice line", .count(1...120))
    var advice: String
    
    @Guide(description: "Why this advice is terrible", .count(0...80))
    var rationale: String?
    
    @Guide(description: "How confident it sounds", .range(1...10))
    var confidence: Int
    
    @Guide(description: "How disastrous following it would be", .range(1...10))
    var chaosLevel: Int
}

@available(iOS 18.0, *)
@Generable(description: "Analysis of a user's situation")
struct SituationAnalysis {
    @Guide(description: "Key themes in the situation", .count(1...5))
    var themes: [String]
    
    @Guide(description: "Detected emotional state")
    var emotionalState: String
    
    @Guide(description: "Relevant keywords", .count(3...10))
    var keywords: [String]
    
    @Guide(description: "Complexity level", .range(1...10))
    var complexity: Int
}

@available(iOS 18.0, *)
@Generable(description: "Variations of existing advice")
struct AdviceVariations {
    @Guide(description: "Different phrasings of the same bad idea", .count(3...5))
    var variations: [String]
}

@available(iOS 18.0, *)
@Generable(description: "Humor analysis of advice")
struct HumorAnalysis {
    @Guide(description: "How absurd the advice is", .range(1...10))
    var absurdityScore: Int
    
    @Guide(description: "Level of irony", .range(1...10))
    var ironyScore: Int
    
    @Guide(description: "Potential for misinterpretation", .range(1...10))
    var misinterpretationRisk: Int
    
    @Guide(description: "Overall humor rating", .range(1...10))
    var humorScore: Int
    
    @Guide(description: "Why it's funny or not")
    var analysis: String
}

// MARK: - Enhanced Data Models

struct EnhancedAdvice {
    let adviceLine: String
    let rationaleLine: String?
    let confidence: Int
    let chaosLevel: Int
    let category: AdviceCategory
    let tone: ToneMode
    var generatedAt: Date = Date()
    
    var qualityScore: Double {
        Double(confidence + chaosLevel) / 20.0
    }
}

struct EnhancedSituation {
    let originalText: String
    let themes: [String]
    let emotionalState: String
    let keywords: [String]
    let complexity: Int
}

struct PartialAdvice {
    let advice: String?
    let rationale: String?
    let confidence: Int?
    let chaosLevel: Int?
}

// MARK: - Integration Extension for GenerateViewModel

extension GenerateViewModel {
    @available(iOS 18.0, *)
    func generateWithML(
        mlGenerator: MLAdviceGenerator,
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?
    ) async {
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let enhanced = try await mlGenerator.generateEnhancedAdvice(
                category: category,
                tone: tone,
                situation: situation,
                includeRationale: settingsViewModel.includeRationale
            )
            
            // Convert to AdviceRecord
            let record = AdviceRecord(
                createdAt: enhanced.generatedAt,
                category: category,
                tone: tone,
                adviceLine: enhanced.adviceLine,
                rationaleLine: enhanced.rationaleLine
            )
            
            current = record
            repository.save(record)
            
            // Update haptics based on chaos level
            hapticWeight = Double(enhanced.chaosLevel) / 10.0
            hapticTrigger += 1
            
        } catch {
            print("ML generation failed: \(error)")
            // Fallback to traditional generation
            generate()
        }
    }
}
