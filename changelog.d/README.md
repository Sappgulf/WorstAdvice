# changelog.d — How to Use

Each feature or fix gets its own file in this directory, named:

    <date>-<short-slug>.md
    e.g.  2026-02-20-theme-hoisting.md

When releasing, run the aggregation script or manually merge entries
into the root CHANGELOG.md.

## Entry Format

```
## [type] Short title  (date)

**What:** What was added/changed/fixed.
**Why:** The problem it solves or value it adds.
**Files:** Key files touched.
```

Types: `feat` · `fix` · `perf` · `refactor` · `content` · `chore`
