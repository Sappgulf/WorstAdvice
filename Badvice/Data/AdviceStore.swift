import Foundation

struct AdviceStore {
    let categoryRules: [AdviceCategory: CategoryRuleSet]
    let toneProfiles: [ToneMode: ToneProfile]
    let contentPackAugments: [ContentPack: [AdviceCategory: CategoryRuleAugment]]
    private let resolvedBaseRules: [AdviceCategory: CategoryRuleSet]
    private let resolvedRulesByPack: [ContentPack: [AdviceCategory: CategoryRuleSet]]

    init(
        categoryRules: [AdviceCategory: CategoryRuleSet] = AdviceStore.defaultCategoryRules,
        toneProfiles: [ToneMode: ToneProfile] = AdviceStore.defaultToneProfiles,
        contentPackAugments: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = AdviceStore.defaultContentPackAugments
    ) {
        self.categoryRules = categoryRules
        self.toneProfiles = toneProfiles
        self.contentPackAugments = contentPackAugments

        let fallbackRules: CategoryRuleSet
        if let resolvedFallback = categoryRules[.productivity] ?? AdviceStore.defaultCategoryRules[.productivity] {
            fallbackRules = resolvedFallback
        } else {
            assertionFailure(
                "AdviceStore: .productivity entry missing from defaultCategoryRules; falling back to empty rules"
            )
            fallbackRules = CategoryRuleSet(
                badPrinciples: [],
                keywords: [],
                forbiddenPatterns: [],
                actionTemplates: [],
                rationaleTemplates: []
            )
        }
        var baseRules: [AdviceCategory: CategoryRuleSet] = [:]
        for category in AdviceCategory.concrete {
            let base = categoryRules[category] ?? fallbackRules
            baseRules[category] = base.merged(with: Self.generatedBaseExpansion(for: category))
        }
        self.resolvedBaseRules = baseRules

        let fallbackResolved = baseRules[.productivity] ?? fallbackRules
        var packRules: [ContentPack: [AdviceCategory: CategoryRuleSet]] = [.classic: baseRules]
        for pack in ContentPack.allCases where pack != .classic {
            var categoryMap: [AdviceCategory: CategoryRuleSet] = [:]
            for category in AdviceCategory.concrete {
                let base = baseRules[category] ?? fallbackResolved
                let storedAugment = contentPackAugments[pack]?[category] ?? .empty
                let generatedAugment = Self.generatedPackExpansion(for: pack, category: category)
                categoryMap[category] = base.merged(with: storedAugment.merged(with: generatedAugment))
            }
            packRules[pack] = categoryMap
        }
        self.resolvedRulesByPack = packRules
    }

    func rules(for category: AdviceCategory) -> CategoryRuleSet {
        if let rules = resolvedBaseRules[category] {
            return rules
        }
        return resolvedBaseRules[.productivity] ?? CategoryRuleSet(
            badPrinciples: [],
            keywords: [],
            forbiddenPatterns: [],
            actionTemplates: [],
            rationaleTemplates: []
        )
    }

    func rules(for category: AdviceCategory, contentPack: ContentPack) -> CategoryRuleSet {
        resolvedRulesByPack[contentPack]?[category] ?? rules(for: category)
    }

    func profile(for tone: ToneMode) -> ToneProfile {
        guard tone != .random else {
            return toneProfiles[.corporateConsultant] ?? Self.defaultToneProfiles[.corporateConsultant] ?? ToneProfile(opener: [], confidenceTag: [], rhetoricalTick: [], ending: [], slang: [])
        }
        return toneProfiles[tone] ?? Self.defaultToneProfiles[.corporateConsultant] ?? ToneProfile(opener: [], confidenceTag: [], rhetoricalTick: [], ending: [], slang: [])
    }

    func toneDirectiveVocabulary(for tone: ToneMode) -> [String] {
        AdviceStore.toneDirectiveVocabulary[tone] ?? AdviceStore.toneDirectiveVocabulary[.corporateConsultant] ?? ["assertive framing"]
    }

    func categoryDirectiveVocabulary(for category: AdviceCategory) -> [String] {
        AdviceStore.categoryDirectiveVocabulary[category] ?? AdviceStore.categoryDirectiveVocabulary[.productivity] ?? ["visible momentum"]
    }
}
