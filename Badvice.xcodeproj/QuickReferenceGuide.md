# Quick Reference Guide - Theme & Performance Updates

## 🎨 Using Enhanced Themes

### Check for Theme Features
```swift
// Check if theme has secondary accent
if let secondary = Theme.secondaryAccent(for: theme) {
    // Use dual-color design
}

// Check if theme supports glow
if Theme.shouldUseGlow(for: theme) {
    // Add glow effects
}

// Get glassmorphism intensity
let glassOpacity = Theme.glassMorphismOpacity(for: theme)
```

### Apply Smooth Theme Transitions
```swift
VStack {
    // Your content
}
.themeTransition(settings.theme)
```

### Use Enhanced Shadows
```swift
.shadow(
    color: Theme.cardShadow(for: theme).color,
    radius: Theme.cardShadow(for: theme).radius,
    y: Theme.cardShadow(for: theme).y
)
// Optionally add secondary shadow
if let secondary = Theme.cardSecondaryShadow(for: theme) {
    .overlay {
        // Secondary shadow layer
    }
}
```

---

## ⚡️ Using Performance Optimizations

### Apply Render Budget Optimization
```swift
view
    .optimized(for: renderBudget)
```

### Use Metal Acceleration Conditionally
```swift
ComplexCanvasView()
    .conditionalDrawingGroup(shouldOptimize)
```

### Lazy Load Expensive Views
```swift
HeavyContentView()
    .lazyLoad(priority: .userInitiated)
```

### Optimize View Lifecycle
```swift
view
    .optimizeLifecycle()
```

---

## 📊 Performance Monitoring

### Measure Operation Performance
```swift
let result = PerformanceOptimizer.shared.measurePerformance("Operation name") {
    // Your code
    return someValue
}

// Async version
let result = await PerformanceOptimizer.shared.measureAsyncPerformance("Async op") {
    // Your async code
    return someValue
}
```

### Cache Expensive Computations
```swift
// Check cache
if let cached: MyType = PerformanceOptimizer.shared.getCached("myKey") {
    return cached
}

// Compute and cache
let result = expensiveComputation()
PerformanceOptimizer.shared.cache(result, forKey: "myKey")
```

### Cache Images
```swift
// Get from cache
if let image = PerformanceOptimizer.shared.getCachedImage(forKey: "shareCard") {
    return image
}

// Generate and cache
let image = generateShareCard()
PerformanceOptimizer.shared.cacheImage(image, forKey: "shareCard")
```

---

## 🔧 Advanced Utilities

### Debounce Search/Filter
```swift
class ViewModel {
    private let searchDebouncer = Debouncer(duration: 0.3)
    
    func search(_ query: String) {
        searchDebouncer.debounce {
            await self.performSearch(query)
        }
    }
}
```

### Batch Process Items
```swift
let processor = BatchProcessor<Item>(batchSize: 50, processingDelay: 0.1)

await processor.add(item)
await processor.addBatch(items)
```

### Use Memory-Efficient Lists
```swift
MemoryEfficientList(largeDataSet, visibleThreshold: 20) { item in
    RowView(item)
}
```

---

## 🎯 Best Practices

### ✅ DO
- Use `.optimized(for:)` on views with expensive rendering
- Apply `.conditionalDrawingGroup()` to complex Canvas views
- Cache expensive computations that are reused
- Use `.lazyLoad()` for views that can defer loading
- Measure performance of critical paths
- Respect reduce motion settings
- Use render budgets appropriately

### ❌ DON'T
- Over-cache (respects 50-item limit automatically)
- Use `.drawingGroup()` on simple views (adds overhead)
- Ignore render budgets
- Bypass performance monitoring on critical operations
- Block main thread with synchronous operations
- Forget to clear caches when appropriate

---

## 📱 Render Budget Guidelines

### When to Use Each Budget

**Full** - Use when:
- User is actively generating advice
- Animations are critical to UX
- Device has resources available

**Balanced** - Use when:
- General navigation
- Tab bar is visible
- Standard user interaction

**Reduced** - Use when:
- Tab bar is hidden (content focus)
- Low power mode detected
- Device is under stress
- Background operations running

### Example
```swift
private func budget(for session: AppSessionViewModel) -> RenderBudget {
    switch context {
    case .generating:
        return .full
    case .browsing:
        return .balanced
    case .scrolling:
        return .reduced
    }
}
```

---

## 🎨 Theme Personality Guide

### Premium Themes (Full Effects)
- **Neon** - Magenta + Cyan, strongest shadows, full glow
- **Cosmic** - Purple gradients, starfield, dual shadows
- **Retro** - Matrix Green + Hot Pink, CRT effects

### Atmospheric Themes
- **Midnight** - Frost blue, deep shadows, Nord-inspired
- **Sunset** - Gold + Coral, warm depth

### Nature Themes
- **Evergreen** - Sage + Forest, organic feel
- **Ember** - Ember orange, energetic

### Clean Themes
- **Minimal** - Softest shadows, no effects, readability
- **Badvice** - Signature coral, balanced effects
- **Slate** - Cool blue, professional

---

## 🐛 Debugging Performance Issues

### Check Performance Logs
```swift
// Look for these in Console.app:
// "Slow operation: X took Yms"
// "Memory warning received, clearing caches"
```

### Profile with Instruments
1. Product → Profile (⌘I)
2. Choose "Time Profiler" or "Allocations"
3. Look for hot paths in performance-critical code

### Use Performance Monitor (Debug Only)
```swift
#if DEBUG
view.performanceMonitor(theme: theme, enabled: true)
#endif
```

### Check Memory Usage
```swift
// Memory warnings trigger automatic cache clearing
// Check Console for: "Memory warning received"
```

---

## 📦 Migration Guide

### Old Code
```swift
// Before
view
    .background(Theme.cardColor(for: theme))
    .shadow(color: .black.opacity(0.3), radius: 10)
```

### New Code
```swift
// After
view
    .background(Theme.cardColor(for: theme))
    .shadow(
        color: Theme.cardShadow(for: theme).color,
        radius: Theme.cardShadow(for: theme).radius,
        y: Theme.cardShadow(for: theme).y
    )
    .themeTransition(theme)
```

---

## 🔍 Testing Checklist

- [ ] Test all 10 themes for visual consistency
- [ ] Verify 60 FPS in performance monitor
- [ ] Check memory usage (should be <150MB)
- [ ] Test with reduce motion enabled
- [ ] Verify theme transitions are smooth
- [ ] Test on older devices (iPhone 12/13)
- [ ] Profile with Instruments
- [ ] Check battery drain (background mode)
- [ ] Verify accessibility features work
- [ ] Test low power mode behavior

---

## 📞 Need Help?

### Resources
- **ThemePolishSummary.md** - Complete theme documentation
- **PerformanceEnhancementSummary.md** - Performance guide
- **ThemeShowcaseView.swift** - Interactive theme testing
- **ThemePerformanceHelper.swift** - Performance utilities

### Common Issues

**Issue**: Theme switching is slow
**Solution**: Ensure `.themeTransition()` is applied

**Issue**: High memory usage
**Solution**: Check cache sizes, verify automatic cleanup

**Issue**: Frame drops
**Solution**: Apply `.optimized(for:)` and appropriate render budget

**Issue**: Effects not showing
**Solution**: Check render budget and scene phase

---

## 🚀 Quick Wins

### Instant Improvements
```swift
// 1. Add to any expensive view
.optimized(for: renderBudget)

// 2. Add to complex Canvas
.conditionalDrawingGroup(true)

// 3. Add to theme-aware views
.themeTransition(theme)

// 4. Measure critical operations
PerformanceOptimizer.shared.measurePerformance("Operation") {
    // code
}
```

### One-Liner Optimizations
```swift
// Before: Multiple theme lookups
let color1 = Theme.accent(for: theme)
let color2 = Theme.accent(for: theme) // Redundant!

// After: Cache in computed property
private var accentColor: Color { Theme.accent(for: theme) }
```

---

**Last Updated**: 2026-02-17
**Version**: 2.0 (Theme Polish & Performance Update)
