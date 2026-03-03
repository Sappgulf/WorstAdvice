## [chore] Repo hygiene guard and orphan cleanup  (2026-03-02)

**What:** Added a project-source verification script to catch Swift files that live on disk but are not wired into `Badvice.xcodeproj`, hooked that guard into both CI test entrypoints, corrected the repository path in the README, and removed stale orphaned source/docs that were outside the project graph.
**Why:** The repo had accumulated dead Swift files and stray summary artifacts that made the codebase look larger and noisier than the shipped app. Guarding the Xcode project boundary keeps the repository clean and prevents that drift from returning.
**Files:** `scripts/check_project_sources.js`, `scripts/ci_xcodebuild_tests.sh`, `scripts/ci_ios_smoke.sh`, `README.md`
