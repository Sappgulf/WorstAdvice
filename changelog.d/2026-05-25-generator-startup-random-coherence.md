## [fix] Generator startup and random coherence  (2026-05-25)

**What:** Made the Generate tab start on a coherent Career + Corporate Consultant pair, show immediate launch generation state, use a fast classic bootstrap card while local model warmup continues, and filter random category/tone picks away from compatibility warnings.
**Why:** Fresh launch should produce advice quickly, and random mixes should feel intentional instead of landing on awkward category/tone combinations.
**Files:** `Badvice/State/GenerateViewModel.swift`, `Badvice/Models/AppModels.swift`, `WorstAdviceTests/AppSessionSmokeTests.swift`
