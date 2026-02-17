import Foundation
import SwiftUI
import Combine

// MARK: - Performance Optimization Manager

@MainActor
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    @Published var isLowPowerModeEnabled = false
    @Published var memoryWarningReceived = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        // Monitor low power mode
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .store(in: &cancellables)
        
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        memoryWarningReceived = true
        
        // Clear caches
        ImageCache.shared.clearCache()
        ParticleCache.shared.clearCache()
        
        // Reduce animation complexity
        AnimationManager.shared.reduceComplexity()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.memoryWarningReceived = false
        }
    }
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    private let maxMemorySize = 50 * 1024 * 1024 // 50 MB
    
    private init() {
        cache.totalCostLimit = maxMemorySize
        cache.countLimit = 100
    }
    
    func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Particle Cache

class ParticleCache {
    static let shared = ParticleCache()
    
    private var cachedPositions: [[CGPoint]] = []
    private let maxCachedSets = 10
    
    private init() {}
    
    func cachePositions(_ positions: [CGPoint]) {
        if cachedPositions.count >= maxCachedSets {
            cachedPositions.removeFirst()
        }
        cachedPositions.append(positions)
    }
    
    func getCachedPositions() -> [CGPoint]? {
        cachedPositions.randomElement()
    }
    
    func clearCache() {
        cachedPositions.removeAll()
    }
}

// MARK: - Animation Manager

@MainActor
class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    
    @Published var complexity: AnimationComplexity = .high
    @Published var frameRate: Double = 60
    
    enum AnimationComplexity {
        case low, medium, high
        
        var particleCount: Int {
            switch self {
            case .low: return 5
            case .medium: return 12
            case .high: return 20
            }
        }
        
        var animationDuration: Double {
            switch self {
            case .low: return 0.1
            case .medium: return 0.2
            case .high: return 0.3
            }
        }
    }
    
    private init() {
        adjustForPowerMode()
    }
    
    func reduceComplexity() {
        complexity = .low
        frameRate = 30
    }
    
    func restoreComplexity() {
        adjustForPowerMode()
    }
    
    private func adjustForPowerMode() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            complexity = .low
            frameRate = 30
        } else {
            complexity = .high
            frameRate = 60
        }
    }
}

// MARK: - Lazy Loading Manager

class LazyLoadingManager {
    static let shared = LazyLoadingManager()
    
    private var loadedRanges: [Range<Int>] = []
    private let preloadThreshold = 5
    
    private init() {}
    
    func shouldLoad(index: Int, total: Int) -> Bool {
        // Check if already loaded
        if loadedRanges.contains(where: { $0.contains(index) }) {
            return false
        }
        
        // Load in chunks
        let chunkSize = 20
        let chunkStart = (index / chunkSize) * chunkSize
        let chunkEnd = min(chunkStart + chunkSize, total)
        
        loadedRanges.append(chunkStart..<chunkEnd)
        return true
    }
    
    func shouldPreload(index: Int, total: Int, visibleIndices: [Int]) -> Bool {
        guard let maxVisible = visibleIndices.max() else { return false }
        return index <= maxVisible + preloadThreshold
    }
    
    func reset() {
        loadedRanges.removeAll()
    }
}

// MARK: - Database Query Optimizer

class QueryOptimizer {
    static let shared = QueryOptimizer()
    
    private var queryCache: [String: (result: Any, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 60 // 1 minute
    
    private init() {}
    
    func getCached<T>(forKey key: String) -> T? {
        guard let cached = queryCache[key] else { return nil }
        
        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationInterval {
            queryCache.removeValue(forKey: key)
            return nil
        }
        
        return cached.result as? T
    }
    
    func cache<T>(_ result: T, forKey key: String) {
        queryCache[key] = (result, Date())
    }
    
    func clearCache() {
        queryCache.removeAll()
    }
    
    func clearExpired() {
        let now = Date()
        queryCache = queryCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) <= cacheExpirationInterval
        }
    }
}

// MARK: - Batch Processing

class BatchProcessor<T> {
    private let batchSize: Int
    private let processingQueue = DispatchQueue(label: "com.badvice.batchprocessor", qos: .userInitiated)
    
    init(batchSize: Int = 50) {
        self.batchSize = batchSize
    }
    
    func process(
        items: [T],
        operation: @escaping (T) -> Void,
        completion: @escaping () -> Void
    ) {
        processingQueue.async {
            let batches = stride(from: 0, to: items.count, by: self.batchSize).map {
                Array(items[$0..<min($0 + self.batchSize, items.count)])
            }
            
            for batch in batches {
                batch.forEach(operation)
                
                // Small delay between batches to prevent overwhelming the system
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

// MARK: - View Recycling Pool

class ViewRecyclingPool<T: Identifiable> {
    private var pool: [String: [T]] = [:]
    private let maxPoolSize = 50
    
    func recycle(_ item: T, forType type: String) {
        var items = pool[type, default: []]
        if items.count < maxPoolSize {
            items.append(item)
            pool[type] = items
        }
    }
    
    func dequeue(forType type: String) -> T? {
        guard var items = pool[type], !items.isEmpty else { return nil }
        let item = items.removeFirst()
        pool[type] = items
        return item
    }
    
    func clear() {
        pool.removeAll()
    }
}

// MARK: - Throttle and Debounce

class ThrottleDebounce {
    private var workItem: DispatchWorkItem?
    private var lastExecutionTime: Date?
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }
    
    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    func throttle(interval: TimeInterval, action: @escaping () -> Void) {
        let now = Date()
        
        if let lastExecution = lastExecutionTime {
            let elapsed = now.timeIntervalSince(lastExecution)
            if elapsed < interval {
                return
            }
        }
        
        lastExecutionTime = now
        queue.async(execute: action)
    }
}

// MARK: - Memory Monitor

class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    private init() {}
    
    func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    func memoryUsageString() -> String {
        let bytes = currentMemoryUsage()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func isMemoryPressureHigh() -> Bool {
        let usage = currentMemoryUsage()
        let threshold: UInt64 = 500 * 1024 * 1024 // 500 MB
        return usage > threshold
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let timestamp: Date
    let memoryUsage: UInt64
    let frameRate: Double
    let animationComplexity: AnimationManager.AnimationComplexity
    let cacheHitRate: Double
    
    static func current() -> PerformanceMetrics {
        PerformanceMetrics(
            timestamp: Date(),
            memoryUsage: MemoryMonitor.shared.currentMemoryUsage(),
            frameRate: AnimationManager.shared.frameRate,
            animationComplexity: AnimationManager.shared.complexity,
            cacheHitRate: 0.85 // Mock value
        )
    }
}

// MARK: - SwiftUI Performance Extensions

extension View {
    func performanceOptimized() -> some View {
        self
            .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
    
    func conditionalAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V,
        isEnabled: Bool = true
    ) -> some View {
        self.animation(isEnabled ? animation : nil, value: value)
    }
    
    func lazyRendering(id: some Hashable) -> some View {
        self.id(id)
            .drawingGroup()
    }
}

// MARK: - Background Task Optimizer

class BackgroundTaskOptimizer {
    static let shared = BackgroundTaskOptimizer()
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .utility
        return queue
    }()
    
    private init() {}
    
    func schedule(_ task: @escaping () -> Void) {
        operationQueue.addOperation(task)
    }
    
    func scheduleHighPriority(_ task: @escaping () -> Void) {
        let operation = BlockOperation(block: task)
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }
    
    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}
