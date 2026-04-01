import SwiftUI

actor ImageCache {
    static let shared = ImageCache()

    /// Maximum total cache size in bytes (50 MB).
    private let maxBytes: Int = 50 * 1024 * 1024

    private var cache: [URL: Data] = [:]
    /// Access order for LRU eviction — oldest access is at index 0.
    private var accessOrder: [URL] = []
    private var totalBytes: Int = 0
    private var inProgress: [URL: Task<Data?, Never>] = [:]

    func data(for url: URL) -> Data? {
        guard let data = cache[url] else { return nil }
        touch(url)
        return data
    }

    func setData(_ data: Data, for url: URL) {
        insert(data: data, for: url)
    }

    func loadData(from url: URL) async -> Data? {
        if let cached = cache[url] {
            touch(url)
            return cached
        }

        if let existingTask = inProgress[url] {
            return await existingTask.value
        }

        let task = Task<Data?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                return nil
            }
            guard !Task.isCancelled else { return nil }
            insert(data: data, for: url)
            return data
        }

        inProgress[url] = task
        let result = await task.value
        inProgress[url] = nil
        return result
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        totalBytes = 0
    }

    // MARK: - LRU helpers

    private func insert(data: Data, for url: URL) {
        if let existing = cache[url] {
            totalBytes -= existing.count
            accessOrder.removeAll { $0 == url }
        }
        cache[url] = data
        totalBytes += data.count
        accessOrder.append(url)
        evictIfNeeded()
    }

    private func touch(_ url: URL) {
        accessOrder.removeAll { $0 == url }
        accessOrder.append(url)
    }

    private func evictIfNeeded() {
        while totalBytes > maxBytes, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            if let evicted = cache.removeValue(forKey: oldest) {
                totalBytes -= evicted.count
            }
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var imageData: Data?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        if let cached = await ImageCache.shared.data(for: url) {
            self.imageData = cached
            return
        }
        
        if let loaded = await ImageCache.shared.loadData(from: url) {
            self.imageData = loaded
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif
