import Foundation
import SwiftUI
import OSLog

/// App-wide performance optimization manager
@MainActor
final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private let logger = Logger(subsystem: "com.worstadvice.app", category: "performance")
    
    // MARK: - Memory Management
    
    /// Cache for expensive computations
    private var computationCache: [String: Any] = [:]
    private let maxCacheSize = 50
    
    /// Image cache for share cards
    private var imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 20
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    // MARK: - Cache Management
    
    func getCached<T>(_ key: String) -> T? {
        return computationCache[key] as? T
    }
    
    func cache<T>(_ value: T, forKey key: String) {
        if computationCache.count >= maxCacheSize {
            // Remove oldest entries (simplified LRU)
            let keysToRemove = Array(computationCache.keys.prefix(10))
            keysToRemove.forEach { computationCache.removeValue(forKey: $0) }
        }
        computationCache[key] = value
    }
    
    func clearCache() {
        computationCache.removeAll()
        imageCache.removeAllObjects()
        logger.info("Performance cache cleared")
    }
    
    // MARK: - Image Caching
    
    func cacheImage(_ image: UIImage, forKey key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    func getCachedImage(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received, clearing caches")
        clearCache()
    }
    
    // MARK: - Performance Metrics
    
    func measurePerformance<T>(
        _ operation: String,
        block: () -> T
    ) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        if duration > 0.016 { // More than 1 frame (16ms at 60fps)
            logger.warning("Slow operation: \(operation, privacy: .public) took \(duration * 1000, privacy: .public)ms")
        }
        
        return result
    }
    
    func measureAsyncPerformance<T>(
        _ operation: String,
        block: () async -> T
    ) async -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        if duration > 0.016 {
            logger.warning("Slow async operation: \(operation, privacy: .public) took \(duration * 1000, privacy: .public)ms")
        }
        
        return result
    }
}

// MARK: - View Extensions for Performance

extension View {
    /// Apply performance optimizations based on budget
    func optimized(for budget: RenderBudget) -> some View {
        self.modifier(PerformanceOptimizedModifier(budget: budget))
    }
    
    /// Conditionally enable drawing group for expensive rendering
    @ViewBuilder
    func conditionalDrawingGroup(_ enabled: Bool) -> some View {
        if enabled {
            self.drawingGroup()
        } else {
            self
        }
    }
    
    /// Add lazy loading wrapper
    func lazyLoad(priority: TaskPriority = .userInitiated) -> some View {
        self.modifier(LazyLoadModifier(priority: priority))
    }
}

private struct PerformanceOptimizedModifier: ViewModifier {
    let budget: RenderBudget
    
    func body(content: Content) -> some View {
        switch budget {
        case .full:
            content
        case .balanced:
            content
                .animation(.easeInOut(duration: 0.25), value: budget)
        case .reduced:
            content
                .animation(nil)
                .drawingGroup(opaque: false, colorMode: .linear)
        }
    }
}

private struct LazyLoadModifier: ViewModifier {
    let priority: TaskPriority
    @State private var isLoaded = false
    
    func body(content: Content) -> some View {
        Group {
            if isLoaded {
                content
            } else {
                Color.clear
                    .task(priority: priority) {
                        await Task.yield() // Allow other tasks to run
                        isLoaded = true
                    }
            }
        }
    }
}

// MARK: - Text Normalization Cache

actor TextNormalizationCache {
    private var cache: [String: String] = [:]
    private let maxSize = 100
    
    func get(_ text: String) -> String? {
        return cache[text]
    }
    
    func set(_ text: String, normalized: String) {
        if cache.count >= maxSize {
            // Remove first 20 entries
            let keysToRemove = Array(cache.keys.prefix(20))
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
        cache[text] = normalized
    }
    
    func clear() {
        cache.removeAll()
    }
}

// MARK: - Debouncer for Search/Filter Operations

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let duration: TimeInterval
    
    init(duration: TimeInterval = 0.3) {
        self.duration = duration
    }
    
    func debounce(_ action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Batch Processing

actor BatchProcessor<T> {
    private var items: [T] = []
    private let batchSize: Int
    private let processingDelay: TimeInterval
    private var processingTask: Task<Void, Never>?
    
    init(batchSize: Int = 50, processingDelay: TimeInterval = 0.1) {
        self.batchSize = batchSize
        self.processingDelay = processingDelay
    }
    
    func add(_ item: T) {
        items.append(item)
        scheduleProcessing()
    }
    
    func addBatch(_ newItems: [T]) {
        items.append(contentsOf: newItems)
        scheduleProcessing()
    }
    
    private func scheduleProcessing() {
        guard processingTask == nil || processingTask?.isCancelled == true else { return }
        
        processingTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
            await processBatch()
        }
    }
    
    private func processBatch() async {
        // Process in chunks to avoid blocking
        let chunk = Array(items.prefix(batchSize))
        items.removeFirst(min(batchSize, items.count))
        
        // Subclasses should override this
        // For now, just clear the batch
        if !items.isEmpty {
            scheduleProcessing()
        }
    }
}

// MARK: - View Lifecycle Optimizer

struct ViewLifecycleOptimizer: ViewModifier {
    @State private var hasAppeared = false
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    // Expensive one-time setup here
                }
                isVisible = true
            }
            .onDisappear {
                isVisible = false
                // Cleanup here
            }
    }
}

extension View {
    func optimizeLifecycle() -> some View {
        modifier(ViewLifecycleOptimizer())
    }
}

// MARK: - Conditional Animation Helper

extension Animation {
    static func conditional(_ enabled: Bool, _ animation: Animation) -> Animation? {
        enabled ? animation : nil
    }
}

// MARK: - Memory Efficient List Helper

struct MemoryEfficientList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let visibleThreshold: Int
    let content: (Data.Element) -> Content
    
    @State private var visibleRange: Range<Int> = 0..<20
    
    init(
        _ data: Data,
        visibleThreshold: Int = 20,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.visibleThreshold = visibleThreshold
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .onAppear {
                            updateVisibleRange(around: index)
                        }
                }
            }
        }
    }
    
    private func updateVisibleRange(around index: Int) {
        let start = max(0, index - visibleThreshold / 2)
        let end = min(data.count, index + visibleThreshold / 2)
        visibleRange = start..<end
    }
}

// MARK: - Performance Metrics Struct

struct PerformanceMetrics {
    var renderTime: TimeInterval = 0
    var memoryUsage: UInt64 = 0
    var cacheHitRate: Double = 0
    var frameDrops: Int = 0
    
    mutating func update(renderTime: TimeInterval) {
        self.renderTime = renderTime
    }
    
    var isHealthy: Bool {
        renderTime < 0.016 && frameDrops < 5
    }
}
