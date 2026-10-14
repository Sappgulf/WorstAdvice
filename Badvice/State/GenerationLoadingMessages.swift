import Foundation

enum AdviceGenerationStage: String, CaseIterable, Identifiable, Sendable {
    case preparing
    case checkingContext
    case draftingApple
    case draftingBureau
    case draftingCommunity
    case reviewing
    case ranking
    case filing
    case complete

    var id: String { rawValue }

    /// Completed work in the generation pipeline. Drafting remains a stable
    /// milestone while Foundation Models returns its non-streaming response.
    var progress: Double {
        return switch self {
        case .preparing: 0.06
        case .checkingContext: 0.16
        case .draftingApple, .draftingBureau, .draftingCommunity: 0.35
        case .reviewing: 0.68
        case .ranking: 0.82
        case .filing: 0.94
        case .complete: 1
        }
    }

    var title: String {
        return switch self {
        case .preparing: "PREPARING THE BRIEF"
        case .checkingContext: "CHECKING THE FILE"
        case .draftingApple: "APPLE INTELLIGENCE IS WRITING"
        case .draftingBureau: "THE BUREAU IS DRAFTING"
        case .draftingCommunity: "CURATING THE COMMUNITY TAKE"
        case .reviewing: "RUNNING THE QUALITY CHECK"
        case .ranking: "PICKING THE STRONGEST LINE"
        case .filing: "SEALING THE CASE FILE"
        case .complete: "FILED"
        }
    }

    var accessibilityStatus: String {
        return switch self {
        case .preparing: "Preparing the advice brief"
        case .checkingContext: "Checking the selected topic and situation"
        case .draftingApple: "Writing with Apple Intelligence on device"
        case .draftingBureau: "Writing with the local Bureau Engine"
        case .draftingCommunity: "Matching community suggestions"
        case .reviewing: "Reviewing safety, topic fit, and repeated lines"
        case .ranking: "Choosing the strongest candidate"
        case .filing: "Saving the new advice"
        case .complete: "Advice is ready"
        }
    }

    func message(category: AdviceCategory, tone: ToneMode) -> String {
        return switch self {
        case .preparing:
            "Tuning a \(category.title.lowercased()) brief for \(tone.voice.name)."
        case .checkingContext:
            "Checking your situation, saved takes, and repeat filters."
        case .draftingApple:
            "Writing a fresh \(category.title.lowercased()) take in \(tone.voice.name)'s voice."
        case .draftingBureau:
            "Building a fresh \(category.title.lowercased()) take from the Bureau's local playbook."
        case .draftingCommunity:
            "Matching community suggestions to your topic and voice."
        case .reviewing:
            "Checking topic fit, voice, safety, and repeated lines."
        case .ranking:
            "Choosing the strongest fit for this brief."
        case .filing:
            "Saving the take and its case details."
        case .complete:
            "Your new bad advice is ready."
        }
    }
}

enum GenerationLoadingMessages {
    private static let bootstrapMessages: [String] = [
        "Summoning bad judgment…",
        "Warming up the confidence simulator.",
        "Checking that optimism is at least 2% functional.",
        "Booting the chaos engine and sealing every leak.",
        "Asking the universe if certainty is actually required.",
        "Charging the sarcasm battery to cruising tempo.",
        "Convincing vibes to pass for evidence, for now.",
        "Assembling a short list of gloriously reckless options.",
        "Running a preflight pass on the hype deck.",
        "Forging a first-draft from controlled chaos.",
        "Running a reality check on your biggest impulse.",
        "Polishing a plan so the risks look intentional.",
    ]

    private static let synthesisMessages: [String] = [
        "Asking the advice gremlins to stop rehearsing.",
        "Scanning your vibe for the highest-leverage mistake.",
        "Cross-checking audacity against historical faceplants.",
        "Polishing the risky angle until it glows.",
        "Brewing confidence tea and pouring it over data.",
        "Spinning a wheel labeled “Bold Move.”",
        "Drafting a fallback plan that sounds cooler.",
        "Collecting vibes and pretending they count as proof.",
        "Sharpening the most dramatic option.",
        "Charging the roast engine and praying to speed.",
        "Building a punchy one-liner for each outcome.",
        "Testing one more wildly honest angle.",
    ]

    private static let curationMessages: [String] = [
        "Comparing candidates and ranking theatrical courage.",
        "Checking if this advice survives one awkward silence.",
        "Compressing hesitation into momentum.",
        "Reframing doubt as premium uncertainty.",
        "Making the committee of highly confident experts vote.",
        "Testing the idea against real-world embarrassment.",
        "Running a risk audit with tiny hands.",
        "Converting overthinking into overconfidence.",
        "Polishing a panic into a plan.",
        "Giving your second thoughts a pep talk.",
        "Borrowing caution from people who finish things.",
        "Checking every option for style, chaos, and recovery.",
    ]

    private static let polishMessages: [String] = [
        "Aligning bad decisions with excellent naming.",
        "Installing optimism patches at runtime.",
        "Charging the fallback plan battery.",
        "Selecting one tone with maximum chaos compatibility.",
        "Sending your hesitation to silent mode.",
        "Treating complexity as a personality trait.",
        "Applying confidence as a patch.",
        "Running final checks before launch.",
        "Letting the deck become the narrative.",
        "Drafting a comeback before the first mistake.",
        "Tuning the chaos compass to “mostly right.”",
        "Checking for typos in your future headlines.",
        "Adding one more layer of cinematic bravado.",
    ]

    private static var allMessages: [String] {
        bootstrapMessages + synthesisMessages + curationMessages + polishMessages
    }

    static let messages: [String] = allMessages

    static let fallbackMessage = "Summoning bad judgment…"

    static func phaseTitle(forTick tick: Int) -> String {
        let normalized = abs(tick) % 56
        switch normalized {
        case 0..<14:
            return "Booting chaos engine"
        case 14..<28:
            return "Shaping options"
        case 28..<42:
            return "Selecting the best disaster"
        default:
            return "Polishing the final hit"
        }
    }

    static func message(forTick tick: Int) -> String {
        guard !messages.isEmpty else {
            return fallbackMessage
        }
        let normalized = abs(tick)
        let phase = normalized % 4
        let index: Int
        switch phase {
        case 0:
            index = normalized % bootstrapMessages.count
            return bootstrapMessages[index]
        case 1:
            index = (normalized / 4) % synthesisMessages.count
            return synthesisMessages[index]
        case 2:
            index = (normalized / 4) % curationMessages.count
            return curationMessages[index]
        default:
            index = (normalized / 4) % polishMessages.count
            return polishMessages[index]
        }
    }
}
