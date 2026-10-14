## [fix] Make advice easier to follow (2026-10-13)

**What:** Tightened the Apple Intelligence writing contract, rejected malformed model drafts, and paired each Bureau action with its own punchline. Simplified Bureau sentence structure and tone lead-ins.
**Why:** Safe output was reaching users even when it was repetitive, fragmented, or logically disconnected; independent joke selection could also splice unrelated setup and payoff.
**Files:** `Badvice/Engine/AdviceEngine.swift`, `Badvice/Services/AppleOnDeviceBridge.swift`, `Badvice/State/GenerateViewModel.swift`
