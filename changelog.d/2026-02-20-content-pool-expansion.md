## [content] Advice & quote content pool expansion  (2026-02-20)

**What:** Significantly expanded all advice generation content pools.

AdviceStore.swift (per category, all 10 categories):
- +5 badPrinciples each → 50 total new entries
- +5–6 keywords each → 55 total new entries
- +5 actionTemplates each → 50 total new entries
- +3 rationaleTemplates each → 30 total new entries

AdviceEngine+Vocabulary.swift:
- +10 momentumBeats
- +5 rationaleLeads
- +8 pivotPhrases
- +8 escalationClauses
- +40 categorySpice entries (4 per category)
- +20 wisdomAnchorsByCategory entries (2 per category)

SharedDailyQuoteSource.swift:
- 28 curated seed quotes + 8 "famous misquote" entries
- 80 generated quotes from topic × template matrix

**Why:** Larger pools reduce repetition between sessions and increase
the perceived variety of the advice generator and daily quote feed.

**Files:**
- `Data/AdviceStore.swift`
- `Engine/AdviceEngine+Vocabulary.swift`
- `Shared/SharedDailyQuoteSource.swift`
